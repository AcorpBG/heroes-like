#include "aurelion_rules/port/adventure_services.hpp"
// OverworldRules for the human seat's arrival (Phase 7, slice 7.2): dwellings,
// visit buildings and the site effects, with CreatureDwellingRules' and
// VisitBuildingRules' texts and bonuses.

#include "aurelion_rules/port/overworld_rules_move.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/battle_payload.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_ai.hpp"
#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"
#include "aurelion_rules/port/visit_building_rules_ai.hpp"
#include "aurelion_rules/port/visit_building_rules_turn.hpp"
#include "aurelion_rules/port/water_travel_rules_turn.hpp"

#include <string>
#include <vector>

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

// String(x): stringify(), and the engine's for a float or a container.
Atom string_of_value(State &state, const Value &value) {
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

// String(d.get(name, fallback)).
Atom string_of(State &state, DictRef dict, Atom name, Atom fallback) {
	return string_of_value(state, state.get(dict, str(name), str(fallback)));
}

// d.get(field, {}) of a field that is passed on or written: the value, or a new Dictionary.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// var x: Dictionary = d.get(field, {}) (or the same passed to a Dictionary
// parameter): the field's Dictionary, a ScriptError for another type, or a new one.
DictRef typed_dict_field(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return gd::as_dict(found);
	}
	return state.new_dict();
}

// var x: Array = d.get(field, []): the field's Array, a ScriptError for another
// type, or a new one.
ArrayRef typed_array_field(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return gd::as_array(found);
	}
	return state.new_array();
}

// {"ok": false, "message": message}.
DictRef refusal(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

// separator.join(parts) of Strings.
Atom join_atoms(State &state, Atom separator, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t at = 0; at < parts.size(); ++at) {
		if (at > 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[at]);
	}
	return state.intern(joined);
}

// separator.join(array) of an Array: each item as String, as its
// PackedStringArray conversion makes it.
Atom join_array(State &state, Atom separator, ArrayRef array) {
	std::string joined;
	const int64_t count = state.array_size(array);
	for (int64_t at = 0; at < count; ++at) {
		if (at > 0) {
			joined += state.text(separator);
		}
		joined += state.text(string_of_value(state, state.at(array, at)));
	}
	return state.intern(joined);
}

} // namespace

namespace overworld_rules {

DictRef _dwelling_guard_battle_result(State &state, DictRef session, DictRef node, DictRef site) {
	const Atom site_name = string_of(state, site, key::name, key::the_dwelling);
	const DictRef payload = battle_rules::create_dwelling_guard_payload(state, dict_value(session), string_of(state, node, key::placement_id, key::empty));
	if (gd::is_empty(state, payload)) {
		return refusal(state, gd::format(state, key::the_guards_of_s_cannot_be, {str(site_name)}));
	}
	state.set(session, str(key::battle), dict_value(payload));
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::message), str(gd::format(state, key::the_guards_of_s_stand_against, {str(site_name)})));
	state.set(result, str(key::route), str(key::battle));
	return result;
}

DictRef dwelling_recruit_offer(State &state, DictRef session, DictRef node, DictRef site) {
	const DictRef available = creature_dwelling_rules::population(state, node, site, ai::session_int(state, session, key::day));
	const ArrayRef rows = state.new_array();
	const ArrayRef offered = creature_dwelling_rules::creatures(state, node, site, ai::session_int(state, session, key::day));
	for (const Value &unit_id : gd::items(state, array_value(offered))) {
		const DictRef unit = gd::content_row(state, ContentTable::Unit, gd::to_string(unit_id));
		const DictRef cost = creature_dwelling_rules::unit_cost(state, gd::to_string(unit_id));
		const DictRef row = state.new_dict();
		state.set(row, str(key::unit_id), unit_id);
		state.set(row, str(key::name), str(string_of_value(state, state.get(unit, str(key::name), unit_id))));
		state.set(row, str(key::tier), int_value(gd::int_field(state, unit, key::tier, 1)));
		state.set(row, str(key::available), int_value(gd::to_int(state, state.get(available, unit_id, int_value(0)))));
		state.set(row, str(key::cost), dict_value(cost));
		state.set(row, str(key::free), bool_value(gd::is_empty(state, cost)));
		state.append(rows, dict_value(row));
	}
	const DictRef offer = state.new_dict();
	state.set(offer, str(key::title), str(string_of(state, site, key::name, key::creature_dwelling)));
	state.set(offer, str(key::site_id), str(string_of(state, node, key::site_id, key::empty)));
	{
		const DictRef node_facts = state.new_dict();
		state.set(node_facts, str(key::placement_id), str(string_of(state, node, key::placement_id, key::empty)));
		state.set(node_facts, str(key::site_id), str(string_of(state, node, key::site_id, key::empty)));
		state.set(node_facts, str(key::collected), bool_value(gd::bool_field(state, node, key::collected, false)));
		state.set(node_facts, str(key::collected_by_faction_id), str(string_of(state, node, key::collected_by_faction_id, key::empty)));
		state.set(offer, str(key::node), dict_value(node_facts));
	}
	state.set(offer, str(key::context), dict_value(_resource_reward_choice_context(state, session, node)));
	state.set(offer, str(key::creatures), array_value(rows));
	state.set(offer, str(key::summary), str(creature_dwelling_rules::summary(state, node, site, ai::session_int(state, session, key::day))));
	return offer;
}

