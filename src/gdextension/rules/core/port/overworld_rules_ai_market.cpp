// OverworldRules: the town market (its state, rates, weekly caps and usage, and
// quotes), the built-building list it reads, and the resource and recruit sets.

#include "aurelion_rules/port/overworld_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/town_development_rules_ai.hpp"

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

// LIVE_STOCKPILE_RESOURCE_KEYS, NORMAL_MARKET_RESOURCE_KEYS and MARKET_RESOURCE_KEYS.
constexpr Atom kLiveStockpileKeys[] = {key::gold, key::wood, key::ore, key::aetherglass, key::embergrain, key::peatwax, key::verdant_grafts, key::brass_scrip, key::memory_salt};
constexpr Atom kNormalMarketKeys[] = {key::wood, key::ore};
constexpr Atom kMarketKeys[] = {key::wood, key::ore, key::aetherglass, key::embergrain, key::peatwax, key::verdant_grafts, key::brass_scrip, key::memory_salt};

// x in NORMAL_MARKET_RESOURCE_KEYS and x in MARKET_RESOURCE_KEYS of a String.
bool is_normal_market_key(Atom resource_key) {
	return resource_key == key::wood || resource_key == key::ore;
}

bool is_market_key(Atom resource_key) {
	for (const Atom market_key : kMarketKeys) {
		if (market_key == resource_key) {
			return true;
		}
	}
	return false;
}

// MARKET_RESOURCE_VALUES.get(resource_key, 400).
int64_t market_resource_value(Atom resource_key) {
	if (resource_key == key::wood || resource_key == key::ore) {
		return 400;
	}
	if (resource_key == key::aetherglass || resource_key == key::embergrain || resource_key == key::peatwax || resource_key == key::verdant_grafts || resource_key == key::brass_scrip || resource_key == key::memory_salt) {
		return 800;
	}
	return 400;
}

// d.get(k, {}) if d.get(k, {}) is Dictionary else {}, where the code only reads
// it: false stands for the empty fallback.
bool dict_field(const State &state, DictRef dict, Atom field, DictRef &out) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		out = found.ref;
		return true;
	}
	return false;
}

// The same where a Dictionary must be passed on: a new empty one for the fallback.
DictRef dict_field_or_new(State &state, DictRef dict, Atom field) {
	DictRef found = 0;
	return dict_field(state, dict, field, found) ? found : state.new_dict();
}

// d.get(k, {}) stored in a result.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}

// x.get(k, {}) if x is Dictionary else {}, read only: Nil stands for the empty
// Dictionary (both count as no entries below).
Value dict_get_or_none(const State &state, const Value &value, Atom field) {
	return gd::is_dict(value) ? state.get(value.ref, str(field), Value()) : Value();
}

// 1 if x is Dictionary and int(x.get(resource_key, 0)) > 0 else 0.
int64_t positive_entry(const State &state, const Value &value, Atom resource_key) {
	return gd::is_dict(value) && gd::int_field(state, value.ref, resource_key, 0) > 0 ? 1 : 0;
}

// {"wood": 0, "ore": 0}.
DictRef wood_ore_zero(State &state) {
	const DictRef zero = state.new_dict();
	state.set(zero, str(key::wood), int_value(0));
	state.set(zero, str(key::ore), int_value(0));
	return zero;
}

// _town_market_state's `inactive` literal.
DictRef inactive_market_state(State &state) {
	const DictRef inactive = state.new_dict();
	state.set(inactive, str(key::active), bool_value(false));
	state.set(inactive, str(key::tier), int_value(0));
	state.set(inactive, str(key::profile), str(key::none));
	state.set(inactive, str(key::building_id), str(key::empty));
	state.set(inactive, str(key::building_name), str(key::empty));
	state.set(inactive, str(key::buy_rates), dict_value(wood_ore_zero(state)));
	state.set(inactive, str(key::sell_rates), dict_value(wood_ore_zero(state)));
	state.set(inactive, str(key::buy_caps), dict_value(wood_ore_zero(state)));
	state.set(inactive, str(key::sell_caps), dict_value(wood_ore_zero(state)));
	state.set(inactive, str(key::rare_resources), array_value(state.new_array()));
	state.set(inactive, str(key::refresh_cadence), str(key::weekly));
	state.set(inactive, str(key::bulk_resource), str(key::empty));
	state.set(inactive, str(key::bulk_resources), array_value(state.new_array()));
	state.set(inactive, str(key::bulk_amount), int_value(0));
	state.set(inactive, str(key::specialty_summary), str(key::empty));
	state.set(inactive, str(key::exchange_value), int_value(0));
	return inactive;
}

} // namespace

