// HeroCommandRules and HeroProgressionRules for the panels (Phase 7, slice 7.8):
// heroes' positions, the tavern, transfer and rendezvous texts, the town defense
// and the specialties.

#include "aurelion_rules/port/overworld_rules_panels.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/hero_progression_rules_turn.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include <string>

namespace aurelion::rules::port {

// Defined in enemy_states.cpp, declared only there.
namespace hero_progression_rules {
int64_t specialty_rank(State &state, DictRef hero_state, Atom specialty_id);
Value specialties(State &state);
} // namespace hero_progression_rules

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// HeroCommandRules.HERO_LIMIT.
constexpr int64_t kHeroLimit = 4;

// String(x) of any value: the engine's text for a float, a vector or a container.
Atom string_of(State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Nil:
		case Kind::Bool:
		case Kind::Int:
		case Kind::String:
		case Kind::StringName:
			return gd::stringify(state, value);
		default:
			return gd::engine_str(state, value);
	}
}

// String(d.get(field, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return string_of(state, state.get(dict, str(field), fallback));
}

// d.get(field, {}): the field, or a new {}.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// d.get(field, []): the field, or a new [].
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// int(d.get(outer, {}).get(inner, 0)): a missing outer is the empty
// Dictionary's 0; an outer that is no Dictionary has no get() (a ScriptError).
int64_t nested_int(State &state, DictRef dict, Atom outer, Atom inner) {
	Value found;
	if (!state.lookup(dict, str(outer), found)) {
		return 0;
	}
	return gd::to_int(state, ai::vget(state, found, inner, int_value(0)));
}

// sep.join(parts) of an Array of Strings.
Atom join_array(State &state, Atom separator, ArrayRef parts) {
	std::string joined;
	const int64_t size = state.array_size(parts);
	for (int64_t index = 0; index < size; ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(gd::stringify(state, state.at(parts, index)));
	}
	return state.intern(joined);
}

// "- Active: %s | %s | Gear %d | Spells %d" and the reserve line of a hero.
Atom rendezvous_line(State &state, Atom pattern, DictRef hero) {
	const Atom name = text_or(state, hero, key::name, str(key::Commander));
	const Atom army = hero_command_rules::_army_summary(state, field_or_new_dict(state, hero, key::army));
	const int64_t gear = state.array_size(artifact_rules::owned_artifact_ids(state, hero));
	const int64_t spells = state.array_size(spell_rules::known_spells(state, hero, key::empty));
	return gd::format(state, pattern, {str(name), str(army), int_value(gear), int_value(spells)});
}

} // namespace

