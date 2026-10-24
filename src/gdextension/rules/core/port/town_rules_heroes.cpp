// TownRules for the human seat's heroes in a town (Phase 7, slice 7.5): the read
// cache, the active town, hero, tavern, transfer and artifact actions, the
// garrison and the town's artifact services.

#include "aurelion_rules/port/overworld_rules_heroes.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <algorithm>
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
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;

// OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS.
constexpr Atom kLiveStockpileKeys[] = {key::gold, key::wood, key::ore, key::aetherglass, key::embergrain, key::peatwax, key::verdant_grafts, key::brass_scrip, key::memory_salt};

// String(d.get(field, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// d.get(field, {}) of a value that may be stored: the field, or a new
// Dictionary.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// {"ok": false, "message": message}.
DictRef refusal(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

// sep.join(parts) of an Array of Strings.
Atom join_array(State &state, Atom separator, ArrayRef parts) {
	std::string joined;
	bool first = true;
	for (const Value &part : gd::items(state, array_value(parts))) {
		if (!first) {
			joined += state.text(separator);
		}
		first = false;
		joined += gd::text(state, part);
	}
	return state.intern(joined);
}

// s.split(delimiter) (allow_empty): every piece, the empty ones too.
std::vector<Atom> split_text(State &state, Atom text_atom, const std::string &delimiter) {
	const std::string source = state.text(text_atom);
	std::vector<Atom> parts;
	if (source.empty()) {
		parts.push_back(key::empty);
		return parts;
	}
	size_t from = 0;
	while (true) {
		size_t end = source.find(delimiter, from);
		if (end == std::string::npos) {
			end = source.size();
		}
		parts.push_back(state.intern(std::string_view(source).substr(from, end - from)));
		if (end == source.size()) {
			break;
		}
		from = end + delimiter.size();
	}
	return parts;
}

// ContentService.canonical_town_id(id), as the content store answers it: the
// alias towns.json's legacy_aliases gives a retired town id, else the id.
Atom canonical_town_id(State &state, Atom id) {
	const DictRef raw = gd::content_file(state, key::towns_path);
	Value aliases_value;
	if (!state.lookup(raw, str(key::legacy_aliases), aliases_value)) {
		return id;
	}
	// var aliases: Dictionary = load_json(TOWNS_PATH).get("legacy_aliases", {})
	const DictRef aliases = gd::as_dict(aliases_value);
	Value alias;
	if (!state.lookup(aliases, str(id), alias)) {
		return id;
	}
	return gd::to_string(alias);
}

// String(session.session_id) == _read_scope_session_id, with a scope open.
bool read_scope_open_for(State &state, DictRef session) {
	return ai::static_int(state, key::town_rules_script, key::_read_scope_depth) > 0
			&& gd::stringify(state, gd::index(state, session, str(key::session_id))) == gd::to_string(gd::static_var(state, key::town_rules_script, key::_read_scope_session_id));
}

// for key in result.keys(): if key not in ["ok", "message"]: finalized[key] = result[key]
void copy_result_fields(State &state, DictRef finalized, DictRef result) {
	const ArrayRef result_keys = gd::keys(state, result);
	for (const Value &key_value : gd::items(state, array_value(result_keys))) {
		const Atom field = gd::stringify(state, key_value);
		if (field != key::ok && field != key::message) {
			state.set(finalized, str(field), gd::index(state, result, str(field)));
		}
	}
}

} // namespace

namespace town_rules {

bool _read_cache_has(State &state, DictRef session, Atom cache_key) {
	// session != null: a session is its view.
	return read_scope_open_for(state, session)
			&& state.has(ai::static_dict(state, key::town_rules_script, key::_read_scope_cache), str(cache_key));
}

Value _read_cache_get(State &state, DictRef session, Atom cache_key) {
	if (!_read_cache_has(state, session, cache_key)) {
		return Value();
	}
	// The cached value itself, as GDScript answers it.
	return gd::index(state, ai::static_dict(state, key::town_rules_script, key::_read_scope_cache), str(cache_key));
}

void _read_cache_store(State &state, DictRef session, Atom cache_key, const Value &value) {
	// session == null: a session is its view.
	if (!read_scope_open_for(state, session)) {
		return;
	}
	state.set(ai::static_dict(state, key::town_rules_script, key::_read_scope_cache), str(cache_key), value);
}

DictRef get_active_town(State &state, DictRef session) {
	if (_read_cache_has(state, session, key::active_town)) {
		return gd::as_dict(_read_cache_get(state, session, key::active_town));
	}
	const DictRef result = _find_active_town_result(state, session);
	const DictRef town = gd::as_dict(field_or_new_dict(state, result, key::town));
	_read_cache_store(state, session, key::active_town, dict_value(town));
	return town;
}

ArrayRef get_hero_actions(State &state, DictRef session) {
	if (_read_cache_has(state, session, key::hero_actions)) {
		return gd::as_array(_read_cache_get(state, session, key::hero_actions));
	}
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		const ArrayRef empty = state.new_array();
		_read_cache_store(state, session, key::hero_actions, array_value(empty));
		return empty;
	}
	const ArrayRef actions = hero_command_rules::get_town_switch_actions(state, session, town);
	_read_cache_store(state, session, key::hero_actions, array_value(actions));
	return actions;
}

