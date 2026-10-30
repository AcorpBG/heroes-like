// AiHeroRules: one computer player's day (run_faction_turn), its income and
// result, the weight sets in the static vars, the decision context and what the
// player sees and remembers.

#include "aurelion_rules/port/ai_hero_rules_turn.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_ai.hpp"
#include "aurelion_rules/port/enemy_adventure_rules_ai.hpp"
#include "aurelion_rules/port/enemy_town_services_turn.hpp"
#include "aurelion_rules/port/enemy_turn_rules.hpp"
#include "aurelion_rules/port/enemy_turn_rules_turn.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"
#include "aurelion_rules/port/visit_building_rules_ai.hpp"
#include "aurelion_rules/port/water_travel_rules.hpp"

#include <limits>
#include <string>
#include <vector>

namespace aurelion::rules::port {

// Ported in enemy_states.cpp (Phase 5) and declared in no header.
namespace enemy_turn_rules {
DictRef _normalize_resource_pool(State &state, const Value &value);
} // namespace enemy_turn_rules

namespace ai_hero_rules {
DictRef normalize_ai_heroes(State &state, DictRef session, Atom only_controller);
} // namespace ai_hero_rules

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
using state::State;
using state::Value;
namespace key = state::key;

// AiHeroRules.TOWN_SIGHT_RADIUS.
constexpr int64_t kTownSightRadius = 8;

// One tuning number of _apply_weights: Script.NAME = int(weights[field]) when
// whole, float(weights[field]) otherwise, in the GDScript order.
struct Weight {
	uint32_t name;
	uint32_t field;
	bool whole;
};

constexpr Weight kWeights[] = {
	{key::MAX_DECISIONS_PER_DAY, key::max_decisions_per_day, true},
	{key::SEARCH_DAYS, key::search_days, true},
	{key::FAR_SEARCH_DAYS, key::far_search_days, true},
	{key::STRATEGIC_DAYS, key::strategic_days, true},
	{key::MIN_SEARCH_RADIUS, key::min_search_radius, true},
	{key::MAX_GATES_WEIGHED, key::max_gates_weighed, true},
	{key::ROUTE_DETOUR, key::route_detour, false},
	{key::ROUTE_UNEXPLORED_MIN, key::route_unexplored_min, true},
	{key::ROUTE_REVISIT_DAYS, key::route_revisit_days, true},
	{key::SHORE_STEP_SHARE, key::shore_step_share, false},
	{key::BOAT_SAVING_DAYS, key::boat_saving_days, true},
	{key::GUARD_WIN_RATIO, key::guard_win_ratio, false},
	{key::HERO_ATTACK_RATIO, key::hero_attack_ratio, false},
	{key::TOWN_ATTACK_RATIO, key::town_attack_ratio, false},
	{key::THREAT_RATIO, key::threat_ratio, false},
	{key::TOWN_BASE_VALUE, key::town_base_value, false},
	{key::TOWN_HORIZON_WEEKS, key::town_horizon_weeks, false},
	{key::ELIMINATION_VALUE, key::elimination_value, false},
	{key::DEFENSE_HORIZON_DAYS, key::defense_horizon_days, true},
	{key::DEFENSE_MARGIN, key::defense_margin, false},
	{key::DEFENSE_SHARE_MAX, key::defense_share_max, false},
	{key::DEFENSE_SHARE_MAX_MAIN, key::defense_share_max_main, false},
	{key::JOIN_BASE_VALUE, key::join_base_value, false},
	{key::SPELL_BURST_PREVIEW_SHARE, key::spell_burst_preview_share, false},
	{key::HOMELESS_TOWN_MULTIPLIER, key::homeless_town_multiplier, false},
	{key::THREAT_KILL_SHARE, key::threat_kill_share, false},
	{key::DANGER_RATIO, key::danger_ratio, false},
	{key::GUARD_SHARE_MAX, key::guard_share_max, false},
	{key::MAIN_ARMY_SHARE, key::main_army_share, false},
	{key::TROOP_VALUE_PER_POWER, key::troop_value_per_power, false},
	{key::BUILD_HORIZON_WEEKS, key::build_horizon_weeks, false},
	{key::SHORT_RESOURCE_MULTIPLIER, key::short_resource_multiplier, false},
	{key::STARVED_TOWN_WEEKLY_TROOPS, key::starved_town_weekly_troops, false},
	{key::CLEAR_WIN_RATIO, key::clear_win_ratio, false},
	{key::LOSS_ESTIMATE_FACTOR, key::loss_estimate_factor, false},
	{key::LOSS_ESTIMATE_PER_RATIO, key::loss_estimate_per_ratio, false},
	{key::FREE_FIGHT_MAX_RATIO, key::free_fight_max_ratio, false},
	{key::MAX_FREE_FIGHT_PREVIEWS, key::max_free_fight_previews, true},
	{key::MAX_FIGHT_VETOES, key::max_fight_vetoes, true},
	{key::MAX_IDLE_PREVIEWS, key::max_idle_previews, true},
	{key::IDLE_FIGHT_MIN_KEPT, key::idle_fight_min_kept, false},
	{key::HOME_WAIT_RADIUS, key::home_wait_radius, true},
	{key::GOAL_CONTINUITY_BONUS, key::goal_continuity_bonus, false},
	{key::EXPLORE_VALUE, key::explore_value, false},
	{key::HUNT_EXPLORE_VALUE, key::hunt_explore_value, false},
	{key::HUNT_START_DAY, key::hunt_start_day, true},
	{key::HUNT_FULL_DAY, key::hunt_full_day, true},
	{key::SIGHTING_MEMORY_DAYS, key::sighting_memory_days, true},
	{key::PASSAGE_BASE_VALUE, key::passage_base_value, false},
	{key::PASSAGE_UNEXPLORED_TILE_VALUE, key::passage_unexplored_tile_value, false},
	{key::PASSAGE_KNOWN_SITE_SHARE, key::passage_known_site_share, false},
	{key::PASSAGE_VALUE_CAP, key::passage_value_cap, false},
	{key::HIDDEN_RIVAL_SHARE, key::hidden_rival_share, false},
	{key::HIDDEN_RIVAL_TILES, key::hidden_rival_tiles, true},
	{key::PASSAGE_TILE_CAP, key::passage_tile_cap, true},
	{key::SCROLL_SPELL_BASE_VALUE, key::scroll_spell_base_value, false},
	{key::SCROLL_SPELL_TIER_VALUE, key::scroll_spell_tier_value, false},
	{key::TILES_PER_EXPLORER, key::tiles_per_explorer, true},
	{key::HIRE_RESERVE_DAYS, key::hire_reserve_days, true},
	{key::EXPLORER_RESERVE_DAYS, key::explorer_reserve_days, true},
	{key::EXTRA_HERO_DAY, key::extra_hero_day, true},
	{key::STARVED_TOWN_TROOP_MULTIPLIER, key::starved_town_troop_multiplier, false},
	{key::MAGE_GUILD_BASE_VALUE, key::mage_guild_base_value, false},
	{key::MAGE_GUILD_TIER_VALUE, key::mage_guild_tier_value, false},
	{key::READINESS_VALUE, key::readiness_value, false},
	{key::OPENS_BUILDING_VALUE, key::opens_building_value, false},
	{key::UPGRADE_VALUE_WEEKS, key::upgrade_value_weeks, false},
	{key::UPGRADE_BASE_VALUE, key::upgrade_base_value, false},
	{key::THREAT_REACH_MARGIN, key::threat_reach_margin, true},
	{key::THREAT_MIN_REACH, key::threat_min_reach, true},
	{key::AVOID_DAYS, key::avoid_days, true},
	{key::GATE_HOME_DETOUR, key::gate_home_detour, true},
	{key::IDLE_FIGHT_DISTANCE_COST, key::idle_fight_distance_cost, false},
	{key::FIGHT_MIN_KEPT, key::fight_min_kept, false},
	{key::ARTIFACT_VALUE, key::artifact_value, false},
	{key::ARTIFACT_PRIZE_VALUE, key::artifact_prize_value, false},
	{key::PLAYER_HERO_KILL_VALUE, key::player_hero_kill_value, false},
	{key::AI_HERO_KILL_VALUE, key::ai_hero_kill_value, false},
	{key::HERO_KILL_TROOP_SHARE, key::hero_kill_troop_share, false},
	{key::HANDOVER_TROOP_SHARE, key::handover_troop_share, false},
	{key::GARRISON_PICKUP_SHARE, key::garrison_pickup_share, false},
	{key::COURIER_TROOP_SHARE, key::courier_troop_share, false},
	{key::MIN_TROOP_ERRAND_VALUE, key::min_troop_errand_value, false},
	{key::DWELLING_BASE_VALUE, key::dwelling_base_value, false},
	{key::DWELLING_WEEK_SHARE, key::dwelling_week_share, false},
	{key::VISIT_BUILDING_BASE_VALUE, key::visit_building_base_value, false},
	{key::SITE_INCOME_DAYS, key::site_income_days, false},
	{key::SITE_CONTROL_VALUE, key::site_control_value, false},
	{key::RIVAL_SITE_MULTIPLIER, key::rival_site_multiplier, false},
	{key::GUARD_FIGHT_BASE_VALUE, key::guard_fight_base_value, false},
	{key::GUARDED_VALUE_SHARE, key::guarded_value_share, false},
	{key::GUARDED_NEUTRAL_TOWN_VALUE, key::guarded_neutral_town_value, false},
	{key::GUARDED_RIVAL_TOWN_VALUE, key::guarded_rival_town_value, false},
	{key::HUMAN_TOWN_BONUS, key::human_town_bonus, false},
};

// var x: Dictionary = d.get(field, {}) where the {} is stored or written: the
// field's Dictionary, or a new one when the key is missing.
DictRef dict_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? gd::as_dict(found) : state.new_dict();
}

