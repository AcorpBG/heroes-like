// OverworldRules.normalize_overworld_state's parts: the resource nodes rebuilt
// with their known fields and the runtime metadata they keep.

#include "aurelion_rules/port/overworld_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

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
using state::State;
using state::Value;
namespace key = state::key;

// String(d.get(key, "")) into d's new copy.
void copy_string(State &state, DictRef target, DictRef source, Atom field) {
	state.set(target, str(field), str(gd::to_string(state.get(source, str(field), str(key::empty)))));
}

// max(0, int(d.get(key, 0))): an int, as max() of two ints is.
void copy_day(State &state, DictRef target, DictRef source, Atom field) {
	state.set(target, str(field), int_value(compat::engine_max<int64_t>(0, gd::int_field(state, source, field, 0))));
}

// The runtime metadata _copy_resource_runtime_metadata keeps, in its order
// (ResourceNodePayloadRules, VisitBuildingRules and CreatureDwellingRules name
// some of them).
constexpr Atom kRuntimeMetadataKeys[] = {
	key::reward_choice_id,
	key::route_state_id,
	key::state_id,
	key::native_transit,
	key::h3m_type_id,
	key::h3m_subtype,
	key::collected_by_player_id,
	key::level,
	key::content_batch_id,
	key::object_id,
	key::zone_id,
	key::owner,
	key::player_slot,
	key::player_type,
	key::team_id,
	key::kind,
	key::generated_kind,
	key::original_resource_category_id,
	key::resource_id,
	key::neutral_dwelling_family_id,
	key::guard_pressure,
	key::guard_front_id,
	key::body_tiles,
	key::blocking_body,
	key::approach_tiles,
	key::visit_tile,
	key::package_body_tiles,
	key::package_block_tiles,
	key::package_visit_tiles,
	key::passability_class,
	key::pathing_status,
	key::object_footprint_catalog_ref,
	key::footprint,
	key::runtime_footprint,
	key::body_mask,
	key::runtime_body_mask,
	key::visit_mask,
	key::approach_mask,
	key::passability_mask,
	key::action_mask,
	key::terrain_restrictions,
	key::placement_predicates,
	key::placement_predicate_results,
	key::footprint_deferred,
	key::front,
	key::ai_defended_by_faction_id,
	key::ai_defended_by_player_id,
	key::ai_defended_day,
	key::ai_defense_until_day,
	key::ai_defense_rating,
	key::ai_defense_reinforced_strength,
	key::ai_defender_army,
	key::ai_defender_commander_state,
	key::ai_defender_roster_hero_id,
	key::development_source_support,
	key::source_support_town_placement_id,
	key::source_support_faction_id,
	key::source_support_missing_resource_ids,
	key::artifact_reward_id,
	key::artifact_reward_ids,
	key::artifact_reward_table_id,
	key::artifact_reward_source_key,
	key::artifact_reward_claimed_by_faction_id,
	key::artifact_reward_claimed_by_player_id,
	key::artifact_reward_claimed_day,
	key::payload_rewards,
	key::payload_reward_choices,
	key::payload_spell_ids,
	key::claim_payload_spent,
	key::payload_visit,
	key::payload_recruits,
	key::payload_vision_radius,
	key::payload_artifact_classes,
	key::payload_artifact_rarity,
	key::generated_bank_level,
	key::generated_reward_unguarded,
	key::hero_visits,
	key::side_visits,
	key::dwelling_population,
	key::dwelling_week,
	key::dwelling_guard_beaten,
	key::dwelling_guard_survivors,
	key::site_last_visit_day,
	key::generated_reward_translation,
};

} // namespace

namespace overworld_rules {

ArrayRef _normalize_resource_nodes(State &state, ArrayRef nodes) {
	const ArrayRef normalized = state.new_array();
	for (const Value &node_value : gd::items(state, array_value(nodes))) {
		if (!gd::is_dict(node_value)) {
			continue;
		}
		const DictRef node = node_value.ref;
		const DictRef normalized_node = state.new_dict();
		copy_string(state, normalized_node, node, key::placement_id);
		copy_string(state, normalized_node, node, key::site_id);
		state.set(normalized_node, str(key::x), int_value(gd::int_field(state, node, key::x, 0)));
		state.set(normalized_node, str(key::y), int_value(gd::int_field(state, node, key::y, 0)));
		state.set(normalized_node, str(key::collected), bool_value(gd::bool_field(state, node, key::collected, false)));
		copy_string(state, normalized_node, node, key::collected_by_faction_id);
		copy_day(state, normalized_node, node, key::collected_day);
		copy_string(state, normalized_node, node, key::response_origin);
		copy_string(state, normalized_node, node, key::response_source_town_id);
		copy_day(state, normalized_node, node, key::response_last_day);
		copy_day(state, normalized_node, node, key::response_until_day);
		copy_string(state, normalized_node, node, key::response_commander_id);
		copy_day(state, normalized_node, node, key::response_security_rating);
		copy_string(state, normalized_node, node, key::delivery_controller_id);
		copy_string(state, normalized_node, node, key::delivery_origin_town_id);
		copy_string(state, normalized_node, node, key::delivery_target_kind);
		copy_string(state, normalized_node, node, key::delivery_target_id);
		copy_string(state, normalized_node, node, key::delivery_target_label);
		copy_day(state, normalized_node, node, key::delivery_arrival_day);
		state.set(normalized_node, str(key::delivery_manifest), dict_value(_normalize_recruit_payload(state, state.get(node, str(key::delivery_manifest), dict_value(state.new_dict())))));
		state.set(normalized_node, str(key::delivery_completion_counts), dict_value(_normalize_delivery_completion_counts(state, state.get(node, str(key::delivery_completion_counts), dict_value(state.new_dict())))));
		copy_string(state, normalized_node, node, key::last_delivery_target_kind);
		copy_string(state, normalized_node, node, key::last_delivery_target_id);
		copy_day(state, normalized_node, node, key::last_delivery_day);
		state.set(normalized_node, str(key::last_delivery_manifest), dict_value(_normalize_recruit_payload(state, state.get(node, str(key::last_delivery_manifest), dict_value(state.new_dict())))));
		_copy_resource_runtime_metadata(state, normalized_node, node);
		state.append(normalized, dict_value(normalized_node));
	}
	return normalized;
}

void _copy_resource_runtime_metadata(State &state, DictRef target, DictRef source) {
    // Field-service state is part of the placement, including across saves.
    for (const char *name : {"prison_released", "released_hero_id", "intelligence_visits", "intelligence_reports"}) {
        const Atom field = state.intern(name);
        Value value;
        if (state.lookup(source, str(field), value)) state.set(target, str(field), value.is_container() ? gd::duplicate_value(state, value, true) : value);
    }

	for (const Atom field : kRuntimeMetadataKeys) {
		Value value;
		if (state.lookup(source, str(field), value)) {
			state.set(target, str(field), value.is_container() ? gd::duplicate_value(state, value, true) : value);
		}
	}
}

DictRef _normalize_delivery_completion_counts(State &state, const Value &value) {
	const DictRef normalized = state.new_dict();
	if (gd::is_dict(value)) {
		for (const Value &receipt_key_value : gd::items(state, array_value(gd::keys(state, value.ref)))) {
			const Atom receipt_key = gd::strip_edges(state, gd::to_string(receipt_key_value));
			const int64_t count = compat::engine_max<int64_t>(0, gd::to_int(state, state.get(value.ref, receipt_key_value, int_value(0))));
			if (receipt_key == key::empty || count <= 0) {
				continue;
			}
			state.set(normalized, str(receipt_key), int_value(count));
		}
	}
	return normalized;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
