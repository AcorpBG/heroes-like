// AiHeroRules: a computer player's towns on its day: the opening stockpile and
// start hero, the tavern, hires, recruits and the day's construction.

#include "aurelion_rules/port/ai_hero_rules_turn.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/enemy_turn_rules_turn.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/native_random_map_package_session_bridge.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/overworld_turn_playback_turn.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/town_development_rules.hpp"
#include "aurelion_rules/port/town_development_rules_ai.hpp"
#include "aurelion_rules/port/turn_port.hpp"

#include <string>

namespace aurelion::rules::port {

// Ported elsewhere (hero_commit.cpp, enemy_states.cpp) without a header.
namespace hero_command_rules {
gd::Atom new_growth_seed(state::State &state, gd::Atom hero_id, gd::DictRef session);
} // namespace hero_command_rules

namespace enemy_adventure_rules {
gd::DictRef build_roster_commander_state(state::State &state, gd::Atom roster_hero_id, gd::Atom faction_id, gd::DictRef existing_state, const state::Value &record_source);
gd::DictRef _normalize_enemy_progression(state::State &state, gd::DictRef commander_state);
} // namespace enemy_adventure_rules

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

constexpr Atom kScript = key::ai_hero_rules_script;
// HeroCommandRules.HERO_LIMIT and TAVERN_OFFER_SIZE.
constexpr int64_t kHeroLimit = 4;
constexpr int64_t kTavernOfferSize = 2;

// d.get(k, {}) / d.get(k, []) whose result is kept: a new container when the
// key is missing.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}

Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

// The same of an untyped value (anything but a Dictionary has no get()).
Value vget_or_new_dict(State &state, const Value &object, Atom field) {
	if (gd::is_dict(object)) {
		return field_or_new_dict(state, object.ref, field);
	}
	return ai::vget(state, object, field);
}

Value vget_or_new_array(State &state, const Value &object, Atom field) {
	if (gd::is_dict(object)) {
		return field_or_new_array(state, object.ref, field);
	}
	return ai::vget(state, object, field);
}

// context.state, context.state.treasury and String(context.controller).
DictRef context_state(State &state, DictRef context) {
	return gd::as_dict(gd::index(state, context, str(key::state)));
}

DictRef context_treasury(State &state, DictRef context) {
	return gd::as_dict(ai::vmember(state, gd::index(state, context, str(key::state)), key::treasury));
}

Atom context_controller(State &state, DictRef context) {
	return gd::stringify(state, gd::index(state, context, str(key::controller)));
}

// var towns: Array = session.overworld.get("towns", [])
ArrayRef overworld_towns(State &state, DictRef session) {
	return ai::typed_array(field_or_new_array(state, session_view::overworld(state, session), key::towns), "AiHeroRules: session.overworld.towns");
}

// {"messages": messages, "events": events}
DictRef messages_events(State &state, ArrayRef messages, ArrayRef events) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::messages), array_value(messages));
	state.set(result, str(key::events), array_value(events));
	return result;
}

// {"messages": [], "events": [hired.get("event", {})]}
DictRef hired_result(State &state, DictRef hired) {
	const ArrayRef messages = state.new_array();
	const ArrayRef events = state.new_array();
	state.append(events, field_or_new_dict(state, hired, key::event));
	return messages_events(state, messages, events);
}

// {"ok": false}
DictRef not_ok(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	return result;
}

// NativeRandomMapPackageSessionBridge.GENERATED_START_ARMY_BY_FACTION.get(faction_id, "").
Atom generated_start_army(Atom faction_id) {
	if (faction_id == key::faction_embercourt) {
		return key::army_start_embercourt;
	}
	if (faction_id == key::faction_mireclaw) {
		return key::army_start_mireclaw;
	}
	if (faction_id == key::faction_sunvault) {
		return key::army_start_sunvault;
	}
	if (faction_id == key::faction_thornwake) {
		return key::army_start_thornwake;
	}
	if (faction_id == key::faction_brasshollow) {
		return key::army_start_brasshollow;
	}
	if (faction_id == key::faction_veilmourn) {
		return key::army_start_veilmourn;
	}
	return key::empty;
}

} // namespace

