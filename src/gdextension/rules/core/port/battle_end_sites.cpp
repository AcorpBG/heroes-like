// The overworld sites the battle ends change (Phase 5 slice 09): dwelling
// guards and resource-site defenders after a battle, reserve convoys caught in
// one, battle rewards and artifacts claimed by the active hero.
//
// OverworldRules._collect_resource_node_result (a site's visit) is not ported:
// it is a GDScript host target (registry.cpp), called from one place here, for a
// dwelling flagged after its guards are beaten and a field site retaken after
// its defenders are beaten.

#include "aurelion_rules/port/battle_ends.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/difficulty_rules.hpp"
#include "aurelion_rules/port/difficulty_rules_ai.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/resource_node_payload_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <cstdint>
#include <string>
#include <vector>

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

// String(d.get(field, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// d.get(field, {}): the field as it is, or a new Dictionary when it is missing.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}

// d.get(field, []): the field as it is, or a new Array when it is missing.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

// x[index] = value of an untyped container: an Array's item or a Dictionary's
// int key.
void set_index(State &state, const Value &container, int64_t index, const Value &value) {
	if (gd::is_array(container)) {
		state.set_at(container.ref, index, value);
		return;
	}
	if (gd::is_dict(container)) {
		state.set(container.ref, int_value(index), value);
		return;
	}
	throw state::ScriptError(std::string("Invalid assignment of index on a base object of type '") + gd::type_name(container) + "'.");
}

// session.overworld["resource_nodes"] = nodes after nodes[index] = node.
void store_resource_node(State &state, DictRef session, const Value &nodes, int64_t index, DictRef node) {
	set_index(state, nodes, index, dict_value(node));
	state.set(session_view::overworld(state, session), str(key::resource_nodes), nodes);
}

// {"index": index, "node": node}.
DictRef node_result(State &state, int64_t index, const Value &node) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::index), int_value(index));
	state.set(result, str(key::node), node);
	return result;
}

// {"ok": false, "message": ""}.
DictRef not_captured(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), gd::bool_value(false));
	state.set(result, str(key::message), str(key::empty));
	return result;
}

// String(d.get(field, {}).get(name, fallback)) if d.get(field, {}) is Dictionary
// else fallback: a missing field reads as {}, which gives the fallback too.
Atom nested_text(State &state, DictRef dict, Atom field, Atom name, Atom fallback) {
	Value inner;
	if (state.lookup(dict, str(field), inner) && gd::is_dict(inner)) {
		return text(state, inner.ref, name, fallback);
	}
	return fallback;
}

// ", ".join(parts) of Strings.
Atom join_comma(State &state, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t at = 0; at < parts.size(); ++at) {
		if (at > 0) {
			joined += ", ";
		}
		joined += state.text(parts[at]);
	}
	return state.intern(joined);
}

// clamp(x, lo, hi) of ints (the untyped utility): lo when x < lo, then hi when
// that value > hi.
int64_t clamp_untyped(int64_t value, int64_t lo, int64_t hi) {
	if (value < lo) {
		value = lo;
	}
	if (value > hi) {
		value = hi;
	}
	return value;
}

// _collect_resource_node_result(session, node_result, refresh_fog_after_action):
// the host target's one call site. It takes the session object, not its view,
// and every argument (native_transit_cost = 1, reward_choice_id = "").
DictRef collect_resource_node_result(State &state, DictRef session, DictRef node_result, bool refresh_fog_after_action) {
	return gd::as_dict(gd::call_static(state, key::overworld_rules_script, key::_collect_resource_node_result,
			{gd::view_object(state, session), dict_value(node_result), gd::bool_value(refresh_fog_after_action), int_value(1), str(key::empty)}));
}

} // namespace

// CreatureDwellingRules.

namespace creature_dwelling_rules {

Atom placement_from_guard_key(State &state, Atom guard_key) {
	// GUARD_KEY_PREFIX ("dwelling_guard:") is ASCII: its length in characters is
	// its length in bytes.
	if (!gd::begins_with(state, guard_key, key::dwelling_guard_3)) {
		return key::empty;
	}
	const std::string rest = state.text(guard_key).substr(state.text(key::dwelling_guard_3).size());
	return state.intern(rest);
}

} // namespace creature_dwelling_rules

// DifficultyRules.

namespace difficulty_rules {

DictRef scale_reward_resources(State &state, DictRef session, const Value &payload) {
	const double multiplier = gd::float_field(state, profile_for_session(state, dict_value(session)), key::reward_multiplier, 1.0);
	return scale_resource_payload(state, payload, multiplier);
}

} // namespace difficulty_rules

// OverworldRules. A session is its view: GDScript's session == null cannot happen.

