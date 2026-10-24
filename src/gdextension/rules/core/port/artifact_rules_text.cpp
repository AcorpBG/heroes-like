// ArtifactRules for the human seat's context (Phase 7, slice 7.3): an
// artifact's short text, its impact and where it is.

#include "aurelion_rules/port/overworld_rules_context.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/artifact_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <string>

namespace aurelion::rules::port {

namespace {

using gd::dict_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
namespace key = state::key;

// DAILY_INCOME_RESOURCE_IDS.
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

// String(d.get(field, fallback)).
Atom string_of_field(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
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

// parts.append(pattern % amount) when amount > 0.
void append_positive(State &state, ArrayRef parts, Atom pattern, int64_t amount) {
	if (amount > 0) {
		state.append(parts, str(gd::format(state, pattern, {int_value(amount)})));
	}
}

} // namespace

namespace artifact_rules {

Atom describe_single_artifact_impact(State &state, Atom artifact_id) {
	const DictRef artifact = gd::content_row(state, ContentTable::Artifact, artifact_id);
	const ArrayRef sections = _bonus_impact_sections(state, _artifact_bonus_totals(state, artifact), true);
	const Atom impact = state.array_size(sections) == 0 ? static_cast<Atom>(key::no_direct_stat_change) : join_array(state, key::space_bar_space, sections);
	return gd::format(state, key::impact_s, {str(impact)});
}

Atom describe_artifact_short(State &state, Atom artifact_id) {
	if (gd::is_empty(state, gd::content_row(state, ContentTable::Artifact, artifact_id))) {
		return key::artifact_cache;
	}
	const Atom name = artifact_name(state, artifact_id);
	const Atom slot_label = artifact_slot_label(state, artifact_id);
	const Atom taxonomy = artifact_taxonomy_summary(state, artifact_id);
	const Atom role = artifact_reward_role(state, artifact_id);
	const Atom effect = artifact_effect_summary(state, artifact_id);
	return gd::format(state, key::s_s_s_s_s, {str(name), str(slot_label), str(taxonomy), str(role), str(effect)});
}

Atom artifact_collection_state(State &state, DictRef hero_state, Atom artifact_id, bool collected, Atom collected_by_faction_id) {
	if (collected) {
		if (collected_by_faction_id == key::player) {
			const DictRef owned_location = locate_artifact(state, hero_state, artifact_id);
			return _owned_location_label(state, artifact_id, owned_location);
		}
		if (collected_by_faction_id != key::empty) {
			return gd::format(state, key::already_claimed_by_s, {str(gd::capitalize(state, collected_by_faction_id))});
		}
		return key::already_claimed_2;
	}
	const DictRef location = locate_artifact(state, hero_state, artifact_id);
	if (string_of_field(state, location, key::location, key::missing) != key::missing) {
		return _owned_location_label(state, artifact_id, location);
	}
	const Atom slot = artifact_slot(state, artifact_id);
	// hero_state.get("artifacts", {}): a missing key normalizes as null does.
	const DictRef artifacts = normalize_hero_artifacts(state, gd::field(state, hero_state, key::artifacts));
	// artifacts.get("equipped", {}): the normalized artifacts always hold it.
	const Value equipped = gd::index(state, artifacts, str(key::equipped));
	const Atom target_slot = _first_empty_compatible_slot(state, equipped, artifact_id);
	const Atom replacement_slot = slot != key::empty ? gd::stringify(state, state.at(_compatible_equipment_slots(state, slot), 0)) : static_cast<Atom>(key::empty);
	const Atom equipped_id = string_of_field(state, gd::as_dict(equipped), replacement_slot, key::empty);
	if (slot != key::empty && target_slot != key::empty) {
		return gd::format(state, key::will_auto_equip_to_empty_s, {str(_equipment_slot_label(state, target_slot))});
	}
	if (slot != key::empty && equipped_id != key::empty) {
		const Atom slot_label = artifact_slot_label(state, artifact_id);
		const Atom equipped_name = artifact_name(state, equipped_id);
		return gd::format(state, key::will_enter_pack_s_holds_s, {str(slot_label), str(equipped_name)});
	}
	return key::will_enter_pack;
}

Atom _owned_location_label(State &state, Atom artifact_id, DictRef location) {
	const Atom location_name = string_of_field(state, location, key::location, key::missing);
	if (location_name == key::equipped) {
		// The fallback is evaluated before the get, as in GDScript.
		const Atom fallback_slot = artifact_slot(state, artifact_id);
		const Atom slot = string_of_field(state, location, key::slot, fallback_slot);
		return gd::format(state, key::equipped_in_s_slot, {str(_equipment_slot_label(state, slot))});
	}
	if (location_name == key::inventory) {
		return key::stored_in_pack;
	}
	return key::not_owned;
}

DictRef _artifact_bonus_totals(State &state, DictRef artifact) {
	// artifact.get("bonuses", {}): a missing key is a new {}, which
	// _apply_bonus_payload still applies (its income merge keeps the base three).
	Value bonuses;
	if (!state.lookup(artifact, str(key::bonuses), bonuses)) {
		bonuses = dict_value(state.new_dict());
	}
	const DictRef totals = _blank_bonus_totals(state);
	if (!gd::is_dict(bonuses)) {
		return totals;
	}
	_apply_bonus_payload(state, totals, bonuses, artifact, string_of_field(state, artifact, key::id, key::empty));
	return totals;
}

ArrayRef _bonus_impact_sections(State &state, DictRef totals, bool include_empty_sections) {
	const ArrayRef sections = state.new_array();
	const ArrayRef field_parts = state.new_array();
	append_positive(state, field_parts, key::move_d, gd::int_field(state, totals, key::overworld_movement, 0));
	append_positive(state, field_parts, key::scout_d, gd::int_field(state, totals, key::scouting_radius, 0));
	if (state.array_size(field_parts) != 0) {
		state.append(sections, str(gd::format(state, key::field_s, {str(join_array(state, key::comma_space, field_parts))})));
	} else if (include_empty_sections) {
		state.append(sections, str(key::field_no_change));
	}

	const ArrayRef command_parts = state.new_array();
	append_positive(state, command_parts, key::attack_d, gd::int_field(state, totals, key::battle_attack, 0));
	append_positive(state, command_parts, key::defense_d, gd::int_field(state, totals, key::battle_defense, 0));
	append_positive(state, command_parts, key::initiative_d, gd::int_field(state, totals, key::battle_initiative, 0));
	append_positive(state, command_parts, key::spell_resist_d, gd::int_field(state, totals, key::battle_spell_resistance_pct, 0));
	append_positive(state, command_parts, key::control_resist_d, gd::int_field(state, totals, key::battle_control_resistance_pct, 0));
	// A missing key's {} has no schools.
	Value school_resistance;
	if (state.lookup(totals, str(key::battle_school_resistance_pct), school_resistance) && gd::is_dict(school_resistance)) {
		for (const Value &school_id : gd::items(state, school_resistance)) {
			const int64_t amount = gd::to_int(state, gd::index(state, school_resistance.ref, school_id));
			if (amount > 0) {
				const Atom school = gd::capitalize(state, gd::stringify(state, school_id));
				state.append(command_parts, str(gd::format(state, key::s_resist_d, {str(school), int_value(amount)})));
			}
		}
	}
	if (state.array_size(command_parts) != 0) {
		state.append(sections, str(gd::format(state, key::command_s, {str(join_array(state, key::comma_space, command_parts))})));
	} else if (include_empty_sections) {
		state.append(sections, str(key::command_no_change));
	}

	// totals.get("daily_income", {}) and totals.get("spell_modifiers", []): a
	// missing key gives no parts, as null does.
	const ArrayRef economy_parts = _resource_impact_parts(state, gd::field(state, totals, key::daily_income));
	if (state.array_size(economy_parts) != 0) {
		state.append(sections, str(gd::format(state, key::economy_s, {str(join_array(state, key::comma_space, economy_parts))})));
	} else if (include_empty_sections) {
		state.append(sections, str(key::economy_no_income));
	}

	const ArrayRef spell_parts = _artifact_spell_modifier_parts(state, gd::field(state, totals, key::spell_modifiers));
	if (state.array_size(spell_parts) != 0) {
		state.append(sections, str(gd::format(state, key::magic_s, {str(join_array(state, key::comma_space, spell_parts))})));
	} else if (include_empty_sections) {
		state.append(sections, str(key::magic_no_spell_hook));
	}
	return sections;
}

ArrayRef _resource_impact_parts(State &state, const Value &value) {
	const ArrayRef parts = state.new_array();
	if (!gd::is_dict(value)) {
		return parts;
	}
	for (const Atom resource : kDailyIncomeResourceIds) {
		const int64_t amount = gd::int_field(state, value.ref, resource, 0);
		if (amount > 0) {
			state.append(parts, str(gd::format(state, key::d_s_day_2, {int_value(amount), str(_resource_display_name(state, resource))})));
		}
	}
	return parts;
}

} // namespace artifact_rules

} // namespace aurelion::rules::port