bool _dwelling_has_creatures_for_hire(State &state, DictRef offer) {
	for (const Value &row : gd::field_items(state, offer, str(key::creatures))) {
		if (gd::is_dict(row) && gd::int_field(state, row.ref, key::available, 0) > 0) {
			return true;
		}
	}
	return false;
}

DictRef _dwelling_recruit_result(State &state, DictRef session, DictRef node, DictRef site, Atom prefix) {
	const DictRef offer = dwelling_recruit_offer(state, session, node, site);
	const Atom site_name = string_of(state, site, key::name, key::the_dwelling_2);
	if (!_dwelling_has_creatures_for_hire(state, offer)) {
		const Atom empty_message = gd::format(state, key::s_has_no_creatures_left_this, {str(site_name)});
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(prefix != key::empty));
		state.set(result, str(key::message), str(gd::strip_edges(state, gd::format(state, key::s_s, {str(prefix), str(empty_message)}))));
		return result;
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::route), str(key::dwelling_recruit));
	const Atom summary_text = string_of(state, offer, key::summary, key::empty);
	state.set(result, str(key::message), str(gd::strip_edges(state, gd::format(state, key::attack_forecast_message_text, {str(prefix), str(site_name), str(summary_text)}))));
	state.set(result, str(key::dwelling_recruit), dict_value(offer));
	return result;
}

DictRef _attach_dwelling_recruit_offer(State &state, DictRef session, DictRef result, DictRef node, DictRef site) {
	if (!gd::bool_field(state, result, key::ok, false) || player_identity_rules::resource_controller_id(state, node) != key::player) {
		return result;
	}
	const DictRef offer = dwelling_recruit_offer(state, session, node, site);
	if (_dwelling_has_creatures_for_hire(state, offer)) {
		state.set(result, str(key::route), str(key::dwelling_recruit));
		state.set(result, str(key::dwelling_recruit), dict_value(offer));
	}
	return result;
}

