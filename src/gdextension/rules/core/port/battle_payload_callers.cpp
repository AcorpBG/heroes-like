// The payloads of the battles the map starts other than at an encounter (Phase
// 2, slice 2b): a hero assaulting a computer player's town, a resource site a
// computer player defends, and the guard of a creature dwelling. Each builds
// the encounter placement and hands it to create_battle_payload.

#include "aurelion_rules/port/battle_payload.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"

#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_ai.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_turn.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"

#include <string>

namespace aurelion::rules::port::battle_rules {

using gd::array_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
namespace key = state::key;

namespace {

// d.get(key, {}) where the Dictionary is passed on: the stored one, or a new one.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// String(d.get(key, "")).
Atom string_of(State &state, DictRef dict, Atom field) {
	return gd::stringify(state, gd::field_or(state, dict, field, str(key::empty)));
}

// String(d.get(key, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return gd::stringify(state, gd::field_or(state, dict, field, fallback));
}

// hash("%s:%s:%d:<kind>:%s" % [session.scenario_id, session.launch_mode,
// session.day, placement_id]): the seed of a battle the map starts.
int64_t placement_combat_seed(State &state, const Value &session, Atom pattern, Atom placement_id) {
	const Atom seed_text = gd::format(state, pattern,
			{ gd::member(state, session, key::scenario_id), gd::member(state, session, key::launch_mode), gd::member(state, session, key::day), str(placement_id) });
	return gd::hash(state, str(seed_text));
}

// OverworldRules._find_resource_node_by_placement(session, id): its index (-1
// when not found) and node.
DictRef find_resource_node(State &state, const Value &session, Atom placement_id) {
	return overworld_rules::_find_resource_node_by_placement(state, gd::object_view(state, session), placement_id);
}

} // namespace

DictRef create_town_assault_payload(State &state, const Value &session, Atom town_placement_id) {
	overworld_rules::normalize_overworld_state(state, gd::object_view(state, session));
	const DictRef town_result = _find_town_by_placement(state, session, town_placement_id);
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return state.new_dict();
	}
	const DictRef town = gd::as_dict(field_or_new_dict(state, town_result, key::town));
	if (gd::is_empty(state, town) || text_or(state, town, key::owner, str(key::neutral)) != key::enemy) {
		return state.new_dict();
	}
	const DictRef enemy_commander = _town_assault_enemy_commander_state(state, town);
	const DictRef entrance = overworld_level_rules::town_entrance(state, town);
	const DictRef placement = state.new_dict();
	state.set(placement, str(key::placement_id), str(gd::format(state, key::town_assault_s, { str(town_placement_id) })));
	state.set(placement, str(key::encounter_id), str(key::encounter_town_assault));
	state.set(placement, str(key::x), int_value(gd::to_int(state, gd::index(state, entrance, str(key::x)))));
	state.set(placement, str(key::y), int_value(gd::to_int(state, gd::index(state, entrance, str(key::y)))));
	state.set(placement, str(key::level), int_value(overworld_level_rules::level_of(state, dict_value(town))));
	state.set(placement, str(key::combat_seed), int_value(placement_combat_seed(state, session, key::s_s_d_town_assault_s, town_placement_id)));
	{
		const DictRef enemy_army = state.new_dict();
		state.set(enemy_army, str(key::id), str(gd::format(state, key::town_garrison_s_2, { str(town_placement_id) })));
		state.set(enemy_army, str(key::name), str(gd::format(state, key::s_garrison, { str(_town_name(state, town)) })));
		const Value garrison = gd::field_or(state, town, key::garrison, Value());
		state.set(enemy_army, str(key::stacks), array_value(gd::is_array(garrison) ? gd::deep_duplicate_array(state, garrison.ref) : state.new_array()));
		state.set(placement, str(key::enemy_army), dict_value(enemy_army));
	}
	state.set(placement, str(key::enemy_hero_override),
			dict_value(!gd::is_empty(state, enemy_commander) ? enemy_commander : _town_captain_state(state, town)));
	{
		const DictRef battle_context = state.new_dict();
		state.set(battle_context, str(key::type), str(key::town_assault));
		state.set(battle_context, str(key::town_placement_id), str(town_placement_id));
		state.set(battle_context, str(key::trigger_faction_id),
				str(player_identity_rules::faction_id(state, gd::object_view(state, session), player_identity_rules::town_controller_id(state, town))));
		state.set(battle_context, str(key::trigger_player_id), str(string_of(state, town, key::controlling_player_id)));
		state.set(placement, str(key::battle_context), dict_value(battle_context));
	}
	return create_battle_payload(state, session, placement);
}

