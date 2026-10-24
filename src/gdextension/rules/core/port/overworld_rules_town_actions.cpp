// OverworldRules for the human seat's town actions from the map (Phase 7, slice
// 7.3): building and recruiting in the visited town, their costs, discounts and
// the market's cover. HeroCommandRules.town_recruitment_destination and
// HeroProgressionRules.scale_recruit_cost are here too.

#include "aurelion_rules/port/overworld_rules_context.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/hero_progression_rules_turn.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/scenario_factory_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/town_development_rules.hpp"
#include "aurelion_rules/port/town_development_rules_turn.hpp"

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

// LIVE_STOCKPILE_RESOURCE_KEYS and MARKET_RESOURCE_KEYS.
constexpr Atom kLiveStockpileKeys[] = {key::gold, key::wood, key::ore, key::aetherglass, key::embergrain, key::peatwax, key::verdant_grafts, key::brass_scrip, key::memory_salt};
constexpr Atom kMarketKeys[] = {key::wood, key::ore, key::aetherglass, key::embergrain, key::peatwax, key::verdant_grafts, key::brass_scrip, key::memory_salt};

// HeroCommandRules.ARMY_SLOT_COUNT.
constexpr int64_t kArmySlotCount = 7;

// x in NORMAL_MARKET_RESOURCE_KEYS of a String.
bool is_normal_market_key(Atom resource_key) {
	return resource_key == key::wood || resource_key == key::ore;
}

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

// "%+d" % value: Godot's sign flag puts "+" before a value that is not negative.
Atom signed_int_text(State &state, int64_t value) {
	return gd::format(state, value < 0 ? key::d_text : key::plus_d_text, {int_value(value)});
}

// int(d.get(field, {}).get(entry, 0)), read only.
int64_t nested_int(State &state, DictRef dict, Atom field, Atom entry) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return 0;
	}
	return gd::to_int(state, ai::vget(state, found, entry, int_value(0)));
}

// value in d.get(field, []), read only.
bool in_field(State &state, DictRef dict, Atom field, Atom value) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return false;
	}
	return gd::in(state, str(value), found);
}

// a.sort() of an Array that holds only Strings (code point order).
void sort_strings(State &state, ArrayRef array) {
	gd::sort_custom(state, array, [&state](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
}

// {"market_usage": usage}, the town a cap check reads.
DictRef usage_town(State &state, DictRef usage) {
	const DictRef town = state.new_dict();
	state.set(town, str(key::market_usage), dict_value(usage));
	return town;
}

// towns[index] = town.
void set_town_at(State &state, const Value &towns, int64_t index, const Value &town) {
	if (gd::is_dict(towns)) {
		state.set(towns.ref, int_value(index), town);
		return;
	}
	state.set_at(gd::as_array(towns), index, town);
}

} // namespace

namespace overworld_rules {

int64_t _scenario_unit_growth(State &state, Atom unit_id) {
	return scenario_factory::_unit_growth(state, unit_id);
}

DictRef build_in_active_town(State &state, DictRef session, Atom building_id) {
	normalize_overworld_state(state, session);
	const DictRef town_result = _find_active_town(state, session);
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return refusal(state, key::no_town_is_available_for_construction);
	}

	const Value towns = field_or_new_array(state, session_view::overworld(state, session), key::towns);
	const DictRef town = gd::as_dict(field_or_new_dict(state, town_result, key::town));
	if (gd::stringify(state, state.get(town, str(key::owner), str(key::neutral))) != key::player) {
		return refusal(state, key::capture_the_town_before_issuing_orders);
	}

	const DictRef build_status = get_town_build_status(state, town, building_id, -1);
	if (town_built_today(state, town, ai::session_int(state, session, key::day))) {
		return refusal(state, key::this_town_has_already_completed_a);
	}
	if (!gd::to_bool(state.get(build_status, str(key::buildable), bool_value(false)))) {
		return refusal(state, gd::stringify(state, state.get(build_status, str(key::blocked_message), str(key::that_building_is_not_available_in))));
	}

	const DictRef building = gd::as_dict(field_or_new_dict(state, build_status, key::building));
	const Value cost = field_or_new_dict(state, building, key::cost);
	if (!_can_afford(state, session, cost)) {
		const DictRef pool = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::resources));
		const DictRef readiness = town_cost_readiness(state, town, pool, cost, ai::session_int(state, session, key::day));
		const Atom shortfall = _describe_cost_shortfall(state, readiness);
		const Atom building_name = gd::stringify(state, state.get(building, str(key::name), str(building_id)));
		const Atom missing = shortfall != key::empty ? gd::format(state, key::missing_s_3, {str(shortfall)}) : key::empty;
		return refusal(state, gd::format(state, key::insufficient_resources_for_s_s, {str(building_name), str(missing)}));
	}

	const DictRef income_before = _calculate_town_income(state, town, dict_value(session));
	const DictRef growth_before = town_weekly_growth(state, town, dict_value(session));
	_spend_resources(state, session, cost);
	const ArrayRef built_buildings = _normalize_built_buildings_for_town_state(state, town);
	state.append(built_buildings, str(building_id));
	state.set(town, str(key::built_buildings), array_value(built_buildings));
	town_development_rules::migrate_town(state, town);
	state.set(town, str(key::last_build_day), int_value(ai::session_int(state, session, key::day)));
	// town.get("available_recruits", {}): only read, so a missing one adds as {} does (as null).
	const Value base_recruits = state.get(town, str(key::available_recruits), Value());
	const DictRef scaling_hero = _town_scaling_hero(state, session, town);
	const DictRef growth_payload = _building_growth_payload(state, building_id);
	const DictRef scaled_growth = hero_progression_rules::scale_recruit_growth(state, scaling_hero, dict_value(growth_payload));
	state.set(town, str(key::available_recruits), dict_value(_add_recruit_growth(state, base_recruits, dict_value(scaled_growth))));
	set_town_at(state, towns, gd::int_field(state, town_result, key::index, -1), dict_value(town));
	state.set(session_view::overworld(state, session), str(key::towns), towns);
	const DictRef income_after = _calculate_town_income(state, town, dict_value(session));
	const DictRef growth_after = town_weekly_growth(state, town, dict_value(session));
	std::vector<Atom> message_parts;
	const Atom built_name = gd::stringify(state, state.get(building, str(key::name), str(building_id)));
	message_parts.push_back(gd::format(state, key::built_s_in_s, {str(built_name), str(_town_name(state, town))}));
	if (gd::int_field(state, building, key::spell_tier, 0) > 0) {
		_teach_visiting_town_spells(state, session, town);
	}
	const Atom cost_summary = _describe_resource_delta(state, cost);
	if (cost_summary != key::empty) {
		message_parts.push_back(gd::format(state, key::spent_s, {str(cost_summary)}));
	}
	const Atom income_change = _describe_resource_change(state, dict_value(income_before), dict_value(income_after));
	if (income_change != key::empty) {
		const Atom income_summary = _describe_resource_delta(state, dict_value(income_after));
		message_parts.push_back(gd::format(state, key::daily_income_now_s_s, {str(income_summary), str(income_change)}));
	}
	const Atom growth_change = _describe_recruit_projection(state, dict_value(growth_before), dict_value(growth_after));
	if (growth_change != key::empty) {
		message_parts.push_back(gd::format(state, key::weekly_muster_s, {str(growth_change)}));
	}
	return _finalize_action_result(state, session, true, join_atoms(state, key::space, message_parts), true, false, state.new_dict());
}