// session == null: a view is never null.
DictRef _apply_resource_site_strategic_effects(State &state, DictRef session, DictRef node, DictRef site) {
	Value authored = state.get(site, str(key::service_effects), Value());
	if (string_of(state, site, key::batch003_role, key::empty) == key::shrine_progression) {
		authored = state.get(site, str(key::shrine_effects), Value());
	}
	// A missing field is an empty Dictionary: nothing to apply either way.
	if (!gd::is_dict(authored) || gd::is_empty(state, authored.ref)) {
		return state.new_dict();
	}
	const DictRef result = state.new_dict();
	const ArrayRef messages = state.new_array();
	state.set(result, str(key::movement_restored), int_value(0));
	state.set(result, str(key::town_recovery_relieved), int_value(0));
	state.set(result, str(key::town_placement_id), str(key::empty));
	state.set(result, str(key::enemy_pressure_relieved), int_value(0));
	state.set(result, str(key::enemy_faction_id), str(key::empty));
	state.set(result, str(key::messages), array_value(messages));

	const int64_t movement_restore = compat::engine_max<int64_t>(0, gd::int_field(state, authored.ref, key::movement_restore, 0));
	if (movement_restore > 0) {
		Value movement = state.get(session_view::overworld(state, session), str(key::movement), Value());
		if (!gd::is_dict(movement)) {
			movement = dict_value(state.new_dict());
		}
		const DictRef hero = hero_command_rules::active_hero(state, session);
		// The fallback is evaluated whether "max" is there or not.
		const int64_t fallback_max = _movement_max_from_hero(state, hero, dict_value(session));
		const int64_t movement_max = compat::engine_max<int64_t>(0, gd::to_int(state, state.get(movement.ref, str(key::max), int_value(fallback_max))));
		const int64_t movement_before = compat::engine_clamp<int64_t>(gd::int_field(state, movement.ref, key::current, 0), 0, movement_max);
		const int64_t movement_after = compat::engine_min<int64_t>(movement_max, gd::add(movement_before, movement_restore));
		state.set(movement.ref, str(key::current), int_value(movement_after));
		state.set(movement.ref, str(key::max), int_value(movement_max));
		state.set(session_view::overworld(state, session), str(key::movement), movement);
		hero_command_rules::commit_active_hero(state, session);
		state.set(result, str(key::movement_restored), int_value(gd::sub(movement_after, movement_before)));
		if (movement_after > movement_before) {
			state.append(messages, str(gd::format(state, key::fresh_field_support_restores_d_movement, {int_value(gd::sub(movement_after, movement_before))})));
		}
	}
	const int64_t recovery_relief = compat::engine_max<int64_t>(0, gd::int_field(state, authored.ref, key::nearest_player_town_recovery_relief, 0));
	if (recovery_relief > 0) {
		const int64_t x = gd::int_field(state, node, key::x, 0);
		const int64_t y = gd::int_field(state, node, key::y, 0);
		const DictRef nearest = _nearest_town_for_controller(state, session, key::player, x, y, overworld_level_rules::level_of(state, dict_value(node)));
		// nearest.get("town", {}): a missing town is an empty one.
		const Value town = state.get(nearest, str(key::town), Value());
		if (gd::is_dict(town) && !gd::is_empty(state, town.ref)) {
			const Atom placement_id = string_of(state, town.ref, key::placement_id, key::empty);
			const int64_t pressure_before = gd::int_field(state, town_recovery_state(state, session, town.ref), key::pressure, 0);
			const Atom recovery_message = relieve_town_recovery_pressure(state, session, placement_id, recovery_relief, string_of(state, site, key::name, key::field_service));
			state.set(result, str(key::town_placement_id), str(placement_id));
			state.set(result, str(key::town_recovery_relieved), int_value(compat::engine_min<int64_t>(pressure_before, recovery_relief)));
			if (recovery_message != key::empty) {
				state.append(messages, str(recovery_message));
			}
		}
	}
	const int64_t pressure_relief = compat::engine_max<int64_t>(0, gd::int_field(state, authored.ref, key::enemy_pressure_relief, 0));
	if (pressure_relief > 0) {
		int64_t best_index = -1;
		int64_t best_pressure = 0;
		// session.overworld.get("enemy_states", []): a missing list has no states.
		const Value states = state.get(session_view::overworld(state, session), str(key::enemy_states), Value());
		if (gd::is_array(states)) {
			const int64_t count = state.array_size(states.ref);
			for (int64_t index = 0; index < count; ++index) {
				const Value enemy = state.at(states.ref, index);
				if (gd::is_dict(enemy) && gd::int_field(state, enemy.ref, key::pressure, 0) > best_pressure) {
					best_index = index;
					best_pressure = gd::int_field(state, enemy.ref, key::pressure, 0);
				}
			}
		}
		if (best_index >= 0) {
			const Value enemy = state.at(states.ref, best_index);
			const int64_t relieved = compat::engine_min<int64_t>(best_pressure, pressure_relief);
			state.set(enemy.ref, str(key::pressure), int_value(gd::sub(best_pressure, relieved)));
			state.set_at(states.ref, best_index, enemy);
			state.set(session_view::overworld(state, session), str(key::enemy_states), states);
			state.set(result, str(key::enemy_pressure_relieved), int_value(relieved));
			state.set(result, str(key::enemy_faction_id), str(string_of(state, enemy.ref, key::faction_id, key::empty)));
			const Atom faction_id = string_of(state, enemy.ref, key::faction_id, key::empty);
			const Atom faction_label = string_of(state, gd::content_row(state, ContentTable::Faction, faction_id), key::name, faction_id);
			state.append(messages, str(gd::format(state, key::reviewed_obligations_reduce_s_pressure_by, {str(faction_label), int_value(relieved)})));
		}
	}
	return result;
}

// session == null: a view is never null.
DictRef _apply_shrine_command_bonus(State &state, DictRef session, DictRef site) {
	if (!_resource_site_grants_command_lesson(state, site)) {
		return state.new_dict();
	}
	const Value authored = state.get(site, str(key::hero_command_bonus), Value());
	if (!gd::is_dict(authored) || gd::is_empty(state, authored.ref)) {
		return state.new_dict();
	}
	const Value hero = state.get(session_view::overworld(state, session), str(key::hero), Value());
	if (!gd::is_dict(hero) || gd::is_empty(state, hero.ref)) {
		return state.new_dict();
	}
	Value command = state.get(hero.ref, str(key::command), Value());
	if (!gd::is_dict(command)) {
		command = dict_value(state.new_dict());
	}
	const DictRef applied = state.new_dict();
	for (const Atom stat : {key::attack, key::defense, key::power, key::knowledge}) {
		const int64_t amount = compat::engine_clamp<int64_t>(gd::int_field(state, authored.ref, stat, 0), 0, 3);
		if (amount <= 0) {
			continue;
		}
		state.set(command.ref, str(stat), int_value(gd::add(compat::engine_max<int64_t>(0, gd::int_field(state, command.ref, stat, 0)), amount)));
		state.set(applied, str(stat), int_value(amount));
	}
	if (gd::is_empty(state, applied)) {
		return state.new_dict();
	}
	state.set(hero.ref, str(key::command), command);
	state.set(session_view::overworld(state, session), str(key::hero), hero);
	hero_command_rules::commit_active_hero(state, session);
	std::vector<Atom> labels;
	for (const Value &stat : gd::items(state, dict_value(applied))) {
		labels.push_back(gd::format(state, key::d_s_2, {int_value(gd::to_int(state, gd::index(state, applied, stat))), str(gd::capitalize(state, gd::stringify(state, stat)))}));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::hero_command_bonus), dict_value(applied));
	const ArrayRef messages = state.new_array();
	state.append(messages, str(gd::format(state, key::the_shrine_grants_s_permanently, {str(join_atoms(state, key::comma_space, labels))})));
	state.set(result, str(key::messages), array_value(messages));
	return result;
}

