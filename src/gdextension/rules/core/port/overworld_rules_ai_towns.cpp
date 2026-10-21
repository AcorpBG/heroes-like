// OverworldRules: resource-node interaction tiles, a site's guard and spells,
// town build status and options, town income and the occupation state.

#include "aurelion_rules/port/overworld_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/mine_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/town_development_rules_ai.hpp"

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

// d.get(key, {}) where the result is passed on: the value, or a new Dictionary.
Value dict_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// Vector2i(int(d.get("x", 0)), int(d.get("y", 0))) as a Value.
Value tile_of(State &state, DictRef dict) {
	const Vector2i tile = Vector2i::of(gd::int_field(state, dict, key::x, 0), gd::int_field(state, dict, key::y, 0));
	return Value::of_vector2i(tile.x, tile.y);
}

// separator.join(items) of an Array of Strings.
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

// OverworldRules._resource_site_guard_targets_node.
bool guard_targets_node(State &state, DictRef guard, DictRef node, DictRef site) {
	const Atom node_placement_id = ai::string_or_empty(state, node, key::placement_id);
	const Atom site_id = gd::stringify(state, state.get(site, str(key::id), state.get(node, str(key::site_id), str(key::empty))));
	const Atom target_placement_id = ai::string_or_empty(state, guard, key::target_placement_id);
	const Atom target_id = ai::string_or_empty(state, guard, key::target_id);
	if (target_placement_id != key::empty) {
		return target_placement_id == node_placement_id;
	}
	if (target_id != key::empty && (target_id == node_placement_id || target_id == site_id)) {
		return true;
	}
	return false;
}

// OverworldRules._resource_site_guard_encounter (a session is never null here).
DictRef guard_encounter(State &state, DictRef session, DictRef node, DictRef site, const Value &positions) {
	const Atom guard_front_id = ai::string_or_empty(state, node, key::guard_front_id);
	Value encounters;
	if (!state.lookup(session_view::overworld(state, session), str(key::encounters), encounters)) {
		encounters = array_value(state.new_array());
	}
	if (gd::is_array(positions)) {
		const ArrayRef listed = state.new_array();
		for (const Value &position : gd::items(state, positions)) {
			state.append(listed, ai::vindex(state, encounters, int_value(gd::to_int(state, position))));
		}
		encounters = array_value(listed);
	}
	for (const Value &encounter : gd::items(state, encounters)) {
		if (!gd::is_dict(encounter) || overworld_rules::is_encounter_resolved(state, session, encounter.ref)) {
			continue;
		}
		if (guard_front_id != key::empty && guard_front_id == ai::string_or_empty(state, encounter.ref, key::placement_id)) {
			return encounter.ref;
		}
		const DictRef guard = overworld_rules::_resource_site_guard_link_for_encounter(state, encounter.ref);
		if (gd::is_empty(state, guard)) {
			continue;
		}
		if (guard_targets_node(state, guard, node, site)) {
			return encounter.ref;
		}
	}
	return state.new_dict();
}

// OverworldRules._resource_site_guard_blocks_node.
bool guard_blocks_node(State &state, DictRef encounter, DictRef node) {
	if (gd::is_empty(state, encounter)) {
		return false;
	}
	const Atom explicit_guard_front_id = ai::string_or_empty(state, node, key::guard_front_id);
	if (explicit_guard_front_id != key::empty && explicit_guard_front_id == ai::string_or_empty(state, encounter, key::placement_id)) {
		return true;
	}
	const DictRef guard_link = overworld_rules::_resource_site_guard_link_for_encounter(state, encounter);
	return gd::bool_field(state, guard_link, key::clear_required_for_target, false);
}

} // namespace