namespace overworld_rules {

DictRef _apply_resource_percent_scale(State &state, const Value &resources, int64_t percent) {
	const DictRef scaled = _normalize_resource_dict(state, resources);
	const int64_t applied_percent = compat::engine_max<int64_t>(0, percent);
	for (const Value &resource_id : gd::items(state, array_value(gd::keys(state, scaled)))) {
		const int64_t current = gd::to_int(state, state.get(scaled, resource_id, int_value(0)));
		const double scaled_value = static_cast<double>(current) * static_cast<double>(applied_percent) / 100.0;
		state.set(scaled, resource_id, int_value(compat::engine_max<int64_t>(0, compat::float_to_int(compat::godot_round(scaled_value)))));
	}
	return scaled;
}

DictRef _town_market_state(State &state, DictRef town) {
	if (gd::is_empty(state, town)) {
		return inactive_market_state(state);
	}
	const ArrayRef built_buildings = _normalize_built_buildings_for_town_state(state, town);
	Atom market_building_id = key::empty;
	DictRef market_profile = state.new_dict();
	for (const Value &building_id_value : gd::items(state, array_value(built_buildings))) {
		const Atom candidate_id = gd::stringify(state, building_id_value);
		// A missing market_profile is {}, whose empty id is skipped below.
		Value candidate_profile_value;
		if (!state.lookup(gd::content_row(state, ContentTable::Building, candidate_id), str(key::market_profile), candidate_profile_value) || !gd::is_dict(candidate_profile_value)) {
			continue;
		}
		const DictRef candidate_profile = candidate_profile_value.ref;
		if (ai::string_or_empty(state, candidate_profile, key::id) == key::empty) {
			continue;
		}
		if (gd::is_empty(state, market_profile) || gd::int_field(state, candidate_profile, key::tier, 0) > gd::int_field(state, market_profile, key::tier, 0)) {
			market_building_id = candidate_id;
			market_profile = gd::deep_duplicate_dict(state, candidate_profile);
		}
	}
	if (gd::is_empty(state, market_profile)) {
		return inactive_market_state(state);
	}
	const Atom profile_id = gd::stringify(state, gd::field_or(state, market_profile, key::id, str(key::none)));
	const int64_t tier = compat::engine_max<int64_t>(1, gd::int_field(state, market_profile, key::tier, 1));

	const DictRef market_building = gd::content_row(state, ContentTable::Building, market_building_id);
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	const DictRef faction = gd::content_row(state, ContentTable::Faction, ai::string_or_empty(state, town_template, key::faction_id));
	const DictRef buy_rates = state.new_dict();
	const DictRef sell_rates = state.new_dict();
	const DictRef buy_adjustments = dict_field_or_new(state, market_profile, key::buy_rate_adjustments);
	const DictRef sell_adjustments = dict_field_or_new(state, market_profile, key::sell_rate_adjustments);
	for (const Atom resource_key : kMarketKeys) {
		// faction.get("economy", {}): a missing economy scores as {} does.
		const int64_t abundance = _market_resource_abundance_score(state, gd::field(state, faction, key::economy), gd::field(state, town_template, key::economy), resource_key);
		int64_t buy_rate = gd::sub(740, gd::mul(abundance, 35));
		int64_t sell_rate = gd::add(280, gd::mul(abundance, 30));
		buy_rate = gd::add(buy_rate, _market_rate_adjustment(state, buy_adjustments, resource_key));
		sell_rate = gd::add(sell_rate, _market_rate_adjustment(state, sell_adjustments, resource_key));
		buy_rate = compat::engine_clamp<int64_t>(buy_rate, 500, 760);
		sell_rate = compat::engine_clamp<int64_t>(sell_rate, 260, compat::engine_max<int64_t>(260, gd::sub(buy_rate, 120)));
		const double value_scale = _market_value_scale(state, resource_key);
		state.set(buy_rates, str(resource_key), int_value(compat::float_to_int(compat::godot_round(static_cast<double>(buy_rate) * value_scale))));
		state.set(sell_rates, str(resource_key), int_value(compat::float_to_int(compat::godot_round(static_cast<double>(sell_rate) * value_scale))));
	}
	const ArrayRef bulk_resources = state.new_array();
	for (const Value &resource_value : gd::field_items(state, market_profile, str(key::bulk_resources))) {
		const Atom resource_id = gd::stringify(state, resource_value);
		if (is_normal_market_key(resource_id) && !gd::array_has(state, bulk_resources, str(resource_id))) {
			state.append(bulk_resources, str(resource_id));
		}
	}
	const Atom bulk_resource = state.array_size(bulk_resources) != 0 ? gd::stringify(state, state.at(bulk_resources, 0)) : key::empty;
	const Atom specialty_summary = ai::string_or_empty(state, market_profile, key::specialty_summary);
	int64_t exchange_value = 0;
	for (const Atom resource_key : kNormalMarketKeys) {
		exchange_value = gd::add(exchange_value, gd::int_field(state, sell_rates, resource_key, 0));
		exchange_value = gd::add(exchange_value, compat::engine_max<int64_t>(0, gd::sub(900, gd::int_field(state, buy_rates, resource_key, 0))));
	}
	exchange_value = gd::add(exchange_value, gd::mul(state.array_size(bulk_resources), 120));
	const DictRef caps = _market_caps_for_profile(state, market_profile);
	const ArrayRef rare_resources = state.new_array();
	for (const Atom resource_key : kMarketKeys) {
		if (!is_normal_market_key(resource_key)) {
			state.append(rare_resources, str(resource_key));
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::active), bool_value(true));
	state.set(result, str(key::tier), int_value(tier));
	state.set(result, str(key::profile), str(profile_id));
	state.set(result, str(key::rare_resources), array_value(rare_resources));
	state.set(result, str(key::building_id), str(market_building_id));
	state.set(result, str(key::building_name), str(gd::stringify(state, gd::field_or(state, market_building, key::name, str(market_building_id)))));
	state.set(result, str(key::buy_rates), dict_value(buy_rates));
	state.set(result, str(key::sell_rates), dict_value(sell_rates));
	state.set(result, str(key::buy_caps), field_or_new_dict(state, caps, key::buy_caps));
	state.set(result, str(key::sell_caps), field_or_new_dict(state, caps, key::sell_caps));
	state.set(result, str(key::refresh_cadence), str(gd::stringify(state, gd::field_or(state, caps, key::refresh_cadence, str(key::weekly)))));
	state.set(result, str(key::bulk_resource), str(bulk_resource));
	state.set(result, str(key::bulk_resources), array_value(bulk_resources));
	state.set(result, str(key::bulk_amount), int_value(state.array_size(bulk_resources) != 0 ? 2 : 0));
	state.set(result, str(key::specialty_summary), str(specialty_summary));
	state.set(result, str(key::exchange_value), int_value(exchange_value));
	return result;
}

int64_t _market_rate_adjustment(State &state, DictRef adjustments, Atom resource_key) {
	if (state.has(adjustments, str(resource_key))) {
		return gd::int_field(state, adjustments, resource_key, 0);
	}
	int64_t total = 0;
	for (const Atom common_key : kNormalMarketKeys) {
		total = gd::add(total, gd::int_field(state, adjustments, common_key, 0));
	}
	return compat::float_to_int(compat::godot_round(static_cast<double>(total) / static_cast<double>(2)));
}

double _market_value_scale(State &state, Atom resource_key) {
	(void)state;
	return static_cast<double>(market_resource_value(resource_key)) / static_cast<double>(market_resource_value(key::wood));
}

DictRef _market_caps_for_profile(State &state, DictRef profile) {
	const DictRef buy_caps = state.new_dict();
	const DictRef sell_caps = state.new_dict();
	DictRef buy_bonus = 0;
	DictRef sell_bonus = 0;
	const bool has_buy_bonus = dict_field(state, profile, key::buy_cap_bonus, buy_bonus);
	const bool has_sell_bonus = dict_field(state, profile, key::sell_cap_bonus, sell_bonus);
	for (const Atom resource_key : kMarketKeys) {
		const bool common = is_normal_market_key(resource_key);
		const int64_t buy_extra = compat::engine_max<int64_t>(0, has_buy_bonus ? gd::int_field(state, buy_bonus, resource_key, 0) : 0);
		state.set(buy_caps, str(resource_key), int_value(gd::add(common ? 12 : 2, buy_extra)));
		const int64_t sell_extra = compat::engine_max<int64_t>(0, has_sell_bonus ? gd::int_field(state, sell_bonus, resource_key, 0) : 0);
		state.set(sell_caps, str(resource_key), int_value(gd::add(common ? 16 : 3, sell_extra)));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::refresh_cadence), str(key::weekly));
	state.set(result, str(key::buy_caps), dict_value(buy_caps));
	state.set(result, str(key::sell_caps), dict_value(sell_caps));
	return result;
}