// var x: Array = d.get(field, []) where the [] is stored or written.
ArrayRef array_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? gd::as_array(found) : state.new_array();
}

// var x: Dictionary = value.get(field, {}) of an untyped value, only read: the
// field into found (false when missing). value must be a Dictionary.
bool read_dict_field(const State &state, const Value &value, Atom field, Value &found) {
	if (!gd::is_dict(value)) {
		(void)ai::vget(state, value, field);
	}
	if (!state.lookup(value.ref, str(field), found)) {
		return false;
	}
	(void)gd::as_dict(found);
	return true;
}

// Marshalls.raw_to_base64(bytes) (CryptoCore::b64_encode_str: mbedtls's
// base64, padded, on one line).
std::string raw_to_base64(const std::vector<uint8_t> &bytes) {
	static constexpr char kDigits[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	std::string out;
	out.reserve((bytes.size() + 2) / 3 * 4);
	size_t at = 0;
	for (; at + 2 < bytes.size(); at += 3) {
		const uint32_t n = static_cast<uint32_t>(bytes[at]) << 16 | static_cast<uint32_t>(bytes[at + 1]) << 8 | bytes[at + 2];
		out += kDigits[(n >> 18) & 63];
		out += kDigits[(n >> 12) & 63];
		out += kDigits[(n >> 6) & 63];
		out += kDigits[n & 63];
	}
	const size_t left = bytes.size() - at;
	if (left == 1) {
		const uint32_t n = static_cast<uint32_t>(bytes[at]) << 16;
		out += kDigits[(n >> 18) & 63];
		out += kDigits[(n >> 12) & 63];
		out += "==";
	} else if (left == 2) {
		const uint32_t n = static_cast<uint32_t>(bytes[at]) << 16 | static_cast<uint32_t>(bytes[at + 1]) << 8;
		out += kDigits[(n >> 18) & 63];
		out += kDigits[(n >> 12) & 63];
		out += kDigits[(n >> 6) & 63];
		out += '=';
	}
	return out;
}

} // namespace

