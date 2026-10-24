// ArtifactRules for the human seat's artifact management (Phase 7, slice 7.5):
// equipping, unequipping, the management actions and their texts.

#include "aurelion_rules/port/overworld_rules_heroes.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/artifact_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <algorithm>
#include <iterator>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::str;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;

// EQUIPMENT_SLOTS.
constexpr Atom kEquipmentSlots[] = {key::boots, key::banner, key::armor, key::trinket, key::trinket_2};

// slot in EQUIPMENT_SLOTS of a String.
bool is_equipment_slot(Atom slot) {
	return std::find(std::begin(kEquipmentSlots), std::end(kEquipmentSlots), slot) != std::end(kEquipmentSlots);
}

// String(d.get(field, fallback)).
Atom string_of_field(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// d.get(field, {}) of a value that may be written: the field, or a new Dictionary.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// {"ok": ok, "hero": hero, "message": message}.
DictRef hero_result(State &state, bool ok, DictRef hero, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(ok));
	state.set(result, str(key::hero), dict_value(hero));
	state.set(result, str(key::message), str(message));
	return result;
}

// ensure_hero_artifacts(hero_state.duplicate(true)).
DictRef ensured_copy(State &state, DictRef hero_state) {
	return artifact_rules::ensure_hero_artifacts(state, gd::as_dict(gd::engine_duplicate(state, dict_value(hero_state), true)));
}

// artifacts.get("equipped", {}) of normalize_hero_artifacts' answer, which
// always holds "equipped", read only.
Value normalized_equipped(State &state, DictRef artifacts) {
	return gd::index(state, artifacts, str(key::equipped));
}

} // namespace

namespace artifact_rules {

DictRef perform_management_action(State &state, DictRef hero_state, Atom action_id) {
	if (gd::begins_with(state, action_id, key::equip_artifact)) {
		return equip_artifact(state, hero_state, gd::trim_prefix(state, action_id, key::equip_artifact));
	}
	if (gd::begins_with(state, action_id, key::unequip_artifact)) {
		return unequip_artifact(state, hero_state, gd::trim_prefix(state, action_id, key::unequip_artifact));
	}
	return hero_result(state, false, ensured_copy(state, hero_state), key::that_artifact_order_is_not_supported);
}

bool equipment_slot_accepts(State &state, Atom slot, Atom artifact_id) {
	return gd::array_has(state, _compatible_equipment_slots(state, artifact_slot(state, artifact_id)), str(slot));
}

DictRef equip_artifact_in_slot(State &state, DictRef hero_state, Atom artifact_id, Atom slot) {
	const DictRef hero = ensured_copy(state, hero_state);
	if (!equipment_slot_accepts(state, slot, artifact_id)) {
		const Atom name = artifact_name(state, artifact_id);
		const Atom slot_label = _equipment_slot_label(state, slot);
		return hero_result(state, false, hero, gd::format(state, key::s_does_not_fit_the_s, {str(name), str(slot_label)}));
	}
	const DictRef location = locate_artifact(state, hero, artifact_id);
	const Atom location_name = string_of_field(state, location, key::location, key::missing);
	if (location_name == key::missing) {
		return hero_result(state, false, hero, key::that_artifact_is_not_owned_by);
	}
	if (location_name == key::equipped && string_of_field(state, location, key::slot, key::empty) == slot) {
		return hero_result(state, false, hero, gd::format(state, key::s_is_already_worn_there, {str(artifact_name(state, artifact_id))}));
	}
	// var artifacts = hero.get("artifacts", {}): untyped, so its get() is a Dictionary's.
	const Value artifacts = field_or_new_dict(state, hero, key::artifacts);
	const DictRef equipped = gd::as_dict(ai::vget(state, artifacts, key::equipped, dict_value(state.new_dict())));
	const Value inventory_value = ai::vget(state, artifacts, key::inventory, array_value(state.new_array()));
	const ArrayRef inventory = gd::is_array(inventory_value) ? inventory_value.ref : state.new_array();
	Atom previous_slot = key::empty;
	if (location_name == key::equipped) {
		previous_slot = string_of_field(state, location, key::slot, key::empty);
		state.set(equipped, str(previous_slot), str(key::empty));
	} else {
		_remove_artifact_from_inventory(state, inventory, artifact_id);
	}
	const Atom displaced_id = string_of_field(state, equipped, slot, key::empty);
	state.set(equipped, str(slot), str(artifact_id));
	if (displaced_id != key::empty) {
		if (previous_slot != key::empty && equipment_slot_accepts(state, previous_slot, displaced_id)) {
			state.set(equipped, str(previous_slot), str(displaced_id));
		} else {
			state.append(inventory, str(displaced_id));
		}
	}
	state.set(artifacts.ref, str(key::equipped), dict_value(equipped));
	state.set(artifacts.ref, str(key::inventory), array_value(inventory));
	state.set(hero, str(key::artifacts), dict_value(normalize_hero_artifacts(state, artifacts)));
	Atom message = gd::format(state, key::equipped_s_in_s, {str(artifact_name(state, artifact_id)), str(_equipment_slot_label(state, slot))});
	if (displaced_id != key::empty) {
		const Atom displaced_name = artifact_name(state, displaced_id);
		const bool swapped = string_of_field(state, equipped, previous_slot, key::empty) == displaced_id && previous_slot != key::empty;
		const Atom outcome = swapped ? static_cast<Atom>(key::swaps_places) : static_cast<Atom>(key::goes_to_the_pack);
		const Atom tail = gd::format(state, key::s_s_13, {str(displaced_name), str(outcome)});
		message = state.intern(state.text(message) + state.text(tail));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::hero), dict_value(hero));
	state.set(result, str(key::slot), str(slot));
	state.set(result, str(key::swapped_out_artifact_id), str(displaced_id));
	state.set(result, str(key::message), str(message));
	return result;
}

