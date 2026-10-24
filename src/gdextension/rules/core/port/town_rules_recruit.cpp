// TownRules for the human seat's recruiting (Phase 7, slice 7.6): the recruit
// actions, the muster catalog and their cost texts.

#include "aurelion_rules/port/town_rules_actions.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_context.hpp"
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

// int(d.get(field, {}).get(entry, 0)), read only.
int64_t nested_int(State &state, DictRef dict, Atom field, const Value &entry) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return 0;
	}
	return gd::to_int(state, ai::vget(state, found, entry, int_value(0)));
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

} // namespace

namespace town_rules {

ArrayRef get_recruit_actions(State &state, DictRef session) {
	if (_read_cache_has(state, session, key::recruit_actions)) {
		return gd::as_array(_read_cache_get(state, session, key::recruit_actions));
	}
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		const ArrayRef empty = state.new_array();
		_read_cache_store(state, session, key::recruit_actions, array_value(empty));
		return empty;
	}

	const ArrayRef actions = state.new_array();
	const Value resources = field_or_new_dict(state, session_view::overworld(state, session), key::resources);
	const ArrayRef options = overworld_rules::get_town_recruit_options(state, town);
	for (const Value &unit_id_value : gd::items(state, array_value(options))) {
		const Atom unit_id = gd::to_string(unit_id_value);
		const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
		const int64_t unit_tier = gd::int_field(state, unit, key::tier, 0);
		const Atom tier_label = _unit_tier_label(state, unit_tier);
		const int64_t available = nested_int(state, town, key::available_recruits, unit_id_value);
		const int64_t weekly_growth = gd::to_int(state, state.get(overworld_rules::town_weekly_growth(state, town, dict_value(session)), unit_id_value, int_value(0)));
		const DictRef unit_cost = overworld_rules::town_recruit_cost(state, session, town, unit_id);
		int64_t direct_affordable_count = compat::engine_min<int64_t>(available, _max_affordable_count(state, session, dict_value(unit_cost)));
		int64_t market_affordable_count = _max_market_affordable_count(state, session, town, gd::as_dict(resources), dict_value(unit_cost), available);
		const DictRef destination = hero_command_rules::town_recruitment_destination(state, session, town);
		const DictRef additions = state.new_dict();
		state.set(additions, unit_id_value, int_value(1));
		const DictRef admission = hero_command_rules::army_addition_plan(state, field_or_new_array(state, destination, key::stacks), additions);
		const bool capacity_ok = gd::bool_field(state, admission, key::ok, false);
		if (!capacity_ok) {
			direct_affordable_count = 0;
			market_affordable_count = 0;
		}
		const DictRef direct_recruit_cost = _multiply_resource_cost(state, dict_value(unit_cost), direct_affordable_count);
		const Atom recruit_impact_line = _recruit_choice_impact_line(state, unit_id, direct_affordable_count, available);
		Atom market_summary = key::empty;
		if (market_affordable_count > direct_affordable_count) {
			const DictRef market_readiness = overworld_rules::town_cost_readiness(
					state,
					town,
					gd::as_dict(resources),
					dict_value(_multiply_resource_cost(state, dict_value(unit_cost), market_affordable_count)),
					ai::session_int(state, session, key::day));
			market_summary = _market_coverage_line(state, market_readiness);
		}
		Atom shortfall_summary = key::empty;
		if (market_affordable_count <= 0) {
			shortfall_summary = _cost_shortfall_line(state, overworld_rules::town_cost_readiness(state, town, gd::as_dict(resources), dict_value(unit_cost), ai::session_int(state, session, key::day)));
		}
		if (!capacity_ok) {
			shortfall_summary = gd::stringify(state, state.get(admission, str(key::message), str(key::formation_full)));
		}
		const Atom unit_name = gd::stringify(state, state.get(unit, str(key::name), unit_id_value));
		std::vector<Atom> summary_lines;
		summary_lines.push_back(gd::stringify(state, gd::index(state, destination, str(key::summary))));
		summary_lines.push_back(gd::format(state, key::s_s_x_d_s_weekly, {
				str(tier_label),
				str(unit_name),
				int_value(available),
				str(overworld_rules::describe_unit_recruit_brief(state, unit_id, available)),
				int_value(weekly_growth),
				str(_describe_resources(state, dict_value(unit_cost))),
		}));
		if (recruit_impact_line != key::empty) {
			summary_lines.push_back(recruit_impact_line);
		}
		if (direct_affordable_count > 0) {
			summary_lines.push_back(gd::format(state, key::ready_current_stores_can_field_d, {
					int_value(direct_affordable_count),
					str(_describe_resources(state, dict_value(direct_recruit_cost))),
			}));
			const Atom after_recruit_line = _stores_after_cost_line(state, gd::as_dict(resources), dict_value(direct_recruit_cost));
			if (after_recruit_line != key::empty) {
				summary_lines.push_back(gd::format(state, key::after_recruit_stores_s_town_reserve, {
						str(after_recruit_line),
						int_value(compat::engine_max<int64_t>(0, gd::sub(available, direct_affordable_count))),
				}));
			}
		} else if (market_affordable_count > 0 && market_summary != key::empty) {
			summary_lines.push_back(gd::format(state, key::exchange_can_unlock_d_now_s, {int_value(market_affordable_count), str(market_summary)}));
		} else if (shortfall_summary != key::empty) {
			summary_lines.push_back(gd::format(state, key::blocker_s, {str(shortfall_summary)}));
		}
		const DictRef action = state.new_dict();
		state.set(action, str(key::id), str(gd::format(state, key::recruit_s, {unit_id_value})));
		state.set(action, str(key::label), str(gd::format(state, key::recruit_s_2, {str(unit_name)})));
		state.set(action, str(key::button_label), str(gd::format(state, key::recruit_s_s_s, {
				str(tier_label),
				str(gd::stringify(state, state.get(unit, str(key::name), unit_id_value))),
				str(_recruit_action_badge(state, direct_affordable_count, market_affordable_count)),
		})));
		state.set(action, str(key::summary), str(join_atoms(state, key::newline, summary_lines)));
		state.set(action, str(key::impact_line), str(recruit_impact_line));
		state.set(action, str(key::recommendation_line), str(_action_recommendation_line(
				state,
				key::Recruit,
				gd::stringify(state, state.get(unit, str(key::name), unit_id_value)),
				direct_affordable_count > 0,
				market_affordable_count > direct_affordable_count,
				shortfall_summary,
				recruit_impact_line)));
		state.set(action, str(key::unit_cost), dict_value(unit_cost));
		state.set(action, str(key::unit_tier), int_value(unit_tier));
		state.set(action, str(key::tier_label), str(tier_label));
		state.set(action, str(key::available_count), int_value(available));
		state.set(action, str(key::weekly_growth), int_value(weekly_growth));
		state.set(action, str(key::affordability_label), str(_recruit_affordability_label(state, direct_affordable_count, market_affordable_count, shortfall_summary)));
		state.set(action, str(key::direct_affordable_count), int_value(direct_affordable_count));
		state.set(action, str(key::market_affordable_count), int_value(market_affordable_count));
		state.set(action, str(key::market_coverable), bool_value(market_affordable_count > direct_affordable_count));
		state.set(action, str(key::market_summary), str(market_summary));
		state.set(action, str(key::shortfall_summary), str(shortfall_summary));
		state.set(action, str(key::disabled_reason), str(_disabled_reason_line(state, direct_affordable_count > 0, market_affordable_count > direct_affordable_count, market_summary, shortfall_summary)));
		state.set(action, str(key::disabled), bool_value(direct_affordable_count <= 0));
		state.append(actions, dict_value(action));
	}
	_read_cache_store(state, session, key::recruit_actions, array_value(actions));
	return actions;
}

