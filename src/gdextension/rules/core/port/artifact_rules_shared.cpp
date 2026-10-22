// ArtifactRules ports shared by the computer players' day (Phase 4) and the ends of
// a battle (Phase 5): the artifacts a hero claims and equips, the live source
// rewards it draws, and the messages and summaries of its claims.

#include "aurelion_rules/port/artifact_rules.hpp"

#include <algorithm>
#include <initializer_list>
#include <iterator>
#include <string>
#include <unordered_set>
#include <vector>

namespace aurelion::rules::port::artifact_rules {

namespace {

using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
namespace key = state::key;

// ARTIFACT_SLOTS, EQUIPMENT_SLOTS and DAILY_INCOME_RESOURCE_IDS.
constexpr Atom kArtifactSlots[] = {key::boots, key::banner, key::armor, key::trinket};
constexpr Atom kEquipmentSlots[] = {key::boots, key::banner, key::armor, key::trinket, key::trinket_2};
constexpr Atom kDailyIncomeResourceIds[] = {
	key::gold,
	key::wood,
	key::ore,
	key::aetherglass,
	key::embergrain,
	key::peatwax,
	key::verdant_grafts,
	key::brass_scrip,
	key::memory_salt,
};

bool is_artifact_slot(Atom slot) {
	return std::find(std::begin(kArtifactSlots), std::end(kArtifactSlots), slot) != std::end(kArtifactSlots);
}

// String(d.get(field, fallback)).
Atom string_of_field(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// d.get(field, {}) and d.get(field, []): a new container when the key is missing.
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

// x.get(...) of an untyped value: only a Dictionary has get().
DictRef get_target(const Value &target) {
	if (!gd::is_dict(target)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' in base '") + gd::type_name(target) + "'.");
	}
	return target.ref;
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

// s.split(delimiter) with allow_empty: the pieces between the delimiters.
std::vector<std::string> split_text(const std::string &text, const std::string &delimiter) {
	std::vector<std::string> pieces;
	if (text.empty()) {
		pieces.emplace_back();
		return pieces;
	}
	size_t from = 0;
	while (true) {
		const size_t found = text.find(delimiter, from);
		if (found == std::string::npos) {
			pieces.push_back(text.substr(from));
			break;
		}
		pieces.push_back(text.substr(from, found - from));
		from = found + delimiter.size();
	}
	return pieces;
}

// s.unicode_at(i) for each i in range(s.length()): the code points of the UTF-8.
std::vector<uint32_t> code_points(const std::string &text) {
	std::vector<uint32_t> points;
	size_t index = 0;
	while (index < text.size()) {
		const unsigned char lead = static_cast<unsigned char>(text[index]);
		uint32_t point = lead;
		size_t length = 1;
		if (lead >= 0xf0) {
			point = lead & 0x07u;
			length = 4;
		} else if (lead >= 0xe0) {
			point = lead & 0x0fu;
			length = 3;
		} else if (lead >= 0xc0) {
			point = lead & 0x1fu;
			length = 2;
		}
		for (size_t next = 1; next < length && index + next < text.size(); ++next) {
			point = (point << 6) | (static_cast<unsigned char>(text[index + next]) & 0x3fu);
		}
		points.push_back(point);
		index += length;
	}
	return points;
}

DictRef location_result(State &state, Atom location, Atom slot) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::location), str(location));
	state.set(result, str(key::slot), str(slot));
	return result;
}

// {"ok": false, "reason": "placement_holds_no_artifact", "source_tag": ..., "source_key": ...}
DictRef no_artifact_result(State &state, Atom source_tag, Atom source_key) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::reason), str(key::placement_holds_no_artifact));
	state.set(result, str(key::source_tag), str(source_tag));
	state.set(result, str(key::source_key), str(source_key));
	return result;
}

DictRef not_opted_in_result(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::reason), str(key::source_not_opted_in));
	return result;
}

// {"ok": false, "reason": reason, "table_id": table_id}
DictRef refused_result(State &state, Atom reason, Atom table_id) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::reason), str(reason));
	state.set(result, str(key::table_id), str(table_id));
	return result;
}

DictRef exhausted_result(State &state, Atom table_id, Atom source_tag, Atom source_key) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::reason), str(key::source_table_exhausted));
	state.set(result, str(key::exhausted), bool_value(true));
	state.set(result, str(key::table_id), str(table_id));
	state.set(result, str(key::source_tag), str(source_tag));
	state.set(result, str(key::source_key), str(source_key));
	return result;
}

DictRef drawn_result(State &state, Atom artifact_id, int64_t candidate_count, Atom table_id, Atom source_tag, Atom source_key) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::artifact_id), str(artifact_id));
	state.set(result, str(key::candidate_count), int_value(candidate_count));
	state.set(result, str(key::table_id), str(table_id));
	state.set(result, str(key::source_tag), str(source_tag));
	state.set(result, str(key::source_key), str(source_key));
	return result;
}

// {"ok": false, "hero": hero, "message": message}
DictRef hero_refusal(State &state, DictRef hero, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::hero), dict_value(hero));
	state.set(result, str(key::message), str(message));
	return result;
}