namespace ai_hero_rules {

void _ensure_opening_stockpile(State &state, DictRef session, DictRef context) {
	const DictRef state_ = context_state(state, context);
	if (gd::bool_field(state, state_, key::ai_opening_granted, false)) {
		return;
	}
	state.set(state_, str(key::ai_opening_granted), bool_value(true));
	if (ai::session_int(state, session, key::day) > 2) {
		return;
	}
	Value adoption;
	if (!state.lookup(session_view::overworld(state, session), str(key::native_random_map_package_session_adoption), adoption) || !gd::is_dict(adoption) || gd::is_empty(state, adoption.ref)) {
		return;
	}
	const DictRef opening = native_random_map_package_session_bridge::_opening_resource_stockpile(state);
	_add_pool(state, gd::as_dict(gd::index(state, state_, str(key::treasury))), dict_value(opening));
}

DictRef _ensure_starting_hero(State &state, DictRef session, DictRef context) {
	const DictRef state_ = context_state(state, context);
	const Atom controller = context_controller(state, context);
	if (gd::bool_field(state, state_, key::ai_start_hero_granted, false)) {
		return state.new_dict();
	}
	if (active_hero_count(state, session, controller) > 0) {
		state.set(state_, str(key::ai_start_hero_granted), bool_value(true));
		return state.new_dict();
	}
	const ArrayRef entries = enemy_turn_rules::_owned_town_entries(state, session, controller);
	if (state.array_size(entries) == 0) {
		return state.new_dict();
	}
	const DictRef town = gd::as_dict(vget_or_new_dict(state, state.at(entries, 0), key::town));
	if (!_town_entrance_free(state, session, town, controller)) {
		return state.new_dict();
	}
	const ArrayRef offer = ai_tavern_offer_ids(state, session, state_, controller);
	if (state.array_size(offer) == 0) {
		return state.new_dict();
	}
	const Atom hero_id = gd::stringify(state, state.at(offer, 0));
	const Atom faction_id = player_identity_rules::faction_id(state, session, controller);
	const Atom army_id = generated_start_army(faction_id);
	const ArrayRef stacks = state.new_array();
	const DictRef army_group = gd::content_row(state, ContentTable::ArmyGroup, army_id);
	for (const Value &stack : gd::field_items(state, army_group, str(key::stacks))) {
		if (gd::is_dict(stack) && gd::int_field(state, stack.ref, key::count, 0) > 0) {
			const DictRef added = state.new_dict();
			state.set(added, str(key::unit_id), str(ai::string_or_empty(state, stack.ref, key::unit_id)));
			state.set(added, str(key::count), int_value(gd::int_field(state, stack.ref, key::count, 0)));
			state.append(stacks, dict_value(added));
		}
	}
	const DictRef hired = _create_hero(state, session, context, town, hero_id, stacks);
	if (gd::is_empty(state, hired)) {
		return state.new_dict();
	}
	state.set(state_, str(key::ai_start_hero_granted), bool_value(true));
	return hired_result(state, hired);
}

DictRef _govern_towns(State &state, DictRef session, DictRef context) {
	const Atom controller = context_controller(state, context);
	const ArrayRef messages = state.new_array();
	const ArrayRef events = state.new_array();
	const ArrayRef town_entries = enemy_turn_rules::_owned_town_entries(state, session, controller);
	if (state.array_size(town_entries) == 0) {
		return messages_events(state, messages, events);
	}
	int64_t started = gd::ticks_usec();
	// An army stuck on its island saves for a boat before the towns spend.
	DictRef held = state.new_dict();
	const int64_t wanted_day = gd::to_int(state, ai::vget(state, gd::index(state, context, str(key::state)), key::ai_boat_wanted_day, int_value(-1000)));
	if (wanted_day >= gd::sub(ai::session_int(state, session, key::day), ai::static_int(state, kScript, key::BOAT_SAVING_DAYS))) {
		const DictRef treasury = context_treasury(state, context);
		const DictRef surface = _level_surface(state, session, context, 0);
		held = _hold_back(state, treasury, gd::as_dict(field_or_new_dict(state, surface, key::boat_cost)));
	}
	const int64_t wanted = _desired_hero_count(state, session, controller);
	const int64_t heroes = active_hero_count(state, session, controller);
	if (heroes < wanted && !_faction_has_tavern(state, town_entries)) {
		const DictRef tavern_result = _build_tavern(state, session, context, town_entries);
		_append_all(state, messages, gd::field(state, tavern_result, key::messages));
		_append_all(state, events, gd::field(state, tavern_result, key::events));
	}
	if (heroes < wanted) {
		const DictRef hire_result = _hire_hero(state, session, context);
		_append_all(state, events, gd::field(state, hire_result, key::events));
		_append_all(state, messages, gd::field(state, hire_result, key::messages));
	}
	_profile_add(state, context, key::hire_ms, started);
	// Troops first (they only appear with weekly growth and new dwellings), then
	// the day's construction with what is left.
	started = gd::ticks_usec();
	const DictRef recruit_result = _recruit_in_towns(state, session, context, state.new_dict());
	_append_all(state, events, gd::field(state, recruit_result, key::events));
	_append_all(state, messages, gd::field(state, recruit_result, key::messages));
	_profile_add(state, context, key::recruit_ms, started);
	started = gd::ticks_usec();
	const DictRef build_result = _build_in_towns(state, session, context);
	_append_all(state, messages, gd::field(state, build_result, key::messages));
	_append_all(state, events, gd::field(state, build_result, key::events));
	_profile_add(state, context, key::build_ms, started);
	_add_pool(state, context_treasury(state, context), dict_value(held));
	return messages_events(state, messages, events);
}

DictRef _hold_back(State &state, DictRef treasury, DictRef amounts) {
	const DictRef held = state.new_dict();
	const ArrayRef keys = gd::keys(state, amounts);
	for (const Value &resource : gd::items(state, array_value(keys))) {
		const int64_t take = compat::engine_min<int64_t>(gd::to_int(state, state.get(treasury, resource, int_value(0))), gd::to_int(state, gd::index(state, amounts, resource)));
		if (take > 0) {
			state.set(treasury, resource, int_value(gd::sub(gd::to_int(state, state.get(treasury, resource, int_value(0))), take)));
			state.set(held, resource, int_value(take));
		}
	}
	return held;
}

int64_t _desired_hero_count(State &state, DictRef session, Atom controller) {
	const int64_t towns = enemy_turn_rules::_owned_town_count(state, session, controller);
	const int64_t base = gd::add(1, compat::engine_min<int64_t>(towns, ai::static_int(state, kScript, key::HERO_COUNT_TOWN_MAX)));
	const int64_t extra = ai::session_int(state, session, key::day) >= ai::static_int(state, kScript, key::EXTRA_HERO_DAY) ? 1 : 0;
	return compat::engine_clamp<int64_t>(gd::add(base, extra), 1, kHeroLimit);
}

bool _faction_has_tavern(State &state, ArrayRef town_entries) {
	for (const Value &entry : gd::items(state, array_value(town_entries))) {
		if (hero_command_rules::town_has_hall(state, gd::as_dict(vget_or_new_dict(state, entry, key::town)))) {
			return true;
		}
	}
	return false;
}

DictRef _build_tavern(State &state, DictRef session, DictRef context, ArrayRef town_entries) {
	const DictRef treasury = context_treasury(state, context);
	const ArrayRef towns = overworld_towns(state, session);
	for (int64_t at = 0; at < state.array_size(town_entries); ++at) {
		const Value entry = state.at(town_entries, at);
		const int64_t index = gd::to_int(state, ai::vget(state, entry, key::index, int_value(-1)));
		if (index < 0 || index >= state.array_size(towns)) {
			continue;
		}
		const DictRef town = gd::as_dict(state.at(towns, index));
		if (gd::int_field(state, town, key::last_build_day, 0) == ai::session_int(state, session, key::day)) {
			continue;
		}
		const DictRef status = overworld_rules::get_town_build_status(state, town, key::building_wayfarers_hall);
		if (!gd::bool_field(state, status, key::buildable, false)) {
			continue;
		}
		const DictRef building = gd::as_dict(field_or_new_dict(state, status, key::building));
		const DictRef cost = gd::as_dict(field_or_new_dict(state, building, key::cost));
		if (!_market_cover(state, session, town, treasury, cost, false)) {
			continue;
		}
		const DictRef result = build_in_town(state, session, context, index, key::building_wayfarers_hall);
		if (gd::bool_field(state, result, key::ok, false)) {
			return result;
		}
	}
	return state.new_dict();
}

DictRef _build_in_towns(State &state, DictRef session, DictRef context) {
	const ArrayRef messages = state.new_array();
	const ArrayRef events = state.new_array();
	const DictRef treasury = context_treasury(state, context);
	ArrayRef towns = overworld_towns(state, session);
	const ArrayRef entries = enemy_turn_rules::_owned_town_entries(state, session, context_controller(state, context));
	for (int64_t at = 0; at < state.array_size(entries); ++at) {
		const Value entry = state.at(entries, at);
		const int64_t index = gd::to_int(state, ai::vget(state, entry, key::index, int_value(-1)));
		if (index < 0 || index >= state.array_size(towns)) {
			continue;
		}
		const DictRef town = gd::as_dict(state.at(towns, index));
		if (gd::int_field(state, town, key::last_build_day, 0) == ai::session_int(state, session, key::day)) {
			continue;
		}
		const DictRef choice = _build_choice(state, session, town, treasury, state.new_dict());
		if (gd::is_empty(state, choice)) {
			continue;
		}
		const Atom building_id = gd::stringify(state, gd::index(state, choice, str(key::building_id)));
		const Atom reason = gd::stringify(state, gd::index(state, choice, str(key::reason)));
		const DictRef result = build_in_town(state, session, context, index, building_id, reason);
		_append_all(state, messages, gd::field(state, result, key::messages));
		_append_all(state, events, gd::field(state, result, key::events));
		towns = overworld_towns(state, session);
	}
	return messages_events(state, messages, events);
}

DictRef _build_choice(State &state, DictRef session, DictRef town, DictRef treasury, DictRef values) {
	const DictRef income_before = _trial_income(state, town);
	const DictRef growth_before = _trial_growth(state, town);
	const double weekly_troops_before = _recruit_set_value(state, growth_before);
	const ArrayRef options = overworld_rules::get_town_build_options(state, town, ai::session_int(state, session, key::day));
	const ArrayRef built = ai::typed_array(field_or_new_array(state, town, key::built_buildings), "AiHeroRules._build_choice: town.built_buildings");
	DictRef best = state.new_dict();
	double best_score = 0.0;
	// Resources the treasury lacks for something this town could build now.
	const DictRef short_ = state.new_dict();
	const DictRef market_memo = state.new_dict();
	for (int64_t at = 0; at < state.array_size(options); ++at) {
		const DictRef row = gd::content_row(state, ContentTable::Building, gd::stringify(state, state.at(options, at)));
		Value listed_value;
		if (!state.lookup(row, str(key::cost), listed_value)) {
			continue;
		}
		const DictRef listed = gd::as_dict(listed_value);
		for (const Value &k : gd::items(state, dict_value(listed))) {
			if (gd::to_int(state, gd::index(state, listed, k)) > gd::to_int(state, state.get(treasury, k, int_value(0)))) {
				state.set(short_, str(gd::stringify(state, k)), bool_value(true));
			}
		}
	}
	for (int64_t at = 0; at < state.array_size(options); ++at) {
		const Atom building_id = gd::stringify(state, state.at(options, at));
		// Buildable today, so buildable on any day too; the town is not changed
		// here, so its status would only hand back the building record.
		const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
		const DictRef cost = gd::as_dict(field_or_new_dict(state, building, key::cost));
		if (!_market_cover(state, session, town, treasury, cost, false, dict_value(market_memo))) {
			continue;
		}
		const ArrayRef trial_built = gd::duplicate_array(state, built);
		state.append(trial_built, str(building_id));
		const DictRef trial = state.new_dict();
		state.set(trial, str(key::town_id), state.get(town, str(key::town_id), str(key::empty)));
		state.set(trial, str(key::placement_id), state.get(town, str(key::placement_id), str(key::empty)));
		state.set(trial, str(key::built_buildings), array_value(trial_built));
		state.set(trial, str(key::development_version), state.get(town, str(key::development_version), int_value(0)));
		double value = 0.0;
		Atom reason = key::development;
		// Troops and income are weighed over the same two weeks; a town that
		// musters little wants dwellings first, as a human would.
		const double weekly_troops = _recruit_set_value(state, _trial_growth(state, trial));
		double troops = (weekly_troops - weekly_troops_before) * ai::static_float(state, kScript, key::BUILD_HORIZON_WEEKS);
		if (weekly_troops_before < ai::static_float(state, kScript, key::STARVED_TOWN_WEEKLY_TROOPS)) {
			troops *= ai::static_float(state, kScript, key::STARVED_TOWN_TROOP_MULTIPLIER);
		}
		if (troops > 0.0) {
			value += troops;
			reason = key::troops;
		}
		const DictRef trial_income = _trial_income(state, trial);
		const double income_value = _build_value(state, _pool_delta(state, trial_income, income_before));
		const double income = income_value * 7.0 * ai::static_float(state, kScript, key::BUILD_HORIZON_WEEKS);
		if (income > value) {
			reason = key::income;
		}
		value += income;
		// The troops above already hold what an upgrade adds on the current
		// development rules.
		if (ai::string_or_empty(state, building, key::upgrade_from) != key::empty && ai::string_or_empty(state, building, key::unlock_unit_id) != key::empty) {
			if (!town_development_rules::is_current(state, town)) {
				value += _upgrade_value(state, town, building);
			}
			reason = key::troops;
		}
		if (gd::int_field(state, building, key::spell_tier, 0) > 0) {
			const double guild_base = ai::static_float(state, kScript, key::MAGE_GUILD_BASE_VALUE);
			const double guild_tier = ai::static_float(state, kScript, key::MAGE_GUILD_TIER_VALUE);
			value += guild_base + guild_tier * gd::float_field(state, building, key::spell_tier, 0.0);
			if (value > 0.0 && reason == key::development) {
				reason = key::spells;
			}
		}
		const double readiness = ai::static_float(state, kScript, key::READINESS_VALUE);
		value += readiness * gd::float_field(state, building, key::readiness_bonus, 0.0);
		const double market = _market_value(state, building, short_);
		if (market > 0.0) {
			value += market;
			reason = key::market;
		}
		const double opens_value = ai::static_float(state, kScript, key::OPENS_BUILDING_VALUE);
		value += opens_value * static_cast<double>(_opens_count(state, town, building_id, trial_built));
		const double cost_value = compat::engine_max(1.0, _build_value(state, cost));
		const double score = value / cost_value;
		state.set(values, str(building_id), float_value(value));
		if (score > best_score) {
			best_score = score;
			best = state.new_dict();
			state.set(best, str(key::building_id), str(building_id));
			state.set(best, str(key::reason), str(reason));
			state.set(best, str(key::score), float_value(score));
		}
	}
	return best;
}

DictRef _trial_income(State &state, DictRef town) {
	if (town_development_rules::is_current(state, town)) {
		return town_development_rules::income(state, town);
	}
	return overworld_rules::town_income(state, town);
}

int64_t _opens_count(State &state, DictRef town, Atom building_id, ArrayRef trial_built) {
	int64_t count = 0;
	const DictRef trial = gd::duplicate_dict(state, town);
	state.set(trial, str(key::built_buildings), array_value(trial_built));
	const DictRef town_row = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	for (const Value &other_value : gd::field_items(state, town_row, str(key::buildable_building_ids))) {
		const Atom other_id = gd::stringify(state, other_value);
		if (other_id == building_id || gd::array_has(state, trial_built, str(other_id))) {
			continue;
		}
		Value requires;
		if (!state.lookup(gd::content_row(state, ContentTable::Building, other_id), str(key::requires_), requires) || !gd::in(state, str(building_id), requires)) {
			continue;
		}
		if (gd::bool_field(state, overworld_rules::get_town_build_status(state, trial, other_id), key::buildable, false)) {
			count += 1;
		}
	}
	return count;
}

double _market_value(State &state, DictRef building, DictRef short_) {
	Value profile;
	if (!state.lookup(building, str(key::market_profile), profile) || !gd::is_dict(profile) || gd::is_empty(state, profile.ref)) {
		return 0.0;
	}
	const DictRef storehouse = gd::as_dict(field_or_new_dict(state, gd::content_row(state, ContentTable::Building, key::building_dev_storehouse_1), key::income));
	const double storehouse_value = _build_value(state, storehouse);
	double value = storehouse_value * 7.0 * ai::static_float(state, kScript, key::BUILD_HORIZON_WEEKS);
	if (!gd::is_empty(state, short_)) {
		value *= ai::static_float(state, kScript, key::SHORT_RESOURCE_MULTIPLIER);
	}
	return value;
}

DictRef _pool_delta(State &state, DictRef after, DictRef before) {
	const DictRef delta = state.new_dict();
	for (const Value &k : gd::items(state, dict_value(after))) {
		const int64_t amount = gd::sub(gd::to_int(state, gd::index(state, after, k)), gd::to_int(state, state.get(before, k, int_value(0))));
		if (amount != 0) {
			state.set(delta, k, int_value(amount));
		}
	}
	return delta;
}

DictRef build_in_town(State &state, DictRef session, DictRef context, int64_t town_index, Atom building_id, Atom reason) {
	const DictRef treasury = context_treasury(state, context);
	const ArrayRef towns = overworld_towns(state, session);
	const DictRef town = gd::as_dict(state.at(towns, town_index));
	const DictRef status = overworld_rules::get_town_build_status(state, town, building_id);
	if (gd::int_field(state, town, key::last_build_day, 0) == ai::session_int(state, session, key::day) || !gd::bool_field(state, status, key::buildable, false)) {
		return not_ok(state);
	}
	const DictRef building = gd::as_dict(field_or_new_dict(state, status, key::building));
	const DictRef cost = gd::as_dict(field_or_new_dict(state, building, key::cost));
	if (!_market_cover(state, session, town, treasury, cost, false)) {
		return not_ok(state);
	}
	_market_cover(state, session, town, treasury, cost, true);
	enemy_turn_rules::_spend_from_pool(state, treasury, dict_value(cost));
	_economy_add(state, session, context_controller(state, context), key::build_gold, gd::float_field(state, cost, key::gold, 0.0));
	Value built_value;
	const ArrayRef built = state.lookup(town, str(key::built_buildings), built_value) && gd::is_array(built_value) ? built_value.ref : state.new_array();
	state.append(built, str(building_id));
	state.set(town, str(key::built_buildings), array_value(built));
	town_development_rules::migrate_town(state, town);
	state.set(town, str(key::last_build_day), int_value(ai::session_int(state, session, key::day)));
	const Value recruits = field_or_new_dict(state, town, key::available_recruits);
	const DictRef growth = enemy_turn_rules::_building_growth_payload(state, building_id);
	state.set(town, str(key::available_recruits), dict_value(enemy_turn_rules::_merge_recruits(state, recruits, dict_value(growth))));
	state.set_at(towns, town_index, dict_value(town));
	state.set(session_view::overworld(state, session), str(key::towns), array_value(towns));
	const DictRef config = gd::as_dict(gd::index(state, context, str(key::config)));
	const DictRef selected = state.new_dict();
	state.set(selected, str(key::building_id), str(building_id));
	state.set(selected, str(key::building_label), str(gd::stringify(state, state.get(building, str(key::name), str(building_id)))));
	const ArrayRef reason_codes = state.new_array();
	state.append(reason_codes, str(gd::format(state, key::town_build_s, { str(reason) })));
	state.set(selected, str(key::reason_codes), array_value(reason_codes));
	state.set(selected, str(key::public_reason), str(reason));
	const DictRef event = enemy_turn_rules::ai_town_build_event(state, session, config, town, selected);
	const Value label_source = gd::index(state, context, str(key::config));
	const Atom label = gd::stringify(state, ai::vget(state, label_source, key::label, gd::index(state, context, str(key::controller))));
	const Atom building_name = gd::stringify(state, state.get(building, str(key::name), str(building_id)));
	const Atom town_name = enemy_turn_rules::_town_name(state, town);
	const ArrayRef messages = state.new_array();
	state.append(messages, str(gd::format(state, key::s_builds_s_in_s, { str(label), str(building_name), str(town_name) })));
	const ArrayRef events = state.new_array();
	if (!gd::is_empty(state, event)) {
		state.append(events, dict_value(event));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::messages), array_value(messages));
	state.set(result, str(key::events), array_value(events));
	return result;
}

