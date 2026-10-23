// OverworldRules for the human seat's arrival at a resource site (Phase 7,
// slice 7.2): the pickup and claim, its route lock and reward texts.

#include "aurelion_rules/port/overworld_rules_move.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_ai.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/native_transit_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/resource_node_payload_rules_ai.hpp"
#include "aurelion_rules/port/resource_node_payload_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/visit_building_rules_ai.hpp"

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
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// String(x): stringify(), the engine's str() for a float, a container or an
// object (PackedStringArray(array) converts each item so too).
Atom value_text(State &state, const Value &value) {
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
Atom field_text(State &state, DictRef dict, Atom field, Atom fallback) {
	return value_text(state, gd::field_or(state, dict, field, str(fallback)));
}

// separator.join(array) of an untyped Array (PackedStringArray(array)).
Atom join_values(State &state, Atom separator, ArrayRef array) {
	std::string joined;
	const int64_t size = state.array_size(array);
	for (int64_t index = 0; index < size; ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(value_text(state, state.at(array, index)));
	}
	return state.intern(joined);
}

// separator.join(parts) of a PackedStringArray built here.
Atom join_atoms(State &state, Atom separator, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// {"ok": ok, "message": message}.
DictRef ok_message(State &state, bool ok, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(ok));
	state.set(result, str(key::message), str(message));
	return result;
}

// d.get(field, []) where the answer is kept: a new Array when it is missing.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

// d.get(field, {}) where the answer is kept: a new Dictionary when it is missing.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}

// x.duplicate(deep) of an untyped value: only an Array or a Dictionary has it here.
Value duplicate_container(State &state, const Value &value, bool deep) {
	if (gd::is_dict(value) || gd::is_array(value)) {
		if (deep) {
			return gd::engine_duplicate(state, value, true);
		}
		return gd::is_dict(value) ? dict_value(gd::duplicate_dict(state, value.ref)) : array_value(gd::duplicate_array(state, value.ref));
	}
	throw state::ScriptError(std::string("Invalid call. Nonexistent function 'duplicate' in base '") + gd::type_name(value) + "'.");
}

// x[index] = value of an untyped value.
void set_indexed(State &state, const Value &container, int64_t index, const Value &value) {
	if (gd::is_array(container)) {
		state.set_at(container.ref, index, value);
		return;
	}
	if (gd::is_dict(container)) {
		state.set(container.ref, int_value(index), value);
		return;
	}
	throw state::ScriptError(std::string("Invalid assignment of index on a base of type '") + gd::type_name(container) + "'.");
}

} // namespace

namespace overworld_rules {

DictRef collect_active_resource(State &state, DictRef session) {
	normalize_overworld_state_for_runtime(state, session);
	const DictRef node_result = _find_context_resource_node(state, session);
	if (gd::int_field(state, node_result, key::index, -1) < 0) {
		return ok_message(state, false, key::no_resource_site_here);
	}
	return _collect_resource_node_result(state, session, node_result, true, 1, key::empty);
}

DictRef _route_lock_prompt(State &state, DictRef session, DictRef node, DictRef site) {
	const Atom site_name = field_text(state, site, key::name, key::the_gate);
	const DictRef price = _resource_site_visit_cost(state, site);
	const Atom summary = gd::strip_edges(state, field_text(state, site, key::summary, key::empty));
	Atom message = key::empty;
	Atom explanation = key::empty;
	Atom label = key::empty;
	if (gd::is_empty(state, price)) {
		// A free route site (a reward camp across the road) is claimed, not paid.
		std::vector<Atom> gains;
		const Atom reward_part = _resource_site_reward_summary(state, site);
		const Atom recruit_part = _describe_recruit_count(state, _resource_site_claim_recruits(state, site));
		for (const Atom part : {reward_part, recruit_part}) {
			if (part != key::empty) {
				gains.push_back(part);
			}
		}
		message = gd::format(state, key::s_blocks_this_passage_claim_it, {str(site_name)});
		const Atom gains_text = gains.empty() ? key::empty : gd::format(state, key::and_gives_s, {str(join_atoms(state, key::comma_space, gains))});
		explanation = gd::format(state, key::claiming_it_opens_the_passage_for, {str(gains_text)});
		label = key::Claim;
	} else {
		const Atom price_text = _describe_resource_delta(state, dict_value(price));
		message = gd::format(state, key::s_blocks_this_passage_pay_s, {str(site_name), str(price_text)});
		explanation = key::this_gate_blocks_the_passage_until;
		label = gd::format(state, key::s_s_11, {str(field_text(state, site, key::action_label, key::Open)), str(price_text)});
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::route), str(key::reward_choice));
	state.set(result, str(key::message), str(message));
	const DictRef reward_choice = state.new_dict();
	state.set(reward_choice, str(key::title), str(site_name));
	const Atom object_suffix = gd::trim_prefix(state, field_text(state, node, key::object_id, key::empty), key::object_);
	state.set(reward_choice, str(key::asset_id), str(state.intern(state.text(key::mapobj_) + state.text(object_suffix))));
	state.set(reward_choice, str(key::context), dict_value(_resource_reward_choice_context(state, session, node)));
	const Atom instruction = summary != key::empty ? gd::format(state, key::s_s_12, {str(summary), str(explanation)}) : explanation;
	state.set(reward_choice, str(key::instruction), str(instruction));
	const ArrayRef choices = state.new_array();
	const DictRef choice = state.new_dict();
	state.set(choice, str(key::id), str(key::open_route));
	state.set(choice, str(key::label), str(label));
	state.append(choices, dict_value(choice));
	state.set(reward_choice, str(key::choices), array_value(choices));
	state.set(result, str(key::reward_choice), dict_value(reward_choice));
	return result;
}