DictRef claimed_result(State &state, const Value &hero, Atom message, bool auto_equipped, Atom artifact_id, Atom slot) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::hero), hero);
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::duplicate), bool_value(false));
	state.set(result, str(key::auto_equipped), bool_value(auto_equipped));
	state.set(result, str(key::artifact_id), str(artifact_id));
	state.set(result, str(key::slot), str(slot));
	state.set(result, str(key::effect_summary), str(artifact_effect_summary(state, artifact_id)));
	state.set(result, str(key::reward_role), str(artifact_reward_role(state, artifact_id)));
	return result;
}

// H3M_ARTIFACT_CLASS_RARITIES.get(artifact_class, []): a copy of the const's
// rarity groups, which _draw_from_rarities only reads.
ArrayRef class_rarity_tiers(State &state, Atom artifact_class) {
	const ArrayRef tiers = state.new_array();
	const auto group = [&state, tiers](std::initializer_list<Atom> rarities) {
		const ArrayRef rarity_group = state.new_array();
		for (const Atom rarity : rarities) {
			state.append(rarity_group, str(rarity));
		}
		state.append(tiers, array_value(rarity_group));
	};
	if (artifact_class == key::treasure) {
		group({key::common, key::uncommon});
	} else if (artifact_class == key::minor) {
		group({key::uncommon});
	} else if (artifact_class == key::major) {
		group({key::rare});
	} else if (artifact_class == key::relic) {
		group({key::epic});
		group({key::rare});
	}
	return tiers;
}

} // namespace

ArrayRef owned_artifact_ids(State &state, DictRef hero_state) {
	// normalize_hero_artifacts({}) is normalize_hero_artifacts(null).
	const DictRef artifacts = normalize_hero_artifacts(state, gd::field(state, hero_state, key::artifacts));
	const ArrayRef artifact_ids = state.new_array();
	const DictRef equipped = gd::as_dict(gd::index(state, artifacts, str(key::equipped)));
	for (const Atom slot : kEquipmentSlots) {
		const Atom equipped_id = string_of_field(state, equipped, slot, key::empty);
		if (equipped_id != key::empty && !gd::array_has(state, artifact_ids, str(equipped_id))) {
			state.append(artifact_ids, str(equipped_id));
		}
	}
	for (const Value &artifact_id_value : gd::items(state, gd::index(state, artifacts, str(key::inventory)))) {
		const Atom artifact_id = gd::stringify(state, artifact_id_value);
		if (artifact_id != key::empty && !gd::array_has(state, artifact_ids, str(artifact_id))) {
			state.append(artifact_ids, str(artifact_id));
		}
	}
	return artifact_ids;
}

DictRef locate_artifact(State &state, DictRef hero_state, Atom artifact_id) {
	const DictRef artifacts = normalize_hero_artifacts(state, gd::field(state, hero_state, key::artifacts));
	if (artifact_id == key::empty) {
		return location_result(state, key::missing, key::empty);
	}

	const DictRef equipped = gd::as_dict(gd::index(state, artifacts, str(key::equipped)));
	for (const Atom slot : kEquipmentSlots) {
		if (string_of_field(state, equipped, slot, key::empty) == artifact_id) {
			return location_result(state, key::equipped, slot);
		}
	}

	for (const Value &inventory_id_value : gd::items(state, gd::index(state, artifacts, str(key::inventory)))) {
		if (gd::stringify(state, inventory_id_value) == artifact_id) {
			return location_result(state, key::inventory, key::empty);
		}
	}

	return location_result(state, key::missing, key::empty);
}