namespace ai_hero_rules {

void _use_weights(State &state, DictRef state_) {
	Atom set_name = ai::string_or_empty(state, state_, key::ai_weight_set);
	if (set_name == key::empty) {
		set_name = key::default_set;
	}
	const int64_t revision = gd::content_revision(state);
	if (set_name == gd::to_string(gd::static_var(state, key::ai_hero_rules_script, key::_weight_set_name)) &&
			revision == ai::static_int(state, key::ai_hero_rules_script, key::_weight_set_revision)) {
		return;
	}
	if (revision != ai::static_int(state, key::ai_hero_rules_script, key::_weight_set_revision)) {
		gd::set_static_var(state, key::ai_hero_rules_script, key::_weight_sets, dict_value(state.new_dict()));
		gd::set_static_var(state, key::ai_hero_rules_script, key::_weight_set_revision, int_value(revision));
	}
	if (!state.has(ai::static_dict(state, key::ai_hero_rules_script, key::_weight_sets), str(set_name))) {
		const DictRef resolved = _resolved_weight_set(state, set_name);
		state.set(ai::static_dict(state, key::ai_hero_rules_script, key::_weight_sets), str(set_name), dict_value(resolved));
	}
	_apply_weights(state, gd::as_dict(gd::index(state, ai::static_dict(state, key::ai_hero_rules_script, key::_weight_sets), str(set_name))));
	gd::set_static_var(state, key::ai_hero_rules_script, key::_weight_set_name, str(set_name));
}

DictRef _resolved_weight_set(State &state, Atom set_name) {
	const DictRef sets = dict_or_new(state, gd::content_file(state, key::ai_hero_weights_path), key::sets);
	Value found;
	const DictRef resolved = state.lookup(sets, str(key::default_set), found) ? gd::as_dict(gd::duplicate_value(state, found, true)) : state.new_dict();
	if (set_name == key::default_set) {
		return resolved;
	}
	if (!gd::is_dict(gd::field(state, sets, set_name))) {
		state.print_error(state.text(gd::format(state, key::ai_weight_set_s_is_not, {str(set_name), str(key::ai_hero_weights_path)})));
		return resolved;
	}
	const DictRef changes = gd::as_dict(gd::index(state, sets, str(set_name)));
	for (const Value &change_key : gd::items(state, dict_value(changes))) {
		const Value change = gd::index(state, changes, change_key);
		if (gd::is_dict(change) && gd::is_dict(state.get(resolved, change_key, Value()))) {
			gd::merge(state, gd::as_dict(gd::index(state, resolved, change_key)), gd::as_dict(gd::index(state, changes, change_key)), true);
		} else {
			state.set(resolved, change_key, gd::index(state, changes, change_key));
		}
	}
	return resolved;
}

void _apply_weights(State &state, DictRef weights) {
	for (const Weight &weight : kWeights) {
		if (weight.whole) {
			ai::assign_int(state, key::ai_hero_rules_script, weight.name, weights, weight.field);
		} else {
			ai::assign_float(state, key::ai_hero_rules_script, weight.name, weights, weight.field);
		}
	}
	const DictRef resource_values = state.new_dict();
	const DictRef values = gd::as_dict(gd::index(state, weights, str(key::resource_values)));
	for (const Value &resource_key : gd::items(state, dict_value(values))) {
		const Atom resource_id = gd::stringify(state, resource_key);
		state.set(resource_values, str(resource_id), float_value(gd::to_float(gd::index(state, values, resource_key))));
	}
	gd::set_static_var(state, key::ai_hero_rules_script, key::RESOURCE_VALUES, dict_value(resource_values));
	enemy_adventure_rules::apply_ai_weights(state, weights);
	enemy_town_services::apply_ai_weights(state, weights);
	visit_building_rules::apply_ai_weights(state, weights);
	creature_dwelling_rules::apply_ai_weights(state, weights);
}

DictRef run_faction_turn(State &state, DictRef session, DictRef config, DictRef state_, bool should_apply_weekly_growth, bool profile_enabled) {
	const int64_t started = gd::ticks_usec();
	DictRef faction_state = state_;
	_use_weights(state, faction_state);
	const Atom controller = player_identity_rules::controller_id(state, config, key::empty);
	const ArrayRef messages = state.new_array();
	const ArrayRef events = state.new_array();
	const DictRef phases = state.new_dict();
	// state.get("treasury", {}): a missing pool normalizes as an empty one.
	const DictRef normalized_treasury = enemy_turn_rules::_normalize_resource_pool(state, gd::field(state, faction_state, key::treasury));
	state.set(faction_state, str(key::treasury), dict_value(normalized_treasury));
	const DictRef treasury = gd::as_dict(gd::index(state, faction_state, str(key::treasury)));
	// Armies a scenario placed for this player since the save migration also
	// play as heroes.
	normalize_ai_heroes(state, session, controller);
	// A hero defeated aboard a boat leaves it empty where it lay.
	water_travel_rules::normalize(state, session);
	const ArrayRef towns = array_or_new(state, session_view::overworld(state, session), key::towns);
	const ArrayRef town_entries = enemy_turn_rules::_owned_town_entries(state, session, controller);
	if (state.array_size(town_entries) == 0 && active_hero_count(state, session, controller) == 0) {
		state.set(faction_state, str(key::posture), str(key::collapsed));
		return _turn_result(state, faction_state, messages, events, profile_enabled, phases, started);
	}

	int64_t phase = gd::ticks_usec();
	const DictRef income = faction_daily_income(state, session, controller);
	_add_pool(state, treasury, dict_value(income));
	if (should_apply_weekly_growth && state.array_size(town_entries) != 0) {
		enemy_turn_rules::_apply_weekly_musters(state, session, town_entries, towns, controller, config);
		state.set(session_view::overworld(state, session), str(key::towns), array_value(towns));
	}
	_start_heroes_day(state, session, controller);
	_assign_field_heroes(state, session, controller);
	state.set(phases, str(key::economy_ms), int_value(_elapsed_ms(state, phase)));

	phase = gd::ticks_usec();
	const DictRef context = _new_context(state, session, config, faction_state);
	_reveal_from_holdings(state, session, context);
	_note_sightings(state, session, context);
	_ensure_opening_stockpile(state, session, context);
	// x.get("messages", []) only read: a missing list appends nothing.
	const DictRef start_result = _ensure_starting_hero(state, session, context);
	_append_all(state, messages, gd::field(state, start_result, key::messages));
	_append_all(state, events, gd::field(state, start_result, key::events));
	const DictRef town_result = _govern_towns(state, session, context);
	_append_all(state, messages, gd::field(state, town_result, key::messages));
	_append_all(state, events, gd::field(state, town_result, key::events));
	state.set(phases, str(key::towns_ms), int_value(_elapsed_ms(state, phase)));

	phase = gd::ticks_usec();
	// Lesser heroes move first, as a human moves couriers before the main army:
	// troops they hand over are with the main hero when it acts.
	const Atom main_id = _main_hero_id(state, session, controller);
	const ArrayRef hero_order = state.new_array();
	const ArrayRef entries = active_hero_entries(state, session, controller);
	for (const Value &entry : gd::items(state, array_value(entries))) {
		const DictRef hero = gd::as_dict(entry);
		const Atom id = ai::string_or_empty(state, hero, key::placement_id);
		const double power = ai::string_or_empty(state, hero, key::placement_id) == main_id ? std::numeric_limits<double>::infinity() : hero_power(state, hero);
		const DictRef item = state.new_dict();
		state.set(item, str(key::id), str(id));
		state.set(item, str(key::power), float_value(power));
		state.append(hero_order, dict_value(item));
	}
	gd::sort_custom(state, hero_order, [&state](const Value &a, const Value &b) {
		const double a_power = gd::to_float(ai::vmember(state, a, key::power));
		const double b_power = gd::to_float(ai::vmember(state, b, key::power));
		if (!gd::is_equal_approx(a_power, b_power)) {
			return a_power < b_power;
		}
		return gd::text(state, ai::vmember(state, a, key::id)) < gd::text(state, ai::vmember(state, b, key::id));
	});
	const ArrayRef hero_ids = state.new_array();
	for (const Value &item : gd::items(state, array_value(hero_order))) {
		state.append(hero_ids, ai::vmember(state, item, key::id));
	}
	bool battle_started = false;
	// By index: a hero's day may fight (a host call).
	for (int64_t at = 0; at < state.array_size(hero_ids); ++at) {
		const Value placement_id = state.at(hero_ids, at);
		if (!gd::is_empty(state, gd::as_dict(gd::index(state, session, str(key::battle))))) {
			break;
		}
		const DictRef hero_result = _run_hero_day(state, session, context, gd::stringify(state, placement_id));
		_append_all(state, messages, gd::field(state, hero_result, key::messages));
		_append_all(state, events, gd::field(state, hero_result, key::events));
		if (gd::bool_field(state, hero_result, key::battle_started, false)) {
			battle_started = true;
			break;
		}
	}
	state.set(phases, str(key::heroes_ms), int_value(_elapsed_ms(state, phase)));
	state.set(phases, str(key::searches), int_value(gd::int_field(state, context, key::search_count, 0)));
	state.set(phases, str(key::auto_battles), int_value(gd::int_field(state, context, key::auto_battle_count, 0)));
	state.set(phases, str(key::fight_previews), int_value(gd::int_field(state, context, key::preview_count, 0)));
	Value profile;
	if (state.lookup(context, str(key::profile), profile)) {
		if (!gd::is_dict(profile)) {
			throw state::ScriptError(std::string("Invalid call. Nonexistent function 'keys' in base '") + gd::type_name(profile) + "'.");
		}
		const ArrayRef profile_keys = gd::keys(state, profile.ref);
		for (const Value &profile_key : gd::items(state, array_value(profile_keys))) {
			const Value spent = ai::vindex(state, gd::index(state, context, str(key::profile)), profile_key);
			state.set(phases, profile_key, int_value(compat::float_to_int(compat::godot_round(gd::to_float(spent)))));
		}
	}
	// What the heroes see where they ended the day.
	_note_sightings(state, session, context);
	_store_explored(state, context);
	if (gd::bool_field(state, context, key::topology_changed, false)) {
		overworld_rules::_refresh_blocked_tile_index(state, session);
	}
	overworld_rules::invalidate_spatial_lookup(state, session);
	// Site claims may replace the treasury dictionary; context.state holds the
	// current one.
	faction_state = gd::as_dict(gd::index(state, context, str(key::state)));
	const Atom posture = battle_started ? key::attacking : _posture(state, session, controller);
	state.set(faction_state, str(key::posture), str(posture));
	// Abstract pressure no longer drives anything; clear what older saves held.
	state.set(faction_state, str(key::pressure), int_value(0));
	return _turn_result(state, faction_state, messages, events, profile_enabled, phases, started);
}

DictRef _turn_result(State &state, DictRef state_, ArrayRef messages, ArrayRef events, bool profile_enabled, DictRef phases, int64_t started) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::state), dict_value(state_));
	state.set(result, str(key::messages), array_value(messages));
	state.set(result, str(key::events), array_value(events));
	if (profile_enabled) {
		state.set(phases, str(key::total_ms), int_value(_elapsed_ms(state, started)));
		const Atom faction_id = ai::string_or_empty(state, state_, key::faction_id);
		const Atom player_id = ai::string_or_empty(state, state_, key::player_id);
		const DictRef profile = state.new_dict();
		state.set(profile, str(key::faction_id), str(faction_id));
		state.set(profile, str(key::player_id), str(player_id));
		state.set(profile, str(key::phases_ms), dict_value(phases));
		state.set(profile, str(key::event_count), int_value(state.array_size(events)));
		state.set(result, str(key::profile), dict_value(profile));
	}
	return result;
}

