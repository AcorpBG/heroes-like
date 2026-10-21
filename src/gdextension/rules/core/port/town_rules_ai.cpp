// TownRules: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/town_rules_ai.hpp"

#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/compat/godot_string.hpp"

#include <cmath>
#include <string>

namespace aurelion::rules::port {

namespace {

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
// OverworldRules.MARKET_RESOURCE_KEYS.
constexpr Atom kMarketResourceKeys[] = {
	key::wood,
	key::ore,
	key::aetherglass,
	key::embergrain,
	key::peatwax,
	key::verdant_grafts,
	key::brass_scrip,
	key::memory_salt,
};
// market.get(field, {}) if market.get(field, {}) is Dictionary else {}, read
// only: false when that is the empty fallback.
bool market_rates(const State &state, DictRef market, Atom field, DictRef &rates) {
	Value found;
	if (state.lookup(market, str(field), found) && gd::is_dict(found)) {
		rates = found.ref;
		return true;
	}
	return false;
}
// int(rates.get(resource_id, 0)) of such a Dictionary.
int64_t market_rate(const State &state, bool has_rates, DictRef rates, Atom resource_id) {
	return has_rates ? gd::int_field(state, rates, resource_id, 0) : 0;
}
// s.to_lower() of ASCII text (the Unicode case tables are not ported).
Atom ascii_lower(State &state, Atom text, const char *where) {
	std::string result = state.text(text);
	for (char &c : result) {
		if (static_cast<unsigned char>(c) >= 0x80) {
			throw state::NotPorted(std::string(where) + ": to_lower() of non-ASCII text");
		}
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
		}
	}
	return state.intern(result);
}

} // namespace

