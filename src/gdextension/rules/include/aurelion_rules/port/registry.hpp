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
#include <cstdint>
#include <string_view>

namespace aurelion::rules::port {

struct Function {
	const char *name;
	int arity;
	// Writes into its arguments: checked by comparing the arguments afterwards.
	bool mutates;
	state::Value (*call)(state::State &state, const state::Value *args);
};

// A GDScript static var, by the atoms of its script's res:// path and its name.
struct ScriptStatic {
	uint32_t script;
	uint32_t name;
};

// One subsystem's functions.
struct Table {
	// The environment variable naming the folder for the shadow statistics
	// (HEROES_NATIVE_BATTLE_LOG).
	const char *log_variable;
	const Function *functions;
	size_t count;
	// The memos (static vars) of the subsystem's GDScript, by their part in
	// the validating check (shadow mode: AurelionRules.port_validate_begin and
	// port_validate_end).
	// - GDScript's own: GDScript fills them for its GDScript callers. The native
	//   port neither reads nor fills them (gd::static_var refuses them), so the
	//   check never compares them.
	// - Shared: the port reads and writes them as GDScript does. One the native
	//   call read or set is compared by value; one it left alone must be as
	//   GDScript's call left it, or the native port skipped what GDScript did.
	const ScriptStatic *gdscript_only = nullptr;
	size_t gdscript_only_count = 0;
	const ScriptStatic *shared_memos = nullptr;
	size_t shared_memo_count = 0;
	// The subsystem's switches run the GDScript body when a native call reaches
	// a path the port leaves to GDScript (state::NotPorted): the day port.
	// Without this fallback such a call fails, in native and in shadow mode
	// (AurelionRules reports it as a native failure): its null result could
	// pass for GDScript's.
	bool fallback = false;
};

// Every subsystem's table.
const Table *tables(size_t &count);
// Every table's functions in one array, in table order: a function's index in
// it is its slot in the adapter's statistics.
const Function *functions(size_t &count);
const Function *find_function(std::string_view name);
// A static var that a table names as GDScript's own.
bool gdscript_only_static(uint32_t script, uint32_t name);

} // namespace aurelion::rules::port