DictRef _visit_building_result(State &state, DictRef session, DictRef node_result, DictRef site, bool refresh_fog_after_action, Atom choice_id) {
	if (adventure_services::handles(state, site)) return adventure_services::visit(state, session, node_result, site, refresh_fog_after_action, choice_id);
	const int64_t index = gd::int_field(state, node_result, key::index, -1);
	const ArrayRef nodes = typed_array_field(state, session_view::overworld(state, session), key::resource_nodes);
	if (index < 0 || index >= state.array_size(nodes)) {
		return refusal(state, key::no_building_is_here);
	}
	const DictRef node = gd::as_dict(state.at(nodes, index));
	const Atom site_name = string_of(state, site, key::name, key::the_building);
	const Atom hero_id = string_of(state, session_view::overworld(state, session), key::active_hero_id, key::empty);
	const Atom side = visit_building_rules::side_key(state, dict_value(session));
	const DictRef ready = visit_building_rules::readiness(state, node, site, hero_id, ai::session_int(state, session, key::day), side);
	if (!gd::bool_field(state, ready, key::ok, false)) {
		return refusal(state, string_of(state, ready, key::message, key::empty));
	}
	const DictRef hero = typed_dict_field(state, session_view::overworld(state, session), key::hero);
	const int64_t required_level = visit_building_rules::required_level(state, site);
	if (required_level > 0 && gd::int_field(state, hero, key::level, 1) < required_level) {
		return refusal(state, gd::format(state, key::s_admits_only_heroes_of_level, {str(site_name), int_value(required_level)}));
	}
	const ArrayRef options = visit_building_rules::choices(state, site);
	if (state.array_size(options) != 0 && choice_id == key::empty) {
		const ArrayRef prompt_choices = state.new_array();
		for (const Value &choice : gd::items(state, array_value(options))) {
			if (!gd::is_dict(choice)) {
				continue;
			}
			Atom label = string_of(state, choice.ref, key::label, key::empty);
			if (label == key::empty) {
				label = gd::capitalize(state, visit_building_rules::effect_summary(state, typed_dict_field(state, choice.ref, key::effects)));
			}
			const DictRef prompt = state.new_dict();
			state.set(prompt, str(key::id), str(string_of(state, choice.ref, key::id, key::empty)));
			state.set(prompt, str(key::label), str(label));
			state.append(prompt_choices, dict_value(prompt));
		}
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(true));
		state.set(result, str(key::route), str(key::reward_choice));
		state.set(result, str(key::message), str(gd::format(state, key::visit_s_s, {str(site_name), str(visit_building_rules::summary(state, site))})));
		const DictRef reward_choice = state.new_dict();
		state.set(reward_choice, str(key::title), str(site_name));
		state.set(reward_choice, str(key::asset_id), str(string_of(state, site, key::overworld_sprite_asset_id, key::empty)));
		state.set(reward_choice, str(key::context), dict_value(_resource_reward_choice_context(state, session, node)));
		// The fallback is evaluated whether "public_text" is there or not.
		const Atom fallback_instruction = visit_building_rules::summary(state, site);
		state.set(reward_choice, str(key::instruction), str(string_of(state, site, key::public_text, fallback_instruction)));
		state.set(reward_choice, str(key::choices), array_value(prompt_choices));
		state.set(result, str(key::reward_choice), dict_value(reward_choice));
		return result;
	}
	const DictRef effect = visit_building_rules::effects(state, site, choice_id);
	if (state.array_size(options) != 0 && gd::is_empty(state, effect)) {
		return refusal(state, gd::format(state, key::choose_one_of_the_boons_s, {str(site_name)}));
	}
	const Atom effect_blocker = _visit_effect_blocker(state, session, node, effect);
	if (effect_blocker != key::empty) {
		return refusal(state, effect_blocker);
	}
	const DictRef price = visit_building_rules::cost(state, site, choice_id);
	if (!gd::is_empty(state, price) && !_can_afford(state, session, dict_value(price))) {
		return refusal(state, gd::format(state, key::s_asks_s, {str(site_name), str(_describe_resource_delta(state, dict_value(price)))}));
	}
	if (!gd::is_empty(state, price)) {
		_spend_resources(state, session, dict_value(price));
	}
	visit_building_rules::record_visit(state, node, site, hero_id, ai::session_int(state, session, key::day), side);
	state.set_at(nodes, index, dict_value(node));
	state.set(session_view::overworld(state, session), str(key::resource_nodes), array_value(nodes));
	const ArrayRef messages = state.new_array();
	state.append(messages, str(gd::format(state, key::s_visits_s, {str(string_of(state, hero, key::name, key::the_hero_text)), str(site_name)})));
	if (!gd::is_empty(state, price)) {
		state.append(messages, str(gd::format(state, key::paid_s, {str(_describe_resource_delta(state, dict_value(price)))})));
	}
	ai::append_array(state, messages, _apply_visit_effects(state, session, node, site, effect));
	const DictRef facts = state.new_dict();
	state.set(facts, str(key::visit_building_site_id), str(string_of(state, site, key::id, key::empty)));
	state.set(facts, str(key::visit_effects), gd::engine_duplicate(state, dict_value(effect), true));
	const DictRef result = _finalize_action_result(state, session, true, join_array(state, key::space, messages), refresh_fog_after_action, false, facts);
	{
		const DictRef visit = state.new_dict();
		state.set(visit, str(key::site_id), str(string_of(state, site, key::id, key::empty)));
		state.set(visit, str(key::hero_id), str(hero_id));
		state.set(visit, str(key::effects), gd::engine_duplicate(state, dict_value(effect), true));
		state.set(result, str(key::visit_building), dict_value(visit));
	}
	const DictRef topology_facts = state.new_dict();
	state.set(topology_facts, str(key::contract_known), bool_value(true));
	state.set(topology_facts, str(key::blocks_changed), bool_value(false));
	state.set(topology_facts, str(key::body_tiles_changed), bool_value(false));
	state.set(result, str(key::interaction_result), dict_value(_interactable_result_payload(state, key::resource_site, node, facts, topology_facts)));
	return result;
}

