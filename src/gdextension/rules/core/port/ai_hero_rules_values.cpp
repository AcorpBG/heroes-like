#include "aurelion_rules/port/adventure_services.hpp"
// AiHeroRules: what a site, a neutral guard and a site's doorway are worth to
// a computer hero, and the keys guards, doors and hostile heroes go by.

#include "aurelion_rules/port/ai_hero_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_rules_ai.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_ai.hpp"
#include "aurelion_rules/port/enemy_adventure_rules_ai.hpp"
#include "aurelion_rules/port/native_transit_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/resource_node_payload_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules_ai.hpp"
#include "aurelion_rules/port/visit_building_rules_ai.hpp"

#include <cmath>
#include <limits>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::float_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;

constexpr int64_t kStopResource = 1;
constexpr int64_t kStopArtifact = 2;
constexpr int64_t kStopTown = 3;

// An AiHeroRules tunable (a static var typed float).
double tunable(State &state, Atom name) {
	return ai::static_float(state, key::ai_hero_rules_script, name);
}

// d.get(name, {}) and d.get(name, []) where the fallback is handed on: a new
// container only when the key is missing.
Value get_or_new_dict(State &state, gd::DictRef dict, Atom name) {
	Value found;
	return state.lookup(dict, str(name), found) ? found : dict_value(state.new_dict());
}
Value get_or_new_array(State &state, gd::DictRef dict, Atom name) {
	Value found;
	return state.lookup(dict, str(name), found) ? found : array_value(state.new_array());
}

// var x: Dictionary / Array / PackedByteArray = d.get(name, <empty>).
gd::DictRef dict_or_new(State &state, gd::DictRef dict, Atom name) {
	Value found;
	return state.lookup(dict, str(name), found) ? gd::as_dict(found) : state.new_dict();
}
gd::ArrayRef array_or_new(State &state, gd::DictRef dict, Atom name) {
	Value found;
	return state.lookup(dict, str(name), found) ? gd::as_array(found) : state.new_array();
}
gd::PackedRef bytes_or_new(State &state, gd::DictRef dict, Atom name) {
	Value found;
	return state.lookup(dict, str(name), found) ? gd::as_bytes(found) : gd::new_bytes(state);
}

// String(guard.get("encounter_id", guard.get("id", ""))).
Atom encounter_id_of(State &state, gd::DictRef guard) {
	const Value fallback = state.get(guard, str(key::id), str(key::empty));
	return gd::stringify(state, state.get(guard, str(key::encounter_id), fallback));
}

} // namespace

