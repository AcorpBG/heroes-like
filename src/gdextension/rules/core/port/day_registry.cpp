#include "aurelion_rules/port/registry.hpp"

#include "aurelion_rules/port/overworld_rules.hpp"

namespace aurelion::rules::port {

namespace {

using state::State;
using state::Value;
namespace overworld = overworld_rules;

// The parameters as GDScript's types left them. A session is its view, a
// Dictionary (DayEngine.gd).
gd::DictRef D(const Value *args, int index) {
	return gd::as_dict(args[index]);
}

Value nil() {
	return Value();
}

#define PORT(script, fn, arity, mutates, body) \
	{ #script "." #fn, arity, mutates, [](State &s, const Value *a) -> Value { (void)s; (void)a; body; } }

// The entry points of the day processing ported so far; the functions they
// reach run native inside them.
const Function kFunctions[] = {
	PORT(OverworldRules, _normalize_fog_of_war, 1, true, overworld::_normalize_fog_of_war(s, D(a, 0)); return nil()),
};

#undef PORT

} // namespace

// The day port's table, listed in registry_tables.cpp.
Table day_table() {
	return {"HEROES_NATIVE_DAY_LOG", kFunctions, sizeof(kFunctions) / sizeof(kFunctions[0])};
}

} // namespace aurelion::rules::port
