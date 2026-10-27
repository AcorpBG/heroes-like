// AiSeatRules: the seats the computer plays in place of the human (an
// AI-against-AI evaluation, a spectated game), ported under the GDScript names.
// The seat keeps its identity, towns and treasury. Its towns become computer
// towns and its heroes leave the map, so on its first turn it starts as every
// computer player does: a start hero with the faction's start army at its
// capital. Nothing ends such a match by itself; standing_players() says who is
// left.

#include "aurelion_rules/port/ai_seat_rules.hpp"

#include "aurelion_rules/port/ai_hero_rules.hpp"
#include "aurelion_rules/port/enemy_turn_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

namespace aurelion::rules::port::ai_seat_rules {

namespace {

using gd::str;
using state::Value;
namespace key = state::key;

// String(record.get(name, "")).
Atom text(State &state, DictRef record, Atom name) {
	return gd::stringify(state, state.get(record, str(name), str(key::empty)));
}

// session.overworld.get(name, []): read again after each call that may
// replace it.
Value overworld_array(State &state, DictRef session, Atom name) {
	return state.get(session_view::overworld(state, session), str(name), gd::array_value(state.new_array()));
}

} // namespace

Atom hand_human_seat_to_ai(State &state, DictRef session) {
	if (!player_identity_rules::has_human_seat(state, session)) {
		return key::empty;
	}
	const Atom seat = text(state, session_view::overworld(state, session), key::active_player_id);
	const Value players = overworld_array(state, session, key::players);
	bool found = false;
	for (const Value &record : gd::items(state, players)) {
		if (gd::is_dict(record) && text(state, record.ref, key::player_id) == seat) {
			state.set(record.ref, str(key::human), gd::bool_value(false));
			state.set(record.ref, str(key::computer), gd::bool_value(true));
			state.set(record.ref, str(key::owner), str(key::enemy));
			found = true;
		}
	}
	if (!found) {
		return key::empty;
	}
	state.set(session_view::overworld(state, session), str(key::players), players);
	const ArrayRef towns = gd::duplicate_array(state, gd::as_array(overworld_array(state, session, key::towns)));
	for (const Value &town : gd::items(state, gd::array_value(towns))) {
		if (gd::is_dict(town) && text(state, town.ref, key::owner) == key::player) {
			overworld_rules::transition_town_control(state, session, text(state, town.ref, key::placement_id), key::enemy, seat, key::ai_seat);
		}
	}
	const DictRef overworld = session_view::overworld(state, session);
	const DictRef treasury = gd::deep_duplicate_dict(state, gd::as_dict(state.get(overworld, str(key::resources), gd::dict_value(state.new_dict()))));
	const DictRef emptied = state.new_dict();
	for (const Atom resource : { key::gold, key::wood, key::ore }) {
		state.set(emptied, str(resource), gd::int_value(0));
	}
	state.set(overworld, str(key::resources), gd::dict_value(emptied));
	state.set(overworld, str(key::player_heroes), gd::array_value(state.new_array()));
	state.set(overworld, str(key::active_hero_id), str(key::empty));
	state.set(session, str(key::hero_id), str(key::empty));
	overworld_rules::normalize_overworld_state(state, session);
	const Value states = overworld_array(state, session, key::enemy_states);
	for (const Value &entry : gd::items(state, states)) {
		if (gd::is_dict(entry) && player_identity_rules::controller_id(state, entry.ref, key::empty) == seat) {
			state.set(entry.ref, str(key::treasury), gd::dict_value(treasury));
		}
	}
	state.set(session_view::overworld(state, session), str(key::enemy_states), states);
	overworld_rules::invalidate_spatial_lookup(state, session);
	return seat;
}

ArrayRef standing_players(State &state, DictRef session) {
	const ArrayRef result = state.new_array();
	for (const Value &record : gd::items(state, overworld_array(state, session, key::players))) {
		if (!gd::is_dict(record)) {
			continue;
		}
		const Atom player_id = text(state, record.ref, key::player_id);
		if (state.array_size(enemy_turn_rules::_owned_town_entries(state, session, player_id)) != 0 ||
				ai_hero_rules::active_hero_count(state, session, player_id) > 0) {
			state.append(result, str(player_id));
		}
	}
	return result;
}

bool match_over(State &state, DictRef session) {
	const ArrayRef standing = standing_players(state, session);
	const int64_t size = state.array_size(standing);
	for (int64_t index = 0; index < size; ++index) {
		if (!player_identity_rules::allied(state, gd::dict_value(session), gd::stringify(state, state.at(standing, 0)),
					gd::stringify(state, state.at(standing, index)))) {
			return false;
		}
	}
	return true;
}

} // namespace aurelion::rules::port::ai_seat_rules