Atom _visit_effect_blocker(State &state, DictRef session, DictRef node, DictRef effect) {
	if (gd::bool_field(state, effect, key::build_boat, false)) {
		return water_travel_rules::dock_blocker(state, dict_value(session), node);
	}
	if (gd::bool_field(state, effect, key::whirlpool, false) && !water_travel_rules::is_sailing(state, dict_value(session))) {
		return key::only_a_boat_can_sail_into;
	}
	return key::empty;
}

ArrayRef _apply_visit_effects(State &state, DictRef session, DictRef node, DictRef site, DictRef effect) {
	const ArrayRef messages = state.new_array();
	if (gd::bool_field(state, effect, key::build_boat, false)) {
		const Atom failure = water_travel_rules::build_boat(state, dict_value(session), node);
		state.append(messages, str(failure != key::empty ? failure : key::shipwrights_launch_a_boat_at_the));
	}
	if (gd::bool_field(state, effect, key::whirlpool, false)) {
		ai::append_array(state, messages, _whirlpool_throw(state, session, node));
	}
	// effect.get("resources", {}): a missing field is an empty Dictionary.
	const Value gains = state.get(effect, str(key::resources), Value());
	if (gd::is_dict(gains) && !gd::is_empty(state, gains.ref)) {
		_add_resources(state, session, gains);
		state.append(messages, str(gd::format(state, key::receives_s, {str(_describe_resource_delta(state, gains))})));
	}
	DictRef hero = typed_dict_field(state, session_view::overworld(state, session), key::hero);
	const Value stats = state.get(effect, str(key::stats), Value());
	if (gd::is_dict(stats) && !gd::is_empty(state, stats.ref)) {
		Value command = state.get(hero, str(key::command), Value());
		if (!gd::is_dict(command)) {
			command = dict_value(state.new_dict());
		}
		std::vector<Atom> labels;
		// VisitBuildings.STAT_KEYS.
		for (const Atom stat : {key::attack, key::defense, key::power, key::knowledge}) {
			const int64_t amount = gd::int_field(state, stats.ref, stat, 0);
			if (amount == 0) {
				continue;
			}
			state.set(command.ref, str(stat), int_value(compat::engine_max<int64_t>(0, gd::add(gd::int_field(state, command.ref, stat, 0), amount))));
			labels.push_back(gd::format(state, key::d_s_2, {int_value(amount), str(gd::capitalize(state, stat))}));
		}
		state.set(hero, str(key::command), command);
		hero = spell_rules::ensure_hero_spellbook(state, hero, state.new_dict());
		if (!labels.empty()) {
			state.append(messages, str(gd::format(state, key::gains_s_permanently, {str(join_atoms(state, key::comma_space, labels))})));
		}
		state.set(session_view::overworld(state, session), str(key::hero), dict_value(hero));
		hero_command_rules::commit_active_hero(state, session);
	}
	int64_t experience = compat::engine_max<int64_t>(0, gd::int_field(state, effect, key::experience, 0));
	const int64_t levels = compat::engine_max<int64_t>(0, gd::int_field(state, effect, key::levels, 0));
	for (int64_t level = 0; level < levels; ++level) {
		const Value saved_hero = field_or_new_dict(state, session_view::overworld(state, session), key::hero);
		const DictRef current_hero = hero_progression_rules::ensure_hero_progression(state, gd::as_dict(gd::engine_duplicate(state, saved_hero, true)));
		experience = gd::add(experience, compat::engine_max<int64_t>(1, gd::sub(gd::int_field(state, current_hero, key::next_level_experience, 250), gd::int_field(state, current_hero, key::experience, 0))));
	}
	if (experience > 0) {
		state.append(messages, str(gd::format(state, key::gains_d_experience, {int_value(experience)})));
		ai::append_array(state, messages, _award_experience(state, session, experience));
		hero_command_rules::commit_active_hero(state, session);
	}
	if (gd::int_field(state, effect, key::spell_tier, 0) > 0) {
		const ArrayRef learned = _learn_site_spells(state, session, array_value(_resource_site_spell_ids(state, site)));
		if (state.array_size(learned) == 0) {
			state.append(messages, str(gd::format(state, key::the_hero_already_knows_what_s, {str(string_of(state, site, key::name, key::the_shrine_2))})));
		}
		ai::append_array(state, messages, learned);
		hero_command_rules::commit_active_hero(state, session);
	}
	const Atom mana_mode = string_of(state, effect, key::mana, key::empty);
	if (mana_mode != key::empty) {
		hero = spell_rules::ensure_hero_spellbook(state, typed_dict_field(state, session_view::overworld(state, session), key::hero), state.new_dict());
		if (mana_mode == key::week_double) {
			const int64_t base_mana = gd::sub(spell_rules::mana_max_from_hero(state, hero), visit_building_rules::week_bonus(state, hero, key::mana));
			visit_building_rules::add_week_bonus(state, hero, key::mana, compat::engine_max<int64_t>(0, gd::sub(base_mana, visit_building_rules::week_bonus(state, hero, key::mana))));
			hero = spell_rules::ensure_hero_spellbook(state, hero, state.new_dict());
		}
		const DictRef spellbook = typed_dict_field(state, hero, key::spellbook);
		const DictRef mana = typed_dict_field(state, spellbook, key::mana);
		state.set(mana, str(key::current), int_value(gd::int_field(state, mana, key::max, 0)));
		state.set(spellbook, str(key::mana), dict_value(mana));
		state.set(hero, str(key::spellbook), dict_value(spellbook));
		state.set(session_view::overworld(state, session), str(key::hero), dict_value(hero));
		hero_command_rules::commit_active_hero(state, session);
		state.append(messages, str(gd::format(state, key::mana_s_to_d, {str(mana_mode == key::week_double ? key::doubles : key::refills), int_value(gd::int_field(state, mana, key::current, 0))})));
	}
	const int64_t week_movement = compat::engine_max<int64_t>(0, gd::int_field(state, effect, key::week_movement, 0));
	const int64_t movement_gain = gd::add(compat::engine_max<int64_t>(0, gd::int_field(state, effect, key::movement, 0)), week_movement);
	if (movement_gain > 0) {
		hero = typed_dict_field(state, session_view::overworld(state, session), key::hero);
		if (week_movement > 0) {
			visit_building_rules::add_week_bonus(state, hero, key::movement, week_movement);
			state.set(session_view::overworld(state, session), str(key::hero), dict_value(hero));
		}
		Value movement = state.get(session_view::overworld(state, session), str(key::movement), Value());
		if (!gd::is_dict(movement)) {
			movement = dict_value(state.new_dict());
		}
		const int64_t movement_max = _movement_max_from_hero(state, hero, dict_value(session));
		const int64_t before = gd::int_field(state, movement.ref, key::current, 0);
		state.set(movement.ref, str(key::max), int_value(movement_max));
		state.set(movement.ref, str(key::current), int_value(compat::engine_min<int64_t>(movement_max, gd::add(before, movement_gain))));
		state.set(session_view::overworld(state, session), str(key::movement), movement);
		hero_command_rules::commit_active_hero(state, session);
		state.append(messages, str(gd::format(state, key::movement_rises_to_d, {int_value(gd::to_int(state, gd::index(state, movement.ref, str(key::current))))})));
	}
	Value boosts = field_or_new_dict(state, effect, key::battle_boosts);
	const Value rest_day_boosts = field_or_new_dict(state, effect, key::day7_battle_boosts);
	if (gd::is_dict(boosts) && gd::is_dict(rest_day_boosts) && !gd::is_empty(state, rest_day_boosts.ref) && compat::int_mod(ai::session_int(state, session, key::day), 7) == 0) {
		boosts = gd::engine_duplicate(state, boosts, true);
		const ArrayRef rest_day_keys = gd::keys(state, rest_day_boosts.ref);
		for (const Value &boost_key : gd::items(state, array_value(rest_day_keys))) {
			const int64_t current = gd::to_int(state, state.get(boosts.ref, boost_key, int_value(0)));
			state.set(boosts.ref, boost_key, int_value(gd::add(current, gd::to_int(state, gd::index(state, rest_day_boosts.ref, boost_key)))));
		}
	}
	if (gd::is_dict(boosts) && !gd::is_empty(state, boosts.ref)) {
		hero = typed_dict_field(state, session_view::overworld(state, session), key::hero);
		const DictRef applied = visit_building_rules::add_battle_boosts(state, hero, boosts.ref);
		state.set(session_view::overworld(state, session), str(key::hero), dict_value(hero));
		hero_command_rules::commit_active_hero(state, session);
		std::vector<Atom> boost_labels;
		for (const Value &boost_key : gd::items(state, dict_value(applied))) {
			if (gd::to_int(state, gd::index(state, applied, boost_key)) > 0) {
				boost_labels.push_back(gd::format(state, key::d_s_2, {int_value(gd::to_int(state, gd::index(state, applied, boost_key))), boost_key}));
			}
		}
		const Atom boost_message = !boost_labels.empty() ? gd::format(state, key::the_army_carries_s_into_its, {str(join_atoms(state, key::comma_space, boost_labels))}) : key::the_army_is_already_as_ready;
		state.append(messages, str(boost_message));
	}
	if (gd::int_field(state, effect, key::reveal_radius, 0) > 0) {
		const int64_t nearby = _reveal_resource_site_claim_fog(state, session, node, gd::int_field(state, effect, key::reveal_radius, 0));
		state.append(messages, str(gd::format(state, key::the_lenses_reveal_d_new_tiles, {int_value(nearby)})));
	}
	if (string_of(state, effect, key::reveal, key::empty) == key::level) {
		const Vector2i map_size = derive_map_size(state, session);
		const int64_t revealed = _reveal_resource_site_claim_fog(state, session, node, gd::add(static_cast<int64_t>(map_size.x), static_cast<int64_t>(map_size.y)));
		state.append(messages, str(gd::format(state, key::charts_reveal_d_new_tiles, {int_value(revealed)})));
	}
	return messages;
}

} // namespace overworld_rules