ArrayRef get_tavern_actions(State &state, DictRef session) {
	if (_read_cache_has(state, session, key::tavern_actions)) {
		return gd::as_array(_read_cache_get(state, session, key::tavern_actions));
	}
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		const ArrayRef empty = state.new_array();
		_read_cache_store(state, session, key::tavern_actions, array_value(empty));
		return empty;
	}
	const ArrayRef actions = hero_command_rules::get_tavern_actions(state, session, town);
	_read_cache_store(state, session, key::tavern_actions, array_value(actions));
	return actions;
}

ArrayRef get_transfer_actions(State &state, DictRef session) {
	if (_read_cache_has(state, session, key::transfer_actions)) {
		return gd::as_array(_read_cache_get(state, session, key::transfer_actions));
	}
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		const ArrayRef empty = state.new_array();
		_read_cache_store(state, session, key::transfer_actions, array_value(empty));
		return empty;
	}
	const ArrayRef actions = hero_command_rules::get_town_transfer_actions(state, session, town);
	_read_cache_store(state, session, key::transfer_actions, array_value(actions));
	return actions;
}

ArrayRef get_artifact_actions(State &state, DictRef session) {
	if (_read_cache_has(state, session, key::artifact_actions)) {
		return gd::as_array(_read_cache_get(state, session, key::artifact_actions));
	}
	const DictRef hero = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero));
	const ArrayRef actions = artifact_rules::get_management_actions(state, hero);
	const DictRef town = get_active_town(state, session);
	ai::append_array(state, actions, _town_artifact_service_actions(state, session, town));
	_read_cache_store(state, session, key::artifact_actions, array_value(actions));
	return actions;
}

DictRef switch_active_hero_at_town(State &state, DictRef session, Atom hero_id) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return refusal(state, key::no_town_is_available_for_command);
	}
	const ArrayRef stationed = hero_command_rules::stationed_heroes(state, session, town);
	bool stationed_here = false;
	for (const Value &hero : gd::items(state, array_value(stationed))) {
		if (gd::is_dict(hero) && text(state, hero.ref, key::id, key::empty) == hero_id) {
			stationed_here = true;
			break;
		}
	}
	if (!stationed_here) {
		return refusal(state, key::only_heroes_stationed_in_the_active);
	}
	const DictRef result = hero_command_rules::set_active_hero(state, session, hero_id);
	if (!gd::bool_field(state, result, key::ok, false)) {
		return refusal(state, text(state, result, key::message, key::unable_to_change_command));
	}
	teach_visiting_heroes(state, session, town);
	return _finalize_town_result(state, session, true, text(state, result, key::message, key::empty));
}

DictRef hire_hero_at_active_town(State &state, DictRef session, Atom hero_id) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return refusal(state, key::no_town_is_available_for_hero);
	}
	const DictRef result = hero_command_rules::recruit_hero_at_town(state, session, town, hero_id);
	if (!gd::bool_field(state, result, key::ok, false)) {
		return refusal(state, text(state, result, key::message, key::hero_recruitment_failed));
	}
	teach_visiting_heroes(state, session, town);
	return _finalize_town_result(state, session, true, text(state, result, key::message, key::empty));
}

DictRef transfer_in_active_town(State &state, DictRef session, Atom action_id) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return refusal(state, key::no_town_is_available_for_transfer);
	}
	const std::vector<Atom> parts = split_text(state, action_id, ":");
	if (parts.size() != 5 || parts[0] != key::transfer) {
		return refusal(state, key::that_transfer_order_is_invalid);
	}
	const DictRef result = hero_command_rules::transfer_town_stack(state, session, town, parts[1], parts[2], parts[3], parts[4]);
	if (!gd::bool_field(state, result, key::ok, false)) {
		return refusal(state, text(state, result, key::message, key::transfer_failed));
	}
	return _finalize_town_result(state, session, true, text(state, result, key::message, key::empty));
}

