// HeroCommandRules.commit_active_hero: the active hero's overworld mirrors
// (hero, army, movement, hero_position) written back into the player's roster,
// the hero normalized as a hire is (progression, spellbook, artifacts, army,
// movement), and the mirrors rebuilt from the roster entry, which they share
// with it.

#include "aurelion_rules/port/hero_commit.hpp"

#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include <string>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::State;
using state::Value;
namespace key = state::key;

// String(d.get(key, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify_or_fallback(state, state.get(dict, str(field), str(fallback)));
}

// d.get(key, {}): the field, or a new Dictionary when it is missing.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}

// HeroCommandRules.ARMY_SLOT_COUNT.
constexpr int64_t kArmySlotCount = 7;

} // namespace

namespace hero_progression_rules {
bool has_specialty(State &state, Atom specialty_id);
} // namespace hero_progression_rules

namespace hero_command_rules {
DictRef active_hero(State &state, DictRef session);
int64_t _hero_index_by_id(State &state, ArrayRef player_heroes, Atom hero_id);
DictRef _normalize_army(State &state, const Value &value, Atom hero_id);
DictRef _normalize_movement(State &state, const Value &value, int64_t movement_max);
DictRef _normalize_player_hero(State &state, DictRef hero_state, DictRef session, DictRef fallback_position, DictRef fallback_army, const Value &fallback_movement);
Atom new_growth_seed(State &state, Atom hero_id, DictRef session);
ArrayRef _normalize_authored_specialties(State &state, const Value &value);
void _sync_active_hero_mirror(State &state, DictRef session);
} // namespace hero_command_rules

// HeroProgressionRules.

namespace hero_progression_rules {

bool has_specialty(State &state, Atom specialty_id) {
	return !gd::is_empty(state, _specialty_row(state, specialty_id));
}

} // namespace hero_progression_rules

// HeroCommandRules.