ArrayRef _market_bulk_resources(State &state, DictRef state_) {
	const ArrayRef result = state.new_array();
	Value authored;
	if (state.lookup(state_, str(key::bulk_resources), authored) && gd::is_array(authored)) {
		for (const Value &resource_value : gd::items(state, authored)) {
			const Atom resource_id = gd::stringify(state, resource_value);
			if (is_normal_market_key(resource_id) && !gd::array_has(state, result, str(resource_id))) {
				state.append(result, str(resource_id));
			}
		}
	}
	const Atom legacy_resource = ai::string_or_empty(state, state_, key::bulk_resource);
	if (is_normal_market_key(legacy_resource) && !gd::array_has(state, result, str(legacy_resource))) {
		state.append(result, str(legacy_resource));
	}
	return result;
}

DictRef _empty_market_usage_bucket(State &state, int64_t default_value) {
	const DictRef bucket = state.new_dict();
	for (const Atom resource_key : kNormalMarketKeys) {
		state.set(bucket, str(resource_key), int_value(default_value));
	}
	return bucket;
}

DictRef _normalize_market_usage_bucket(State &state, const Value &value) {
	const DictRef bucket = _empty_market_usage_bucket(state, 0);
	if (!gd::is_dict(value)) {
		return bucket;
	}
	for (const Atom resource_key : kLiveStockpileKeys) {
		if (resource_key != key::gold && (is_normal_market_key(resource_key) || state.has(value.ref, str(resource_key)))) {
			state.set(bucket, str(resource_key), int_value(compat::engine_max<int64_t>(0, gd::int_field(state, value.ref, resource_key, 0))));
		}
	}
	return bucket;
}