DictRef manage_army_slots_in_active_town(State &state, DictRef session, Atom source_holder_id, int64_t source_slot_index, Atom target_holder_id, int64_t target_slot_index, Atom amount_token) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return refusal(state, key::no_town_is_available_for_army);
	}
	const DictRef result = hero_command_rules::manage_army_slots(state, session, town, source_holder_id, source_slot_index, target_holder_id, target_slot_index, amount_token);
	if (!gd::bool_field(state, result, key::ok, false)) {
		return result;
	}
	const DictRef finalized = _finalize_town_result(state, session, true, text(state, result, key::message, key::empty));
	copy_result_fields(state, finalized, result);
	return finalized;
}

DictRef set_garrison_hero_in_active_town(State &state, DictRef session, Atom hero_id) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return refusal(state, key::no_town_is_available_for_its);
	}
	const DictRef result = hero_command_rules::set_town_garrison_hero(state, session, town, hero_id);
	if (!gd::bool_field(state, result, key::ok, false)) {
		return result;
	}
	const DictRef finalized = _finalize_town_result(state, session, true, text(state, result, key::message, key::empty));
	copy_result_fields(state, finalized, result);
	return finalized;
}

DictRef manage_artifact_at_active_town(State &state, DictRef session, Atom action_id) {
	if (gd::begins_with(state, action_id, key::commission_artifact)) {
		return _commission_town_artifact(state, session, gd::trim_prefix(state, action_id, key::commission_artifact));
	}
	return overworld_rules::perform_artifact_action(state, session, action_id);
}

ArrayRef _town_artifact_service_actions(State &state, DictRef session, DictRef town) {
	const ArrayRef actions = state.new_array();
	// session == null: a session is its view.
	if (gd::is_empty(state, town) || text(state, town, key::owner, key::neutral) != key::player) {
		return actions;
	}
	if (text(state, town, key::artifact_reward_id, key::empty) != key::empty) {
		return actions;
	}
	const DictRef town_template = gd::content_row(state, ContentTable::Town, text(state, town, key::town_id, key::empty));
	// town_template.get("faction_id", town.get("faction_id", "")): the fallback first.
	const Value town_faction_id = state.get(town, str(key::faction_id), str(key::empty));
	const Atom faction_id = gd::stringify(state, state.get(town_template, str(key::faction_id), town_faction_id));
	const DictRef hero = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero));
	const ArrayRef owned_artifact_ids = artifact_rules::owned_artifact_ids(state, hero);
	for (const Value &building_id_value : gd::field_items(state, town, str(key::built_buildings))) {
		const Atom building_id = gd::stringify(state, building_id_value);
		const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
		Value contract_value;
		Value boundary_value;
		const bool has_contract = state.lookup(building, str(key::artifact_reward_contract), contract_value);
		const bool has_boundary = state.lookup(building, str(key::runtime_boundary), boundary_value);
		if ((has_contract && !gd::is_dict(contract_value)) || (has_boundary && !gd::is_dict(boundary_value))) {
			continue;
		}
		// A missing contract is {}, whose source_tag is "".
		if (!has_contract) {
			continue;
		}
		const DictRef contract = contract_value.ref;
		// A missing boundary is {}, whose artifact_reward_execution is false.
		if (text(state, contract, key::source_tag, key::empty) != key::town
				|| !has_boundary || !gd::bool_field(state, boundary_value.ref, key::artifact_reward_execution, false)) {
			continue;
		}
		const Atom town_id = text(state, town, key::town_id, key::empty);
		// contract.get("allowed_town_ids", []): a missing one is empty, which allows every town.
		Value allowed_town_ids;
		if (state.lookup(contract, str(key::allowed_town_ids), allowed_town_ids) && gd::is_array(allowed_town_ids)
				&& state.array_size(allowed_town_ids.ref) > 0
				&& !gd::array_has(state, allowed_town_ids.ref, str(canonical_town_id(state, town_id)))) {
			continue;
		}
		// contract.get("excluded_town_ids", []): a missing one is an empty Array,
		// whose check still asks for the canonical id.
		Value excluded_town_ids;
		const bool has_excluded = state.lookup(contract, str(key::excluded_town_ids), excluded_town_ids);
		if (!has_excluded || gd::is_array(excluded_town_ids)) {
			const Atom canonical_id = canonical_town_id(state, town_id);
			if (has_excluded && gd::array_has(state, excluded_town_ids.ref, str(canonical_id))) {
				continue;
			}
		}
		const Atom source_key = gd::format(state, key::consequence_cache_key_text, {
				gd::index(state, session, str(key::scenario_id)),
				str(text(state, town, key::placement_id, key::empty)),
				str(building_id),
		});
		const DictRef selection = artifact_rules::select_live_source_reward(state, key::town, building, source_key, faction_id, owned_artifact_ids);
		if (!gd::bool_field(state, selection, key::ok, false)) {
			continue;
		}
		// cost_value.duplicate(true) if cost_value is Dictionary else {}: a
		// missing one is {}, whose copy is a new empty Dictionary.
		Value cost_value;
		const DictRef cost = state.lookup(contract, str(key::service_cost), cost_value) && gd::is_dict(cost_value)
				? gd::as_dict(gd::engine_duplicate(state, cost_value, true))
				: state.new_dict();
		const bool affordable = _can_afford(state, session, dict_value(cost));
		const Atom artifact_id = text(state, selection, key::artifact_id, key::empty);
		const Atom artifact_name = artifact_rules::artifact_name(state, artifact_id);
		const Atom shortfall = _resource_shortfall(state, session, dict_value(cost));
		const Atom action_id = gd::format(state, key::commission_artifact_s, {str(building_id)});
		const Atom label = gd::format(state, key::commission_s, {str(artifact_name)});
		const Atom building_name = text(state, building, key::name, building_id);
		const Atom summary = gd::format(state, key::s_commissions_s_for_s, {
				str(building_name),
				str(artifact_name),
				str(_describe_resources(state, dict_value(cost), key::none)),
		});
		const Atom table_id = text(state, selection, key::table_id, key::empty);
		const DictRef action = state.new_dict();
		state.set(action, str(key::id), str(action_id));
		state.set(action, str(key::label), str(label));
		state.set(action, str(key::summary), str(summary));
		state.set(action, str(key::impact), str(key::the_artifact_is_equipped_when_a));
		state.set(action, str(key::artifact_id), str(artifact_id));
		state.set(action, str(key::artifact_reward_table_id), str(table_id));
		state.set(action, str(key::source_key), str(source_key));
		state.set(action, str(key::building_id), str(building_id));
		state.set(action, str(key::cost), dict_value(cost));
		state.set(action, str(key::shortfall_summary), str(shortfall));
		state.set(action, str(key::disabled), bool_value(!affordable));
		state.append(actions, dict_value(action));
	}
	return actions;
}

