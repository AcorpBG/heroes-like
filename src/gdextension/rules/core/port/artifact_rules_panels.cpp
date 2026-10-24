// ArtifactRules for the hero panels (Phase 7, slice 7.8): the management,
// bonus, set and inspection texts and the icons.

#include "aurelion_rules/port/overworld_rules_panels.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/artifact_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"

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
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// EQUIPMENT_SLOTS.
constexpr Atom kEquipmentSlots[] = {key::boots, key::banner, key::armor, key::trinket, key::trinket_2};

// String(x) of any value: the engine's text for a float, a vector or a container.
Atom string_of(State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Nil:
		case Kind::Bool:
		case Kind::Int:
		case Kind::String:
		case Kind::StringName:
			return gd::stringify(state, value);
		default:
			return gd::engine_str(state, value);
	}
}

// String(d.get(field, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, Atom fallback) {
	return string_of(state, state.get(dict, str(field), str(fallback)));
}

// d.get(outer, {}).get(inner, fallback): a missing outer is the empty
// Dictionary's fallback; an outer that is no Dictionary has no get() (a
// ScriptError, as in GDScript).
Value nested_field(State &state, DictRef dict, Atom outer, Atom inner, const Value &fallback) {
	Value found;
	if (!state.lookup(dict, str(outer), found)) {
		return fallback;
	}
	return ai::vget(state, found, inner, fallback);
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

// a + b of Strings.
Atom concat(State &state, Atom a, Atom b) {
	return state.intern(state.text(a) + state.text(b));
}

// parts.append(pattern % amount) when amount > 0.
void append_positive(State &state, ArrayRef parts, Atom pattern, int64_t amount) {
	if (amount > 0) {
		state.append(parts, str(gd::format(state, pattern, {int_value(amount)})));
	}
}

// ContentService.get_content_ids(path).size(), as the content store answers
// it: the ids of raw.get("items", raw.get("entries", [])) when it is an Array.
int64_t content_id_count(State &state, Atom path) {
	const DictRef raw = gd::content_file(state, path);
	if (gd::is_empty(state, raw)) {
		return 0;
	}
	Value items;
	if (!state.lookup(raw, str(key::items), items) && !state.lookup(raw, str(key::entries), items)) {
		return 0;
	}
	if (!gd::is_array(items)) {
		return 0;
	}
	int64_t count = 0;
	for (const Value &item : gd::items(state, items)) {
		if (!gd::is_dict(item)) {
			throw state::NotPorted("left to GDScript: get_content_ids over an item that is no Dictionary");
		}
		if (state.has(item.ref, str(key::id))) {
			++count;
		}
	}
	return count;
}

} // namespace

