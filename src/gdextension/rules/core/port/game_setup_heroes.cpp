// A new game's start heroes: HeroCommandRules.army_has_troops and
// seed_start_heroes_from_session, and HeroProgressionRules.brief_summary for
// the setup's launch text.

#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_progression_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

} // namespace

// Defined in hero_commit.cpp and enemy_states.cpp (Phase 5) without a header.

namespace hero_command_rules {
Atom new_growth_seed(State &state, Atom hero_id, DictRef session);
} // namespace hero_command_rules

namespace hero_progression_rules {
int64_t specialty_rank(State &state, DictRef hero_state, Atom specialty_id);
Value specialties(State &state);
} // namespace hero_progression_rules

// HeroCommandRules.

namespace hero_command_rules {

bool army_has_troops(State &state, const Value &army) {
	if (!gd::is_dict(army)) {
		return false;
	}
	Value stacks;
	if (!state.lookup(army.ref, str(key::stacks), stacks)) {
		stacks = array_value(state.new_array());
	}
	return _valid_stack_count(state, stacks) > 0;
}

void seed_start_heroes_from_session(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return;
	}
	const DictRef view = gd::object_view(state, session);
	const DictRef overworld = session_view::overworld(state, view);
	Value heroes_value;
	const ArrayRef heroes = state.lookup(overworld, str(key::player_heroes), heroes_value) && gd::is_array(heroes_value)
			? heroes_value.ref
			: state.new_array();
	// The active hero mirror can be a separate copy of its roster entry.
	Value mirror;
	if (!state.lookup(overworld, str(key::hero), mirror)) {
		mirror = dict_value(state.new_dict());
	}
	const ArrayRef tail = state.new_array();
	state.append(tail, mirror);
	const ArrayRef all = gd::concat(state, heroes, tail);
	for (int64_t index = 0; index < state.array_size(all); ++index) {
		const Value hero = state.at(all, index);
		if (gd::is_dict(hero) && ai::string_or_empty(state, hero.ref, key::id) != key::empty) {
			const Atom hero_id = ai::string_or_empty(state, hero.ref, key::id);
			state.set(hero.ref, str(key::growth_seed), str(new_growth_seed(state, hero_id, view)));
		}
	}
}

} // namespace hero_command_rules

// HeroProgressionRules.

namespace hero_progression_rules {

Atom brief_summary(State &state, DictRef hero_state) {
	const DictRef hero = ensure_hero_progression(state, gd::deep_duplicate_dict(state, hero_state));
	std::vector<std::string> parts;
	const Value catalog = specialties(state);
	for (int64_t index = 0; index < ai::vsize(state, catalog); ++index) {
		const Value specialty = ai::vindex(state, catalog, int_value(index));
		const Atom specialty_id = gd::stringify(state, ai::vget(state, specialty, str(key::id), str(key::empty)));
		const int64_t rank = specialty_rank(state, hero, specialty_id);
		if (rank <= 0) {
			continue;
		}
		const Atom short_name = gd::stringify(state, ai::vget(state, specialty, str(key::short_name), str(specialty_id)));
		parts.push_back(state.text(gd::format(state, key::s_s, { str(short_name), str(rank_label(state, rank)) })));
	}
	std::string summary;
	if (parts.empty()) {
		summary = state.text(key::no_specialties_chosen_yet);
	} else {
		// ", ".join(parts)
		for (size_t index = 0; index < parts.size(); ++index) {
			if (index > 0) {
				summary += state.text(key::comma_space);
			}
			summary += parts[index];
		}
	}
	const int64_t pending_count = pending_choices_remaining(state, hero);
	if (pending_count > 0) {
		summary += state.text(gd::format(state, key::pending_d, { int_value(pending_count) }));
	}
	return state.intern(summary);
}

} // namespace hero_progression_rules

} // namespace aurelion::rules::port
