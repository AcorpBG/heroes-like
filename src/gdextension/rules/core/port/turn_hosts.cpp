#include "aurelion_rules/port/turn_hosts.hpp"

#include "aurelion_rules/port/turn_port.hpp"

#include <initializer_list>

namespace aurelion::rules::port::ai_hero_rules {

namespace {

using state::Value;
namespace key = state::key;

// TurnEngine.host_call(target, session, [args]): the target runs with the
// session itself where its view is.
DictRef host_call(State &state, Atom host, Atom target, DictRef session, std::initializer_list<Value> args) {
	const uint32_t list = state.new_array();
	for (const Value &value : args) {
		state.append(list, value);
	}
	const Value result = gd::call_static(state, key::turn_engine_script, host, {gd::name_value(target), gd::dict_value(session), gd::array_value(list)});
	return gd::as_dict(result);
}

} // namespace

DictRef _start_player_battle(State &state, DictRef session, DictRef context, int64_t index, DictRef battle_context, Atom summary, DictRef target) {
	return host_call(state, key::host_call, key::aiherorules_start_player_battle, session,
			{gd::dict_value(session), gd::dict_value(context), gd::int_value(index), gd::dict_value(battle_context), gd::str(summary), gd::dict_value(target)});
}

} // namespace aurelion::rules::port::ai_hero_rules