DictRef recruit_in_active_town(State &state, DictRef session, Atom unit_id, int64_t requested_count, bool runtime_normalized) {
	if (runtime_normalized) {
		normalize_overworld_state_for_runtime(state, session);
	} else {
		normalize_overworld_state(state, session);
	}
	const DictRef town_result = _find_active_town(state, session);
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return refusal(state, key::no_town_is_available_for_recruitment);
	}

	const Value towns = field_or_new_array(state, session_view::overworld(state, session), key::towns);
	const DictRef town = gd::as_dict(field_or_new_dict(state, town_result, key::town));
	if (gd::stringify(state, state.get(town, str(key::owner), str(key::neutral))) != key::player) {
		return refusal(state, key::recruitment_requires_control_of_the_town);
	}

	const Value recruits = field_or_new_dict(state, town, key::available_recruits);
	const int64_t available_count = gd::to_int(state, ai::vget(state, recruits, unit_id, int_value(0)));
	if (available_count <= 0) {
		return refusal(state, key::no_recruits_are_waiting_for_that);
	}

	const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
	const DictRef adjusted_unit_cost = town_recruit_cost(state, session, town, unit_id);
	const int64_t max_affordable = _max_affordable_count(state, session, dict_value(adjusted_unit_cost));
	int64_t recruit_count = requested_count <= 0 ? available_count : compat::engine_min<int64_t>(requested_count, available_count);
	recruit_count = compat::engine_min<int64_t>(recruit_count, max_affordable);
	if (recruit_count <= 0) {
		const DictRef pool = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::resources));
		const DictRef readiness = town_cost_readiness(state, town, pool, dict_value(adjusted_unit_cost), ai::session_int(state, session, key::day));
		const Atom shortfall = _describe_cost_shortfall(state, readiness);
		const Atom unit_name = gd::stringify(state, state.get(unit, str(key::name), str(unit_id)));
		const Atom missing = shortfall != key::empty ? gd::format(state, key::missing_s_3, {str(shortfall)}) : key::empty;
		return refusal(state, gd::format(state, key::resources_are_too_thin_to_recruit, {str(unit_name), str(missing)}));
	}

	const DictRef recruit_cost = _multiply_cost(state, dict_value(adjusted_unit_cost), recruit_count);
	const DictRef destination = hero_command_rules::town_recruitment_destination(state, session, town);
	const DictRef additions = state.new_dict();
	state.set(additions, str(unit_id), int_value(recruit_count));
	const DictRef admission = hero_command_rules::army_addition_plan(state, state.get(destination, str(key::stacks), Value()), additions);
	if (!gd::to_bool(state.get(admission, str(key::ok), bool_value(false)))) {
		const Value label = gd::index(state, destination, str(key::label));
		const Atom refused = gd::stringify(state, state.get(admission, str(key::message), str(key::formation_full)));
		state.set(admission, str(key::message), str(gd::format(state, key::s_colon_s_text, {label, str(refused)})));
		return admission;
	}
	_spend_resources(state, session, dict_value(recruit_cost));
	state.set(gd::as_dict(recruits), str(unit_id), int_value(gd::sub(available_count, recruit_count)));
	state.set(town, str(key::available_recruits), recruits);
	set_town_at(state, towns, gd::int_field(state, town_result, key::index, -1), dict_value(town));
	state.set(session_view::overworld(state, session), str(key::towns), towns);

	const ArrayRef stacks = gd::as_array(field_or_new_array(state, admission, key::stacks));
	hero_command_rules::_set_holder_stacks(state, session, town, gd::stringify(state, gd::index(state, destination, str(key::holder_id))), stacks);
	const int64_t field_total = _army_unit_count(state, array_value(stacks), unit_id);
	std::vector<Atom> message_parts;
	const Atom unit_name = gd::stringify(state, state.get(unit, str(key::name), str(unit_id)));
	message_parts.push_back(gd::format(state, key::recruited_d_s, {int_value(recruit_count), str(unit_name)}));
	const Atom cost_summary = _describe_resource_delta(state, dict_value(recruit_cost));
	if (cost_summary != key::empty) {
		message_parts.push_back(gd::format(state, key::spent_s, {str(cost_summary)}));
	}
	const Atom destination_label = gd::stringify(state, gd::index(state, destination, str(key::label)));
	const int64_t remaining = compat::engine_max<int64_t>(0, gd::to_int(state, ai::vget(state, recruits, unit_id, int_value(0))));
	message_parts.push_back(gd::format(state, key::arrived_immediately_in_s_d_remain, {str(destination_label), int_value(remaining), int_value(field_total)}));
	return _finalize_action_result(state, session, true, join_atoms(state, key::space, message_parts), true, false, state.new_dict());
}

