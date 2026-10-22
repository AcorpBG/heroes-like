// PlayerEliminationRules.apply_daily: the days each player has gone without a
// town, counted once a day after every player has moved. The paths AI matches
// never run are left to GDScript (state::NotPorted): the human player's
// townless warnings and defeat, and a computer player's removal when its time
// is up (a few times a game).

#include "aurelion_rules/port/ai_hero_rules.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <string>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
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
				// _defeat_human.
				not_ported("a human with no town and no hero");
			}
			continue;
		}
		if (!state.has(since, str(player_id))) {
			state.set(since, str(player_id), int_value(day));
		}
		const int64_t left = gd::sub(kTownlessDays, gd::sub(day, gd::to_int(state, gd::index(state, since, str(player_id)))));
		if (left > 0) {
			if (human) {
				// The townless warning.
				not_ported("a townless human's warning");
			}
			continue;
		}
		// The human's defeat, or a computer player's removal:
		// normalize_all_commander_rosters, _remove_computer_player and its message.
		not_ported("a player whose townless days are up");
	}
	state.set(overworld, str(key::townless_since), dict_value(since));
	return messages;
}

} // namespace player_elimination_rules

} // namespace aurelion::rules::port