DictRef _resource_reward_choice_context(State &state, DictRef session, DictRef node) {
	const DictRef context = state.new_dict();
	state.set(context, str(key::hero_id), str(field_text(state, session_view::overworld(state, session), key::active_hero_id, key::empty)));
	state.set(context, str(key::placement_id), str(field_text(state, node, key::placement_id, key::empty)));
	state.set(context, str(key::site_id), str(field_text(state, node, key::site_id, key::empty)));
	state.set(context, str(key::x), int_value(gd::int_field(state, node, key::x, 0)));
	state.set(context, str(key::y), int_value(gd::int_field(state, node, key::y, 0)));
	state.set(context, str(key::level), int_value(gd::int_field(state, node, key::level, 0)));
	return context;
}

ArrayRef _resource_site_reward_choices(State &state, DictRef site) {
	Value choices;
	if (state.lookup(site, str(key::reward_choices), choices) && gd::is_array(choices)) {
		return choices.ref;
	}
	return state.new_array();
}

Atom _resource_site_artifact_summary(State &state, DictRef site) {
	Value classes;
	if (!state.lookup(site, str(key::claim_artifact_classes), classes) || !gd::is_array(classes) || state.array_size(classes.ref) == 0) {
		return key::empty;
	}
	const int64_t count = state.array_size(classes.ref);
	if (count == 1) {
		return gd::format(state, key::a_s_artifact, {str(value_text(state, state.at(classes.ref, 0)))});
	}
	return gd::format(state, key::d_artifacts_s, {int_value(count), str(join_values(state, key::comma_space, classes.ref))});
}

Atom _spell_list_text(State &state, ArrayRef names) {
	const int64_t count = state.array_size(names);
	return count <= 3 ? join_values(state, key::comma_space, names) : gd::format(state, key::d_spells, {int_value(count)});
}

Atom _resource_site_reward_summary(State &state, DictRef site) {
	const ArrayRef choices = _resource_site_reward_choices(state, site);
	if (state.array_size(choices) == 0) {
		return _describe_reward_delta(state, dict_value(_resource_site_claim_rewards(state, site)));
	}
	std::vector<Atom> labels;
	for (int64_t index = 0; index < state.array_size(choices); ++index) {
		const Value choice = state.at(choices, index);
		labels.push_back(_describe_reward_delta(state, ai::vget(state, choice, key::rewards, dict_value(state.new_dict()))));
	}
	return state.intern(state.text(key::choose) + state.text(join_atoms(state, key::or_, labels)));
}