ArrayRef get_muster_catalog(State &state, DictRef session) {
	if (_read_cache_has(state, session, key::muster_catalog)) {
		return gd::as_array(_read_cache_get(state, session, key::muster_catalog));
	}
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return state.new_array();
	}
	const DictRef actions_by_unit = state.new_dict();
	const ArrayRef recruit_actions = get_recruit_actions(state, session);
	for (const Value &action_value : gd::items(state, array_value(recruit_actions))) {
		if (!gd::is_dict(action_value)) {
			continue;
		}
		const DictRef action = action_value.ref;
		const Atom action_unit = gd::trim_prefix(state, gd::stringify(state, state.get(action, str(key::id), str(key::empty))), key::recruit_2);
		state.set(actions_by_unit, str(action_unit), dict_value(action));
	}
	const ArrayRef catalog = state.new_array();
	const ArrayRef unit_ids = _town_unit_ids(state, town);
	for (const Value &unit_id_value : gd::items(state, array_value(unit_ids))) {
		const Atom unit_id = gd::stringify(state, unit_id_value);
		const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
		if (gd::is_empty(state, unit)) {
			continue;
		}
		const DictRef action = gd::as_dict(field_or_new_dict(state, actions_by_unit, unit_id));
		const DictRef row = !gd::is_empty(state, action) ? gd::as_dict(gd::engine_duplicate(state, dict_value(action), true)) : state.new_dict();
		const int64_t available = nested_int(state, town, key::available_recruits, str(unit_id));
		const int64_t weekly_growth = gd::to_int(state, state.get(overworld_rules::town_weekly_growth(state, town, dict_value(session)), str(unit_id), int_value(0)));
		const Atom unlock_building_id = _unlock_building_for_unit(state, town, unit_id);
		const DictRef unlock_building = gd::content_row(state, ContentTable::Building, unlock_building_id);
		const bool unlocked = _unit_is_unlocked_in_town(state, town, unit_id);
		// Future choices belong in Construction; retain old reserves in Muster.
		if (!unlocked && available <= 0) {
			continue;
		}
		Atom catalog_status = key::Locked;
		Atom status_detail = gd::format(state, key::build_s_to_unlock_this_unit, {str(gd::stringify(state, state.get(unlock_building, str(key::name), str(key::its_dwelling))))});
		if (unlocked && available <= 0) {
			catalog_status = key::Empty;
			status_detail = gd::format(state, key::no_recruits_are_waiting_weekly_growth, {int_value(weekly_growth)});
		} else if (!gd::is_empty(state, action) && gd::int_field(state, action, key::direct_affordable_count, 0) > 0) {
			catalog_status = key::Ready;
			status_detail = gd::format(state, key::d_available_d_can_be_recruited, {int_value(available), int_value(gd::int_field(state, action, key::direct_affordable_count, 0))});
		} else if (!gd::is_empty(state, action) && gd::int_field(state, action, key::market_affordable_count, 0) > 0) {
			catalog_status = key::Trade;
			status_detail = gd::stringify(state, state.get(action, str(key::market_summary), str(key::trade_can_fund_this_muster)));
		} else if (unlocked) {
			catalog_status = key::Resources;
			status_detail = gd::stringify(state, state.get(action, str(key::disabled_reason), str(key::current_stores_cannot_fund_this_muster)));
		}
		const DictRef unit_cost = overworld_rules::town_recruit_cost(state, session, town, unit_id);
		const DictRef art = gd::content_row(state, ContentTable::UnitArt, unit_id);
		const DictRef fields = state.new_dict();
		state.set(fields, str(key::id), str(gd::format(state, key::recruit_s, {str(unit_id)})));
		state.set(fields, str(key::unit_id), str(unit_id));
		state.set(fields, str(key::name), str(gd::stringify(state, state.get(unit, str(key::name), str(unit_id)))));
		state.set(fields, str(key::label), str(gd::format(state, key::recruit_s_2, {str(gd::stringify(state, state.get(unit, str(key::name), str(unit_id))))})));
		state.set(fields, str(key::unit_tier), int_value(gd::int_field(state, unit, key::tier, 0)));
		state.set(fields, str(key::tier_label), str(_unit_tier_label(state, gd::int_field(state, unit, key::tier, 0))));
		state.set(fields, str(key::role), str(gd::stringify(state, state.get(unit, str(key::role), str(key::empty)))));
		state.set(fields, str(key::unit_cost), gd::engine_duplicate(state, dict_value(unit_cost), true));
		state.set(fields, str(key::available_count), int_value(available));
		state.set(fields, str(key::weekly_growth), int_value(weekly_growth));
		state.set(fields, str(key::unlock_building_id), str(unlock_building_id));
		state.set(fields, str(key::unlock_building_name), str(gd::stringify(state, state.get(unlock_building, str(key::name), str(unlock_building_id)))));
		state.set(fields, str(key::portrait_path), str(gd::stringify(state, state.get(art, str(key::portrait), str(key::empty)))));
		state.set(fields, str(key::catalog_status), str(catalog_status));
		state.set(fields, str(key::catalog_status_detail), str(status_detail));
		state.set(fields, str(key::unlocked), bool_value(unlocked));
		state.set(fields, str(key::action_available), bool_value(!gd::is_empty(state, action)));
		state.set(fields, str(key::disabled), bool_value(gd::is_empty(state, action) || gd::bool_field(state, action, key::disabled, false)));
		state.set(fields, str(key::disabled_reason), str(gd::is_empty(state, action) ? status_detail : gd::stringify(state, state.get(action, str(key::disabled_reason), str(key::empty)))));
		gd::merge(state, row, fields, true);
		state.append(catalog, dict_value(row));
	}
	gd::sort_custom(state, catalog, [&state](const Value &left, const Value &right) {
		return _muster_catalog_row_less(state, gd::as_dict(left), gd::as_dict(right));
	});
	_read_cache_store(state, session, key::muster_catalog, array_value(catalog));
	return catalog;
}

