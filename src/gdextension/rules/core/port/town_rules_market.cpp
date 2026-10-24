// TownRules for the human seat's market (Phase 7, slice 7.6): the market
// actions, the desk and the conversion.

#include "aurelion_rules/port/town_rules_actions.hpp"

#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/town_rules_ai.hpp"

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
using state::State;
using state::Value;
namespace key = state::key;

// OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS and NORMAL_MARKET_RESOURCE_KEYS.
constexpr Atom kLiveStockpileKeys[] = {key::gold, key::wood, key::ore, key::aetherglass, key::embergrain, key::peatwax, key::verdant_grafts, key::brass_scrip, key::memory_salt};
constexpr Atom kNormalMarketKeys[] = {key::wood, key::ore};

// x in NORMAL_MARKET_RESOURCE_KEYS of a String.
bool is_normal_market_key(Atom resource_id) {
	return resource_id == key::wood || resource_id == key::ore;
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

// int(s) of a String (String::to_int).
int64_t text_int(State &state, Atom text) {
	return compat::to_int(state.text(text));
}

// {"ok": false, "message": message}.
DictRef refusal(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

// session.overworld.get("resources", {}) if ... is Dictionary else {}.
DictRef session_stock(State &state, DictRef session) {
	Value found;
	if (state.lookup(session_view::overworld(state, session), str(key::resources), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// usage.get(field, {}) if usage.get(field, {}) is Dictionary else {}, stored back.
DictRef usage_bucket(State &state, DictRef usage, Atom field) {
	Value found;
	if (state.lookup(usage, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// "%s>%s" % [give_id, receive_id], a desk's pair key.
Atom pair_key(State &state, Atom give_id, Atom receive_id) {
	return gd::format(state, key::s_s_14, {str(give_id), str(receive_id)});
}

// int(pairs.get(pair, {}).get("max_amount", 0)), read only.
int64_t pair_max_amount(State &state, DictRef pairs, Atom pair) {
	Value found;
	if (!state.lookup(pairs, str(pair), found)) {
		return 0;
	}
	return gd::to_int(state, ai::vget(state, found, key::max_amount, int_value(0)));
}

// {"give": give_id, "receive": receive_id}.
DictRef suggestion(State &state, Atom give_id, Atom receive_id) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::give), str(give_id));
	state.set(result, str(key::receive), str(receive_id));
	return result;
}

} // namespace

namespace town_rules {

ArrayRef get_market_actions(State &state, DictRef session) {
	if (_read_cache_has(state, session, key::market_actions)) {
		return gd::as_array(_read_cache_get(state, session, key::market_actions));
	}
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		const ArrayRef empty = state.new_array();
		_read_cache_store(state, session, key::market_actions, array_value(empty));
		return empty;
	}
	const ArrayRef actions = overworld_rules::get_town_market_actions(state, session, town);
	_read_cache_store(state, session, key::market_actions, array_value(actions));
	return actions;
}

DictRef perform_market_action(State &state, DictRef session, Atom action_id) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return refusal(state, key::no_town_is_available_for_exchange);
	}
	const std::vector<Atom> parts = split_atoms(state, action_id, key::colon);
	if (parts.size() == 5 && parts[0] == key::market && parts[1] == key::convert) {
		return _perform_market_conversion(state, session, town, parts[2], parts[3], text_int(state, parts[4]));
	}
	return overworld_rules::perform_town_market_action(state, session, town, action_id);
}

DictRef market_desk(State &state, DictRef session, DictRef need) {
	// get_active_town(session) if session != null else {}: a view is never null.
	const DictRef town = get_active_town(state, session);
	const DictRef market = overworld_rules::town_market_state(state, town);
	const bool active = gd::bool_field(state, market, key::active, false) && gd::stringify(state, state.get(town, str(key::owner), str(key::neutral))) == key::player;
	const DictRef desk = state.new_dict();
	state.set(desk, str(key::active), bool_value(active));
	state.set(desk, str(key::building_id), str(ai::string_or_empty(state, market, key::building_id)));
	state.set(desk, str(key::building_name), str(ai::string_or_empty(state, market, key::building_name)));
	state.set(desk, str(key::tier), int_value(gd::int_field(state, market, key::tier, 0)));
	state.set(desk, str(key::give_ids), array_value(state.new_array()));
	state.set(desk, str(key::receive_ids), array_value(state.new_array()));
	state.set(desk, str(key::resources), dict_value(state.new_dict()));
	state.set(desk, str(key::pairs), dict_value(state.new_dict()));
	state.set(desk, str(key::reset_day), int_value(0));
	state.set(desk, str(key::suggested_give), str(key::empty));
	state.set(desk, str(key::suggested_receive), str(key::empty));
	if (!active) {
		return desk;
	}
	const int64_t day = gd::to_int(state, gd::field(state, session, key::day));
	// town.get("market_usage", {}): a missing usage normalizes as {} does (as null).
	const DictRef usage = overworld_rules::_normalize_town_market_usage_state(state, gd::field(state, town, key::market_usage), day);
	const DictRef stock = session_stock(state, session);
	const ArrayRef give_ids = state.new_array();
	state.append(give_ids, str(key::gold));
	ai::append_array(state, give_ids, market_resource_ids(state, market));
	const ArrayRef receive_ids = gd::duplicate_array(state, give_ids);
	const DictRef resources = state.new_dict();
	for (const Value &resource_id_value : gd::items(state, array_value(receive_ids))) {
		const Atom resource_id = gd::stringify(state, resource_id_value);
		const DictRef definition = overworld_rules::resource_definition(state, resource_id);
		const DictRef entry = state.new_dict();
		state.set(entry, str(key::id), str(resource_id));
		const Atom fallback_name = gd::capitalize(state, gd::replace(state, resource_id, key::_, key::space));
		state.set(entry, str(key::name), str(gd::stringify(state, state.get(definition, str(key::display_name), str(fallback_name)))));
		state.set(entry, str(key::icon_path), str(overworld_rules::resource_icon_path(state, resource_id)));
		state.set(entry, str(key::stock), int_value(gd::int_field(state, stock, resource_id, 0)));
		state.set(entry, str(key::rare), bool_value(!is_normal_market_key(resource_id)));
		state.set(resources, str(resource_id), dict_value(entry));
	}
	const DictRef pairs = state.new_dict();
	for (const Value &give_id_value : gd::items(state, array_value(give_ids))) {
		for (const Value &receive_id_value : gd::items(state, array_value(receive_ids))) {
			const Atom give_id = gd::stringify(state, give_id_value);
			const Atom receive_id = gd::stringify(state, receive_id_value);
			if (give_id == receive_id) {
				continue;
			}
			const DictRef terms = market_trade_quote(state, market, usage, stock, give_id, receive_id, 1);
			const ArrayRef quotes = state.new_array();
			const ArrayRef counts = _market_slider_counts(state, market, give_id, receive_id, gd::int_field(state, terms, key::max_amount, 0));
			for (const Value &count : gd::items(state, array_value(counts))) {
				const DictRef quote = market_trade_quote(state, market, usage, stock, give_id, receive_id, gd::to_int(state, count));
				const DictRef row = state.new_dict();
				state.set(row, str(key::amount), count);
				state.set(row, str(key::give_amount), int_value(gd::int_field(state, quote, key::give_amount, 0)));
				state.set(row, str(key::receive_amount), int_value(gd::int_field(state, quote, key::receive_amount, 0)));
				state.set(row, str(key::action_id), str(ai::string_or_empty(state, quote, key::action_id)));
				state.set(row, str(key::label), str(ai::string_or_empty(state, quote, key::label)));
				state.append(quotes, dict_value(row));
			}
			const DictRef pair = state.new_dict();
			state.set(pair, str(key::mode), str(ai::string_or_empty(state, terms, key::mode)));
			state.set(pair, str(key::max_amount), int_value(gd::int_field(state, terms, key::max_amount, 0)));
			state.set(pair, str(key::reason), str(gd::int_field(state, terms, key::max_amount, 0) <= 0 ? ai::string_or_empty(state, terms, key::reason) : key::empty));
			state.set(pair, str(key::rate_text), str(ai::string_or_empty(state, terms, key::rate_text)));
			state.set(pair, str(key::unit_text), str(ai::string_or_empty(state, terms, key::unit_text)));
			state.set(pair, str(key::limit_text), str(ai::string_or_empty(state, terms, key::limit_text)));
			state.set(pair, str(key::quotes), array_value(quotes));
			state.set(pairs, str(pair_key(state, give_id, receive_id)), dict_value(pair));
		}
	}
	state.set(desk, str(key::give_ids), array_value(give_ids));
	state.set(desk, str(key::receive_ids), array_value(receive_ids));
	state.set(desk, str(key::resources), dict_value(resources));
	state.set(desk, str(key::pairs), dict_value(pairs));
	state.set(desk, str(key::reset_day), int_value(gd::add(gd::mul(gd::int_field(state, usage, key::week, 1), 7), 1)));
	const DictRef suggested = _market_suggestion(state, pairs, stock, need);
	state.set(desk, str(key::suggested_give), str(gd::stringify(state, state.get(suggested, str(key::give), str(key::gold)))));
	state.set(desk, str(key::suggested_receive), str(gd::stringify(state, state.get(suggested, str(key::receive), str(key::wood)))));
	return desk;
}

ArrayRef _market_slider_counts(State &state, DictRef market, Atom give_id, Atom receive_id, int64_t max_amount) {
	const ArrayRef counts = state.new_array();
	const DictRef rate = market_conversion_rate(state, market, give_id, receive_id);
	const int64_t numerator = gd::int_field(state, rate, key::numerator, 0);
	const int64_t denominator = gd::int_field(state, rate, key::denominator, 0);
	if (numerator <= 0 || numerator >= denominator) {
		const int64_t end = gd::add(max_amount, 1);
		for (int64_t count = 1; count < end; ++count) {
			state.append(counts, int_value(count));
		}
		return counts;
	}
	int64_t given = 1;
	while (true) {
		const int64_t count = compat::int_div(gd::mul(given, denominator), numerator);
		if (count > max_amount) {
			break;
		}
		if (count >= 1 && (state.array_size(counts) == 0 || count > gd::to_int(state, state.at(counts, -1)))) {
			state.append(counts, int_value(count));
		}
		given = gd::add(given, 1);
	}
	return counts;
}

DictRef _market_suggestion(State &state, DictRef pairs, DictRef stock, DictRef need) {
	Atom short_id = key::empty;
	for (const Atom resource_id : kLiveStockpileKeys) {
		if (gd::int_field(state, need, resource_id, 0) > gd::int_field(state, stock, resource_id, 0)) {
			short_id = resource_id;
			if (short_id != key::gold) {
				break;
			}
		}
	}
	if (short_id != key::empty && short_id != key::gold) {
		const Atom buy_key = pair_key(state, key::gold, short_id);
		if (state.has(pairs, str(buy_key))) {
			if (gd::to_int(state, ai::vget(state, gd::index(state, pairs, str(buy_key)), key::max_amount, int_value(0))) > 0) {
				return suggestion(state, key::gold, short_id);
			}
			for (const Atom resource_id : kNormalMarketKeys) {
				if (pair_max_amount(state, pairs, pair_key(state, resource_id, short_id)) > 0) {
					return suggestion(state, resource_id, short_id);
				}
			}
			return suggestion(state, key::gold, short_id);
		}
	}
	if (short_id == key::gold) {
		Atom best = key::empty;
		for (const Atom resource_id : kNormalMarketKeys) {
			const int64_t sellable = pair_max_amount(state, pairs, pair_key(state, resource_id, key::gold));
			if (sellable > 0 && (best == key::empty || sellable > pair_max_amount(state, pairs, pair_key(state, best, key::gold)))) {
				best = resource_id;
			}
		}
		if (best != key::empty) {
			return suggestion(state, best, key::gold);
		}
	}
	return suggestion(state, key::gold, kNormalMarketKeys[0]);
}

DictRef _perform_market_conversion(State &state, DictRef session, DictRef town, Atom give_id, Atom receive_id, int64_t amount) {
	const DictRef town_result = overworld_rules::_find_town_by_placement(state, session, ai::string_or_empty(state, town, key::placement_id));
	const Value found_town = state.get(town_result, str(key::town), dict_value(town));
	const DictRef live_town = gd::is_dict(found_town) ? found_town.ref : town;
	if (gd::stringify(state, state.get(live_town, str(key::owner), str(key::neutral))) != key::player) {
		return refusal(state, key::only_your_own_towns_trade_through);
	}
	const DictRef market = overworld_rules::town_market_state(state, live_town);
	const int64_t day = gd::to_int(state, gd::field(state, session, key::day));
	// live_town.get("market_usage", {}): a missing usage normalizes as {} does (as null).
	const DictRef usage = overworld_rules::_normalize_town_market_usage_state(state, gd::field(state, live_town, key::market_usage), day);
	const DictRef stock = session_stock(state, session);
	const DictRef quote = market_trade_quote(state, market, usage, stock, give_id, receive_id, amount);
	if (ai::string_or_empty(state, quote, key::mode) != key::convert || !gd::bool_field(state, quote, key::ok, false)) {
		const Atom reason = ai::string_or_empty(state, quote, key::reason);
		return refusal(state, reason != key::empty ? reason : gd::format(state, key::that_conversion_is_not_available_in, {str(_town_name(state, live_town))}));
	}
	const int64_t give_amount = gd::int_field(state, quote, key::give_amount, 0);
	const int64_t receive_amount = gd::int_field(state, quote, key::receive_amount, 0);
	const DictRef cost = state.new_dict();
	state.set(cost, str(give_id), int_value(give_amount));
	overworld_rules::_spend_resources(state, session, dict_value(cost));
	const DictRef gain = state.new_dict();
	state.set(gain, str(receive_id), int_value(receive_amount));
	overworld_rules::_add_resources(state, session, dict_value(gain));
	const DictRef sold = usage_bucket(state, usage, key::sell);
	state.set(sold, str(give_id), int_value(gd::add(gd::int_field(state, sold, give_id, 0), give_amount)));
	state.set(usage, str(key::sell), dict_value(sold));
	const DictRef bought = usage_bucket(state, usage, key::buy);
	state.set(bought, str(receive_id), int_value(gd::add(gd::int_field(state, bought, receive_id, 0), receive_amount)));
	state.set(usage, str(key::buy), dict_value(bought));
	state.set(live_town, str(key::market_usage), dict_value(usage));
	const int64_t index = gd::int_field(state, town_result, key::index, -1);
	// session.overworld.get("towns", []): a missing list is a new empty one, which no index fits.
	Value towns;
	if (state.lookup(session_view::overworld(state, session), str(key::towns), towns) && index >= 0 && gd::is_array(towns) && index < state.array_size(towns.ref)) {
		state.set_at(towns.ref, index, dict_value(live_town));
		state.set(session_view::overworld(state, session), str(key::towns), towns);
	}
	const Atom message = gd::format(state, key::traded_d_s_for_d_s, {
		int_value(give_amount),
		str(_market_resource_name(state, give_id)),
		int_value(receive_amount),
		str(_market_resource_name(state, receive_id)),
		str(_town_name(state, live_town)),
		str(gd::stringify(state, state.get(market, str(key::building_name), str(key::the_market)))),
	});
	return overworld_rules::_finalize_action_result(state, session, true, message, true, false, state.new_dict());
}

Atom market_action_label(State &state, Atom action_id) {
	const std::vector<Atom> parts = split_atoms(state, action_id, key::colon);
	if (parts.size() == 4 && parts[0] == key::market && (parts[1] == key::buy || parts[1] == key::sell)) {
		return gd::format(state, key::s_d_s_4, {str(parts[1] == key::buy ? key::Buy : key::Sell), int_value(text_int(state, parts[3])), str(_market_resource_name(state, parts[2]))});
	}
	if (parts.size() == 5 && parts[0] == key::market && parts[1] == key::convert) {
		return gd::format(state, key::convert_s_into_d_s, {str(_market_resource_name(state, parts[2])), int_value(text_int(state, parts[4])), str(_market_resource_name(state, parts[3]))});
	}
	return action_id;
}

Atom _market_coverage_line(State &state, DictRef readiness) {
	// readiness.get("market_actions", []): a missing list is empty.
	Value actions;
	if (!state.lookup(readiness, str(key::market_actions), actions) || !gd::is_array(actions) || state.array_size(actions.ref) == 0) {
		return key::empty;
	}
	const int64_t size = state.array_size(actions.ref);
	const int64_t shown = compat::engine_min<int64_t>(2, size);
	// "; ".join(shown)
	std::string summary;
	for (int64_t index = 0; index < shown; ++index) {
		if (index > 0) {
			summary += state.text(key::semicolon_space);
		}
		summary += state.text(gd::stringify(state, state.at(actions.ref, index)));
	}
	if (size > 2) {
		summary += state.text(gd::format(state, key::d_more_step_s, {int_value(size - 2), str(size - 2 == 1 ? key::empty : key::s)}));
	}
	return state.intern(summary);
}

int64_t _max_market_affordable_count(State &state, DictRef session, DictRef town, DictRef resources, const Value &unit_cost, int64_t available_count) {
	// Market affordability only shrinks as the count grows, so search for the
	// largest affordable count instead of simulating every count from the top.
	// int(session.day) if session != null else -1: a view is never null.
	const int64_t current_day = gd::to_int(state, gd::field(state, session, key::day));
	int64_t high = compat::engine_max<int64_t>(available_count, 0);
	if (high <= 0) {
		return 0;
	}
	if (overworld_rules::can_afford_cost_with_town_market(state, town, resources, dict_value(_multiply_resource_cost(state, unit_cost, high)), current_day)) {
		return high;
	}
	int64_t low = 0;
	high = gd::sub(high, 1);
	while (low < high) {
		const int64_t middle = compat::int_div(gd::add(gd::add(low, high), 1), 2);
		if (overworld_rules::can_afford_cost_with_town_market(state, town, resources, dict_value(_multiply_resource_cost(state, unit_cost, middle)), current_day)) {
			low = middle;
		} else {
			high = gd::sub(middle, 1);
		}
	}
	return low;
}

Atom _market_building_summary(State &state, DictRef building) {
	const Atom building_id = ai::string_or_empty(state, building, key::id);
	if (building_id == key::building_market_square) {
		return key::trade_every_resource_for_gold_or;
	}
	if (building_id == key::building_dev_trade_exchange) {
		return key::better_rates_and_larger_weekly_limits;
	}
	if (building_id == key::building_river_granary_exchange) {
		return key::bulk_wood_lots_and_stronger_river;
	}
	if (building_id == key::building_resonant_exchange) {
		return key::bulk_ore_lots_and_stronger_relay;
	}
	return key::empty;
}

} // namespace town_rules

} // namespace aurelion::rules::port