Atom _posture(State &state, DictRef session, Atom controller) {
	const ArrayRef entries = active_hero_entries(state, session, controller);
	for (const Value &entry : gd::items(state, array_value(entries))) {
		// entry.get(AI_HERO_KEY, {}).get("goal", {}): missing is an empty goal.
		Atom kind = key::empty;
		Value block;
		if (state.lookup(gd::as_dict(entry), str(key::ai_hero), block)) {
			Value goal;
			if (read_dict_field(state, block, key::goal, goal)) {
				kind = ai::string_or_empty(state, goal.ref, key::kind);
			}
		}
		if (kind == key::hero || kind == key::town_hostile) {
			return key::attacking;
		}
	}
	return active_hero_count(state, session, controller) > 0 ? key::expanding : key::building;
}

DictRef faction_daily_income(State &state, DictRef session, Atom controller) {
	const DictRef income = state.new_dict();
	for (const Value &town : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (gd::is_dict(town) && ai::string_or_empty(state, town.ref, key::owner) == key::enemy && player_identity_rules::town_controller_id(state, town.ref) == controller) {
			_add_pool(state, income, dict_value(overworld_rules::town_income(state, town.ref, dict_value(session))));
		}
	}
	_add_pool(state, income, dict_value(overworld_rules::controlled_resource_site_income(state, session, controller, -1)));
	const ArrayRef entries = active_hero_entries(state, session, controller);
	for (const Value &entry : gd::items(state, array_value(entries))) {
		const DictRef commander = dict_or_new(state, gd::as_dict(entry), key::enemy_commander_state);
		// .get("daily_income", {}) only read: a missing one adds nothing.
		_add_pool(state, income, gd::field(state, artifact_rules::aggregate_bonuses(state, commander), key::daily_income));
		_add_pool(state, income, dict_value(hero_progression_rules::daily_income_bonus(state, commander)));
	}
	return income;
}