DictRef _normalize_town_market_usage_state(State &state, const Value &value, int64_t current_day) {
	const int64_t current_week = current_day > 0 ? _week_of_day(state, current_day) : 1;
	const int64_t source_week = gd::is_dict(value) ? gd::int_field(state, value.ref, key::week, current_week) : current_week;
	const int64_t usage_week = current_day > 0 ? current_week : compat::engine_max<int64_t>(1, source_week);
	const bool should_reset = current_day > 0 && source_week != usage_week;
	// source.get("buy", {}): a missing bucket normalizes as {} does (as null).
	const DictRef buy = should_reset ? _empty_market_usage_bucket(state, 0) : _normalize_market_usage_bucket(state, dict_get_or_none(state, value, key::buy));
	const DictRef sell = should_reset ? _empty_market_usage_bucket(state, 0) : _normalize_market_usage_bucket(state, dict_get_or_none(state, value, key::sell));
	const DictRef result = state.new_dict();
	state.set(result, str(key::week), int_value(usage_week));
	state.set(result, str(key::refresh_cadence), str(key::weekly));
	state.set(result, str(key::buy), dict_value(buy));
	state.set(result, str(key::sell), dict_value(sell));
	return result;
}

DictRef _market_cap_state_for_quote(State &state, DictRef town, DictRef state_, DictRef quote, int64_t current_day) {
	const Atom action_type = ai::string_or_empty(state, quote, key::action_type);
	const Atom resource_key = ai::string_or_empty(state, quote, key::resource);
	// town.get("market_usage", {}): a missing usage normalizes as {} does (as null).
	const DictRef usage = _normalize_town_market_usage_state(state, gd::field(state, town, key::market_usage), current_day);
	DictRef caps = 0;
	DictRef bucket = 0;
	const bool has_caps = dict_field(state, state_, gd::format(state, key::s_caps, {str(action_type)}), caps);
	const bool has_bucket = dict_field(state, usage, action_type, bucket);
	const int64_t limit = compat::engine_max<int64_t>(0, has_caps ? gd::int_field(state, caps, resource_key, 0) : 0);
	const int64_t used = compat::engine_clamp<int64_t>(has_bucket ? gd::int_field(state, bucket, resource_key, 0) : 0, 0, limit);
	const DictRef result = state.new_dict();
	state.set(result, str(key::week), int_value(gd::int_field(state, usage, key::week, 1)));
	state.set(result, str(key::refresh_cadence), str(gd::stringify(state, gd::field_or(state, state_, key::refresh_cadence, str(key::weekly)))));
	state.set(result, str(key::limit), int_value(limit));
	state.set(result, str(key::used), int_value(used));
	state.set(result, str(key::remaining), int_value(compat::engine_max<int64_t>(0, gd::sub(limit, used))));
	return result;
}

