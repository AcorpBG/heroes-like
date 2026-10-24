// TownConstructionBoard for the human seat (Phase 7, slice 7.6): the town's
// construction board, its slots and their status.

#include "aurelion_rules/port/town_rules_actions.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/town_development_rules_ai.hpp"
#include "aurelion_rules/port/town_development_rules_turn.hpp"

#include <string>
#include <vector>

namespace aurelion::rules::port {

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
using state::State;
using state::Value;
namespace key = state::key;

// RESOURCE_ORDER.
constexpr Atom kResourceOrder[] = {key::gold, key::wood, key::ore, key::aetherglass, key::embergrain, key::peatwax, key::verdant_grafts, key::brass_scrip, key::memory_salt};

// ROMAN.
constexpr Atom kRoman[] = {key::empty, key::I, key::II, key::III, key::IV, key::V, key::VI, key::VII};

// ContentService.get_building(id) of an untyped id.
DictRef building_row(State &state, const Value &id) {
	return gd::content_row(state, ContentTable::Building, gd::to_string(id));
}

// String(text).split(" ")[0]: the text before the first space.
Atom first_word(State &state, Atom text) {
	const std::string &value = state.text(text);
	const size_t at = value.find(state.text(key::space));
	if (at == std::string::npos) {
		return text;
	}
	return state.intern(value.substr(0, at));
}

// sep.join(parts) of Strings.
Atom join_atoms(State &state, Atom separator, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// sep.join(array) of an Array of Strings.
Atom join_array(State &state, Atom separator, ArrayRef array) {
	std::vector<Atom> parts;
	for (const Value &item : gd::items(state, array_value(array))) {
		parts.push_back(gd::stringify(state, item));
	}
	return join_atoms(state, separator, parts);
}

// for x in value.get(field, []) of an untyped value.
gd::Items untyped_field_items(State &state, const Value &object, Atom field) {
	if (gd::is_dict(object)) {
		return gd::field_items(state, object.ref, str(field));
	}
	return gd::items(state, ai::vget(state, object, field));
}

// value in object.get(field, []) of an untyped object, read only.
bool untyped_field_has(State &state, const Value &object, Atom field, const Value &value) {
	if (gd::is_dict(object)) {
		Value found;
		if (!state.lookup(object.ref, str(field), found)) {
			return false;
		}
		return gd::in(state, value, found);
	}
	return gd::in(state, value, ai::vget(state, object, field));
}

// var row: Dictionary = context.catalog.get(building_id, {}).
DictRef catalog_row(State &state, DictRef context, Atom building_id) {
	const DictRef catalog = gd::as_dict(gd::index(state, context, str(key::catalog)));
	Value found;
	if (state.lookup(catalog, str(building_id), found)) {
		return gd::as_dict(found);
	}
	return state.new_dict();
}

// a.sort_custom(func(a, b): return int(a.stage) < int(b.stage)).
void sort_by_stage(State &state, ArrayRef array) {
	gd::sort_custom(state, array, [&state](const Value &a, const Value &b) {
		return gd::to_int(state, ai::vmember(state, a, key::stage)) < gd::to_int(state, ai::vmember(state, b, key::stage));
	});
}

// a.sort() of an Array that holds only Strings (code point order).
void sort_strings(State &state, ArrayRef array) {
	gd::sort_custom(state, array, [&state](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
}

// {"id": building_id, "stage": int(building.get("stage", 1))}.
DictRef stage_entry(State &state, const Value &building_id, DictRef building) {
	const DictRef entry = state.new_dict();
	state.set(entry, str(key::id), building_id);
	state.set(entry, str(key::stage), int_value(gd::int_field(state, building, key::stage, 1)));
	return entry;
}

// String(entry.id) of each entry.
ArrayRef entry_ids(State &state, ArrayRef entries) {
	const ArrayRef chain = state.new_array();
	for (const Value &entry : gd::items(state, array_value(entries))) {
		state.append(chain, str(gd::stringify(state, ai::vmember(state, entry, key::id))));
	}
	return chain;
}

} // namespace

namespace town_construction_board {

DictRef layout(State &state) {
	return gd::content_file(state, key::town_construction_layout_path);
}

DictRef build_for_active_town(State &state, const Value &session) {
	const DictRef view = gd::as_dict(session);
	const DictRef town = town_rules::get_active_town(state, view);
	if (gd::is_empty(state, town)) {
		return state.new_dict();
	}
	const DictRef overworld = session_view::overworld(state, view);
	Value resources_value;
	const DictRef resources = state.lookup(overworld, str(key::resources), resources_value) && gd::is_dict(resources_value) ? resources_value.ref : state.new_dict();
	const DictRef rows_by_building = state.new_dict();
	const ArrayRef catalog = town_rules::get_build_catalog(state, view);
	for (const Value &row_value : gd::items(state, array_value(catalog))) {
		if (gd::is_dict(row_value)) {
			state.set(rows_by_building, str(ai::string_or_empty(state, row_value.ref, key::building_id)), row_value);
		}
	}
	return build(state, town, ai::session_int(state, view, key::day), resources, rows_by_building);
}

DictRef build(State &state, DictRef town, int64_t day, DictRef resources, DictRef catalog_by_building) {
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	const Atom faction_id = ai::string_or_empty(state, town_template, key::faction_id);
	const ArrayRef town_ids = town_building_ids(state, town_template);
	ArrayRef active = 0;
	if (town_development_rules::is_current(state, town)) {
		active = town_development_rules::active_buildings(state, town);
	} else {
		Value built;
		active = state.lookup(town, str(key::built_buildings), built) ? gd::as_array(gd::duplicate_value(state, built, false)) : state.new_array();
	}
	const bool built_today = day > 0 && gd::int_field(state, town, key::last_build_day, 0) == day;
	const DictRef context = state.new_dict();
	state.set(context, str(key::town), dict_value(town));
	state.set(context, str(key::day), int_value(day));
	state.set(context, str(key::faction_id), str(faction_id));
	state.set(context, str(key::active), array_value(active));
	state.set(context, str(key::resources), dict_value(resources));
	state.set(context, str(key::catalog), dict_value(catalog_by_building));
	state.set(context, str(key::built_today), bool_value(built_today));
	const ArrayRef rows = state.new_array();
	const DictRef assigned = state.new_dict();
	int64_t slot_count = 0;
	const DictRef layout_document = layout(state);
	for (const Value &row_value : gd::field_items(state, layout_document, str(key::rows))) {
		if (!gd::is_dict(row_value)) {
			continue;
		}
		const DictRef row_spec = row_value.ref;
		const ArrayRef slots = state.new_array();
		for (const Value &slot_value : gd::field_items(state, row_spec, str(key::slots))) {
			if (!gd::is_dict(slot_value)) {
				continue;
			}
			const DictRef slot = _build_slot(state, slot_value.ref, ai::string_or_empty(state, row_spec, key::id), town_ids, context);
			if (gd::is_empty(state, slot)) {
				continue;
			}
			for (const Value &building_id : gd::field_items(state, slot, str(key::building_ids))) {
				state.set(assigned, building_id, str(ai::string_or_empty(state, slot, key::id)));
			}
			state.append(slots, dict_value(slot));
			slot_count += 1;
		}
		const DictRef faction = gd::content_row(state, ContentTable::Faction, faction_id);
		const Atom faction_word = first_word(state, gd::stringify(state, gd::field_or(state, faction, key::name, str(key::Faction))));
		const DictRef row = state.new_dict();
		state.set(row, str(key::id), str(ai::string_or_empty(state, row_spec, key::id)));
		state.set(row, str(key::title), str(gd::replace(state, ai::string_or_empty(state, row_spec, key::title), key::faction_2, faction_word)));
		state.set(row, str(key::subtitle), str(gd::replace(state, ai::string_or_empty(state, row_spec, key::subtitle), key::faction_2, faction_word)));
		state.set(row, str(key::slots), array_value(slots));
		state.append(rows, dict_value(row));
	}
	const ArrayRef unassigned = state.new_array();
	for (const Value &building_id : gd::items(state, array_value(town_ids))) {
		if (!state.has(assigned, building_id)) {
			state.append(unassigned, building_id);
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::schema), str(key::town_construction_board_v1));
	state.set(result, str(key::town_id), str(gd::stringify(state, gd::field_or(state, town_template, key::id, gd::field_or(state, town, key::town_id, str(key::empty))))));
	state.set(result, str(key::town_name), str(gd::stringify(state, gd::field_or(state, town_template, key::name, gd::field_or(state, town, key::town_id, str(key::empty))))));
	state.set(result, str(key::faction_id), str(faction_id));
	state.set(result, str(key::faction_name), str(ai::string_or_empty(state, gd::content_row(state, ContentTable::Faction, faction_id), key::name)));
	state.set(result, str(key::day), int_value(day));
	state.set(result, str(key::built_today), bool_value(built_today));
	state.set(result, str(key::rows), array_value(rows));
	state.set(result, str(key::slot_count), int_value(slot_count));
	state.set(result, str(key::unassigned_building_ids), array_value(unassigned));
	return result;
}

ArrayRef town_building_ids(State &state, DictRef town_template) {
	const ArrayRef ids = state.new_array();
	const Atom sources[] = {key::starting_building_ids, key::buildable_building_ids};
	for (const Atom field : sources) {
		Value source;
		if (!state.lookup(town_template, str(field), source) || !gd::is_array(source)) {
			continue;
		}
		for (const Value &value : gd::items(state, source)) {
			const Atom building_id = gd::stringify(state, value);
			if (building_id != key::empty && !gd::array_has(state, ids, str(building_id)) && !gd::is_empty(state, gd::content_row(state, ContentTable::Building, building_id))) {
				state.append(ids, str(building_id));
			}
		}
	}
	return ids;
}

DictRef slot_for_building(State &state, DictRef board, Atom building_id) {
	for (const Value &row : gd::field_items(state, board, str(key::rows))) {
		for (const Value &slot : untyped_field_items(state, row, key::slots)) {
			if (untyped_field_has(state, slot, key::building_ids, str(building_id))) {
				return gd::as_dict(slot);
			}
		}
	}
	return state.new_dict();
}

Atom format_amount(State &state, int64_t value) {
	std::string digits = std::to_string(compat::absi(value));
	std::string grouped;
	while (digits.size() > 3) {
		grouped = state.text(key::comma) + digits.substr(digits.size() - 3) + grouped;
		digits = digits.substr(0, digits.size() - 3);
	}
	return state.intern((value < 0 ? state.text(key::dash) : state.text(key::empty)) + digits + grouped);
}

Atom resource_name(State &state, Atom resource_id) {
	return gd::replace(state, resource_id, key::_, key::space);
}

Atom roman(State &state, int64_t tier) {
	constexpr int64_t kRomanSize = static_cast<int64_t>(sizeof(kRoman) / sizeof(kRoman[0]));
	if (tier > 0 && tier < kRomanSize) {
		return kRoman[tier];
	}
	return gd::stringify(state, int_value(tier));
}

DictRef _build_slot(State &state, DictRef spec, Atom row_id, ArrayRef town_ids, DictRef context) {
	const DictRef slot = state.new_dict();
	state.set(slot, str(key::id), str(ai::string_or_empty(state, spec, key::id)));
	state.set(slot, str(key::row_id), str(row_id));
	state.set(slot, str(key::blurb), str(ai::string_or_empty(state, spec, key::blurb)));
	state.set(slot, str(key::line_title), str(ai::string_or_empty(state, spec, key::title)));
	state.set(slot, str(key::tier), int_value(0));
	state.set(slot, str(key::tier_label), str(key::empty));
	if (state.has(spec, str(key::line_id))) {
		const ArrayRef chain = _line_chain(state, ai::string_or_empty(state, spec, key::line_id), town_ids);
		if (state.array_size(chain) == 0) {
			return state.new_dict();
		}
		state.set(slot, str(key::kind), str(key::line));
		return _finish_chain_slot(state, slot, chain, context);
	}
	if (state.has(spec, str(key::building_id))) {
		const Atom building_id = ai::string_or_empty(state, spec, key::building_id);
		if (!gd::array_has(state, town_ids, str(building_id))) {
			return state.new_dict();
		}
		state.set(slot, str(key::kind), str(key::single));
		const ArrayRef chain = state.new_array();
		state.append(chain, str(building_id));
		return _finish_chain_slot(state, slot, chain, context);
	}
	if (state.has(spec, str(key::faction_special))) {
		const ArrayRef specials = state.new_array();
		for (const Value &building_id : gd::items(state, array_value(town_ids))) {
			const DictRef building = building_row(state, building_id);
			if (ai::string_or_empty(state, building, key::faction_id) != key::empty && gd::int_field(state, building, key::dwelling_tier, 0) == 0) {
				state.append(specials, building_id);
			}
		}
		sort_strings(state, specials);
		const int64_t index = gd::sub(gd::int_field(state, spec, key::faction_special, 0), 1);
		if (index < 0 || index >= state.array_size(specials)) {
			return state.new_dict();
		}
		state.set(slot, str(key::kind), str(key::single));
		const Atom special_id = gd::stringify(state, state.at(specials, index));
		if (gd::stringify(state, gd::index(state, slot, str(key::blurb))) == key::empty) {
			state.set(slot, str(key::blurb), str(_first_sentence(state, ai::string_or_empty(state, gd::content_row(state, ContentTable::Building, special_id), key::description))));
		}
		const ArrayRef chain = state.new_array();
		state.append(chain, str(special_id));
		return _finish_chain_slot(state, slot, chain, context);
	}
	if (state.has(spec, str(key::dwelling_tier))) {
		return _dwelling_slot(state, slot, gd::int_field(state, spec, key::dwelling_tier, 0), town_ids, context);
	}
	return state.new_dict();
}

ArrayRef _line_chain(State &state, Atom line_id, ArrayRef town_ids) {
	const ArrayRef stages = state.new_array();
	for (const Value &building_id : gd::items(state, array_value(town_ids))) {
		const DictRef building = building_row(state, building_id);
		if (ai::string_or_empty(state, building, key::line_id) == line_id && gd::int_field(state, building, key::dwelling_tier, 0) == 0) {
			state.append(stages, dict_value(stage_entry(state, building_id, building)));
		}
	}
	sort_by_stage(state, stages);
	return entry_ids(state, stages);
}

ArrayRef _dwelling_branches(State &state, int64_t tier, ArrayRef town_ids) {
	const DictRef by_branch = state.new_dict();
	for (const Value &building_id : gd::items(state, array_value(town_ids))) {
		const DictRef building = building_row(state, building_id);
		if (gd::int_field(state, building, key::dwelling_tier, 0) != tier) {
			continue;
		}
		const int64_t branch = gd::int_field(state, building, key::choice_branch, 1);
		if (!state.has(by_branch, int_value(branch))) {
			state.set(by_branch, int_value(branch), array_value(state.new_array()));
		}
		const ArrayRef entries = gd::as_array(gd::index(state, by_branch, int_value(branch)));
		state.append(entries, dict_value(stage_entry(state, building_id, building)));
	}
	const ArrayRef branches = state.new_array();
	const ArrayRef keys = gd::keys(state, by_branch);
	gd::sort_custom(state, keys, [](const Value &a, const Value &b) { return gd::op_less(a, b); });
	for (const Value &branch : gd::items(state, array_value(keys))) {
		const ArrayRef entries = gd::as_array(gd::index(state, by_branch, branch));
		sort_by_stage(state, entries);
		const ArrayRef chain = entry_ids(state, entries);
		const DictRef record = state.new_dict();
		state.set(record, str(key::branch), int_value(gd::to_int(state, branch)));
		state.set(record, str(key::chain), array_value(chain));
		state.append(branches, dict_value(record));
	}
	return branches;
}

DictRef _dwelling_slot(State &state, DictRef slot, int64_t tier, ArrayRef town_ids, DictRef context) {
	const ArrayRef branches = _dwelling_branches(state, tier, town_ids);
	if (state.array_size(branches) == 0) {
		return state.new_dict();
	}
	state.set(slot, str(key::tier), int_value(tier));
	state.set(slot, str(key::tier_label), str(roman(state, tier)));
	const ArrayRef all_ids = state.new_array();
	DictRef chosen = state.new_dict();
	for (const Value &branch : gd::items(state, array_value(branches))) {
		ai::append_array(state, all_ids, gd::as_array(ai::vmember(state, branch, key::chain)));
		for (const Value &building_id : gd::items(state, ai::vmember(state, branch, key::chain))) {
			if (_stage_done(state, gd::stringify(state, building_id), context)) {
				chosen = gd::as_dict(branch);
			}
		}
	}
	if (state.array_size(branches) > 1 && gd::is_empty(state, chosen)) {
		// Open exclusive choice: both base dwellings share cost and prerequisites.
		state.set(slot, str(key::kind), str(key::choice));
		const ArrayRef options = state.new_array();
		for (const Value &branch : gd::items(state, array_value(branches))) {
			const ArrayRef chain = gd::as_array(ai::vmember(state, branch, key::chain));
			const Atom base_id = gd::stringify(state, state.at(chain, 0));
			const Atom upgrade_id = state.array_size(chain) > 1 ? gd::stringify(state, state.at(chain, 1)) : key::empty;
			const DictRef base = gd::content_row(state, ContentTable::Building, base_id);
			const Atom unit_id = ai::string_or_empty(state, base, key::unlock_unit_id);
			const Atom upgrade_unit_id = upgrade_id != key::empty ? ai::string_or_empty(state, gd::content_row(state, ContentTable::Building, upgrade_id), key::unlock_unit_id) : key::empty;
			const DictRef option = state.new_dict();
			state.set(option, str(key::branch), int_value(gd::to_int(state, ai::vmember(state, branch, key::branch))));
			state.set(option, str(key::building_id), str(base_id));
			state.set(option, str(key::building_name), str(gd::stringify(state, gd::field_or(state, base, key::name, str(base_id)))));
			state.set(option, str(key::upgrade_building_id), str(upgrade_id));
			state.set(option, str(key::unit_id), str(unit_id));
			state.set(option, str(key::unit_name), str(gd::stringify(state, gd::field_or(state, gd::content_row(state, ContentTable::Unit, unit_id), key::name, str(unit_id)))));
			state.set(option, str(key::upgrade_unit_id), str(upgrade_unit_id));
			state.set(option, str(key::upgrade_unit_name), str(gd::stringify(state, gd::field_or(state, gd::content_row(state, ContentTable::Unit, upgrade_unit_id), key::name, str(upgrade_unit_id)))));
			state.append(options, dict_value(option));
		}
		state.set(slot, str(key::options), array_value(options));
		state.set(slot, str(key::building_ids), array_value(all_ids));
		state.set(slot, str(key::stages), array_value(state.new_array()));
		state.set(slot, str(key::done_count), int_value(0));
		state.set(slot, str(key::stage_count), int_value(ai::vsize(state, ai::vmember(state, state.at(branches, 0), key::chain))));
		state.set(slot, str(key::current_id), str(key::empty));
		state.set(slot, str(key::next_id), str(gd::stringify(state, ai::vmember(state, state.at(options, 0), key::building_id))));
		state.set(slot, str(key::art_building_id), str(gd::stringify(state, ai::vmember(state, state.at(options, 0), key::building_id))));
		state.set(slot, str(key::built), bool_value(false));
		std::vector<Atom> unit_names;
		for (const Value &option : gd::items(state, array_value(options))) {
			unit_names.push_back(gd::stringify(state, ai::vmember(state, option, key::unit_name)));
		}
		state.set(slot, str(key::title), str(join_atoms(state, key::or_, unit_names)));
		_apply_status(state, slot, gd::stringify(state, ai::vmember(state, state.at(options, 0), key::building_id)), context, key::Choose);
		return slot;
	}
	const DictRef selected = !gd::is_empty(state, chosen) ? chosen : gd::as_dict(state.at(branches, 0));
	state.set(slot, str(key::kind), str(key::dwelling));
	const DictRef result = _finish_chain_slot(state, slot, gd::as_array(gd::index(state, selected, str(key::chain))), context);
	state.set(result, str(key::building_ids), array_value(all_ids));
	const ArrayRef forgone = state.new_array();
	for (const Value &branch : gd::items(state, array_value(branches))) {
		if (gd::to_int(state, ai::vmember(state, branch, key::branch)) != gd::to_int(state, gd::index(state, selected, str(key::branch)))) {
			const DictRef base = gd::content_row(state, ContentTable::Building, gd::stringify(state, ai::vindex(state, ai::vmember(state, branch, key::chain), int_value(0))));
			const DictRef unit = gd::content_row(state, ContentTable::Unit, ai::string_or_empty(state, base, key::unlock_unit_id));
			state.append(forgone, str(ai::string_or_empty(state, unit, key::name)));
		}
	}
	state.set(result, str(key::forgone_unit_names), array_value(forgone));
	const Atom display_id = ai::string_or_empty(state, result, key::current_id) != key::empty ? ai::string_or_empty(state, result, key::current_id) : gd::stringify(state, ai::vindex(state, gd::index(state, selected, str(key::chain)), int_value(0)));
	const Atom unit_id = ai::string_or_empty(state, gd::content_row(state, ContentTable::Building, display_id), key::unlock_unit_id);
	const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
	state.set(result, str(key::title), str(gd::stringify(state, gd::field_or(state, unit, key::name, gd::field_or(state, result, key::title, str(key::empty))))));
	return result;
}

DictRef _finish_chain_slot(State &state, DictRef slot, ArrayRef chain, DictRef context) {
	const ArrayRef stages = state.new_array();
	Atom current_id = key::empty;
	Atom next_id = key::empty;
	int64_t done_count = 0;
	for (const Value &building_id_value : gd::items(state, array_value(chain))) {
		const Atom building_id = gd::stringify(state, building_id_value);
		const bool done = _stage_done(state, building_id, context);
		if (done) {
			current_id = building_id;
			done_count += 1;
		} else if (next_id == key::empty) {
			next_id = building_id;
		}
		const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
		const DictRef stage = state.new_dict();
		state.set(stage, str(key::building_id), str(building_id));
		state.set(stage, str(key::name), str(gd::stringify(state, gd::field_or(state, building, key::name, str(building_id)))));
		state.set(stage, str(key::done), bool_value(done));
		state.set(stage, str(key::next), bool_value(false));
		state.set(stage, str(key::unit_id), str(ai::string_or_empty(state, building, key::unlock_unit_id)));
		state.append(stages, dict_value(stage));
	}
	for (const Value &stage : gd::items(state, array_value(stages))) {
		state.set(gd::as_dict(stage), str(key::next), bool_value(gd::stringify(state, ai::vmember(state, stage, key::building_id)) == next_id));
	}
	const int64_t chain_size = state.array_size(chain);
	state.set(slot, str(key::stages), array_value(stages));
	state.set(slot, str(key::building_ids), array_value(gd::duplicate_array(state, chain)));
	state.set(slot, str(key::done_count), int_value(done_count));
	state.set(slot, str(key::stage_count), int_value(chain_size));
	state.set(slot, str(key::current_id), str(current_id));
	state.set(slot, str(key::next_id), str(next_id));
	state.set(slot, str(key::built), bool_value(current_id != key::empty));
	state.set(slot, str(key::art_building_id), str(current_id != key::empty ? current_id : gd::stringify(state, state.at(chain, 0))));
	const Value art_building_id = gd::index(state, slot, str(key::art_building_id));
	const DictRef art_building = gd::content_row(state, ContentTable::Building, gd::stringify(state, art_building_id));
	state.set(slot, str(key::title), str(gd::stringify(state, gd::field_or(state, art_building, key::name, art_building_id))));
	if (next_id == key::empty) {
		state.set(slot, str(key::status), str(key::complete));
		state.set(slot, str(key::status_text), str(chain_size == 1 ? key::Built : key::Complete));
		state.set(slot, str(key::status_detail), str(chain_size == 1 ? key::standing_in_this_town : key::every_stage_of_this_line_stands));
		state.set(slot, str(key::cost), dict_value(state.new_dict()));
		state.set(slot, str(key::shortfall), dict_value(state.new_dict()));
		state.set(slot, str(key::missing_requirements), array_value(state.new_array()));
		state.set(slot, str(key::verb), str(key::empty));
		return slot;
	}
	_apply_status(state, slot, next_id, context, current_id != key::empty ? key::Upgrade : key::Build);
	return slot;
}

bool _stage_done(State &state, Atom building_id, DictRef context) {
	const DictRef row = catalog_row(state, context, building_id);
	if (!gd::is_empty(state, row)) {
		const Atom catalog_status = ai::string_or_empty(state, row, key::catalog_status);
		return catalog_status == key::Built || catalog_status == key::Upgraded || gd::bool_field(state, row, key::built, false);
	}
	return town_development_rules::satisfies(state, gd::as_array(gd::index(state, context, str(key::active))), building_id);
}

void _apply_status(State &state, DictRef slot, Atom building_id, DictRef context, Atom verb) {
	const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
	Value cost_value;
	const DictRef cost = state.lookup(building, str(key::cost), cost_value) && gd::is_dict(cost_value) ? cost_value.ref : state.new_dict();
	const DictRef row = catalog_row(state, context, building_id);
	const ArrayRef missing = _missing_requirement_names(state, building, context);
	const DictRef shortfall = _shortfall(state, cost, gd::as_dict(gd::index(state, context, str(key::resources))));
	state.set(slot, str(key::verb), str(verb));
	state.set(slot, str(key::cost), gd::engine_duplicate(state, dict_value(cost), true));
	state.set(slot, str(key::shortfall), dict_value(shortfall));
	state.set(slot, str(key::missing_requirements), array_value(missing));
	const int64_t missing_count = state.array_size(missing);
	if (missing_count > 0 || gd::is_empty(state, row)) {
		state.set(slot, str(key::status), str(key::locked));
		const Atom first = missing_count > 0 ? gd::stringify(state, state.at(missing, 0)) : key::its_prerequisites;
		const Atom more = missing_count > 1 ? gd::format(state, key::d, {int_value(missing_count - 1)}) : key::empty;
		state.set(slot, str(key::status_text), str(gd::format(state, key::needs_s_s, {str(first), str(more)})));
		const Atom requires_text = gd::format(state, key::requires_s, {str(join_array(state, key::comma_space, missing))});
		state.set(slot, str(key::status_detail), str(gd::stringify(state, gd::field_or(state, row, key::catalog_status_detail, str(requires_text)))));
		return;
	}
	if (gd::to_bool(gd::index(state, context, str(key::built_today)))) {
		state.set(slot, str(key::status), str(key::tomorrow));
		state.set(slot, str(key::status_text), str(key::Tomorrow));
		state.set(slot, str(key::status_detail), str(key::this_town_already_built_today_one));
		return;
	}
	if (gd::bool_field(state, row, key::direct_affordable, false)) {
		state.set(slot, str(key::status), str(key::ready));
		state.set(slot, str(key::status_text), str(gd::format(state, key::s_s_11, {str(verb), str(format_amount(state, gd::int_field(state, cost, key::gold, 0)))})));
		state.set(slot, str(key::status_detail), str(key::ready_for_today_s_construction_order));
		return;
	}
	if (gd::bool_field(state, row, key::market_coverable, false)) {
		state.set(slot, str(key::status), str(key::trade));
		state.set(slot, str(key::status_text), str(key::trade_covers_it));
		state.set(slot, str(key::status_detail), str(gd::stringify(state, gd::field_or(state, row, key::market_summary, str(key::trade_can_cover_the_missing_resources)))));
		return;
	}
	state.set(slot, str(key::status), str(key::short_));
	if (state.dict_size(shortfall) == 1) {
		const ArrayRef shortfall_keys = gd::keys(state, shortfall);
		const Atom resource_id = gd::stringify(state, state.at(shortfall_keys, 0));
		const int64_t amount = gd::to_int(state, gd::index(state, shortfall, str(resource_id)));
		state.set(slot, str(key::status_text), str(gd::format(state, key::short_s_s, {str(format_amount(state, amount)), str(resource_name(state, resource_id))})));
	} else {
		std::vector<Atom> names;
		for (const Atom resource_id : kResourceOrder) {
			if (state.has(shortfall, str(resource_id))) {
				names.push_back(resource_name(state, resource_id));
			}
		}
		const Atom status_text = !names.empty() ? state.intern(state.text(key::short__2) + state.text(join_atoms(state, key::comma_space, names))) : key::resources_missing;
		state.set(slot, str(key::status_text), str(status_text));
	}
	state.set(slot, str(key::status_detail), str(gd::stringify(state, gd::field_or(state, row, key::disabled_reason, str(key::current_stores_cannot_fund_this_building)))));
}

ArrayRef _missing_requirement_names(State &state, DictRef building, DictRef context) {
	const ArrayRef names = state.new_array();
	const ArrayRef ids = state.new_array();
	const Atom upgrade_from = ai::string_or_empty(state, building, key::upgrade_from);
	if (upgrade_from != key::empty) {
		state.append(ids, str(upgrade_from));
	}
	for (const Value &requirement_value : gd::field_items(state, building, str(key::requires_))) {
		const Atom requirement = gd::stringify(state, requirement_value);
		if (requirement != key::empty && requirement != ai::string_or_empty(state, building, key::id) && !gd::array_has(state, ids, str(requirement))) {
			state.append(ids, str(requirement));
		}
	}
	for (const Value &requirement : gd::items(state, array_value(ids))) {
		if (!town_development_rules::satisfies(state, gd::as_array(gd::index(state, context, str(key::active))), gd::to_string(requirement))) {
			const DictRef required = building_row(state, requirement);
			state.append(names, str(gd::stringify(state, gd::field_or(state, required, key::name, requirement))));
		}
	}
	const int64_t required_tier = gd::int_field(state, building, key::requires_dwelling_tier, 0);
	if (required_tier > 0 && !town_development_rules::has_dwelling_tier(state, gd::as_dict(gd::index(state, context, str(key::town))), required_tier)) {
		state.append(names, str(gd::format(state, key::tier_s_dwelling, {str(roman(state, required_tier))})));
	}
	return names;
}

DictRef _shortfall(State &state, DictRef cost, DictRef resources) {
	const DictRef shortfall = state.new_dict();
	const ArrayRef cost_keys = gd::keys(state, cost);
	for (const Value &resource_id : gd::items(state, array_value(cost_keys))) {
		const int64_t need = gd::to_int(state, gd::index(state, cost, resource_id));
		const int64_t have = gd::to_int(state, state.get(resources, resource_id, int_value(0)));
		if (need > have) {
			state.set(shortfall, str(gd::stringify(state, resource_id)), int_value(gd::sub(need, have)));
		}
	}
	return shortfall;
}

Atom _first_sentence(State &state, Atom text) {
	const std::string &value = state.text(text);
	const size_t index = value.find(state.text(key::period_space_text));
	if (index != std::string::npos && index > 0) {
		return state.intern(value.substr(0, index + 1));
	}
	return text;
}

} // namespace town_construction_board

} // namespace aurelion::rules::port