bool town_built_today(State &state, DictRef town, int64_t day) {
	return day > 0 && gd::int_field(state, town, key::last_build_day, 0) == day;
}

DictRef town_cost_readiness(State &state, DictRef town, DictRef pool, const Value &cost, int64_t current_day) {
	const DictRef readiness = _town_market_cost_coverage(state, town, pool, cost, current_day);
	ArrayRef market_actions = state.new_array();
	if (gd::to_bool(state.get(readiness, str(key::market_affordable), bool_value(false)))) {
		const DictRef simulated_pool = gd::as_dict(gd::engine_duplicate(state, field_or_new_dict(state, readiness, key::pool), true));
		const DictRef simulated_town = gd::as_dict(gd::engine_duplicate(state, dict_value(town), true));
		market_actions = _apply_market_cost_coverage(state, simulated_town, simulated_pool, field_or_new_dict(state, readiness, key::cost), current_day);
	}
	state.set(readiness, str(key::market_actions), array_value(market_actions));
	return readiness;
}

DictRef town_recruit_cost(State &state, DictRef session, DictRef town, Atom unit_id) {
	const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
	const DictRef scaling_hero = _town_scaling_hero(state, session, town);
	// unit.get("cost", {}): only read, so a missing cost scales as {} does (as null).
	const DictRef adjusted_cost = hero_progression_rules::scale_recruit_cost(state, scaling_hero, state.get(unit, str(key::cost), Value()));
	return _apply_percent_discount(state, dict_value(adjusted_cost), _recruitment_discount_percent(state, town, unit_id));
}

ArrayRef _market_buy_resources(State &state, DictRef market_state) {
	const ArrayRef result = state.new_array();
	if (gd::to_bool(state.get(market_state, str(key::active), bool_value(false)))) {
		for (const Atom resource_key : kMarketKeys) {
			state.append(result, str(resource_key));
		}
	}
	return result;
}

