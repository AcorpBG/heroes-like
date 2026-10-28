// HeroCommandRules for the taverns (Phase 7, slice 7.6): the offers, their
// rotation and the heroes a scenario lets a player hire. Every tavern, a town's
// Wayfarer's Hall or a Wayfarer Lodge on the map, draws its own pair each week
// from the free heroes of every faction, its own faction's most often; the
// human and the computer players hire from the same taverns (owner, 2026-10-28).

#include "aurelion_rules/port/town_rules_actions.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/turn_port.hpp"

#include <cstddef>
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

// HeroCommandRules.TAVERN_OFFER_SIZE.
constexpr int64_t kTavernOfferSize = 2;
// A tavern draws heroes of its own faction this many times as often as those
// of any other: with eleven heroes a faction, about four offers in five are
// its own while they are free (owner, 2026-10-28).
constexpr int64_t kOwnFactionWeight = 20;

// a.sort() of an Array that holds only Strings (code point order, which is
// UTF-8 byte order).
void sort_strings(State &state, ArrayRef array) {
	gd::sort_custom(state, array, [&state](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
}

} // namespace

namespace hero_command_rules {

int64_t player_hero_count(State &state, DictRef session) {
	// session != null: a view is never null.
	return hero_count_from_overworld(state, dict_value(session_view::overworld(state, session)));
}

// Heroes some player leads or will lead again: the human's, the computer
// players' on the map and those recovering in a computer player's roster. No
// tavern offers them.
DictRef heroes_in_play(State &state, DictRef session) {
	const DictRef taken = state.new_dict();
	const DictRef overworld = session_view::overworld(state, session);
	for (const Value &hero : gd::field_items(state, overworld, str(key::player_heroes))) {
		if (gd::is_dict(hero)) {
			state.set(taken, str(ai::string_or_empty(state, hero.ref, key::id)), bool_value(true));
		}
	}
	for (const Value &entry : gd::field_items(state, overworld, str(key::encounters))) {
		if (!gd::is_dict(entry) || overworld_rules::is_encounter_resolved(state, session, entry.ref)) {
			continue;
		}
		Value commander;
		if (state.lookup(entry.ref, str(key::enemy_commander_state), commander) && gd::is_dict(commander)) {
			Atom hero_id = ai::string_or_empty(state, commander.ref, key::roster_hero_id);
			if (hero_id == key::empty) {
				hero_id = ai::string_or_empty(state, commander.ref, key::id);
			}
			if (hero_id != key::empty) {
				state.set(taken, str(hero_id), bool_value(true));
			}
		}
	}
	const int64_t day = ai::session_int(state, session, key::day);
	for (const Value &empire : gd::field_items(state, overworld, str(key::enemy_states))) {
		if (!gd::is_dict(empire)) {
			continue;
		}
		for (const Value &roster_entry : gd::field_items(state, empire.ref, str(key::commander_roster))) {
			if (gd::is_dict(roster_entry) && ai::string_or_empty(state, roster_entry.ref, key::status) == key::recovering && gd::int_field(state, roster_entry.ref, key::recovery_day, 0) > day) {
				state.set(taken, str(ai::string_or_empty(state, roster_entry.ref, key::roster_hero_id)), bool_value(true));
			}
		}
	}
	return taken;
}

ArrayRef tavern_draw(State &state, DictRef session, Atom site_id, Atom faction_id, int64_t other_weight) {
	const DictRef taken = heroes_in_play(state, session);
	std::vector<Atom> ids;
	std::vector<int64_t> weights;
	int64_t total = 0;
	for (const Value &id_value : gd::items(state, array_value(_tavern_roster(state, session)))) {
		const Atom hero_id = gd::stringify(state, id_value);
		const Atom hero_faction = gd::stringify(state, gd::field(state, gd::content_row(state, ContentTable::Hero, hero_id), key::faction_id));
		const int64_t weight = hero_faction == faction_id ? kOwnFactionWeight : other_weight;
		if (weight > 0) {
			ids.push_back(hero_id);
			weights.push_back(weight);
			total += weight;
		}
	}
	// The whole roster is drawn, free heroes or not, so a hire elsewhere moves
	// no other tavern's pair.
	const Atom fixed_seed = fixed_match_roll_seed(state, session);
	const Atom base = fixed_seed != key::empty ? fixed_seed : gd::stringify(state, gd::index(state, session, str(key::session_id)));
	const Atom seed_text = state.intern(state.text(base) + ":" + state.text(site_id) + ":tavern:" + std::to_string(tavern_week(state, session)));
	const Value rng = turn::seeded_rng(state, gd::hash(state, str(seed_text)));
	const ArrayRef offer = state.new_array();
	while (total > 0 && state.array_size(offer) < kTavernOfferSize) {
		int64_t roll = gd::rng_randi_range(state, rng, 0, total - 1);
		size_t at = 0;
		while (roll >= weights[at]) {
			roll -= weights[at];
			++at;
		}
		if (!state.has(taken, str(ids[at]))) {
			state.append(offer, str(ids[at]));
		}
		total -= weights[at];
		ids.erase(ids.begin() + static_cast<std::ptrdiff_t>(at));
		weights.erase(weights.begin() + static_cast<std::ptrdiff_t>(at));
	}
	return offer;
}

ArrayRef site_tavern_offer_ids(State &state, DictRef session, Atom site_id, Atom faction_id) {
	// A tavern where a hero was hired this week keeps what is left of its draw.
	Value stored;
	if (state.lookup(session_view::overworld(state, session), str(key::tavern_offers), stored) && gd::is_dict(stored) &&
			gd::int_field(state, stored.ref, key::week, -1) == tavern_week(state, session)) {
		Value sites;
		Value kept;
		if (state.lookup(stored.ref, str(key::sites), sites) && gd::is_dict(sites) && state.lookup(sites.ref, str(site_id), kept) && gd::is_array(kept)) {
			const DictRef taken = heroes_in_play(state, session);
			const ArrayRef offer = state.new_array();
			for (const Value &hero_id : gd::items(state, kept)) {
				if (!state.has(taken, str(gd::stringify(state, hero_id)))) {
					state.append(offer, str(gd::stringify(state, hero_id)));
				}
			}
			return offer;
		}
	}
	return tavern_draw(state, session, site_id, faction_id, 1);
}

ArrayRef tavern_offer_ids(State &state, DictRef session, DictRef town) {
	if (gd::is_empty(state, town)) {
		return state.new_array();
	}
	return site_tavern_offer_ids(state, session, ai::string_or_empty(state, town, key::placement_id), overworld_rules::_town_faction_id(state, town));
}

void take_tavern_offer(State &state, DictRef session, Atom site_id, ArrayRef offer, Atom hero_id) {
	const DictRef overworld = session_view::overworld(state, session);
	const int64_t week = tavern_week(state, session);
	DictRef sites = state.new_dict();
	Value stored;
	if (state.lookup(overworld, str(key::tavern_offers), stored) && gd::is_dict(stored) && gd::int_field(state, stored.ref, key::week, -1) == week) {
		Value found;
		if (state.lookup(stored.ref, str(key::sites), found) && gd::is_dict(found)) {
			sites = gd::deep_duplicate_dict(state, found.ref);
		}
	}
	const ArrayRef rest = gd::duplicate_array(state, offer);
	ai::array_erase(state, rest, str(hero_id));
	state.set(sites, str(site_id), array_value(rest));
	const DictRef record = state.new_dict();
	state.set(record, str(key::week), int_value(week));
	state.set(record, str(key::sites), dict_value(sites));
	state.set(overworld, str(key::tavern_offers), dict_value(record));
}

int64_t days_until_tavern_rotation(State &state, DictRef session) {
	// session != null: a view is never null.
	const int64_t day = compat::engine_max<int64_t>(1, ai::session_int(state, session, key::day));
	return 7 - compat::int_mod(gd::sub(day, 1), 7);
}

DictRef tavern_offer_preview(State &state, DictRef session, Atom hero_id) {
	const DictRef offer = tavern_offer(state, session, hero_id, -1);
	if (gd::is_empty(state, offer)) {
		return state.new_dict();
	}
	Value army;
	if (!state.lookup(offer, str(key::army), army)) {
		army = dict_value(state.new_dict());
	}
	return build_recruited_hero(state, gd::content_row(state, ContentTable::Hero, hero_id), state.new_dict(), dict_value(session), gd::int_field(state, offer, key::level, 1), army, key::empty, key::empty);
}

ArrayRef recruitable_hero_ids(State &state, DictRef session) {
	const DictRef taken = heroes_in_play(state, session);
	const ArrayRef recruitable = state.new_array();
	for (const Value &hero_id : gd::items(state, array_value(_tavern_roster(state, session)))) {
		if (!state.has(taken, str(gd::stringify(state, hero_id)))) {
			state.append(recruitable, hero_id);
		}
	}
	return recruitable;
}

ArrayRef _tavern_roster(State &state, DictRef session) {
	const ArrayRef roster = state.new_array();
	// session == null: a view is never null.
	const DictRef scenario = scenario_rules::scenario_record_for_session(state, session);
	for (const Value &faction : gd::field_items(state, gd::content_file(state, key::factions_path), str(key::items))) {
		if (!gd::is_dict(faction)) {
			continue;
		}
		for (const Value &hero_id_value : gd::field_items(state, faction.ref, str(key::hero_ids))) {
			const Atom hero_id = gd::stringify(state, hero_id_value);
			if (hero_id != key::empty && !gd::array_has(state, roster, str(hero_id)) && _hero_recruitable_for_scenario(state, hero_id, scenario)) {
				state.append(roster, str(hero_id));
			}
		}
	}
	sort_strings(state, roster);
	return roster;
}

ArrayRef _tavern_candidate_ids(State &state, DictRef session) {
	const ArrayRef recruitable = state.new_array();
	// session == null: a view is never null.
	const DictRef scenario = scenario_rules::scenario_record_for_session(state, session);
	const DictRef player_faction = gd::content_row(state, ContentTable::Faction, ai::string_or_empty(state, scenario, key::player_faction_id));
	for (const Value &hero_id_value : gd::field_items(state, player_faction, str(key::hero_ids))) {
		const Atom hero_id = gd::stringify(state, hero_id_value);
		if (hero_id == key::empty || gd::array_has(state, recruitable, str(hero_id))) {
			continue;
		}
		if (!_hero_recruitable_for_scenario(state, hero_id, scenario)) {
			continue;
		}
		state.append(recruitable, str(hero_id));
	}
	sort_strings(state, recruitable);
	return recruitable;
}

bool _hero_recruitable_for_scenario(State &state, Atom hero_id, DictRef scenario) {
	const DictRef hero = gd::content_row(state, ContentTable::Hero, hero_id);
	if (gd::is_empty(state, hero)) {
		return false;
	}
	if (gd::stringify(state, state.get(hero, str(key::roster_state), str(key::live))) != key::scaffold) {
		return true;
	}
	if (gd::bool_field(state, scenario, key::allow_scaffold_roster, false)) {
		return true;
	}
	for (const Value &start_id_value : gd::field_items(state, scenario, str(key::hero_starts))) {
		if (gd::stringify(state, start_id_value) == hero_id) {
			return true;
		}
	}
	return false;
}

int64_t hero_count_from_overworld(State &state, const Value &overworld_state) {
	if (!gd::is_dict(overworld_state)) {
		return 0;
	}
	// overworld_state.get("player_heroes", []): a missing list is [], an Array
	// of no heroes.
	Value player_heroes;
	if (!state.lookup(overworld_state.ref, str(key::player_heroes), player_heroes)) {
		return 0;
	}
	if (gd::is_array(player_heroes)) {
		return state.array_size(player_heroes.ref);
	}
	// overworld_state.get("hero", {}): a missing one is an empty Dictionary.
	Value hero;
	if (state.lookup(overworld_state.ref, str(key::hero), hero) && gd::is_dict(hero) && !gd::is_empty(state, hero.ref)) {
		return 1;
	}
	return 0;
}

} // namespace hero_command_rules

} // namespace aurelion::rules::port
