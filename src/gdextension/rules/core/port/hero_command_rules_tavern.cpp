// HeroCommandRules for the human seat's tavern (Phase 7, slice 7.6): the offers,
// their rotation and the heroes a scenario lets a player hire.

#include "aurelion_rules/port/town_rules_actions.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/turn_port.hpp"

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

ArrayRef tavern_offer_ids(State &state, DictRef session) {
	// session == null: a view is never null.
	const ArrayRef pool = recruitable_hero_ids(state, session);
	const int64_t week = tavern_week(state, session);
	// stored = session.overworld.get(TAVERN_ROTATION_KEY, {}): a missing one is
	// an empty Dictionary, whose week is -1 and whose hero_ids are [].
	Value stored;
	const bool has_stored = state.lookup(session_view::overworld(state, session), str(key::tavern_rotation), stored);
	bool keep = false;
	if (!has_stored) {
		keep = week == -1;
	} else if (gd::is_dict(stored) && gd::int_field(state, stored.ref, key::week, -1) == week) {
		Value hero_ids;
		keep = !state.lookup(stored.ref, str(key::hero_ids), hero_ids) || gd::is_array(hero_ids);
	}
	if (keep) {
		const ArrayRef kept = state.new_array();
		if (has_stored) {
			for (const Value &hero_id_value : gd::field_items(state, stored.ref, str(key::hero_ids))) {
				if (gd::array_has(state, pool, str(gd::stringify(state, hero_id_value)))) {
					state.append(kept, str(gd::stringify(state, hero_id_value)));
				}
			}
		}
		return kept;
	}
	// Shuffle every hireable hero, controlled ones included, so a change in who
	// is in command moves the weekly pair as little as possible.
	const ArrayRef candidates = _tavern_candidate_ids(state, session);
	const Atom session_id = gd::stringify(state, gd::index(state, session, str(key::session_id)));
	const Atom scenario_id = gd::stringify(state, gd::index(state, session, str(key::scenario_id)));
	const Atom seed_text = gd::format(state, key::s_s_tavern_d, {str(session_id), str(scenario_id), int_value(week)});
	const Value rng = turn::seeded_rng(state, gd::hash(state, str(seed_text)));
	for (int64_t index = state.array_size(candidates) - 1; index > 0; --index) {
		const int64_t swap = gd::rng_randi_range(state, rng, 0, index);
		const Value held = state.at(candidates, index);
		state.set_at(candidates, index, state.at(candidates, swap));
		state.set_at(candidates, swap, held);
	}
	const ArrayRef offer = state.new_array();
	for (const Value &hero_id_value : gd::items(state, array_value(candidates))) {
		if (gd::array_has(state, pool, str(gd::stringify(state, hero_id_value)))) {
			state.append(offer, str(gd::stringify(state, hero_id_value)));
			if (state.array_size(offer) >= kTavernOfferSize) {
				break;
			}
		}
	}
	return offer;
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
	const DictRef controlled = state.new_dict();
	// session != null: a view is never null.
	for (const Value &hero : gd::field_items(state, session_view::overworld(state, session), str(key::player_heroes))) {
		if (gd::is_dict(hero)) {
			state.set(controlled, str(ai::string_or_empty(state, hero.ref, key::id)), bool_value(true));
		}
	}
	const ArrayRef candidates = _tavern_candidate_ids(state, session);
	const ArrayRef recruitable = state.new_array();
	for (const Value &hero_id : gd::items(state, array_value(candidates))) {
		if (!state.has(controlled, str(gd::stringify(state, hero_id)))) {
			state.append(recruitable, hero_id);
		}
	}
	return recruitable;
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
