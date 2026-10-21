#pragma once

// The ported functions the GDScript switches reach (BattleEngine.gd and the
// other subsystems' engines), by their GDScript names: "BattleRules._hex_cell".
// Each takes its GDScript arguments as Values, converted as GDScript's typed
// parameters already did, and returns its GDScript result (Nil for void).
//
// Each subsystem registers its functions in a table of its own file (the
// battle port: core/port/registry.cpp), listed in core/port/registry_tables.cpp.

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

// One subsystem's functions.
struct Table {
	// The environment variable naming the folder for the shadow statistics
	// (HEROES_NATIVE_BATTLE_LOG).
	const char *log_variable;
	const Function *functions;
	size_t count;
};

// Every subsystem's table.
const Table *tables(size_t &count);
// Every table's functions in one array, in table order: a function's index in
// it is its slot in the adapter's statistics.
const Function *functions(size_t &count);
const Function *find_function(std::string_view name);

} // namespace aurelion::rules::port