namespace overworld_rules {

Atom update_dwelling_guard_after_battle(State &state, DictRef session, Atom placement_id, ArrayRef survivor_stacks, bool won) {
	const DictRef found = _find_resource_node_by_placement(state, session, placement_id);
	const int64_t index = gd::int_field(state, found, key::index, -1);
	if (index < 0) {
		return key::empty;
	}
	const DictRef node = gd::as_dict(field_or_new_dict(state, found, key::node));
	const DictRef site = resource_node_payload_rules::site_for_node(state, node, state.new_dict());
	creature_dwelling_rules::record_guard_result(state, node, key::player, survivor_stacks, won || state.array_size(survivor_stacks) == 0, ai::session_int(state, session, key::day));
	const ArrayRef nodes = gd::as_array(field_or_new_array(state, session_view::overworld(state, session), key::resource_nodes));
	state.set_at(nodes, index, dict_value(node));
	state.set(session_view::overworld(state, session), str(key::resource_nodes), array_value(nodes));
	if (won || state.array_size(survivor_stacks) == 0) {
		return key::empty;
	}
	const Atom recruits = _describe_recruit_delta(state, dict_value(_stacks_to_recruits(state, survivor_stacks)));
	const Atom site_name = text(state, site, key::name, key::the_dwelling);
	return gd::format(state, key::s_guards_still_hold_s, {str(recruits), str(site_name)});
}

Atom capture_dwelling_after_guard_victory(State &state, DictRef session, Atom placement_id) {
	const DictRef found = _find_resource_node_by_placement(state, session, placement_id);
	if (gd::int_field(state, found, key::index, -1) < 0) {
		return key::empty;
	}
	const DictRef node = gd::as_dict(field_or_new_dict(state, found, key::node));
	const DictRef site = resource_node_payload_rules::site_for_node(state, node, state.new_dict());
	creature_dwelling_rules::record_guard_result(state, node, key::player, state.new_array(), true, ai::session_int(state, session, key::day));
	const ArrayRef nodes = gd::as_array(field_or_new_array(state, session_view::overworld(state, session), key::resource_nodes));
	state.set_at(nodes, gd::int_field(state, found, key::index, -1), dict_value(node));
	state.set(session_view::overworld(state, session), str(key::resource_nodes), array_value(nodes));
	const Atom site_name = text(state, site, key::name, key::the_dwelling);
	if (player_identity_rules::resource_controller_id(state, node) == key::player) {
		return gd::format(state, key::the_guards_of_s_are_beaten, {str(site_name)});
	}
	const DictRef claimed = collect_resource_node_result(state, session, _find_resource_node_by_placement(state, session, placement_id), false);
	if (gd::bool_field(state, claimed, key::ok, false)
			&& player_identity_rules::resource_controller_id(state, gd::as_dict(field_or_new_dict(state, _find_resource_node_by_placement(state, session, placement_id), key::node))) == key::player) {
		return gd::format(state, key::the_guards_of_s_are_beaten_2, {str(site_name)});
	}
	return gd::format(state, key::the_guards_of_s_are_beaten, {str(site_name)});
}

DictRef _stacks_to_recruits(State &state, ArrayRef stacks) {
	const DictRef recruits = state.new_dict();
	for (const Value &stack : gd::items(state, array_value(stacks))) {
		if (!gd::is_dict(stack)) {
			continue;
		}
		const Atom unit_id = text(state, stack.ref, key::unit_id, key::empty);
		const int64_t held = gd::int_field(state, recruits, unit_id, 0);
		const int64_t count = gd::int_field(state, stack.ref, key::count, 0);
		state.set(recruits, str(unit_id), int_value(gd::add(held, count)));
	}
	return recruits;
}

DictRef _find_resource_node_by_placement(State &state, DictRef session, Atom placement_id) {
	if (placement_id == key::empty) {
		return node_result(state, -1, dict_value(state.new_dict()));
	}
	const int64_t lookup_started_usec = _rules_profile_timer(state);
	const Value nodes = field_or_new_array(state, session_view::overworld(state, session), key::resource_nodes);
	_rules_profile_set(state, key::descriptor, key::lookup_collection_size, int_value(gd::is_array(nodes) ? state.array_size(nodes.ref) : 0));
	const DictRef lookup_index = _spatial_lookup_index(state, session, -1);
	// var by_placement: Dictionary = lookup_index.get("resource_by_placement", {}), {} unless a Dictionary.
	Value by_placement;
	if (state.lookup(lookup_index, str(key::resource_by_placement), by_placement) && gd::is_dict(by_placement) &&
			state.has(by_placement.ref, str(placement_id))) {
		const int64_t indexed = gd::to_int(state, state.get(by_placement.ref, str(placement_id), int_value(-1)));
		if (gd::is_array(nodes) && indexed >= 0 && indexed < state.array_size(nodes.ref)) {
			const Value indexed_node = state.at(nodes.ref, indexed);
			if (gd::is_dict(indexed_node) && text(state, indexed_node.ref, key::placement_id, key::empty) == placement_id) {
				_rules_profile_set(state, key::descriptor, key::lookup_mode, str(key::placement_index));
				_rules_profile_add_ms(state, key::descriptor_lookup_ms, lookup_started_usec);
				return node_result(state, indexed, indexed_node);
			}
		}
	}
	_rules_profile_set(state, key::descriptor, key::lookup_mode, str(key::full_scan_fallback));
	// for index in range(nodes.size()): nodes[index]
	const int64_t count = ai::vsize(state, nodes);
	for (int64_t index = 0; index < count; ++index) {
		const Value node = ai::vindex(state, nodes, int_value(index));
		if (gd::is_dict(node) && text(state, node.ref, key::placement_id, key::empty) == placement_id) {
			_rules_profile_add_ms(state, key::descriptor_lookup_ms, lookup_started_usec);
			return node_result(state, index, node);
		}
	}
	_rules_profile_add_ms(state, key::descriptor_lookup_ms, lookup_started_usec);
	return node_result(state, -1, dict_value(state.new_dict()));
}

DictRef capture_resource_after_defender_victory(State &state, DictRef session, Atom placement_id) {
	if (placement_id == key::empty) {
		return not_captured(state);
	}
	const DictRef found = _find_resource_node_by_placement(state, session, placement_id);
	if (gd::int_field(state, found, key::index, -1) < 0) {
		return not_captured(state);
	}
	DictRef node = gd::as_dict(field_or_new_dict(state, found, key::node));
	const DictRef site = resource_node_payload_rules::site_for_node(state, node, state.new_dict());
	if (gd::is_empty(state, site) || !_resource_site_is_persistent(state, site)) {
		return not_captured(state);
	}
	const Value nodes = field_or_new_array(state, session_view::overworld(state, session), key::resource_nodes);
	node = _clear_resource_ai_defender_metadata(state, node);
	store_resource_node(state, session, nodes, gd::int_field(state, found, key::index, -1), node);
	const DictRef refreshed = _find_resource_node_by_placement(state, session, placement_id);
	return collect_resource_node_result(state, session, refreshed, true);
}

Atom update_resource_defender_after_battle(State &state, DictRef session, Atom placement_id, Atom faction_id, DictRef commander_state, ArrayRef survivor_stacks, bool resolved) {
	if (placement_id == key::empty) {
		return key::empty;
	}
	const DictRef found = _find_resource_node_by_placement(state, session, placement_id);
	if (gd::int_field(state, found, key::index, -1) < 0) {
		return key::empty;
	}
	const Value nodes = field_or_new_array(state, session_view::overworld(state, session), key::resource_nodes);
	DictRef node = gd::as_dict(field_or_new_dict(state, found, key::node));
	const DictRef site = gd::content_row(state, ContentTable::ResourceSite, text(state, node, key::site_id, key::empty));
	if (resolved || text(state, node, key::collected_by_faction_id, key::empty) == key::player || state.array_size(survivor_stacks) == 0) {
		node = _clear_resource_ai_defender_metadata(state, node);
		store_resource_node(state, session, nodes, gd::int_field(state, found, key::index, -1), node);
		return key::empty;
	}
	const Atom army_id = nested_text(state, node, key::ai_defender_army, key::id, key::resource_defense_host);
	const Atom army_name = nested_text(state, node, key::ai_defender_army, key::name, key::resource_defense_host_2);
	const DictRef defender_army = state.new_dict();
	state.set(defender_army, str(key::id), str(army_id));
	state.set(defender_army, str(key::name), str(army_name));
	state.set(defender_army, str(key::stacks), array_value(gd::deep_duplicate_array(state, survivor_stacks)));
	const int64_t defender_strength = _army_strength_value(state, array_value(survivor_stacks));
	state.set(node, str(key::ai_defender_army), dict_value(defender_army));
	state.set(node, str(key::ai_defense_rating), int_value(defender_strength));
	const int64_t reinforced = gd::int_field(state, node, key::ai_defense_reinforced_strength, 0);
	state.set(node, str(key::ai_defense_reinforced_strength), int_value(compat::engine_max<int64_t>(reinforced, defender_strength)));
	if (!gd::is_empty(state, commander_state)) {
		state.set(node, str(key::ai_defender_commander_state), dict_value(gd::deep_duplicate_dict(state, commander_state)));
		state.set(node, str(key::ai_defender_roster_hero_id), str(text(state, commander_state, key::roster_hero_id, key::empty)));
	}
	if (text(state, node, key::ai_defended_by_faction_id, key::empty) == key::empty && faction_id != key::empty) {
		state.set(node, str(key::ai_defended_by_faction_id), str(player_identity_rules::faction_id(state, session, faction_id)));
		if (!gd::is_empty(state, player_identity_rules::player(state, session, faction_id))) {
			state.set(node, str(key::ai_defended_by_player_id), str(faction_id));
		}
	}
	store_resource_node(state, session, nodes, gd::int_field(state, found, key::index, -1), node);
	const Atom site_name = text(state, site, key::name, key::the_field_site);
	const Atom holder = faction_id != key::empty ? text(state, gd::content_row(state, ContentTable::Faction, faction_id), key::name, faction_id) : key::the_stationed_force;
	return gd::format(state, key::s_remains_defended_by_s, {str(site_name), str(holder)});
}

DictRef _clear_resource_ai_defender_metadata(State &state, DictRef node) {
	const DictRef cleared = gd::deep_duplicate_dict(state, node);
	state.erase(cleared, str(key::ai_defender_commander_state));
	state.erase(cleared, str(key::ai_defender_roster_hero_id));
	state.erase(cleared, str(key::ai_defender_army));
	state.erase(cleared, str(key::ai_defended_by_faction_id));
	state.erase(cleared, str(key::ai_defended_by_player_id));
	state.erase(cleared, str(key::ai_defended_day));
	state.erase(cleared, str(key::ai_defense_until_day));
	state.erase(cleared, str(key::ai_defense_rating));
	state.erase(cleared, str(key::ai_defense_reinforced_strength));
	// var front: Dictionary = cleared.get("front", {}) if a Dictionary else {}: a
	// missing or other front reads as {}, which erases nothing.
	Value front;
	if (state.lookup(cleared, str(key::front), front) && gd::is_dict(front)) {
		bool erase_front = text(state, front.ref, key::source, key::empty) == key::strategic_ai_resource_defense;
		if (!erase_front) {
			const Atom front_state = text(state, front.ref, key::state, key::empty);
			erase_front = front_state == key::defend || front_state == key::stabilizing;
		}
		if (erase_front) {
			state.erase(cleared, str(key::front));
		}
	}
	return cleared;
}

Atom _resolve_player_reserve_delivery(State &state, DictRef session, DictRef site, DictRef delivery_state, DictRef node) {
	const DictRef manifest = _normalize_recruit_payload(state, field_or_new_dict(state, delivery_state, key::manifest));
	if (gd::is_empty(state, manifest)) {
		return key::empty;
	}
	const Atom site_name = text(state, site, key::name, key::the_route);
	const Atom target_kind = text(state, delivery_state, key::target_kind, key::empty);
	const Atom target_id = text(state, delivery_state, key::target_id, key::empty);
	const Atom target_label = text(state, delivery_state, key::target_label, key::the_front);
	const Atom recruit_summary = text(state, delivery_state, key::recruit_summary, key::empty);
	bool delivered = false;
	if (target_kind == key::hero) {
		delivered = _deliver_reinforcements_to_hero(state, session, target_id, manifest);
	} else if (target_kind == key::town) {
		delivered = _deliver_reinforcements_to_town(state, session, target_id, manifest);
	}
	if (delivered) {
		_record_successful_reserve_delivery(state, node, delivery_state, ai::session_int(state, session, key::day));
		return gd::format(state, key::s_convoy_reaches_s_s, {str(site_name), str(target_label), str(recruit_summary)});
	}
	const Atom returned_to = _return_reinforcements_to_source(state, session, text(state, delivery_state, key::origin_town_id, key::empty), manifest);
	if (returned_to != key::empty) {
		return gd::format(state, key::s_convoy_turns_back_to_s, {str(site_name), str(returned_to), str(target_label), str(recruit_summary)});
	}
	return gd::format(state, key::s_convoy_for_s_is_lost, {str(site_name), str(target_label), str(recruit_summary)});
}

void _record_successful_reserve_delivery(State &state, DictRef node, DictRef delivery_state, int64_t delivery_day) {
	if (gd::is_empty(state, node) || gd::is_empty(state, delivery_state)) {
		return;
	}
	const Atom target_kind = gd::strip_edges(state, text(state, delivery_state, key::target_kind, key::empty));
	const Atom target_id = gd::strip_edges(state, text(state, delivery_state, key::target_id, key::empty));
	if (target_kind == key::empty || target_id == key::empty) {
		return;
	}
	const Atom receipt_key = gd::format(state, key::s_s_6, {str(target_kind), str(target_id)});
	const DictRef completion_counts = _normalize_delivery_completion_counts(state, field_or_new_dict(state, node, key::delivery_completion_counts));
	const int64_t completed = compat::engine_max<int64_t>(0, gd::int_field(state, completion_counts, receipt_key, 0));
	state.set(completion_counts, str(receipt_key), int_value(gd::add(completed, 1)));
	state.set(node, str(key::delivery_completion_counts), dict_value(completion_counts));
	state.set(node, str(key::last_delivery_target_kind), str(target_kind));
	state.set(node, str(key::last_delivery_target_id), str(target_id));
	state.set(node, str(key::last_delivery_day), int_value(compat::engine_max<int64_t>(0, delivery_day)));
	state.set(node, str(key::last_delivery_manifest), dict_value(_normalize_recruit_payload(state, field_or_new_dict(state, delivery_state, key::manifest))));
}

DictRef apply_delivery_interception_outcome(State &state, DictRef session, Atom node_placement_id, Atom outcome) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::summary), str(key::empty));
	if (node_placement_id == key::empty) {
		return result;
	}
	const DictRef found = _find_resource_node_by_placement(state, session, node_placement_id);
	if (gd::int_field(state, found, key::index, -1) < 0) {
		return result;
	}
	DictRef node = gd::as_dict(field_or_new_dict(state, found, key::node));
	const DictRef site = gd::content_row(state, ContentTable::ResourceSite, text(state, node, key::site_id, key::empty));
	const DictRef delivery_state = _resource_site_delivery_state(state, session, node, site);
	if (!gd::bool_field(state, delivery_state, key::active, false) || text(state, delivery_state, key::controller_id, key::empty) != key::player) {
		return result;
	}
	const Value nodes = field_or_new_array(state, session_view::overworld(state, session), key::resource_nodes);
	if (outcome == key::victory) {
		if (ai::session_int(state, session, key::day) < gd::int_field(state, delivery_state, key::arrival_day, 0)) {
			const Atom site_name = text(state, site, key::name, key::the_route);
			const Atom recruit_summary = text(state, delivery_state, key::recruit_summary, key::the_convoy);
			const Atom target_label = text(state, delivery_state, key::target_label, key::the_front);
			state.set(result, str(key::summary), str(gd::format(state, key::s_route_holds_s_keeps_marching, {str(site_name), str(recruit_summary), str(target_label)})));
			return result;
		}
		const Atom delivery_message = _resolve_player_reserve_delivery(state, session, site, delivery_state, node);
		node = _clear_resource_site_delivery(state, node);
		store_resource_node(state, session, nodes, gd::int_field(state, found, key::index, -1), node);
		state.set(result, str(key::summary), str(delivery_message));
		return result;
	}
	if (outcome == key::stalemate) {
		node = _clear_resource_site_delivery(state, node);
		store_resource_node(state, session, nodes, gd::int_field(state, found, key::index, -1), node);
		const Atom origin_town_id = text(state, delivery_state, key::origin_town_id, key::empty);
		const DictRef manifest = _normalize_recruit_payload(state, field_or_new_dict(state, delivery_state, key::manifest));
		const Atom returned_to = _return_reinforcements_to_source(state, session, origin_town_id, manifest);
		const Atom site_name = text(state, site, key::name, key::the_route);
		if (returned_to != key::empty) {
			const Atom recruit_summary = text(state, delivery_state, key::recruit_summary, key::empty);
			state.set(result, str(key::summary), str(gd::format(state, key::s_convoy_turns_back_to_s_2, {str(site_name), str(returned_to), str(recruit_summary)})));
		} else {
			const Atom target_label = text(state, delivery_state, key::target_label, key::the_front);
			const Atom recruit_summary = text(state, delivery_state, key::recruit_summary, key::empty);
			state.set(result, str(key::summary), str(gd::format(state, key::s_convoy_breaks_off_from_s, {str(site_name), str(target_label), str(recruit_summary)})));
		}
		return result;
	}
	if (outcome == key::retreat) {
		node = _clear_resource_site_delivery(state, node);
		store_resource_node(state, session, nodes, gd::int_field(state, found, key::index, -1), node);
		const DictRef partition = _split_recruit_payload(state, _normalize_recruit_payload(state, field_or_new_dict(state, delivery_state, key::manifest)), 0.45);
		const DictRef returned_manifest = gd::as_dict(field_or_new_dict(state, partition, key::returned));
		const DictRef lost_manifest = gd::as_dict(field_or_new_dict(state, partition, key::lost));
		const Atom returned_to = _return_reinforcements_to_source(state, session, text(state, delivery_state, key::origin_town_id, key::empty), returned_manifest);
		const Atom returned_summary = _describe_recruit_delta(state, dict_value(returned_manifest));
		const Atom lost_summary = _describe_recruit_delta(state, dict_value(lost_manifest));
		const Atom site_name = text(state, site, key::name, key::the_route);
		if (returned_to != key::empty && returned_summary != key::empty && lost_summary != key::empty) {
			const Atom target_label = text(state, delivery_state, key::target_label, key::the_front);
			state.set(result, str(key::summary),
					str(gd::format(state, key::s_convoy_scatters_under_pursuit_s, {str(site_name), str(returned_to), str(returned_summary), str(lost_summary), str(target_label)})));
		} else if (returned_to != key::empty && returned_summary != key::empty) {
			state.set(result, str(key::summary), str(gd::format(state, key::s_convoy_breaks_contact_and_turns, {str(site_name), str(returned_summary), str(returned_to)})));
		} else {
			const Atom recruit_summary = text(state, delivery_state, key::recruit_summary, key::empty);
			state.set(result, str(key::summary), str(gd::format(state, key::s_convoy_is_cut_apart_during, {str(site_name), str(recruit_summary)})));
		}
		return result;
	}
	if (outcome == key::surrender) {
		node = _clear_resource_site_delivery(state, node);
		store_resource_node(state, session, nodes, gd::int_field(state, found, key::index, -1), node);
		const Atom site_name = text(state, site, key::name, key::the_route);
		const Atom target_label = text(state, delivery_state, key::target_label, key::the_front);
		const Atom recruit_summary = text(state, delivery_state, key::recruit_summary, key::empty);
		state.set(result, str(key::summary), str(gd::format(state, key::s_convoy_for_s_is_handed, {str(site_name), str(target_label), str(recruit_summary)})));
		return result;
	}
	node = _clear_resource_site_delivery(state, node);
	store_resource_node(state, session, nodes, gd::int_field(state, found, key::index, -1), node);
	const Atom collapse_label = (outcome == key::hero_defeat || outcome == key::defeat || outcome == key::town_lost) ? key::is_overrun_in_the_rout : key::is_intercepted;
	const Atom site_name = text(state, site, key::name, key::the_route);
	const Atom target_label = text(state, delivery_state, key::target_label, key::the_front);
	const Atom recruit_summary = text(state, delivery_state, key::recruit_summary, key::empty);
	state.set(result, str(key::summary), str(gd::format(state, key::s_convoy_for_s_s_s, {str(site_name), str(target_label), str(collapse_label), str(recruit_summary)})));
	return result;
}