void _start_heroes_day(State &state, DictRef session, Atom controller) {
	const ArrayRef encounters = array_or_new(state, session_view::overworld(state, session), key::encounters);
	const int64_t day = ai::session_int(state, session, key::day);
	const bool new_week = visit_building_rules::week_index(state, day) != visit_building_rules::week_index(state, gd::sub(ai::session_int(state, session, key::day), 1));
	const int64_t count = state.array_size(encounters);
	for (int64_t index = 0; index < count; ++index) {
		const Value entry = state.at(encounters, index);
		if (!is_ai_hero(state, entry) || player_identity_rules::raid_controller_id(state, entry.ref) != controller ||
				_is_resolved(state, session, ai::string_or_empty(state, entry.ref, key::placement_id))) {
			continue;
		}
		const DictRef held_commander = dict_or_new(state, entry.ref, key::enemy_commander_state);
		if (new_week) {
			// VisitBuildings.WEEK_BONUSES.
			state.erase(held_commander, str(key::week_bonuses));
		}
		const DictRef commander = spell_rules::refresh_daily_mana(state, held_commander);
		state.set(entry.ref, str(key::enemy_commander_state), dict_value(commander));
		const DictRef block = dict_or_new(state, entry.ref, key::ai_hero);
		const int64_t movement_max = _movement_max(state, entry.ref);
		const DictRef movement = state.new_dict();
		state.set(movement, str(key::current), int_value(movement_max));
		state.set(movement, str(key::max), int_value(movement_max));
		state.set(block, str(key::movement), dict_value(movement));
		state.erase(block, str(key::visited_town_day));
		// A town lost overnight, or a hero no longer in it, ends the wait there.
		if (ai::string_or_empty(state, block, key::parked) != key::empty) {
			const Atom parked_town = gd::stringify(state, gd::index(state, block, str(key::parked)));
			const Atom parked_hero = _parked_hero_id(state, session, controller, parked_town);
			if (parked_hero != ai::string_or_empty(state, entry.ref, key::placement_id)) {
				state.erase(block, str(key::parked));
			}
		}
		state.set(entry.ref, str(key::ai_hero), dict_value(block));
		const int64_t days_active = compat::engine_max<int64_t>(0, gd::int_field(state, entry.ref, key::days_active, 0));
		state.set(entry.ref, str(key::days_active), int_value(gd::add(days_active, 1)));
		state.set_at(encounters, index, entry);
	}
	state.set(session_view::overworld(state, session), str(key::encounters), array_value(encounters));
}