DictRef create_entry_defense_assault_payload(State &state, const Value &session, Atom town_placement_id, DictRef hero_encounter) {
	const DictRef town_result = _find_town_by_placement(state, session, town_placement_id);
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return state.new_dict();
	}
	DictRef town = gd::as_dict(field_or_new_dict(state, town_result, key::town));
	const Value commander = state.get(hero_encounter, str(key::enemy_commander_state), Value());
	if (!gd::is_dict(commander) || gd::is_empty(state, commander.ref)) {
		return state.new_dict();
	}
	const Value hero_army = state.get(hero_encounter, str(key::enemy_army), Value());
	const Value hero_stacks = gd::duplicate_value(state, gd::is_dict(hero_army) ? state.get(hero_army.ref, str(key::stacks), array_value(state.new_array())) : array_value(state.new_array()), true);
	const Value garrison = gd::duplicate_value(state, state.get(town, str(key::garrison), array_value(state.new_array())), true);
	const DictRef plan = hero_command_rules::entry_defense_plan(state, hero_stacks, garrison);
	if (!gd::bool_field(state, plan, key::fits, false)) {
		return state.new_dict();
	}
	// The town holds the hero's and the garrison's stacks and the hero as its
	// commander only while the ordinary assault payload reads them.
	const Value town_commander = gd::duplicate_value(state, state.get(town, str(key::ai_defender_commander_state), dict_value(state.new_dict())), true);
	const Value town_roster_hero = state.get(town, str(key::ai_defender_roster_hero_id), str(key::empty));
	state.set(town, str(key::garrison), gd::index(state, plan, str(key::stacks)));
	state.set(town, str(key::ai_defender_commander_state), gd::duplicate_value(state, commander, true));
	const DictRef payload = create_town_assault_payload(state, session, town_placement_id);
	town = gd::as_dict(field_or_new_dict(state, _find_town_by_placement(state, session, town_placement_id), key::town));
	state.set(town, str(key::garrison), garrison);
	if (gd::is_dict(town_commander) && !gd::is_empty(state, town_commander.ref)) {
		state.set(town, str(key::ai_defender_commander_state), town_commander);
	} else {
		state.erase(town, str(key::ai_defender_commander_state));
	}
	if (gd::is_empty(state, payload)) {
		return payload;
	}
	const DictRef record = state.new_dict();
	state.set(record, str(key::placement_id), str(string_of(state, hero_encounter, key::placement_id)));
	state.set(record, str(key::resolved_key), str(overworld_rules::encounter_key(state, hero_encounter)));
	state.set(record, str(key::hero_stacks), hero_stacks);
	state.set(record, str(key::garrison), garrison);
	state.set(record, str(key::town_commander), town_commander);
	state.set(record, str(key::town_roster_hero_id), town_roster_hero);
	const Value payload_context = state.get(payload, str(key::context), Value());
	if (gd::is_dict(payload_context)) {
		state.set(payload_context.ref, str(key::entry_defense), dict_value(record));
	}
	return payload;
}

DictRef _town_assault_enemy_commander_state(State &state, DictRef town) {
	const Value commander_state = field_or_new_dict(state, town, key::ai_defender_commander_state);
	if (gd::is_dict(commander_state) && !gd::is_empty(state, commander_state.ref)) {
		return gd::deep_duplicate_dict(state, commander_state.ref);
	}
	return state.new_dict();
}