bool _deliver_reinforcements_to_hero(State &state, DictRef session, Atom hero_id, DictRef manifest) {
	if (hero_id == key::empty) {
		return false;
	}
	const Value heroes = field_or_new_array(state, session_view::overworld(state, session), key::player_heroes);
	// for index in range(heroes.size()): heroes[index]
	const int64_t count = ai::vsize(state, heroes);
	for (int64_t index = 0; index < count; ++index) {
		const Value hero = ai::vindex(state, heroes, int_value(index));
		if (!gd::is_dict(hero) || text(state, hero.ref, key::id, key::empty) != hero_id) {
			continue;
		}
		// var army: Dictionary = hero.get("army", {}).duplicate(true)
		const DictRef army = gd::as_dict(gd::duplicate_value(state, field_or_new_dict(state, hero.ref, key::army), true));
		const DictRef admission = hero_command_rules::army_addition_plan(state, field_or_new_array(state, army, key::stacks), manifest);
		if (!gd::bool_field(state, admission, key::ok, false)) {
			return false;
		}
		state.set(army, str(key::stacks), field_or_new_array(state, admission, key::stacks));
		state.set(hero.ref, str(key::army), dict_value(army));
		set_index(state, heroes, index, hero);
		state.set(session_view::overworld(state, session), str(key::player_heroes), heroes);
		if (text(state, session_view::overworld(state, session), key::active_hero_id, key::empty) == hero_id) {
			hero_command_rules::_sync_active_hero_mirror(state, session);
		}
		return true;
	}
	return false;
}