DictRef unequip_artifact(State &state, DictRef hero_state, Atom slot) {
	const DictRef hero = ensured_copy(state, hero_state);
	if (!is_equipment_slot(slot)) {
		return hero_result(state, false, hero, key::that_equipment_slot_does_not_exist);
	}

	const Value artifacts = field_or_new_dict(state, hero, key::artifacts);
	const Value equipped = ai::vget(state, artifacts, key::equipped, dict_value(state.new_dict()));
	const Atom artifact_id = gd::stringify(state, ai::vget(state, equipped, slot, str(key::empty)));
	if (artifact_id == key::empty) {
		return hero_result(state, false, hero, key::no_artifact_is_equipped_there);
	}

	const Value inventory = ai::vget(state, artifacts, key::inventory, array_value(state.new_array()));
	// equipped[slot] = "": equipped.get() above answered, so it is a Dictionary.
	state.set(equipped.ref, str(slot), str(key::empty));
	_append_inventory_artifact(state, artifact_id, gd::as_dict(equipped), gd::as_array(inventory));
	state.set(artifacts.ref, str(key::equipped), equipped);
	state.set(artifacts.ref, str(key::inventory), inventory);
	state.set(hero, str(key::artifacts), dict_value(normalize_hero_artifacts(state, artifacts)));

	const Atom name = artifact_name(state, artifact_id);
	const Atom slot_label = _equipment_slot_label(state, slot);
	const Atom effect = artifact_effect_summary(state, artifact_id);
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::hero), dict_value(hero));
	state.set(result, str(key::slot), str(slot));
	state.set(result, str(key::message), str(gd::format(state, key::stowed_s_from_s_into_pack, {str(name), str(slot_label), str(effect)})));
	return result;
}

ArrayRef get_management_actions(State &state, DictRef hero_state_value) {
	const DictRef hero_state = ensured_copy(state, hero_state_value);
	const ArrayRef actions = state.new_array();
	const Value artifacts = field_or_new_dict(state, hero_state, key::artifacts);
	const Value inventory = ai::vget(state, artifacts, key::inventory, array_value(state.new_array()));
	const Value equipped = ai::vget(state, artifacts, key::equipped, dict_value(state.new_dict()));

	if (gd::is_array(inventory)) {
		for (const Value &artifact_id_value : gd::items(state, inventory)) {
			const Atom artifact_id = gd::stringify(state, artifact_id_value);
			if (artifact_id == key::empty) {
				continue;
			}
			if (gd::is_empty(state, gd::content_row(state, ContentTable::Artifact, artifact_id))) {
				continue;
			}
			Atom slot = _first_empty_compatible_slot(state, equipped, artifact_id);
			if (slot == key::empty) {
				slot = gd::to_string(state.at(_compatible_equipment_slots(state, artifact_slot(state, artifact_id)), 0));
			}
			const Atom equipped_id = gd::stringify(state, ai::vget(state, equipped, slot, str(key::empty)));
			Atom label_prefix = key::Equip;
			// The summary, built again for a swap as the GDScript does.
			const auto summary_text = [&state, hero_state, artifact_id]() {
				const Atom decision = artifact_decision_summary(state, hero_state, artifact_id);
				const Atom role = artifact_reward_role(state, artifact_id);
				const Atom set_context = artifact_set_context(state, artifact_id);
				const Atom impact = describe_single_artifact_impact(state, artifact_id);
				const Atom effect = artifact_effect_summary(state, artifact_id);
				return gd::format(state, key::s_s_s_s_s, {str(decision), str(role), str(set_context), str(impact), str(effect)});
			};
			Atom summary = summary_text();
			if (equipped_id != key::empty) {
				label_prefix = key::swap_in;
				summary = summary_text();
			}
			const DictRef action = state.new_dict();
			state.set(action, str(key::id), str(gd::format(state, key::equip_artifact_s, {str(artifact_id)})));
			state.set(action, str(key::label), str(gd::format(state, key::s_s, {str(label_prefix), str(artifact_name(state, artifact_id))})));
			state.set(action, str(key::summary), str(summary));
			state.append(actions, dict_value(action));
		}
	}

	if (gd::is_dict(equipped)) {
		for (const Atom slot : kEquipmentSlots) {
			const Atom equipped_id = string_of_field(state, equipped.ref, slot, key::empty);
			if (equipped_id == key::empty) {
				continue;
			}
			const DictRef equipped_artifact = gd::content_row(state, ContentTable::Artifact, equipped_id);
			const DictRef action = state.new_dict();
			state.set(action, str(key::id), str(gd::format(state, key::unequip_artifact_s, {str(slot)})));
			state.set(action, str(key::label), str(gd::format(state, key::stow_s, {str(artifact_name(state, equipped_id))})));
			const Atom slot_label = artifact_slot_label(state, equipped_id);
			const Atom impact = describe_single_artifact_impact(state, equipped_id);
			const Atom effect = _artifact_effect_summary(state, equipped_artifact);
			state.set(action, str(key::summary), str(gd::format(state, key::s_slot_move_to_pack_removes, {str(slot_label), str(impact), str(effect)})));
			state.append(actions, dict_value(action));
		}
	}
	return actions;
}