int64_t _market_resource_abundance_score(State &state, const Value &faction_economy, const Value &town_economy, Atom resource_key) {
	int64_t score = 0;
	const Value faction_base = dict_get_or_none(state, faction_economy, key::base_income);
	const Value town_base = dict_get_or_none(state, town_economy, key::base_income);
	const Value faction_categories = dict_get_or_none(state, faction_economy, key::per_category_income);
	const Value town_categories = dict_get_or_none(state, town_economy, key::per_category_income);
	const Value faction_economy_bucket = dict_get_or_none(state, faction_categories, key::economy);
	const Value town_economy_bucket = dict_get_or_none(state, town_categories, key::economy);
	score += positive_entry(state, faction_base, resource_key);
	score += positive_entry(state, town_base, resource_key);
	score += positive_entry(state, faction_economy_bucket, resource_key);
	score += positive_entry(state, town_economy_bucket, resource_key);
	return score;
}

DictRef _market_quote_from_state(State &state, DictRef state_, Atom action_type, Atom resource_key, int64_t amount) {
	if (!gd::to_bool(gd::field_or(state, state_, key::active, bool_value(false)))) {
		return state.new_dict();
	}
	if (!is_market_key(resource_key) || (action_type != key::buy && action_type != key::sell)) {
		return state.new_dict();
	}
	const int64_t normalized_amount = compat::engine_max<int64_t>(0, amount);
	if (normalized_amount <= 0) {
		return state.new_dict();
	}
	const bool buying = action_type == key::buy;
	// var rates: Dictionary = state.get(..., {}): a missing one has no rate.
	int64_t unit_rate = 0;
	Value rates_value;
	if (state.lookup(state_, str(buying ? key::buy_rates : key::sell_rates), rates_value)) {
		unit_rate = gd::int_field(state, gd::as_dict(rates_value), resource_key, 0);
	}
	if (unit_rate <= 0) {
		return state.new_dict();
	}
	int64_t total_value = gd::mul(unit_rate, normalized_amount);
	const int64_t bulk_amount = gd::int_field(state, state_, key::bulk_amount, 0);
	int64_t bulk_lots = 0;
	if (bulk_amount > 1 && gd::array_has(state, _market_bulk_resources(state, state_), str(resource_key))) {
		bulk_lots = compat::int_div(normalized_amount, bulk_amount);
	}
	const bool is_bulk = bulk_lots > 0;
	if (is_bulk) {
		const double lot_price = static_cast<double>(gd::mul(unit_rate, bulk_amount)) * (buying ? 0.9 : 1.1);
		const int64_t lot_value = compat::engine_max<int64_t>(1, compat::float_to_int(compat::godot_round(lot_price)));
		total_value = gd::add(gd::mul(bulk_lots, lot_value), gd::mul(gd::sub(normalized_amount, gd::mul(bulk_lots, bulk_amount)), unit_rate));
	}
	const DictRef cost = state.new_dict();
	const DictRef gain = state.new_dict();
	if (buying) {
		state.set(cost, str(key::gold), int_value(total_value));
		state.set(gain, str(resource_key), int_value(normalized_amount));
	} else {
		state.set(cost, str(resource_key), int_value(normalized_amount));
		state.set(gain, str(key::gold), int_value(total_value));
	}
	const int64_t per_unit = compat::float_to_int(compat::godot_round(static_cast<double>(total_value) / static_cast<double>(normalized_amount)));
	Atom rate_summary = gd::format(state, key::s_d_gold_per_s, {str(buying ? key::Pays : key::Yields), int_value(per_unit), str(resource_key)});
	if (is_bulk) {
		rate_summary = state.intern(gd::text(state, str(rate_summary)) + gd::text(state, str(key::in_bulk)));
	}
	Atom summary = key::empty;
	if (buying) {
		summary = gd::format(state, key::pay_d_gold_for_d_s, {int_value(total_value), int_value(normalized_amount), str(resource_key)});
	} else {
		summary = gd::format(state, key::trade_d_s_for_d_gold, {int_value(normalized_amount), str(resource_key), int_value(total_value)});
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::action_type), str(action_type));
	state.set(result, str(key::resource), str(resource_key));
	state.set(result, str(key::amount), int_value(normalized_amount));
	state.set(result, str(key::cost), dict_value(cost));
	state.set(result, str(key::gain), dict_value(gain));
	state.set(result, str(key::gold_value), int_value(total_value));
	state.set(result, str(key::building_name), str(gd::stringify(state, gd::field_or(state, state_, key::building_name, str(key::Market)))));
	state.set(result, str(key::building_summary), str(ai::string_or_empty(state, state_, key::specialty_summary)));
	state.set(result, str(key::summary), str(summary));
	state.set(result, str(key::rate_summary), str(rate_summary));
	return result;
}

