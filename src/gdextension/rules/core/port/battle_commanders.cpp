// The enemy commander of a battle (an override, a seeded or roster commander, a
// town's watch captain, a site's defender) and a raid's name and strength.

#include "aurelion_rules/port/battle_payload.hpp"

#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/enemy_adventure_rules.hpp"
#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <string>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Kind;
namespace key = state::key;

// String(d.get(key, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// String(d.get(key, fallback)) with an untyped fallback.
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return gd::stringify(state, state.get(dict, str(field), fallback));
}

// The untyped max(a, b) and clamp(x, lo, hi) of ints: an int.
int64_t imax(int64_t a, int64_t b) {
	return compat::engine_max<int64_t>(a, b);
}

int64_t iclamp(int64_t x, int64_t lo, int64_t hi) {
	return compat::engine_clamp<int64_t>(x, lo, hi);
}

// d.get(key, {}) and d.get(key, []): a new container when the key is missing.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

Value get_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// `var x = d.get(key, {})` then `x is Dictionary and not x.is_empty()`.
bool nonempty_dict_field(const State &state, DictRef dict, Atom field, Value &found) {
	return state.lookup(dict, str(field), found) && gd::is_dict(found) && !gd::is_empty(state, found.ref);
}

// `d.get(key, []) is Array`: a missing key gives the default, an Array.
bool array_field_or_missing(const State &state, DictRef dict, Atom field) {
	Value found;
	return !state.lookup(dict, str(field), found) || gd::is_array(found);
}

// int(counts.get(key, 0) / 2): the untyped division.
int64_t half_count(State &state, DictRef counts, Atom field) {
	return gd::to_int(state, gd::op_div(state.get(counts, str(field), int_value(0)), int_value(2)));
}

} // namespace

// Defined in enemy_states.cpp, declared in no header.
namespace enemy_adventure_rules {
DictRef build_roster_commander_state(State &state, Atom roster_hero_id, Atom faction_id, DictRef existing_state, const Value &record_source);
DictRef _apply_commander_record_metadata(State &state, DictRef commander_state, const Value &record_source);
DictRef _base_enemy_army(State &state, Atom encounter_id);
DictRef _normalize_army_payload(State &state, const Value &army);
ArrayRef _normalized_specialty_ranks(State &state, const Value &primary, const Value &secondary);
ArrayRef _normalized_specialty_focus_ids(State &state, const Value &value);
} // namespace enemy_adventure_rules

