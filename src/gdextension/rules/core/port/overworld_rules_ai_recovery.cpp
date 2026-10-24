// OverworldRules: a town's recovery state, occupation relief and retake front,
// its name and faction, and a resource site's linked town and threats.

#include "aurelion_rules/port/overworld_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

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

// d.get(key, {}) where the result is passed on: the value, or a new Dictionary.
Value dict_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// String(town.get("owner", "neutral")).
Atom town_owner(State &state, DictRef town) {
	return gd::stringify(state, gd::field_or(state, town, key::owner, str(key::neutral)));
}

// {"index": -1, "town": {}}.
DictRef no_town(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::index), int_value(-1));
	state.set(result, str(key::town), dict_value(state.new_dict()));
	return result;
}

} // namespace

namespace overworld_rules {

DictRef _resource_node_linked_town(State &state, DictRef session, DictRef node, Atom controller_id) {
	const DictRef town_result = _nearest_town_for_controller(
			state,
			session,
			controller_id,
			gd::int_field(state, node, key::x, 0),
			gd::int_field(state, node, key::y, 0),
			overworld_level_rules::level_of(state, dict_value(node)));
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return no_town(state);
	}
	const Value town = dict_or_new(state, town_result, key::town);
	const int64_t distance = gd::add(
			compat::absi(gd::sub(gd::int_field(state, node, key::x, 0), gd::to_int(state, ai::vget(state, town, key::x, int_value(0))))),
			compat::absi(gd::sub(gd::int_field(state, node, key::y, 0), gd::to_int(state, ai::vget(state, town, key::y, int_value(0))))));
	if (distance > gd::int_field(state, _town_logistics_plan(state, gd::as_dict(town)), key::support_radius, 0)) {
		return no_town(state);
	}
	return town_result;
}

DictRef _town_recovery_state(State &state, DictRef session, DictRef town, DictRef logistics_state) {
	return _town_recovery_state(state, dict_value(session), town, logistics_state);
}

DictRef _town_recovery_state(State &state, const Value &session, DictRef town, DictRef logistics_state) {
	const DictRef recovery = _normalize_town_recovery_state(state, dict_or_new(state, town, key::recovery));
	const int64_t pressure = compat::engine_max<int64_t>(0, gd::int_field(state, recovery, key::pressure, 0));
	const int64_t relief_rating = _town_recovery_relief_rating(state, session, town, logistics_state);
	const int64_t relief_per_day = compat::engine_max<int64_t>(1, gd::add(1, compat::float_to_int(compat::godot_floor(static_cast<double>(relief_rating) / 3.0))));
	const int64_t readiness_penalty = gd::mul(pressure, 6);
	const int64_t quality_penalty = gd::mul(pressure, 4);
	const int64_t pressure_penalty = compat::float_to_int(compat::godot_ceil(static_cast<double>(pressure) / 2.0));
	const int64_t growth_penalty_percent = compat::engine_clamp<int64_t>(gd::mul(pressure, 12), 0, 60);
	const int64_t days_to_clear = pressure <= 0 ? 0 : compat::float_to_int(compat::godot_ceil(static_cast<double>(pressure) / static_cast<double>(relief_per_day)));
	Atom summary = key::steady;
	if (pressure > 0) {
		summary = gd::format(state, key::d_pressure_d_readiness_d_recruits, {int_value(pressure), int_value(readiness_penalty), int_value(growth_penalty_percent), int_value(relief_per_day)});
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::active), bool_value(pressure > 0));
	state.set(result, str(key::pressure), int_value(pressure));
	state.set(result, str(key::last_event_day), int_value(gd::int_field(state, recovery, key::last_event_day, 0)));
	state.set(result, str(key::source), str(ai::string_or_empty(state, recovery, key::source)));
	state.set(result, str(key::relief_rating), int_value(relief_rating));
	state.set(result, str(key::relief_per_day), int_value(relief_per_day));
	state.set(result, str(key::readiness_penalty), int_value(readiness_penalty));
	state.set(result, str(key::quality_penalty), int_value(quality_penalty));
	state.set(result, str(key::pressure_penalty), int_value(pressure_penalty));
	state.set(result, str(key::growth_penalty_percent), int_value(growth_penalty_percent));
	state.set(result, str(key::days_to_clear), int_value(days_to_clear));
	state.set(result, str(key::summary), str(summary));
	return result;
}

DictRef _town_occupation_front_proxy(State &state, DictRef session, DictRef town, Atom faction_id) {
	DictRef front = _normalize_town_front_state(state, dict_or_new(state, town, key::front));
	front = _retake_front_from_legacy_state(state, session, town, front);
	const Atom front_faction_id = _normalized_enemy_front_faction_id(state, session, front, town);
	const bool active = town_owner(state, town) == key::player
			&& ai::string_or_empty(state, front, key::state) == key::retake
			&& front_faction_id != key::empty
			&& front_faction_id == faction_id;
	// {...}.merged(identity, true): a new Dictionary either way.
	const DictRef result = state.new_dict();
	state.set(result, str(key::active), bool_value(active));
	state.set(result, str(key::mode), str(active ? key::retake : key::empty));
	state.set(result, str(key::faction_id), str(front_faction_id));
	gd::merge(state, result, player_identity_rules::identity_fields(state, session, front_faction_id), true);
	return result;
}

