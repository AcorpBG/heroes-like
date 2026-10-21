// PlayerIdentityRules: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/player_identity_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/session_view.hpp"

namespace aurelion::rules::port {

namespace {

using gd::Atom;
using gd::DictRef;
using gd::str;
using state::Kind;
using state::State;
namespace key = state::key;

} // namespace

namespace player_identity_rules {

Atom resource_controller_id(State &state, DictRef node) {
	const Atom player_id = ai::string_or_empty(state, node, key::collected_by_player_id);
	return player_id != key::empty ? player_id : ai::string_or_empty(state, node, key::collected_by_faction_id);
}

bool allied(State &state, const Value &session, Atom first, Atom second) {
	// The one-human runtime retains "player" in legacy interaction APIs.
	if (session.kind != Kind::Nil) {
		if (first == key::player) {
			first = gd::stringify(state, gd::field_or(state, session_view::overworld(state, session.ref), key::active_player_id, str(first)));
		}
		if (second == key::player) {
			second = gd::stringify(state, gd::field_or(state, session_view::overworld(state, session.ref), key::active_player_id, str(second)));
		}
	}
	if (first == key::empty || second == key::empty) {
		return false;
	}
	if (first == second) {
		return true;
	}
	// player(null, id) is {}.
	const DictRef first_player = session.kind == Kind::Nil ? state.new_dict() : player(state, session.ref, first);
	const DictRef second_player = session.kind == Kind::Nil ? state.new_dict() : player(state, session.ref, second);
	const Atom team = ai::string_or_empty(state, first_player, key::team_id);
	return team != key::empty && team == ai::string_or_empty(state, second_player, key::team_id);
}

} // namespace player_identity_rules

} // namespace aurelion::rules::port
