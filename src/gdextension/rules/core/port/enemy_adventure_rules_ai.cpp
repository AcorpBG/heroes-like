#include "aurelion_rules/port/adventure_services.hpp"
// EnemyAdventureRules: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/enemy_adventure_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/content_service_ai.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_ai.hpp"
#include "aurelion_rules/port/native_transit_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/visit_building_rules_ai.hpp"

#include <string>

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
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;
// text.find(what) >= 0 for a non-empty what.
bool contains_text(const State &state, Atom text, Atom what) {
	return state.text(text).find(state.text(what)) != std::string::npos;
}

} // namespace

namespace enemy_adventure_rules {

Atom _visit_key(State &state, Atom faction_id) {
	return gd::format(state, key::ai_s, {str(faction_id)});
}

DictRef _find_resource_by_placement(State &state, DictRef session, Atom placement_id) {
	// session.overworld.get("resource_nodes", []): a missing list has no nodes.
	Value nodes;
	if (state.lookup(session_view::overworld(state, session), str(key::resource_nodes), nodes)) {
		const int64_t count = ai::vsize(state, nodes);
		for (int64_t index = 0; index < count; ++index) {
			const Value node = ai::vindex(state, nodes, int_value(index));
			if (gd::is_dict(node) && ai::string_or_empty(state, node.ref, key::placement_id) == placement_id) {
				const DictRef found = state.new_dict();
				state.set(found, str(key::index), int_value(index));
				state.set(found, str(key::node), node);
				return found;
			}
		}
	}
	const DictRef missing = state.new_dict();
	state.set(missing, str(key::index), int_value(-1));
	state.set(missing, str(key::node), dict_value(state.new_dict()));
	return missing;
}

DictRef _guard_link_for_encounter(State &state, DictRef encounter) {
	Value guard;
	if (state.lookup(encounter, str(key::guard_link), guard) && gd::is_dict(guard) && !gd::is_empty(state, guard.ref)) {
		return guard.ref;
	}
	// A missing neutral_encounter or guard_link reads as a new {}, which is returned.
	Value neutral_metadata;
	if (state.lookup(encounter, str(key::neutral_encounter), neutral_metadata) && gd::is_dict(neutral_metadata)) {
		if (state.lookup(neutral_metadata.ref, str(key::guard_link), guard) && gd::is_dict(guard)) {
			return guard.ref;
		}
	}
	return state.new_dict();
}

DictRef _artifact_guard_encounter_for_node(State &state, DictRef session, DictRef node, const Value &positions) {
	if (gd::is_empty(state, node)) {
		return state.new_dict();
	}
	const DictRef overworld = session_view::overworld(state, session);
	Value resolved_encounters;
	if (!state.lookup(overworld, str(key::resolved_encounters), resolved_encounters)) {
		resolved_encounters = array_value(state.new_array());
	}
	Value encounters;
	if (!state.lookup(overworld, str(key::encounters), encounters)) {
		encounters = array_value(state.new_array());
	}
	if (gd::is_array(positions)) {
		const ArrayRef listed = state.new_array();
		for (const Value &position : gd::items(state, positions)) {
			state.append(listed, ai::vindex(state, encounters, int_value(gd::to_int(state, position))));
		}
		encounters = array_value(listed);
	}
	for (const Value &encounter_value : gd::items(state, encounters)) {
		if (!gd::is_dict(encounter_value)) {
			continue;
		}
		const DictRef encounter = encounter_value.ref;
		const DictRef guard = _guard_link_for_encounter(state, encounter);
		if (!((!gd::is_empty(state, guard) && _artifact_guard_link_targets_node(state, guard, node)) || _generated_object_guard_targets(state, encounter, key::artifact, ai::string_or_empty(state, node, key::placement_id)))) {
			continue;
		}
		if (overworld_rules::is_encounter_resolved(state, session, encounter)) {
			continue;
		}
		if (_encounter_is_pressure_host_candidate(state, encounter_value, key::empty, resolved_encounters)) {
			continue;
		}
		return encounter;
	}
	return state.new_dict();
}

bool _resource_site_is_persistent(State &state, DictRef site) {
	return gd::bool_field(state, site, key::persistent_control, false);
}

bool _resource_node_contestable_by_faction(State &state, DictRef node, DictRef site, Atom faction_id, const Value &session) {
	if (native_transit_rules::is_native(state, node)) {
		return state.array_size(native_transit_rules::destinations(state, node)) != 0;
	}
	if (adventure_services::handles(state, site)) return session.kind != Kind::Nil && adventure_services::available(state, gd::as_dict(session), node, site, faction_id);
	if (visit_building_rules::is_visit_building(state, site)) {
		return session.kind != Kind::Nil
				&& visit_building_rules::cadence(state, site) != key::always
				&& visit_building_rules::ai_value(state, site) > 0
				&& gd::bool_field(state, visit_building_rules::readiness(state, node, site, _visit_key(state, faction_id), ai::session_int(state, gd::as_dict(session), key::day)), key::ok, false);
	}
	if (creature_dwelling_rules::is_dwelling(state, site) && session.kind != Kind::Nil && player_identity_rules::resource_controller_id(state, node) == faction_id) {
		if (!ai::static_bool(state, key::enemy_adventure_rules_script, key::_ai_weights_ready)) {
			apply_ai_weights(state, content_service::default_ai_hero_weights(state));
		}
		const int64_t week_value = creature_dwelling_rules::week_value(state, node, site, ai::session_int(state, gd::as_dict(session), key::day), true);
		return week_value >= ai::static_int(state, key::enemy_adventure_rules_script, key::DWELLING_HIRE_MIN_VALUE);
	}
	if (_resource_site_is_persistent(state, site)) {
		return !player_identity_rules::allied(state, session, player_identity_rules::resource_controller_id(state, node), faction_id);
	}
	return !gd::bool_field(state, node, key::collected, false);
}

DictRef _resource_site_claim_rewards(State &state, DictRef site) {
	// site.get("claim_rewards", site.get("rewards", {})): the fallback {} is returned.
	Value rewards;
	if (!state.lookup(site, str(key::claim_rewards), rewards) && !state.lookup(site, str(key::rewards), rewards)) {
		return state.new_dict();
	}
	return gd::is_dict(rewards) ? rewards.ref : state.new_dict();
}

bool _is_active_raid(State &state, const Value &encounter, Atom faction_id, const Value &resolved_encounters) {
	if (!gd::is_dict(encounter)) {
		return false;
	}
	if (gd::bool_field(state, encounter.ref, key::raid_retired_to_rebuild, false)) {
		return false;
	}
	const Atom raid_faction = player_identity_rules::raid_controller_id(state, encounter.ref);
	if (faction_id == key::empty) {
		if (raid_faction == key::empty) {
			return false;
		}
	} else if (raid_faction != faction_id) {
		return false;
	}
	const Atom placement_id = ai::string_or_empty(state, encounter.ref, key::placement_id);
	return !_placement_resolved(state, placement_id, resolved_encounters);
}

bool _encounter_is_pressure_host_candidate(State &state, const Value &encounter, Atom faction_id, const Value &resolved_encounters) {
	if (!gd::is_dict(encounter)) {
		return false;
	}
	const DictRef raid = encounter.ref;
	if (gd::bool_field(state, raid, key::raid_retired_to_rebuild, false)) {
		return false;
	}
	const Atom placement_id = ai::string_or_empty(state, raid, key::placement_id);
	if (_is_active_raid(state, encounter, faction_id, resolved_encounters)) {
		return true;
	}
	if (_placement_resolved(state, placement_id, resolved_encounters)) {
		return false;
	}
	if (player_identity_rules::raid_controller_id(state, raid) != key::empty) {
		return true;
	}
	if (ai::string_or_empty(state, raid, key::difficulty) == key::pressure) {
		return true;
	}
	if (state.has(raid, str(key::days_active))) {
		return true;
	}
	if (gd::bool_field(state, raid, key::commanderless_support_column, false)) {
		return true;
	}
	if (ai::string_or_empty(state, raid, key::delivery_intercept_node_placement_id) != key::empty) {
		return true;
	}
	Value commander_state;
	if (state.lookup(raid, str(key::enemy_commander_state), commander_state) && gd::is_dict(commander_state) && !gd::is_empty(state, commander_state.ref)) {
		return true;
	}
	return gd::begins_with(state, placement_id, key::faction_) && contains_text(state, placement_id, key::_raid_);
}

bool _artifact_guard_link_targets_node(State &state, DictRef guard, DictRef node) {
	const Atom role = ai::string_or_empty(state, guard, key::guard_role);
	const Atom target_kind = ai::string_or_empty(state, guard, key::target_kind);
	const bool role_listed = role == key::guards_reward || role == key::guards_object;
	if (!role_listed && !(target_kind == key::artifact || target_kind == key::artifact_node || target_kind == key::reward || target_kind == key::object)) {
		return false;
	}
	if (!gd::bool_field(state, guard, key::clear_required_for_target, false) && !gd::bool_field(state, guard, key::blocks_approach, false)) {
		return false;
	}
	const Atom node_placement_id = ai::string_or_empty(state, node, key::placement_id);
	const Atom artifact_id = ai::string_or_empty(state, node, key::artifact_id);
	const Atom target_placement_id = ai::string_or_empty(state, guard, key::target_placement_id);
	const Atom target_id = ai::string_or_empty(state, guard, key::target_id);
	return (target_placement_id != key::empty && target_placement_id == node_placement_id) || (target_id != key::empty && (target_id == node_placement_id || target_id == artifact_id));
}

bool _generated_object_guard_targets(State &state, DictRef encounter, Atom target_kind, Atom target_placement_id) {
	if (target_placement_id == key::empty) {
		return false;
	}
	if (ai::string_or_empty(state, encounter, key::guarded_object_placement_id) != target_placement_id) {
		return false;
	}
	const Atom guarded_kind = ai::string_or_empty(state, encounter, key::guarded_object_kind);
	if (target_kind == key::artifact) {
		return guarded_kind == key::artifact;
	}
	return guarded_kind == key::resource || guarded_kind == key::resource_site || guarded_kind == key::mine || guarded_kind == key::neutral_dwelling || guarded_kind == key::faction_outpost || guarded_kind == key::frontier_shrine || guarded_kind == key::reward_reference || guarded_kind == key::mine_placeholder;
}

DictRef _find_artifact_by_placement(State &state, DictRef session, Atom placement_id) {
	const DictRef overworld = session_view::overworld(state, session);
	Value nodes;
	if (state.lookup(overworld, str(key::artifact_nodes), nodes)) {
		const int64_t count = ai::vsize(state, nodes);
		for (int64_t index = 0; index < count; ++index) {
			const Value node = ai::vindex(state, nodes, int_value(index));
			if (gd::is_dict(node) && ai::string_or_empty(state, node.ref, key::placement_id) == placement_id) {
				const DictRef found = state.new_dict();
				state.set(found, str(key::index), int_value(index));
				state.set(found, str(key::node), node);
				return found;
			}
		}
	}
	const DictRef missing = state.new_dict();
	state.set(missing, str(key::index), int_value(-1));
	state.set(missing, str(key::node), dict_value(state.new_dict()));
	return missing;
}

void apply_ai_weights(State &state, DictRef weights) {
	ai::assign_int(state, key::enemy_adventure_rules_script, key::DWELLING_HIRE_MIN_VALUE, weights, key::dwelling_hire_min_value);
	gd::set_static_var(state, key::enemy_adventure_rules_script, key::_ai_weights_ready, bool_value(true));
}

} // namespace enemy_adventure_rules

} // namespace aurelion::rules::port