DictRef create_resource_defense_payload(State &state, const Value &session, Atom resource_placement_id) {
	overworld_rules::normalize_overworld_state(state, gd::object_view(state, session));
	const DictRef node_result = find_resource_node(state, session, resource_placement_id);
	if (gd::int_field(state, node_result, key::index, -1) < 0) {
		return state.new_dict();
	}
	const DictRef node = gd::as_dict(field_or_new_dict(state, node_result, key::node));
	const DictRef site = gd::content_row(state, ContentTable::ResourceSite, string_of(state, node, key::site_id));
	const Value defender_army = field_or_new_dict(state, node, key::ai_defender_army);
	if (gd::is_empty(state, site) || !gd::is_dict(defender_army)
			|| _army_strength_from_stacks(state, gd::field_or(state, defender_army.ref, key::stacks, array_value(state.new_array()))) <= 0) {
		return state.new_dict();
	}
	// String(node.get(field, node.get(fallback_field, ""))).
	const auto node_text = [&](Atom field, Atom fallback_field) {
		return text_or(state, node, field, gd::field_or(state, node, fallback_field, str(key::empty)));
	};
	const Atom faction_id = node_text(key::ai_defended_by_faction_id, key::collected_by_faction_id);
	const Value commander_state = field_or_new_dict(state, node, key::ai_defender_commander_state);
	const DictRef placement = state.new_dict();
	state.set(placement, str(key::placement_id), str(gd::format(state, key::resource_defense_s, { str(resource_placement_id) })));
	state.set(placement, str(key::encounter_id), str(key::encounter_resource_defense));
	state.set(placement, str(key::x), int_value(gd::int_field(state, node, key::x, 0)));
	state.set(placement, str(key::y), int_value(gd::int_field(state, node, key::y, 0)));
	state.set(placement, str(key::level), int_value(overworld_level_rules::level_of(state, dict_value(node))));
	state.set(placement, str(key::combat_seed), int_value(placement_combat_seed(state, session, key::s_s_d_resource_defense_s, resource_placement_id)));
	state.set(placement, str(key::spawned_by_faction_id), str(faction_id));
	state.set(placement, str(key::spawned_by_player_id), str(node_text(key::ai_defended_by_player_id, key::collected_by_player_id)));
	state.set(placement, str(key::target_kind), str(key::resource));
	state.set(placement, str(key::target_placement_id), str(resource_placement_id));
	state.set(placement, str(key::target_label), str(text_or(state, site, key::name, str(resource_placement_id))));
	state.set(placement, str(key::enemy_army), dict_value(gd::deep_duplicate_dict(state, defender_army.ref)));
	state.set(placement, str(key::enemy_hero_override),
			dict_value(gd::is_dict(commander_state) ? gd::deep_duplicate_dict(state, commander_state.ref) : state.new_dict()));
	{
		const DictRef battle_context = state.new_dict();
		state.set(battle_context, str(key::type), str(key::resource_assault));
		state.set(battle_context, str(key::resource_placement_id), str(resource_placement_id));
		state.set(battle_context, str(key::resource_site_id), str(string_of(state, node, key::site_id)));
		state.set(battle_context, str(key::resource_site_name), str(text_or(state, site, key::name, str(resource_placement_id))));
		state.set(battle_context, str(key::trigger_faction_id), str(faction_id));
		state.set(battle_context, str(key::trigger_player_id), str(node_text(key::ai_defended_by_player_id, key::collected_by_player_id)));
		state.set(placement, str(key::battle_context), dict_value(battle_context));
	}
	return create_battle_payload(state, session, placement);
}

// A hero attacks the guard of a tier 5+ creature dwelling. The guard is a
// plain neutral encounter keyed "dwelling_guard:<placement>", so the battle
// resolves through the normal encounter flow; only its outcome is written back
// to the dwelling (see OverworldRules.update_dwelling_guard_after_battle).
DictRef create_dwelling_guard_payload(State &state, const Value &session, Atom resource_placement_id) {
	overworld_rules::normalize_overworld_state(state, gd::object_view(state, session));
	const DictRef node_result = find_resource_node(state, session, resource_placement_id);
	if (gd::int_field(state, node_result, key::index, -1) < 0) {
		return state.new_dict();
	}
	const DictRef node = gd::as_dict(field_or_new_dict(state, node_result, key::node));
	const DictRef site = gd::content_row(state, ContentTable::ResourceSite, string_of(state, node, key::site_id));
	const ArrayRef stacks = creature_dwelling_rules::guard_stacks(state, node, site, key::player, gd::to_int(state, gd::member(state, session, key::day)));
	if (state.array_size(stacks) == 0) {
		return state.new_dict();
	}
	const DictRef placement = state.new_dict();
	state.set(placement, str(key::placement_id), str(creature_dwelling_rules::guard_key(state, resource_placement_id)));
	state.set(placement, str(key::encounter_id), str(key::encounter_dwelling_guard));
	state.set(placement, str(key::x), int_value(gd::int_field(state, node, key::x, 0)));
	state.set(placement, str(key::y), int_value(gd::int_field(state, node, key::y, 0)));
	state.set(placement, str(key::level), int_value(overworld_level_rules::level_of(state, dict_value(node))));
	state.set(placement, str(key::combat_seed), int_value(placement_combat_seed(state, session, key::s_s_d_dwelling_guard_s, resource_placement_id)));
	{
		const DictRef enemy_army = state.new_dict();
		state.set(enemy_army, str(key::id), str(gd::format(state, key::dwelling_guard_s, { str(resource_placement_id) })));
		state.set(enemy_army, str(key::name), str(gd::format(state, key::s_guards, { str(text_or(state, site, key::name, str(key::Dwelling))) })));
		state.set(enemy_army, str(key::affiliation), str(key::neutral));
		state.set(enemy_army, str(key::stacks), array_value(stacks));
		state.set(placement, str(key::enemy_army), dict_value(enemy_army));
	}
	return create_battle_payload(state, session, placement);
}

} // namespace aurelion::rules::port::battle_rules