bool _muster_catalog_row_less(State &state, DictRef left, DictRef right) {
	const int64_t left_tier = gd::int_field(state, left, key::unit_tier, 0);
	const int64_t right_tier = gd::int_field(state, right, key::unit_tier, 0);
	if (left_tier != right_tier) {
		return left_tier < right_tier;
	}
	const Atom left_name = gd::stringify(state, state.get(left, str(key::name), str(key::empty)));
	const Atom right_name = gd::stringify(state, state.get(right, str(key::name), str(key::empty)));
	return state.text(left_name) < state.text(right_name);
}

DictRef recruit_active_town(State &state, DictRef session, Atom unit_id, int64_t requested_count, bool runtime_normalized) {
	return overworld_rules::recruit_in_active_town(state, session, unit_id, requested_count, runtime_normalized);
}

Atom _recruit_choice_impact_line(State &state, Atom unit_id, int64_t ready_count, int64_t available_count) {
	const int64_t field_count = compat::engine_max<int64_t>(0, ready_count);
	if (field_count <= 0) {
		return key::defense_frontier_reserves_are_waiting_but;
	}
	const int64_t strength = overworld_rules::unit_stack_strength_value(state, unit_id, field_count);
	return gd::format(state, key::defense_frontier_adds_strength_d_to, {
			int_value(strength),
			int_value(compat::engine_max<int64_t>(0, gd::sub(available_count, field_count))),
	});
}

