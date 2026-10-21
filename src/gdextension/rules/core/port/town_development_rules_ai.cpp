// TownDevelopmentRules: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/town_development_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"

#include <cstddef>
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
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;
using gd::bool_value;

} // namespace

namespace town_development_rules {

bool choice_blocked(State &state, DictRef town, DictRef building) {
	if (ai::string_or_empty(state, building, key::choice_group) == key::empty) {
		return false;
	}
	return choice_blocked_among(state, active_buildings(state, town), building);
}

bool has_dwelling_tier(State &state, DictRef town, int64_t tier) {
	return has_dwelling_tier_among(state, active_buildings(state, town), tier);
}

DictRef data(State &state) {
	return gd::content_file(state, key::town_development_path);
}

Atom faction_id(State &state, DictRef town) {
	const DictRef town_row = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	return ai::string_or_empty(state, town_row, key::faction_id);
}

bool is_current(State &state, DictRef town) {
	const DictRef town_row = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	return gd::int_field(state, town_row, key::development_version, 0) == 1;
}

void _sync_memo_sources(State &state) {
	const int64_t revision = gd::content_revision(state);
	const DictRef buildings = gd::content_file(state, key::buildings_path);
	const DictRef towns = gd::content_file(state, key::towns_path);
	const DictRef development = gd::content_file(state, key::town_development_path);
	const ArrayRef sources = ai::static_array(state, key::town_development_rules_script, key::_memo_sources);
	if (state.array_size(sources) == 4 && gd::equal(state, state.at(sources, 0), int_value(revision)) && gd::is_same(state, state.at(sources, 1), dict_value(buildings)) && gd::is_same(state, state.at(sources, 2), dict_value(towns)) && gd::is_same(state, state.at(sources, 3), dict_value(development))) {
		return;
	}
	gd::set_static_var(state, key::town_development_rules_script, key::_active_memo, dict_value(state.new_dict()));
	gd::set_static_var(state, key::town_development_rules_script, key::_satisfied_memo, dict_value(state.new_dict()));
	const ArrayRef made = state.new_array();
	state.append(made, int_value(revision));
	state.append(made, dict_value(buildings));
	state.append(made, dict_value(towns));
	state.append(made, dict_value(development));
	gd::set_static_var(state, key::town_development_rules_script, key::_memo_sources, array_value(made));
}

DictRef satisfied_ids(State &state, ArrayRef built) {
	return _satisfied_ids(state, built);
}

DictRef _satisfied_ids(State &state, ArrayRef built) {
	_sync_memo_sources(state);
	// "|".join(key_parts) of String(id) for each id.
	std::string joined;
	bool first = true;
	for (const Value &id : gd::items(state, array_value(built))) {
		const Atom part = gd::stringify(state, id);
		if (!first) {
			joined += '|';
		}
		first = false;
		joined += state.text(part);
	}
	const Value memo_key = str(state.intern(joined));
	Value cached;
	if (state.lookup(ai::static_dict(state, key::town_development_rules_script, key::_satisfied_memo), memo_key, cached)) {
		return gd::as_dict(cached);
	}
	const DictRef ids = state.new_dict();
	for (const Value &id : gd::items(state, array_value(built))) {
		Atom cursor = gd::stringify(state, id);
		while (cursor != key::empty && !state.has(ids, str(cursor))) {
			state.set(ids, str(cursor), bool_value(true));
			cursor = ai::string_or_empty(state, gd::content_row(state, ContentTable::Building, cursor), key::upgrade_from);
		}
	}
	if (state.dict_size(ai::static_dict(state, key::town_development_rules_script, key::_satisfied_memo)) > 512) {
		gd::set_static_var(state, key::town_development_rules_script, key::_satisfied_memo, dict_value(state.new_dict()));
	}
	state.set(ai::static_dict(state, key::town_development_rules_script, key::_satisfied_memo), memo_key, dict_value(ids));
	return ids;
}

ArrayRef active_buildings(State &state, DictRef town) {
	_sync_memo_sources(state);
	// "|".join(key_parts): the town id, then String(value) of each built value.
	std::string joined = state.text(ai::string_or_empty(state, town, key::town_id));
	Value built_value;
	if (state.lookup(town, str(key::built_buildings), built_value) && gd::is_array(built_value)) {
		for (const Value &value : gd::items(state, built_value)) {
			const Atom part = gd::stringify(state, value);
			joined += '|';
			joined += state.text(part);
		}
	}
	const Value memo_key = str(state.intern(joined));
	Value cached;
	if (state.lookup(ai::static_dict(state, key::town_development_rules_script, key::_active_memo), memo_key, cached)) {
		return gd::duplicate_array(state, gd::as_array(cached));
	}
	const ArrayRef active = _compute_active_buildings(state, town);
	if (state.dict_size(ai::static_dict(state, key::town_development_rules_script, key::_active_memo)) > 256) {
		gd::set_static_var(state, key::town_development_rules_script, key::_active_memo, dict_value(state.new_dict()));
	}
	state.set(ai::static_dict(state, key::town_development_rules_script, key::_active_memo), memo_key, array_value(gd::duplicate_array(state, active)));
	return active;
}

ArrayRef _compute_active_buildings(State &state, DictRef town) {
	const DictRef template_row = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	const ArrayRef result = state.new_array();
	const Value migration = gd::field_or(state, data(state), key::migration, dict_value(state.new_dict()));
	const Atom faction = faction_id(state, town);
	const DictRef mapping = gd::as_dict(ai::vget(state, migration, str(faction), dict_value(state.new_dict())));
	Value starting;
	const ArrayRef candidates = state.lookup(template_row, str(key::starting_building_ids), starting) ? gd::as_array(gd::duplicate_value(state, starting, false)) : state.new_array();
	Value built;
	if (state.lookup(town, str(key::built_buildings), built)) {
		ai::append_array(state, candidates, gd::as_array(built));
	}
	const DictRef choices = state.new_dict();
	for (const Value &value : gd::items(state, array_value(candidates))) {
		const Atom value_text = gd::stringify(state, value);
		const Atom id = gd::stringify(state, state.get(mapping, str(value_text), str(value_text)));
		const DictRef b = gd::content_row(state, ContentTable::Building, id);
		if (gd::int_field(state, b, key::development_version, 0) != 1) {
			continue;
		}
		const Atom group = ai::string_or_empty(state, b, key::choice_group);
		const int64_t branch = gd::int_field(state, b, key::choice_branch, 0);
		if (group != key::empty) {
			Value chosen;
			if (state.lookup(choices, str(group), chosen) && !gd::equal(state, chosen, int_value(branch))) {
				continue;
			}
			state.set(choices, str(group), int_value(branch));
		}
		if (!gd::array_has(state, result, str(id))) {
			state.append(result, str(id));
		}
	}
	// Persist only the active stage. A stage is ancestry when the upgrade chain
	// of another listed stage passes through it; each chain also holds its own
	// stage, so ancestry is held by two chains or more.
	const DictRef chain_counts = state.new_dict();
	for (const Value &id : gd::items(state, array_value(result))) {
		const DictRef chain = state.new_dict();
		Atom cursor = gd::stringify(state, id);
		while (cursor != key::empty && !state.has(chain, str(cursor))) {
			state.set(chain, str(cursor), bool_value(true));
			state.set(chain_counts, str(cursor), int_value(gd::add(gd::int_field(state, chain_counts, cursor, 0), 1)));
			cursor = ai::string_or_empty(state, gd::content_row(state, ContentTable::Building, cursor), key::upgrade_from);
		}
	}
	const ArrayRef active = state.new_array();
	for (const Value &id : gd::items(state, array_value(result))) {
		if (gd::int_field(state, chain_counts, gd::stringify(state, id), 0) < 2) {
			state.append(active, id);
		}
	}
	return active;
}

bool choice_blocked_among(State &state, ArrayRef active, DictRef building) {
	const Atom group = ai::string_or_empty(state, building, key::choice_group);
	if (group == key::empty) {
		return false;
	}
	for (const Value &id : gd::items(state, array_value(active))) {
		const DictRef b = gd::content_row(state, ContentTable::Building, gd::stringify(state, id));
		if (gd::equal(state, gd::field_or(state, b, key::choice_group, str(key::empty)), str(group))) {
			const Value branch = gd::field_or(state, b, key::choice_branch, int_value(0));
			if (!gd::equal(state, branch, gd::field_or(state, building, key::choice_branch, int_value(0)))) {
				return true;
			}
		}
	}
	return false;
}

bool has_dwelling_tier_among(State &state, ArrayRef active, int64_t tier) {
	for (const Value &id : gd::items(state, array_value(active))) {
		const DictRef b = gd::content_row(state, ContentTable::Building, gd::stringify(state, id));
		if (gd::int_field(state, b, key::dwelling_tier, 0) == tier) {
			return true;
		}
	}
	return false;
}

DictRef growth(State &state, DictRef town) {
	const DictRef result = state.new_dict();
	const DictRef bonuses = state.new_dict();
	int64_t percent = 0;
	const ArrayRef built = active_buildings(state, town);
	for (const Value &id : gd::items(state, array_value(built))) {
		const DictRef b = gd::content_row(state, ContentTable::Building, gd::stringify(state, id));
		const Value tier = int_value(gd::int_field(state, b, key::growth_tier, 0));
		const int64_t bonus = gd::to_int(state, state.get(bonuses, tier, int_value(0)));
		state.set(bonuses, tier, int_value(gd::add(bonus, gd::int_field(state, b, key::growth_amount, 0))));
		percent = gd::add(percent, gd::int_field(state, b, key::growth_percent, 0));
	}
	// Fortifications raise every dwelling's whole week, flat bonuses included;
	// fractions round up.
	for (const Value &id : gd::items(state, array_value(built))) {
		const DictRef b = gd::content_row(state, ContentTable::Building, gd::stringify(state, id));
		const Atom uid = ai::string_or_empty(state, b, key::unlock_unit_id);
		if (uid == key::empty) {
			continue;
		}
		const DictRef unit = gd::content_row(state, ContentTable::Unit, uid);
		const int64_t unit_growth = gd::int_field(state, unit, key::growth, 1);
		const Value unit_tier = int_value(gd::int_field(state, unit, key::tier, 0));
		const int64_t weekly = gd::add(unit_growth, gd::to_int(state, state.get(bonuses, unit_tier, int_value(0))));
		state.set(result, str(uid), int_value(gd::add(gd::mul(weekly, gd::add(100, percent)), 99) / 100));
	}
	return result;
}

DictRef income(State &state, DictRef town) {
	const DictRef result = state.new_dict();
	const DictRef faction = gd::content_row(state, ContentTable::Faction, faction_id(state, town));
	const ArrayRef active = active_buildings(state, town);
	for (const Value &id : gd::items(state, array_value(active))) {
		const DictRef b = gd::content_row(state, ContentTable::Building, gd::stringify(state, id));
		for (const Value &resource : gd::field_items(state, b, str(key::income))) {
			const int64_t have = gd::to_int(state, state.get(result, resource, int_value(0)));
			const int64_t gain = gd::to_int(state, ai::vindex(state, gd::index(state, b, str(key::income)), resource));
			state.set(result, resource, int_value(gd::add(have, gain)));
		}
		const int64_t amount = gd::int_field(state, b, key::faction_resource_income, 0);
		if (amount > 0) {
			Value town_resources;
			const Atom resource = state.lookup(faction, str(key::town_resources), town_resources) ? gd::stringify(state, ai::vget(state, town_resources, key::main, str(key::empty))) : key::empty;
			if (resource != key::empty) {
				state.set(result, str(resource), int_value(gd::add(gd::int_field(state, result, resource, 0), amount)));
			}
		}
	}
	return result;
}

} // namespace town_development_rules

} // namespace aurelion::rules::port
