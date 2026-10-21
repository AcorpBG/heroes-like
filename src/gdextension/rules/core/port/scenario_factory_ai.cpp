// ScenarioFactory: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/scenario_factory_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/town_development_rules_ai.hpp"

#include <cstddef>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;

} // namespace

namespace scenario_factory {

DictRef _seed_recruits(State &state, ArrayRef built_buildings) {
	const DictRef recruits = state.new_dict();
	const DictRef growth_bonus = state.new_dict();
	for (const Value &building_id_value : gd::items(state, array_value(built_buildings))) {
		const DictRef building = gd::content_row(state, ContentTable::Building, gd::stringify(state, building_id_value));
		if (gd::is_empty(state, building)) {
			continue;
		}
		const Atom unlock_unit_id = ai::string_or_empty(state, building, key::unlock_unit_id);
		if (unlock_unit_id != key::empty) {
			state.set(recruits, str(unlock_unit_id), int_value(_unit_growth(state, unlock_unit_id)));
		}
		Value building_growth_bonus;
		if (state.lookup(building, str(key::growth_bonus), building_growth_bonus) && gd::is_dict(building_growth_bonus)) {
			for (const Value &unit_id : gd::items(state, building_growth_bonus)) {
				const Atom unit_key = gd::stringify(state, unit_id);
				const int64_t current = gd::int_field(state, growth_bonus, unit_key, 0);
				const int64_t bonus = gd::to_int(state, gd::index(state, building_growth_bonus.ref, unit_id));
				state.set(growth_bonus, str(unit_key), int_value(gd::add(current, bonus)));
			}
		}
	}

	for (const Value &unit_id : gd::items(state, dict_value(growth_bonus))) {
		const Value base_growth = int_value(_unit_growth(state, gd::to_string(unit_id)));
		const int64_t current = gd::to_int(state, state.get(recruits, unit_id, base_growth));
		const int64_t bonus = gd::to_int(state, gd::index(state, growth_bonus, unit_id));
		state.set(recruits, unit_id, int_value(gd::add(current, bonus)));
	}
	return recruits;
}

DictRef _seed_recruits_for_town_state(State &state, DictRef town) {
	if (town_development_rules::is_current(state, town)) {
		return town_development_rules::growth(state, town);
	}
	// A missing built list or recruitment profile reads as [] or {}, which
	// these calls treat as they treat null.
	DictRef recruits = _seed_recruits(state, _duplicate_array(state, gd::field(state, town, key::built_buildings)));
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	recruits = _apply_growth_profile(state, recruits, gd::field(state, town_template, key::recruitment));
	const DictRef faction = gd::content_row(state, ContentTable::Faction, ai::string_or_empty(state, town_template, key::faction_id));
	recruits = _apply_growth_profile(state, recruits, gd::field(state, faction, key::recruitment));
	return recruits;
}

DictRef _apply_growth_profile(State &state, DictRef recruits, const Value &profile) {
	const DictRef merged = gd::deep_duplicate_dict(state, recruits);
	if (!gd::is_dict(profile)) {
		return merged;
	}
	Value growth_bonus;
	if (!state.lookup(profile.ref, str(key::growth_bonus), growth_bonus) || !gd::is_dict(growth_bonus)) {
		return merged;
	}
	for (const Value &unit_id_value : gd::items(state, growth_bonus)) {
		const Atom unit_id = gd::stringify(state, unit_id_value);
		if (unit_id == key::empty || !state.has(merged, str(unit_id))) {
			continue;
		}
		const int64_t current = gd::int_field(state, merged, unit_id, 0);
		const int64_t bonus = gd::to_int(state, gd::index(state, growth_bonus.ref, str(unit_id)));
		state.set(merged, str(unit_id), int_value(gd::add(current, bonus > 0 ? bonus : 0)));
	}
	return merged;
}

int64_t _unit_growth(State &state, Atom unit_id) {
	const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
	const int64_t growth = gd::int_field(state, unit, key::growth, 0);
	return growth > 0 ? growth : 0;
}

ArrayRef _duplicate_array(State &state, const Value &value) {
	return gd::is_array(value) ? gd::deep_duplicate_array(state, value.ref) : state.new_array();
}

} // namespace scenario_factory

} // namespace aurelion::rules::port