ArrayRef ai_tavern_offer_ids(State &state, DictRef session, DictRef state_, Atom controller) {
	const int64_t week = hero_command_rules::tavern_week(state, session);
	const ArrayRef pool = _tavern_pool(state, session, state_, controller);
	// stored = state.get("ai_tavern", {}): a missing one is an empty Dictionary.
	Value stored;
	const bool has_stored = state.lookup(state_, str(key::ai_tavern), stored);
	bool keep = false;
	if (!has_stored) {
		keep = week == -1;
	} else if (gd::is_dict(stored) && gd::int_field(state, stored.ref, key::week, -1) == week) {
		Value ids;
		keep = !state.lookup(stored.ref, str(key::hero_ids), ids) || gd::is_array(ids);
	}
	if (keep) {
		const ArrayRef kept = state.new_array();
		if (has_stored) {
			for (const Value &hero_id : gd::field_items(state, stored.ref, str(key::hero_ids))) {
				if (gd::array_has(state, pool, str(gd::stringify(state, hero_id)))) {
					state.append(kept, str(gd::stringify(state, hero_id)));
				}
			}
		}
		return kept;
	}
	const ArrayRef candidates = gd::duplicate_array(state, pool);
	const Atom session_id = gd::stringify(state, gd::index(state, session, str(key::session_id)));
	const Atom seed_text = gd::format(state, key::s_s_ai_tavern_d, { str(session_id), str(controller), int_value(week) });
	const Value rng = turn::seeded_rng(state, gd::hash(state, str(seed_text)));
	for (int64_t index = state.array_size(candidates) - 1; index > 0; --index) {
		const int64_t swap = gd::rng_randi_range(state, rng, 0, index);
		const Value held = state.at(candidates, index);
		state.set_at(candidates, index, state.at(candidates, swap));
		state.set_at(candidates, swap, held);
	}
	const ArrayRef offer = gd::slice(state, candidates, 0, compat::engine_min<int64_t>(kTavernOfferSize, state.array_size(candidates)));
	const DictRef tavern = state.new_dict();
	state.set(tavern, str(key::week), int_value(week));
	state.set(tavern, str(key::hero_ids), array_value(gd::duplicate_array(state, offer)));
	state.set(state_, str(key::ai_tavern), dict_value(tavern));
	return offer;
}