namespace overworld_rules {

ArrayRef _resource_node_world_interaction_tiles(State &state, DictRef map_object, DictRef placement) {
	if (mine_rules::resource(state, placement) != key::empty) {
		const ArrayRef tiles = state.new_array();
		const Vector2i entry = mine_rules::entry_tile(state, placement);
		state.append(tiles, Value::of_vector2i(entry.x, entry.y));
		return tiles;
	}
	if (_resource_node_has_runtime_visit_tile(state, placement)) {
		// Present and a Dictionary: _resource_node_has_runtime_visit_tile checked it.
		const DictRef visit_tile = gd::as_dict(gd::index(state, placement, str(key::visit_tile)));
		const ArrayRef tiles = state.new_array();
		state.append(tiles, tile_of(state, visit_tile));
		return tiles;
	}
	if (ai::string_or_empty(state, map_object, key::passability_class) == key::passable_visit_on_enter) {
		const ArrayRef tiles = state.new_array();
		state.append(tiles, tile_of(state, placement));
		return tiles;
	}
	return _map_object_world_interaction_tiles(state, map_object, placement);
}

bool _resource_node_has_runtime_visit_tile(State &state, DictRef node) {
	Value visit_tile;
	return state.lookup(node, str(key::visit_tile), visit_tile) && gd::is_dict(visit_tile) && !gd::is_empty(state, visit_tile.ref);
}

int64_t _week_of_day(State &state, int64_t day) {
	(void)state;
	const int64_t first = compat::engine_max<int64_t>(day, 1);
	return gd::add(compat::float_to_int(compat::godot_floor(static_cast<double>(first - 1) / 7.0)), 1);
}

DictRef town_income(State &state, DictRef town, const Value &session) {
	return _calculate_town_income(state, town, session);
}

DictRef town_market_state(State &state, DictRef town) {
	return _town_market_state(state, town);
}

DictRef get_town_build_status(State &state, DictRef town, Atom building_id, int64_t current_day) {
	// Town screens check every building's status many times per refresh.
	const Atom cache_key = _town_content_read_scope_key(state, key::build_status, town, gd::format(state, key::s_d, {str(building_id), int_value(current_day)}));
	if (_town_read_scope_cache_has(state, cache_key)) {
		const DictRef cache = ai::static_dict(state, key::overworld_rules_script, key::_normalized_read_scope_cache);
		return _build_status_copy(state, gd::as_dict(gd::index(state, cache, str(cache_key))));
	}
	const DictRef status = _town_build_status(state, town, building_id, current_day);
	if (cache_key != key::empty) {
		const DictRef copy = _build_status_copy(state, status);
		state.set(ai::static_dict(state, key::overworld_rules_script, key::_normalized_read_scope_cache), str(cache_key), dict_value(copy));
		const int64_t entries = state.dict_size(ai::static_dict(state, key::overworld_rules_script, key::_normalized_read_scope_cache));
		state.set(ai::static_dict(state, key::overworld_rules_script, key::_last_normalized_read_scope_cache_profile), str(key::entries), int_value(entries));
	}
	return status;
}

DictRef _town_build_status(State &state, DictRef town, Atom building_id, int64_t current_day) {
	return _town_build_status_in(state, _town_build_context(state, town), town, building_id, current_day);
}

DictRef _town_build_context(State &state, DictRef town) {
	const bool current = town_development_rules::is_current(state, town);
	const ArrayRef built_buildings = _normalize_built_buildings_for_town_state(state, town);
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	const ArrayRef buildable_ids = state.new_array();
	for (const Value &buildable_id_value : gd::field_items(state, town_template, str(key::buildable_building_ids))) {
		state.append(buildable_ids, str(gd::stringify(state, buildable_id_value)));
	}
	const DictRef satisfied = town_development_rules::satisfied_ids(state, built_buildings);
	const Atom faction_id = ai::string_or_empty(state, town_template, key::faction_id);
	const DictRef context = state.new_dict();
	state.set(context, str(key::current), bool_value(current));
	state.set(context, str(key::built), array_value(built_buildings));
	state.set(context, str(key::satisfied), dict_value(satisfied));
	state.set(context, str(key::buildable_ids), array_value(buildable_ids));
	state.set(context, str(key::faction_id), str(faction_id));
	return context;
}

DictRef _town_build_status_in(State &state, DictRef context, DictRef town, Atom building_id, int64_t current_day) {
	const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
	if (gd::is_empty(state, building)) {
		const DictRef missing = state.new_dict();
		state.set(missing, str(key::buildable), bool_value(false));
		const ArrayRef missing_blockers = state.new_array();
		state.append(missing_blockers, str(key::missing_authored_building_data));
		state.set(missing, str(key::blockers), array_value(missing_blockers));
		state.set(missing, str(key::blocked_message), str(key::that_building_has_no_authored_data));
		return missing;
	}

	const ArrayRef built_buildings = gd::as_array(gd::index(state, context, str(key::built)));
	const DictRef satisfied = gd::as_dict(gd::index(state, context, str(key::satisfied)));
	// A current town's built stages are its active stages.
	const bool current = gd::to_bool(gd::index(state, context, str(key::current)));
	const ArrayRef blockers = state.new_array();
	if (!gd::in(state, str(building_id), gd::index(state, context, str(key::buildable_ids)))) {
		state.append(blockers, str(key::not_authored_for_this_town));
	}
	if (state.has(satisfied, str(building_id))) {
		state.append(blockers, str(key::already_built));
	}
	if (current ? town_development_rules::choice_blocked_among(state, built_buildings, building) : town_development_rules::choice_blocked(state, town, building)) {
		state.append(blockers, str(key::the_other_dwelling_at_this_tier));
	}
	const int64_t required_tier = gd::int_field(state, building, key::requires_dwelling_tier, 0);
	if (required_tier > 0 && !(current ? town_development_rules::has_dwelling_tier_among(state, built_buildings, required_tier) : town_development_rules::has_dwelling_tier(state, town, required_tier))) {
		state.append(blockers, str(gd::format(state, key::requires_either_tier_d_dwelling, {int_value(required_tier)})));
	}
	if (current_day > 0 && gd::int_field(state, town, key::last_build_day, 0) == current_day) {
		state.append(blockers, str(key::already_built_in_this_town_today));
	}
	const ArrayRef missing_requirements = _missing_build_requirements_among(state, building, satisfied);
	for (const Value &requirement_id : gd::items(state, array_value(missing_requirements))) {
		const DictRef requirement = gd::content_row(state, ContentTable::Building, gd::stringify(state, requirement_id));
		const Atom requirement_name = gd::stringify(state, state.get(requirement, str(key::name), requirement_id));
		if (ai::string_or_empty(state, building, key::upgrade_from) == gd::stringify(state, requirement_id)) {
			state.append(blockers, str(gd::format(state, key::upgrade_s_first, {str(requirement_name)})));
		} else {
			state.append(blockers, str(gd::format(state, key::requires_s, {str(requirement_name)})));
		}
	}

	const Atom building_faction_id = ai::string_or_empty(state, building, key::faction_id);
	const Atom town_faction_id = gd::stringify(state, gd::index(state, context, str(key::faction_id)));
	if (building_faction_id != key::empty && town_faction_id != key::empty && building_faction_id != town_faction_id) {
		const DictRef faction = gd::content_row(state, ContentTable::Faction, building_faction_id);
		const Atom faction_name = gd::stringify(state, state.get(faction, str(key::name), str(building_faction_id)));
		state.append(blockers, str(gd::format(state, key::belongs_to_s_towns, {str(faction_name)})));
	}

	const DictRef status = state.new_dict();
	state.set(status, str(key::buildable), bool_value(state.array_size(blockers) == 0));
	state.set(status, str(key::blockers), array_value(blockers));
	state.set(status, str(key::blocked_message), str(join_items(state, key::space, blockers)));
	state.set(status, str(key::building), dict_value(building));
	return status;
}

ArrayRef _missing_build_requirements_among(State &state, DictRef building, DictRef satisfied) {
	const ArrayRef missing = state.new_array();
	const Atom upgrade_from = ai::string_or_empty(state, building, key::upgrade_from);
	if (upgrade_from != key::empty && !state.has(satisfied, str(upgrade_from))) {
		state.append(missing, str(upgrade_from));
	}
	for (const Value &requirement_value : gd::field_items(state, building, str(key::requires_))) {
		const Atom requirement = gd::stringify(state, requirement_value);
		if (requirement == key::empty || state.has(satisfied, str(requirement)) || gd::array_has(state, missing, str(requirement))) {
			continue;
		}
		state.append(missing, str(requirement));
	}
	return missing;
}

ArrayRef get_town_build_options(State &state, DictRef town, int64_t current_day) {
	const ArrayRef options = state.new_array();
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	// Outside a read scope each status is computed afresh, so they can share
	// one reading of the town.
	const DictRef context = ai::static_int(state, key::overworld_rules_script, key::_normalized_read_scope_depth) <= 0 ? _town_build_context(state, town) : state.new_dict();
	for (const Value &building_id_value : gd::field_items(state, town_template, str(key::buildable_building_ids))) {
		const Atom building_id = gd::stringify(state, building_id_value);
		const DictRef status = gd::is_empty(state, context) ? get_town_build_status(state, town, building_id, current_day) : _town_build_status_in(state, context, town, building_id, current_day);
		if (gd::bool_field(state, status, key::buildable, false)) {
			state.append(options, str(building_id));
		}
	}
	return options;
}

DictRef resource_site_blocking_guard(State &state, DictRef session, DictRef node, DictRef site, const Value &positions) {
	const DictRef encounter = guard_encounter(state, session, node, site, positions);
	return guard_blocks_node(state, encounter, node) ? encounter : state.new_dict();
}

DictRef _resource_site_guard_link_for_encounter(State &state, DictRef encounter) {
	Value guard;
	if (state.lookup(encounter, str(key::guard_link), guard) && gd::is_dict(guard) && !gd::is_empty(state, guard.ref)) {
		return guard.ref;
	}
	const DictRef metadata = _encounter_neutral_metadata(state, encounter);
	if (!state.lookup(metadata, str(key::guard_link), guard)) {
		return state.new_dict();
	}
	return gd::is_dict(guard) ? guard.ref : state.new_dict();
}

DictRef _encounter_neutral_metadata(State &state, DictRef encounter) {
	Value metadata;
	if (state.lookup(encounter, str(key::neutral_encounter), metadata) && gd::is_dict(metadata) && !gd::is_empty(state, metadata.ref)) {
		return metadata.ref;
	}
	const DictRef map_object = gd::content_row(state, ContentTable::MapObject, ai::string_or_empty(state, encounter, key::object_id));
	if (!state.lookup(map_object, str(key::neutral_encounter), metadata)) {
		return state.new_dict();
	}
	return gd::is_dict(metadata) ? metadata.ref : state.new_dict();
}

ArrayRef _resource_site_spell_ids(State &state, DictRef site) {
	const ArrayRef result = state.new_array();
	const Atom legacy_spell_id = gd::strip_edges(state, ai::string_or_empty(state, site, key::learn_spell_id));
	if (legacy_spell_id != key::empty) {
		state.append(result, str(legacy_spell_id));
	}
	Value authored_spell_ids;
	if (state.lookup(site, str(key::learn_spell_ids), authored_spell_ids) && gd::is_array(authored_spell_ids)) {
		for (const Value &spell_id_value : gd::items(state, authored_spell_ids)) {
			const Atom spell_id = gd::strip_edges(state, gd::stringify(state, spell_id_value));
			if (spell_id != key::empty && !gd::array_has(state, result, str(spell_id))) {
				state.append(result, str(spell_id));
			}
		}
	}
	return result;
}

DictRef _calculate_town_income(State &state, DictRef town, const Value &session) {
	DictRef income = _empty_live_resource_stockpile(state);
	if (town_development_rules::is_current(state, town)) {
		income = _add_resource_sets(state, dict_value(income), dict_value(town_development_rules::income(state, town)));
		if (session.kind != Kind::Nil) {
			const DictRef occupation = _town_occupation_state(state, session.ref, town);
			income = _apply_resource_percent_scale(state, dict_value(income), gd::sub(100, gd::int_field(state, occupation, key::income_penalty_percent, 0)));
		}
		return income;
	}
	const ArrayRef built_buildings = _normalize_built_buildings_for_town_state(state, town);
	for (const Value &building_id_value : gd::items(state, array_value(built_buildings))) {
		const DictRef building = gd::content_row(state, ContentTable::Building, gd::stringify(state, building_id_value));
		income = _add_resource_sets(state, dict_value(income), dict_or_new(state, building, key::income));
	}
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	const DictRef faction = gd::content_row(state, ContentTable::Faction, ai::string_or_empty(state, town_template, key::faction_id));
	income = _add_resource_sets(state, dict_value(income), dict_value(_economy_profile_income(state, dict_or_new(state, faction, key::economy), built_buildings)));
	income = _add_resource_sets(state, dict_value(income), dict_value(_economy_profile_income(state, dict_or_new(state, town_template, key::economy), built_buildings)));
	if (session.kind != Kind::Nil) {
		const DictRef occupation = _town_occupation_state(state, session.ref, town);
		income = _apply_resource_percent_scale(state, dict_value(income), gd::sub(100, gd::int_field(state, occupation, key::income_penalty_percent, 0)));
	}
	return income;
}

DictRef _normalize_town_occupation_state(State &state, const Value &value) {
	const bool is_dict = gd::is_dict(value);
	const DictRef normalized = state.new_dict();
	state.set(normalized, str(key::state), str(is_dict ? ai::string_or_empty(state, value.ref, key::state) : key::empty));
	state.set(normalized, str(key::faction_id), str(is_dict ? ai::string_or_empty(state, value.ref, key::faction_id) : key::empty));
	state.set(normalized, str(key::pressure), int_value(is_dict ? compat::engine_max<int64_t>(0, gd::int_field(state, value.ref, key::pressure, 0)) : 0));
	state.set(normalized, str(key::initial_pressure), int_value(is_dict ? compat::engine_max<int64_t>(0, gd::int_field(state, value.ref, key::initial_pressure, 0)) : 0));
	state.set(normalized, str(key::start_day), int_value(is_dict ? compat::engine_max<int64_t>(0, gd::int_field(state, value.ref, key::start_day, 0)) : 0));
	state.set(normalized, str(key::last_event_day), int_value(is_dict ? compat::engine_max<int64_t>(0, gd::int_field(state, value.ref, key::last_event_day, 0)) : 0));
	state.set(normalized, str(key::last_owner), str(is_dict ? ai::string_or_empty(state, value.ref, key::last_owner) : key::empty));
	state.set(normalized, str(key::source), str(is_dict ? ai::string_or_empty(state, value.ref, key::source) : key::empty));
	state.set(normalized, str(key::locked_recruits), dict_value(is_dict ? _normalize_recruit_payload(state, dict_or_new(state, value.ref, key::locked_recruits)) : state.new_dict()));

	if (is_dict && ai::string_or_empty(state, value.ref, key::player_id) != key::empty) {
		state.set(normalized, str(key::player_id), str(gd::stringify(state, gd::index(state, value.ref, str(key::player_id)))));
	}
	return normalized;
}

DictRef _town_occupation_state(State &state, DictRef session, DictRef town) {
	const DictRef occupation = _normalize_town_occupation_state(state, dict_or_new(state, town, key::occupation));
	const Atom faction_id = player_identity_rules::controller_id(state, occupation, key::empty);
	const int64_t pressure = compat::engine_max<int64_t>(0, gd::int_field(state, occupation, key::pressure, 0));
	Atom enemy_label = key::empty;
	if (faction_id != key::empty) {
		const DictRef faction = gd::content_row(state, ContentTable::Faction, player_identity_rules::faction_id(state, session, faction_id));
		enemy_label = gd::stringify(state, state.get(faction, str(key::name), str(faction_id)));
	}
	const int64_t initial_pressure = compat::engine_max<int64_t>(pressure, gd::int_field(state, occupation, key::initial_pressure, 0));
	const DictRef locked_recruits = _normalize_recruit_payload(state, dict_or_new(state, occupation, key::locked_recruits));
	const DictRef result = state.new_dict();
	state.set(result, str(key::active), bool_value(false));
	state.set(result, str(key::mode), str(key::empty));
	state.set(result, str(key::faction_id), str(faction_id));
	state.set(result, str(key::enemy_label), str(enemy_label));
	state.set(result, str(key::pressure), int_value(pressure));
	state.set(result, str(key::initial_pressure), int_value(initial_pressure));
	state.set(result, str(key::days_active), int_value(0));
	state.set(result, str(key::relief_per_day), int_value(0));
	state.set(result, str(key::days_to_clear), int_value(0));
	state.set(result, str(key::income_penalty_percent), int_value(0));
	state.set(result, str(key::growth_penalty_percent), int_value(0));
	state.set(result, str(key::quality_penalty), int_value(0));
	state.set(result, str(key::readiness_penalty), int_value(0));
	state.set(result, str(key::pressure_penalty), int_value(0));
	state.set(result, str(key::locked_recruits), dict_value(locked_recruits));
	state.set(result, str(key::locked_headcount), int_value(0));
	state.set(result, str(key::summary), str(key::empty));
	state.set(result, str(key::compact_summary), str(key::empty));
	state.set(result, str(key::public_clause), str(key::empty));
	state.set(result, str(key::target_bonus), int_value(0));
	state.set(result, str(key::state), dict_value(occupation));
	gd::merge(state, result, player_identity_rules::identity_fields(state, session, faction_id), true);
	state.set(result, str(key::locked_headcount), int_value(_recruit_payload_total(state, dict_or_new(state, result, key::locked_recruits))));
	if (gd::stringify(state, gd::field_or(state, town, key::owner, str(key::neutral))) != key::player) {
		return result;
	}
	if (ai::string_or_empty(state, occupation, key::state) != key::pacifying || faction_id == key::empty || pressure <= 0) {
		return result;
	}
	const DictRef logistics = _town_logistics_state(state, session, town);
	const DictRef recovery = _town_recovery_state(state, session, town, state.new_dict());
	const DictRef front = _town_occupation_front_proxy(state, session, town, faction_id);
	const bool front_active = gd::bool_field(state, front, key::active, false) && player_identity_rules::controller_id(state, front, key::empty) == faction_id;
	const int64_t relief_per_day = _town_occupation_relief_per_day(state, session, town, logistics, recovery, front);
	const int64_t days_to_clear = compat::float_to_int(compat::godot_ceil(static_cast<double>(pressure) / static_cast<double>(compat::engine_max<int64_t>(1, relief_per_day))));
	const int64_t income_penalty = compat::engine_clamp<int64_t>(
			gd::add(gd::add(gd::add(18, gd::mul(pressure, 8)), gd::mul(gd::int_field(state, logistics, key::support_gap, 0), 6)), front_active ? 10 : 0),
			20,
			75);
	const int64_t growth_penalty = compat::engine_clamp<int64_t>(
			gd::add(gd::add(gd::add(12, gd::mul(pressure, 9)), gd::mul(gd::int_field(state, logistics, key::support_gap, 0), 5)), gd::mul(gd::int_field(state, recovery, key::pressure, 0), 6)),
			15,
			80);
	const int64_t quality_penalty = gd::add(gd::add(gd::mul(pressure, 3), gd::mul(gd::int_field(state, logistics, key::support_gap, 0), 2)), front_active ? 6 : 0);
	const int64_t readiness_penalty = gd::add(gd::add(gd::mul(pressure, 4), gd::mul(gd::int_field(state, logistics, key::support_gap, 0), 3)), front_active ? 8 : 0);
	const int64_t pressure_penalty = compat::engine_max<int64_t>(1, compat::float_to_int(compat::godot_ceil(static_cast<double>(quality_penalty) / 5.0)));
	const int64_t locked_headcount = gd::int_field(state, result, key::locked_headcount, 0);
	const Atom reserve_clause = locked_headcount > 0
			? gd::format(state, key::d_held_levy_s, {int_value(locked_headcount), str(locked_headcount == 1 ? key::empty : key::ies)})
			: key::musters_still_sorting_under_occupation_orders;
	const int64_t day = ai::session_int(state, session, key::day);
	state.set(result, str(key::active), bool_value(true));
	state.set(result, str(key::mode), str(key::pacifying));
	state.set(result, str(key::days_active), int_value(compat::engine_max<int64_t>(0, gd::sub(day, gd::int_field(state, occupation, key::start_day, day)))));
	state.set(result, str(key::relief_per_day), int_value(relief_per_day));
	state.set(result, str(key::days_to_clear), int_value(days_to_clear));
	state.set(result, str(key::income_penalty_percent), int_value(income_penalty));
	state.set(result, str(key::growth_penalty_percent), int_value(growth_penalty));
	state.set(result, str(key::quality_penalty), int_value(quality_penalty));
	state.set(result, str(key::readiness_penalty), int_value(readiness_penalty));
	state.set(result, str(key::pressure_penalty), int_value(pressure_penalty));
	const Atom summary = gd::format(state, key::s_remains_under_pacification_for_d, {str(_town_name(state, town)), int_value(days_to_clear), str(days_to_clear == 1 ? key::empty : key::s), int_value(income_penalty), str(reserve_clause)});
	state.set(result, str(key::summary), str(summary));
	const Atom compact_summary = gd::format(state, key::s_pacifies_in_d_day_s, {str(_town_name(state, town)), int_value(days_to_clear), str(days_to_clear == 1 ? key::empty : key::s)});
	state.set(result, str(key::compact_summary), str(compact_summary));
	state.set(result, str(key::public_clause), str(key::occupation_still_thins_the_local_musters));
	const int64_t target_bonus = gd::add(gd::add(gd::add(gd::mul(pressure, 12), gd::mul(locked_headcount, 2)), gd::mul(gd::int_field(state, logistics, key::support_gap, 0), 10)), front_active ? 18 : 0);
	state.set(result, str(key::target_bonus), int_value(target_bonus));
	return result;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
