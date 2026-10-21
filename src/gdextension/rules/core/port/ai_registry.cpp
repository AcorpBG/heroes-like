#include "aurelion_rules/port/registry.hpp"

#include "aurelion_rules/port/ai_hero_rules_ai.hpp"

namespace aurelion::rules::port {

namespace {

using state::State;
using state::Value;
namespace ai = ai_hero_rules;

// The parameters as GDScript's types left them. A session is its view, a
// Dictionary (AiEngine.gd).
gd::DictRef D(const Value *args, int index) {
	return gd::as_dict(args[index]);
}
int64_t I(const Value *args, int index) {
	return args[index].i;
}
gd::Atom S(const Value *args, int index) {
	return gd::to_string(args[index]);
}

Value nil() {
	return Value();
}

#define PORT(script, fn, arity, mutates, body) \
	{ #script "." #fn, arity, mutates, [](State &s, const Value *a) -> Value { (void)s; (void)a; body; } }

// The entry points of the AI targets ported so far; the functions they reach
// run native inside them. A static var a port sets counts as a write.
const Function kFunctions[] = {
	PORT(AiHeroRules, _explored, 3, true, return gd::bytes_value(ai::_explored(s, D(a, 0), D(a, 1), I(a, 2)))),
	PORT(AiHeroRules, _sync_site_pass_memo, 0, true, ai::_sync_site_pass_memo(s); return nil()),
	PORT(AiHeroRules, _site_pass_class, 1, true, return gd::array_value(ai::_site_pass_class(s, S(a, 0)))),
};

#undef PORT

} // namespace

// The AI targets port's table, listed in registry_tables.cpp.
Table ai_table() {
	return {"HEROES_NATIVE_AI_LOG", kFunctions, sizeof(kFunctions) / sizeof(kFunctions[0])};
}

} // namespace aurelion::rules::port