DictRef _collect_resource_node_result(State &state, DictRef session, DictRef node_result, bool refresh_fog_after_action, int64_t native_transit_cost, Atom reward_choice_id) {
	const int64_t collect_started_usec = _rules_profile_timer(state);
	_rules_profile_count(state, key::resource_collect_count, 1);
	const int64_t claimability_started_usec = _rules_profile_timer(state);
	// var node = node_result.get("node", {}): every use below takes it as a Dictionary.
	Value node_value;
	DictRef node = state.lookup(node_result, str(key::node), node_value) ? gd::as_dict(node_value) : state.new_dict();
	const DictRef site = resource_node_payload_rules::site_for_node(state, node, state.new_dict());
	if (gd::is_empty(state, site)) {
		_rules_profile_add_ms(state, key::resource_claimability_ms, claimability_started_usec);
		_rules_profile_add_ms(state, key::resource_collect_total_ms, collect_started_usec);
		return ok_message(state, false, key::this_site_has_no_authored_payload);
	}
	if (native_transit_rules::is_native(state, node)) {
		return travel_native_passage(state, session, node, native_transit_cost);
	}
	if (resource_site_is_recruit_source(state, site) && !hero_is_visiting_resource_site(state, session, node)) {
		return ok_message(state, false, key::your_hero_must_visit_this_recruitment);
	}
	if (field_text(state, site, key::batch003_role, key::empty) == key::sign_waypoint || field_text(state, site, key::batch004_role, key::empty) == key::route_waypoint) {
		// site.get("sign_contract", {}): a missing contract reads as an empty one.
		Atom hint_category = key::empty;
		Value sign_contract;
		if (state.lookup(site, str(key::sign_contract), sign_contract) && gd::is_dict(sign_contract)) {
			hint_category = field_text(state, sign_contract.ref, key::route_hint_category, key::empty);
		}
		Atom sign_text = gd::strip_edges(state, field_text(state, site, key::sign_text, key::empty));
		if (sign_text == key::empty) {
			sign_text = key::the_route_marks_are_too_weathered;
		}
		const DictRef sign_facts = state.new_dict();
		state.set(sign_facts, str(key::sign_read), bool_value(true));
		state.set(sign_facts, str(key::route_hint_category), str(hint_category));
		const DictRef sign_result = state.new_dict();
		state.set(sign_result, str(key::ok), bool_value(true));
		state.set(sign_result, str(key::message), str(gd::format(state, key::s_colon_s_text, {str(field_text(state, site, key::name, key::road_sign)), str(sign_text)})));
		state.set(sign_result, str(key::scenario_status), gd::field(state, session, key::scenario_status));
		const DictRef sign_waypoint = state.new_dict();
		state.set(sign_waypoint, str(key::site_id), str(field_text(state, site, key::id, key::empty)));
		state.set(sign_waypoint, str(key::placement_id), str(field_text(state, node, key::placement_id, key::empty)));
		state.set(sign_waypoint, str(key::route_hint_category), str(hint_category));
		state.set(sign_waypoint, str(key::text), str(sign_text));
		state.set(sign_result, str(key::sign_waypoint), dict_value(sign_waypoint));
		const DictRef sign_topology = state.new_dict();
		state.set(sign_topology, str(key::contract_known), bool_value(true));
		state.set(sign_topology, str(key::blocks_changed), bool_value(false));
		state.set(sign_topology, str(key::body_tiles_changed), bool_value(false));
		state.set(sign_result, str(key::interaction_result), dict_value(_interactable_result_payload(state, key::sign_waypoint, node, sign_facts, sign_topology)));
		_rules_profile_add_ms(state, key::resource_claimability_ms, claimability_started_usec);
		_rules_profile_add_ms(state, key::resource_collect_total_ms, collect_started_usec);
		return sign_result;
	}
	const DictRef guard_encounter = resource_site_blocking_guard(state, session, node, site, Value());
	if (!gd::is_empty(state, guard_encounter) && _resource_site_guard_blocks_node(state, guard_encounter, node)) {
		_rules_profile_add_ms(state, key::resource_claimability_ms, claimability_started_usec);
		_rules_profile_add_ms(state, key::resource_collect_total_ms, collect_started_usec);
		return ok_message(state, false, gd::format(state, key::clear_s_before_claiming_this_site, {str(encounter_display_name(state, guard_encounter))}));
	}
	const DictRef defender_battle = _resource_defender_battle_payload(state, session, node, site);
	if (!gd::is_empty(state, defender_battle)) {
		state.set(session, str(key::battle), dict_value(defender_battle));
		_rules_profile_add_ms(state, key::resource_claimability_ms, claimability_started_usec);
		_rules_profile_add_ms(state, key::resource_collect_total_ms, collect_started_usec);
		const DictRef result = ok_message(state, true, gd::format(state, key::battle_is_joined_for_s, {str(field_text(state, site, key::name, key::the_field_site_2))}));
		state.set(result, str(key::route), str(key::battle));
		return result;
	}
	if (visit_building_rules::is_visit_building(state, site)) {
		_rules_profile_add_ms(state, key::resource_claimability_ms, claimability_started_usec);
		_rules_profile_add_ms(state, key::resource_collect_total_ms, collect_started_usec);
		return _visit_building_result(state, session, node_result, site, refresh_fog_after_action, reward_choice_id);
	}
	if (creature_dwelling_rules::is_dwelling(state, site)) {
		if (creature_dwelling_rules::guard_blocks(state, node, site, key::player, ai::session_int(state, session, key::day))) {
			_rules_profile_add_ms(state, key::resource_claimability_ms, claimability_started_usec);
			_rules_profile_add_ms(state, key::resource_collect_total_ms, collect_started_usec);
			return _dwelling_guard_battle_result(state, session, node, site);
		}
		if (player_identity_rules::resource_controller_id(state, node) == key::player) {
			_rules_profile_add_ms(state, key::resource_claimability_ms, claimability_started_usec);
			_rules_profile_add_ms(state, key::resource_collect_total_ms, collect_started_usec);
			return _dwelling_recruit_result(state, session, node, site, key::empty);
		}
	}
	if (!_resource_node_claimable_by_player(state, node, site, dict_value(session))) {
		_rules_profile_add_ms(state, key::resource_claimability_ms, claimability_started_usec);
		_rules_profile_add_ms(state, key::resource_collect_total_ms, collect_started_usec);
		if (_resource_site_is_repeatable(state, site)) {
			return ok_message(state, false, _resource_site_repeatable_block_message(state, session, node, site));
		}
		if (_resource_site_is_persistent(state, site)) {
			return ok_message(state, false, key::this_site_is_already_under_your);
		}
		return ok_message(state, false, key::this_site_has_already_been_gathered);
	}
	if (gd::bool_field(state, site, key::opens_route_on_claim, false)) {
		// A gate takes payment only after the player agrees to open it.
		if (reward_choice_id != key::open_route) {
			_rules_profile_add_ms(state, key::resource_claimability_ms, claimability_started_usec);
			_rules_profile_add_ms(state, key::resource_collect_total_ms, collect_started_usec);
			return _route_lock_prompt(state, session, node, site);
		}
		reward_choice_id = key::empty;
	}
	DictRef choice_rewards = state.new_dict();
	const ArrayRef choices = _resource_site_reward_choices(state, site);
	if (state.array_size(choices) != 0) {
		if (reward_choice_id == key::empty) {
			const DictRef result = state.new_dict();
			state.set(result, str(key::ok), bool_value(true));
			state.set(result, str(key::route), str(key::reward_choice));
			state.set(result, str(key::message), str(gd::format(state, key::open_s_and_s, {str(field_text(state, site, key::name, key::the_chest)), str(_resource_site_reward_summary(state, site))})));
			const DictRef reward_choice = state.new_dict();
			state.set(reward_choice, str(key::title), str(field_text(state, site, key::name, key::treasure_chest)));
			state.set(reward_choice, str(key::asset_id), str(field_text(state, site, key::overworld_sprite_asset_id, key::empty)));
			state.set(reward_choice, str(key::context), dict_value(_resource_reward_choice_context(state, session, node)));
			state.set(reward_choice, str(key::choices), gd::engine_duplicate(state, array_value(choices), true));
			state.set(result, str(key::reward_choice), dict_value(reward_choice));
			return result;
		}
		for (int64_t index = 0; index < state.array_size(choices); ++index) {
			const Value choice = state.at(choices, index);
			if (value_text(state, ai::vget(state, choice, key::id, str(key::empty))) == reward_choice_id) {
				choice_rewards = gd::as_dict(duplicate_container(state, ai::vget(state, choice, key::rewards, dict_value(state.new_dict())), true));
			}
		}
		if (gd::is_empty(state, choice_rewards)) {
			return ok_message(state, false, key::choose_one_of_this_chest_s);
		}
	} else if (reward_choice_id != key::empty) {
		return ok_message(state, false, key::this_site_does_not_offer_a);
	}
	// A full army never blocks the claim: troops without a slot wait for the
	// hero's answer (pending_site_recruits).
	const DictRef visit_cost = _resource_site_visit_cost(state, site);
	if (!_can_afford(state, session, dict_value(visit_cost))) {
		_rules_profile_add_ms(state, key::resource_claimability_ms, claimability_started_usec);
		_rules_profile_add_ms(state, key::resource_collect_total_ms, collect_started_usec);
		return ok_message(state, false, gd::format(state, key::insufficient_resources_for_s, {str(field_text(state, site, key::action_label, key::that_service))}));
	}
	_rules_profile_add_ms(state, key::resource_claimability_ms, claimability_started_usec);

	const int64_t mutate_started_usec = _rules_profile_timer(state);
	const Value nodes = field_or_new_array(state, session_view::overworld(state, session), key::resource_nodes);
	const DictRef before_node = gd::as_dict(gd::engine_duplicate(state, dict_value(node), true));
	const DictRef map_object = _map_object_for_resource_node(state, before_node);
	const Atom previous_controller = player_identity_rules::resource_controller_id(state, node);
	state.set(node, str(key::collected), bool_value(true));
	state.set(node, str(key::collected_by_faction_id), str(key::player));
	state.erase(node, str(key::collected_by_player_id));
	state.set(node, str(key::collected_day), int_value(ai::session_int(state, session, key::day)));
	resource_node_payload_rules::mark_claimed(state, node, site);
	if (reward_choice_id != key::empty) {
		state.set(node, str(key::reward_choice_id), str(reward_choice_id));
	}
	const bool route_opened = _open_resource_site_route_body(state, node, site);
	node = _clear_resource_site_response(state, node);
	set_indexed(state, nodes, gd::int_field(state, node_result, key::index, -1), dict_value(node));
	state.set(session_view::overworld(state, session), str(key::resource_nodes), nodes);
	_rules_profile_add_ms(state, key::resource_mutate_node_ms, mutate_started_usec);
	const int64_t blocked_started_usec = _rules_profile_timer(state);
	const DictRef topology_facts = _resource_topology_facts(state, before_node, node, map_object);
	_refresh_blocked_tile_index_for_interaction(state, session, topology_facts);
	_rules_profile_add_ms(state, key::resource_blocked_index_refresh_ms, blocked_started_usec);

	const int64_t reward_started_usec = _rules_profile_timer(state);
	// Explicit choices grant exactly the amount shown on their buttons.
	DictRef rewards = choice_rewards;
	if (state.array_size(choices) == 0) {
		const DictRef scaled = difficulty_rules::scale_reward_resources(state, session, dict_value(_resource_site_claim_rewards(state, site)));
		const DictRef bonuses = hero_progression_rules::aggregate_bonuses(state, gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero)));
		rewards = apply_reward_bonus(state, dict_value(scaled), gd::int_field(state, bonuses, key::reward_bonus_pct, 0));
	}
	if (!gd::is_empty(state, visit_cost)) {
		_spend_resources(state, session, dict_value(visit_cost));
	}
	_add_resources(state, session, dict_value(rewards));
	_rules_profile_add_ms(state, key::resource_reward_apply_ms, reward_started_usec);
	const int64_t disruption_started_usec = _rules_profile_timer(state);
	const Atom disruption_message = apply_resource_site_disruption(state, session, node, site, previous_controller, key::player);
	const DictRef strategic_effects = _apply_resource_site_strategic_effects(state, session, node, site);
	const DictRef command_effects = _apply_shrine_command_bonus(state, session, site);
	const DictRef service_effects = field_text(state, site, key::batch003_role, key::empty) == key::repeatable_service ? strategic_effects : state.new_dict();
	const DictRef shrine_effects = _resource_site_grants_command_lesson(state, site) ? gd::as_dict(gd::engine_duplicate(state, dict_value(strategic_effects), true)) : state.new_dict();
	if (!gd::is_empty(state, command_effects)) {
		Value found;
		const ArrayRef shrine_messages = state.lookup(shrine_effects, str(key::messages), found) ? gd::as_array(found) : state.new_array();
		if (state.lookup(command_effects, str(key::messages), found)) {
			ai::append_array(state, shrine_messages, gd::as_array(found));
		}
		state.set(shrine_effects, str(key::messages), array_value(shrine_messages));
		state.set(shrine_effects, str(key::hero_command_bonus), duplicate_container(state, field_or_new_dict(state, command_effects, key::hero_command_bonus), true));
	}
	_rules_profile_add_ms(state, key::resource_disruption_ms, disruption_started_usec);
	const ArrayRef messages = state.new_array();
	state.append(messages, str(_resource_site_claim_message(state, site, previous_controller)));
	const Atom cost_summary = _describe_resource_delta(state, dict_value(visit_cost));
	if (cost_summary != key::empty) {
		state.append(messages, str(gd::format(state, key::cost_s, {str(cost_summary)})));
	}
	const Atom reward_summary = _describe_resource_delta(state, dict_value(rewards));
	if (reward_summary != key::empty) {
		state.append(messages, str(gd::format(state, key::stores_s, {str(reward_summary)})));
	}
	if (route_opened) {
		state.append(messages, str(key::the_route_is_open));
	}
	const int64_t recruits_spells_xp_started_usec = _rules_profile_timer(state);
	const Atom recruit_message = _grant_site_claim_recruits(state, session, dict_value(_resource_site_claim_recruits(state, site)), node, site);
	if (recruit_message != key::empty) {
		state.append(messages, str(recruit_message));
	}
	const DictRef claim_flags = _resource_site_claim_flags(state, site);
	{
		const ArrayRef flag_keys = gd::keys(state, claim_flags);
		for (int64_t index = 0; index < state.array_size(flag_keys); ++index) {
			const Value flag_key = state.at(flag_keys, index);
			const DictRef flags = gd::as_dict(gd::index(state, session, str(key::flags)));
			state.set(flags, str(value_text(state, flag_key)), gd::index(state, claim_flags, flag_key));
		}
	}
	const ArrayRef spell_messages = _learn_site_spells(state, session, array_value(_resource_site_spell_ids(state, site)));
	if (state.array_size(spell_messages) > 3) {
		// A Pandora's Box can teach a whole school at once.
		state.append(messages, str(gd::format(state, key::learns_d_spells, {int_value(state.array_size(spell_messages))})));
	} else {
		for (int64_t index = 0; index < state.array_size(spell_messages); ++index) {
			state.append(messages, str(value_text(state, state.at(spell_messages, index))));
		}
	}
	const int64_t site_vision_radius = compat::engine_max<int64_t>(0, gd::int_field(state, site, key::vision_radius, 0));
	const int64_t site_reveal_tiles = _reveal_resource_site_claim_fog(state, session, node, site_vision_radius);
	if (site_reveal_tiles > 0) {
		state.append(messages, str(gd::format(state, key::surveyed_d_new_map_tile_s, {int_value(site_reveal_tiles), str(site_reveal_tiles == 1 ? key::empty : key::s)})));
	}
	if (disruption_message != key::empty) {
		state.append(messages, str(disruption_message));
	}
	{
		const state::ValueList service_messages = gd::field_items(state, service_effects, str(key::messages)).list();
		for (const Value &service_message : service_messages) {
			state.append(messages, str(value_text(state, service_message)));
		}
	}
	{
		const state::ValueList shrine_messages = gd::field_items(state, shrine_effects, str(key::messages)).list();
		for (const Value &shrine_message : shrine_messages) {
			state.append(messages, str(value_text(state, shrine_message)));
		}
	}
	ai::append_array(state, messages, _award_experience(state, session, gd::int_field(state, rewards, key::experience, 0)));
	if (_resource_site_grants_command_lesson(state, site)) {
		hero_command_rules::commit_active_hero(state, session);
	}
	const DictRef artifact_reward = _grant_resource_site_artifact_reward(state, session, node, site);
	if (gd::bool_field(state, artifact_reward, key::applied, false)) {
		state.append(messages, str(field_text(state, artifact_reward, key::message, key::empty)));
		state.set(node, str(key::artifact_reward_id), str(field_text(state, artifact_reward, key::artifact_id, key::empty)));
		// artifact_reward.get("artifact_ids", [node["artifact_reward_id"]]).duplicate()
		Value artifact_ids;
		if (!state.lookup(artifact_reward, str(key::artifact_ids), artifact_ids)) {
			const ArrayRef fallback = state.new_array();
			state.append(fallback, gd::index(state, node, str(key::artifact_reward_id)));
			artifact_ids = array_value(fallback);
		}
		state.set(node, str(key::artifact_reward_ids), duplicate_container(state, artifact_ids, false));
		state.set(node, str(key::artifact_reward_table_id), str(field_text(state, artifact_reward, key::table_id, key::empty)));
		state.set(node, str(key::artifact_reward_source_key), str(field_text(state, artifact_reward, key::source_key, key::empty)));
		state.set(node, str(key::artifact_reward_claimed_by_faction_id), str(key::player));
		state.erase(node, str(key::artifact_reward_claimed_by_player_id));
		state.set(node, str(key::artifact_reward_claimed_day), int_value(ai::session_int(state, session, key::day)));
		set_indexed(state, nodes, gd::int_field(state, node_result, key::index, -1), dict_value(node));
		state.set(session_view::overworld(state, session), str(key::resource_nodes), nodes);
	}
	_rules_profile_add_ms(state, key::resource_recruits_spells_xp_ms, recruits_spells_xp_started_usec);
	const DictRef mutation_facts = _resource_interaction_event_facts(state, node, site, previous_controller, rewards, visit_cost, topology_facts);
	if (site_reveal_tiles > 0) {
		state.set(mutation_facts, str(key::fog_exploration_changed), bool_value(true));
	}
	if (gd::bool_field(state, artifact_reward, key::applied, false)) {
		// artifact_reward.get("artifact_ids", [String(artifact_reward.get("artifact_id", ""))]).duplicate()
		Value artifact_ids;
		if (!state.lookup(artifact_reward, str(key::artifact_ids), artifact_ids)) {
			const ArrayRef fallback = state.new_array();
			state.append(fallback, str(field_text(state, artifact_reward, key::artifact_id, key::empty)));
			artifact_ids = array_value(fallback);
		}
		state.set(mutation_facts, str(key::artifact_ids), duplicate_container(state, artifact_ids, false));
		state.set(mutation_facts, str(key::artifact_reward_table_id), str(field_text(state, artifact_reward, key::table_id, key::empty)));
	}
	if (!gd::is_empty(state, claim_flags)) {
		// Array(claim_flags.keys(), TYPE_STRING, "", null)
		const ArrayRef flag_keys = gd::keys(state, claim_flags);
		const ArrayRef flag_names = gd::new_typed_array(state, state::variant_type::STRING);
		for (int64_t index = 0; index < state.array_size(flag_keys); ++index) {
			state.append(flag_names, state.at(flag_keys, index));
		}
		state.set(mutation_facts, str(key::flags), array_value(flag_names));
	}
	if (route_opened) {
		state.set(mutation_facts, str(key::route_opened), bool_value(true));
	}
	if (!gd::is_empty(state, service_effects)) {
		state.set(mutation_facts, str(key::service_effects), gd::engine_duplicate(state, dict_value(service_effects), true));
	}
	if (!gd::is_empty(state, shrine_effects)) {
		state.set(mutation_facts, str(key::shrine_effects), gd::engine_duplicate(state, dict_value(shrine_effects), true));
	}
	const DictRef result = _finalize_action_result(state, session, true, join_values(state, key::space, messages), refresh_fog_after_action, false, mutation_facts);
	if (site_vision_radius > 0) {
		state.set(result, str(key::site_vision_radius), int_value(site_vision_radius));
		state.set(result, str(key::site_reveal_tiles), int_value(site_reveal_tiles));
	}
	if (!gd::is_empty(state, claim_flags)) {
		state.set(result, str(key::site_claim_flags), gd::engine_duplicate(state, dict_value(claim_flags), true));
	}
	if (route_opened) {
		state.set(result, str(key::route_opened), bool_value(true));
	}
	if (!gd::is_empty(state, service_effects)) {
		state.set(result, str(key::service_effects), gd::engine_duplicate(state, dict_value(service_effects), true));
	}
	if (!gd::is_empty(state, shrine_effects)) {
		state.set(result, str(key::shrine_effects), gd::engine_duplicate(state, dict_value(shrine_effects), true));
	}
	if (!refresh_fog_after_action) {
		state.set(result, str(key::descriptor_route_fog_reused), bool_value(true));
	}
	state.set(result, str(key::interaction_result), dict_value(_interactable_result_payload(state, key::resource_site, node, mutation_facts, topology_facts)));
	const DictRef context = state.new_dict();
	state.set(context, str(key::placement_id), str(field_text(state, node, key::placement_id, key::empty)));
	state.set(context, str(key::site_id), str(field_text(state, node, key::site_id, key::empty)));
	state.set(context, str(key::x), int_value(gd::int_field(state, node, key::x, 0)));
	state.set(context, str(key::y), int_value(gd::int_field(state, node, key::y, 0)));
	state.set(context, str(key::previous_controller), str(previous_controller));
	state.set(context, str(key::rewards), dict_value(rewards));
	state.set(context, str(key::artifact_reward), dict_value(artifact_reward));
	state.set(context, str(key::mutation_facts), dict_value(mutation_facts));
	DictRef recapped = _attach_post_action_recap(state, result, session, key::resource_site, context);
	if (creature_dwelling_rules::is_dwelling(state, site)) {
		recapped = _attach_dwelling_recruit_offer(state, session, recapped, node, site);
	}
	_rules_profile_add_ms(state, key::resource_collect_total_ms, collect_started_usec);
	return recapped;
}