DictRef select_live_source_reward(State &state, Atom source_tag, DictRef source_record, Atom source_key, Atom faction_id, ArrayRef excluded_artifact_ids) {
	// A generated placement draws its artifacts by HoMM3 class; this single draw
	// is the first of them.
	if (state.has(source_record, str(key::claim_artifact_classes))) {
		const Value classes = gd::field(state, source_record, key::claim_artifact_classes);
		if (!gd::is_array(classes) || state.array_size(classes.ref) == 0) {
			return no_artifact_result(state, source_tag, source_key);
		}
		return _select_class_source_reward(state, source_tag, gd::stringify(state, state.at(classes.ref, 0)), source_key, excluded_artifact_ids);
	}
	if (state.has(source_record, str(key::claim_artifact_rarity))) {
		return _select_rarity_source_reward(state, source_tag, string_of_field(state, source_record, key::claim_artifact_rarity, key::empty), source_key, excluded_artifact_ids);
	}
	const DictRef contract = _artifact_source_contract(state, source_record);
	// A missing runtime boundary is the {} fallback: opted out.
	Value runtime_boundary;
	const bool has_boundary = state.lookup(source_record, str(key::runtime_boundary), runtime_boundary);
	if (has_boundary && !gd::is_dict(runtime_boundary)) {
		return not_opted_in_result(state);
	}
	const Atom table_contract_key = source_tag == key::battle_salvage ? static_cast<Atom>(key::battle_salvage_reward_table_id) : static_cast<Atom>(key::artifact_reward_table_id);
	const Atom table_id = gd::strip_edges(state, string_of_field(state, contract, table_contract_key, key::empty));
	if (table_id == key::empty || !(has_boundary && gd::bool_field(state, runtime_boundary.ref, key::artifact_reward_execution, false))) {
		return not_opted_in_result(state);
	}

	const DictRef raw = gd::content_file(state, key::artifacts_path);
	Value tables;
	const bool has_tables = state.lookup(raw, str(key::source_reward_tables), tables);
	Value artifact_records;
	const bool has_records = state.lookup(raw, str(key::items), artifact_records);
	if ((has_tables && !gd::is_array(tables)) || (has_records && !gd::is_array(artifact_records))) {
		return refused_result(state, key::source_content_unavailable, table_id);
	}
	// A table that matches has an id, so it is never empty.
	DictRef table = 0;
	bool table_found = false;
	if (has_tables) {
		for (const Value &table_value : gd::items(state, tables)) {
			if (gd::is_dict(table_value) && string_of_field(state, table_value.ref, key::id, key::empty) == table_id) {
				table = table_value.ref;
				table_found = true;
				break;
			}
		}
	}
	if (!table_found || gd::is_empty(state, table) || string_of_field(state, table, key::source_tag, key::empty) != source_tag) {
		return refused_result(state, key::source_table_mismatch, table_id);
	}
	const DictRef policy = _artifact_source_runtime_policy(state, table);
	if (gd::bool_field(state, policy, key::metadata_only, true) || !gd::bool_field(state, policy, key::live_drop_execution, false)) {
		return refused_result(state, key::source_table_not_live, table_id);
	}
	const ArrayRef context_records = state.new_array();
	state.append(context_records, dict_value(source_record));
	if (state.array_size(_matching_artifact_source_contexts(state, table, context_records, false)) == 0) {
		return refused_result(state, key::source_context_ineligible, table_id);
	}
	const ArrayRef faction_constraints = _string_array(state, gd::field(state, table, key::faction_constraints));
	if (state.array_size(faction_constraints) != 0 && !gd::array_has(state, faction_constraints, str(faction_id))) {
		return refused_result(state, key::faction_ineligible, table_id);
	}

	std::unordered_set<Atom> known_artifact_ids;
	if (has_records) {
		for (const Value &artifact_value : gd::items(state, artifact_records)) {
			if (gd::is_dict(artifact_value)) {
				const Atom artifact_id = gd::strip_edges(state, string_of_field(state, artifact_value.ref, key::id, key::empty));
				if (artifact_id != key::empty) {
					known_artifact_ids.insert(artifact_id);
				}
			}
		}
	}
	std::unordered_set<Atom> excluded;
	for (const Value &artifact_id_value : gd::items(state, array_value(excluded_artifact_ids))) {
		excluded.insert(gd::stringify(state, artifact_id_value));
	}
	ArrayRef table_artifact_ids = _string_array(state, gd::field(state, table, key::artifact_ids));
	Value faction_artifact_ids;
	if (faction_id != key::empty && state.lookup(table, str(key::artifact_ids_by_faction), faction_artifact_ids) && gd::is_dict(faction_artifact_ids) && state.has(faction_artifact_ids.ref, str(faction_id))) {
		table_artifact_ids = _string_array(state, gd::field(state, faction_artifact_ids.ref, faction_id));
	}
	// _string_array holds Strings, so an atom is the dictionaries' key.
	const ArrayRef candidates = state.new_array();
	for (const Value &artifact_id : gd::items(state, array_value(table_artifact_ids))) {
		if (known_artifact_ids.count(artifact_id.ref) != 0 && excluded.count(artifact_id.ref) == 0) {
			state.append(candidates, artifact_id);
		}
	}
	const int64_t candidate_count = state.array_size(candidates);
	if (candidate_count == 0) {
		return exhausted_result(state, table_id, source_tag, source_key);
	}
	const int64_t index = _stable_source_reward_index(state, source_key, candidate_count);
	return drawn_result(state, gd::stringify(state, state.at(candidates, index)), candidate_count, table_id, source_tag, source_key);
}

DictRef _select_class_source_reward(State &state, Atom source_tag, Atom artifact_class, Atom source_key, ArrayRef excluded_artifact_ids) {
	const ArrayRef tiers = class_rarity_tiers(state, artifact_class);
	if (state.array_size(tiers) == 0) {
		return no_artifact_result(state, source_tag, source_key);
	}
	const DictRef selection = _draw_from_rarities(state, source_tag, tiers, gd::format(state, key::placement_class_s, {str(artifact_class)}), source_key, excluded_artifact_ids);
	state.set(selection, str(key::artifact_class), str(artifact_class));
	return selection;
}