namespace artifact_rules {

Atom describe_management(State &state, DictRef hero_state) {
	hero_state = ensure_hero_artifacts(state, gd::as_dict(gd::engine_duplicate(state, dict_value(hero_state), true)));
	const Value equipped = nested_field(state, hero_state, key::artifacts, key::equipped, dict_value(state.new_dict()));
	const Value inventory = nested_field(state, hero_state, key::artifacts, key::inventory, array_value(state.new_array()));
	const ArrayRef lines = state.new_array();

	state.append(lines, str(key::Equipped));
	for (const Atom slot : kEquipmentSlots) {
		const Atom artifact_id = string_of(state, ai::vget(state, equipped, slot, str(key::empty)));
		if (artifact_id == key::empty) {
			const Atom slot_label = _equipment_slot_label(state, slot);
			state.append(lines, str(gd::format(state, key::s_empty_ready_for_s, {str(slot_label), str(_equipment_slot_label(state, slot))})));
			continue;
		}
		const Atom slot_label = _equipment_slot_label(state, slot);
		const Atom name = artifact_name(state, artifact_id);
		const Atom taxonomy = artifact_taxonomy_summary(state, artifact_id);
		const Atom effect = artifact_effect_summary(state, artifact_id);
		const Atom impact = describe_single_artifact_impact(state, artifact_id);
		state.append(lines, str(gd::format(state, key::s_s_equipped_s_s_s, {str(slot_label), str(name), str(taxonomy), str(effect), str(impact)})));
	}

	state.append(lines, str(key::Pack));
	if (gd::is_array(inventory) && state.array_size(inventory.ref) != 0) {
		for (const Value &artifact_id_value : gd::items(state, inventory)) {
			const Atom artifact_id = string_of(state, artifact_id_value);
			if (artifact_id == key::empty) {
				continue;
			}
			const Atom name = artifact_name(state, artifact_id);
			const Atom slot_label = artifact_slot_label(state, artifact_id);
			const Atom taxonomy = artifact_taxonomy_summary(state, artifact_id);
			const Atom decision = artifact_decision_summary(state, hero_state, artifact_id);
			const Atom set_context = artifact_set_context(state, artifact_id);
			const Atom effect = artifact_effect_summary(state, artifact_id);
			const Atom impact = describe_single_artifact_impact(state, artifact_id);
			state.append(lines, str(gd::format(state, key::s_pack_s_slot_s_s, {str(name), str(slot_label), str(taxonomy), str(decision), str(set_context), str(effect), str(impact)})));
		}
	} else {
		state.append(lines, str(key::empty_3));
	}

	state.append(lines, str(describe_bonus_summary(state, hero_state)));
	state.append(lines, str(describe_set_bonus_summary(state, hero_state)));
	state.append(lines, str(describe_impact_summary(state, hero_state)));
	state.append(lines, str(describe_collection_summary(state, hero_state)));
	return join_array(state, key::newline, lines);
}

Atom describe_bonus_summary(State &state, DictRef hero_state) {
	const DictRef totals = aggregate_bonuses(state, hero_state);
	const ArrayRef parts = state.new_array();
	append_positive(state, parts, key::d_move, gd::int_field(state, totals, key::overworld_movement, 0));
	append_positive(state, parts, key::d_scout, gd::int_field(state, totals, key::scouting_radius, 0));
	append_positive(state, parts, key::d_attack, gd::int_field(state, totals, key::battle_attack, 0));
	append_positive(state, parts, key::d_defense, gd::int_field(state, totals, key::battle_defense, 0));
	append_positive(state, parts, key::d_initiative, gd::int_field(state, totals, key::battle_initiative, 0));

	// totals.get("daily_income", {}): a missing key gives no parts.
	const ArrayRef income_parts = state.new_array();
	Value income;
	if (state.lookup(totals, str(key::daily_income), income) && gd::is_dict(income)) {
		for (const Atom resource : {static_cast<Atom>(key::gold), static_cast<Atom>(key::wood), static_cast<Atom>(key::ore)}) {
			const int64_t amount = gd::int_field(state, income.ref, resource, 0);
			if (amount > 0) {
				state.append(income_parts, str(gd::format(state, key::_d_s, {int_value(amount), str(resource)})));
			}
		}
	}
	if (state.array_size(income_parts) != 0) {
		state.append(parts, str(gd::format(state, key::s_day, {str(join_array(state, key::comma_space, income_parts))})));
	}

	const Atom listed = state.array_size(parts) != 0 ? join_array(state, key::comma_space, parts) : static_cast<Atom>(key::none);
	return gd::format(state, key::bonuses_s, {str(listed)});
}

Atom describe_set_bonus_summary(State &state, DictRef hero_state) {
	const ArrayRef parts = state.new_array();
	const ArrayRef set_states = artifact_set_runtime_state(state, hero_state);
	for (const Value &set_state_value : gd::items(state, array_value(set_states))) {
		if (!gd::is_dict(set_state_value)) {
			continue;
		}
		const DictRef set_state = set_state_value.ref;
		const int64_t equipped_count = gd::int_field(state, set_state, key::equipped_piece_count, 0);
		if (equipped_count <= 0) {
			continue;
		}
		const ArrayRef threshold_parts = state.new_array();
		for (const Value &threshold_value : gd::field_items(state, set_state, str(key::active_thresholds))) {
			if (!gd::is_dict(threshold_value)) {
				continue;
			}
			const DictRef threshold = threshold_value.ref;
			const int64_t count = gd::int_field(state, threshold, key::count, 0);
			// {"bonuses": threshold.get("bonuses", {})}
			Value bonuses;
			if (!state.lookup(threshold, str(key::bonuses), bonuses)) {
				bonuses = dict_value(state.new_dict());
			}
			const DictRef payload = state.new_dict();
			state.set(payload, str(key::bonuses), bonuses);
			const Atom effect = _artifact_effect_summary(state, payload);
			state.append(threshold_parts, str(gd::format(state, key::dpc_s, {int_value(count), str(effect)})));
		}
		const Atom set_name = text_or(state, set_state, key::name, key::artifact_set_name);
		Atom status = gd::format(state, key::s_d_d_3, {str(set_name), int_value(equipped_count), int_value(gd::int_field(state, set_state, key::piece_count, 0))});
		if (state.array_size(threshold_parts) != 0) {
			status = concat(state, status, gd::format(state, key::space_bar_space_s, {str(join_array(state, key::semicolon_space, threshold_parts))}));
		} else if (gd::int_field(state, set_state, key::next_threshold_count, 0) > 0) {
			status = concat(state, status, gd::format(state, key::next_bonus_at_d_pieces, {int_value(gd::int_field(state, set_state, key::next_threshold_count, 0))}));
		}
		state.append(parts, str(status));
	}
	const Atom listed = state.array_size(parts) != 0 ? join_array(state, key::semicolon_space, parts) : static_cast<Atom>(key::none_active);
	return gd::format(state, key::sets_s, {str(listed)});
}

Atom describe_impact_summary(State &state, DictRef hero_state) {
	const ArrayRef sections = _bonus_impact_sections(state, aggregate_bonuses(state, hero_state), false);
	const Atom impact = state.array_size(sections) == 0 ? static_cast<Atom>(key::no_equipped_bonuses) : join_array(state, key::space_bar_space, sections);
	return gd::format(state, key::gear_impact_s, {str(impact)});
}

Atom describe_collection_summary(State &state, DictRef hero_state) {
	const int64_t owned_count = state.array_size(owned_artifact_ids(state, hero_state));
	const int64_t total_count = content_id_count(state, key::artifacts_path);
	if (total_count <= 0) {
		return gd::format(state, key::collection_d_owned, {int_value(owned_count)});
	}
	return gd::format(state, key::collection_d_d_known_relics_owned, {int_value(owned_count), int_value(total_count)});
}

Atom artifact_icon_path(State &state, Atom artifact_id) {
	const DictRef artifact = gd::content_row(state, ContentTable::Artifact, artifact_id);
	// artifact.get("ui", {}) if it is a Dictionary else {}, read only.
	Value ui;
	Atom icon_path = key::empty;
	if (state.lookup(artifact, str(key::ui), ui) && gd::is_dict(ui)) {
		icon_path = text_or(state, ui.ref, key::icon_path, key::empty);
	}
	icon_path = gd::strip_edges(state, icon_path);
	if (!gd::begins_with(state, icon_path, key::artifact_atlas_prefix) || !gd::resource_exists(state, icon_path)) {
		return key::empty;
	}
	return icon_path;
}

Atom artifact_type_label(State &state, Atom artifact_id) {
	const Atom slot = artifact_slot(state, artifact_id);
	if (slot == key::boots) {
		return key::Footgear;
	}
	if (slot == key::banner) {
		return key::command_banner;
	}
	if (slot == key::armor) {
		return key::Armor;
	}
	if (slot == key::trinket) {
		return key::Trinket;
	}
	return key::carry_item;
}

Atom describe_artifact_inspection(State &state, DictRef hero_state, Atom artifact_id, bool collected, Atom collected_by_faction_id) {
	const DictRef artifact = gd::content_row(state, ContentTable::Artifact, artifact_id);
	if (gd::is_empty(state, artifact)) {
		return key::artifact_cache_unknown_relic_record;
	}
	const Atom collection_state = artifact_collection_state(state, hero_state, artifact_id, collected, collected_by_faction_id);
	const Atom name = artifact_name(state, artifact_id);
	const Atom slot_label = artifact_slot_label(state, artifact_id);
	const Atom type_label = artifact_type_label(state, artifact_id);
	const Atom role = artifact_reward_role(state, artifact_id);
	const Atom set_context = artifact_set_context(state, artifact_id);
	const Atom taxonomy = artifact_taxonomy_summary(state, artifact_id);
	const Atom effect = artifact_effect_summary(state, artifact_id);
	const Atom impact = describe_single_artifact_impact(state, artifact_id);
	return gd::format(state, key::s_slot_s_s_s_s, {str(name), str(slot_label), str(type_label), str(role), str(set_context), str(taxonomy), str(effect), str(impact), str(collection_state)});
}

} // namespace artifact_rules

} // namespace aurelion::rules::port