namespace hero_command_rules {

Atom town_garrison_holder_id(State &state, DictRef session, DictRef town) {
	const DictRef hero = town_garrison_hero(state, session, town);
	return !gd::is_empty(state, hero) ? text_or(state, hero, key::id, str(key::empty)) : static_cast<Atom>(key::garrison);
}

Atom describe_town_defense_force(State &state, DictRef session, DictRef town) {
	const DictRef force = town_defense_force(state, session, town, key::empty);
	const DictRef hero = gd::as_dict(gd::index(state, force, str(key::hero)));
	const Value troops = gd::index(state, force, str(key::troops));
	const Value stack_count = gd::index(state, force, str(key::stack_count));
	const Value garrison_troops = gd::index(state, force, str(key::garrison_troops));
	const Value garrison_stacks = gd::index(state, force, str(key::garrison_stacks));
	const Atom empty_note = gd::to_int(state, gd::index(state, force, str(key::garrison_troops))) == 0 ? static_cast<Atom>(key::empty_4) : static_cast<Atom>(key::empty);
	Atom visiting = key::no_visiting_defender_remote_heroes_do;
	if (!gd::is_empty(state, hero)) {
		const Value id_or_hero = state.get(hero, str(key::id), str(key::Hero));
		const Atom name = string_of(state, state.get(hero, str(key::name), id_or_hero));
		visiting = gd::format(state, key::visiting_defender_s_d_troops_d, {str(name), gd::index(state, force, str(key::hero_troops)), gd::index(state, force, str(key::hero_stacks))});
	}
	return gd::format(state, key::defenders_d_troops_d_stacks_garrison, {troops, stack_count, garrison_troops, garrison_stacks, str(empty_note), str(visiting)});
}

ArrayRef empty_owned_towns(State &state, DictRef session) {
	// Own troops are known without consulting hidden enemy positions/AI plans.
	const ArrayRef result = state.new_array();
	const DictRef overworld = session_view::overworld(state, session);
	for (const Value &town : gd::field_items(state, overworld, str(key::towns))) {
		if (!gd::is_dict(town) || text_or(state, town.ref, key::owner, str(key::empty)) != key::player) {
			continue;
		}
		const DictRef force = town_defense_force(state, session, town.ref, key::empty);
		if (gd::to_int(state, gd::index(state, force, str(key::troops))) != 0) {
			continue;
		}
		const Atom placement_id = text_or(state, town.ref, key::placement_id, str(key::empty));
		const DictRef town_row = gd::content_row(state, ContentTable::Town, text_or(state, town.ref, key::town_id, str(key::empty)));
		const Value placement_or_town = state.get(town.ref, str(key::placement_id), str(key::Town));
		const Atom name = string_of(state, state.get(town_row, str(key::name), placement_or_town));
		const DictRef entry = state.new_dict();
		state.set(entry, str(key::placement_id), str(placement_id));
		state.set(entry, str(key::name), str(name));
		state.append(result, dict_value(entry));
	}
	return result;
}

Atom describe_tavern(State &state, DictRef session, DictRef town) {
	const DictRef hall = gd::content_row(state, ContentTable::Building, key::building_wayfarers_hall);
	const Atom hall_name = text_or(state, hall, key::name, str(key::wayfarers_hall));
	const ArrayRef lines = state.new_array();
	state.append(lines, str(hall_name));
	if (!town_has_hall(state, town)) {
		state.append(lines, str(gd::format(state, key::build_s_to_recruit_additional_commanders, {str(hall_name)})));
		return join_array(state, key::newline, lines);
	}
	if (player_hero_count(state, session) >= kHeroLimit) {
		state.append(lines, str(key::the_command_roster_is_already_full));
		return join_array(state, key::newline, lines);
	}
	if (state.array_size(recruitable_hero_ids(state, session)) == 0) {
		state.append(lines, str(key::no_additional_commanders_are_currently_available));
		return join_array(state, key::newline, lines);
	}

	const ArrayRef actions = get_tavern_actions(state, session, town);
	if (state.array_size(actions) == 0) {
		state.append(lines, str(key::no_commanders_are_currently_available_for));
		return join_array(state, key::newline, lines);
	}

	for (const Value &action : gd::items(state, array_value(actions))) {
		if (!gd::is_dict(action)) {
			continue;
		}
		const Atom label = text_or(state, action.ref, key::label, str(key::empty));
		const Atom summary = text_or(state, action.ref, key::summary, str(key::empty));
		state.append(lines, str(gd::format(state, key::s_s_15, {str(label), str(summary)})));
	}
	return join_array(state, key::newline, lines);
}

Atom describe_town_transfer(State &state, DictRef session, DictRef town) {
	normalize_session(state, session, key::empty, state.new_dict(), state.new_dict());
	const ArrayRef lines = state.new_array();
	state.append(lines, str(key::Transfer));
	const Atom garrison = _stack_summary_from_array(state, field_or_new_array(state, town, key::garrison));
	state.append(lines, str(gd::format(state, key::garrison_s, {str(garrison)})));
	const ArrayRef stationed = stationed_heroes(state, session, town);
	for (const Value &hero : gd::items(state, array_value(stationed))) {
		const Atom name = string_of(state, ai::vget(state, hero, key::name, str(key::Hero)));
		const Atom army = _army_summary(state, gd::is_dict(hero) ? field_or_new_dict(state, hero.ref, key::army) : ai::vget(state, hero, key::army));
		state.append(lines, str(gd::format(state, key::s_s_15, {str(name), str(army)})));
	}
	return join_array(state, key::newline, lines);
}

Atom describe_field_rendezvous(State &state, DictRef session) {
	const DictRef active = active_hero(state, session);
	const ArrayRef rendezvous = field_rendezvous_heroes(state, session);
	if (gd::is_empty(state, active) || state.array_size(rendezvous) == 0) {
		return key::no_friendly_commander_is_present_for;
	}
	const ArrayRef lines = state.new_array();
	state.append(lines, str(key::field_rendezvous));
	state.append(lines, str(rendezvous_line(state, key::active_s_s_gear_d_spells, active)));
	for (const Value &hero_value : gd::items(state, array_value(rendezvous))) {
		const DictRef hero = gd::is_dict(hero_value) ? hero_value.ref : state.new_dict();
		state.append(lines, str(rendezvous_line(state, key::reserve_s_s_gear_d_spells, hero)));
	}
	return join_array(state, key::newline, lines);
}

ArrayRef hero_positions(State &state, DictRef session) {
	const ArrayRef positions = state.new_array();
	const DictRef overworld = session_view::overworld(state, session);
	const DictRef garrison_towns = state.new_dict();
	for (const Value &town : gd::field_items(state, overworld, str(key::towns))) {
		if (gd::is_dict(town) && text_or(state, town.ref, key::garrison_hero_id, str(key::empty)) != key::empty) {
			const Atom hero_id = text_or(state, town.ref, key::garrison_hero_id, str(key::empty));
			state.set(garrison_towns, str(hero_id), str(text_or(state, town.ref, key::placement_id, str(key::empty))));
		}
	}
	for (const Value &hero : gd::field_items(state, overworld, str(key::player_heroes))) {
		if (!gd::is_dict(hero)) {
			continue;
		}
		const Atom id = text_or(state, hero.ref, key::id, str(key::empty));
		const Atom name = text_or(state, hero.ref, key::name, str(key::Hero));
		const int64_t x = nested_int(state, hero.ref, key::position, key::x);
		const int64_t y = nested_int(state, hero.ref, key::position, key::y);
		const int64_t level = overworld_level_rules::level_of(state, hero);
		const bool is_active = text_or(state, hero.ref, key::id, str(key::empty)) == text_or(state, overworld, key::active_hero_id, str(key::empty));
		const Atom boat_id = text_or(state, hero.ref, key::boat_id, str(key::empty));
		const Atom garrison_town = text_or(state, garrison_towns, text_or(state, hero.ref, key::id, str(key::empty)), str(key::empty));
		const DictRef entry = state.new_dict();
		state.set(entry, str(key::id), str(id));
		state.set(entry, str(key::name), str(name));
		state.set(entry, str(key::x), int_value(x));
		state.set(entry, str(key::y), int_value(y));
		state.set(entry, str(key::level), int_value(level));
		state.set(entry, str(key::is_active), bool_value(is_active));
		state.set(entry, str(key::boat_id), str(boat_id));
		state.set(entry, str(key::garrison_town_placement_id), str(garrison_town));
		state.append(positions, dict_value(entry));
	}
	return positions;
}

} // namespace hero_command_rules

