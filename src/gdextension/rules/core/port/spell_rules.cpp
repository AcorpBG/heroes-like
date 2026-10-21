// SpellRules outside battles: a list of spell ids; shared with the battle port, a spell's school, tier and roles, its
// mana cost for a hero, and the hero's mana and known spells.

#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"

#include <string>

namespace aurelion::rules::port::spell_rules {

namespace {

using gd::array_value;
using gd::dict_value;
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

} // namespace aurelion::rules::port::spell_rules