DictRef _new_context(State &state, DictRef session, DictRef config, DictRef state_) {
	_use_weights(state, state_);
	const Atom controller = player_identity_rules::controller_id(state, config, key::empty);
	const Vector2i map_size = overworld_rules::derive_map_size(state, session);
	const DictRef levels = _shared_level_surfaces(state, session);
	const DictRef context = state.new_dict();
	state.set(context, str(key::config), dict_value(config));
	state.set(context, str(key::state), dict_value(state_));
	state.set(context, str(key::controller), str(controller));
	state.set(context, str(key::map_size), Value::of_vector2i(map_size.x, map_size.y));
	state.set(context, str(key::levels), dict_value(levels));
	state.set(context, str(key::search_count), int_value(0));
	state.set(context, str(key::auto_battle_count), int_value(0));
	state.set(context, str(key::topology_changed), bool_value(false));
	return context;
}

DictRef _shared_level_surfaces(State &state, DictRef session) {
	const Atom session_id = gd::stringify(state, gd::index(state, session, str(key::session_id)));
	const Atom scenario_id = gd::stringify(state, gd::index(state, session, str(key::scenario_id)));
	const int64_t day = ai::session_int(state, session, key::day);
	// session.overworld.get(field, []).size(): a missing list counts 0.
	Value found;
	const int64_t node_count = state.lookup(session_view::overworld(state, session), str(key::resource_nodes), found) ? ai::vsize(state, found) : 0;
	const int64_t town_count = state.lookup(session_view::overworld(state, session), str(key::towns), found) ? ai::vsize(state, found) : 0;
	const Atom cache_key = gd::format(state, key::s_s_d_d_d, {str(session_id), str(scenario_id), int_value(day), int_value(node_count), int_value(town_count)});
	if (cache_key != gd::to_string(gd::static_var(state, key::ai_hero_rules_script, key::_surface_cache_key))) {
		gd::set_static_var(state, key::ai_hero_rules_script, key::_surface_cache_key, str(cache_key));
		gd::set_static_var(state, key::ai_hero_rules_script, key::_surface_cache, dict_value(state.new_dict()));
	}
	return ai::static_dict(state, key::ai_hero_rules_script, key::_surface_cache);
}