DictRef _draw_from_rarities(State &state, Atom source_tag, ArrayRef tiers, Atom table_id, Atom source_key, ArrayRef excluded_artifact_ids) {
	std::unordered_set<Atom> excluded;
	for (const Value &artifact_id_value : gd::items(state, array_value(excluded_artifact_ids))) {
		excluded.insert(gd::stringify(state, artifact_id_value));
	}
	// var items: Array = ...get("items", []): a missing key holds no artifact.
	Value items;
	const bool has_items = state.lookup(gd::content_file(state, key::artifacts_path), str(key::items), items);
	if (has_items) {
		(void)gd::as_array(items);
	}
	for (const Value &rarities : gd::items(state, array_value(tiers))) {
		const ArrayRef candidates = state.new_array();
		if (has_items) {
			for (const Value &artifact_value : gd::items(state, items)) {
				if (!gd::is_dict(artifact_value) || !gd::in(state, str(string_of_field(state, artifact_value.ref, key::rarity, key::empty)), rarities)) {
					continue;
				}
				const Atom artifact_id = gd::strip_edges(state, string_of_field(state, artifact_value.ref, key::id, key::empty));
				if (artifact_id != key::empty && excluded.count(artifact_id) == 0) {
					state.append(candidates, str(artifact_id));
				}
			}
		}
		const int64_t candidate_count = state.array_size(candidates);
		if (candidate_count == 0) {
			continue;
		}
		// candidates.sort() of Strings: by code point, which is UTF-8 byte order.
		gd::sort_custom(state, candidates, [&state](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
		const int64_t index = _stable_source_reward_index(state, source_key, candidate_count);
		return drawn_result(state, gd::stringify(state, state.at(candidates, index)), candidate_count, table_id, source_tag, source_key);
	}
	return exhausted_result(state, table_id, source_tag, source_key);
}

DictRef _artifact_source_contract(State &state, DictRef source_record) {
	Value contract;
	if (state.lookup(source_record, str(key::artifact_reward_contract), contract) && gd::is_dict(contract) && !gd::is_empty(state, contract.ref)) {
		return contract.ref;
	}
	if (state.lookup(source_record, str(key::guarded_reward_contract), contract) && gd::is_dict(contract)) {
		return contract.ref;
	}
	return state.new_dict();
}

DictRef claim_artifact(State &state, DictRef hero_state, Atom artifact_id, Atom source_verb, bool auto_equip) {
	const DictRef hero = ensure_hero_artifacts(state, gd::deep_duplicate_dict(state, hero_state));
	const DictRef artifact = gd::content_row(state, ContentTable::Artifact, artifact_id);
	if (gd::is_empty(state, artifact)) {
		return hero_refusal(state, hero, key::unknown_artifact);
	}

	const DictRef location = locate_artifact(state, hero, artifact_id);
	if (string_of_field(state, location, key::location, key::missing) != key::missing) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(true));
		state.set(result, str(key::hero), dict_value(hero));
		state.set(result, str(key::message), str(_already_owned_message(state, artifact_id, location, source_verb)));
		state.set(result, str(key::duplicate), bool_value(true));
		state.set(result, str(key::auto_equipped), bool_value(false));
		return result;
	}

	const DictRef artifacts = get_target(get_or_new_dict(state, hero, key::artifacts));
	const ArrayRef inventory = gd::as_array(get_or_new_array(state, artifacts, key::inventory));
	state.append(inventory, str(artifact_id));
	state.set(artifacts, str(key::inventory), array_value(inventory));
	state.set(hero, str(key::artifacts), dict_value(normalize_hero_artifacts(state, dict_value(artifacts))));

	Atom message = gd::format(state, key::s_s_2, {str(source_verb), str(artifact_name(state, artifact_id))});
	const DictRef hero_artifacts = get_target(get_or_new_dict(state, hero, key::artifacts));
	Atom slot = _first_empty_compatible_slot(state, get_or_new_dict(state, hero_artifacts, key::equipped), artifact_id);
	if (auto_equip && slot != key::empty) {
		const DictRef equip_result = equip_artifact(state, hero, artifact_id);
		const Value equipped_hero = state.get(equip_result, str(key::hero), dict_value(hero));
		slot = gd::stringify(state, state.get(equip_result, str(key::slot), str(slot)));
		const Atom suffix_fallback = state.intern(state.text(artifact_name(state, artifact_id)) + state.text(key::period));
		const Atom suffix = gd::stringify(state, state.get(equip_result, str(key::suffix_message), str(suffix_fallback)));
		message = gd::format(state, key::s_s, {str(source_verb), str(suffix)});
		return claimed_result(state, equipped_hero, message, true, artifact_id, slot);
	}

	message = gd::format(state, key::s_s_s_3, {str(source_verb), str(artifact_name(state, artifact_id)), str(_artifact_collection_note(state, hero, artifact_id))});
	return claimed_result(state, dict_value(hero), message, false, artifact_id, slot);
}