namespace creature_dwelling_rules {

Atom describe_creatures(State &state, DictRef node, DictRef site, int64_t day) {
	std::vector<Atom> parts;
	const DictRef growth = weekly_growth(state, node, site, day);
	for (const Value &unit_id : gd::items(state, dict_value(growth))) {
		const DictRef unit = gd::content_row(state, ContentTable::Unit, gd::to_string(unit_id));
		parts.push_back(gd::format(state, key::_d_s, {int_value(gd::to_int(state, gd::index(state, growth, unit_id))), str(string_of_value(state, state.get(unit, str(key::name), unit_id)))}));
	}
	return join_atoms(state, key::comma_space, parts);
}

Atom summary(State &state, DictRef node, DictRef site, int64_t day) {
	if (is_refugee_camp(state, site)) {
		const Atom unit_id = refugee_unit(state, node, day);
		return unit_id != key::empty ? gd::format(state, key::this_week_s_a_new_creature, {str(describe_creatures(state, node, site, day))}) : key::a_new_creature_each_week;
	}
	std::vector<Atom> parts;
	parts.push_back(gd::format(state, key::hire_s_a_week, {str(describe_creatures(state, node, site, day))}));
	const ArrayRef offered = creatures(state, node, site, day);
	for (const Value &unit_id : gd::items(state, array_value(offered))) {
		// CreatureDwellingRules.FREE_TIER.
		if (unit_tier(state, gd::to_string(unit_id)) <= 1) {
			parts.push_back(key::free);
			break;
		}
	}
	const ArrayRef guard = full_guard(state, node, site, day);
	if (state.array_size(guard) != 0) {
		const Value first = state.at(guard, 0);
		const int64_t count = gd::to_int(state, ai::vget(state, first, key::count, int_value(0)));
		const Atom guard_unit_id = string_of_value(state, ai::vget(state, first, key::unit_id, str(key::empty)));
		const Atom guard_name = string_of(state, gd::content_row(state, ContentTable::Unit, guard_unit_id), key::name, key::empty);
		parts.push_back(gd::format(state, key::guarded_by_d_s, {int_value(count), str(guard_name)}));
	}
	return join_atoms(state, key::comma_space, parts);
}

} // namespace creature_dwelling_rules