namespace ai_hero_rules {

DictRef _resource_candidate(State &state, DictRef session, Atom controller, DictRef entry, int64_t index, double power, DictRef needs, DictRef treasury, double opens) {
	const ArrayRef nodes = array_or_new(state, session_view::overworld(state, session), key::resource_nodes);
	const DictRef node = gd::as_dict(state.at(nodes, index));
	if (native_transit_rules::is_native(state, node)) {
		return state.new_dict();
	}
	const DictRef site = resource_node_payload_rules::site_for_node(state, node, state.new_dict());
	if (gd::is_empty(state, site) || gd::bool_field(state, site, key::opens_route_on_claim, false)) {
		return state.new_dict();
	}
	// A shipyard serves a route over water (`_search`), a whirlpool only a boat.
	const Atom site_id = ai::string_or_empty(state, site, key::id);
	if (site_id == key::site_shipyard || site_id == key::site_whirlpool) {
		return state.new_dict();
	}
	if (!overworld_rules::resource_node_is_present(state, node, site)) {
		return state.new_dict();
	}
	if (!enemy_adventure_rules::_resource_node_contestable_by_faction(state, node, site, controller, dict_value(session))) {
		return state.new_dict();
	}
	double value = 0.0;
	double fight = 0.0;
	if (creature_dwelling_rules::is_dwelling(state, site)) {
		if (player_identity_rules::resource_controller_id(state, node) == controller && !_can_hire_any(state, session, node, site, treasury)) {
			return state.new_dict();
		}
		if (creature_dwelling_rules::guard_blocks(state, node, site, controller, ai::session_int(state, session, key::day))) {
			const ArrayRef stacks = creature_dwelling_rules::guard_stacks(state, node, site, controller, ai::session_int(state, session, key::day));
			const double guard_power = army_power(state, array_value(stacks), dict_value(state.new_dict()));
			if (power < guard_power * tunable(state, key::GUARD_WIN_RATIO)) {
				return state.new_dict();
			}
			fight = guard_power;
		}
		const int64_t week = creature_dwelling_rules::week_value(state, node, site, ai::session_int(state, session, key::day));
		value = tunable(state, key::DWELLING_BASE_VALUE) + static_cast<double>(week) * tunable(state, key::DWELLING_WEEK_SHARE);
	} else if (visit_building_rules::is_visit_building(state, site)) {
		if (adventure_services::handles(state, site) && !adventure_services::available(state, session, node, site, controller, entry)) return state.new_dict();
		Value commander;
		const Value level = state.lookup(entry, str(key::enemy_commander_state), commander) ? ai::vget(state, commander, key::level, int_value(1)) : int_value(1);
		if (gd::to_int(state, level) < visit_building_rules::required_level(state, site)) {
			return state.new_dict();
		}
		if (!_can_afford(state, treasury, visit_building_rules::cost(state, site))) {
			return state.new_dict();
		}
		value = tunable(state, key::VISIT_BUILDING_BASE_VALUE) + static_cast<double>(visit_building_rules::ai_value(state, site));
	} else {
		value = _payload_value(state, dict_value(enemy_adventure_rules::_resource_site_claim_rewards(state, site)), needs);
		const double recruits = _recruit_set_value(state, _recruit_dict(state, get_or_new_dict(state, site, key::claim_recruits)));
		const double artifacts = _site_artifact_value(state, site);
		const double spells = _site_spell_value(state, site, entry);
		value += recruits + artifacts + spells;
		if (gd::bool_field(state, site, key::persistent_control, false)) {
			const double income = _payload_value(state, get_or_new_dict(state, site, key::control_income), needs);
			value += income * tunable(state, key::SITE_INCOME_DAYS) + tunable(state, key::SITE_CONTROL_VALUE);
			// A site that musters troops every week is worth a week of them.
			value += _recruit_set_value(state, _recruit_dict(state, get_or_new_dict(state, site, key::weekly_recruits)));
			const Atom owner = player_identity_rules::resource_controller_id(state, node);
			if (owner != key::empty && owner != controller) {
				value *= tunable(state, key::RIVAL_SITE_MULTIPLIER);
			}
		}
	}
	value += opens - _expected_loss_value(state, power, fight);
	if (value <= 0.0) {
		return state.new_dict();
	}
	// A guarded site is reached by beating its guard first (a separate target).
	if (_resource_guarded(state, session, node, site)) {
		return state.new_dict();
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::kind), str(key::resource));
	state.set(result, str(key::id), str(ai::string_or_empty(state, node, key::placement_id)));
	state.set(result, str(key::index), int_value(index));
	state.set(result, str(key::value), float_value(value));
	state.set(result, str(key::fight_power), float_value(fight));
	return result;
}

bool _can_hire_any(State &state, DictRef session, DictRef node, DictRef site, DictRef treasury) {
	const DictRef available = creature_dwelling_rules::population(state, node, site, ai::session_int(state, session, key::day));
	for (const Value &unit_id : gd::items(state, dict_value(available))) {
		if (gd::to_int(state, gd::index(state, available, unit_id)) > 0 && _can_afford(state, treasury, creature_dwelling_rules::unit_cost(state, gd::stringify(state, unit_id)))) {
			return true;
		}
	}
	return false;
}

DictRef _encounter_candidate(State &state, DictRef session, DictRef context, DictRef entry, int64_t index, double power, DictRef needs, DictRef search) {
	const double value = _guard_fight_value(state, session, context, entry, index, power, needs, search);
	if (std::isnan(value) || value <= 0.0) {
		return state.new_dict();
	}
	const Value encounters = gd::index(state, session_view::overworld(state, session), str(key::encounters));
	const DictRef guard = gd::as_dict(ai::vindex(state, encounters, int_value(index)));
	const double guard_power = _guard_power(state, guard);
	const DictRef result = state.new_dict();
	state.set(result, str(key::kind), str(key::encounter));
	state.set(result, str(key::id), str(ai::string_or_empty(state, guard, key::placement_id)));
	state.set(result, str(key::index), int_value(index));
	state.set(result, str(key::value), float_value(value));
	state.set(result, str(key::fight_power), float_value(guard_power));
	state.set(result, str(key::estimated_loss), float_value(_expected_loss_value(state, power, guard_power)));
	return result;
}

