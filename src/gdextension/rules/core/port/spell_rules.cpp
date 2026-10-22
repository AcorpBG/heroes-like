// SpellRules outside battles: a list of spell ids; shared with the battle port, a spell's school, tier and roles, its
// mana cost for a hero, the hero's mana and known spells, and its spellbook and maximum mana.

#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"

#include <string>

namespace aurelion::rules::port::spell_rules {

namespace {

using gd::array_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
namespace key = state::key;

// String(d.get(key, fallback)) in a shared helper.
Atom string_of_field(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify_or_fallback(state, state.get(dict, str(field), str(fallback)));
}

// x.get(key, fallback) on an untyped value: only a Dictionary has a two-argument get (Array.get and Object.get take
// one), so anything else stops the script.
DictRef two_argument_get_target(const Value &target) {
	if (!gd::is_dict(target)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' with two arguments in base '") + gd::type_name(target) + "'.");
	}
	return target.ref;
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

} // namespace

ArrayRef _normalize_spell_ids(State &state, const Value &value) {
	const ArrayRef ids = state.new_array();
	if (gd::is_array(value)) {
		for (const Value &spell_id_value : gd::items(state, value)) {
			const gd::Atom spell_id = gd::stringify_or_fallback(state, spell_id_value);
			if (spell_id != key::empty) {
				state.append(ids, str(spell_id));
			}
		}
	}
	return ids;
}

int64_t adjusted_spell_mana_cost(State &state, DictRef hero_state, const Value &spell) {
	const DictRef spell_dict = gd::is_dict(spell) ? spell.ref : gd::content_row(state, state::ContentTable::Spell, gd::stringify_or_fallback(state, spell));
	if (gd::is_empty(state, spell_dict)) {
		return 0;
	}
	// The cost reads the hero's specialties and artifacts, not its spellbook. The artifact bonuses normalize the
	// hero's top-level artifacts key in place, so they get a shallow copy.
	const DictRef hero = gd::duplicate_dict(state, hero_state);
	const int64_t base_cost = gd::int_field(state, spell_dict, key::mana_cost, 0);
	const int64_t progression_cost = hero_progression_rules::adjusted_mana_cost(state, hero, base_cost, string_of_field(state, spell_dict, key::school_id, key::empty));
	const int64_t artifact_delta = artifact_rules::spell_mana_cost_delta(state, hero, spell_dict);
	return compat::engine_max<int64_t>(0, gd::add(progression_cost, artifact_delta));
}

Atom spell_school_id(State &state, DictRef spell) {
	return string_of_field(state, spell, key::school_id, key::empty);
}

int64_t spell_tier(State &state, DictRef spell) {
	return gd::int_field(state, spell, key::tier, 0);
}

Atom spell_primary_role(State &state, DictRef spell) {
	return string_of_field(state, spell, key::primary_role, key::empty);
}

ArrayRef spell_role_categories(State &state, DictRef spell) {
	return _normalize_string_array(state, get_or_new_array(state, spell, key::role_categories));
}

ArrayRef _normalize_string_array(State &state, const Value &value) {
	const ArrayRef results = state.new_array();
	if (gd::is_array(value)) {
		for (const Value &entry : gd::items(state, value)) {
			const Atom normalized = gd::strip_edges(state, gd::stringify_or_fallback(state, entry));
			if (normalized != key::empty && !gd::array_has(state, results, str(normalized))) {
				state.append(results, str(normalized));
			}
		}
	}
	return results;
}

bool _has_mana(State &state, DictRef hero_state, int64_t cost) {
	// hero_state.get("spellbook", {}).get("mana", {}).get("current", 0)
	const DictRef spellbook = two_argument_get_target(get_or_new_dict(state, hero_state, key::spellbook));
	const DictRef mana = two_argument_get_target(get_or_new_dict(state, spellbook, key::mana));
	return gd::int_field(state, mana, key::current, 0) >= compat::engine_max<int64_t>(0, cost);
}

bool _knows_spell(State &state, DictRef hero_state, Atom spell_id) {
	// for known_spell_id in hero_state.get("spellbook", {}).get("known_spell_ids", [])
	const DictRef spellbook = two_argument_get_target(get_or_new_dict(state, hero_state, key::spellbook));
	for (const Value &known_spell_id : gd::items(state, get_or_new_array(state, spellbook, key::known_spell_ids))) {
		if (gd::stringify_or_fallback(state, known_spell_id) == spell_id) {
			return true;
		}
	}
	return false;
}

DictRef ensure_hero_spellbook(State &state, DictRef hero_state, DictRef hero_template) {
	const int64_t max_mana = mana_max_from_hero(state, hero_state);
	const ArrayRef default_known_spells = !gd::is_empty(state, hero_template) ? _normalize_spell_ids(state, get_or_new_array(state, hero_template, key::starting_spell_ids)) : state.new_array();
	// var spellbook = hero_state.get("spellbook", {}), a new one when it is not a Dictionary.
	const Value spellbook_value = get_or_new_dict(state, hero_state, key::spellbook);
	const DictRef spellbook = gd::is_dict(spellbook_value) ? spellbook_value.ref : state.new_dict();

	// The template's list is normalized already; only a stored list needs it.
	Value stored_spell_ids;
	ArrayRef known_spell_ids = state.lookup(spellbook, str(key::known_spell_ids), stored_spell_ids) ? _normalize_spell_ids(state, stored_spell_ids) : default_known_spells;
	if (state.array_size(known_spell_ids) == 0 && state.array_size(default_known_spells) > 0) {
		known_spell_ids = default_known_spells;
	}

	// var mana: Dictionary = spellbook.get("mana", {}).
	const DictRef mana = gd::as_dict(get_or_new_dict(state, spellbook, key::mana));
	int64_t current_mana = max_mana;
	if (!gd::is_empty(state, mana)) {
		current_mana = compat::engine_clamp<int64_t>(gd::int_field(state, mana, key::current, max_mana), 0, max_mana);
	}

	const DictRef mana_state = state.new_dict();
	state.set(mana_state, str(key::current), int_value(current_mana));
	state.set(mana_state, str(key::max), int_value(max_mana));
	const DictRef new_spellbook = state.new_dict();
	state.set(new_spellbook, str(key::known_spell_ids), array_value(known_spell_ids));
	state.set(new_spellbook, str(key::mana), dict_value(mana_state));
	state.set(hero_state, str(key::spellbook), dict_value(new_spellbook));
	return hero_state;
}

int64_t mana_max_from_hero(State &state, DictRef hero_state) {
	const Value week_bonuses = get_or_new_dict(state, hero_state, key::week_bonuses);
	const int64_t week_mana = gd::is_dict(week_bonuses) ? gd::int_field(state, week_bonuses.ref, key::mana, 0) : 0;
	const int64_t command_mana = mana_max_from_command(state, get_or_new_dict(state, hero_state, key::command));
	return gd::add(gd::add(command_mana, hero_progression_rules::mana_max_bonus(state, hero_state)), week_mana);
}

int64_t mana_max_from_command(State &state, const Value &command) {
	if (!gd::is_dict(command)) {
		return 8;
	}
	return compat::engine_max<int64_t>(8, gd::add(8, gd::mul(compat::engine_max<int64_t>(0, gd::int_field(state, command.ref, key::knowledge, 0)), 4)));
}

} // namespace aurelion::rules::port::spell_rules