bool _deliver_reinforcements_to_town(State &state, DictRef session, Atom town_placement_id, DictRef manifest) {
	if (town_placement_id == key::empty) {
		return false;
	}
	const DictRef town_result = _find_town_by_placement(state, session, town_placement_id);
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return false;
	}
	// var town = town_result.get("town", {}): a found town is a Dictionary.
	const DictRef town = gd::as_dict(field_or_new_dict(state, town_result, key::town));
	if (text(state, town, key::owner, key::neutral) != key::player) {
		return false;
	}
	const Value garrison = field_or_new_array(state, town, key::garrison);
	const DictRef admission = hero_command_rules::army_addition_plan(state, garrison, manifest);
	if (!gd::bool_field(state, admission, key::ok, false)) {
		return false;
	}
	state.set(town, str(key::garrison), field_or_new_array(state, admission, key::stacks));
	const Value towns = field_or_new_array(state, session_view::overworld(state, session), key::towns);
	set_index(state, towns, gd::int_field(state, town_result, key::index, -1), dict_value(town));
	state.set(session_view::overworld(state, session), str(key::towns), towns);
	return true;
}

Atom _return_reinforcements_to_source(State &state, DictRef session, Atom source_town_id, DictRef manifest) {
	if (source_town_id == key::empty) {
		return key::empty;
	}
	const DictRef town_result = _find_town_by_placement(state, session, source_town_id);
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return key::empty;
	}
	// var town = town_result.get("town", {}): a found town is a Dictionary.
	const DictRef town = gd::as_dict(field_or_new_dict(state, town_result, key::town));
	if (text(state, town, key::owner, key::neutral) != key::player) {
		return key::empty;
	}
	const DictRef recruits = _add_recruit_growth(state, field_or_new_dict(state, town, key::available_recruits), dict_value(manifest));
	state.set(town, str(key::available_recruits), dict_value(recruits));
	const Value towns = field_or_new_array(state, session_view::overworld(state, session), key::towns);
	set_index(state, towns, gd::int_field(state, town_result, key::index, -1), dict_value(town));
	state.set(session_view::overworld(state, session), str(key::towns), towns);
	return _town_name(state, town);
}

