// TownRules ports shared by the computer players' day (Phase 4) and the ends of a
// battle (Phase 5): the spells a town's mage guild teaches. Phase 4's ports
// (branch native-phase4-faction-turn), moved unchanged by Phase 5's slice 09.

#include "aurelion_rules/port/town_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::str;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;

// maxi and max() of ints.
int64_t imax(int64_t a, int64_t b) {
	return compat::engine_max<int64_t>(a, b);
}

// String(d.get(field, fallback)).
Atom text_field(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// TownRules.FACTION_SPELL_SCHOOL_ACCESS.get(faction_id, []).
std::vector<Atom> faction_spell_schools(Atom faction_id) {
	if (faction_id == key::faction_embercourt) {
		return { key::beacon, key::furnace };
	}
	if (faction_id == key::faction_mireclaw) {
		return { key::mire, key::root };
	}
	if (faction_id == key::faction_sunvault) {
		return { key::lens, key::beacon };
	}
	if (faction_id == key::faction_thornwake) {
		return { key::root, key::mire };
	}
	if (faction_id == key::faction_brasshollow) {
		return { key::furnace, key::old_measure };
	}
	if (faction_id == key::faction_veilmourn) {
		return { key::veil, key::old_measure };
	}
	return {};
}

} // namespace

namespace town_rules {

int64_t current_spell_tier(State &state, DictRef town) {
	int64_t highest_tier = 0;
	for (const Value &building_id_value : gd::field_items(state, town, str(key::built_buildings))) {
		const DictRef building = gd::content_row(state, ContentTable::Building, gd::stringify(state, building_id_value));
		highest_tier = imax(highest_tier, gd::int_field(state, building, key::spell_tier, 0));
	}
	return highest_tier;
}

ArrayRef accessible_spell_ids(State &state, DictRef town) {
	return spell_ids_through_tier(state, town, current_spell_tier(state, town));
}

ArrayRef spell_ids_through_tier(State &state, DictRef town, int64_t tier) {
	const DictRef town_template = gd::content_row(state, ContentTable::Town, text_field(state, town, key::town_id, key::empty));
	if (tier <= 0) {
		return state.new_array();
	}
	const ArrayRef spell_ids = state.new_array();
	for (const Value &entry : gd::field_items(state, town_template, str(key::spell_library))) {
		if (!gd::is_dict(entry)) {
			continue;
		}
		if (gd::int_field(state, entry.ref, key::tier, 0) > tier) {
			continue;
		}
		for (const Value &spell_id_value : gd::field_items(state, entry.ref, str(key::spell_ids))) {
			const Atom spell_id = gd::stringify(state, spell_id_value);
			if (spell_id != key::empty && !gd::array_has(state, spell_ids, str(spell_id))) {
				state.append(spell_ids, str(spell_id));
			}
		}
	}
	for (const Value &spell_id : gd::items(state, array_value(_school_spell_ids_for_town(state, town_template, tier)))) {
		if (!gd::equal(state, spell_id, str(key::empty)) && !gd::array_has(state, spell_ids, spell_id)) {
			state.append(spell_ids, spell_id);
		}
	}
	return spell_ids;
}

ArrayRef _school_spell_ids_for_town(State &state, DictRef town_template, int64_t tier) {
	const ArrayRef allowed_schools = _town_spell_school_access(state, town_template);
	if (state.array_size(allowed_schools) == 0) {
		return state.new_array();
	}
	const ArrayRef results = state.new_array();
	Value spells;
	if (!state.lookup(gd::content_file(state, key::spells_path), str(key::items), spells) || !gd::is_array(spells)) {
		return results;
	}
	for (const Value &spell_value : gd::items(state, spells)) {
		if (!gd::is_dict(spell_value)) {
			continue;
		}
		const DictRef spell = spell_value.ref;
		const Atom spell_id = text_field(state, spell, key::id, key::empty);
		if (spell_id == key::empty) {
			continue;
		}
		if (gd::int_field(state, spell, key::tier, 0) > tier) {
			continue;
		}
		if (gd::array_has(state, allowed_schools, str(text_field(state, spell, key::school_id, key::empty))) && !gd::array_has(state, results, str(spell_id))) {
			state.append(results, str(spell_id));
		}
	}
	return results;
}

ArrayRef _town_spell_school_access(State &state, DictRef town_template) {
	const ArrayRef schools = state.new_array();
	const Atom faction_id = text_field(state, town_template, key::faction_id, key::empty);
	for (const Atom school_id : faction_spell_schools(faction_id)) {
		if (school_id != key::empty && !gd::array_has(state, schools, str(school_id))) {
			state.append(schools, str(school_id));
		}
	}
	if (!gd::array_has(state, schools, str(key::old_measure))) {
		state.append(schools, str(key::old_measure));
	}
	return schools;
}

} // namespace town_rules

} // namespace aurelion::rules::port