Atom artifact_id_for_management_action(State &state, DictRef hero_state, Atom action_id) {
	if (gd::begins_with(state, action_id, key::equip_artifact)) {
		const Atom inventory_artifact_id = gd::trim_prefix(state, action_id, key::equip_artifact);
		const DictRef location = locate_artifact(state, hero_state, inventory_artifact_id);
		return string_of_field(state, location, key::location, key::missing) == key::inventory ? inventory_artifact_id : static_cast<Atom>(key::empty);
	}
	if (gd::begins_with(state, action_id, key::unequip_artifact)) {
		const Atom slot = gd::trim_prefix(state, action_id, key::unequip_artifact);
		if (!is_equipment_slot(slot)) {
			return key::empty;
		}
		// hero_state.get("artifacts", {}): normalize_hero_artifacts({}) is normalize_hero_artifacts(null).
		const DictRef artifacts = normalize_hero_artifacts(state, gd::field(state, hero_state, key::artifacts));
		return gd::stringify(state, ai::vget(state, normalized_equipped(state, artifacts), slot, str(key::empty)));
	}
	return key::empty;
}

Atom artifact_set_context(State &state, Atom artifact_id) {
	const DictRef artifact = gd::content_row(state, ContentTable::Artifact, artifact_id);
	if (gd::is_empty(state, artifact)) {
		return key::set_unknown;
	}
	const Atom set_id = _artifact_set_id(state, artifact);
	if (set_id == key::empty) {
		return key::standalone_relic;
	}
	return gd::format(state, key::set_s, {str(_title_label(state, set_id))});
}

Atom artifact_decision_summary(State &state, DictRef hero_state, Atom artifact_id) {
	if (gd::is_empty(state, gd::content_row(state, ContentTable::Artifact, artifact_id))) {
		return key::cannot_equip;
	}
	const Atom slot = artifact_slot(state, artifact_id);
	if (slot == key::empty) {
		return key::pack_only;
	}
	const DictRef location = locate_artifact(state, hero_state, artifact_id);
	// hero_state.get("artifacts", {}): normalize_hero_artifacts({}) is normalize_hero_artifacts(null).
	const DictRef artifacts = normalize_hero_artifacts(state, gd::field(state, hero_state, key::artifacts));
	Atom target_slot = _first_empty_compatible_slot(state, normalized_equipped(state, artifacts), artifact_id);
	if (target_slot == key::empty) {
		target_slot = gd::to_string(state.at(_compatible_equipment_slots(state, slot), 0));
	}
	const Atom equipped_id = gd::stringify(state, ai::vget(state, normalized_equipped(state, artifacts), target_slot, str(key::empty)));
	const Atom location_name = string_of_field(state, location, key::location, key::missing);
	if (location_name == key::equipped) {
		const Atom slot_label = _equipment_slot_label(state, string_of_field(state, location, key::slot, slot));
		return gd::format(state, key::equipped_in_s_can_stow_to, {str(slot_label)});
	}
	if (location_name == key::inventory) {
		if (equipped_id == key::empty) {
			return gd::format(state, key::can_equip_to_empty_s, {str(_equipment_slot_label(state, target_slot))});
		}
		return gd::format(state, key::can_swap_with_s, {str(artifact_name(state, equipped_id))});
	}
	if (equipped_id == key::empty) {
		return gd::format(state, key::will_auto_equip_to_empty_s_2, {str(_equipment_slot_label(state, target_slot))});
	}
	return gd::format(state, key::will_enter_pack_can_swap_with, {str(artifact_name(state, equipped_id))});
}

} // namespace artifact_rules

} // namespace aurelion::rules::port