double _guard_fight_value(State &state, DictRef session, DictRef context, DictRef entry, int64_t index, double power, DictRef needs, DictRef search) {
	const ArrayRef encounters = array_or_new(state, session_view::overworld(state, session), key::encounters);
	const DictRef guard = gd::as_dict(state.at(encounters, index));
	if (player_identity_rules::raid_controller_id(state, guard) != key::empty) {
		return std::numeric_limits<double>::quiet_NaN();
	}
	const DictRef encounter = gd::content_row(state, ContentTable::Encounter, encounter_id_of(state, guard));
	if (gd::is_empty(state, encounter)) {
		return std::numeric_limits<double>::quiet_NaN();
	}
	const double guard_power = _guard_power(state, guard);
	if (guard_power <= 0.0 || power < guard_power * tunable(state, key::GUARD_WIN_RATIO)) {
		return std::numeric_limits<double>::quiet_NaN();
	}
	// What beating it pays, by its strength, as the battle will pay it.
	const Value stacks = get_or_new_array(state, _neutral_army(state, guard), key::stacks);
	const Value commander = get_or_new_dict(state, encounter, key::enemy_commander);
	const DictRef rewards = battle_rules::battle_rewards_for_strength(state, encounter, stacks, commander);
	double value = _payload_value(state, dict_value(rewards), needs) + tunable(state, key::GUARD_FIGHT_BASE_VALUE);
	value += _guarded_object_value(state, session, guard, needs, search, index, ai::string_or_empty(state, context, key::controller));
	value += _passage_value(state, session, context, entry, search, index, needs);
	return value - _expected_loss_value(state, power, guard_power);
}

double _guard_power(State &state, DictRef guard) {
	const DictRef encounter = gd::content_row(state, ContentTable::Encounter, encounter_id_of(state, guard));
	const Value stacks = get_or_new_array(state, _neutral_army(state, guard), key::stacks);
	const Value commander = get_or_new_dict(state, encounter, key::enemy_commander);
	return army_power(state, stacks, commander);
}

double _expected_loss_value(State &state, double power, double enemy_power) {
	if (power <= 0.0 || enemy_power <= 0.0) {
		return 0.0;
	}
	const double ratio = compat::engine_min(1.0, enemy_power / power);
	const double share = compat::engine_min(1.0, tunable(state, key::LOSS_ESTIMATE_FACTOR) * (1.0 - std::sqrt(1.0 - ratio * ratio)) + tunable(state, key::LOSS_ESTIMATE_PER_RATIO) * ratio);
	return power * share * tunable(state, key::TROOP_VALUE_PER_POWER);
}