namespace hero_command_rules {

void commit_active_hero(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	Value heroes_value;
	if (!state.lookup(overworld, str(key::player_heroes), heroes_value) || !gd::is_array(heroes_value) || state.array_size(heroes_value.ref) == 0) {
		return;
	}
	const ArrayRef heroes = heroes_value.ref;
	const int64_t active_index = _hero_index_by_id(state, heroes, text(state, overworld, key::active_hero_id, key::empty));
	if (active_index < 0) {
		return;
	}

	Value committed_value = field_or_new_dict(state, overworld, key::hero);
	if (!gd::is_dict(committed_value) || gd::is_empty(state, committed_value.ref)) {
		committed_value = state.at(heroes, active_index);
	}
	const DictRef committed = gd::deep_duplicate_dict(state, committed_value.ref);
	const Value saved_position = field_or_new_dict(state, committed, key::position);
	state.set(committed, str(key::position), dict_value(_normalize_position(state, state.get(overworld, str(key::hero_position), saved_position))));
	const Value saved_army = field_or_new_dict(state, committed, key::army);
	const Value army = state.get(overworld, str(key::army), saved_army);
	state.set(committed, str(key::army), dict_value(_normalize_army(state, army, text(state, committed, key::id, key::empty))));
	const Value saved_movement = field_or_new_dict(state, committed, key::movement);
	const Value movement = state.get(overworld, str(key::movement), saved_movement);
	state.set(committed, str(key::movement), dict_value(_normalize_movement(state, movement, movement_max_for_hero(state, committed, dict_value(session)))));
	const DictRef hero = _normalize_player_hero(state, committed, session,
			gd::as_dict(field_or_new_dict(state, committed, key::position)),
			gd::as_dict(field_or_new_dict(state, committed, key::army)),
			field_or_new_dict(state, committed, key::movement));
	state.set_at(heroes, active_index, dict_value(hero));
	state.set(overworld, str(key::player_heroes), array_value(heroes));
	_sync_active_hero_mirror(state, session);
}

DictRef active_hero(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	const Atom active_hero_id = text(state, overworld, key::active_hero_id, key::empty);
	for (const Value &hero : gd::field_items(state, overworld, str(key::player_heroes))) {
		if (gd::is_dict(hero) && text(state, hero.ref, key::id, key::empty) == active_hero_id) {
			return hero.ref;
		}
	}
	return state.new_dict();
}

int64_t _hero_index_by_id(State &state, ArrayRef player_heroes, Atom hero_id) {
	for (int64_t index = 0; index < state.array_size(player_heroes); ++index) {
		const Value hero = state.at(player_heroes, index);
		if (gd::is_dict(hero) && text(state, hero.ref, key::id, key::empty) == hero_id) {
			return index;
		}
	}
	return -1;
}

DictRef _normalize_army(State &state, const Value &value, Atom hero_id) {
	const ArrayRef stacks = state.new_array();
	if (gd::is_dict(value)) {
		for (const Value &stack : gd::field_items(state, value.ref, str(key::stacks))) {
			if (!gd::is_dict(stack)) {
				continue;
			}
			const Atom unit_id = text(state, stack.ref, key::unit_id, key::empty);
			const int64_t count = compat::engine_max<int64_t>(0, gd::int_field(state, stack.ref, key::count, 0));
			if (unit_id == key::empty || count <= 0) {
				continue;
			}
			const DictRef normalized_stack = state.new_dict();
			state.set(normalized_stack, str(key::unit_id), str(unit_id));
			state.set(normalized_stack, str(key::count), int_value(count));
			const int64_t slot_index = gd::int_field(state, stack.ref, key::slot_index, -1);
			if (slot_index >= 0 && slot_index < kArmySlotCount) {
				state.set(normalized_stack, str(key::slot_index), int_value(slot_index));
			}
			state.append(stacks, dict_value(normalized_stack));
		}
	}
	const DictRef source = gd::is_dict(value) ? value.ref : state.new_dict();
	const Atom default_id = state.intern(state.text(hero_id) + "_army");
	const DictRef army = state.new_dict();
	state.set(army, str(key::id), str(text(state, source, key::id, default_id)));
	state.set(army, str(key::name), str(text(state, source, key::name, key::field_army)));
	state.set(army, str(key::stacks), array_value(stacks));
	return army;
}

DictRef _normalize_movement(State &state, const Value &value, int64_t movement_max) {
	const DictRef normalized = state.new_dict();
	state.set(normalized, str(key::current), int_value(movement_max));
	state.set(normalized, str(key::max), int_value(movement_max));
	if (gd::is_dict(value)) {
		const int64_t current = gd::int_field(state, value.ref, key::current, movement_max);
		state.set(normalized, str(key::current), int_value(compat::engine_clamp<int64_t>(current, 0, movement_max)));
	}
	return normalized;
}

DictRef _normalize_player_hero(State &state, DictRef hero_state, DictRef session, DictRef fallback_position, DictRef fallback_army, const Value &fallback_movement) {
	const Atom hero_id = text(state, hero_state, key::id, key::empty);
	if (hero_id == key::empty) {
		return state.new_dict();
	}
	// ContentService.get_hero(hero_id).
	const DictRef hero_template = gd::content_row(state, state::ContentTable::Hero, hero_id);
	DictRef hero = gd::deep_duplicate_dict(state, hero_state);
	state.set(hero, str(key::id), str(hero_id));
	const Value template_name = state.get(hero_template, str(key::name), str(hero_id));
	state.set(hero, str(key::name), str(gd::stringify_or_fallback(state, state.get(hero, str(key::name), template_name))));
	if (text(state, hero, key::growth_seed, key::empty) == key::empty) {
		state.set(hero, str(key::growth_seed), str(new_growth_seed(state, hero_id, session)));
	}
	const Value template_movement = state.get(hero_template, str(key::base_movement), int_value(10));
	state.set(hero, str(key::base_movement), int_value(compat::engine_max<int64_t>(1, gd::to_int(state, state.get(hero, str(key::base_movement), template_movement)))));
	const Value template_focus = state.get(hero_template, str(key::specialty_focus_ids), array_value(state.new_array()));
	state.set(hero, str(key::specialty_focus_ids), array_value(_normalize_authored_specialties(state, state.get(hero, str(key::specialty_focus_ids), template_focus))));
	if (gd::int_field(state, hero, key::level, 1) <= 1 && gd::int_field(state, hero, key::experience, 0) == 0) {
		const ArrayRef starting_specialties = _normalize_authored_specialties(state, state.get(hero_template, str(key::starting_specialties), array_value(state.new_array())));
		if (state.array_size(starting_specialties) > 0 &&
				state.array_size(_normalize_authored_specialties(state, state.get(hero, str(key::specialties), array_value(state.new_array())))) == 0) {
			state.set(hero, str(key::specialties), array_value(starting_specialties));
		}
	}
	hero = hero_progression_rules::ensure_hero_progression(state, hero);
	hero = spell_rules::ensure_hero_spellbook(state, hero, hero_template);
	hero = artifact_rules::ensure_hero_artifacts(state, hero);
	state.set(hero, str(key::position), dict_value(_normalize_position(state, state.get(hero, str(key::position), dict_value(fallback_position)))));
	state.set(hero, str(key::army), dict_value(_normalize_army(state, state.get(hero, str(key::army), dict_value(fallback_army)), hero_id)));
	const Value movement = state.get(hero, str(key::movement), fallback_movement);
	state.set(hero, str(key::movement), dict_value(_normalize_movement(state, movement, movement_max_for_hero(state, hero, dict_value(session)))));
	return hero;
}

Atom new_growth_seed(State &state, Atom hero_id, DictRef session) {
	// "%s|%s|%s" % [String(session.session_id), String(session.scenario_id), hero_id]
	// for a session; without one GDScript draws a random seed, which no
	// commit reaches.
	const Atom session_id = gd::stringify_or_fallback(state, gd::field(state, session, key::session_id));
	const Atom scenario_id = gd::stringify_or_fallback(state, gd::field(state, session, key::scenario_id));
	return state.intern(state.text(session_id) + "|" + state.text(scenario_id) + "|" + state.text(hero_id));
}

ArrayRef _normalize_authored_specialties(State &state, const Value &value) {
	const ArrayRef normalized = state.new_array();
	if (!gd::is_array(value)) {
		return normalized;
	}
	for (const Value &specialty_id_value : gd::items(state, value)) {
		const Atom specialty_id = gd::stringify_or_fallback(state, specialty_id_value);
		if (!hero_progression_rules::has_specialty(state, specialty_id) || gd::array_has(state, normalized, str(specialty_id))) {
			continue;
		}
		state.append(normalized, str(specialty_id));
	}
	return normalized;
}

void _sync_active_hero_mirror(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	const DictRef hero = active_hero(state, session);
	if (gd::is_empty(state, hero)) {
		state.set(overworld, str(key::hero), dict_value(state.new_dict()));
		state.set(overworld, str(key::army), dict_value(state.new_dict()));
		state.set(overworld, str(key::movement), dict_value(state.new_dict()));
		state.set(overworld, str(key::hero_position), dict_value(state.new_dict()));
		return;
	}
	state.set(overworld, str(key::hero), dict_value(hero));
	state.set(overworld, str(key::army), field_or_new_dict(state, hero, key::army));
	state.set(overworld, str(key::movement), field_or_new_dict(state, hero, key::movement));
	state.set(overworld, str(key::hero_position), field_or_new_dict(state, hero, key::position));
}

} // namespace hero_command_rules

} // namespace aurelion::rules::port