DictRef _town_market_cost_coverage(State &state, DictRef town, DictRef pool, const Value &cost, int64_t current_day) {
	const DictRef market = _town_market_state(state, town);
	const DictRef pool_base = _empty_live_resource_stockpile(state);
	const DictRef normalized_pool = _add_resource_sets(state, dict_value(pool_base), dict_value(_normalize_resource_dict(state, dict_value(pool))));
	const DictRef cost_base = _empty_live_resource_stockpile(state);
	const DictRef normalized_cost = _add_resource_sets(state, dict_value(cost_base), dict_value(_normalize_resource_dict(state, cost)));
	const bool direct_affordable = _resource_pool_meets_cost(state, normalized_pool, normalized_cost);
	const bool market_active = gd::to_bool(state.get(market, str(key::active), bool_value(false)));
	const DictRef direct_shortfall = _resource_pool_shortfall(state, normalized_pool, normalized_cost);
	if (!gd::to_bool(state.get(market, str(key::active), bool_value(false)))) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::affordable), bool_value(direct_affordable));
		state.set(result, str(key::direct_affordable), bool_value(direct_affordable));
		state.set(result, str(key::market_affordable), bool_value(direct_affordable));
		state.set(result, str(key::market_active), bool_value(market_active));
		state.set(result, str(key::pool), dict_value(normalized_pool));
		state.set(result, str(key::cost), dict_value(normalized_cost));
		state.set(result, str(key::direct_shortfall), dict_value(direct_shortfall));
		state.set(result, str(key::liquidatable_gold), int_value(0));
		state.set(result, str(key::available_gold_total), int_value(gd::int_field(state, normalized_pool, key::gold, 0)));
		state.set(result, str(key::required_gold_total), int_value(gd::int_field(state, normalized_cost, key::gold, 0)));
		return result;
	}
	int64_t required_gold_total = gd::int_field(state, normalized_cost, key::gold, 0);
	int64_t liquidatable_gold = 0;
	const ArrayRef market_cap_blockers = state.new_array();
	const ArrayRef restricted_resource_blockers = state.new_array();
	const ArrayRef buy_resources = _market_buy_resources(state, market);
	for (const Value &resource_value : gd::items(state, array_value(buy_resources))) {
		const Atom resource_key = gd::to_string(resource_value);
		const int64_t required_amount = gd::int_field(state, normalized_cost, resource_key, 0);
		const int64_t current_amount = gd::int_field(state, normalized_pool, resource_key, 0);
		const int64_t deficit = compat::engine_max<int64_t>(0, gd::sub(required_amount, current_amount));
		const int64_t surplus = compat::engine_max<int64_t>(0, gd::sub(current_amount, required_amount));
		if (deficit > 0) {
			const DictRef buy_quote = _market_quote_from_state(state, market, key::buy, resource_key, deficit);
			const DictRef buy_cap = _market_cap_state_for_quote(state, town, market, buy_quote, current_day);
			const int64_t buy_remaining = gd::int_field(state, buy_cap, key::remaining, deficit);
			if ((current_day > 0 || in_field(state, market, key::rare_resources, resource_key)) && buy_remaining < deficit) {
				state.append(market_cap_blockers, str(gd::format(state, key::buy_s_d_d, {str(resource_key), int_value(buy_remaining), int_value(deficit)})));
			} else {
				required_gold_total = gd::add(required_gold_total, gd::mul(deficit, nested_int(state, market, key::buy_rates, resource_key)));
			}
		}
		if (surplus > 0 && is_normal_market_key(resource_key)) {
			const DictRef sell_quote = _market_quote_from_state(state, market, key::sell, resource_key, surplus);
			const DictRef sell_cap = _market_cap_state_for_quote(state, town, market, sell_quote, current_day);
			const int64_t sell_remaining = gd::int_field(state, sell_cap, key::remaining, surplus);
			const int64_t sellable_surplus = current_day <= 0 ? surplus : compat::engine_min<int64_t>(surplus, sell_remaining);
			liquidatable_gold = gd::add(liquidatable_gold, gd::mul(sellable_surplus, nested_int(state, market, key::sell_rates, resource_key)));
		}
	}
	for (const Atom resource_key : kLiveStockpileKeys) {
		if (resource_key == key::gold || gd::array_has(state, buy_resources, str(resource_key))) {
			continue;
		}
		const int64_t restricted_deficit = compat::engine_max<int64_t>(0, gd::sub(gd::int_field(state, normalized_cost, resource_key, 0), gd::int_field(state, normalized_pool, resource_key, 0)));
		if (restricted_deficit > 0) {
			state.append(restricted_resource_blockers, str(gd::format(state, key::s_d_6, {str(resource_key), int_value(restricted_deficit)})));
		}
	}
	const int64_t available_gold_total = gd::add(gd::int_field(state, normalized_pool, key::gold, 0), liquidatable_gold);
	const bool market_affordable = available_gold_total >= required_gold_total
			&& state.array_size(market_cap_blockers) == 0
			&& state.array_size(restricted_resource_blockers) == 0;
	const DictRef result = state.new_dict();
	state.set(result, str(key::affordable), bool_value(market_affordable));
	state.set(result, str(key::direct_affordable), bool_value(direct_affordable));
	state.set(result, str(key::market_affordable), bool_value(market_affordable));
	state.set(result, str(key::market_active), bool_value(market_active));
	state.set(result, str(key::pool), dict_value(normalized_pool));
	state.set(result, str(key::cost), dict_value(normalized_cost));
	state.set(result, str(key::direct_shortfall), dict_value(direct_shortfall));
	state.set(result, str(key::liquidatable_gold), int_value(liquidatable_gold));
	state.set(result, str(key::available_gold_total), int_value(available_gold_total));
	state.set(result, str(key::required_gold_total), int_value(required_gold_total));
	state.set(result, str(key::market_cap_blockers), array_value(market_cap_blockers));
	state.set(result, str(key::restricted_resource_blockers), array_value(restricted_resource_blockers));
	return result;
}

