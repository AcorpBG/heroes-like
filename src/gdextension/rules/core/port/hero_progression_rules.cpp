// Layer 2: a hero's specialty bonuses. A copy of the battle port's
// HeroProgressionRules functions (commander_payload.cpp on branch
// native-phase1-battle), which the day port reaches through a hero's scouting
// radius: whichever port reaches main second drops its copy.

#include "aurelion_rules/port/hero_progression_rules.hpp"

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

// The id keys of _commander_identity_tokens and _resolve_bonus_key.
constexpr Atom kHeroIdKeys[] = {
	key::id,
	key::roster_hero_id,
	key::hero_id,
};

// x.get(key, fallback) on an untyped value: only a Dictionary has a two-argument
// get (Array.get and Object.get take one), so anything else stops the script.
[[noreturn]] void no_two_argument_get(const Value &target) {
	throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' with two arguments in base '") + gd::type_name(target) + "'.");
}

// x.get(key, {}) on an untyped value: the default is a new Dictionary.
Value variant_get_or_new_dict(State &state, const Value &target, Atom field) {
	if (!gd::is_dict(target)) {
		no_two_argument_get(target);
	}
	Value found;
	if (state.lookup(target.ref, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
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

// `d.get(key, {}) if d.get(key, {}) is Dictionary else {}`.
DictRef dict_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

} // namespace

namespace hero_progression_rules {

DictRef aggregate_bonuses(State &state, DictRef hero_state) {
	const DictRef bonuses = state.new_dict();
	state.set(bonuses, str(key::overworld_movement), int_value(0));
	state.set(bonuses, str(key::scouting_radius), int_value(0));
	const DictRef daily_income = state.new_dict();
	state.set(daily_income, str(key::gold), int_value(0));
	state.set(daily_income, str(key::wood), int_value(0));
	state.set(daily_income, str(key::ore), int_value(0));
	state.set(bonuses, str(key::daily_income), dict_value(daily_income));
	state.set(bonuses, str(key::max_mana), int_value(0));
	state.set(bonuses, str(key::mana_cost_discount), int_value(0));
	state.set(bonuses, str(key::battle_attack), int_value(0));
	state.set(bonuses, str(key::battle_defense), int_value(0));
	state.set(bonuses, str(key::battle_initiative), int_value(0));
	state.set(bonuses, str(key::recruit_growth_multiplier), gd::float_value(0.0));
	state.set(bonuses, str(key::recruit_cost_delta), gd::float_value(0.0));
	state.set(bonuses, str(key::raid_pillage_resistance), gd::float_value(0.0));
	const Value raw_specialty_ids = get_or_new_array(state, hero_state, key::specialties);
	if (!gd::is_array(raw_specialty_ids) || state.array_size(raw_specialty_ids.ref) == 0) {
		return bonuses;
	}
	const DictRef catalog = _specialty_catalog(state);
	const ArrayRef specialty_ids = _normalize_specialties_in(state, catalog, raw_specialty_ids);
	const DictRef counted = state.new_dict();
	for (const Value &specialty_id_value : gd::items(state, array_value(specialty_ids))) {
		const Atom specialty_id = gd::to_string(specialty_id_value);
		if (state.has(counted, str(specialty_id))) {
			continue;
		}
		state.set(counted, str(specialty_id), gd::bool_value(true));
		// row: Dictionary takes catalog.get(specialty_id, {}).
		Value row_value;
		const DictRef row = state.lookup(catalog, str(specialty_id), row_value) ? gd::as_dict(row_value) : state.new_dict();
		const int64_t rank = _rank_in_array(state, specialty_ids, specialty_id);
		_merge_bonuses(state, bonuses, _rank_bonuses(state, row, rank), hero_state);
	}
	return bonuses;
}

void _merge_bonuses(State &state, DictRef target, DictRef source, DictRef hero_state) {
	// source.keys(): a copy, walked while target is written.
	const state::ValueList source_keys = state.dict(source).keys.list();
	for (const Value &source_key : source_keys) {
		const Atom bonus_key = gd::to_string(source_key);
		const Value value = gd::index(state, source, source_key);
		if (gd::is_dict(value)) {
			const DictRef nested = dict_field_or_new(state, target, bonus_key);
			const state::ValueList nested_keys = state.dict(value.ref).keys.list();
			for (const Value &nested_key : nested_keys) {
				const Atom resolved = _resolve_bonus_key(state, gd::to_string(nested_key), hero_state);
				if (resolved == key::empty) {
					continue;
				}
				const Value current = state.get(nested, str(resolved), int_value(0));
				const Value added = gd::index(state, value.ref, nested_key);
				state.set(nested, str(resolved), _sum_bonus(state, current, added));
			}
			state.set(target, str(bonus_key), dict_value(nested));
		} else {
			const Value current = state.get(target, str(bonus_key), int_value(0));
			state.set(target, str(bonus_key), _sum_bonus(state, current, value));
		}
	}
}

ArrayRef _normalize_specialties_in(State &state, DictRef catalog, const Value &value) {
	const ArrayRef normalized = state.new_array();
	if (gd::is_array(value)) {
		for (const Value &specialty_id_value : gd::items(state, value)) {
			const Atom specialty_id = gd::to_string(specialty_id_value);
			// var row: Dictionary = catalog.get(specialty_id, {})
			Value row_value;
			const DictRef row = state.lookup(catalog, str(specialty_id), row_value) ? gd::as_dict(row_value) : state.new_dict();
			if (gd::is_empty(state, row)) {
				continue;
			}
			if (_rank_in_array(state, normalized, specialty_id) >= compat::engine_max<int64_t>(1, gd::int_field(state, row, key::max_rank, 1))) {
				continue;
			}
			state.append(normalized, str(specialty_id));
		}
	}
	return normalized;
}

DictRef _rank_bonuses(State &state, DictRef row, int64_t rank) {
	// var ranks: Array = row.get("ranks", []): anything but an Array stops the script.
	const ArrayRef ranks = gd::as_array(get_or_new_array(state, row, key::ranks));
	if (rank < 1 || state.array_size(ranks) == 0) {
		return state.new_dict();
	}
	const Value entry = state.at(ranks, compat::engine_min<int64_t>(rank, state.array_size(ranks)) - 1);
	const Value bonuses = variant_get_or_new_dict(state, entry, key::bonuses);
	return gd::is_dict(bonuses) ? bonuses.ref : state.new_dict();
}

int64_t _rank_in_array(State &state, ArrayRef specialty_ids, Atom specialty_id) {
	int64_t count = 0;
	for (const Value &specialty_id_value : gd::items(state, array_value(specialty_ids))) {
		if (gd::to_string(specialty_id_value) == specialty_id) {
			count = gd::add(count, 1);
		}
	}
	return count;
}

DictRef _specialty_catalog(State &state) {
	// Without the catalog memo (_catalog_source, _catalog_index): every call builds
	// the index a content change builds, from the same shared rows.
	const DictRef data = gd::content_file(state, key::hero_specialties_path);
	Value items;
	const bool has_items = state.lookup(data, str(key::items), items) && gd::is_array(items);
	const DictRef index = state.new_dict();
	if (has_items) {
		for (const Value &specialty : gd::items(state, items)) {
			if (gd::is_dict(specialty)) {
				state.set(index, str(gd::string_field(state, specialty.ref, key::id, key::empty)), specialty);
			}
		}
	}
	return index;
}

Atom _resolve_bonus_key(State &state, Atom bonus_key, DictRef hero_state) {
	if (bonus_key != key::faction_rare_main && bonus_key != key::faction_rare_secondary) {
		return bonus_key;
	}
	Atom faction_id = gd::string_field(state, hero_state, key::faction_id, key::empty);
	if (faction_id == key::empty) {
		for (const Atom id_key : kHeroIdKeys) {
			const Atom hero_id = gd::string_field(state, hero_state, id_key, key::empty);
			const DictRef hero = gd::content_row(state, state::ContentTable::Hero, hero_id);
			faction_id = gd::string_field(state, hero, key::faction_id, key::empty);
			if (faction_id != key::empty) {
				break;
			}
		}
	}
	const DictRef faction = gd::content_row(state, state::ContentTable::Faction, faction_id);
	const Value resources = get_or_new_dict(state, faction, key::town_resources);
	if (!gd::is_dict(resources)) {
		return key::empty;
	}
	return gd::string_field(state, resources.ref, bonus_key == key::faction_rare_main ? key::main : key::secondary, key::empty);
}

Value _sum_bonus(State &state, const Value &current, const Value &added) {
	if (gd::type_of(current) == state::variant_type::FLOAT || gd::type_of(added) == state::variant_type::FLOAT) {
		const double current_float = gd::to_float(current);
		return gd::float_value(current_float + gd::to_float(added));
	}
	const int64_t current_int = gd::to_int(state, current);
	return int_value(gd::add(current_int, gd::to_int(state, added)));
}

} // namespace hero_progression_rules

} // namespace aurelion::rules::port