Atom _recruit_action_badge(State &state, int64_t ready_count, int64_t market_count) {
	if (ready_count > 0) {
		return gd::format(state, key::ready_x_d, {int_value(ready_count)});
	}
	if (market_count > 0) {
		return gd::format(state, key::trade_x_d, {int_value(market_count)});
	}
	return key::Blocked;
}

Atom _unit_tier_label(State &state, int64_t unit_tier) {
	if (unit_tier <= 0) {
		return key::tier_2;
	}
	return gd::format(state, key::tier_d, {int_value(unit_tier)});
}

Atom _cost_shortfall_line(State &state, DictRef readiness) {
	const Atom shortfall_summary = _describe_resources(state, field_or_new_dict(state, readiness, key::direct_shortfall), key::empty);
	const int64_t gold_short = compat::engine_max<int64_t>(
			0,
			gd::sub(gd::int_field(state, readiness, key::required_gold_total, 0), gd::int_field(state, readiness, key::available_gold_total, 0)));
	if (shortfall_summary != key::empty) {
		if (gd::bool_field(state, readiness, key::market_active, false) && gold_short > 0) {
			return gd::format(state, key::need_s_and_even_a_full, {str(shortfall_summary), int_value(gold_short)});
		}
		return gd::format(state, key::need_s_2, {str(shortfall_summary)});
	}
	if (gold_short > 0) {
		if (gd::bool_field(state, readiness, key::market_active, false)) {
			return gd::format(state, key::even_a_full_exchange_leaves_d, {int_value(gold_short)});
		}
		return gd::format(state, key::need_d_more_gold, {int_value(gold_short)});
	}
	return key::stores_are_too_thin;
}

