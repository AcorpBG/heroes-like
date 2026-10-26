#include "aurelion_rules/port/adventure_services.hpp"
// OverworldRules for the human seat's arrival (Phase 7, slice 7.2): resource
// site and artifact lookups, claims, guards and their texts, and the artifact
// pickup.

#include "aurelion_rules/port/overworld_rules_move.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/battle_payload.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_ai.hpp"
#include "aurelion_rules/port/native_transit_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/resource_node_payload_rules_ai.hpp"
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
using overworld_rules::Vector2i;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// {"index": index, "node": node}.
DictRef node_result(State &state, int64_t index, const Value &node) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::index), int_value(index));
	state.set(result, str(key::node), node);
	return result;
}

// {"index": -1, "node": {}}.
DictRef no_node(State &state) {
	return node_result(state, -1, dict_value(state.new_dict()));
}

// {"ok": false, "message": message}.
DictRef refusal(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

// d.get(field, []) of an untyped field: the value, or a new Array.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// nodes[index] if nodes is Array and index >= 0 and index < nodes.size() else {}.
Value node_at(State &state, const Value &nodes, int64_t index) {
	if (gd::is_array(nodes) && index >= 0 && index < state.array_size(nodes.ref)) {
		return state.at(nodes.ref, index);
	}
	return dict_value(state.new_dict());
}

// The first entry of a spatial lookup table at the hero's tile whose node is a
// Dictionary (and, with skip_collected, not collected).
DictRef node_at_hero_tile(State &state, DictRef session, Atom collection, Atom table, bool skip_collected) {
	const Vector2i pos = overworld_rules::hero_position(state, session);
	const Value nodes = field_or_new_array(state, session_view::overworld(state, session), collection);
	const DictRef lookup_index = overworld_rules::_spatial_lookup_index(state, session, -1);
	for (const Value &node_index : gd::items(state, array_value(overworld_rules::_spatial_lookup_entries(state, lookup_index, table, pos)))) {
		const int64_t index = gd::to_int(state, node_index);
		const Value node = node_at(state, nodes, index);
		if (gd::is_dict(node) && !(skip_collected && gd::bool_field(state, node.ref, key::collected, false))) {
			return node_result(state, index, node);
		}
	}
	return no_node(state);
}

// separator.join(strings) of an Array of Strings.
Atom join_items(State &state, Atom separator, ArrayRef items) {
	std::string joined;
	const int64_t count = state.array_size(items);
	for (int64_t index = 0; index < count; ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += gd::text(state, state.at(items, index));
	}
	return state.intern(joined);
}

// s.to_lower() of ASCII text (the cadence labels).
Atom to_lower_ascii(State &state, Atom text) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

// _resource_site_repeat_ready(session, node, site) with GDScript's session, a
// view or Nil.
bool repeat_ready(State &state, const Value &session, DictRef node, DictRef site) {
	if (!overworld_rules::_resource_site_is_repeatable(state, site)) {
		return false;
	}
	if (!gd::bool_field(state, node, key::collected, false)) {
		return true;
	}
	if (session.kind == Kind::Nil) {
		return false;
	}
	const int64_t cooldown = compat::engine_max<int64_t>(1, gd::int_field(state, site, key::visit_cooldown_days, 1));
	return ai::session_int(state, gd::as_dict(session), key::day) >= gd::add(gd::int_field(state, node, key::collected_day, 0), cooldown);
}

// nodes[index] = value of an untyped Array or Dictionary.
void set_untyped_index(State &state, const Value &container, int64_t index, const Value &value) {
	if (gd::is_array(container)) {
		state.set_at(container.ref, index, value);
		return;
	}
	if (gd::is_dict(container)) {
		state.set(container.ref, int_value(index), value);
		return;
	}
	throw state::ScriptError(std::string("Invalid assignment of index '") + std::to_string(index) + "' on a base object of type '" + gd::type_name(container) + "'.");
}

} // namespace

