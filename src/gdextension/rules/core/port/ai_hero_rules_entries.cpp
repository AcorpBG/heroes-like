// AiHeroRules: the computer heroes among the encounters, the guard index of
// sites and artifacts, recruit sets, build values and the town market trades.

#include "aurelion_rules/port/ai_hero_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/enemy_adventure_rules_ai.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/overworld_level_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/town_development_rules_ai.hpp"
#include "aurelion_rules/port/town_rules_ai.hpp"

#include <string>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::float_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;

// x.get(k, []) of an untyped value whose result is kept: a new Array when the
// key is missing.
Value vget_or_new_array(State &state, const Value &object, const Value &k) {
	if (gd::is_dict(object)) {
		Value found;
		return state.lookup(object.ref, k, found) ? found : array_value(state.new_array());
	}
	return ai::vget(state, object, k);
}

// [stack]
Value one_stack(State &state, const Value &stack) {
	const ArrayRef stacks = state.new_array();
	state.append(stacks, stack);
	return array_value(stacks);
}

// army_power(stacks) with its default commander {}.
double power_of(State &state, const Value &stacks) {
	return ai_hero_rules::army_power(state, stacks, dict_value(state.new_dict()));
}

// {resource: amount}
DictRef one_resource(State &state, Atom resource, int64_t amount) {
	const DictRef pool = state.new_dict();
	state.set(pool, str(resource), int_value(amount));
	return pool;
}

// float(OverworldRules.MARKET_RESOURCE_VALUES.get(resource, 0.0)).
double market_resource_value(Atom resource) {
	if (resource == key::wood || resource == key::ore) {
		return 400.0;
	}
	if (resource == key::aetherglass || resource == key::embergrain || resource == key::peatwax || resource == key::verdant_grafts || resource == key::brass_scrip || resource == key::memory_salt) {
		return 800.0;
	}
	return 0.0;
}

// d.get(k, {}) if d.get(k, {}) is Dictionary else {}, kept: a new one unless
// the key holds a Dictionary.
DictRef dict_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// int(entry.get("x", -1)) == int(entrance.get("x", -2)) and the same for y.
bool at_entrance(State &state, DictRef entry, DictRef entrance) {
	return gd::int_field(state, entry, key::x, -1) == gd::int_field(state, entrance, key::x, -2) && gd::int_field(state, entry, key::y, -1) == gd::int_field(state, entrance, key::y, -2);
}

} // namespace