namespace hero_progression_rules {

Atom describe_specialties(State &state, DictRef hero_state) {
	const DictRef hero = ensure_hero_progression(state, gd::as_dict(gd::engine_duplicate(state, dict_value(hero_state), true)));
	const ArrayRef lines = state.new_array();
	state.append(lines, str(key::Specialties));
	const ArrayRef chosen_lines = state.new_array();
	const Value catalog = specialties(state);
	for (const Value &specialty : gd::items(state, catalog)) {
		const Atom specialty_id = string_of(state, ai::vget(state, specialty, key::id, str(key::empty)));
		const int64_t rank = specialty_rank(state, hero, specialty_id);
		if (rank <= 0) {
			continue;
		}
		const Atom name = string_of(state, ai::vget(state, specialty, key::name, str(specialty_id)));
		const Atom label = rank_label(state, rank);
		const Atom text = rank_text(state, specialty_id, rank);
		state.append(chosen_lines, str(gd::format(state, key::s_s_s_12, {str(name), str(label), str(text)})));
	}
	state.append(lines, str(state.array_size(chosen_lines) != 0 ? join_array(state, key::newline, chosen_lines) : static_cast<Atom>(key::no_specialties_chosen_yet_2)));

	// hero.get("pending_specialty_choices", []): a missing key lists nothing.
	Value pending_choices;
	if (state.lookup(hero, str(key::pending_specialty_choices), pending_choices) && gd::is_array(pending_choices) && state.array_size(pending_choices.ref) != 0) {
		state.append(lines, str(key::pending_choices));
		for (const Value &pending_choice : gd::items(state, pending_choices)) {
			if (!gd::is_dict(pending_choice)) {
				continue;
			}
			const int64_t level = gd::int_field(state, pending_choice.ref, key::level, 0);
			const Atom summary = pending_choice_summary(state, pending_choice.ref);
			state.append(lines, str(gd::format(state, key::level_d_s, {int_value(level), str(summary)})));
		}
	}
	return join_array(state, key::newline, lines);
}

Atom specialty_id_for_action(State &state, Atom action_id) {
	if (!gd::begins_with(state, action_id, key::choose_specialty)) {
		return key::empty;
	}
	const Atom specialty_id = gd::trim_prefix(state, action_id, key::choose_specialty);
	// has_specialty(id): not _specialty_row(id).is_empty().
	return !gd::is_empty(state, _specialty_row(state, specialty_id)) ? specialty_id : static_cast<Atom>(key::empty);
}

Atom specialty_insignia_description(State &state, Atom specialty_id) {
	return text_or(state, _specialty_row(state, specialty_id), key::icon_description, str(key::empty));
}

} // namespace hero_progression_rules

} // namespace aurelion::rules::port