DictRef _commission_town_artifact(State &state, DictRef session, Atom building_id) {
	const DictRef town_result = _find_active_town_result(state, session);
	const DictRef town = gd::as_dict(field_or_new_dict(state, town_result, key::town));
	const int64_t town_index = gd::int_field(state, town_result, key::index, -1);
	if (town_index < 0 || gd::is_empty(state, town) || text(state, town, key::owner, key::neutral) != key::player) {
		return refusal(state, key::no_player_town_is_available_for);
	}
	if (text(state, town, key::artifact_reward_id, key::empty) != key::empty) {
		return refusal(state, key::this_town_has_already_completed_its);
	}
	// building_id not in town.get("built_buildings", []): a missing one holds nothing.
	Value built_buildings;
	if (!state.lookup(town, str(key::built_buildings), built_buildings) || !gd::in(state, str(building_id), built_buildings)) {
		return refusal(state, key::that_artifact_service_has_not_been);
	}
	DictRef selected_action = 0;
	bool has_selected_action = false;
	const ArrayRef service_actions = _town_artifact_service_actions(state, session, town);
	for (const Value &action_value : gd::items(state, array_value(service_actions))) {
		if (gd::is_dict(action_value) && text(state, action_value.ref, key::building_id, key::empty) == building_id) {
			selected_action = action_value.ref;
			has_selected_action = true;
			break;
		}
	}
	if (!has_selected_action || gd::is_empty(state, selected_action)) {
		return refusal(state, key::that_building_cannot_provide_an_artifact);
	}
	const DictRef cost = gd::as_dict(field_or_new_dict(state, selected_action, key::cost));
	if (!_can_afford(state, session, dict_value(cost))) {
		const Atom described = _describe_resources(state, dict_value(cost), key::none);
		const Atom shortfall = _resource_shortfall(state, session, dict_value(cost));
		return refusal(state, gd::format(state, key::the_commission_requires_s_shortfall_s, {str(described), str(shortfall)}));
	}
	const Atom artifact_id = text(state, selected_action, key::artifact_id, key::empty);
	const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
	const Atom source_verb = gd::format(state, key::s_commissions, {str(text(state, building, key::name, building_id))});
	// OverworldRules.claim_artifact_for_session(session, artifact_id, verb, true)
	// is _apply_artifact_claim(session, artifact_id, verb, true).
	const DictRef claim = overworld_rules::_apply_artifact_claim(state, session, artifact_id, source_verb, true);
	if (!gd::bool_field(state, claim, key::ok, false) || gd::bool_field(state, claim, key::duplicate, false)) {
		return refusal(state, text(state, claim, key::message, key::the_artifact_commission_failed));
	}
	_spend_resources(state, session, cost);
	// session.overworld.get("towns", []): a missing one is [], which fails the check.
	Value towns_value;
	if (!state.lookup(session_view::overworld(state, session), str(key::towns), towns_value) || !gd::is_array(towns_value)
			|| town_index >= static_cast<int64_t>(state.array_size(towns_value.ref))
			|| !gd::is_dict(state.at(towns_value.ref, town_index))) {
		return refusal(state, key::the_commissioned_artifact_was_granted_but);
	}
	const DictRef updated_town = gd::as_dict(state.at(towns_value.ref, town_index));
	const DictRef town_template = gd::content_row(state, ContentTable::Town, text(state, updated_town, key::town_id, key::empty));
	state.set(updated_town, str(key::artifact_reward_id), str(artifact_id));
	state.set(updated_town, str(key::artifact_reward_table_id), str(text(state, selected_action, key::artifact_reward_table_id, key::empty)));
	state.set(updated_town, str(key::artifact_reward_source_key), str(text(state, selected_action, key::source_key, key::empty)));
	state.set(updated_town, str(key::artifact_reward_claimed_by_owner), str(text(state, updated_town, key::owner, key::player)));
	{
		// town_template.get("faction_id", updated_town.get("faction_id", "")): the fallback first.
		const Value town_faction_id = state.get(updated_town, str(key::faction_id), str(key::empty));
		state.set(updated_town, str(key::artifact_reward_claimed_by_faction_id), str(gd::stringify(state, state.get(town_template, str(key::faction_id), town_faction_id))));
	}
	state.set(updated_town, str(key::artifact_reward_claimed_day), int_value(ai::session_int(state, session, key::day)));
	state.set(updated_town, str(key::artifact_reward_service_building_id), str(building_id));
	state.set_at(towns_value.ref, town_index, dict_value(updated_town));
	state.set(session_view::overworld(state, session), str(key::towns), towns_value);
	const Atom building_name = text(state, building, key::name, building_id);
	const Atom artifact_name = artifact_rules::artifact_name(state, artifact_id);
	const Atom described = _describe_resources(state, dict_value(cost), key::none);
	const DictRef result = _finalize_town_result(state, session, true,
			gd::format(state, key::s_commissioned_s_for_s, {str(building_name), str(artifact_name), str(described)}));
	state.set(result, str(key::artifact_id), str(artifact_id));
	state.set(result, str(key::artifact_reward_table_id), str(text(state, selected_action, key::artifact_reward_table_id, key::empty)));
	state.set(result, str(key::cost), gd::engine_duplicate(state, dict_value(cost), true));
	return result;
}