DictRef _split_recruit_payload(State &state, DictRef manifest, double return_ratio) {
	const DictRef normalized = _normalize_recruit_payload(state, dict_value(manifest));
	const DictRef result = state.new_dict();
	state.set(result, str(key::returned), dict_value(state.new_dict()));
	state.set(result, str(key::lost), dict_value(state.new_dict()));
	if (gd::is_empty(state, normalized)) {
		return result;
	}
	int64_t total_units = 0;
	for (const Value &unit_id_value : gd::items(state, dict_value(normalized))) {
		const int64_t units = gd::to_int(state, state.get(normalized, unit_id_value, int_value(0)));
		total_units = gd::add(total_units, compat::engine_max<int64_t>(0, units));
	}
	int64_t target_returned = compat::float_to_int(compat::godot_floor(static_cast<double>(total_units) * compat::engine_clamp<double>(return_ratio, 0.0, 1.0)));
	if (target_returned <= 0 && total_units >= 4 && return_ratio > 0.0) {
		target_returned = 1;
	}
	target_returned = compat::engine_clamp<int64_t>(target_returned, 0, compat::engine_max<int64_t>(0, gd::sub(total_units, 1)));
	const DictRef returned = state.new_dict();
	const DictRef lost = state.new_dict();
	int64_t remaining_to_return = target_returned;
	const ArrayRef unit_ids = gd::keys(state, normalized);
	// unit_ids.sort(): the keys are Strings (_normalize_recruit_payload).
	gd::sort_custom(state, unit_ids, [&state](const Value &a, const Value &b) {
		return gd::text(state, a) < gd::text(state, b);
	});
	for (const Value &unit_id_value : gd::items(state, array_value(unit_ids))) {
		const Atom unit_id = gd::stringify(state, unit_id_value);
		const int64_t available = compat::engine_max<int64_t>(0, gd::to_int(state, state.get(normalized, unit_id_value, int_value(0))));
		const int64_t returned_count = compat::engine_min<int64_t>(available, remaining_to_return);
		if (returned_count > 0) {
			state.set(returned, str(unit_id), int_value(returned_count));
		}
		const int64_t lost_count = compat::engine_max<int64_t>(0, gd::sub(available, returned_count));
		if (lost_count > 0) {
			state.set(lost, str(unit_id), int_value(lost_count));
		}
		remaining_to_return = compat::engine_max<int64_t>(0, gd::sub(remaining_to_return, returned_count));
	}
	state.set(result, str(key::returned), dict_value(returned));
	state.set(result, str(key::lost), dict_value(lost));
	return result;
}