ArrayRef _apply_market_cost_coverage(State &state, DictRef town, DictRef pool, const Value &cost, int64_t current_day) {
	const DictRef coverage = _town_market_cost_coverage(state, town, pool, cost, current_day);
	if (!gd::to_bool(state.get(coverage, str(key::affordable), bool_value(false)))) {
		return state.new_array();
	}
	const DictRef market = _town_market_state(state, town);
	if (!gd::to_bool(state.get(market, str(key::active), bool_value(false)))) {
		return state.new_array();
	}
	const DictRef normalized_cost = gd::as_dict(field_or_new_dict(state, coverage, key::cost));
	const int64_t required_gold_total = gd::int_field(state, coverage, key::required_gold_total, 0);
	const ArrayRef actions = state.new_array();
	// town.get("market_usage", {}): a missing usage normalizes as {} does (as null).
	const DictRef local_usage = _normalize_town_market_usage_state(state, gd::field(state, town, key::market_usage), current_day);
	const ArrayRef sell_order = state.new_array();
	state.append(sell_order, str(key::wood));
	state.append(sell_order, str(key::ore));
	gd::sort_custom(state, sell_order, [&state, market](const Value &a, const Value &b) {
		return nested_int(state, market, key::sell_rates, gd::to_string(a)) > nested_int(state, market, key::sell_rates, gd::to_string(b));
	});
	for (const Value &resource_value : gd::items(state, array_value(sell_order))) {
		const Atom resource_key = gd::to_string(resource_value);
		int64_t surplus = compat::engine_max<int64_t>(0, gd::sub(gd::int_field(state, pool, resource_key, 0), gd::int_field(state, normalized_cost, resource_key, 0)));
		while (gd::int_field(state, pool, key::gold, 0) < required_gold_total && surplus > 0) {
			const DictRef sell_quote = _market_quote_from_state(state, market, key::sell, resource_key, 1);
			if (gd::is_empty(state, sell_quote)) {
				break;
			}
			if (current_day > 0) {
				const DictRef sell_cap = _market_cap_state_for_quote(state, usage_town(state, local_usage), market, sell_quote, current_day);
				if (gd::int_field(state, sell_cap, key::remaining, 0) <= 0) {
					break;
				}
			}
			_apply_resource_transaction_to_pool(state, pool, gd::field(state, sell_quote, key::cost), gd::field(state, sell_quote, key::gain));
			if (current_day > 0) {
				const DictRef sell_bucket = gd::as_dict(field_or_new_dict(state, local_usage, key::sell));
				state.set(sell_bucket, str(resource_key), int_value(gd::add(gd::int_field(state, sell_bucket, resource_key, 0), 1)));
				state.set(local_usage, str(key::sell), dict_value(sell_bucket));
			}
			surplus -= 1;
			const Atom town_name = _town_name(state, town);
			state.append(actions, str(gd::format(state, key::s_sold_1_s_for_d, {str(town_name), str(resource_key), int_value(gd::int_field(state, sell_quote, key::gold_value, 0))})));
		}
		if (gd::int_field(state, pool, key::gold, 0) >= required_gold_total) {
			break;
		}
	}
	const ArrayRef buy_resources = _market_buy_resources(state, market);
	for (const Value &resource_value : gd::items(state, array_value(buy_resources))) {
		const Atom resource_key = gd::to_string(resource_value);
		int64_t deficit = compat::engine_max<int64_t>(0, gd::sub(gd::int_field(state, normalized_cost, resource_key, 0), gd::int_field(state, pool, resource_key, 0)));
		while (deficit > 0) {
			const DictRef buy_quote = _market_quote_from_state(state, market, key::buy, resource_key, 1);
			if (gd::is_empty(state, buy_quote) || gd::int_field(state, pool, key::gold, 0) < gd::int_field(state, buy_quote, key::gold_value, 0)) {
				return actions;
			}
			if (current_day > 0 || in_field(state, market, key::rare_resources, resource_key)) {
				const DictRef buy_cap = _market_cap_state_for_quote(state, usage_town(state, local_usage), market, buy_quote, current_day);
				if (gd::int_field(state, buy_cap, key::remaining, 0) <= 0) {
					return actions;
				}
			}
			_apply_resource_transaction_to_pool(state, pool, gd::field(state, buy_quote, key::cost), gd::field(state, buy_quote, key::gain));
			if (current_day > 0 || in_field(state, market, key::rare_resources, resource_key)) {
				const DictRef buy_bucket = gd::as_dict(field_or_new_dict(state, local_usage, key::buy));
				state.set(buy_bucket, str(resource_key), int_value(gd::add(gd::int_field(state, buy_bucket, resource_key, 0), 1)));
				state.set(local_usage, str(key::buy), dict_value(buy_bucket));
			}
			deficit -= 1;
			const Atom town_name = _town_name(state, town);
			state.append(actions, str(gd::format(state, key::s_bought_1_s_for_d, {str(town_name), str(resource_key), int_value(gd::int_field(state, buy_quote, key::gold_value, 0))})));
		}
	}
	if (state.array_size(actions) != 0) {
		bool write_usage = current_day > 0;
		if (!write_usage) {
			// not state.get("rare_resources", []).is_empty()
			Value rare_resources;
			write_usage = state.lookup(market, str(key::rare_resources), rare_resources) && !ai::vempty(state, rare_resources);
		}
		if (write_usage) {
			state.set(town, str(key::market_usage), dict_value(local_usage));
		}
	}
	return actions;
}