double _guarded_object_value(State &state, DictRef session, DictRef guard, DictRef needs, DictRef search, int64_t guard_index, Atom controller) {
	Atom target_id = ai::string_or_empty(state, guard, key::guarded_object_placement_id);
	if (target_id == key::empty) {
		const DictRef link = enemy_adventure_rules::_guard_link_for_encounter(state, guard);
		target_id = ai::string_or_empty(state, link, key::target_placement_id);
	}
	Value found;
	if (target_id != key::empty) {
		const DictRef resource = enemy_adventure_rules::_find_resource_by_placement(state, session, target_id);
		if (state.lookup(resource, str(key::node), found)) {
			const DictRef linked = gd::as_dict(found);
			if (!gd::is_empty(state, linked)) {
				return _guarded_node_value(state, session, linked, needs, controller);
			}
		}
		const DictRef artifact_ref = enemy_adventure_rules::_find_artifact_by_placement(state, session, target_id);
		if (state.lookup(artifact_ref, str(key::node), found)) {
			const DictRef artifact = gd::as_dict(found);
			if (!gd::is_empty(state, artifact) && !gd::bool_field(state, artifact, key::collected, false)) {
				return tunable(state, key::ARTIFACT_PRIZE_VALUE);
			}
		}
		return 0.0;
	}
	if (!state.lookup(search, str(key::guard_zones), found)) {
		return 0.0;
	}
	const DictRef zones = gd::as_dict(found);
	Value zone_list;
	if (!state.lookup(zones, int_value(guard_index), zone_list)) {
		return 0.0;
	}
	const DictRef static_stops = dict_or_new(state, search, key::static_stops);
	const DictRef overworld = session_view::overworld(state, session);
	const ArrayRef nodes = array_or_new(state, overworld, key::resource_nodes);
	const ArrayRef artifacts = array_or_new(state, overworld, key::artifact_nodes);
	const ArrayRef towns = array_or_new(state, overworld, key::towns);
	double value = 0.0;
	for (const Value &zone_index : gd::items(state, zone_list)) {
		for (const Value &ref : gd::field_items(state, static_stops, int_value(gd::to_int(state, zone_index)))) {
			switch (gd::to_int(state, ai::vmember(state, ref, key::kind))) {
				case kStopResource: {
					const DictRef node = gd::as_dict(state.at(nodes, gd::to_int(state, ai::vmember(state, ref, key::index))));
					value += _guarded_node_value(state, session, node, needs, controller);
					break;
				}
				case kStopArtifact: {
					const Value artifact = state.at(artifacts, gd::to_int(state, ai::vmember(state, ref, key::index)));
					if (!gd::to_bool(ai::vget(state, artifact, key::collected, bool_value(false)))) {
						value += tunable(state, key::ARTIFACT_PRIZE_VALUE);
					}
					break;
				}
				case kStopTown: {
					// A town whose doorway the guard holds: worth what taking it is.
					const DictRef town = gd::as_dict(state.at(towns, gd::to_int(state, ai::vmember(state, ref, key::index))));
					const Atom owner = gd::stringify(state, state.get(town, str(key::owner), str(key::neutral)));
					const Atom town_controller = owner == key::player ? key::player : player_identity_rules::town_controller_id(state, town);
					if (owner == key::neutral) {
						value += tunable(state, key::GUARDED_NEUTRAL_TOWN_VALUE) * tunable(state, key::GUARDED_VALUE_SHARE);
					} else if ((owner == key::player || owner == key::enemy) && town_controller != controller && !player_identity_rules::allied(state, dict_value(session), controller, town_controller)) {
						value += tunable(state, key::GUARDED_RIVAL_TOWN_VALUE) * tunable(state, key::GUARDED_VALUE_SHARE);
					}
					break;
				}
				default:
					break;
			}
		}
	}
	return value;
}

double _guarded_node_value(State &state, DictRef session, DictRef node, DictRef needs, Atom controller) {
	const DictRef site = resource_node_payload_rules::site_for_node(state, node, state.new_dict());
	if (gd::is_empty(state, site) || !overworld_rules::resource_node_is_present(state, node, site)) {
		return 0.0;
	}
	if (controller != key::empty && !enemy_adventure_rules::_resource_node_contestable_by_faction(state, node, site, controller, dict_value(session))) {
		return 0.0;
	}
	double value = _payload_value(state, dict_value(enemy_adventure_rules::_resource_site_claim_rewards(state, site)), needs);
	// A creature bank can pay in troops and artifacts alone.
	const double recruits = _recruit_set_value(state, _recruit_dict(state, get_or_new_dict(state, site, key::claim_recruits)));
	const double artifacts = _site_artifact_value(state, site);
	value += recruits + artifacts;
	if (gd::bool_field(state, site, key::persistent_control, false)) {
		const double income = _payload_value(state, get_or_new_dict(state, site, key::control_income), needs);
		value += income * tunable(state, key::SITE_INCOME_DAYS) + tunable(state, key::SITE_CONTROL_VALUE);
	}
	if (creature_dwelling_rules::is_dwelling(state, site)) {
		value += tunable(state, key::DWELLING_BASE_VALUE);
	}
	return value * tunable(state, key::GUARDED_VALUE_SHARE);
}