namespace ai_hero_rules {

int64_t _entry_index(State &state, DictRef session, Atom placement_id) {
	Value found;
	if (!state.lookup(session_view::overworld(state, session), str(key::encounters), found)) {
		return -1;
	}
	const ArrayRef encounters = gd::as_array(found);
	const int64_t count = state.array_size(encounters);
	for (int64_t index = 0; index < count; ++index) {
		const Value entry = state.at(encounters, index);
		if (gd::is_dict(entry) && ai::string_or_empty(state, entry.ref, key::placement_id) == placement_id) {
			return index;
		}
	}
	return -1;
}

int64_t _movement_max(State &state, DictRef entry) {
	Value found;
	const DictRef commander = state.lookup(entry, str(key::enemy_commander_state), found) && gd::is_dict(found) ? found.ref : state.new_dict();
	const DictRef hero = gd::duplicate_dict(state, commander);
	if (!state.has(hero, str(key::base_movement))) {
		const DictRef row = gd::content_row(state, ContentTable::Hero, ai::string_or_empty(state, commander, key::roster_hero_id));
		state.set(hero, str(key::base_movement), int_value(gd::int_field(state, row, key::base_movement, 10)));
	}
	return hero_command_rules::movement_max_for_hero(state, hero, str(key::normal));
}

bool _resource_guarded(State &state, DictRef session, DictRef node, DictRef site) {
	Value resolved;
	const int64_t resolved_size = state.lookup(session_view::overworld(state, session), str(key::resolved_encounters), resolved) ? ai::vsize(state, resolved) : 0;
	const Value cache_key = str(gd::format(state, key::d_s, {int_value(resolved_size), str(ai::string_or_empty(state, node, key::placement_id))}));
	if (!state.has(ai::static_dict(state, key::ai_hero_rules_script, key::_guard_cache), cache_key)) {
		const DictRef index = _encounter_guard_index(state, session);
		const ArrayRef lists = state.new_array();
		state.append(lists, vget_or_new_array(state, gd::index(state, index, str(key::by_placement)), str(ai::string_or_empty(state, node, key::guard_front_id))));
		state.append(lists, vget_or_new_array(state, gd::index(state, index, str(key::by_site_target)), str(ai::string_or_empty(state, node, key::placement_id))));
		const Value site_id = state.get(site, str(key::id), state.get(node, str(key::site_id), str(key::empty)));
		state.append(lists, vget_or_new_array(state, gd::index(state, index, str(key::by_site_target)), str(gd::stringify(state, site_id))));
		const ArrayRef positions = _guard_positions(state, lists);
		const bool guarded = !gd::is_empty(state, overworld_rules::resource_site_blocking_guard(state, session, node, site, array_value(positions)));
		state.set(ai::static_dict(state, key::ai_hero_rules_script, key::_guard_cache), cache_key, bool_value(guarded));
	}
	return gd::to_bool(gd::index(state, ai::static_dict(state, key::ai_hero_rules_script, key::_guard_cache), cache_key));
}

DictRef _artifact_guard(State &state, DictRef session, DictRef node) {
	const DictRef index = _encounter_guard_index(state, session);
	const ArrayRef lists = state.new_array();
	state.append(lists, vget_or_new_array(state, gd::index(state, index, str(key::by_artifact_target)), str(ai::string_or_empty(state, node, key::placement_id))));
	state.append(lists, vget_or_new_array(state, gd::index(state, index, str(key::by_artifact_target)), str(ai::string_or_empty(state, node, key::artifact_id))));
	const ArrayRef positions = _guard_positions(state, lists);
	return enemy_adventure_rules::_artifact_guard_encounter_for_node(state, session, node, array_value(positions));
}

DictRef _encounter_guard_index(State &state, DictRef session) {
	Value found;
	const ArrayRef encounters = state.lookup(session_view::overworld(state, session), str(key::encounters), found) ? gd::as_array(found) : state.new_array();
	const DictRef cached = ai::static_dict(state, key::ai_hero_rules_script, key::_guard_index);
	if (!gd::is_empty(state, cached) && gd::is_same(state, gd::index(state, cached, str(key::encounters)), array_value(encounters)) && gd::to_int(state, gd::index(state, cached, str(key::size))) == state.array_size(encounters)) {
		return cached;
	}
	const DictRef by_placement = state.new_dict();
	const DictRef by_site_target = state.new_dict();
	const DictRef by_artifact_target = state.new_dict();
	const int64_t count = state.array_size(encounters);
	for (int64_t position = 0; position < count; ++position) {
		const Value encounter = state.at(encounters, position);
		if (!gd::is_dict(encounter)) {
			continue;
		}
		_add_guard_position(state, by_placement, ai::string_or_empty(state, encounter.ref, key::placement_id), position);
		const DictRef site_link = overworld_rules::_resource_site_guard_link_for_encounter(state, encounter.ref);
		if (!gd::is_empty(state, site_link)) {
			_add_guard_position(state, by_site_target, ai::string_or_empty(state, site_link, key::target_placement_id), position);
			_add_guard_position(state, by_site_target, ai::string_or_empty(state, site_link, key::target_id), position);
		}
		const DictRef artifact_link = enemy_adventure_rules::_guard_link_for_encounter(state, encounter.ref);
		if (!gd::is_empty(state, artifact_link)) {
			_add_guard_position(state, by_artifact_target, ai::string_or_empty(state, artifact_link, key::target_placement_id), position);
			_add_guard_position(state, by_artifact_target, ai::string_or_empty(state, artifact_link, key::target_id), position);
		}
		_add_guard_position(state, by_artifact_target, ai::string_or_empty(state, encounter.ref, key::guarded_object_placement_id), position);
	}
	const DictRef index = state.new_dict();
	state.set(index, str(key::encounters), array_value(encounters));
	state.set(index, str(key::size), int_value(state.array_size(encounters)));
	state.set(index, str(key::by_placement), dict_value(by_placement));
	state.set(index, str(key::by_site_target), dict_value(by_site_target));
	state.set(index, str(key::by_artifact_target), dict_value(by_artifact_target));
	gd::set_static_var(state, key::ai_hero_rules_script, key::_guard_index, dict_value(index));
	return ai::static_dict(state, key::ai_hero_rules_script, key::_guard_index);
}

void _add_guard_position(State &state, DictRef lookup, Atom lookup_key, int64_t position) {
	if (lookup_key == key::empty) {
		return;
	}
	const Value k = str(lookup_key);
	Value list;
	if (!state.lookup(lookup, k, list)) {
		const ArrayRef made = state.new_array();
		state.append(made, int_value(position));
		state.set(lookup, k, array_value(made));
		return;
	}
	if (!gd::is_array(list)) {
		throw state::NotPorted("AiHeroRules._add_guard_position: a lookup entry that is not an Array");
	}
	if (gd::to_int(state, ai::array_back(state, list.ref)) != position) {
		state.append(list.ref, int_value(position));
	}
}

ArrayRef _guard_positions(State &state, ArrayRef lists) {
	const ArrayRef positions = state.new_array();
	const int64_t list_count = state.array_size(lists);
	for (int64_t index = 0; index < list_count; ++index) {
		ai::append_array(state, positions, gd::as_array(state.at(lists, index)));
	}
	if (state.array_size(positions) < 2) {
		return positions;
	}
	gd::sort_custom(state, positions, [](const Value &x, const Value &y) { return gd::op_less(x, y); });
	const ArrayRef unique = state.new_array();
	state.append(unique, state.at(positions, 0));
	const int64_t count = state.array_size(positions);
	for (int64_t index = 0; index < count; ++index) {
		const Value position = state.at(positions, index);
		if (gd::to_int(state, position) != gd::to_int(state, ai::array_back(state, unique))) {
			state.append(unique, position);
		}
	}
	return unique;
}

DictRef _trial_growth(State &state, DictRef town) {
	if (town_development_rules::is_current(state, town)) {
		return town_development_rules::growth(state, town);
	}
	return overworld_rules::_seed_recruits_for_town(state, town);
}

DictRef _recruit_dict(State &state, const Value &value) {
	const DictRef result = state.new_dict();
	if (gd::is_dict(value)) {
		const ArrayRef unit_ids = gd::keys(state, value.ref);
		const int64_t count = state.array_size(unit_ids);
		for (int64_t index = 0; index < count; ++index) {
			const Value unit_id = state.at(unit_ids, index);
			if (gd::to_int(state, gd::index(state, value.ref, unit_id)) > 0) {
				state.set(result, str(gd::stringify(state, unit_id)), int_value(gd::to_int(state, gd::index(state, value.ref, unit_id))));
			}
		}
	}
	return result;
}

double _recruit_set_value(State &state, DictRef recruits) {
	double value = 0.0;
	const ArrayRef unit_ids = gd::keys(state, recruits);
	const int64_t count = state.array_size(unit_ids);
	for (int64_t index = 0; index < count; ++index) {
		const Value unit_id = state.at(unit_ids, index);
		const DictRef stack = state.new_dict();
		state.set(stack, str(key::unit_id), str(gd::stringify(state, unit_id)));
		state.set(stack, str(key::count), int_value(gd::to_int(state, gd::index(state, recruits, unit_id))));
		const double power = power_of(state, one_stack(state, dict_value(stack)));
		const double troops = power * ai::static_float(state, key::ai_hero_rules_script, key::TROOP_VALUE_PER_POWER);
		value = value + troops;
	}
	return value;
}

double _build_value(State &state, DictRef payload) {
	double value = 0.0;
	const ArrayRef resource_keys = gd::keys(state, payload);
	const int64_t count = state.array_size(resource_keys);
	for (int64_t index = 0; index < count; ++index) {
		const Value resource_key = state.at(resource_keys, index);
		const Value amount_value = gd::index(state, payload, resource_key);
		const double amount = gd::is_int(amount_value) || gd::is_float(amount_value) ? gd::to_float(amount_value) : 0.0;
		const Atom resource = gd::stringify(state, resource_key);
		const double rate = resource == key::gold ? 1.0 : market_resource_value(resource);
		const double worth = amount * rate;
		value = value + worth;
	}
	return value;
}

bool _market_cover(State &state, DictRef session, DictRef town, DictRef pool, DictRef cost, bool apply, const Value &market_memo) {
	if (_can_afford(state, pool, cost)) {
		return true;
	}
	const bool memo_is_dict = gd::is_dict(market_memo);
	DictRef market = 0;
	bool have_market = false;
	if (memo_is_dict) {
		Value found;
		if (state.lookup(market_memo.ref, str(key::market), found)) {
			market = gd::as_dict(found);
			have_market = !gd::is_empty(state, market);
		}
	}
	if (!have_market) {
		market = overworld_rules::town_market_state(state, town);
		if (memo_is_dict) {
			state.set(market_memo.ref, str(key::market), dict_value(market));
		}
	}
	if (!gd::bool_field(state, market, key::active, false)) {
		return false;
	}
	Value usage_source;
	if (!state.lookup(town, str(key::market_usage), usage_source)) {
		usage_source = dict_value(state.new_dict());
	}
	const DictRef usage = gd::deep_duplicate_dict(state, overworld_rules::_normalize_town_market_usage_state(state, usage_source, ai::session_int(state, session, key::day)));
	const DictRef stock = gd::duplicate_dict(state, pool);
	const ArrayRef tradable = town_rules::market_resource_ids(state, market);
	const ArrayRef sources = state.new_array();
	// OverworldRules.NORMAL_MARKET_RESOURCE_KEYS
	for (const Atom resource_id : {key::wood, key::ore}) {
		if (gd::array_has(state, tradable, str(resource_id))) {
			state.append(sources, str(resource_id));
		}
	}
	const int64_t tradable_count = state.array_size(tradable);
	for (int64_t index = 0; index < tradable_count; ++index) {
		const Atom resource_id = gd::stringify(state, state.at(tradable, index));
		if (!gd::array_has(state, sources, str(resource_id))) {
			state.append(sources, str(resource_id));
		}
	}
	const ArrayRef cost_keys = gd::keys(state, cost);
	const int64_t cost_count = state.array_size(cost_keys);
	for (int64_t cost_index = 0; cost_index < cost_count; ++cost_index) {
		const Atom resource_key = gd::stringify(state, state.at(cost_keys, cost_index));
		if (resource_key == key::gold) {
			continue;
		}
		int64_t deficit = gd::sub(gd::to_int(state, gd::index(state, cost, str(resource_key))), gd::int_field(state, stock, resource_key, 0));
		if (deficit <= 0) {
			continue;
		}
		if (gd::array_has(state, tradable, str(resource_key))) {
			const int64_t source_count = state.array_size(sources);
			for (int64_t source_index = 0; source_index < source_count; ++source_index) {
				const Atom other = gd::stringify(state, state.at(sources, source_index));
				const int64_t spare = gd::sub(gd::int_field(state, stock, other, 0), gd::int_field(state, cost, other, 0));
				if (other == resource_key || spare <= 0 || deficit <= 0) {
					continue;
				}
				const DictRef terms = town_rules::market_trade_quote(state, market, usage, one_resource(state, other, spare), other, resource_key, 1, false);
				const int64_t count = compat::engine_min<int64_t>(deficit, gd::int_field(state, terms, key::max_amount, 0));
				if (count > 0 && _market_trade(state, town_rules::market_trade_quote(state, market, usage, one_resource(state, other, spare), other, resource_key, count, false), stock, usage)) {
					deficit = gd::sub(deficit, count);
				}
			}
		}
		if (deficit > 0 && gd::array_has(state, tradable, str(resource_key))) {
			const int64_t spare_gold = compat::engine_max<int64_t>(0, gd::sub(gd::int_field(state, stock, key::gold, 0), gd::int_field(state, cost, key::gold, 0)));
			if (!_market_trade(state, town_rules::market_trade_quote(state, market, usage, one_resource(state, key::gold, spare_gold), key::gold, resource_key, deficit, false), stock, usage)) {
				return false;
			}
			deficit = 0;
		}
		if (deficit > 0) {
			return false;
		}
	}
	int64_t gold_deficit = gd::sub(gd::int_field(state, cost, key::gold, 0), gd::int_field(state, stock, key::gold, 0));
	const int64_t source_count = state.array_size(sources);
	for (int64_t source_index = 0; source_index < source_count; ++source_index) {
		if (gold_deficit <= 0) {
			break;
		}
		const Atom other = gd::stringify(state, state.at(sources, source_index));
		const int64_t spare = gd::sub(gd::int_field(state, stock, other, 0), gd::int_field(state, cost, other, 0));
		if (spare <= 0) {
			continue;
		}
		const DictRef terms = town_rules::market_trade_quote(state, market, usage, one_resource(state, other, spare), other, key::gold, 1, false);
		int64_t count = 0;
		// Every amount up to max_amount is a sale the quote allows, for the gold
		// market_sale_gold names.
		const int64_t end = gd::add(gd::int_field(state, terms, key::max_amount, 0), 1);
		for (int64_t amount = 1; amount < end; ++amount) {
			count = amount;
			if (town_rules::market_sale_gold(state, market, other, amount) >= gold_deficit) {
				break;
			}
		}
		if (count <= 0) {
			continue;
		}
		const DictRef sale = town_rules::market_trade_quote(state, market, usage, one_resource(state, other, spare), other, key::gold, count, false);
		if (_market_trade(state, sale, stock, usage)) {
			gold_deficit = gd::sub(gold_deficit, gd::int_field(state, sale, key::receive_amount, 0));
		}
	}
	if (!_can_afford(state, stock, cost)) {
		return false;
	}
	if (apply) {
		const ArrayRef stock_keys = gd::keys(state, stock);
		const int64_t stock_count = state.array_size(stock_keys);
		for (int64_t index = 0; index < stock_count; ++index) {
			const Value k = state.at(stock_keys, index);
			state.set(pool, k, gd::index(state, stock, k));
		}
		state.set(town, str(key::market_usage), dict_value(usage));
	}
	return true;
}

bool _market_trade(State &state, DictRef quote, DictRef stock, DictRef usage) {
	if (!gd::bool_field(state, quote, key::ok, false)) {
		return false;
	}
	const Atom give_id = ai::string_or_empty(state, quote, key::give_id);
	const Atom receive_id = ai::string_or_empty(state, quote, key::receive_id);
	const int64_t give_amount = gd::int_field(state, quote, key::give_amount, 0);
	const int64_t receive_amount = gd::int_field(state, quote, key::receive_amount, 0);
	state.set(stock, str(give_id), int_value(gd::sub(gd::int_field(state, stock, give_id, 0), give_amount)));
	state.set(stock, str(receive_id), int_value(gd::add(gd::int_field(state, stock, receive_id, 0), receive_amount)));
	const Atom mode = ai::string_or_empty(state, quote, key::mode);
	if (mode == key::sell || mode == key::convert) {
		const DictRef sold = dict_or_new(state, usage, key::sell);
		state.set(sold, str(give_id), int_value(gd::add(gd::int_field(state, sold, give_id, 0), give_amount)));
		state.set(usage, str(key::sell), dict_value(sold));
	}
	if (mode == key::buy || mode == key::convert) {
		const DictRef bought = dict_or_new(state, usage, key::buy);
		state.set(bought, str(receive_id), int_value(gd::add(gd::int_field(state, bought, receive_id, 0), receive_amount)));
		state.set(usage, str(key::buy), dict_value(bought));
	}
	return true;
}

int64_t _town_hero_defender_index(State &state, DictRef session, DictRef town, Atom controller) {
	const DictRef entrance = level_rules::town_entrance(state, town);
	const DictRef resolved = _resolved_lookup(state, session);
	Value found;
	if (!state.lookup(session_view::overworld(state, session), str(key::encounters), found)) {
		return -1;
	}
	const ArrayRef encounters = gd::as_array(found);
	const int64_t count = state.array_size(encounters);
	for (int64_t index = 0; index < count; ++index) {
		const Value entry = state.at(encounters, index);
		if (!gd::is_dict(entry) || !is_ai_hero(state, entry) || state.has(resolved, str(ai::string_or_empty(state, entry.ref, key::placement_id)))) {
			continue;
		}
		const Atom other = player_identity_rules::raid_controller_id(state, entry.ref);
		if (other == controller || player_identity_rules::allied(state, dict_value(session), controller, other)) {
			continue;
		}
		if (level_rules::same_level(state, entry, dict_value(entrance)) && at_entrance(state, entry.ref, entrance)) {
			return index;
		}
	}
	return -1;
}

bool _town_entrance_free(State &state, DictRef session, DictRef town, Atom own_controller) {
	const DictRef entrance = level_rules::town_entrance(state, town);
	const DictRef resolved = _resolved_lookup(state, session);
	for (const Value &entry : gd::field_items(state, session_view::overworld(state, session), str(key::encounters))) {
		if (gd::is_dict(entry) && !state.has(resolved, str(ai::string_or_empty(state, entry.ref, key::placement_id))) && level_rules::same_level(state, entry, dict_value(entrance)) && at_entrance(state, entry.ref, entrance)) {
			if (own_controller != key::empty && is_ai_hero(state, entry) && player_identity_rules::raid_controller_id(state, entry.ref) == own_controller) {
				continue;
			}
			return false;
		}
	}
	for (const Value &hero : gd::field_items(state, session_view::overworld(state, session), str(key::player_heroes))) {
		Value found;
		const DictRef position = gd::is_dict(hero) && state.lookup(hero.ref, str(key::position), found) && gd::is_dict(found) ? found.ref : state.new_dict();
		if (level_rules::same_level(state, dict_value(position), dict_value(entrance)) && at_entrance(state, position, entrance)) {
			return false;
		}
	}
	return true;
}

DictRef _garrison_pickup(State &state, ArrayRef stacks, ArrayRef garrison) {
	const double before = power_of(state, array_value(stacks));
	const DictRef merged = _merge_stacks_into(state, array_value(stacks), array_value(garrison));
	const ArrayRef taken = gd::as_array(state.get(merged, str(key::stacks), array_value(stacks)));
	Value found;
	const ArrayRef left = state.lookup(merged, str(key::left), found) ? gd::as_array(found) : state.new_array();
	while (state.array_size(left) != 0 && state.array_size(taken) != 0) {
		int64_t strongest = 0;
		const int64_t left_count = state.array_size(left);
		for (int64_t index = 0; index < left_count; ++index) {
			const double power = power_of(state, one_stack(state, state.at(left, index)));
			if (power > power_of(state, one_stack(state, state.at(left, strongest)))) {
				strongest = index;
			}
		}
		const int64_t weakest = _weakest_stack_index(state, taken);
		const double strong = power_of(state, one_stack(state, state.at(left, strongest)));
		if (strong <= power_of(state, one_stack(state, state.at(taken, weakest)))) {
			break;
		}
		const DictRef swapped = gd::as_dict(state.at(taken, weakest));
		state.set_at(taken, weakest, state.at(left, strongest));
		state.set_at(left, strongest, dict_value(swapped));
	}
	const double after = power_of(state, array_value(taken));
	const DictRef result = state.new_dict();
	state.set(result, str(key::stacks), array_value(taken));
	state.set(result, str(key::left), array_value(left));
	state.set(result, str(key::gain), float_value(after - before));
	return result;
}

bool _ferries_from(State &state, DictRef session, DictRef context, DictRef town, Atom main_id) {
	if (main_id == key::empty || _town_threatened(state, session, context, town)) {
		return false;
	}
	const int64_t main_index = _entry_index(state, session, main_id);
	if (main_index < 0) {
		return false;
	}
	const Value encounters = gd::index(state, session_view::overworld(state, session), str(key::encounters));
	const DictRef main = gd::as_dict(ai::vindex(state, encounters, int_value(main_index)));
	if (!level_rules::same_level(state, dict_value(main), dict_value(town))) {
		return true;
	}
	const DictRef entrance = level_rules::town_entrance(state, town);
	const int64_t dx = compat::absi(gd::sub(gd::int_field(state, main, key::x, 0), gd::int_field(state, entrance, key::x, 0)));
	const int64_t dy = compat::absi(gd::sub(gd::int_field(state, main, key::y, 0), gd::int_field(state, entrance, key::y, 0)));
	const int64_t distance = compat::engine_max<int64_t>(dx, dy);
	// main.get(AI_HERO_KEY, {}).get("movement", {}).get("max", 0): the fallbacks are only read.
	const Value empty = dict_value(state.new_dict());
	const Value block = state.get(main, str(key::ai_hero), empty);
	const Value movement = ai::vget(state, block, key::movement, empty);
	return distance > gd::to_int(state, ai::vget(state, movement, key::max, int_value(0)));
}

} // namespace ai_hero_rules

} // namespace aurelion::rules::port