DictRef _find_active_town_result(State &state, DictRef session) {
	// OverworldRules.active_town_visit_result(session) is _find_active_town(session).
	return overworld_rules::_find_active_town(state, session);
}

bool _can_afford(State &state, DictRef session, const Value &cost) {
	// session.overworld.get("resources", {}): a missing one is {}, which reads 0.
	Value resources;
	const bool has_resources = state.lookup(session_view::overworld(state, session), str(key::resources), resources);
	if (!gd::is_dict(cost)) {
		return true;
	}
	const ArrayRef cost_keys = gd::keys(state, cost.ref);
	for (const Value &cost_key : gd::items(state, array_value(cost_keys))) {
		const int64_t available = has_resources
				? gd::to_int(state, ai::vget(state, resources, str(gd::stringify(state, cost_key)), int_value(0)))
				: 0;
		if (available < gd::to_int(state, gd::index(state, cost.ref, cost_key))) {
			return false;
		}
	}
	return true;
}

Atom _resource_shortfall(State &state, DictRef session, const Value &cost) {
	if (!gd::is_dict(cost)) {
		return key::none;
	}
	// session.overworld.get("resources", {}): a missing one is {}, which reads 0.
	Value resources;
	const bool has_resources = state.lookup(session_view::overworld(state, session), str(key::resources), resources);
	const DictRef missing = state.new_dict();
	const ArrayRef cost_keys = gd::keys(state, cost.ref);
	for (const Value &key_value : gd::items(state, array_value(cost_keys))) {
		const Atom resource_key = gd::stringify(state, key_value);
		const int64_t needed = gd::to_int(state, state.get(cost.ref, key_value, int_value(0)));
		const int64_t available = has_resources ? gd::to_int(state, ai::vget(state, resources, str(resource_key), int_value(0))) : 0;
		const int64_t amount = std::max<int64_t>(0, gd::sub(needed, available));
		if (amount > 0) {
			state.set(missing, str(resource_key), int_value(amount));
		}
	}
	return _describe_resources(state, dict_value(missing), key::none);
}