namespace battle_rules {

DictRef _enemy_commander_state_for_battle(State &state, const Value &session, DictRef encounter_placement, DictRef encounter, DictRef battle_context) {
	Value override_value;
	if (nonempty_dict_field(state, encounter_placement, key::enemy_hero_override, override_value)) {
		return gd::deep_duplicate_dict(state, override_value.ref);
	}
	Value seeded_commander;
	if (nonempty_dict_field(state, encounter_placement, key::enemy_commander_state, seeded_commander)) {
		return _normalize_enemy_hero_state(state, seeded_commander, encounter, encounter_placement);
	}
	if (_is_town_assault_context(state, dict_value(battle_context))) {
		const DictRef found = _find_town_by_placement(state, session, text(state, battle_context, key::town_placement_id, key::empty));
		return _town_captain_state(state, gd::as_dict(get_or_new_dict(state, found, key::town)));
	}
	if (_is_resource_assault_context(state, dict_value(battle_context))) {
		const Atom placement_id = text(state, battle_context, key::resource_placement_id, key::empty);
		// A null session finds {"index": -1, "node": {}} (the callee takes the view).
		const DictRef node = session.kind == Kind::Nil
				? state.new_dict()
				: gd::as_dict(get_or_new_dict(state, overworld_rules::_find_resource_node_by_placement(state, gd::object_view(state, session), placement_id), key::node));
		Value commander_state;
		if (nonempty_dict_field(state, node, key::ai_defender_commander_state, commander_state)) {
			return _normalize_enemy_hero_state(state, commander_state, encounter, encounter_placement);
		}
	}
	return _normalize_enemy_hero_state(state, dict_value(state.new_dict()), encounter, encounter_placement);
}

DictRef _town_captain_state(State &state, DictRef town) {
	const Atom name = gd::format(state, key::s_watch_captain, { str(_town_name(state, town)) });
	const DictRef category_counts = _town_building_category_counts(state, town);
	const DictRef command = state.new_dict();
	state.set(command, str(key::attack), int_value(iclamp(half_count(state, category_counts, key::dwelling), 0, 3)));
	const int64_t support = gd::int_field(state, category_counts, key::support, 0);
	const int64_t defense = gd::add(gd::add(1, support), half_count(state, category_counts, key::civic));
	state.set(command, str(key::defense), int_value(iclamp(defense, 1, 5)));
	state.set(command, str(key::power), int_value(iclamp(half_count(state, category_counts, key::magic), 0, 2)));
	state.set(command, str(key::knowledge), int_value(iclamp(gd::int_field(state, category_counts, key::magic, 0), 0, 2)));
	const Atom captain_id = gd::format(state, key::town_captain_s, { str(text(state, town, key::placement_id, key::empty)) });
	const DictRef captain = state.new_dict();
	state.set(captain, str(key::id), str(captain_id));
	state.set(captain, str(key::name), str(name));
	state.set(captain, str(key::level), int_value(1));
	state.set(captain, str(key::experience), int_value(0));
	state.set(captain, str(key::next_level_experience), int_value(250));
	state.set(captain, str(key::base_movement), int_value(0));
	state.set(captain, str(key::command), dict_value(command));
	state.set(captain, str(key::specialties), array_value(state.new_array()));
	state.set(captain, str(key::pending_specialty_choices), array_value(state.new_array()));
	state.set(captain, str(key::artifacts), dict_value(artifact_rules::normalize_hero_artifacts(state, dict_value(state.new_dict()))));
	return _normalize_town_captain(state, captain);
}

DictRef _normalize_town_captain(State &state, DictRef hero_state) {
	const DictRef command = _normalize_command(state, get_or_new_dict(state, hero_state, key::command));
	const DictRef hero = state.new_dict();
	state.set(hero, str(key::id), str(text(state, hero_state, key::id, key::empty)));
	state.set(hero, str(key::name), str(text(state, hero_state, key::name, key::town_captain)));
	state.set(hero, str(key::level), int_value(imax(1, gd::int_field(state, hero_state, key::level, 1))));
	state.set(hero, str(key::experience), int_value(imax(0, gd::int_field(state, hero_state, key::experience, 0))));
	state.set(hero, str(key::next_level_experience), int_value(imax(250, gd::int_field(state, hero_state, key::next_level_experience, 250))));
	state.set(hero, str(key::base_movement), int_value(0));
	state.set(hero, str(key::command), dict_value(command));
	state.set(hero, str(key::specialties), array_value(state.new_array()));
	state.set(hero, str(key::pending_specialty_choices), array_value(state.new_array()));
	state.set(hero, str(key::artifacts), dict_value(artifact_rules::normalize_hero_artifacts(state, dict_value(state.new_dict()))));
	const DictRef progressed = hero_progression_rules::ensure_hero_progression(state, hero);
	const DictRef spell_template = state.new_dict();
	state.set(spell_template, str(key::command), dict_value(command));
	state.set(spell_template, str(key::starting_spell_ids), array_value(state.new_array()));
	return spell_rules::ensure_hero_spellbook(state, progressed, spell_template);
}

DictRef _town_building_category_counts(State &state, DictRef town) {
	const DictRef counts = state.new_dict();
	state.set(counts, str(key::civic), int_value(0));
	state.set(counts, str(key::dwelling), int_value(0));
	state.set(counts, str(key::economy), int_value(0));
	state.set(counts, str(key::support), int_value(0));
	state.set(counts, str(key::magic), int_value(0));
	const ArrayRef buildings = _normalized_town_buildings(state, town);
	for (const Value &building_id_value : gd::items(state, array_value(buildings))) {
		const DictRef building = gd::content_row(state, ContentTable::Building, gd::stringify(state, building_id_value));
		Atom category = text(state, building, key::category, key::support);
		if (!state.has(counts, str(category))) {
			category = key::support;
		}
		state.set(counts, str(category), int_value(gd::add(gd::int_field(state, counts, category, 0), 1)));
	}
	return counts;
}

ArrayRef _normalized_town_buildings(State &state, DictRef town) {
	const ArrayRef normalized = state.new_array();
	const DictRef town_template = gd::content_row(state, ContentTable::Town, text(state, town, key::town_id, key::empty));
	for (const Value &building_id_value : gd::field_items(state, town_template, str(key::starting_building_ids))) {
		_append_building_with_requirements(state, normalized, gd::stringify(state, building_id_value), state.new_array());
	}
	for (const Value &building_id_value : gd::field_items(state, town, str(key::built_buildings))) {
		_append_building_with_requirements(state, normalized, gd::stringify(state, building_id_value), state.new_array());
	}
	return normalized;
}

void _append_building_with_requirements(State &state, ArrayRef target, Atom building_id, ArrayRef trail) {
	if (building_id == key::empty || gd::array_has(state, target, str(building_id)) || gd::array_has(state, trail, str(building_id))) {
		return;
	}
	const ArrayRef next_trail = gd::deep_duplicate_array(state, trail);
	state.append(next_trail, str(building_id));
	const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
	const Atom upgrade_from = text(state, building, key::upgrade_from, key::empty);
	if (upgrade_from != key::empty) {
		_append_building_with_requirements(state, target, upgrade_from, next_trail);
	}
	for (const Value &requirement_value : gd::field_items(state, building, str(key::requires_))) {
		_append_building_with_requirements(state, target, gd::stringify(state, requirement_value), next_trail);
	}
	state.append(target, str(building_id));
}

DictRef _encounter_enemy_commander_seed(State &state, DictRef encounter_placement) {
	Value seeded;
	if (nonempty_dict_field(state, encounter_placement, key::enemy_commander_state, seeded)) {
		return seeded.ref;
	}
	Value override_value;
	if (nonempty_dict_field(state, encounter_placement, key::enemy_hero_override, override_value)) {
		return override_value.ref;
	}
	return state.new_dict();
}

Atom _encounter_enemy_commander_name(State &state, DictRef encounter_placement, DictRef encounter) {
	const DictRef seeded = _encounter_enemy_commander_seed(state, encounter_placement);
	if (!gd::is_empty(state, seeded)) {
		return enemy_adventure_rules::commander_display_name(state, dict_value(seeded), true);
	}
	return enemy_adventure_rules::commander_display_name(state, dict_value(_enemy_commander_state(state, encounter)), true);
}

DictRef _enemy_commander_state(State &state, DictRef encounter) {
	Value commander_value;
	if (!nonempty_dict_field(state, encounter, key::enemy_commander, commander_value)) {
		return state.new_dict();
	}
	const DictRef commander = commander_value.ref;
	const Atom roster_hero_id = gd::strip_edges(state, text(state, commander, key::roster_hero_id, key::empty));
	if (roster_hero_id != key::empty) {
		const DictRef hero_template = gd::content_row(state, ContentTable::Hero, roster_hero_id);
		const Value faction_fallback = state.get(hero_template, str(key::faction_id), str(key::empty));
		const Atom faction_id = gd::strip_edges(state, text_or(state, commander, key::faction_id, faction_fallback));
		if (!gd::is_empty(state, hero_template) && faction_id == text(state, hero_template, key::faction_id, key::empty)) {
			return enemy_adventure_rules::build_roster_commander_state(state, roster_hero_id, faction_id, state.new_dict(), dict_value(state.new_dict()));
		}
	}
	const DictRef command = _normalize_command(state, get_or_new_dict(state, commander, key::command));
	const Atom name = text(state, commander, key::name, key::enemy_commander_title);
	const ArrayRef battle_traits = _normalized_battle_traits(state, commander_value);
	const DictRef hero = state.new_dict();
	state.set(hero, str(key::name), str(name));
	state.set(hero, str(key::command), dict_value(command));
	state.set(hero, str(key::battle_traits), array_value(battle_traits));
	const DictRef spell_template = state.new_dict();
	state.set(spell_template, str(key::command), dict_value(command));
	state.set(spell_template, str(key::starting_spell_ids), get_or_new_array(state, commander, key::starting_spell_ids));
	return spell_rules::ensure_hero_spellbook(state, hero, spell_template);
}

DictRef _normalize_enemy_hero_state(State &state, const Value &existing_state_value, DictRef encounter, DictRef encounter_placement) {
	const DictRef template_state = _enemy_commander_state(state, encounter);
	const DictRef seeded = _encounter_enemy_commander_seed(state, encounter_placement);
	DictRef existing_state = 0;
	if (!gd::is_dict(existing_state_value) || gd::is_empty(state, existing_state_value.ref)) {
		if (gd::is_empty(state, seeded)) {
			return template_state;
		}
		existing_state = seeded;
	} else {
		existing_state = existing_state_value.ref;
	}
	const Atom roster_hero_id = gd::strip_edges(state, text(state, existing_state, key::roster_hero_id, key::empty));
	if (roster_hero_id != key::empty) {
		const DictRef hero_template = gd::content_row(state, ContentTable::Hero, roster_hero_id);
		const Value faction_fallback = state.get(hero_template, str(key::faction_id), str(key::empty));
		const Atom faction_id = gd::strip_edges(state, text_or(state, existing_state, key::faction_id, faction_fallback));
		if (!gd::is_empty(state, hero_template) && faction_id == text(state, hero_template, key::faction_id, key::empty)) {
			existing_state = enemy_adventure_rules::build_roster_commander_state(state, roster_hero_id, faction_id, existing_state, dict_value(state.new_dict()));
		}
	}
	const DictRef normalized = gd::deep_duplicate_dict(state, existing_state);
	Value seeded_spellbook_value = get_or_new_dict(state, seeded, key::spellbook);
	if (!gd::is_dict(seeded_spellbook_value)) {
		seeded_spellbook_value = dict_value(state.new_dict());
	}
	const DictRef seeded_spellbook = seeded_spellbook_value.ref;
	if (!gd::is_empty(state, seeded)) {
		for (const Atom field : { key::id, key::roster_hero_id, key::faction_id, key::archetype, key::identity_summary }) {
			const Value seeded_fallback = state.get(seeded, str(field), str(key::empty));
			state.set(normalized, str(field), str(text_or(state, normalized, field, seeded_fallback)));
		}
		if (array_field_or_missing(state, normalized, key::specialties) || array_field_or_missing(state, seeded, key::specialties)) {
			Value resolved_specialties = get_or_new_array(state, normalized, key::specialties);
			if (!gd::is_array(resolved_specialties) || state.array_size(resolved_specialties.ref) == 0) {
				resolved_specialties = get_or_new_array(state, seeded, key::specialties);
			}
			state.set(normalized, str(key::specialties), array_value(_normalized_specialty_ranks(state, resolved_specialties, array_value(state.new_array()))));
		}
		if (array_field_or_missing(state, normalized, key::specialty_focus_ids) || array_field_or_missing(state, seeded, key::specialty_focus_ids)) {
			Value focus_source;
			if (!state.lookup(normalized, str(key::specialty_focus_ids), focus_source)) {
				focus_source = get_or_new_array(state, seeded, key::specialty_focus_ids);
			}
			state.set(normalized, str(key::specialty_focus_ids), array_value(_normalized_specialty_focus_ids(state, focus_source)));
		}
	}
	const Value name_fallback = state.get(template_state, str(key::name), str(key::enemy_commander_title));
	state.set(normalized, str(key::name), str(text_or(state, normalized, key::name, name_fallback)));
	// normalized.get("command", seeded.get("command", template.get("command", {}))).
	Value command_source;
	if (!state.lookup(normalized, str(key::command), command_source) && !state.lookup(seeded, str(key::command), command_source)) {
		command_source = get_or_new_dict(state, template_state, key::command);
	}
	state.set(normalized, str(key::command), dict_value(_normalize_command(state, command_source)));
	const DictRef traits_source = state.has(normalized, str(key::battle_traits)) ? normalized : template_state;
	state.set(normalized, str(key::battle_traits), array_value(_normalized_battle_traits(state, dict_value(traits_source))));
	Value spell_command;
	if (!state.lookup(normalized, str(key::command), spell_command)) {
		spell_command = get_or_new_dict(state, template_state, key::command);
	}
	// template.get("spellbook", {}).get("known_spell_ids", []), the fallback
	// GDScript evaluates before seeded_spellbook.get.
	const Value template_spellbook = get_or_new_dict(state, template_state, key::spellbook);
	if (!gd::is_dict(template_spellbook)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' with two arguments in base '") + gd::type_name(template_spellbook) + "'.");
	}
	const Value template_known_spell_ids = get_or_new_array(state, template_spellbook.ref, key::known_spell_ids);
	const DictRef spell_template = state.new_dict();
	state.set(spell_template, str(key::command), spell_command);
	state.set(spell_template, str(key::starting_spell_ids), state.get(seeded_spellbook, str(key::known_spell_ids), template_known_spell_ids));
	const DictRef with_spellbook = spell_rules::ensure_hero_spellbook(state, normalized, spell_template);
	return enemy_adventure_rules::_apply_commander_record_metadata(state, with_spellbook, dict_value(normalized));
}

ArrayRef _normalized_specialty_ranks(State &state, const Value &primary, const Value &secondary) {
	return enemy_adventure_rules::_normalized_specialty_ranks(state, primary, secondary);
}

ArrayRef _normalized_specialty_focus_ids(State &state, const Value &value) {
	return enemy_adventure_rules::_normalized_specialty_focus_ids(state, value);
}

DictRef _normalize_command(State &state, const Value &value) {
	const DictRef command = state.new_dict();
	if (!gd::is_dict(value)) {
		state.set(command, str(key::attack), int_value(0));
		state.set(command, str(key::defense), int_value(0));
		state.set(command, str(key::power), int_value(0));
		state.set(command, str(key::knowledge), int_value(0));
		return command;
	}
	state.set(command, str(key::attack), int_value(imax(0, gd::int_field(state, value.ref, key::attack, 0))));
	state.set(command, str(key::defense), int_value(imax(0, gd::int_field(state, value.ref, key::defense, 0))));
	state.set(command, str(key::power), int_value(imax(0, gd::int_field(state, value.ref, key::power, 0))));
	state.set(command, str(key::knowledge), int_value(imax(0, gd::int_field(state, value.ref, key::knowledge, 0))));
	return command;
}

} // namespace battle_rules

} // namespace aurelion::rules::port