DictRef _building_growth_payload(State &state, Atom building_id) {
	const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
	if (gd::int_field(state, building, key::development_version, 0) == 1) {
		return town_development_rules::construction_growth(state, building);
	}
	const DictRef payload = state.new_dict();
	const Atom unlock_unit_id = ai::string_or_empty(state, building, key::unlock_unit_id);
	if (unlock_unit_id != key::empty) {
		state.set(payload, str(unlock_unit_id), int_value(_scenario_unit_growth(state, unlock_unit_id)));
	}
	// building.get("growth_bonus", {}): a missing bonus adds nothing, as {} does.
	const Value growth_bonus = gd::field(state, building, key::growth_bonus);
	if (gd::is_dict(growth_bonus)) {
		for (const Value &unit_id : gd::items(state, array_value(gd::keys(state, growth_bonus.ref)))) {
			const Value id = str(gd::stringify(state, unit_id));
			const int64_t held = gd::to_int(state, state.get(payload, id, int_value(0)));
			state.set(payload, id, int_value(gd::add(held, gd::to_int(state, gd::index(state, growth_bonus.ref, unit_id)))));
		}
	}
	return payload;
}

int64_t _max_affordable_count(State &state, DictRef session, const Value &unit_cost) {
	if (!gd::is_dict(unit_cost) || gd::is_empty(state, unit_cost.ref)) {
		return 999;
	}
	// session.overworld.get("resources", {}): read only, a missing one holds nothing.
	Value resources;
	const bool has_resources = state.lookup(session_view::overworld(state, session), str(key::resources), resources);
	int64_t max_affordable = 999;
	for (const Value &cost_key : gd::items(state, array_value(gd::keys(state, unit_cost.ref)))) {
		const int64_t price = compat::engine_max<int64_t>(1, gd::to_int(state, gd::index(state, unit_cost.ref, cost_key)));
		const Value held = has_resources ? ai::vget(state, resources, str(gd::stringify(state, cost_key)), int_value(0)) : int_value(0);
		max_affordable = compat::engine_min<int64_t>(max_affordable, compat::int_div(gd::to_int(state, held), price));
	}
	return max_affordable;
}

bool _resource_pool_meets_cost(State &state, DictRef pool, DictRef cost) {
	for (const Value &resource_key : gd::items(state, array_value(_resource_keys_for_payload(state, dict_value(cost))))) {
		if (gd::to_int(state, state.get(pool, resource_key, int_value(0))) < gd::to_int(state, state.get(cost, resource_key, int_value(0)))) {
			return false;
		}
	}
	return true;
}

DictRef _resource_pool_shortfall(State &state, DictRef pool, DictRef cost) {
	const DictRef shortfall = state.new_dict();
	for (const Value &resource_key : gd::items(state, array_value(_resource_keys_for_payload(state, dict_value(cost))))) {
		const int64_t needed = gd::to_int(state, state.get(cost, resource_key, int_value(0)));
		const int64_t held = gd::to_int(state, state.get(pool, resource_key, int_value(0)));
		const int64_t missing = compat::engine_max<int64_t>(0, gd::sub(needed, held));
		if (missing > 0) {
			state.set(shortfall, resource_key, int_value(missing));
		}
	}
	return shortfall;
}

DictRef _apply_percent_discount(State &state, const Value &cost, int64_t discount_percent) {
	const DictRef discounted = state.new_dict();
	const int64_t clamped_discount = compat::engine_clamp<int64_t>(discount_percent, 0, 75);
	if (gd::is_dict(cost)) {
		for (const Value &cost_key : gd::items(state, array_value(gd::keys(state, cost.ref)))) {
			const Atom resource_key = gd::stringify(state, cost_key);
			const int64_t base_amount = compat::engine_max<int64_t>(0, gd::to_int(state, gd::index(state, cost.ref, cost_key)));
			const double scaled = static_cast<double>(gd::mul(base_amount, gd::sub(100, clamped_discount))) / 100.0;
			state.set(discounted, str(resource_key), int_value(compat::float_to_int(compat::godot_ceil(scaled))));
		}
	}
	return discounted;
}