ArrayRef _normalize_built_buildings_for_town_state(State &state, DictRef town) {
	if (town_development_rules::is_current(state, town)) {
		return town_development_rules::active_buildings(state, town);
	}
	const ArrayRef normalized = state.new_array();
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	for (const Value &building_id_value : gd::field_items(state, town_template, str(key::starting_building_ids))) {
		_append_building_with_requirements(state, normalized, gd::stringify(state, building_id_value), state.new_array());
	}
	for (const Value &building_id_value : gd::field_items(state, town, str(key::built_buildings))) {
		_append_building_with_requirements(state, normalized, gd::stringify(state, building_id_value), state.new_array());
	}
	return normalized;
}

DictRef _add_resource_sets(State &state, const Value &base, const Value &delta) {
	const DictRef merged = state.new_dict();
	if (gd::is_dict(base)) {
		for (const Value &resource : gd::items(state, base)) {
			const Atom resource_key = gd::stringify(state, resource);
			if (resource_key == key::experience || resource_key == key::empty) {
				continue;
			}
			state.set(merged, str(resource_key), int_value(gd::to_int(state, state.get(base.ref, resource, int_value(0)))));
		}
	}
	if (gd::is_dict(delta)) {
		for (const Value &resource : gd::items(state, delta)) {
			const Atom resource_key = gd::stringify(state, resource);
			if (resource_key == key::experience) {
				continue;
			}
			const int64_t current = gd::int_field(state, merged, resource_key, 0);
			state.set(merged, str(resource_key), int_value(gd::add(current, gd::to_int(state, gd::index(state, delta.ref, resource)))));
		}
	}
	return merged;
}

DictRef _normalize_resource_dict(State &state, const Value &value) {
	const DictRef normalized = state.new_dict();
	if (gd::is_dict(value)) {
		for (const Value &resource : gd::items(state, value)) {
			const Atom resource_key = gd::stringify(state, resource);
			state.set(normalized, str(resource_key), int_value(compat::engine_max<int64_t>(0, gd::to_int(state, gd::index(state, value.ref, resource)))));
		}
	}
	return normalized;
}

DictRef _empty_live_resource_stockpile(State &state) {
	const DictRef resources = state.new_dict();
	for (const Atom resource_key : kLiveStockpileKeys) {
		state.set(resources, str(resource_key), int_value(0));
	}
	return resources;
}

int64_t _recruit_payload_total(State &state, const Value &value) {
	int64_t total = 0;
	if (gd::is_dict(value)) {
		for (const Value &unit_id_value : gd::items(state, value)) {
			total = gd::add(total, compat::engine_max<int64_t>(0, gd::to_int(state, state.get(value.ref, unit_id_value, int_value(0)))));
		}
	}
	return total;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