DictRef equip_artifact(State &state, DictRef hero_state, Atom artifact_id) {
	const DictRef hero = ensure_hero_artifacts(state, gd::deep_duplicate_dict(state, hero_state));
	const DictRef artifact = gd::content_row(state, ContentTable::Artifact, artifact_id);
	if (gd::is_empty(state, artifact)) {
		return hero_refusal(state, hero, key::that_artifact_is_not_known);
	}

	const Atom artifact_slot_type = artifact_slot(state, artifact_id);
	if (artifact_slot_type == key::empty || !is_artifact_slot(artifact_slot_type)) {
		return hero_refusal(state, hero, key::that_artifact_cannot_be_equipped);
	}

	const DictRef location = locate_artifact(state, hero, artifact_id);
	if (string_of_field(state, location, key::location, key::missing) == key::equipped) {
		const Atom name = artifact_name(state, artifact_id);
		const Atom slot_label = _equipment_slot_label(state, string_of_field(state, location, key::slot, artifact_slot_type));
		return hero_refusal(state, hero, gd::format(state, key::s_is_already_equipped_in_the, {str(name), str(slot_label)}));
	}
	if (string_of_field(state, location, key::location, key::missing) != key::inventory) {
		return hero_refusal(state, hero, key::that_artifact_is_not_in_the);
	}

	const DictRef artifacts = get_target(get_or_new_dict(state, hero, key::artifacts));
	const Value equipped = get_or_new_dict(state, artifacts, key::equipped);
	const Value inventory = get_or_new_array(state, artifacts, key::inventory);
	_remove_artifact_from_inventory(state, gd::as_array(inventory), artifact_id);
	Atom slot = _first_empty_compatible_slot(state, equipped, artifact_id);
	if (slot == key::empty) {
		slot = gd::to_string(state.at(_compatible_equipment_slots(state, artifact_slot_type), 0));
	}

	const DictRef equipped_dict = get_target(equipped);
	const Atom swapped_out_id = string_of_field(state, equipped_dict, slot, key::empty);
	if (swapped_out_id != key::empty) {
		state.set(equipped_dict, str(slot), str(key::empty));
		_append_inventory_artifact(state, swapped_out_id, equipped_dict, gd::as_array(inventory));
	}

	state.set(equipped_dict, str(slot), str(artifact_id));
	state.set(artifacts, str(key::equipped), equipped);
	state.set(artifacts, str(key::inventory), inventory);
	state.set(hero, str(key::artifacts), dict_value(normalize_hero_artifacts(state, dict_value(artifacts))));

	Atom suffix_message = gd::format(state, key::s_s_3, {str(artifact_name(state, artifact_id)), str(_artifact_equipped_note(state, artifact_id, slot))});
	Atom message = gd::format(state, key::equipped_s_from_pack_into_s, {
		str(artifact_name(state, artifact_id)),
		str(_equipment_slot_label(state, slot)),
		str(_artifact_effect_line(state, artifact_id)),
	});
	if (swapped_out_id != key::empty) {
		message = gd::format(state, key::swapped_s_into_s_and_stowed, {
			str(artifact_name(state, artifact_id)),
			str(_equipment_slot_label(state, slot)),
			str(artifact_name(state, swapped_out_id)),
		});
		const Atom comparison = gd::format(state, key::new_s_was_s, {
			str(artifact_effect_summary(state, artifact_id)),
			str(artifact_effect_summary(state, swapped_out_id)),
		});
		message = state.intern(state.text(message) + state.text(comparison));
		suffix_message = gd::format(state, key::s_swapped_into_s_stowed_s, {
			str(artifact_name(state, artifact_id)),
			str(_equipment_slot_label(state, slot)),
			str(artifact_name(state, swapped_out_id)),
			str(artifact_effect_summary(state, artifact_id)),
			str(artifact_effect_summary(state, swapped_out_id)),
		});
	}

	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::hero), dict_value(hero));
	state.set(result, str(key::slot), str(slot));
	state.set(result, str(key::swapped_out_artifact_id), str(swapped_out_id));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::suffix_message), str(suffix_message));
	return result;
}

Atom artifact_name(State &state, Atom artifact_id) {
	if (artifact_id == key::empty) {
		return key::Artifact;
	}
	const DictRef artifact = gd::content_row(state, ContentTable::Artifact, artifact_id);
	return string_of_field(state, artifact, key::name, artifact_id);
}

Atom artifact_slot_label(State &state, Atom artifact_id) {
	const Atom slot = artifact_slot(state, artifact_id);
	return slot != key::empty ? gd::capitalize(state, slot) : static_cast<Atom>(key::Carry);
}

Atom artifact_effect_summary(State &state, Atom artifact_id) {
	return _artifact_effect_summary(state, gd::content_row(state, ContentTable::Artifact, artifact_id));
}

Atom artifact_reward_role(State &state, Atom artifact_id) {
	const DictRef artifact = gd::content_row(state, ContentTable::Artifact, artifact_id);
	if (gd::is_empty(state, artifact)) {
		return key::equipment_reward;
	}
	const DictRef bonuses = get_target(get_or_new_dict(state, artifact, key::bonuses));
	// A missing daily income is the {} fallback, which holds no amount.
	Value income;
	if (state.lookup(bonuses, str(key::daily_income), income) && gd::is_dict(income)) {
		for (const Value &resource : gd::items(state, income)) {
			if (gd::to_int(state, gd::index(state, income.ref, resource)) > 0) {
				return key::economy_reward;
			}
		}
	}
	const int64_t movement = gd::int_field(state, bonuses, key::overworld_movement, 0);
	const int64_t scouting = gd::int_field(state, bonuses, key::scouting_radius, 0);
	if (movement > 0 && scouting > 0) {
		return key::exploration_reward;
	}
	if (movement > 0) {
		return key::movement_reward;
	}
	if (scouting > 0) {
		return key::scouting_reward;
	}
	if (gd::int_field(state, bonuses, key::battle_defense, 0) > 0 && gd::int_field(state, bonuses, key::battle_attack, 0) <= 0) {
		return key::defense_reward;
	}
	if (gd::int_field(state, bonuses, key::battle_attack, 0) > 0 || gd::int_field(state, bonuses, key::battle_initiative, 0) > 0) {
		return key::command_reward;
	}
	return key::equipment_reward;
}