int64_t _recruitment_discount_percent(State &state, DictRef town, Atom unit_id) {
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	// x.get("recruitment", {}): a missing profile gives no discount, as {} does.
	int64_t total_discount = _cost_discount_from_profile(state, gd::field(state, town_template, key::recruitment), unit_id);
	const DictRef faction = gd::content_row(state, ContentTable::Faction, ai::string_or_empty(state, town_template, key::faction_id));
	total_discount = gd::add(total_discount, _cost_discount_from_profile(state, gd::field(state, faction, key::recruitment), unit_id));
	for (const Value &building_id_value : gd::items(state, array_value(_normalize_built_buildings_for_town_state(state, town)))) {
		const DictRef building = gd::content_row(state, ContentTable::Building, gd::stringify(state, building_id_value));
		const Value building_discount = gd::field(state, building, key::recruitment_discount_percent);
		if (gd::is_dict(building_discount)) {
			total_discount = gd::add(total_discount, gd::int_field(state, building_discount.ref, unit_id, 0));
		}
	}
	return total_discount;
}

int64_t _cost_discount_from_profile(State &state, const Value &profile, Atom unit_id) {
	if (!gd::is_dict(profile)) {
		return 0;
	}
	// profile.get("cost_discount_percent", {}): a missing one gives 0, as {} does.
	const Value discounts = gd::field(state, profile.ref, key::cost_discount_percent);
	if (!gd::is_dict(discounts)) {
		return 0;
	}
	return gd::int_field(state, discounts.ref, unit_id, 0);
}

void _apply_resource_transaction_to_pool(State &state, DictRef pool, const Value &cost, const Value &gain) {
	if (gd::is_dict(cost)) {
		// cost.keys() is a copy: the pool may be the cost itself.
		const ArrayRef cost_keys = gd::keys(state, cost.ref);
		for (int64_t index = 0; index < state.array_size(cost_keys); ++index) {
			const Value cost_key = state.at(cost_keys, index);
			const Value resource_key = str(gd::stringify(state, cost_key));
			const int64_t held = gd::to_int(state, state.get(pool, resource_key, int_value(0)));
			const int64_t spent = gd::to_int(state, gd::index(state, cost.ref, cost_key));
			state.set(pool, resource_key, int_value(compat::engine_max<int64_t>(0, gd::sub(held, spent))));
		}
	}
	if (gd::is_dict(gain)) {
		const ArrayRef gain_keys = gd::keys(state, gain.ref);
		for (int64_t index = 0; index < state.array_size(gain_keys); ++index) {
			const Value gain_key = state.at(gain_keys, index);
			const Atom resource_text = gd::stringify(state, gain_key);
			if (resource_text == key::experience) {
				continue;
			}
			const Value resource_key = str(resource_text);
			const int64_t held = gd::to_int(state, state.get(pool, resource_key, int_value(0)));
			const int64_t gained = gd::to_int(state, gd::index(state, gain.ref, gain_key));
			state.set(pool, resource_key, int_value(compat::engine_max<int64_t>(0, gd::add(held, gained))));
		}
	}
}

Atom resource_icon_path(State &state, Atom resource_id) {
	const DictRef resource = resource_definition(state, resource_id);
	if (ai::string_or_empty(state, resource, key::icon_id) != gd::format(state, key::resource_icon_s, {str(resource_id)})) {
		return key::empty;
	}
	const Atom icon_path = ai::string_or_empty(state, resource, key::icon_path);
	if (!gd::begins_with(state, icon_path, key::res_art_economy_runtime_resources) || !gd::resource_exists(state, icon_path)) {
		return key::empty;
	}
	return icon_path;
}

Atom _describe_resource_change(State &state, const Value &before, const Value &after) {
	if (!gd::is_dict(after)) {
		return key::empty;
	}
	std::vector<Atom> parts;
	for (const Value &resource_key : gd::items(state, array_value(_resource_keys_for_payload(state, after)))) {
		const int64_t previous = gd::is_dict(before) ? gd::to_int(state, state.get(before.ref, resource_key, int_value(0))) : 0;
		const int64_t current = gd::to_int(state, state.get(after.ref, resource_key, int_value(0)));
		const int64_t delta = gd::sub(current, previous);
		if (delta != 0) {
			parts.push_back(gd::format(state, key::s_s, {str(signed_int_text(state, delta)), resource_key}));
		}
	}
	return join_atoms(state, key::comma_space, parts);
}