Atom _cost_readiness_line(State &state, DictRef resources, const Value &cost, DictRef readiness) {
	if (!gd::is_dict(cost) || gd::is_empty(state, cost.ref)) {
		return key::ready_no_resource_cost;
	}
	const Atom stock_line = _stock_against_cost_line(state, resources, cost);
	if (gd::bool_field(state, readiness, key::direct_affordable, false)) {
		return gd::format(state, key::ready_stores_cover_s, {str(stock_line)});
	}
	if (gd::bool_field(state, readiness, key::market_affordable, false) && gd::bool_field(state, readiness, key::market_active, false)) {
		return gd::format(state, key::needs_exchange_stores_show_s, {str(stock_line)});
	}
	const Atom shortfall = _cost_shortfall_line(state, readiness);
	return gd::format(state, key::blocked_s_2, {str(shortfall)});
}

Atom _stock_against_cost_line(State &state, DictRef resources, const Value &cost) {
	if (!gd::is_dict(cost) || gd::is_empty(state, cost.ref)) {
		return key::no_cost;
	}
	std::vector<Atom> parts;
	const ArrayRef resource_keys = _resource_keys_for_payload(state, cost);
	for (const Value &resource_key : gd::items(state, array_value(resource_keys))) {
		const int64_t required = gd::to_int(state, state.get(cost.ref, resource_key, int_value(0)));
		if (required <= 0) {
			continue;
		}
		parts.push_back(gd::format(state, key::s_d_d_3, {
				resource_key,
				int_value(gd::to_int(state, state.get(resources, resource_key, int_value(0)))),
				int_value(required),
		}));
	}
	return !parts.empty() ? join_atoms(state, key::comma_space, parts) : static_cast<Atom>(key::no_cost);
}

Atom _stores_after_cost_line(State &state, DictRef resources, const Value &cost) {
	if (!gd::is_dict(cost)) {
		return key::empty;
	}
	const DictRef after = state.new_dict();
	const ArrayRef resource_keys = _resource_keys_for_payload(state, cost);
	for (const Value &resource_key : gd::items(state, array_value(resource_keys))) {
		const int64_t held = gd::to_int(state, state.get(resources, resource_key, int_value(0)));
		const int64_t spent = gd::to_int(state, state.get(cost.ref, resource_key, int_value(0)));
		state.set(after, resource_key, int_value(compat::engine_max<int64_t>(0, gd::sub(held, spent))));
	}
	return _describe_resources(state, dict_value(after), key::none);
}

Atom _recruit_affordability_label(State &state, int64_t direct_count, int64_t market_count, Atom shortfall_summary) {
	if (direct_count > 0) {
		return gd::format(state, key::ready_now_x_d, {int_value(direct_count)});
	}
	if (market_count > 0) {
		return gd::format(state, key::needs_exchange_x_d, {int_value(market_count)});
	}
	if (shortfall_summary != key::empty) {
		return gd::format(state, key::blocked_s, {str(shortfall_summary)});
	}
	return key::blocked_stores_are_too_thin;
}

Atom _disabled_reason_line(State &state, bool ready, bool market_coverable, Atom market_summary, Atom shortfall_summary) {
	if (ready) {
		return key::empty;
	}
	if (market_coverable && market_summary != key::empty) {
		return gd::format(state, key::use_exchange_first_s, {str(market_summary)});
	}
	if (shortfall_summary != key::empty) {
		return gd::format(state, key::blocked_s, {str(shortfall_summary)});
	}
	return key::blocked_stores_are_too_thin;
}

DictRef _multiply_resource_cost(State &state, const Value &cost, int64_t multiplier) {
	const DictRef scaled = state.new_dict();
	if (gd::is_dict(cost)) {
		const ArrayRef cost_keys = gd::keys(state, cost.ref);
		for (const Value &cost_key : gd::items(state, array_value(cost_keys))) {
			state.set(scaled, str(gd::stringify(state, cost_key)), int_value(gd::mul(gd::to_int(state, gd::index(state, cost.ref, cost_key)), multiplier)));
		}
	}
	return scaled;
}

