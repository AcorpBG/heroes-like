#pragma once

// The ported battle functions the GDScript switch reaches (BattleEngine.gd),
// by their GDScript names: "BattleRules._hex_cell". Each takes its GDScript
// arguments as Values, converted as GDScript's typed parameters already did,
// and returns its GDScript result (Nil for void).

#include "aurelion_rules/battle_state.hpp"

#include <cstddef>
#include <string_view>

namespace aurelion::rules::port {

struct Function {
	const char *name;
	int arity;
	// Writes into its arguments: checked by comparing the arguments afterwards.
	bool mutates;
	state::Value (*call)(state::State &state, const state::Value *args);
};

const Function *functions(size_t &count);
const Function *find_function(std::string_view name);

} // namespace aurelion::rules::port