Atom _artifact_effect_line(State &state, Atom artifact_id) {
	const Atom role = artifact_reward_role(state, artifact_id);
	const Atom effect = artifact_effect_summary(state, artifact_id);
	return gd::format(state, key::s_s_4, {str(role), str(effect)});
}

Atom _artifact_equipped_note(State &state, Atom artifact_id, Atom slot) {
	const Atom slot_label = _equipment_slot_label(state, slot);
	const Atom effect_line = _artifact_effect_line(state, artifact_id);
	return gd::format(state, key::equipped_in_s_slot_s, {str(slot_label), str(effect_line)});
}

Atom _artifact_collection_note(State &state, DictRef hero_state, Atom artifact_id) {
	(void)hero_state;
	const Atom slot_label = artifact_slot_label(state, artifact_id);
	const Atom role = artifact_reward_role(state, artifact_id);
	const Atom effect = artifact_effect_summary(state, artifact_id);
	return gd::format(state, key::s_s_s_5, {str(slot_label), str(role), str(effect)});
}

Atom _first_empty_compatible_slot(State &state, const Value &equipped, Atom artifact_id) {
	if (!gd::is_dict(equipped)) {
		return key::empty;
	}
	return _first_empty_slot_from_candidates(state, equipped.ref, _compatible_equipment_slots(state, artifact_slot(state, artifact_id)));
}

Atom _equipment_slot_label(State &state, Atom slot) {
	if (slot == key::trinket_2) {
		return key::trinket_ii;
	}
	return gd::capitalize(state, slot);
}

bool _remove_artifact_from_inventory(State &state, ArrayRef inventory, Atom artifact_id) {
	const int64_t size = state.array_size(inventory);
	for (int64_t index = 0; index < size; ++index) {
		if (gd::stringify(state, state.at(inventory, index)) == artifact_id) {
			gd::remove_at(state, inventory, index);
			return true;
		}
	}
	return false;
}

Atom _already_owned_message(State &state, Atom artifact_id, DictRef location, Atom source_verb) {
	const Atom location_name = string_of_field(state, location, key::location, key::missing);
	if (location_name == key::equipped) {
		const Atom name = artifact_name(state, artifact_id);
		const Atom slot_label = _equipment_slot_label(state, string_of_field(state, location, key::slot, key::equipment));
		return gd::format(state, key::s_s_but_it_is_already, {str(source_verb), str(name), str(slot_label)});
	}
	if (location_name == key::inventory) {
		return gd::format(state, key::s_s_but_it_is_already_2, {str(source_verb), str(artifact_name(state, artifact_id))});
	}
	return gd::format(state, key::s_s_2, {str(source_verb), str(artifact_name(state, artifact_id))});
}

Atom _artifact_effect_summary(State &state, DictRef artifact) {
	if (gd::is_empty(state, artifact)) {
		return key::no_bonuses;
	}
	const DictRef bonuses = get_target(get_or_new_dict(state, artifact, key::bonuses));
	const ArrayRef parts = state.new_array();
	const struct {
		Atom bonus;
		Atom pattern;
	} int_parts[] = {
		{key::overworld_movement, key::d_move},
		{key::scouting_radius, key::d_scout},
		{key::battle_attack, key::d_attack},
		{key::battle_defense, key::d_defense},
		{key::battle_initiative, key::d_initiative},
		{key::battle_spell_resistance_pct, key::d_spell_resist},
		{key::battle_control_resistance_pct, key::d_control_resist},
	};
	for (const auto &part : int_parts) {
		const int64_t amount = gd::int_field(state, bonuses, part.bonus, 0);
		if (amount > 0) {
			state.append(parts, str(gd::format(state, part.pattern, {int_value(amount)})));
		}
	}
	Value school_resistance;
	if (state.lookup(bonuses, str(key::battle_school_resistance_pct), school_resistance) && gd::is_dict(school_resistance)) {
		for (const Value &school_id : gd::items(state, school_resistance)) {
			const int64_t amount = gd::to_int(state, gd::index(state, school_resistance.ref, school_id));
			if (amount > 0) {
				const Atom school = gd::capitalize(state, gd::stringify(state, school_id));
				state.append(parts, str(gd::format(state, key::d_s_resist, {int_value(amount), str(school)})));
			}
		}
	}

	const ArrayRef income_parts = state.new_array();
	Value income;
	if (state.lookup(bonuses, str(key::daily_income), income) && gd::is_dict(income)) {
		for (const Atom resource : kDailyIncomeResourceIds) {
			const int64_t amount = gd::int_field(state, income.ref, resource, 0);
			if (amount > 0) {
				state.append(income_parts, str(gd::format(state, key::d_s_day, {int_value(amount), str(_resource_display_name(state, resource))})));
			}
		}
	}
	if (state.array_size(income_parts) != 0) {
		state.append(parts, str(join_array(state, key::comma_space, income_parts)));
	}
	const ArrayRef records = _artifact_spell_modifier_records(state, artifact, string_of_field(state, artifact, key::id, key::empty));
	const ArrayRef spell_parts = _artifact_spell_modifier_parts(state, array_value(records));
	if (state.array_size(spell_parts) != 0) {
		state.append(parts, str(join_array(state, key::comma_space, spell_parts)));
	}

	return state.array_size(parts) != 0 ? join_array(state, key::comma_space, parts) : static_cast<Atom>(key::no_bonuses);
}