int64_t _army_strength_value(State &state, const Value &stacks) {
	int64_t total_strength = 0;
	if (!gd::is_array(stacks)) {
		return total_strength;
	}
	for (const Value &stack : gd::items(state, stacks)) {
		if (!gd::is_dict(stack)) {
			continue;
		}
		const int64_t count = compat::engine_max<int64_t>(0, gd::int_field(state, stack.ref, key::count, 0));
		if (count <= 0) {
			continue;
		}
		const DictRef unit = gd::content_row(state, ContentTable::Unit, text(state, stack.ref, key::unit_id, key::empty));
		int64_t value = gd::int_field(state, unit, key::hp, 1);
		value = gd::add(value, gd::int_field(state, unit, key::min_damage, 1));
		value = gd::add(value, gd::int_field(state, unit, key::max_damage, 1));
		value = gd::add(value, gd::bool_field(state, unit, key::ranged, false) ? 3 : 0);
		total_strength = gd::add(total_strength, gd::mul(count, compat::engine_max<int64_t>(6, value)));
	}
	return total_strength;
}

int64_t _movement_max_from_hero(State &state, DictRef hero, const Value &session) {
	return hero_command_rules::movement_max_for_hero(state, hero, session);
}

void _spend_resources(State &state, DictRef session, const Value &cost) {
	const DictRef resources = _normalize_live_resource_stockpile(state, field_or_new_dict(state, session_view::overworld(state, session), key::resources));
	if (gd::is_dict(cost)) {
		// for key in cost.keys(): the loop writes only resources.
		for (const Value &cost_key : gd::items(state, cost)) {
			const Atom resource_key = gd::stringify(state, cost_key);
			const int64_t held = gd::int_field(state, resources, resource_key, 0);
			const int64_t spent = gd::to_int(state, gd::index(state, cost.ref, cost_key));
			state.set(resources, str(resource_key), int_value(compat::engine_max<int64_t>(0, gd::sub(held, spent))));
		}
	}
	state.set(session_view::overworld(state, session), str(key::resources), dict_value(resources));
}