bool _resource_site_grants_command_lesson(State &state, DictRef site) {
	if (field_text(state, site, key::batch003_role, key::empty) == key::shrine_progression) {
		return true;
	}
	// site.get("runtime_boundary", {}).get("status", ""): a missing boundary has no status.
	Atom status = key::empty;
	Value boundary;
	if (state.lookup(site, str(key::runtime_boundary), boundary)) {
		status = value_text(state, ai::vget(state, boundary, key::status, str(key::empty)));
	}
	return status == key::high_arcanum_live || status == key::field_mastery_convocation_live || status == key::commander_proving_road_live || status == key::commander_doctrine_expedition_live;
}

bool _open_resource_site_route_body(State &state, DictRef node, DictRef site) {
	if (!gd::bool_field(state, site, key::opens_route_on_claim, false)) {
		return false;
	}
	state.set(node, str(key::blocking_body), bool_value(false));
	state.set(node, str(key::package_block_tiles), array_value(state.new_array()));
	state.set(node, str(key::route_state_id), str(key::opened));
	state.set(node, str(key::state_id), str(key::opened));
	return true;
}

DictRef _clear_resource_site_response(State &state, DictRef node) {
	const DictRef cleared = _clear_resource_site_delivery(state, node);
	state.set(cleared, str(key::response_origin), str(key::empty));
	state.set(cleared, str(key::response_source_town_id), str(key::empty));
	state.set(cleared, str(key::response_last_day), int_value(0));
	state.set(cleared, str(key::response_until_day), int_value(0));
	state.set(cleared, str(key::response_commander_id), str(key::empty));
	state.set(cleared, str(key::response_security_rating), int_value(0));
	return cleared;
}

int64_t _reveal_resource_site_claim_fog(State &state, DictRef session, DictRef node, int64_t radius) {
	// session == null cannot happen: a session is its view.
	if (radius <= 0 || gd::is_empty(state, node)) {
		return 0;
	}
	if (!_fog_state_ready(state, session)) {
		_normalize_fog_of_war(state, session);
	}
	const Vector2i map_size = derive_map_size(state, session);
	const int64_t level = overworld_level_rules::level_of(state, dict_value(node));
	const DictRef fog = fog_for_level(state, session, level);
	const int64_t before_count = gd::int_field(state, fog, key::explored_count, 0);
	const ArrayRef explored_tiles = _normalize_visibility_grid(state, field_or_new_array(state, fog, key::explored_tiles), map_size);
	_apply_site_reveal(state, explored_tiles, node, radius, map_size);
	_reveal_all_current_fog_sources(state, session, explored_tiles, map_size, level);
	const DictRef payload = _build_fog_payload(state, _duplicate_visibility_grid(state, explored_tiles), explored_tiles, map_size);
	_store_level_fog(state, session, payload, level);
	return compat::engine_max<int64_t>(0, gd::sub(gd::int_field(state, payload, key::explored_count, before_count), before_count));
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