void clear_shared_surfaces(State &state) {
	gd::set_static_var(state, key::ai_hero_rules_script, key::_surface_cache_key, str(key::empty));
	gd::set_static_var(state, key::ai_hero_rules_script, key::_surface_cache, dict_value(state.new_dict()));
	gd::set_static_var(state, key::ai_hero_rules_script, key::_guard_cache, dict_value(state.new_dict()));
	gd::set_static_var(state, key::ai_hero_rules_script, key::_guard_index, dict_value(state.new_dict()));
}

void _note_sightings(State &state, DictRef session, DictRef context) {
	const int64_t day = ai::session_int(state, session, key::day);
	// context.state.get(SIGHTINGS_KEY, {}): a missing memory keeps nothing.
	const Value known = ai::vget(state, gd::index(state, context, str(key::state)), key::ai_sightings, Value());
	const DictRef kept = state.new_dict();
	if (gd::is_dict(known)) {
		const ArrayRef ids = gd::keys(state, known.ref);
		for (const Value &id : gd::items(state, array_value(ids))) {
			const Value seen = gd::index(state, known.ref, id);
			if (!gd::is_dict(seen)) {
				continue;
			}
			const int64_t memory_days = ai::static_int(state, key::ai_hero_rules_script, key::SIGHTING_MEMORY_DAYS);
			const int64_t seen_day = gd::int_field(state, seen.ref, key::day, gd::neg(memory_days));
			if (gd::add(seen_day, ai::static_int(state, key::ai_hero_rules_script, key::SIGHTING_MEMORY_DAYS)) > day) {
				state.set(kept, str(gd::stringify(state, id)), seen);
			}
		}
	}
	const Atom controller = gd::stringify(state, gd::index(state, context, str(key::controller)));
	const ArrayRef hostiles = _hostile_heroes(state, session, controller);
	for (const Value &hostile : gd::items(state, array_value(hostiles))) {
		if (gd::stringify(state, ai::vmember(state, hostile, key::id)) == key::empty) {
			continue;
		}
		const Atom id = gd::stringify(state, ai::vmember(state, hostile, key::id));
		const Atom owner = gd::stringify(state, ai::vmember(state, hostile, key::owner));
		const double power = compat::snappedf(gd::to_float(ai::vmember(state, hostile, key::power)), 0.1);
		const DictRef record = state.new_dict();
		state.set(record, str(key::owner), str(owner));
		state.set(record, str(key::power), float_value(power));
		state.set(record, str(key::day), int_value(day));
		// Where it stood and how far it goes in a turn (_recent_hostiles).
		for (const Atom field : {key::x, key::y, key::level, key::reach}) {
			state.set(record, str(field), ai::vmember(state, hostile, field));
		}
		// Seen again, it is still the hero that took the town.
		Value earlier;
		if (state.lookup(kept, str(id), earlier) && gd::is_dict(earlier) && state.has(earlier.ref, str(key::taken_day))) {
			for (const Atom field : {key::town, key::taken_day}) {
				state.set(record, str(field), gd::index(state, earlier.ref, str(field)));
			}
		}
		state.set(kept, str(id), dict_value(record));
	}
	state.set(gd::as_dict(gd::index(state, context, str(key::state))), str(key::ai_sightings), dict_value(kept));
}