Atom _resource_display_name(State &state, Atom resource_id) {
	if (resource_id == key::gold || resource_id == key::wood || resource_id == key::ore) {
		return resource_id;
	}
	return gd::capitalize(state, gd::replace(state, resource_id, key::_, key::space));
}

ArrayRef _artifact_spell_modifier_parts(State &state, const Value &value) {
	const ArrayRef parts = state.new_array();
	if (!gd::is_array(value)) {
		return parts;
	}
	for (const Value &modifier_value : gd::items(state, value)) {
		if (!gd::is_dict(modifier_value)) {
			continue;
		}
		const DictRef modifier = modifier_value.ref;
		const Atom school = _title_label(state, string_of_field(state, modifier, key::school_id, key::spell));
		const Atom context = gd::replace(state, string_of_field(state, modifier, key::context, key::spell), key::_, key::space);
		const ArrayRef modifier_parts = state.new_array();
		const int64_t mana_delta = gd::int_field(state, modifier, key::mana_cost_delta, 0);
		const int64_t effect_delta = gd::int_field(state, modifier, key::effect_amount_delta, 0);
		if (mana_delta != 0) {
			state.append(modifier_parts, str(gd::format(state, key::s_mana, {str(_signed_amount_label(state, mana_delta))})));
		}
		if (effect_delta != 0) {
			state.append(modifier_parts, str(gd::format(state, key::s_effect, {str(_signed_amount_label(state, effect_delta))})));
		}
		if (state.array_size(modifier_parts) == 0) {
			continue;
		}
		state.append(parts, str(gd::format(state, key::s_s_s_4, {str(school), str(context), str(join_array(state, key::comma_space, modifier_parts))})));
	}
	return parts;
}

int64_t _stable_source_reward_index(State &state, Atom source_key, int64_t candidate_count) {
	if (candidate_count <= 1) {
		return 0;
	}
	int64_t value = 0;
	for (const uint32_t point : code_points(state.text(source_key))) {
		value = (value * 131 + static_cast<int64_t>(point)) % 2147483647;
	}
	return value % candidate_count;
}

DictRef _artifact_source_runtime_policy(State &state, DictRef table) {
	Value policy;
	const bool has_policy = state.lookup(table, str(key::runtime_policy), policy);
	const DictRef result = state.new_dict();
	if (has_policy && !gd::is_dict(policy)) {
		state.set(result, str(key::metadata_only), bool_value(false));
		state.set(result, str(key::live_drop_execution), bool_value(true));
		state.set(result, str(key::save_version_bump), bool_value(true));
		state.set(result, str(key::equipment_runtime_effects), bool_value(true));
		state.set(result, str(key::ai_valuation_behavior), bool_value(true));
		state.set(result, str(key::rare_resource_activation), bool_value(true));
		return result;
	}
	// A missing policy is the {} fallback: every flag at its default.
	const auto flag = [&](Atom field, bool fallback) {
		return has_policy ? gd::bool_field(state, policy.ref, field, fallback) : fallback;
	};
	state.set(result, str(key::metadata_only), bool_value(flag(key::metadata_only, false)));
	state.set(result, str(key::live_drop_execution), bool_value(flag(key::live_drop_execution, true)));
	state.set(result, str(key::save_version_bump), bool_value(flag(key::save_version_bump, true)));
	state.set(result, str(key::equipment_runtime_effects), bool_value(flag(key::equipment_runtime_effects, true)));
	state.set(result, str(key::ai_valuation_behavior), bool_value(flag(key::ai_valuation_behavior, true)));
	state.set(result, str(key::rare_resource_activation), bool_value(flag(key::rare_resource_activation, true)));
	return result;
}

ArrayRef _matching_artifact_source_contexts(State &state, DictRef table, ArrayRef records, bool map_object_context) {
	const ArrayRef matches = state.new_array();
	const Atom family_key = map_object_context ? static_cast<Atom>(key::eligible_object_families) : static_cast<Atom>(key::eligible_site_families);
	const ArrayRef eligible_families = _string_array(state, gd::field(state, table, family_key));
	const ArrayRef required_tags = map_object_context ? _string_array(state, gd::field(state, table, key::required_object_tags)) : state.new_array();
	const ArrayRef required_categories = _string_array(state, gd::field(state, table, key::required_reward_categories));
	const ArrayRef guard_tiers = _string_array(state, gd::field(state, table, key::guard_tiers));
	for (const Value &record_value : gd::items(state, array_value(records))) {
		if (!gd::is_dict(record_value)) {
			continue;
		}
		const DictRef record = record_value.ref;
		if (state.array_size(eligible_families) != 0 && !gd::array_has(state, eligible_families, str(gd::strip_edges(state, string_of_field(state, record, key::family, key::empty))))) {
			continue;
		}
		if (!_source_record_has_required_tags(state, record, required_tags)) {
			continue;
		}
		if (!_source_record_has_required_categories(state, record, required_categories)) {
			continue;
		}
		const Atom guard_tier = _source_record_guard_tier(state, record);
		if (state.array_size(guard_tiers) != 0 && !gd::array_has(state, guard_tiers, str(guard_tier))) {
			continue;
		}
		state.append(matches, str(string_of_field(state, record, key::id, key::empty)));
	}
	return matches;
}

