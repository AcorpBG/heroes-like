#pragma once

// The battle AI arena's router, natively (Phase 2c; tools/battle_ai_arena/router.py):
// battle_sim_cli plays each side's stacks with that side's AI weights. The
// GDScript router stands in for BattleAiRules.gd and routes each call the
// other scripts make into it, so the battle code wraps each of those calls in
// a route here, with the side the router picks (Backing::ai_route_enter): the
// side of its acting stack (router.py's STACK_PARAMS, then SIDE_PARAMS), the
// enemy for a function named after it, or none. The game routes nothing, and
// a route there costs one virtual call.

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::ai_route {

// _arena_side_of(stack): String(stack.get("side", "")) for a Dictionary, else "".
inline gd::Atom side_of(state::State &state, const state::Value &stack) {
	if (stack.kind != state::Kind::Dict) {
		return state::key::empty;
	}
	state::Value side;
	if (!state.lookup(stack.ref, gd::str(state::key::side), side)) {
		return state::key::empty;
	}
	return gd::stringify(state, side);
}

inline bool routing(const state::State &state) {
	return state.backing() != nullptr && state.backing()->routes_ai();
}

// Enters the side for the guard's lifetime.
class Route {
public:
	Route(state::State &state, gd::Atom side) :
			state_(state) {
		state.backing()->ai_route_enter(state, side);
	}
	Route(const Route &) = delete;
	Route &operator=(const Route &) = delete;
	~Route() { state_.backing()->ai_route_leave(state_); }

private:
	state::State &state_;
};

// call() routed by its acting stack.
template <typename Call>
decltype(auto) by_stack(state::State &state, const state::Value &stack, Call &&call) {
	if (!routing(state)) {
		return call();
	}
	const Route route(state, side_of(state, stack));
	return call();
}

// call() routed by a side the router names in code: key::enemy, or key::empty
// for shared plumbing (the default variant).
template <typename Call>
decltype(auto) by_side(state::State &state, gd::Atom side, Call &&call) {
	if (!routing(state)) {
		return call();
	}
	const Route route(state, side);
	return call();
}

} // namespace aurelion::rules::port::ai_route