void _spend_resources(State &state, DictRef session, DictRef cost) {
	Value resources_value;
	const bool has_resources = state.lookup(session_view::overworld(state, session), str(key::resources), resources_value);
	// var resources: Dictionary = resources_value if resources_value is Dictionary else {}
	const DictRef resources = has_resources && gd::is_dict(resources_value) ? resources_value.ref : state.new_dict();
	const ArrayRef cost_keys = gd::keys(state, cost);
	for (const Value &key_value : gd::items(state, array_value(cost_keys))) {
		const Atom resource_key = gd::stringify(state, key_value);
		const int64_t available = gd::to_int(state, state.get(resources, str(resource_key), int_value(0)));
		const int64_t spent = gd::to_int(state, state.get(cost, key_value, int_value(0)));
		state.set(resources, str(resource_key), int_value(std::max<int64_t>(0, gd::sub(available, spent))));
	}
	state.set(session_view::overworld(state, session), str(key::resources), dict_value(resources));
}

Atom _describe_resources(State &state, const Value &resources, Atom empty_label) {
	if (!gd::is_dict(resources)) {
		return empty_label;
	}
	const ArrayRef parts = state.new_array();
	const ArrayRef resource_keys = _resource_keys_for_payload(state, resources);
	for (const Value &resource_key : gd::items(state, array_value(resource_keys))) {
		const int64_t amount = gd::to_int(state, state.get(resources.ref, resource_key, int_value(0)));
		if (amount > 0) {
			state.append(parts, str(gd::format(state, key::_d_s, {int_value(amount), resource_key})));
		}
	}
	return state.array_size(parts) > 0 ? join_array(state, key::comma_space, parts) : empty_label;
}

ArrayRef _resource_keys_for_payload(State &state, const Value &value) {
	const ArrayRef resource_keys = state.new_array();
	for (const Atom resource_key : kLiveStockpileKeys) {
		if (!gd::array_has(state, resource_keys, str(resource_key))) {
			state.append(resource_keys, str(resource_key));
		}
	}
	if (gd::is_dict(value)) {
		const ArrayRef value_keys = gd::keys(state, value.ref);
		for (const Value &key_value : gd::items(state, array_value(value_keys))) {
			const Atom resource_key = gd::stringify(state, key_value);
			if (resource_key == key::experience || resource_key == key::empty) {
				continue;
			}
			if (!gd::array_has(state, resource_keys, str(resource_key))) {
				state.append(resource_keys, str(resource_key));
			}
		}
	}
	return resource_keys;
}

DictRef _finalize_town_result(State &state, DictRef session, bool ok, Atom base_message) {
	hero_command_rules::commit_active_hero(state, session);
	overworld_rules::refresh_fog_of_war(state, session);
	const ArrayRef messages = state.new_array();
	if (base_message != key::empty) {
		state.append(messages, str(base_message));
	}

	const DictRef scenario_result = scenario_rules::evaluate_session(state, session);
	const Atom scenario_message = text(state, scenario_result, key::message, key::empty);
	hero_command_rules::commit_active_hero(state, session);
	overworld_rules::refresh_fog_of_war(state, session);
	if (scenario_message != key::empty) {
		state.append(messages, str(scenario_message));
	}

	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(ok));
	state.set(result, str(key::message), str(join_array(state, key::space, messages)));
	state.set(result, str(key::scenario_status), gd::index(state, session, str(key::scenario_status)));
	return result;
}

} // namespace town_rules

} // namespace aurelion::rules::port