namespace visit_building_rules {

Atom side_key(State &state, const Value &session) {
	const Atom player_id = session.kind != Kind::Nil
			? string_of(state, session_view::overworld(state, gd::object_view(state, session)), key::active_player_id, key::empty)
			: key::empty;
	return gd::format(state, key::player_s, {str(player_id != key::empty ? player_id : key::player)});
}

Atom cadence_label(State &state, DictRef site) {
	const Atom mode = cadence(state, site);
	if (mode == key::once_per_side) {
		return key::once_per_player;
	}
	if (mode == key::daily_per_hero) {
		return key::once_per_hero_each_day;
	}
	if (mode == key::weekly_per_hero) {
		return key::once_per_hero_each_week;
	}
	if (mode == key::weekly_site) {
		return key::once_a_week;
	}
	if (mode == key::always) {
		return key::any_time;
	}
	return key::once_per_hero_2;
}

Atom summary(State &state, DictRef site) {
	Atom text = key::empty;
	const ArrayRef options = choices(state, site);
	if (state.array_size(options) != 0) {
		std::vector<Atom> labels;
		for (const Value &choice : gd::items(state, array_value(options))) {
			if (!gd::is_dict(choice)) {
				continue;
			}
			const Atom label = string_of(state, choice.ref, key::label, key::empty);
			labels.push_back(label != key::empty ? label : effect_summary(state, typed_dict_field(state, choice.ref, key::effects)));
		}
		text = gd::format(state, key::choose_s, {str(join_atoms(state, key::or_, labels))});
	} else {
		text = effect_summary(state, effects(state, site, key::empty));
	}
	const DictRef price = cost(state, site, key::empty);
	if (!gd::is_empty(state, price)) {
		text = gd::format(state, key::s_for_s, {str(text), str(_resource_text(state, price))});
	}
	if (required_level(state, site) > 0) {
		text = gd::format(state, key::s_hero_level_d, {str(text), int_value(required_level(state, site))});
	}
	return text != key::empty ? gd::format(state, key::s_s_10, {str(text), str(cadence_label(state, site))}) : cadence_label(state, site);
}

Atom status_line(State &state, DictRef node, DictRef site, Atom visitor_key, int64_t day, Atom side) {
	const DictRef ready = readiness(state, node, site, visitor_key, day, side);
	if (!gd::bool_field(state, ready, key::ok, false)) {
		return string_of(state, ready, key::message, key::empty);
	}
	return cadence(state, site) == key::once_per_side ? key::Ready : key::ready_for_this_hero;
}

void add_week_bonus(State &state, DictRef hero, Atom bonus_key, int64_t amount) {
	Value bonuses = state.get(hero, str(key::week_bonuses), Value());
	if (!gd::is_dict(bonuses)) {
		bonuses = dict_value(state.new_dict());
	}
	state.set(bonuses.ref, str(bonus_key), int_value(gd::add(gd::int_field(state, bonuses.ref, bonus_key, 0), amount)));
	state.set(hero, str(key::week_bonuses), bonuses);
}

int64_t week_bonus(State &state, DictRef hero, Atom bonus_key) {
	// hero.get(WEEK_BONUSES, {}): a missing entry reads as {}, so 0.
	Value bonuses;
	if (!state.lookup(hero, str(key::week_bonuses), bonuses)) {
		return 0;
	}
	return gd::is_dict(bonuses) ? gd::int_field(state, bonuses.ref, bonus_key, 0) : 0;
}

DictRef add_battle_boosts(State &state, DictRef hero, DictRef boosts) {
	Value current = state.get(hero, str(key::battle_boosts), Value());
	if (!gd::is_dict(current)) {
		current = dict_value(state.new_dict());
	}
	const DictRef applied = state.new_dict();
	// VisitBuildingRules.BOOST_KEYS, capped at BOOST_CAP.
	for (const Atom boost : {key::cohesion, key::momentum}) {
		const int64_t amount = gd::int_field(state, boosts, boost, 0);
		if (amount == 0) {
			continue;
		}
		const int64_t before = gd::int_field(state, current.ref, boost, 0);
		state.set(current.ref, str(boost), int_value(compat::engine_clamp<int64_t>(gd::add(before, amount), 0, 3)));
		state.set(applied, str(boost), int_value(gd::sub(gd::to_int(state, gd::index(state, current.ref, str(boost))), before)));
	}
	state.set(hero, str(key::battle_boosts), current);
	return applied;
}

} // namespace visit_building_rules

} // namespace aurelion::rules::port