namespace town_rules {

Atom market_trade_mode(State &state, DictRef market, Atom give_id, Atom receive_id) {
	if (!gd::bool_field(state, market, key::active, false) || give_id == receive_id) {
		return key::empty;
	}
	const ArrayRef tradable = market_resource_ids(state, market);
	if (give_id == key::gold && gd::array_has(state, tradable, str(receive_id))) {
		return key::buy;
	}
	if (receive_id == key::gold && gd::array_has(state, tradable, str(give_id))) {
		return key::sell;
	}
	if (gd::array_has(state, tradable, str(give_id)) && gd::array_has(state, tradable, str(receive_id))) {
		return key::convert;
	}
	return key::empty;
}

ArrayRef market_resource_ids(State &state, DictRef market) {
	DictRef buy_rates = 0;
	const bool has_buy_rates = market_rates(state, market, key::buy_rates, buy_rates);
	const ArrayRef ids = state.new_array();
	for (const Atom resource_id : kMarketResourceKeys) {
		if (market_rate(state, has_buy_rates, buy_rates, resource_id) > 0) {
			state.append(ids, str(resource_id));
		}
	}
	return ids;
}

DictRef market_conversion_rate(State &state, DictRef market, Atom give_id, Atom receive_id) {
	if (market_trade_mode(state, market, give_id, receive_id) != key::convert) {
		return state.new_dict();
	}
	DictRef sell_rates = 0;
	const bool has_sell_rates = market_rates(state, market, key::sell_rates, sell_rates);
	DictRef buy_rates = 0;
	const bool has_buy_rates = market_rates(state, market, key::buy_rates, buy_rates);
	const int64_t give_sell = market_rate(state, has_sell_rates, sell_rates, give_id);
	const int64_t receive_buy = market_rate(state, has_buy_rates, buy_rates, receive_id);
	const int64_t receive_value = gd::add(receive_buy, market_rate(state, has_sell_rates, sell_rates, receive_id));
	if (give_sell <= 0 || receive_value <= 0) {
		return state.new_dict();
	}
	const DictRef rate = state.new_dict();
	state.set(rate, str(key::numerator), int_value(receive_value));
	state.set(rate, str(key::denominator), int_value(gd::mul(2, give_sell)));
	return rate;
}

int64_t market_conversion_give_amount(State &state, DictRef rate, int64_t receive_amount) {
	const int64_t numerator = gd::int_field(state, rate, key::numerator, 0);
	const int64_t denominator = gd::int_field(state, rate, key::denominator, 0);
	if (numerator <= 0 || denominator <= 0 || receive_amount <= 0) {
		return 0;
	}
	return compat::int_div(gd::sub(gd::add(gd::mul(receive_amount, numerator), denominator), 1), denominator);
}

DictRef market_trade_quote(State &state, DictRef market, DictRef usage, DictRef stock, Atom give_id, Atom receive_id, int64_t amount, bool with_text) {
	const Atom mode = market_trade_mode(state, market, give_id, receive_id);
	const DictRef quote = state.new_dict();
	state.set(quote, str(key::mode), str(mode));
	state.set(quote, str(key::give_id), str(give_id));
	state.set(quote, str(key::receive_id), str(receive_id));
	state.set(quote, str(key::amount), int_value(compat::engine_max<int64_t>(0, amount)));
	state.set(quote, str(key::give_amount), int_value(0));
	state.set(quote, str(key::receive_amount), int_value(0));
	state.set(quote, str(key::max_amount), int_value(0));
	state.set(quote, str(key::ok), bool_value(false));
	state.set(quote, str(key::reason), str(key::empty));
	state.set(quote, str(key::action_id), str(key::empty));
	state.set(quote, str(key::label), str(key::empty));
	state.set(quote, str(key::rate_text), str(key::empty));
	state.set(quote, str(key::unit_text), str(key::empty));
	state.set(quote, str(key::limit_text), str(key::empty));
	if (mode == key::empty) {
		if (with_text) {
			state.set(quote, str(key::reason), str(_market_pair_reason(state, market, give_id, receive_id)));
		}
		return quote;
	}
	const int64_t reset_day = gd::add(gd::mul(gd::int_field(state, usage, key::week, 1), 7), 1);
	const DictRef usage_town = state.new_dict();
	state.set(usage_town, str(key::market_usage), dict_value(usage));
	if (mode == key::buy) {
		const DictRef unit = overworld_rules::_market_quote_from_state(state, market, key::buy, receive_id, 1);
		const DictRef cap = overworld_rules::_market_cap_state_for_quote(state, usage_town, market, unit, -1);
		const int64_t gold = gd::int_field(state, stock, key::gold, 0);
		const int64_t end = gd::add(gd::int_field(state, cap, key::remaining, 0), 1);
		for (int64_t count = 1; count < end; ++count) {
			if (gd::int_field(state, overworld_rules::_market_quote_from_state(state, market, key::buy, receive_id, count), key::gold_value, 0) > gold) {
				break;
			}
			state.set(quote, str(key::max_amount), int_value(count));
		}
		if (with_text) {
			const int64_t price = gd::int_field(state, unit, key::gold_value, 0);
			state.set(quote, str(key::unit_text), str(gd::format(state, key::s_gold, { str(_format_market_amount(state, price)) })));
			state.set(quote, str(key::rate_text), str(gd::format(state, key::s_gold_each_s, { str(_format_market_amount(state, price)), str(_market_bulk_text(state, market, key::buy, receive_id)) })));
			state.set(quote, str(key::limit_text), str(gd::format(state, key::s_bought_this_week_d_of, { str(_market_resource_title(state, receive_id)), int_value(gd::int_field(state, cap, key::used, 0)), int_value(gd::int_field(state, cap, key::limit, 0)) })));
			if (gd::to_int(state, gd::index(state, quote, str(key::max_amount))) <= 0) {
				const Atom reason = gd::int_field(state, cap, key::remaining, 0) <= 0 ? _market_limit_reason(state, key::buy, receive_id, cap, reset_day) : gd::format(state, key::not_enough_gold_1_s_costs, { str(_market_resource_name(state, receive_id)), str(_format_market_amount(state, price)) });
				state.set(quote, str(key::reason), str(reason));
			}
		}
	} else if (mode == key::sell) {
		const DictRef unit = overworld_rules::_market_quote_from_state(state, market, key::sell, give_id, 1);
		const DictRef cap = overworld_rules::_market_cap_state_for_quote(state, usage_town, market, unit, -1);
		const int64_t remaining = gd::int_field(state, cap, key::remaining, 0);
		const int64_t held = gd::int_field(state, stock, give_id, 0);
		state.set(quote, str(key::max_amount), int_value(compat::engine_max<int64_t>(0, compat::engine_min<int64_t>(remaining, held))));
		if (with_text) {
			const int64_t price = gd::int_field(state, unit, key::gold_value, 0);
			state.set(quote, str(key::unit_text), str(gd::format(state, key::s_per_s, { str(_format_market_amount(state, price)), str(_market_resource_name(state, give_id)) })));
			state.set(quote, str(key::rate_text), str(gd::format(state, key::s_gold_each_s, { str(_format_market_amount(state, price)), str(_market_bulk_text(state, market, key::sell, give_id)) })));
			state.set(quote, str(key::limit_text), str(gd::format(state, key::s_sold_this_week_d_of, { str(_market_resource_title(state, give_id)), int_value(gd::int_field(state, cap, key::used, 0)), int_value(gd::int_field(state, cap, key::limit, 0)) })));
			if (gd::to_int(state, gd::index(state, quote, str(key::max_amount))) <= 0) {
				const Atom reason = gd::int_field(state, cap, key::remaining, 0) <= 0 ? _market_limit_reason(state, key::sell, give_id, cap, reset_day) : gd::format(state, key::no_s_to_sell, { str(_market_resource_name(state, give_id)) });
				state.set(quote, str(key::reason), str(reason));
			}
		}
	} else if (mode == key::convert) {
		const DictRef rate = market_conversion_rate(state, market, give_id, receive_id);
		const int64_t numerator = gd::int_field(state, rate, key::numerator, 0);
		const int64_t denominator = gd::int_field(state, rate, key::denominator, 0);
		const DictRef sell_cap = overworld_rules::_market_cap_state_for_quote(state, usage_town, market, overworld_rules::_market_quote_from_state(state, market, key::sell, give_id, 1), -1);
		const DictRef buy_cap = overworld_rules::_market_cap_state_for_quote(state, usage_town, market, overworld_rules::_market_quote_from_state(state, market, key::buy, receive_id, 1), -1);
		const int64_t held = gd::int_field(state, stock, give_id, 0);
		const int64_t sell_remaining = gd::int_field(state, sell_cap, key::remaining, 0);
		const int64_t give_limit = compat::engine_max<int64_t>(0, compat::engine_min<int64_t>(held, sell_remaining));
		if (numerator > 0 && denominator > 0) {
			const int64_t buy_remaining = gd::int_field(state, buy_cap, key::remaining, 0);
			const int64_t affordable = compat::int_div(gd::mul(give_limit, denominator), numerator);
			state.set(quote, str(key::max_amount), int_value(compat::engine_max<int64_t>(0, compat::engine_min<int64_t>(buy_remaining, affordable))));
		}
		if (with_text) {
			const double per_unit = static_cast<double>(numerator) / static_cast<double>(compat::engine_max<int64_t>(1, denominator));
			state.set(quote, str(key::unit_text), str(gd::format(state, key::s_s, { str(_market_ratio_text(state, per_unit)), str(_market_resource_name(state, give_id)) })));
			// Read as "1 ore for 1.7 wood" or, for a valuable give, "1.2 wood for 1 aetherglass".
			if (per_unit >= 1.0) {
				state.set(quote, str(key::rate_text), str(gd::format(state, key::k_1_s_for_s_s, { str(_market_resource_name(state, receive_id)), str(_market_ratio_text(state, per_unit)), str(_market_resource_name(state, give_id)) })));
			} else {
				state.set(quote, str(key::rate_text), str(gd::format(state, key::s_s_for_1_s, { str(_market_ratio_text(state, 1.0 / per_unit)), str(_market_resource_name(state, receive_id)), str(_market_resource_name(state, give_id)) })));
			}
			state.set(quote, str(key::limit_text), str(gd::format(state, key::s_sold_this_week_d_of_2, { str(_market_resource_title(state, give_id)), int_value(gd::int_field(state, sell_cap, key::used, 0)), int_value(gd::int_field(state, sell_cap, key::limit, 0)), str(_market_resource_name(state, receive_id)), int_value(gd::int_field(state, buy_cap, key::used, 0)), int_value(gd::int_field(state, buy_cap, key::limit, 0)) })));
			if (gd::to_int(state, gd::index(state, quote, str(key::max_amount))) <= 0) {
				if (gd::int_field(state, buy_cap, key::remaining, 0) <= 0) {
					state.set(quote, str(key::reason), str(_market_limit_reason(state, key::buy, receive_id, buy_cap, reset_day)));
				} else if (gd::int_field(state, sell_cap, key::remaining, 0) <= 0) {
					state.set(quote, str(key::reason), str(_market_limit_reason(state, key::sell, give_id, sell_cap, reset_day)));
				} else {
					state.set(quote, str(key::reason), str(gd::format(state, key::needs_d_s_for_1_s, { int_value(market_conversion_give_amount(state, rate, 1)), str(_market_resource_name(state, give_id)), str(_market_resource_name(state, receive_id)) })));
				}
			}
		}
	}
	const int64_t count = gd::to_int(state, gd::index(state, quote, str(key::amount)));
	if (count <= 0 || count > gd::to_int(state, gd::index(state, quote, str(key::max_amount)))) {
		if (with_text && gd::stringify(state, gd::index(state, quote, str(key::reason))) == key::empty) {
			state.set(quote, str(key::reason), str(gd::format(state, key::choose_from_1_to_d, { int_value(gd::to_int(state, gd::index(state, quote, str(key::max_amount)))) })));
		}
		return quote;
	}
	if (mode == key::buy) {
		state.set(quote, str(key::give_amount), int_value(gd::int_field(state, overworld_rules::_market_quote_from_state(state, market, key::buy, receive_id, count), key::gold_value, 0)));
		state.set(quote, str(key::receive_amount), int_value(count));
		state.set(quote, str(key::action_id), str(gd::format(state, key::market_buy_s_d, { str(receive_id), int_value(count) })));
	} else if (mode == key::sell) {
		state.set(quote, str(key::give_amount), int_value(count));
		state.set(quote, str(key::receive_amount), int_value(market_sale_gold(state, market, give_id, count)));
		state.set(quote, str(key::action_id), str(gd::format(state, key::market_sell_s_d, { str(give_id), int_value(count) })));
	} else if (mode == key::convert) {
		state.set(quote, str(key::give_amount), int_value(market_conversion_give_amount(state, market_conversion_rate(state, market, give_id, receive_id), count)));
		state.set(quote, str(key::receive_amount), int_value(count));
		state.set(quote, str(key::action_id), str(gd::format(state, key::market_convert_s_s_d, { str(give_id), str(receive_id), int_value(count) })));
	}
	if (with_text) {
		state.set(quote, str(key::label), str(gd::format(state, key::trade_s_s_for_s_s, { str(_format_market_amount(state, gd::to_int(state, gd::index(state, quote, str(key::give_amount))))), str(_market_resource_name(state, give_id)), str(_format_market_amount(state, gd::to_int(state, gd::index(state, quote, str(key::receive_amount))))), str(_market_resource_name(state, receive_id)) })));
	}
	state.set(quote, str(key::ok), bool_value(true));
	return quote;
}

int64_t market_sale_gold(State &state, DictRef market, Atom give_id, int64_t count) {
	return gd::int_field(state, overworld_rules::_market_quote_from_state(state, market, key::sell, give_id, count), key::gold_value, 0);
}

Atom _market_pair_reason(State &state, DictRef market, Atom give_id, Atom receive_id) {
	if (!gd::bool_field(state, market, key::active, false)) {
		return key::no_market_stands_in_this_town;
	}
	if (give_id == receive_id) {
		return key::choose_a_different_resource_to_get;
	}
	if (give_id != key::gold && !gd::array_has(state, market_resource_ids(state, market), str(give_id))) {
		return gd::format(state, key::this_market_does_not_buy_s, {str(_market_resource_name(state, give_id))});
	}
	return gd::format(state, key::this_market_does_not_sell_s, {str(_market_resource_name(state, receive_id))});
}

Atom _market_ratio_text(State &state, double value) {
	// ("%.1f" % value).trim_suffix(".0"): a whole number below 2^53 prints as its digits on any C runtime. A
	// fraction is float text (String::num, the C runtime's snprintf), and -0.0, nan and inf are left to GDScript.
	if (!std::isfinite(value) || value != compat::godot_floor(value) || std::fabs(value) >= 9007199254740992.0 || (value == 0.0 && std::signbit(value))) {
		throw state::NotPorted("TownRules._market_ratio_text: \"%.1f\" % value of a fraction (float text)");
	}
	return state.intern(compat::itos(static_cast<int64_t>(value)));
}

Atom _market_limit_reason(State &state, Atom action_type, Atom resource_id, DictRef cap, int64_t reset_day) {
	const Atom verb = action_type == key::buy ? key::buy : key::sell;
	const int64_t used = gd::int_field(state, cap, key::used, 0);
	const int64_t limit = gd::int_field(state, cap, key::limit, 0);
	const Atom name = _market_resource_name(state, resource_id);
	const Atom done = action_type == key::buy ? key::bought : key::sold;
	return gd::format(state, key::this_week_s_s_limit_is, {str(verb), int_value(used), int_value(limit), str(name), str(done), int_value(reset_day)});
}

Atom _market_bulk_text(State &state, DictRef market, Atom action_type, Atom resource_id) {
	const int64_t bulk_amount = gd::int_field(state, market, key::bulk_amount, 0);
	Value bulk_resources;
	if (bulk_amount <= 1 || !state.lookup(market, str(key::bulk_resources), bulk_resources) || !gd::in(state, str(resource_id), bulk_resources)) {
		return key::empty;
	}
	const DictRef lot = overworld_rules::_market_quote_from_state(state, market, action_type, resource_id, bulk_amount);
	const Atom gold = _format_market_amount(state, gd::int_field(state, lot, key::gold_value, 0));
	return gd::format(state, key::d_for_s_gold, {int_value(bulk_amount), str(gold)});
}

Atom _market_resource_title(State &state, Atom resource_id) {
	const std::string name = state.text(_market_resource_name(state, resource_id));
	if (name.empty()) {
		return key::empty;
	}
	char first = name[0];
	if (static_cast<unsigned char>(first) >= 0x80) {
		throw state::NotPorted("TownRules._market_resource_title: to_upper() of a non-ASCII character");
	}
	if (first >= 'a' && first <= 'z') {
		first = static_cast<char>(first - 'a' + 'A');
	}
	return state.intern(std::string(1, first) + name.substr(1));
}

Atom _market_resource_name(State &state, Atom resource_id) {
	const DictRef definition = overworld_rules::resource_definition(state, resource_id);
	const Atom fallback = gd::replace(state, resource_id, key::_, key::space);
	const Atom name = gd::stringify(state, state.get(definition, str(key::display_name), str(fallback)));
	return ascii_lower(state, name, "TownRules._market_resource_name");
}

Atom _format_market_amount(State &state, int64_t value) {
	std::string digits = compat::itos(compat::absi(value));
	std::string grouped;
	while (digits.size() > 3) {
		grouped = "," + digits.substr(digits.size() - 3) + grouped;
		digits = digits.substr(0, digits.size() - 3);
	}
	return state.intern((value < 0 ? "-" : "") + digits + grouped);
}

} // namespace town_rules

} // namespace aurelion::rules::port