void _store_explored(State &state, DictRef context) {
	// context.get("explored", {}): none kept, nothing to store.
	Value found;
	if (!state.lookup(context, str(key::explored), found)) {
		return;
	}
	const DictRef maps = gd::as_dict(found);
	if (gd::is_empty(state, maps)) {
		return;
	}
	const Value enemy_state = gd::index(state, context, str(key::state));
	const Value existing = ai::vget(state, enemy_state, key::ai_explored, Value());
	const DictRef stored = gd::is_dict(existing) ? existing.ref : state.new_dict();
	const ArrayRef levels = gd::keys(state, maps);
	for (const Value &level : gd::items(state, array_value(levels))) {
		const PackedRef tiles = gd::as_bytes(gd::index(state, maps, level));
		const int64_t size = gd::packed_size(state, tiles);
		std::vector<uint8_t> bits(static_cast<size_t>((size + 7) / 8), 0);
		const uint8_t *tile_bytes = gd::packed_bytes(state, tiles);
		for (int64_t index = 0; index < size; ++index) {
			if (tile_bytes[index] != 0) {
				bits[static_cast<size_t>(index >> 3)] = static_cast<uint8_t>(bits[static_cast<size_t>(index >> 3)] | (1 << (index & 7)));
			}
		}
		const std::string encoded = raw_to_base64(bits);
		if (encoded.empty()) {
			// Marshalls.raw_to_base64 of an empty array: ERR_FAIL_COND_V.
			state.print_error("Condition \"ret.is_empty()\" is true. Returning: ret");
		}
		const Atom level_key = gd::stringify(state, level);
		state.set(stored, str(level_key), str(state.intern(encoded)));
	}
	state.set(gd::as_dict(gd::index(state, context, str(key::state))), str(key::ai_explored), dict_value(stored));
}

void _reveal_from_holdings(State &state, DictRef session, DictRef context) {
	const Atom controller = gd::stringify(state, gd::index(state, context, str(key::controller)));
	for (const Value &town : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (gd::is_dict(town) && ai::string_or_empty(state, town.ref, key::owner) == key::enemy && player_identity_rules::town_controller_id(state, town.ref) == controller) {
			_reveal(state, session, context, overworld_level_rules::town_entrance(state, town.ref), kTownSightRadius);
		}
	}
	const ArrayRef entries = active_hero_entries(state, session, controller);
	for (const Value &entry : gd::items(state, array_value(entries))) {
		const DictRef point = overworld_level_rules::position(state, gd::as_dict(entry));
		const int64_t radius = _sight_radius(state, gd::as_dict(entry));
		_reveal(state, session, context, point, radius);
	}
}

int64_t _elapsed_ms(State &state, int64_t started) {
	(void)state;
	return compat::float_to_int(compat::godot_round(static_cast<double>(gd::sub(gd::ticks_usec(), started)) / 1000.0));
}

} // namespace ai_hero_rules

} // namespace aurelion::rules::port