namespace overworld_rules {

DictRef _find_resource_node_at(State &state, DictRef session) {
	return node_at_hero_tile(state, session, key::resource_nodes, key::resource_by_tile, false);
}

DictRef _find_context_resource_node(State &state, DictRef session) {
	DictRef found = _find_resource_node_at(state, session);
	if (gd::int_field(state, found, key::index, -1) < 0) {
		found = _find_resource_node_interaction_at(state, session);
	}
	if (gd::int_field(state, found, key::index, -1) < 0) {
		return no_node(state);
	}
	const DictRef node = gd::as_dict(gd::field(state, found, key::node));
	const DictRef site = gd::content_row(state, ContentTable::ResourceSite, ai::string_or_empty(state, node, key::site_id));
	if (resource_node_is_present(state, node, site)) {
		return found;
	}
	return no_node(state);
}

DictRef _find_resource_node_interaction_at(State &state, DictRef session) {
	return node_at_hero_tile(state, session, key::resource_nodes, key::resource_by_interaction_tile, false);
}

DictRef _resource_site_visit_cost(State &state, DictRef site) {
	// site.get("service_cost", {}): a missing cost normalizes to {} as null does.
	return _normalize_resource_dict(state, gd::field(state, site, key::service_cost));
}

bool _resource_site_repeat_ready(State &state, DictRef session, DictRef node, DictRef site) {
	return repeat_ready(state, dict_value(session), node, site);
}

int64_t _resource_site_next_visit_day(State &state, DictRef node, DictRef site) {
	return gd::add(gd::int_field(state, node, key::collected_day, 0), compat::engine_max<int64_t>(1, gd::int_field(state, site, key::visit_cooldown_days, 1)));
}

Atom _resource_site_repeatable_block_message(State &state, DictRef session, DictRef node, DictRef site) {
	const int64_t next_day = _resource_site_next_visit_day(state, node, site);
	if (ai::session_int(state, session, key::day) < next_day) {
		return gd::format(state, key::s_can_be_used_again_on, {str(gd::stringify(state, state.get(site, str(key::name), str(key::this_service)))), int_value(next_day)});
	}
	return gd::format(state, key::s_is_not_available_right_now, {str(gd::stringify(state, state.get(site, str(key::name), str(key::this_service))))});
}

bool _resource_node_claimable_by_player(State &state, DictRef node, DictRef site, const Value &session) {
	if (native_transit_rules::is_native(state, node)) {
		return true;
	}
	if (session.kind != Kind::Nil) {
		const DictRef guard_encounter = _resource_site_guard_encounter(state, gd::as_dict(session), node, site, Value());
		if (_resource_site_guard_blocks_node(state, guard_encounter, node)) {
			return false;
		}
	}
	if (visit_building_rules::is_visit_building(state, site)) {
		if (session.kind == Kind::Nil) {
			return false;
		}
		const DictRef view = gd::as_dict(session);
		const Atom visitor_key = ai::string_or_empty(state, session_view::overworld(state, view), key::active_hero_id);
		const int64_t day = ai::session_int(state, view, key::day);
		const Atom side = visit_building_rules::side_key(state, session);
		return gd::bool_field(state, visit_building_rules::readiness(state, node, site, visitor_key, day, side), key::ok, false);
	}
	if (creature_dwelling_rules::is_dwelling(state, site)) {
		return session.kind != Kind::Nil;
	}
	if (_resource_site_is_repeatable(state, site) && !_resource_site_is_persistent(state, site)) {
		return repeat_ready(state, session, node, site);
	}
	if (_resource_site_is_persistent(state, site)) {
		return ai::string_or_empty(state, node, key::collected_by_faction_id) != key::player;
	}
	return !gd::bool_field(state, node, key::collected, false);
}

DictRef _resource_defender_battle_payload(State &state, DictRef session, DictRef node, DictRef site) {
	if (!_resource_node_has_live_ai_defender(state, session, node, site)) {
		return state.new_dict();
	}
	return battle_rules::create_resource_defense_payload(state, dict_value(session), ai::string_or_empty(state, node, key::placement_id));
}

bool _resource_node_has_live_ai_defender(State &state, DictRef session, DictRef node, DictRef site) {
	if (gd::is_empty(state, node) || !_resource_site_is_persistent(state, site)) {
		return false;
	}
	const Atom controller = player_identity_rules::resource_controller_id(state, node);
	if (controller == key::empty || controller == key::player) {
		return false;
	}
	const Atom defended_by = player_identity_rules::defender_controller_id(state, node);
	if (defended_by != key::empty && defended_by != controller) {
		return false;
	}
	int64_t defense_until = gd::int_field(state, node, key::ai_defense_until_day, 0);
	// var front: Dictionary = node.get("front", {}) if it is a Dictionary else {}.
	Value front;
	const int64_t front_until = state.lookup(node, str(key::front), front) && gd::is_dict(front) ? gd::int_field(state, front.ref, key::defense_until_day, 0) : 0;
	defense_until = compat::engine_max<int64_t>(defense_until, front_until);
	if (defense_until < ai::session_int(state, session, key::day)) {
		return false;
	}
	Value defender_army;
	if (!state.lookup(node, str(key::ai_defender_army), defender_army)) {
		// node.get("ai_defender_army", {}): {} has no stacks, a strength of 0.
		return false;
	}
	if (!gd::is_dict(defender_army)) {
		return false;
	}
	// defender_army.get("stacks", []): a missing list has a strength of 0, as null does.
	return _army_strength_value(state, gd::field(state, defender_army.ref, key::stacks)) > 0;
}

DictRef _resource_site_claim_rewards(State &state, DictRef site) {
	// site.get("claim_rewards", site.get("rewards", {})).
	Value rewards;
	if (!state.lookup(site, str(key::claim_rewards), rewards) && !state.lookup(site, str(key::rewards), rewards)) {
		return state.new_dict();
	}
	return gd::is_dict(rewards) ? rewards.ref : state.new_dict();
}

DictRef _resource_site_claim_recruits(State &state, DictRef site) {
	Value recruits;
	if (state.lookup(site, str(key::claim_recruits), recruits) && gd::is_dict(recruits) && !gd::is_empty(state, recruits.ref)) {
		return recruits.ref;
	}
	Value roster;
	if (state.lookup(site, str(key::neutral_roster), roster) && gd::is_dict(roster)) {
		// roster.get("claim_recruits", {}): a missing entry is a new empty Dictionary.
		Value roster_recruits;
		if (!state.lookup(roster.ref, str(key::claim_recruits), roster_recruits)) {
			return state.new_dict();
		}
		if (gd::is_dict(roster_recruits)) {
			return roster_recruits.ref;
		}
	}
	return state.new_dict();
}

DictRef _resource_site_claim_flags(State &state, DictRef site) {
	Value claim_flags;
	if (!state.lookup(site, str(key::claim_flags), claim_flags)) {
		// site.get("claim_flags", {}).duplicate(true): a new empty Dictionary.
		return state.new_dict();
	}
	return gd::is_dict(claim_flags) ? gd::as_dict(gd::engine_duplicate(state, claim_flags, true)) : state.new_dict();
}

bool hero_is_visiting_resource_site(State &state, DictRef session, DictRef node) {
	if (!overworld_level_rules::on_level(state, dict_value(node), hero_level(state, session))) {
		return false;
	}
	const Vector2i tile = hero_position(state, session);
	const ArrayRef tiles = _resource_node_world_interaction_tiles(state, _map_object_for_resource_node(state, node), node);
	return gd::array_has(state, tiles, Value::of_vector2i(tile.x, tile.y));
}

bool resource_site_is_recruit_source(State &state, DictRef site) {
	return ai::string_or_empty(state, site, key::family) == key::neutral_dwelling
			|| !gd::is_empty(state, _resource_site_claim_recruits(state, site))
			|| !gd::is_empty(state, _resource_site_weekly_recruits(state, site));
}

Atom _resource_site_claim_message(State &state, DictRef site, Atom previous_controller) {
	// String(site.get("name", fallback)).
	const auto site_name = [&](Atom fallback) {
		return str(gd::stringify(state, state.get(site, str(key::name), str(fallback))));
	};
	if (_resource_site_is_repeatable(state, site) && !_resource_site_is_persistent(state, site)) {
		return gd::format(state, key::used_s, {site_name(key::the_service)});
	}
	if (!_resource_site_is_persistent(state, site)) {
		return gd::format(state, key::claimed_s, {site_name(key::the_site)});
	}
	if (previous_controller == key::empty) {
		return gd::format(state, key::secured_s, {site_name(key::the_site)});
	}
	if (previous_controller == key::player) {
		return gd::format(state, key::s_already_answers_your_banners, {site_name(key::the_site_2)});
	}
	return gd::format(state, key::retook_s_from_hostile_control, {site_name(key::the_site)});
}

Atom _resource_site_yield_line(State &state, DictRef session, DictRef node, DictRef site) {
	return _resource_site_yield_line(state, dict_value(session), node, site);
}

Atom _resource_site_yield_line(State &state, const Value &session, DictRef node, DictRef site) {
	site = resource_node_payload_rules::site_for_node(state, node, site);
    if (adventure_services::handles(state, site)) {
        if (gd::bool_field(state, node, state.intern("prison_released"), false)) return state.intern("Empty stockade: its commander has already been rescued.");
        return ai::string_or_empty(state, site, key::public_text);
    }
	if (visit_building_rules::is_visit_building(state, site)) {
		const ArrayRef visit_parts = state.new_array();
		state.append(visit_parts, str(visit_building_rules::summary(state, site)));
		if (session.kind != Kind::Nil) {
			const DictRef view = gd::as_dict(session);
			const Atom visitor_key = ai::string_or_empty(state, session_view::overworld(state, view), key::active_hero_id);
			const int64_t day = ai::session_int(state, view, key::day);
			const Atom side = visit_building_rules::side_key(state, session);
			state.append(visit_parts, str(visit_building_rules::status_line(state, node, site, visitor_key, day, side)));
		}
		return join_items(state, key::space_bar_space, _non_empty_strings(state, visit_parts));
	}
	if (creature_dwelling_rules::is_dwelling(state, site)) {
		const int64_t day = session.kind != Kind::Nil ? ai::session_int(state, gd::as_dict(session), key::day) : 1;
		const ArrayRef dwelling_parts = state.new_array();
		state.append(dwelling_parts, str(creature_dwelling_rules::summary(state, node, site, day)));
		if (session.kind != Kind::Nil && player_identity_rules::resource_controller_id(state, node) == key::player) {
			const Atom population = _describe_recruit_delta(state, dict_value(creature_dwelling_rules::population(state, node, site, day)));
			state.append(dwelling_parts, str(gd::format(state, key::s_left_this_week, {str(population)})));
		}
		return join_items(state, key::space_bar_space, _non_empty_strings(state, dwelling_parts));
	}
	const ArrayRef parts = state.new_array();
	const Atom claim_summary = _resource_site_reward_summary(state, site);
	// site.get("control_income", {}): a missing income describes as "", as null does.
	const Atom income_summary = _describe_resource_delta(state, gd::field(state, site, key::control_income));
	const Atom weekly_summary = _describe_recruit_delta(state, dict_value(_resource_site_weekly_recruits(state, site)));
	const Atom claim_recruits = _describe_recruit_delta(state, dict_value(_resource_site_claim_recruits(state, site)));
	if (_resource_site_is_persistent(state, site)) {
		if (claim_summary != key::empty) {
			state.append(parts, str(gd::format(state, key::claim_s, {str(claim_summary)})));
		}
		if (income_summary != key::empty) {
			const Atom cadence = to_lower_ascii(state, _resource_site_income_cadence_label(state, site));
			state.append(parts, str(gd::format(state, key::s_s, {str(cadence), str(income_summary)})));
		}
		if (weekly_summary != key::empty) {
			state.append(parts, str(gd::format(state, key::weekly_s, {str(weekly_summary)})));
		}
		if (claim_recruits != key::empty) {
			state.append(parts, str(gd::format(state, key::capture_recruits_s, {str(claim_recruits)})));
		}
	} else {
		const Atom reward_summary = _resource_site_reward_summary(state, site);
		if (reward_summary != key::empty) {
			state.append(parts, str(gd::format(state, key::one_time_s, {str(reward_summary)})));
		}
		if (claim_recruits != key::empty) {
			state.append(parts, str(gd::format(state, key::troops_join_s, {str(claim_recruits)})));
		}
	}
	const Atom artifact_summary = _resource_site_artifact_summary(state, site);
	if (artifact_summary != key::empty) {
		state.append(parts, str(artifact_summary));
	}
	if (_resource_site_is_repeatable(state, site)) {
		const Atom cost_summary = _describe_resource_delta(state, dict_value(_resource_site_visit_cost(state, site)));
		if (cost_summary != key::empty) {
			state.append(parts, str(gd::format(state, key::service_cost_s, {str(cost_summary)})));
		}
		// _resource_site_repeat_ready(session, node, site), whose session may be null here.
		if (repeat_ready(state, session, node, site)) {
			state.append(parts, str(key::service_ready));
		} else if (gd::bool_field(state, node, key::collected, false)) {
			state.append(parts, str(gd::format(state, key::next_service_day_d, {int_value(_resource_site_next_visit_day(state, node, site))})));
		}
	}
	const ArrayRef lesson_names = _resource_site_spell_names(state, site);
	if (state.array_size(lesson_names) != 0) {
		state.append(parts, str(gd::format(state, key::teaches_s, {str(_spell_list_text(state, lesson_names))})));
	}
	return join_items(state, key::comma_space, _non_empty_strings(state, parts));
}

Atom _resource_site_income_cadence_label(State &state, DictRef site) {
	return gd::stringify(state, state.get(site, str(key::control_income_cadence), str(key::daily))) == key::weekly ? key::Weekly : key::Daily;
}

DictRef _resource_site_guard_encounter(State &state, DictRef session, DictRef node, DictRef site, const Value &positions) {
	const Atom guard_front_id = ai::string_or_empty(state, node, key::guard_front_id);
	Value encounters = field_or_new_array(state, session_view::overworld(state, session), key::encounters);
	if (gd::is_array(positions)) {
		const ArrayRef listed = state.new_array();
		for (const Value &position : gd::items(state, positions)) {
			state.append(listed, ai::vindex(state, encounters, int_value(gd::to_int(state, position))));
		}
		encounters = array_value(listed);
	}
	for (const Value &encounter : gd::items(state, encounters)) {
		if (!gd::is_dict(encounter) || is_encounter_resolved(state, session, encounter.ref)) {
			continue;
		}
		if (guard_front_id != key::empty && guard_front_id == ai::string_or_empty(state, encounter.ref, key::placement_id)) {
			return encounter.ref;
		}
		const DictRef guard = _resource_site_guard_link_for_encounter(state, encounter.ref);
		if (gd::is_empty(state, guard)) {
			continue;
		}
		if (_resource_site_guard_targets_node(state, guard, node, site)) {
			return encounter.ref;
		}
	}
	return state.new_dict();
}

bool _resource_site_guard_blocks_node(State &state, DictRef encounter, DictRef node) {
	if (gd::is_empty(state, encounter)) {
		return false;
	}
	const Atom explicit_guard_front_id = ai::string_or_empty(state, node, key::guard_front_id);
	if (explicit_guard_front_id != key::empty && explicit_guard_front_id == ai::string_or_empty(state, encounter, key::placement_id)) {
		return true;
	}
	const DictRef guard_link = _resource_site_guard_link_for_encounter(state, encounter);
	return gd::bool_field(state, guard_link, key::clear_required_for_target, false);
}

bool _resource_site_guard_targets_node(State &state, DictRef guard, DictRef node, DictRef site) {
	const Atom node_placement_id = ai::string_or_empty(state, node, key::placement_id);
	const Atom site_id = gd::stringify(state, state.get(site, str(key::id), state.get(node, str(key::site_id), str(key::empty))));
	const Atom target_placement_id = ai::string_or_empty(state, guard, key::target_placement_id);
	const Atom target_id = ai::string_or_empty(state, guard, key::target_id);
	// An explicit placement scopes this guard to one instance.
	if (target_placement_id != key::empty) {
		return target_placement_id == node_placement_id;
	}
	if (target_id != key::empty && (target_id == node_placement_id || target_id == site_id)) {
		return true;
	}
	return false;
}

DictRef _find_resource_node_by_guard(State &state, DictRef guard, DictRef session) {
	const Atom target_placement_id = gd::strip_edges(state, ai::string_or_empty(state, guard, key::target_placement_id));
	if (target_placement_id != key::empty) {
		return _find_resource_node_by_placement(state, session, target_placement_id);
	}
	const Atom target_id = gd::strip_edges(state, ai::string_or_empty(state, guard, key::target_id));
	if (target_id == key::empty) {
		return no_node(state);
	}
	const Value nodes = field_or_new_array(state, session_view::overworld(state, session), key::resource_nodes);
	const int64_t count = ai::vsize(state, nodes);
	for (int64_t index = 0; index < count; ++index) {
		const Value node = ai::vindex(state, nodes, int_value(index));
		if (!gd::is_dict(node)) {
			continue;
		}
		if (ai::string_or_empty(state, node.ref, key::placement_id) == target_id || ai::string_or_empty(state, node.ref, key::site_id) == target_id) {
			return node_result(state, index, node);
		}
	}
	return no_node(state);
}

DictRef collect_active_artifact(State &state, DictRef session) {
	normalize_overworld_state_for_runtime(state, session);
	const DictRef found = _find_active_artifact_node(state, session);
	if (gd::int_field(state, found, key::index, -1) < 0) {
		return refusal(state, key::no_artifact_cache_is_here);
	}
	return _collect_artifact_node_result(state, session, found, true);
}

DictRef _collect_artifact_node_result(State &state, DictRef session, DictRef node_result, bool refresh_fog_after_action) {
	const int64_t collect_started_usec = _rules_profile_timer(state);
	_rules_profile_count(state, key::artifact_collect_count);
	Value node;
	if (!state.lookup(node_result, str(key::node), node)) {
		node = dict_value(state.new_dict());
	}
	if (gd::to_bool(ai::vget(state, node, key::collected, bool_value(false)))) {
		_rules_profile_add_ms(state, key::artifact_collect_total_ms, collect_started_usec);
		return refusal(state, key::this_cache_has_already_been_claimed);
	}
	// node.get() above answered, so node is a Dictionary.
	const DictRef node_dict = node.ref;

	const DictRef pickup_result = _apply_artifact_claim(state, session, ai::string_or_empty(state, node_dict, key::artifact_id), key::Recovered, true);
	if (!gd::bool_field(state, pickup_result, key::ok, false)) {
		_rules_profile_add_ms(state, key::artifact_collect_total_ms, collect_started_usec);
		return refusal(state, gd::stringify(state, state.get(pickup_result, str(key::message), str(key::artifact_recovery_failed))));
	}

	const DictRef overworld = session_view::overworld(state, session);
	const Value nodes = field_or_new_array(state, overworld, key::artifact_nodes);
	state.set(node_dict, str(key::collected), bool_value(true));
	state.set(node_dict, str(key::collected_by_faction_id), str(key::player));
	state.erase(node_dict, str(key::collected_by_player_id));
	state.set(node_dict, str(key::collected_day), gd::index(state, session, str(key::day)));
	set_untyped_index(state, nodes, gd::int_field(state, node_result, key::index, -1), node);
	state.set(overworld, str(key::artifact_nodes), nodes);
	_profile_blocked_index_not_applicable(state, session, key::artifact_collection_does_not_use_blocked_index);

	const DictRef mutation_facts = _artifact_interaction_event_facts(state, node_dict);
	const Atom message = gd::stringify(state, state.get(pickup_result, str(key::message), str(key::recovered_artifact)));
	const DictRef result = _finalize_action_result(state, session, true, message, refresh_fog_after_action, false, mutation_facts);
	if (!refresh_fog_after_action) {
		state.set(result, str(key::descriptor_route_fog_reused), bool_value(true));
	}
	const DictRef topology_facts = state.new_dict();
	state.set(topology_facts, str(key::contract_known), bool_value(true));
	state.set(topology_facts, str(key::blocks_changed), bool_value(false));
	state.set(topology_facts, str(key::body_tiles_changed), bool_value(false));
	state.set(result, str(key::interaction_result), dict_value(_interactable_result_payload(state, key::artifact, node_dict, mutation_facts, topology_facts)));
	const DictRef context = state.new_dict();
	state.set(context, str(key::placement_id), str(ai::string_or_empty(state, node_dict, key::placement_id)));
	state.set(context, str(key::artifact_id), str(ai::string_or_empty(state, node_dict, key::artifact_id)));
	state.set(context, str(key::x), int_value(gd::int_field(state, node_dict, key::x, 0)));
	state.set(context, str(key::y), int_value(gd::int_field(state, node_dict, key::y, 0)));
	state.set(context, str(key::mutation_facts), dict_value(mutation_facts));
	const DictRef recapped = _attach_post_action_recap(state, result, session, key::artifact, context);
	_rules_profile_add_ms(state, key::artifact_collect_total_ms, collect_started_usec);
	return recapped;
}

DictRef _find_active_artifact_node(State &state, DictRef session) {
	return node_at_hero_tile(state, session, key::artifact_nodes, key::artifact_by_tile, true);
}

DictRef _find_artifact_node_by_descriptor(State &state, DictRef session, DictRef descriptor) {
	const int64_t lookup_started_usec = _rules_profile_timer(state);
	const Atom artifact_id = ai::string_or_empty(state, descriptor, key::artifact_id);
	const Atom placement_id = ai::string_or_empty(state, descriptor, key::placement_id);
	const int64_t x = gd::int_field(state, descriptor, key::x, -999);
	const int64_t y = gd::int_field(state, descriptor, key::y, -999);
	const Value nodes = field_or_new_array(state, session_view::overworld(state, session), key::artifact_nodes);
	_rules_profile_set(state, key::descriptor, key::lookup_collection_size, int_value(gd::is_array(nodes) ? state.array_size(nodes.ref) : 0));
	if (placement_id != key::empty) {
		const DictRef lookup_index = _spatial_lookup_index(state, session, -1);
		// var by_placement: Dictionary = lookup_index.get("artifact_by_placement", {}), {} unless a Dictionary.
		Value by_placement;
		if (state.lookup(lookup_index, str(key::artifact_by_placement), by_placement) && gd::is_dict(by_placement)
				&& state.has(by_placement.ref, str(placement_id))) {
			const int64_t indexed = gd::to_int(state, state.get(by_placement.ref, str(placement_id), int_value(-1)));
			if (gd::is_array(nodes) && indexed >= 0 && indexed < state.array_size(nodes.ref)) {
				const Value indexed_node = state.at(nodes.ref, indexed);
				if (gd::is_dict(indexed_node) && overworld_level_rules::on_level(state, indexed_node, hero_level(state, session))
						&& ai::string_or_empty(state, indexed_node.ref, key::placement_id) == placement_id
						&& !gd::bool_field(state, indexed_node.ref, key::collected, false)) {
					_rules_profile_set(state, key::descriptor, key::lookup_mode, str(key::placement_index));
					_rules_profile_add_ms(state, key::descriptor_lookup_ms, lookup_started_usec);
					return node_result(state, indexed, indexed_node);
				}
			}
		}
	}
	_rules_profile_set(state, key::descriptor, key::lookup_mode, str(key::full_scan_fallback));
	const int64_t count = ai::vsize(state, nodes);
	for (int64_t index = 0; index < count; ++index) {
		const Value node = ai::vindex(state, nodes, int_value(index));
		if (!gd::is_dict(node) || !overworld_level_rules::on_level(state, node, hero_level(state, session))) {
			continue;
		}
		if (gd::bool_field(state, node.ref, key::collected, false)) {
			continue;
		}
		if (artifact_id != key::empty && ai::string_or_empty(state, node.ref, key::artifact_id) != artifact_id) {
			continue;
		}
		if (gd::int_field(state, node.ref, key::x, -1) == x && gd::int_field(state, node.ref, key::y, -1) == y) {
			_rules_profile_add_ms(state, key::descriptor_lookup_ms, lookup_started_usec);
			return node_result(state, index, node);
		}
	}
	_rules_profile_add_ms(state, key::descriptor_lookup_ms, lookup_started_usec);
	return no_node(state);
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