double _site_spell_value(State &state, DictRef site, DictRef entry) {
	Value found;
	const DictRef commander = state.lookup(entry, str(key::enemy_commander_state), found) && gd::is_dict(found) ? found.ref : state.new_dict();
	double value = 0.0;
	const ArrayRef spell_ids = overworld_rules::_resource_site_spell_ids(state, site);
	for (const Value &spell_id : gd::items(state, array_value(spell_ids))) {
		const DictRef spell = gd::content_row(state, ContentTable::Spell, gd::stringify(state, spell_id));
		if (gd::is_empty(state, spell) || spell_rules::knows_spell(state, commander, gd::stringify(state, spell_id))) {
			continue;
		}
		const int64_t tier = compat::engine_max<int64_t>(1, gd::int_field(state, spell, key::tier, 1));
		value += tunable(state, key::SCROLL_SPELL_BASE_VALUE) + tunable(state, key::SCROLL_SPELL_TIER_VALUE) * static_cast<double>(tier);
	}
	return value;
}

double _site_artifact_value(State &state, DictRef site) {
	Value classes;
	if (!state.lookup(site, str(key::claim_artifact_classes), classes)) {
		// The [] fallback: an empty Array.
		return tunable(state, key::ARTIFACT_PRIZE_VALUE) * 0.0;
	}
	return gd::is_array(classes) ? tunable(state, key::ARTIFACT_PRIZE_VALUE) * static_cast<double>(state.array_size(classes.ref)) : 0.0;
}

double _passage_value(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, int64_t guard_index, DictRef needs) {
	Value found;
	if (!state.lookup(search, str(key::guard_zones), found)) {
		return 0.0;
	}
	const DictRef zones = gd::as_dict(found);
	Value origin;
	if (!state.lookup(zones, int_value(guard_index), origin)) {
		return 0.0;
	}
	return _opened_value(state, session, context, entry, search, guard_index, gd::as_array(origin), needs);
}

double _site_door_value(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, int64_t tile_index, DictRef needs) {
	if (tile_index < 0 || !state.has(_site_doors(state, search), int_value(tile_index))) {
		return 0.0;
	}
	const ArrayRef origin = state.new_array();
	state.append(origin, int_value(tile_index));
	return _opened_value(state, session, context, entry, search, _site_door_key(state, tile_index), origin, needs);
}

int64_t _site_door_key(State &state, int64_t tile_index) {
	(void)state;
	return gd::sub(-10, tile_index);
}

int64_t _hero_war_key(State &state, Atom ref_kind, int64_t index) {
	(void)state;
	return gd::sub(ref_kind == key::ai_hero ? -1000000 : -2000000, index);
}

DictRef _site_doors(State &state, DictRef search) {
	Value found;
	if (state.lookup(search, str(key::site_doors), found)) {
		return gd::as_dict(found);
	}
	const DictRef doors = state.new_dict();
	const PackedRef pass_mask = bytes_or_new(state, search, key::pass_mask);
	const PackedRef guard_mask = bytes_or_new(state, search, key::guard_mask);
	const PackedRef hero_zone = bytes_or_new(state, search, key::hero_zone);
	const DictRef stops = dict_or_new(state, search, key::stops);
	for (const Value &tile_index : gd::items(state, dict_value(stops))) {
		const int64_t tile = gd::to_int(state, tile_index);
		if (gd::packed_is_empty(state, pass_mask) || gd::packed_int(state, pass_mask, tile) != 0 || gd::packed_int(state, guard_mask, tile) != 0 || gd::packed_int(state, hero_zone, tile) != 0) {
			continue;
		}
		for (const Value &ref : gd::items(state, gd::index(state, stops, tile_index))) {
			const int64_t kind = gd::to_int(state, ai::vmember(state, ref, key::kind));
			if (kind == kStopResource || kind == kStopArtifact) {
				state.set(doors, int_value(tile), bool_value(true));
				break;
			}
		}
	}
	state.set(search, str(key::site_doors), dict_value(doors));
	return doors;
}

} // namespace ai_hero_rules

} // namespace aurelion::rules::port
