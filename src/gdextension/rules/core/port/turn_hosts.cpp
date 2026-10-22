#include "aurelion_rules/port/turn_hosts.hpp"

#include "aurelion_rules/port/turn_port.hpp"

#include <initializer_list>

namespace aurelion::rules::port::ai_hero_rules {

namespace {

using state::Value;
namespace key = state::key;

// TurnEngine.host_call(target, session, [args]): the target runs with the
// session itself where its view is. TurnEngine.pure_host_call is the same
// call to a target that changes nothing the native call holds.
DictRef host_call(State &state, Atom host, Atom target, DictRef session, std::initializer_list<Value> args) {
	const uint32_t list = state.new_array();
	for (const Value &value : args) {
		state.append(list, value);
	}
	const Value result = gd::call_static(state, key::turn_engine_script, host, {gd::name_value(target), gd::dict_value(session), gd::array_value(list)});
	return gd::as_dict(result);
}

// HEROES_NATIVE_TURN_PREVIEW_HOST=full: previews as full host calls, for
// timing what the pure ones save (native mode only: shadow names the pure one).
Atom preview_host() {
	static const bool full = turn::environment("HEROES_NATIVE_TURN_PREVIEW_HOST") == "full";
	return full ? key::host_call : key::pure_host_call;
}

} // namespace

DictRef _simulate_battle(State &state, DictRef session, DictRef context, DictRef entry, DictRef defender, int64_t battle_number, int64_t stop_below_creatures) {
	return host_call(state, preview_host(), key::aiherorules_simulate_battle, session,
			{gd::dict_value(session), gd::dict_value(context), gd::dict_value(entry), gd::dict_value(defender), gd::int_value(battle_number), gd::int_value(stop_below_creatures)});
}

DictRef _start_player_battle(State &state, DictRef session, DictRef context, int64_t index, DictRef battle_context, Atom summary, DictRef target) {
	return host_call(state, key::host_call, key::aiherorules_start_player_battle, session,
			{gd::dict_value(session), gd::dict_value(context), gd::int_value(index), gd::dict_value(battle_context), gd::str(summary), gd::dict_value(target)});
}

} // namespace aurelion::rules::port::ai_hero_rules