int64_t _max_affordable_count(State &state, DictRef session, const Value &unit_cost) {
	if (!gd::is_dict(unit_cost) || gd::is_empty(state, unit_cost.ref)) {
		return 999;
	}
	// session.overworld.get("resources", {}): read only, a missing one holds nothing.
	Value resources;
	const bool has_resources = state.lookup(session_view::overworld(state, session), str(key::resources), resources);
	int64_t max_affordable = 999;
	const ArrayRef cost_keys = gd::keys(state, unit_cost.ref);
	for (const Value &cost_key : gd::items(state, array_value(cost_keys))) {
		const int64_t price = compat::engine_max<int64_t>(1, gd::to_int(state, gd::index(state, unit_cost.ref, cost_key)));
		const Value held = has_resources ? ai::vget(state, resources, str(gd::stringify(state, cost_key)), int_value(0)) : int_value(0);
		max_affordable = compat::engine_min<int64_t>(max_affordable, compat::int_div(gd::to_int(state, held), price));
	}
	return max_affordable;
}

ArrayRef _town_unit_ids(State &state, DictRef town) {
	const ArrayRef unit_ids = state.new_array();
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	std::vector<Atom> building_ids;
	for (const Value &building_id_value : gd::field_items(state, town_template, str(key::starting_building_ids))) {
		building_ids.push_back(gd::stringify(state, building_id_value));
	}
	for (const Value &building_id_value : gd::field_items(state, town_template, str(key::buildable_building_ids))) {
		building_ids.push_back(gd::stringify(state, building_id_value));
	}
	for (const Atom building_id : building_ids) {
		const Atom unlock_unit_id = ai::string_or_empty(state, gd::content_row(state, ContentTable::Building, building_id), key::unlock_unit_id);
		if (unlock_unit_id != key::empty && !gd::array_has(state, unit_ids, str(unlock_unit_id))) {
			state.append(unit_ids, str(unlock_unit_id));
		}
	}
	// town.get("available_recruits", {}).keys(): a missing one has no keys.
	Value available_recruits;
	if (state.lookup(town, str(key::available_recruits), available_recruits)) {
		for (const Value &unit_id_value : gd::items(state, dict_value(gd::as_dict(available_recruits)))) {
			const Atom unit_id = gd::stringify(state, unit_id_value);
			if (unit_id != key::empty && !gd::array_has(state, unit_ids, str(unit_id))) {
				state.append(unit_ids, str(unit_id));
			}
		}
	}
	const DictRef growth = overworld_rules::town_weekly_growth(state, town, Value());
	for (const Value &unit_id_value : gd::items(state, dict_value(growth))) {
		const Atom unit_id = gd::stringify(state, unit_id_value);
		if (unit_id != key::empty && !gd::array_has(state, unit_ids, str(unit_id))) {
			state.append(unit_ids, str(unit_id));
		}
	}
	return unit_ids;
}

bool _unit_is_unlocked_in_town(State &state, DictRef town, Atom unit_id) {
	return gd::to_int(state, state.get(overworld_rules::town_weekly_growth(state, town, Value()), str(unit_id), int_value(0))) > 0;
}

Atom _unlock_building_for_unit(State &state, DictRef town, Atom unit_id) {
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	std::vector<Atom> building_ids;
	for (const Value &building_id_value : gd::field_items(state, town_template, str(key::starting_building_ids))) {
		building_ids.push_back(gd::stringify(state, building_id_value));
	}
	for (const Value &building_id_value : gd::field_items(state, town_template, str(key::buildable_building_ids))) {
		building_ids.push_back(gd::stringify(state, building_id_value));
	}
	for (const Atom building_id : building_ids) {
		if (ai::string_or_empty(state, gd::content_row(state, ContentTable::Building, building_id), key::unlock_unit_id) == unit_id) {
			return building_id;
		}
	}
	return key::empty;
}

} // namespace town_rules

} // namespace aurelion::rules::port