int64_t _town_occupation_relief_per_day(State &state, DictRef session, DictRef town, DictRef logistics, DictRef recovery, DictRef front) {
	if (gd::is_empty(state, logistics)) {
		logistics = _town_logistics_state(state, session, town);
	}
	if (gd::is_empty(state, recovery)) {
		recovery = _town_recovery_state(state, session, town, state.new_dict());
	}
	// The only caller (_town_occupation_state) passes a front proxy, never an empty front.
	if (gd::is_empty(state, front)) {
		front = _town_front_state(state, session, town, state.new_dict());
	}
	int64_t relief = gd::add(1, compat::float_to_int(compat::godot_floor(static_cast<double>(_town_recovery_relief_rating(state, session, town, state.new_dict())) / 4.0)));
	relief = gd::add(relief, compat::engine_min<int64_t>(2, gd::int_field(state, logistics, key::met_requirements, 0)));
	relief = gd::sub(relief, gd::int_field(state, logistics, key::support_gap, 0));
	if (gd::bool_field(state, recovery, key::active, false)) {
		relief = gd::sub(relief, 1);
	}
	if (gd::bool_field(state, front, key::active, false) && ai::string_or_empty(state, front, key::mode) == key::retake) {
		relief = gd::sub(relief, 1);
	}
	return compat::engine_clamp<int64_t>(relief, 1, 4);
}

bool _resource_site_under_threat(State &state, DictRef session, DictRef node, Atom controller_id) {
	const DictRef site = gd::content_row(state, ContentTable::ResourceSite, ai::string_or_empty(state, node, key::site_id));
	const bool response_active = gd::bool_field(state, _resource_site_response_state(state, session, node, site), key::active, false);
	const DictRef overworld = session_view::overworld(state, session);
	// A missing resolved_encounters is [], which holds no placement.
	Value resolved_encounters;
	const bool has_resolved = state.lookup(overworld, str(key::resolved_encounters), resolved_encounters);
	for (const Value &encounter : gd::field_items(state, overworld, str(key::encounters))) {
		if (!gd::is_dict(encounter) || !overworld_level_rules::same_level(state, encounter, dict_value(node))) {
			continue;
		}
		if (has_resolved && gd::is_array(resolved_encounters) && gd::array_has(state, resolved_encounters.ref, str(ai::string_or_empty(state, encounter.ref, key::placement_id)))) {
			continue;
		}
		if (player_identity_rules::raid_controller_id(state, encounter.ref) == key::empty
				|| player_identity_rules::allied(state, dict_value(session), player_identity_rules::raid_controller_id(state, encounter.ref), controller_id)) {
			continue;
		}
		if (ai::string_or_empty(state, encounter.ref, key::target_kind) == key::resource
				&& ai::string_or_empty(state, encounter.ref, key::target_placement_id) == ai::string_or_empty(state, node, key::placement_id)) {
			return true;
		}
		if (response_active) {
			continue;
		}
		const int64_t distance = gd::add(
				compat::absi(gd::sub(gd::int_field(state, encounter.ref, key::x, 0), gd::int_field(state, node, key::x, 0))),
				compat::absi(gd::sub(gd::int_field(state, encounter.ref, key::y, 0), gd::int_field(state, node, key::y, 0))));
		if (distance <= 2 && (gd::bool_field(state, encounter.ref, key::arrived, false) || gd::int_field(state, encounter.ref, key::goal_distance, 9999) <= 2)) {
			return true;
		}
	}
	return false;
}

Atom _town_name(State &state, DictRef town) {
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	return gd::stringify(state, state.get(town_template, str(key::name), state.get(town, str(key::town_id), str(key::Town))));
}

Atom _town_faction_id(State &state, DictRef town) {
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	return ai::string_or_empty(state, town_template, key::faction_id);
}

Atom _town_pressure_label(State &state, DictRef town) {
	const Atom faction_id = _town_faction_id(state, town);
	if (faction_id == key::faction_embercourt) {
		return key::frontier_leverage;
	}
	if (faction_id == key::faction_mireclaw) {
		return key::enemy_heroes;
	}
	if (faction_id == key::faction_sunvault) {
		return key::relay_reach;
	}
	if (faction_id == key::faction_thornwake) {
		return key::root_pressure;
	}
	if (faction_id == key::faction_brasshollow) {
		return key::siege_pressure;
	}
	if (faction_id == key::faction_veilmourn) {
		return key::fog_pressure;
	}
	return key::Pressure;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
