// PlayerEliminationRules.apply_daily: the days each player has gone without a
// town, counted once a day after every player has moved, a computer player
// removed when its time is up, and the human player's townless warnings and
// defeat.

#include "aurelion_rules/port/ai_hero_rules.hpp"
#include "aurelion_rules/port/ai_hero_rules_turn.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <string>

namespace aurelion::rules::port {

// Defined in enemy_states.cpp (Phase 5) and declared only where it is called.
namespace enemy_adventure_rules {
void normalize_all_commander_rosters(state::State &state, gd::DictRef session);
} // namespace enemy_adventure_rules

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;

[[noreturn]] void not_ported(const char *path) {
	throw state::NotPorted(std::string("left to GDScript: ") + path);
}

// String(d.get(key, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify_or_fallback(state, state.get(dict, str(field), str(fallback)));
}

// PlayerEliminationRules.TOWNLESS_DAYS.
constexpr int64_t kTownlessDays = 7;

// A computer player's heroes leave the map; its record stays, out of the game.
void _remove_computer_player(State &state, DictRef session, Atom player_id) {
	const ArrayRef entries = ai_hero_rules::active_hero_entries(state, session, player_id);
	for (int64_t index = 0; index < state.array_size(entries); ++index) {
		const DictRef entry = gd::as_dict(state.at(entries, index));
		ai_hero_rules::_mark_resolved(state, session, text(state, entry, key::placement_id, key::empty));
		ai_hero_rules::_record_hero_defeat(state, session, player_id, entry);
	}
}

// The human's defeat: the session's status and its summary, if it has none.
void _defeat_human(State &state, DictRef session, Atom summary) {
	state.set(gd::as_dict(gd::field(state, session, key::flags)), str(key::campaign), str(key::defeat));
	state.set(session, str(key::scenario_status), str(key::defeat));
	if (gd::to_string(gd::field(state, session, key::scenario_summary)) == key::empty) {
		state.set(session, str(key::scenario_summary), str(summary));
	}
}

} // namespace

namespace player_elimination_rules {

bool applies(State &state, DictRef session) {
	return gd::bool_field(state, gd::as_dict(gd::field(state, session, key::flags)), key::native_random_map_package_session_adoption, false);
}

int64_t towns_held(State &state, DictRef session, DictRef player) {
	const Atom player_id = text(state, player, key::player_id, key::empty);
	int64_t count = 0;
	for (const Value &town : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (!gd::is_dict(town)) {
			continue;
		}
		const Atom owner = text(state, town.ref, key::owner, key::neutral);
		if (gd::bool_field(state, player, key::human, false)) {
			if (owner == key::player) {
				count = gd::add(count, 1);
			}
		} else if (owner == key::enemy && player_identity_rules::town_controller_id(state, town.ref) == player_id) {
			count = gd::add(count, 1);
		}
	}
	return count;
}

int64_t heroes_held(State &state, DictRef session, DictRef player) {
	if (gd::bool_field(state, player, key::human, false)) {
		const Value heroes = state.get(session_view::overworld(state, session), str(key::player_heroes), array_value(state.new_array()));
		if (!gd::is_array(heroes)) {
			// (x as Array) of another type.
			not_ported("a human's heroes that are not an Array");
		}
		return state.array_size(heroes.ref);
	}
	return ai_hero_rules::active_hero_count(state, session, text(state, player, key::player_id, key::empty));
}

ArrayRef apply_daily(State &state, DictRef session) {
	const ArrayRef messages = state.new_array();
	if (!applies(state, session)) {
		return messages;
	}
	const DictRef overworld = session_view::overworld(state, session);
	Value since_value;
	const DictRef since = state.lookup(overworld, str(key::townless_since), since_value) && gd::is_dict(since_value) ? since_value.ref : state.new_dict();
	const int64_t day = gd::int_field(state, session, key::day, 0);
	bool rosters_settled = false;
	for (const Value &player : gd::field_items(state, overworld, str(key::players))) {
		if (!gd::is_dict(player)) {
			continue;
		}
		const Atom player_id = text(state, player.ref, key::player_id, key::empty);
		const bool human = gd::bool_field(state, player.ref, key::human, false);
		if (towns_held(state, session, player.ref) > 0) {
			state.erase(since, str(player_id));
			continue;
		}
		if (heroes_held(state, session, player.ref) == 0) {
			state.erase(since, str(player_id));
			if (human && text(state, session, key::scenario_status, key::empty) == key::in_progress) {
				_defeat_human(state, session, key::your_realm_has_no_town_and);
			}
			continue;
		}
		if (!state.has(since, str(player_id))) {
			state.set(since, str(player_id), int_value(day));
		}
		const int64_t left = gd::sub(kTownlessDays, gd::sub(day, gd::to_int(state, gd::index(state, since, str(player_id)))));
		if (left > 0) {
			if (human) {
				state.append(messages, str(gd::format(state, key::you_hold_no_town_take_one, { int_value(left), str(left == 1 ? key::empty : key::s) })));
			}
			continue;
		}
		state.erase(since, str(player_id));
		if (human) {
			_defeat_human(state, session, gd::format(state, key::your_realm_has_held_no_town, { int_value(kTownlessDays) }));
			continue;
		}
		if (!rosters_settled) {
			// The enemy turn leaves its rosters to the scenario check after this.
			enemy_adventure_rules::normalize_all_commander_rosters(state, session);
			rosters_settled = true;
		}
		_remove_computer_player(state, session, player_id);
		const Value name = state.get(gd::content_row(state, ContentTable::Faction, text(state, player.ref, key::faction_id, key::empty)), str(key::name), str(player_id));
		state.append(messages, str(gd::format(state, key::s_has_held_no_town_for_d_days_and_leaves_the_war, { name, int_value(kTownlessDays) })));
	}
	state.set(overworld, str(key::townless_since), dict_value(since));
	return messages;
}

} // namespace player_elimination_rules

} // namespace aurelion::rules::port