DictRef apply_reward_bonus(State &state, const Value &rewards, int64_t pct) {
	const DictRef result = gd::is_dict(rewards) ? gd::deep_duplicate_dict(state, rewards.ref) : state.new_dict();
	if (pct <= 0) {
		return result;
	}
	// for key in result.keys(): a copy of the keys, while the loop rewrites values.
	const ArrayRef reward_keys = gd::keys(state, result);
	const int64_t count = state.array_size(reward_keys);
	for (int64_t at = 0; at < count; ++at) {
		const Value reward_key = state.at(reward_keys, at);
		const Value value = gd::index(state, result, reward_key);
		if (gd::stringify(state, reward_key) == key::experience || !(gd::is_int(value) || gd::is_float(value)) || gd::to_int(state, value) <= 0) {
			continue;
		}
		const int64_t amount = gd::to_int(state, value);
		state.set(result, reward_key, int_value(gd::add(amount, compat::int_div(gd::mul(amount, pct), 100))));
	}
	return result;
}

Atom _describe_reward_delta(State &state, const Value &delta) {
	if (!gd::is_dict(delta)) {
		return key::empty;
	}
	std::vector<Atom> parts;
	const Atom resource_summary = _describe_resource_delta(state, delta);
	if (resource_summary != key::empty) {
		parts.push_back(resource_summary);
	}
	const int64_t experience = gd::int_field(state, delta.ref, key::experience, 0);
	if (experience > 0) {
		parts.push_back(gd::format(state, key::d_xp, {int_value(experience)}));
	}
	for (const Value &delta_key : gd::items(state, delta)) {
		const Atom resource_key = gd::stringify(state, delta_key);
		if (resource_key == key::gold || resource_key == key::wood || resource_key == key::ore || resource_key == key::experience) {
			continue;
		}
		const int64_t amount = gd::to_int(state, state.get(delta.ref, delta_key, int_value(0)));
		if (amount > 0) {
			parts.push_back(gd::format(state, key::_d_s, {int_value(amount), str(resource_key)}));
		}
	}
	return join_comma(state, parts);
}

