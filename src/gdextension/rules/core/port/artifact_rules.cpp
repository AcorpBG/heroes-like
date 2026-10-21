// Layer 2: a hero's artifacts, normalized, and the bonuses they and their sets give.

#include "aurelion_rules/port/artifact_rules.hpp"

#include "aurelion_rules/compat/godot_string.hpp"

#include <algorithm>
#include <string>

namespace aurelion::rules::port::artifact_rules {

namespace {

using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
namespace key = state::key;

// ARTIFACT_SLOTS and EQUIPMENT_SLOTS.
constexpr Atom kArtifactSlots[] = {key::boots, key::banner, key::armor, key::trinket};
constexpr Atom kEquipmentSlots[] = {key::boots, key::banner, key::armor, key::trinket, key::trinket_2};

// The int bonuses _apply_bonus_payload adds.
constexpr Atom kIntBonusKeys[] = {
	key::overworld_movement,
	key::scouting_radius,
	key::battle_attack,
	key::battle_defense,
	key::battle_initiative,
	key::battle_spell_resistance_pct,
	key::battle_control_resistance_pct,
};

// _blank_bonus_totals' daily income.
constexpr Atom kBlankIncomeKeys[] = {
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

// _merge_resources' base resources.
constexpr Atom kBaseResourceKeys[] = {key::gold, key::wood, key::ore};

// The resistance cap of _merge_school_resistance.
constexpr int64_t kMaxSchoolResistancePct = 75;

// String(d.get(key, fallback)).
Atom string_of_field(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// d.get(key, {}): a new Dictionary when the key is missing.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// x.get(key, fallback) on an untyped value: only a Dictionary has a two-argument get.
DictRef two_argument_get_target(const Value &target) {
	if (!gd::is_dict(target)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' with two arguments in base '") + gd::type_name(target) + "'.");
	}
	return target.ref;
}

int64_t clamp_resistance(int64_t amount) {
	return std::clamp<int64_t>(amount, 0, kMaxSchoolResistancePct);
}

} // namespace

DictRef aggregate_bonuses(State &state, DictRef hero_state) {
	hero_state = ensure_hero_artifacts(state, hero_state);
	const DictRef totals = _blank_bonus_totals(state);

	// hero_state.get("artifacts", {}).get("equipped", {}): the Dictionaries
	// ensure_hero_artifacts just stored.
	const DictRef artifacts = two_argument_get_target(get_or_new_dict(state, hero_state, key::artifacts));
	const Value equipped = get_or_new_dict(state, artifacts, key::equipped);
	const DictRef equipped_dict = two_argument_get_target(equipped);
	for (const Atom slot : kEquipmentSlots) {
		const Atom artifact_id = string_of_field(state, equipped_dict, slot, key::empty);
		if (artifact_id == key::empty) {
			continue;
		}
		const DictRef artifact = gd::content_row(state, ContentTable::Artifact, artifact_id);
		_apply_bonus_payload(state, totals, get_or_new_dict(state, artifact, key::bonuses), artifact, artifact_id);
	}

	// The artifacts were just normalized in place, and normalizing them again
	// gives the same slots.
	const ArrayRef active_sets = _set_states_for_equipped(state, equipped);
	for (const Value &set_state_value : gd::items(state, array_value(active_sets))) {
		if (!gd::is_dict(set_state_value)) {
			continue;
		}
		const DictRef set_state = set_state_value.ref;
		Value thresholds;
		if (!state.lookup(set_state, str(key::active_thresholds), thresholds)) {
			continue;
		}
		for (const Value &threshold_value : gd::items(state, thresholds)) {
			if (!gd::is_dict(threshold_value)) {
				continue;
			}
			const DictRef threshold = threshold_value.ref;
			const std::string threshold_id = state.text(string_of_field(state, set_state, key::set_id, key::set)) + ":" + compat::itos(gd::int_field(state, threshold, key::count, 0));
			const Value threshold_bonuses = get_or_new_dict(state, threshold, key::bonuses);
			const DictRef modifier_source = state.new_dict();
			state.set(modifier_source, str(key::bonuses), get_or_new_dict(state, threshold, key::bonuses));
			_apply_bonus_payload(state, totals, threshold_bonuses, modifier_source, state.intern(threshold_id));
		}
	}
	state.set(totals, str(key::active_sets), array_value(active_sets));

	return totals;
}

DictRef ensure_hero_artifacts(State &state, DictRef hero_state) {
	// normalize_hero_artifacts({}) is normalize_hero_artifacts(null).
	const DictRef artifacts = normalize_hero_artifacts(state, gd::field(state, hero_state, key::artifacts));
	state.set(hero_state, str(key::artifacts), dict_value(artifacts));
	return hero_state;
}

DictRef normalize_hero_artifacts(State &state, const Value &value) {
	const DictRef equipped = _blank_equipped_slots(state);
	const ArrayRef inventory = state.new_array();
	if (gd::is_dict(value)) {
		const Value raw_equipped = gd::field(state, value.ref, key::equipped);
		if (gd::is_dict(raw_equipped)) {
			for (const Atom slot : kEquipmentSlots) {
				_register_equipped_candidate(state, string_of_field(state, raw_equipped.ref, slot, key::empty), equipped, inventory, slot);
			}
		}

		const Value raw_inventory = gd::field(state, value.ref, key::inventory);
		if (gd::is_array(raw_inventory)) {
			for (const Value &artifact_id_value : gd::items(state, raw_inventory)) {
				_append_inventory_artifact(state, gd::stringify(state, artifact_id_value), equipped, inventory);
			}
		}
	}

	const DictRef normalized = state.new_dict();
	state.set(normalized, str(key::equipped), dict_value(equipped));
	state.set(normalized, str(key::inventory), array_value(inventory));
	return normalized;
}

DictRef _blank_equipped_slots(State &state) {
	const DictRef equipped = state.new_dict();
	for (const Atom slot : kEquipmentSlots) {
		state.set(equipped, str(slot), str(key::empty));
	}
	return equipped;
}

void _register_equipped_candidate(State &state, Atom artifact_id, DictRef equipped, ArrayRef inventory, Atom preferred_slot) {
	if (artifact_id == key::empty || !_artifact_exists(state, artifact_id) || _artifact_is_owned(state, equipped, inventory, artifact_id)) {
		return;
	}
	const ArrayRef compatible_slots = _compatible_equipment_slots(state, artifact_slot(state, artifact_id));
	if (state.array_size(compatible_slots) == 0) {
		return;
	}
	Atom slot = gd::array_has(state, compatible_slots, str(preferred_slot)) ? preferred_slot : key::empty;
	if (slot == key::empty || string_of_field(state, equipped, slot, key::empty) != key::empty) {
		slot = _first_empty_slot_from_candidates(state, equipped, compatible_slots);
	}
	if (slot == key::empty) {
		state.append(inventory, str(artifact_id));
		return;
	}
	state.set(equipped, str(slot), str(artifact_id));
}

Atom _first_empty_slot_from_candidates(State &state, DictRef equipped, ArrayRef candidates) {
	for (const Value &slot_value : gd::items(state, array_value(candidates))) {
		const Atom slot = gd::stringify(state, slot_value);
		if (string_of_field(state, equipped, slot, key::empty) == key::empty) {
			return slot;
		}
	}
	return key::empty;
}

void _append_inventory_artifact(State &state, Atom artifact_id, DictRef equipped, ArrayRef inventory) {
	if (artifact_id == key::empty || !_artifact_exists(state, artifact_id) || _artifact_is_owned(state, equipped, inventory, artifact_id)) {
		return;
	}
	state.append(inventory, str(artifact_id));
}

bool _artifact_exists(State &state, Atom artifact_id) {
	return artifact_id != key::empty && !gd::is_empty(state, gd::content_row(state, ContentTable::Artifact, artifact_id));
}

bool _artifact_is_owned(State &state, DictRef equipped, ArrayRef inventory, Atom artifact_id) {
	if (artifact_id == key::empty) {
		return false;
	}
	for (const Atom slot : kEquipmentSlots) {
		if (string_of_field(state, equipped, slot, key::empty) == artifact_id) {
			return true;
		}
	}
	for (const Value &inventory_id_value : gd::items(state, array_value(inventory))) {
		if (gd::stringify(state, inventory_id_value) == artifact_id) {
			return true;
		}
	}
	return false;
}

Atom artifact_slot(State &state, Atom artifact_id) {
	if (artifact_id == key::empty) {
		return key::empty;
	}
	const DictRef artifact = gd::content_row(state, ContentTable::Artifact, artifact_id);
	const Atom slot = string_of_field(state, artifact, key::slot, key::empty);
	return std::find(std::begin(kArtifactSlots), std::end(kArtifactSlots), slot) != std::end(kArtifactSlots) ? slot : key::empty;
}

ArrayRef _compatible_equipment_slots(State &state, Atom slot_type) {
	const ArrayRef slots = state.new_array();
	if (slot_type == key::trinket) {
		state.append(slots, str(key::trinket));
		state.append(slots, str(key::trinket_2));
	} else if (slot_type == key::boots || slot_type == key::banner || slot_type == key::armor) {
		state.append(slots, str(slot_type));
	}
	return slots;
}

DictRef _blank_bonus_totals(State &state) {
	const DictRef totals = state.new_dict();
	for (const Atom bonus : kIntBonusKeys) {
		state.set(totals, str(bonus), int_value(0));
	}
	state.set(totals, str(key::battle_school_resistance_pct), dict_value(state.new_dict()));
	const DictRef daily_income = state.new_dict();
	for (const Atom resource : kBlankIncomeKeys) {
		state.set(daily_income, str(resource), int_value(0));
	}
	state.set(totals, str(key::daily_income), dict_value(daily_income));
	state.set(totals, str(key::spell_modifiers), array_value(state.new_array()));
	state.set(totals, str(key::active_sets), array_value(state.new_array()));
	return totals;
}

void _apply_bonus_payload(State &state, DictRef totals, const Value &bonuses_value, DictRef modifier_source, Atom modifier_source_id) {
	if (!gd::is_dict(bonuses_value)) {
		return;
	}
	const DictRef bonuses = bonuses_value.ref;
	for (const Atom bonus : kIntBonusKeys) {
		state.set(totals, str(bonus), int_value(gd::add(gd::int_field(state, totals, bonus, 0), gd::int_field(state, bonuses, bonus, 0))));
	}
	// A missing key's {} merges as nothing, as null does.
	state.set(totals, str(key::battle_school_resistance_pct), dict_value(_merge_school_resistance(state, gd::field(state, totals, key::battle_school_resistance_pct), gd::field(state, bonuses, key::battle_school_resistance_pct))));
	state.set(totals, str(key::daily_income), dict_value(_merge_resources(state, gd::field(state, totals, key::daily_income), gd::field(state, bonuses, key::daily_income))));
	if (!gd::is_empty(state, modifier_source)) {
		const ArrayRef modifiers = gd::as_array(gd::index(state, totals, str(key::spell_modifiers)));
		const ArrayRef records = _artifact_spell_modifier_records(state, modifier_source, modifier_source_id);
		for (const Value &record : gd::items(state, array_value(records))) {
			state.append(modifiers, record);
		}
	}
}

DictRef _merge_school_resistance(State &state, const Value &base, const Value &delta) {
	const DictRef merged = state.new_dict();
	if (gd::is_dict(base)) {
		for (const Value &school : gd::items(state, base)) {
			const Atom school_id = gd::stringify(state, school);
			const int64_t amount = clamp_resistance(gd::to_int(state, gd::index(state, base.ref, school)));
			if (amount > 0) {
				state.set(merged, str(school_id), int_value(amount));
			}
		}
	}
	if (gd::is_dict(delta)) {
		for (const Value &school : gd::items(state, delta)) {
			const Atom school_id = gd::stringify(state, school);
			const int64_t delta_amount = clamp_resistance(gd::to_int(state, gd::index(state, delta.ref, school)));
			if (delta_amount > 0) {
				state.set(merged, str(school_id), int_value(clamp_resistance(gd::add(gd::int_field(state, merged, school_id, 0), delta_amount))));
			}
		}
	}
	return merged;
}

DictRef _merge_resources(State &state, const Value &base, const Value &delta) {
	const DictRef merged = state.new_dict();
	for (const Atom resource : kBaseResourceKeys) {
		state.set(merged, str(resource), int_value(0));
	}
	if (gd::is_dict(base)) {
		for (const Atom resource : kBaseResourceKeys) {
			state.set(merged, str(resource), int_value(gd::int_field(state, base.ref, resource, 0)));
		}
	}
	if (gd::is_dict(delta)) {
		for (const Value &resource_key : gd::items(state, delta)) {
			const Atom resource = gd::stringify(state, resource_key);
			state.set(merged, str(resource), int_value(gd::add(gd::int_field(state, merged, resource, 0), gd::to_int(state, gd::index(state, delta.ref, resource_key)))));
		}
	}
	return merged;
}

ArrayRef _artifact_spell_modifier_records(State &state, DictRef artifact, Atom artifact_id) {
	const ArrayRef records = state.new_array();
	if (gd::is_empty(state, artifact)) {
		return records;
	}
	const Value bonuses = get_or_new_dict(state, artifact, key::bonuses);
	if (!gd::is_dict(bonuses)) {
		return records;
	}
	Value modifiers;
	if (!state.lookup(bonuses.ref, str(key::spell_modifiers), modifiers) || !gd::is_array(modifiers)) {
		return records;
	}
	for (const Value &modifier_value : gd::items(state, modifiers)) {
		if (!gd::is_dict(modifier_value)) {
			continue;
		}
		const DictRef modifier = modifier_value.ref;
		const DictRef record = state.new_dict();
		state.set(record, str(key::artifact_id), str(artifact_id));
		state.set(record, str(key::artifact_name), str(string_of_field(state, artifact, key::name, artifact_id)));
		state.set(record, str(key::school_id), str(string_of_field(state, modifier, key::school_id, key::empty)));
		state.set(record, str(key::context), str(string_of_field(state, modifier, key::context, key::empty)));
		state.set(record, str(key::effect_type), str(string_of_field(state, modifier, key::effect_type, key::empty)));
		state.set(record, str(key::mana_cost_delta), int_value(gd::int_field(state, modifier, key::mana_cost_delta, 0)));
		state.set(record, str(key::effect_amount_delta), int_value(gd::int_field(state, modifier, key::effect_amount_delta, 0)));
		state.set(record, str(key::public_summary), str(string_of_field(state, modifier, key::public_summary, key::empty)));
		state.append(records, dict_value(record));
	}
	return records;
}

ArrayRef _set_states_for_equipped(State &state, const Value &equipped) {
	const DictRef equipped_dict = two_argument_get_target(equipped);
	const ArrayRef equipped_ids = state.new_array();
	for (const Atom slot : kEquipmentSlots) {
		const Atom artifact_id = string_of_field(state, equipped_dict, slot, key::empty);
		if (artifact_id != key::empty && !gd::array_has(state, equipped_ids, str(artifact_id))) {
			state.append(equipped_ids, str(artifact_id));
		}
	}

	const DictRef raw = gd::content_file(state, key::artifacts_path);
	Value sets;
	const bool has_sets = state.lookup(raw, str(key::sets), sets);
	const ArrayRef result = state.new_array();
	// No set has a piece equipped without an equipped artifact.
	if (!has_sets || !gd::is_array(sets) || state.array_size(equipped_ids) == 0) {
		return result;
	}
	// Without the active-set catalog memo (_active_set_catalog): the sets whose
	// bonuses are active, each with its piece ids, rebuilt from the same rows.
	for (const Value &set_value : gd::items(state, sets)) {
		if (!gd::is_dict(set_value)) {
			continue;
		}
		const Value runtime_policy = get_or_new_dict(state, set_value.ref, key::runtime_policy);
		if (!gd::is_dict(runtime_policy) || !gd::to_bool(gd::field_or(state, runtime_policy.ref, key::set_bonuses_active, bool_value(false)))) {
			continue;
		}
		const DictRef artifact_set = set_value.ref;
		Value raw_piece_ids;
		const ArrayRef piece_ids = state.lookup(artifact_set, str(key::piece_ids), raw_piece_ids) ? _string_array(state, raw_piece_ids) : state.new_array();
		const ArrayRef equipped_piece_ids = state.new_array();
		for (const Value &piece_id : gd::items(state, array_value(piece_ids))) {
			if (gd::array_has(state, equipped_ids, piece_id)) {
				state.append(equipped_piece_ids, piece_id);
			}
		}
		const int64_t equipped_count = state.array_size(equipped_piece_ids);
		if (equipped_count == 0) {
			continue;
		}
		const ArrayRef active_thresholds = state.new_array();
		int64_t next_threshold_count = 0;
		Value thresholds;
		if (state.lookup(artifact_set, str(key::piece_thresholds), thresholds)) {
			for (const Value &threshold_value : gd::items(state, thresholds)) {
				if (!gd::is_dict(threshold_value)) {
					continue;
				}
				const DictRef threshold = threshold_value.ref;
				const int64_t required_count = gd::int_field(state, threshold, key::count, 0);
				if (required_count > 0 && required_count <= equipped_count) {
					state.append(active_thresholds, dict_value(gd::deep_duplicate_dict(state, threshold)));
				} else if (required_count > equipped_count && (next_threshold_count == 0 || required_count < next_threshold_count)) {
					next_threshold_count = required_count;
				}
			}
		}
		const int64_t piece_count = state.array_size(piece_ids);
		const Atom set_id = string_of_field(state, artifact_set, key::id, key::empty);
		const DictRef set_state = state.new_dict();
		state.set(set_state, str(key::set_id), str(set_id));
		const Value fallback_name = state.get(artifact_set, str(key::id), str(key::artifact_set_name));
		state.set(set_state, str(key::name), str(gd::stringify(state, state.get(artifact_set, str(key::name), fallback_name))));
		state.set(set_state, str(key::piece_count), int_value(piece_count));
		state.set(set_state, str(key::equipped_piece_count), int_value(equipped_count));
		state.set(set_state, str(key::equipped_piece_ids), array_value(equipped_piece_ids));
		state.set(set_state, str(key::active_thresholds), array_value(active_thresholds));
		state.set(set_state, str(key::next_threshold_count), int_value(next_threshold_count));
		state.set(set_state, str(key::complete), bool_value(piece_count != 0 && equipped_count == piece_count));
		state.set(set_state, str(key::faction_affinity_id), str(string_of_field(state, artifact_set, key::faction_affinity_id, key::empty)));
		state.set(set_state, str(key::insignia), dict_value(artifact_set_insignia_state(state, set_id)));
		state.append(result, dict_value(set_state));
	}
	return result;
}

DictRef artifact_set_insignia_state(State &state, Atom set_id) {
	const DictRef artifact_set = artifact_set_record(state, set_id);
	if (gd::is_empty(state, artifact_set)) {
		return state.new_dict();
	}
	const Value ui_value = get_or_new_dict(state, artifact_set, key::ui);
	if (!gd::is_dict(ui_value)) {
		return state.new_dict();
	}
	const DictRef ui = ui_value.ref;
	const Atom atlas_path = gd::strip_edges(state, string_of_field(state, ui, key::atlas_path, key::empty));
	const Value region_value = get_or_new_dict(state, ui, key::atlas_region);
	const Atom alt_text = gd::strip_edges(state, string_of_field(state, ui, key::alt_text, key::empty));
	if (!gd::begins_with(state, atlas_path, key::artifact_atlas_prefix) || !gd::is_dict(region_value) || alt_text == key::empty) {
		return state.new_dict();
	}
	const DictRef region = region_value.ref;
	const int64_t x = gd::int_field(state, region, key::x, -1);
	const int64_t y = gd::int_field(state, region, key::y, -1);
	const int64_t width = gd::int_field(state, region, key::width, 0);
	const int64_t height = gd::int_field(state, region, key::height, 0);
	if (x < 0 || y < 0 || width <= 0 || height <= 0) {
		return state.new_dict();
	}
	const DictRef insignia = state.new_dict();
	state.set(insignia, str(key::set_id), str(string_of_field(state, artifact_set, key::id, key::empty)));
	state.set(insignia, str(key::name), str(string_of_field(state, artifact_set, key::name, set_id)));
	state.set(insignia, str(key::faction_affinity_id), str(string_of_field(state, artifact_set, key::faction_affinity_id, key::empty)));
	state.set(insignia, str(key::insignia_id), str(string_of_field(state, ui, key::insignia_id, key::empty)));
	state.set(insignia, str(key::atlas_path), str(atlas_path));
	const DictRef atlas_region = state.new_dict();
	state.set(atlas_region, str(key::x), int_value(x));
	state.set(atlas_region, str(key::y), int_value(y));
	state.set(atlas_region, str(key::width), int_value(width));
	state.set(atlas_region, str(key::height), int_value(height));
	state.set(insignia, str(key::atlas_region), dict_value(atlas_region));
	state.set(insignia, str(key::alt_text), str(alt_text));
	return insignia;
}

DictRef artifact_set_record(State &state, Atom set_id) {
	const Atom normalized_id = gd::strip_edges(state, set_id);
	if (normalized_id == key::empty) {
		return state.new_dict();
	}
	const DictRef raw = gd::content_file(state, key::artifacts_path);
	Value sets;
	if (!state.lookup(raw, str(key::sets), sets) || !gd::is_array(sets)) {
		return state.new_dict();
	}
	for (const Value &set_value : gd::items(state, sets)) {
		if (gd::is_dict(set_value) && string_of_field(state, set_value.ref, key::id, key::empty) == normalized_id) {
			return gd::deep_duplicate_dict(state, set_value.ref);
		}
	}
	return state.new_dict();
}

ArrayRef _string_array(State &state, const Value &value) {
	const ArrayRef result = state.new_array();
	if (gd::is_array(value)) {
		for (const Value &item : gd::items(state, value)) {
			const Atom text = gd::strip_edges(state, gd::stringify(state, item));
			if (text != key::empty && !gd::array_has(state, result, str(text))) {
				state.append(result, str(text));
			}
		}
	} else if (value.kind == state::Kind::String) {
		const Atom text = gd::strip_edges(state, value.ref);
		if (text != key::empty) {
			state.append(result, str(text));
		}
	}
	return result;
}

ArrayRef spell_affinity_records(State &state, DictRef hero_state, DictRef spell) {
	const ArrayRef records = state.new_array();
	Value modifiers;
	if (!state.lookup(aggregate_bonuses(state, hero_state), str(key::spell_modifiers), modifiers) || !gd::is_array(modifiers)) {
		return records; // the default [] is an Array with nothing in it
	}
	for (const Value &modifier_value : gd::items(state, modifiers)) {
		if (!gd::is_dict(modifier_value)) {
			continue;
		}
		const DictRef modifier = modifier_value.ref;
		if (!gd::is_empty(state, spell) && !_spell_modifier_matches(state, modifier, spell)) {
			continue;
		}
		state.append(records, dict_value(gd::deep_duplicate_dict(state, modifier)));
	}
	return records;
}

int64_t spell_mana_cost_delta(State &state, DictRef hero_state, DictRef spell) {
	int64_t delta = 0;
	for (const Value &modifier : gd::items(state, array_value(spell_affinity_records(state, hero_state, spell)))) {
		delta = gd::add(delta, gd::int_field(state, modifier.ref, key::mana_cost_delta, 0));
	}
	return delta;
}

bool _spell_modifier_matches(State &state, DictRef modifier, DictRef spell) {
	if (gd::is_empty(state, spell)) {
		return true;
	}
	const Value effect = get_or_new_dict(state, spell, key::effect);
	const Atom effect_type = gd::is_dict(effect) ? string_of_field(state, effect.ref, key::type, key::empty) : static_cast<Atom>(key::empty);
	for (const Atom field : {key::school_id, key::context, key::effect_type, key::primary_role}) {
		const Atom required = gd::strip_edges(state, string_of_field(state, modifier, field, key::empty));
		if (required == key::empty) {
			continue;
		}
		const Atom actual = field == key::effect_type ? effect_type : string_of_field(state, spell, field, key::empty);
		if (actual != required) {
			return false;
		}
	}
	return true;
}

} // namespace aurelion::rules::port::artifact_rules