Atom _describe_cost_shortfall(State &state, DictRef readiness) {
	// readiness.get("direct_shortfall", {}): a missing one describes as {} does.
	const Atom shortfall_summary = _describe_resource_delta(state, gd::field(state, readiness, key::direct_shortfall));
	const int64_t gold_short = compat::engine_max<int64_t>(0, gd::sub(gd::int_field(state, readiness, key::required_gold_total, 0), gd::int_field(state, readiness, key::available_gold_total, 0)));
	if (shortfall_summary != key::empty) {
		if (gd::to_bool(state.get(readiness, str(key::market_active), bool_value(false))) && gold_short > 0) {
			return gd::format(state, key::s_even_full_exchange_leaves_d, {str(shortfall_summary), int_value(gold_short)});
		}
		return shortfall_summary;
	}
	if (gold_short > 0) {
		return gd::to_bool(state.get(readiness, str(key::market_active), bool_value(false)))
				? gd::format(state, key::d_gold_after_exchange, {int_value(gold_short)})
				: gd::format(state, key::d_gold, {int_value(gold_short)});
	}
	return key::empty;
}

Atom _describe_recruit_projection(State &state, const Value &current, const Value &projected) {
	if (!gd::is_dict(projected)) {
		return key::empty;
	}
	const ArrayRef unit_ids = state.new_array();
	if (gd::is_dict(current)) {
		for (const Value &unit_id_value : gd::items(state, array_value(gd::keys(state, current.ref)))) {
			const Atom unit_id = gd::stringify(state, unit_id_value);
			if (unit_id != key::empty && !gd::array_has(state, unit_ids, str(unit_id))) {
				state.append(unit_ids, str(unit_id));
			}
		}
	}
	for (const Value &unit_id_value : gd::items(state, array_value(gd::keys(state, projected.ref)))) {
		const Atom unit_id = gd::stringify(state, unit_id_value);
		if (unit_id != key::empty && !gd::array_has(state, unit_ids, str(unit_id))) {
			state.append(unit_ids, str(unit_id));
		}
	}
	sort_strings(state, unit_ids);
	std::vector<Atom> parts;
	for (const Value &unit_id_value : gd::items(state, array_value(unit_ids))) {
		const Atom unit_id = gd::to_string(unit_id_value);
		const int64_t before = gd::is_dict(current) ? gd::to_int(state, state.get(current.ref, str(unit_id), int_value(0))) : 0;
		const int64_t after = gd::to_int(state, state.get(projected.ref, str(unit_id), int_value(0)));
		const int64_t delta = gd::sub(after, before);
		if (delta == 0) {
			continue;
		}
		const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
		const Atom unit_name = gd::stringify(state, state.get(unit, str(key::name), str(unit_id)));
		parts.push_back(gd::format(state, key::s_s, {str(_describe_signed_int(state, delta)), str(unit_name)}));
	}
	return join_atoms(state, key::comma_space, parts);
}

Atom _describe_signed_int(State &state, int64_t value) {
	return signed_int_text(state, value);
}

} // namespace overworld_rules

namespace hero_command_rules {

DictRef town_recruitment_destination(State &state, DictRef session, DictRef town) {
	// Remote management is not hero presence. Share the entrance/level and
	// deterministic local-hero preference used by town defense.
	const DictRef hero = town_defending_hero(state, session, town);
	const Atom holder_id = gd::stringify(state, state.get(hero, str(key::id), str(key::garrison)));
	const Atom label = _holder_label(state, session, town, holder_id);
	const ArrayRef stacks = _holder_stacks(state, session, town, holder_id);
	int64_t occupied = 0;
	for (const Value &stack : gd::items(state, array_value(stacks))) {
		if (gd::is_dict(stack) && gd::int_field(state, stack.ref, key::count, 0) > 0) {
			occupied += 1;
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::holder_id), str(holder_id));
	state.set(result, str(key::label), str(label));
	state.set(result, str(key::stacks), array_value(stacks));
	state.set(result, str(key::summary), str(gd::format(state, key::destination_s_arrives_immediately_here_d, {str(label), int_value(occupied), int_value(kArmySlotCount)})));
	return result;
}

} // namespace hero_command_rules

namespace hero_progression_rules {

DictRef scale_recruit_cost(State &state, DictRef hero_state, const Value &cost_payload) {
	const DictRef bonuses = aggregate_bonuses(state, hero_state);
	const double multiplier = compat::engine_clamp<double>(1.0 + gd::to_float(state.get(bonuses, str(key::recruit_cost_delta), gd::float_value(0.0))), 0.5, 1.0);
	// Rounded up, so a small discount never halves a 2-resource T7 price.
	const DictRef scaled = state.new_dict();
	if (!gd::is_dict(cost_payload)) {
		return scaled;
	}
	for (const Value &cost_key : gd::items(state, array_value(gd::keys(state, cost_payload.ref)))) {
		const int64_t amount = gd::to_int(state, gd::index(state, cost_payload.ref, cost_key));
		if (amount > 0) {
			const double raised = static_cast<double>(amount) * multiplier - 0.0001;
			state.set(scaled, str(gd::stringify(state, cost_key)), int_value(compat::engine_max<int64_t>(1, compat::float_to_int(compat::godot_ceil(raised)))));
		}
	}
	return scaled;
}

} // namespace hero_progression_rules

} // namespace aurelion::rules::port