void _sync_movement_to_hero(State &state, DictRef session, int64_t previous_max) {
	Value movement_state = field_or_new_dict(state, session_view::overworld(state, session), key::movement);
	if (!gd::is_dict(movement_state)) {
		movement_state = dict_value(state.new_dict());
	}
	const DictRef hero = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero));
	const int64_t new_max = _movement_max_from_hero(state, hero, dict_value(session));
	int64_t current = gd::to_int(state, state.get(movement_state.ref, str(key::current), int_value(new_max)));
	current = clamp_untyped(gd::add(current, gd::sub(new_max, previous_max)), 0, new_max);
	state.set(movement_state.ref, str(key::current), int_value(current));
	state.set(movement_state.ref, str(key::max), int_value(new_max));
	state.set(session_view::overworld(state, session), str(key::movement), movement_state);
}

DictRef _apply_artifact_claim(State &state, DictRef session, Atom artifact_id, Atom source_verb, bool auto_equip) {
	normalize_overworld_state(state, session);
	const DictRef previous_hero = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero));
	const int64_t previous_max = _movement_max_from_hero(state, previous_hero, dict_value(session));
	const DictRef hero = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero));
	const DictRef result = artifact_rules::claim_artifact(state, hero, artifact_id, source_verb, auto_equip);
	if (!gd::bool_field(state, result, key::ok, false)) {
		return result;
	}
	const Value fallback = field_or_new_dict(state, session_view::overworld(state, session), key::hero);
	state.set(session_view::overworld(state, session), str(key::hero), state.get(result, str(key::hero), fallback));
	_sync_movement_to_hero(state, session, previous_max);
	return result;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