ArrayRef _tavern_pool(State &state, DictRef session, DictRef state_, Atom controller) {
	const DictRef taken = state.new_dict();
	for (const Value &hero : gd::field_items(state, session_view::overworld(state, session), str(key::player_heroes))) {
		if (gd::is_dict(hero)) {
			state.set(taken, str(ai::string_or_empty(state, hero.ref, key::id)), bool_value(true));
		}
	}
	const DictRef resolved = _resolved_lookup(state, session);
	for (const Value &entry : gd::field_items(state, session_view::overworld(state, session), str(key::encounters))) {
		if (gd::is_dict(entry) && !state.has(resolved, str(ai::string_or_empty(state, entry.ref, key::placement_id)))) {
			Value commander;
			if (!state.lookup(entry.ref, str(key::enemy_commander_state), commander)) {
				// {}.get("roster_hero_id", "")
				state.set(taken, str(key::empty), bool_value(true));
			} else if (gd::is_dict(commander)) {
				state.set(taken, str(ai::string_or_empty(state, commander.ref, key::roster_hero_id)), bool_value(true));
			}
		}
	}
	for (const Value &roster_entry : gd::field_items(state, state_, str(key::commander_roster))) {
		if (gd::is_dict(roster_entry) && ai::string_or_empty(state, roster_entry.ref, key::status) == key::recovering && gd::int_field(state, roster_entry.ref, key::recovery_day, 0) > ai::session_int(state, session, key::day)) {
			state.set(taken, str(ai::string_or_empty(state, roster_entry.ref, key::roster_hero_id)), bool_value(true));
		}
	}
	const ArrayRef pool = state.new_array();
	const DictRef faction = gd::content_row(state, ContentTable::Faction, player_identity_rules::faction_id(state, session, controller));
	for (const Value &hero_id : gd::field_items(state, faction, str(key::hero_ids))) {
		const Atom id = gd::stringify(state, hero_id);
		if (id != key::empty && !state.has(taken, str(id)) && !gd::is_empty(state, gd::content_row(state, ContentTable::Hero, id))) {
			state.append(pool, str(id));
		}
	}
	// pool.sort() of Strings: code point order, which is UTF-8 byte order.
	gd::sort_custom(state, pool, [&state](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
	return pool;
}

DictRef _hire_hero(State &state, DictRef session, DictRef context) {
	const DictRef state_ = context_state(state, context);
	const Atom controller = context_controller(state, context);
	const DictRef treasury = gd::as_dict(gd::index(state, state_, str(key::treasury)));
	if (active_hero_count(state, session, controller) >= kHeroLimit) {
		return state.new_dict();
	}
	const ArrayRef offer = ai_tavern_offer_ids(state, session, state_, controller);
	if (state.array_size(offer) == 0) {
		return state.new_dict();
	}
	DictRef best_town = state.new_dict();
	double best_power = -1.0;
	const ArrayRef entries = enemy_turn_rules::_owned_town_entries(state, session, controller);
	for (int64_t at = 0; at < state.array_size(entries); ++at) {
		const DictRef town = gd::as_dict(vget_or_new_dict(state, state.at(entries, at), key::town));
		if (!hero_command_rules::town_has_hall(state, town) || !_town_entrance_free(state, session, town, controller)) {
			continue;
		}
		if (gd::int_field(state, town, key::last_hire_day, 0) == ai::session_int(state, session, key::day)) {
			continue;
		}
		const Value garrison = field_or_new_array(state, town, key::garrison);
		const double power = army_power(state, garrison, dict_value(state.new_dict()));
		if (power > best_power) {
			best_power = power;
			best_town = town;
		}
	}
	if (gd::is_empty(state, best_town)) {
		return state.new_dict();
	}
	Atom choice = key::empty;
	for (int64_t at = 0; at < state.array_size(offer); ++at) {
		const Value hero_id = state.at(offer, at);
		const DictRef cost = hero_command_rules::hero_recruit_cost(state, gd::content_row(state, ContentTable::Hero, gd::stringify(state, hero_id)));
		if (_can_afford(state, treasury, cost)) {
			choice = gd::stringify(state, hero_id);
			break;
		}
	}
	if (choice == key::empty) {
		return state.new_dict();
	}
	const DictRef cost = hero_command_rules::hero_recruit_cost(state, gd::content_row(state, ContentTable::Hero, choice));
	const DictRef hired = _create_hero(state, session, context, best_town, choice, state.new_array());
	if (gd::is_empty(state, hired)) {
		return state.new_dict();
	}
	enemy_turn_rules::_spend_from_pool(state, treasury, dict_value(cost));
	_economy_add(state, session, context_controller(state, context), key::hire_gold, gd::float_field(state, cost, key::gold, 0.0));
	Value tavern_value;
	const DictRef tavern = state.lookup(state_, str(key::ai_tavern), tavern_value) ? gd::as_dict(tavern_value) : state.new_dict();
	Value ids;
	const ArrayRef remaining = state.lookup(tavern, str(key::hero_ids), ids) && gd::is_array(ids) ? gd::duplicate_array(state, ids.ref) : state.new_array();
	ai::array_erase(state, remaining, str(choice));
	state.set(tavern, str(key::hero_ids), array_value(remaining));
	state.set(state_, str(key::ai_tavern), dict_value(tavern));
	const ArrayRef towns = overworld_towns(state, session);
	const int64_t town_index = gd::int_field(state, _find_town(state, session, ai::string_or_empty(state, best_town, key::placement_id)), key::index, -1);
	if (town_index >= 0) {
		const Value town = state.at(towns, town_index);
		if (!gd::is_dict(town)) {
			throw state::ScriptError(std::string("Invalid assignment of property or key 'last_hire_day' with value of type 'int' on a base object of type '") + gd::type_name(town) + "'.");
		}
		state.set(town.ref, str(key::last_hire_day), int_value(ai::session_int(state, session, key::day)));
		state.set(session_view::overworld(state, session), str(key::towns), array_value(towns));
	}
	return hired_result(state, hired);
}

DictRef _create_hero(State &state, DictRef session, DictRef context, DictRef town, Atom hero_id, ArrayRef start_stacks) {
	const Atom controller = context_controller(state, context);
	const DictRef state_ = context_state(state, context);
	const DictRef hero_template = gd::content_row(state, ContentTable::Hero, hero_id);
	if (gd::is_empty(state, hero_template)) {
		return state.new_dict();
	}
	const DictRef position = overworld_level_rules::town_entrance(state, town);
	// Level-up rolls come from the hero's growth seed: seed it from the session,
	// as the human's hires are, so the same game plays out the same way.
	const Atom seed_key = gd::format(state, key::s_s_d, { str(controller), str(hero_id), int_value(ai::session_int(state, session, key::day)) });
	const Atom growth_seed = hero_command_rules::new_growth_seed(state, seed_key, session);
	DictRef hero;
	if (state.array_size(start_stacks) != 0) {
		const DictRef army = state.new_dict();
		state.set(army, str(key::id), str(gd::format(state, key::s_army, { str(hero_id) })));
		state.set(army, str(key::name), str(key::field_army));
		state.set(army, str(key::stacks), array_value(start_stacks));
		hero = hero_command_rules::build_recruited_hero(state, hero_template, position, str(key::normal), 1, dict_value(army), key::empty, growth_seed);
	} else {
		const DictRef offer = hero_command_rules::tavern_offer(state, session, hero_id);
		const int64_t level = gd::int_field(state, offer, key::level, 1);
		const Value army = field_or_new_dict(state, offer, key::army);
		hero = hero_command_rules::build_recruited_hero(state, hero_template, position, str(key::normal), level, army, key::empty, growth_seed);
	}
	if (gd::is_empty(state, hero)) {
		return state.new_dict();
	}
	// hero.army.stacks.duplicate(true) if hero.army is Dictionary else []
	ArrayRef army_stacks = 0;
	Value hero_army;
	if (state.lookup(hero, str(key::army), hero_army) && gd::is_dict(hero_army)) {
		Value stacks;
		army_stacks = state.lookup(hero_army.ref, str(key::stacks), stacks) ? ai::typed_array(gd::duplicate_value(state, stacks, true), "AiHeroRules._create_hero: hero.army.stacks") : state.new_array();
	} else {
		army_stacks = state.new_array();
	}
	const DictRef roster_seed = _roster_progression_seed(state, state_, hero_id);
	const DictRef seed = gd::deep_duplicate_dict(state, hero);
	if (!gd::is_empty(state, roster_seed) && gd::int_field(state, roster_seed, key::level, 1) > gd::int_field(state, seed, key::level, 1)) {
		for (const Atom field : { key::level, key::experience, key::next_level_experience, key::command, key::specialties, key::spellbook, key::specialty_focus_ids }) {
			if (state.has(roster_seed, str(field))) {
				state.set(seed, str(field), gd::index(state, roster_seed, str(field)));
			}
		}
	}
	gd::merge(state, seed, player_identity_rules::identity_fields(state, session, controller), true);
	DictRef commander = enemy_adventure_rules::build_roster_commander_state(state, hero_id, controller, seed, dict_value(state.new_dict()));
	const Value template_movement = state.get(hero_template, str(key::base_movement), int_value(10));
	state.set(commander, str(key::base_movement), int_value(gd::to_int(state, state.get(hero, str(key::base_movement), template_movement))));
	commander = enemy_adventure_rules::_normalize_enemy_progression(state, commander);
	const int64_t counter = gd::add(gd::int_field(state, state_, key::ai_hero_counter, 0), 1);
	state.set(state_, str(key::ai_hero_counter), int_value(counter));
	const Atom placement_id = gd::format(state, key::s_hero_d, { str(controller), int_value(counter) });
	DictRef entry = state.new_dict();
	state.set(entry, str(key::placement_id), str(placement_id));
	state.set(entry, str(key::encounter_id), str(key::encounter_mire_raid));
	state.set(entry, str(key::x), int_value(gd::int_field(state, position, key::x, 0)));
	state.set(entry, str(key::y), int_value(gd::int_field(state, position, key::y, 0)));
	state.set(entry, str(key::level), int_value(overworld_level_rules::level_of(state, dict_value(position))));
	const Atom session_id = gd::stringify(state, gd::index(state, session, str(key::session_id)));
	const Atom combat_text = gd::format(state, key::s_d_s, { str(session_id), int_value(ai::session_int(state, session, key::day)), str(placement_id) });
	state.set(entry, str(key::combat_seed), int_value(gd::hash(state, str(combat_text))));
	state.set(entry, str(key::spawned_by_faction_id), str(player_identity_rules::faction_id(state, session, controller)));
	state.set(entry, str(key::spawned_by_player_id), str(ai::string_or_empty(state, player_identity_rules::player(state, session, controller), key::player_id)));
	const DictRef enemy_army = state.new_dict();
	state.set(enemy_army, str(key::id), str(gd::format(state, key::s_army, { str(placement_id) })));
	state.set(enemy_army, str(key::name), str(gd::format(state, key::s_s_army, { str(gd::stringify(state, state.get(commander, str(key::name), str(key::Hero)))) })));
	state.set(enemy_army, str(key::stacks), array_value(army_stacks));
	state.set(entry, str(key::enemy_army), dict_value(enemy_army));
	state.set(entry, str(key::enemy_commander_state), dict_value(commander));
	state.set(entry, str(key::days_active), int_value(0));
	const DictRef ai_hero = state.new_dict();
	state.set(ai_hero, str(key::hero_id), str(hero_id));
	const DictRef first_movement = state.new_dict();
	state.set(first_movement, str(key::current), int_value(0));
	state.set(first_movement, str(key::max), int_value(0));
	state.set(ai_hero, str(key::movement), dict_value(first_movement));
	state.set(ai_hero, str(key::home_town_id), str(ai::string_or_empty(state, town, key::placement_id)));
	state.set(ai_hero, str(key::hired_day), int_value(ai::session_int(state, session, key::day)));
	state.set(ai_hero, str(key::goal), dict_value(state.new_dict()));
	state.set(entry, str(key::ai_hero), dict_value(ai_hero));
	const int64_t movement_max = _movement_max(state, entry);
	const DictRef movement = state.new_dict();
	state.set(movement, str(key::current), int_value(movement_max));
	state.set(movement, str(key::max), int_value(movement_max));
	state.set(gd::as_dict(gd::index(state, entry, str(key::ai_hero))), str(key::movement), dict_value(movement));
	const bool fresh_hire = active_hero_count(state, session, controller) > 0;
	entry = _take_garrison(state, session, entry, town, context, fresh_hire);
	const Value stacks = vget_or_new_array(state, field_or_new_dict(state, entry, key::enemy_army), key::stacks);
	if (army_power(state, stacks, dict_value(state.new_dict())) <= 0.0) {
		// A hero never leaves town without troops.
		state.set(state_, str(key::ai_hero_counter), int_value(gd::sub(counter, 1)));
		return state.new_dict();
	}
	const ArrayRef encounters = ai::typed_array(field_or_new_array(state, session_view::overworld(state, session), key::encounters), "AiHeroRules._create_hero: session.overworld.encounters");
	state.append(encounters, dict_value(entry));
	state.set(session_view::overworld(state, session), str(key::encounters), array_value(encounters));
	overworld_rules::invalidate_spatial_lookup(state, session);
	overworld_turn_playback::action(state, dict_value(session), entry, key::is_hired);
	const DictRef target = state.new_dict();
	state.set(target, str(key::target_kind), str(key::town));
	state.set(target, str(key::target_placement_id), str(ai::string_or_empty(state, town, key::placement_id)));
	state.set(target, str(key::target_label), str(enemy_turn_rules::_town_name(state, town)));
	state.set(target, str(key::target_x), int_value(gd::int_field(state, town, key::x, 0)));
	state.set(target, str(key::target_y), int_value(gd::int_field(state, town, key::y, 0)));
	const Value label_source = gd::index(state, context, str(key::config));
	const Atom label = gd::stringify(state, ai::vget(state, label_source, key::label, str(controller)));
	const Atom name = hero_name(state, entry);
	const Atom town_name = enemy_turn_rules::_town_name(state, town);
	const Atom summary = gd::format(state, key::s_hires_s_at_s, { str(label), str(name), str(town_name) });
	const ArrayRef reason_codes = state.new_array();
	state.append(reason_codes, str(key::hero_hired));
	const DictRef event = _event(state, session, context, key::ai_hero_hired, entry, target, summary, reason_codes);
	const DictRef result = state.new_dict();
	state.set(result, str(key::entry), dict_value(entry));
	state.set(result, str(key::event), dict_value(event));
	return result;
}

DictRef _roster_progression_seed(State &state, DictRef state_, Atom hero_id) {
	for (const Value &entry : gd::field_items(state, state_, str(key::commander_roster))) {
		if (gd::is_dict(entry) && ai::string_or_empty(state, entry.ref, key::roster_hero_id) == hero_id) {
			Value commander;
			if (state.lookup(entry.ref, str(key::commander_state), commander) && gd::is_dict(commander)) {
				return commander.ref;
			}
			return state.new_dict();
		}
	}
	return state.new_dict();
}

DictRef _recruit_in_towns(State &state, DictRef session, DictRef context, DictRef reserve) {
	const ArrayRef events = state.new_array();
	const ArrayRef entries = enemy_turn_rules::_owned_town_entries(state, session, context_controller(state, context));
	for (int64_t at = 0; at < state.array_size(entries); ++at) {
		const int64_t index = gd::to_int(state, ai::vget(state, state.at(entries, at), key::index, int_value(-1)));
		ai::append_array(state, events, _recruit_town(state, session, context, index, reserve));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::events), array_value(events));
	state.set(result, str(key::messages), array_value(state.new_array()));
	return result;
}

void _append_all(State &state, ArrayRef target, const Value &values) {
	if (!gd::is_array(values)) {
		return;
	}
	for (const Value &value : gd::items(state, values)) {
		if (gd::is_dict(value) && gd::is_empty(state, value.ref)) {
			continue;
		}
		if (gd::is_string(value) && value.ref == key::empty) {
			continue;
		}
		state.append(target, value);
	}
}

} // namespace ai_hero_rules

} // namespace aurelion::rules::port