bool _source_record_has_required_tags(State &state, DictRef record, ArrayRef required_tags) {
	if (state.array_size(required_tags) == 0) {
		return true;
	}
	const ArrayRef tags = state.new_array();
	for (const Atom field : {key::family, key::primary_class, key::batch006_role, key::batch007_role}) {
		const Atom value = gd::strip_edges(state, string_of_field(state, record, field, key::empty));
		if (value != key::empty && !gd::array_has(state, tags, str(value))) {
			state.append(tags, str(value));
		}
	}
	for (const Atom field : {key::secondary_tags, key::map_roles}) {
		const ArrayRef field_tags = _string_array(state, gd::field(state, record, field));
		for (const Value &tag : gd::items(state, array_value(field_tags))) {
			if (!gd::array_has(state, tags, tag)) {
				state.append(tags, tag);
			}
		}
	}
	// A missing editor placement is the {} fallback, which has no role.
	Value editor;
	if (state.lookup(record, str(key::editor_placement), editor) && gd::is_dict(editor)) {
		const Atom placement_role = gd::strip_edges(state, string_of_field(state, editor.ref, key::placement_role, key::empty));
		if (placement_role != key::empty && !gd::array_has(state, tags, str(placement_role))) {
			state.append(tags, str(placement_role));
		}
	}
	for (const Value &required_tag : gd::items(state, array_value(required_tags))) {
		if (!gd::array_has(state, tags, required_tag)) {
			return false;
		}
	}
	return true;
}

bool _source_record_has_required_categories(State &state, DictRef record, ArrayRef required_categories) {
	if (state.array_size(required_categories) == 0) {
		return true;
	}
	const ArrayRef categories = _source_record_reward_categories(state, record);
	for (const Value &required_category : gd::items(state, array_value(required_categories))) {
		if (!gd::array_has(state, categories, required_category)) {
			return false;
		}
	}
	return true;
}

ArrayRef _source_record_reward_categories(State &state, DictRef record) {
	const ArrayRef categories = state.new_array();
	for (const Atom container_key : {key::artifact_reward_contract, key::guarded_reward_contract, key::reward_preview}) {
		// A missing container is the {} fallback, which has no categories.
		Value container;
		if (!state.lookup(record, str(container_key), container) || !gd::is_dict(container)) {
			continue;
		}
		const ArrayRef container_categories = _string_array(state, gd::field(state, container.ref, key::reward_categories));
		for (const Value &category : gd::items(state, array_value(container_categories))) {
			if (!gd::array_has(state, categories, category)) {
				state.append(categories, category);
			}
		}
	}
	if (state.has(record, str(key::claim_recruits)) || state.has(record, str(key::weekly_recruits)) || state.has(record, str(key::neutral_roster)) || state.has(record, str(key::dwelling_contract))) {
		if (!gd::array_has(state, categories, str(key::recruit))) {
			state.append(categories, str(key::recruit));
		}
	}
	if (state.has(record, str(key::response_profile)) || string_of_field(state, record, key::family, key::empty) == key::repeatable_service || string_of_field(state, record, key::family, key::empty) == key::faction_landmark) {
		if (!gd::array_has(state, categories, str(key::town_support))) {
			state.append(categories, str(key::town_support));
		}
	}
	return categories;
}

Atom _source_record_guard_tier(State &state, DictRef record) {
	for (const Atom container_key : {key::guard_expectation, key::guard_profile}) {
		// A missing container is the {} fallback, whose tier is "".
		Value container;
		if (state.lookup(record, str(container_key), container) && gd::is_dict(container)) {
			const Value risk_tier = state.get(container.ref, str(key::risk_tier), str(key::empty));
			const Atom tier = gd::strip_edges(state, gd::stringify(state, state.get(container.ref, str(key::tier), risk_tier)));
			if (tier != key::empty) {
				return tier;
			}
		}
	}
	const DictRef contract = _artifact_source_contract(state, record);
	const Atom reward_tier = gd::strip_edges(state, string_of_field(state, contract, key::reward_tier, key::empty));
	if (reward_tier != key::empty) {
		return reward_tier;
	}
	return key::unguarded;
}

Atom _signed_amount_label(State &state, int64_t amount) {
	if (amount > 0) {
		return gd::format(state, key::plus_d_text, {int_value(amount)});
	}
	return gd::format(state, key::d_text, {int_value(amount)});
}

Atom _title_label(State &state, Atom value) {
	const std::string text = state.text(gd::replace(state, value, key::dash, key::_));
	std::vector<Atom> words;
	for (const std::string &part : split_text(text, state.text(key::_))) {
		const Atom word = gd::strip_edges(state, state.intern(part));
		if (word == key::empty) {
			continue;
		}
		words.push_back(gd::capitalize(state, word));
	}
	if (words.empty()) {
		return value;
	}
	std::string joined;
	for (size_t index = 0; index < words.size(); ++index) {
		if (index > 0) {
			joined += state.text(key::space);
		}
		joined += state.text(words[index]);
	}
	return state.intern(joined);
}

} // namespace aurelion::rules::port::artifact_rules
