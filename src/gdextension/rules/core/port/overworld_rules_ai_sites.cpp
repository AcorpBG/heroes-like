// OverworldRules: a map object's interaction tiles, a resource site's response and
// delivery states, its delivery line, its town support and its family's short label.

#include "aurelion_rules/port/overworld_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/enemy_adventure_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using overworld_rules::Vector2i;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// max(0, value) of ints.
int64_t max0(int64_t value) {
	return compat::engine_max<int64_t>(0, value);
}

// max(a, b) of two ints (untyped: a, unless it is less than b).
int64_t vmax(int64_t a, int64_t b) {
	return a < b ? b : a;
}

// d.get(key, {}) where the result is passed on: the value, or a new Dictionary.
Value dict_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// separator.join(parts) of Strings.
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

// {"gold": 0, "wood": 0, "ore": 0}.
DictRef blank_resource_cost(State &state) {
	const DictRef cost = state.new_dict();
	state.set(cost, str(key::gold), int_value(0));
	state.set(cost, str(key::wood), int_value(0));
	state.set(cost, str(key::ore), int_value(0));
	return cost;
}

} // namespace

namespace overworld_rules {

ArrayRef _map_object_world_interaction_tiles(State &state, DictRef map_object, DictRef placement) {
	const ArrayRef tiles = state.new_array();
	const Vector2i origin = _map_object_footprint_origin(state, map_object, placement);
	Value approach;
	Value offsets;
	if (state.lookup(map_object, str(key::approach), approach) && gd::is_dict(approach) && state.lookup(approach.ref, str(key::visit_offsets), offsets) && gd::is_array(offsets) && state.array_size(offsets.ref) > 0) {
		for (const Value &offset_value : gd::items(state, offsets)) {
			if (!gd::is_dict(offset_value)) {
				continue;
			}
			const int64_t x = gd::int_field(state, offset_value.ref, key::x, 0);
			const int64_t y = gd::int_field(state, offset_value.ref, key::y, 0);
			const Vector2i tile = origin + Vector2i::of(x, y);
			state.append(tiles, Value::of_vector2i(tile.x, tile.y));
		}
		return tiles;
	}
	const int64_t x = gd::int_field(state, placement, key::x, 0);
	const int64_t y = gd::int_field(state, placement, key::y, 0);
	const Vector2i tile = Vector2i::of(x, y);
	const ArrayRef single = state.new_array();
	state.append(single, Value::of_vector2i(tile.x, tile.y));
	return single;
}

DictRef _resource_site_response_state(State &state, DictRef session, DictRef node, DictRef site) {
	return _resource_site_response_state(state, dict_value(session), node, site);
}

DictRef _resource_site_response_state(State &state, const Value &session, DictRef node, DictRef site) {
	const DictRef profile = _resource_site_response_profile(state, site);
	bool active = false;
	int64_t remaining_days = 0;
	const Atom commander_id = ai::string_or_empty(state, node, key::response_commander_id);
	Atom commander_name = key::empty;
	int64_t security_rating = max0(gd::int_field(state, node, key::response_security_rating, 0));
	if (session.kind != Kind::Nil && ai::string_or_empty(state, node, key::collected_by_faction_id) == key::player) {
		const DictRef view = gd::as_dict(session);
		const int64_t response_until_day = max0(gd::int_field(state, node, key::response_until_day, 0));
		active = response_until_day >= ai::session_int(state, view, key::day) && gd::int_field(state, profile, key::watch_days, 0) > 0;
		if (active) {
			remaining_days = vmax(1, gd::add(gd::sub(response_until_day, ai::session_int(state, view, key::day)), 1));
		}
		if (commander_id != key::empty) {
			commander_name = ai::string_or_empty(state, hero_command_rules::hero_by_id(state, view, commander_id), key::name);
		}
		if (security_rating <= 0) {
			const DictRef preview_hero = hero_command_rules::active_hero(state, view);
			security_rating = _route_security_rating_for_hero(state, preview_hero);
			if (commander_name == key::empty) {
				commander_name = ai::string_or_empty(state, preview_hero, key::name);
			}
		}
	}
	if (active && security_rating <= 0) {
		security_rating = 1;
	}
	const int64_t pressure_guard_bonus = gd::add(max0(gd::int_field(state, profile, key::pressure_guard_bonus, 0)), max0(gd::sub(security_rating, 1)));
	int64_t growth_bonus_percent = max0(gd::int_field(state, profile, key::growth_bonus_percent, 0));
	if (growth_bonus_percent > 0) {
		growth_bonus_percent = gd::add(growth_bonus_percent, gd::mul(max0(gd::sub(security_rating, 1)), 3));
	}
	const int64_t break_pressure = gd::add(max0(gd::int_field(state, profile, key::break_pressure, 0)), max0(gd::sub(security_rating, 1)));
	const DictRef result = state.new_dict();
	state.set(result, str(key::active), bool_value(active));
	state.set(result, str(key::remaining_days), int_value(remaining_days));
	state.set(result, str(key::origin), str(ai::string_or_empty(state, node, key::response_origin)));
	state.set(result, str(key::source_town_id), str(ai::string_or_empty(state, node, key::response_source_town_id)));
	state.set(result, str(key::commander_id), str(commander_id));
	state.set(result, str(key::commander_name), str(commander_name));
	state.set(result, str(key::security_rating), int_value(security_rating));
	state.set(result, str(key::action_label), str(ai::string_or_empty(state, profile, key::action_label)));
	state.set(result, str(key::summary), str(ai::string_or_empty(state, profile, key::summary)));
	state.set(result, str(key::movement_cost), int_value(gd::int_field(state, profile, key::movement_cost, 0)));
	Value resource_cost;
	if (!state.lookup(profile, str(key::resource_cost), resource_cost)) {
		resource_cost = dict_value(blank_resource_cost(state));
	}
	state.set(result, str(key::resource_cost), resource_cost);
	state.set(result, str(key::watch_days), int_value(gd::int_field(state, profile, key::watch_days, 0)));
	state.set(result, str(key::quality_bonus), int_value(gd::int_field(state, profile, key::quality_bonus, 0)));
	state.set(result, str(key::readiness_bonus), int_value(gd::int_field(state, profile, key::readiness_bonus, 0)));
	state.set(result, str(key::pressure_bonus), int_value(gd::int_field(state, profile, key::pressure_bonus, 0)));
	state.set(result, str(key::recovery_relief), int_value(gd::int_field(state, profile, key::recovery_relief, 0)));
	state.set(result, str(key::pressure_guard_bonus), int_value(pressure_guard_bonus));
	state.set(result, str(key::growth_bonus_percent), int_value(growth_bonus_percent));
	state.set(result, str(key::break_pressure), int_value(break_pressure));
	return result;
}

DictRef _resource_site_delivery_state(State &state, DictRef session, DictRef node, DictRef _site) {
	(void)_site;
	const DictRef manifest = _normalize_recruit_payload(state, dict_or_new(state, node, key::delivery_manifest));
	const Atom controller_id = ai::string_or_empty(state, node, key::delivery_controller_id);
	const int64_t arrival_day = max0(gd::int_field(state, node, key::delivery_arrival_day, 0));
	const Atom target_kind = ai::string_or_empty(state, node, key::delivery_target_kind);
	const Atom target_id = ai::string_or_empty(state, node, key::delivery_target_id);
	const Atom fallback_label = ai::string_or_empty(state, node, key::delivery_target_label);
	const Atom target_label = _resource_site_delivery_target_label(state, session, target_kind, target_id, fallback_label);
	const Atom source_town_id = ai::string_or_empty(state, node, key::delivery_origin_town_id);
	Atom source_town_label = key::empty;
	if (source_town_id != key::empty) {
		const DictRef source_town_result = _find_town_by_placement(state, session, source_town_id);
		if (gd::int_field(state, source_town_result, key::index, -1) >= 0) {
			source_town_label = _town_name(state, gd::as_dict(dict_or_new(state, source_town_result, key::town)));
		}
	}
	bool active = false;
	int64_t days_remaining = 0;
	if (controller_id != key::empty && !gd::is_empty(state, manifest) && arrival_day > 0) {
		active = player_identity_rules::resource_controller_id(state, node) == controller_id;
		if (active) {
			days_remaining = max0(gd::sub(arrival_day, ai::session_int(state, session, key::day)));
			if (days_remaining > 0) {
				days_remaining = vmax(1, days_remaining);
			}
		}
	}
	const Atom recruit_summary = _describe_recruit_delta(state, dict_value(manifest));
	const int64_t manifest_value = _weighted_recruit_value(state, dict_value(manifest));
	const DictRef result = state.new_dict();
	state.set(result, str(key::active), bool_value(active));
	state.set(result, str(key::controller_id), str(controller_id));
	state.set(result, str(key::origin_town_id), str(source_town_id));
	state.set(result, str(key::origin_town_label), str(source_town_label));
	state.set(result, str(key::target_kind), str(target_kind));
	state.set(result, str(key::target_id), str(target_id));
	state.set(result, str(key::target_label), str(target_label));
	state.set(result, str(key::arrival_day), int_value(arrival_day));
	state.set(result, str(key::days_remaining), int_value(days_remaining));
	state.set(result, str(key::manifest), dict_value(manifest));
	state.set(result, str(key::recruit_summary), str(recruit_summary));
	state.set(result, str(key::manifest_value), int_value(manifest_value));
	return result;
}

Atom _resource_site_delivery_line(State &state, DictRef session, DictRef node, DictRef site) {
	const DictRef delivery_state = _resource_site_delivery_state(state, session, node, site);
	if (!gd::bool_field(state, delivery_state, key::active, false)) {
		return key::empty;
	}
	std::vector<Atom> parts;
	const Atom site_name = gd::stringify(state, state.get(site, str(key::name), str(key::frontier_route)));
	parts.push_back(gd::format(state, key::s_convoy, {str(site_name)}));
	const Atom target_label = gd::stringify(state, state.get(delivery_state, str(key::target_label), str(key::the_front)));
	parts.push_back(gd::format(state, key::to_s, {str(target_label)}));
	const Atom recruit_summary = ai::string_or_empty(state, delivery_state, key::recruit_summary);
	if (recruit_summary != key::empty) {
		parts.push_back(recruit_summary);
	}
	const int64_t days_remaining = gd::int_field(state, delivery_state, key::days_remaining, 0);
	if (days_remaining > 0) {
		parts.push_back(gd::format(state, key::d_day_s_out, {int_value(days_remaining), str(days_remaining == 1 ? key::empty : key::s)}));
	} else {
		const DictRef interception_state = _resource_site_delivery_interception(state, session, node, site);
		if (gd::bool_field(state, interception_state, key::blocks_delivery, false)) {
			parts.push_back(key::holding_under_interception);
		}
	}
	const DictRef interception = _resource_site_delivery_interception(state, session, node, site);
	if (gd::bool_field(state, interception, key::active, false)) {
		if (gd::bool_field(state, interception, key::blocks_delivery, false)) {
			const Atom encounter_name = gd::stringify(state, state.get(interception, str(key::encounter_name), str(key::enemy_army_3)));
			parts.push_back(gd::format(state, key::s_blocks_the_route, {str(encounter_name)}));
		} else {
			const Atom encounter_name = gd::stringify(state, state.get(interception, str(key::encounter_name), str(key::enemy_army_3)));
			const int64_t goal_distance = gd::int_field(state, interception, key::goal_distance, 0);
			const Atom plural = gd::int_field(state, interception, key::goal_distance, 0) == 1 ? key::empty : key::s;
			parts.push_back(gd::format(state, key::s_d_tile_s_out, {str(encounter_name), int_value(goal_distance), str(plural)}));
		}
	}
	return join_atoms(state, key::space_bar_space, parts);
}

DictRef _resource_site_town_support(State &state, DictRef site) {
	static constexpr Atom kFields[] = {
		key::quality_bonus,
		key::readiness_bonus,
		key::pressure_bonus,
		key::growth_bonus_percent,
		key::recovery_relief,
		key::disruption_pressure,
	};
	const DictRef support = state.new_dict();
	for (const Atom field : kFields) {
		state.set(support, str(field), int_value(0));
	}
	Value authored_support;
	if (state.lookup(site, str(key::town_support), authored_support) && gd::is_dict(authored_support) && !gd::is_empty(state, authored_support.ref)) {
		for (const Atom field : kFields) {
			const Value current = gd::index(state, support, str(field));
			state.set(support, str(field), int_value(max0(gd::to_int(state, state.get(authored_support.ref, str(field), current)))));
		}
		return support;
	}
	const Atom family = ai::string_or_empty(state, site, key::family);
	if (family == key::mine) {
		state.set(support, str(key::growth_bonus_percent), int_value(3));
		state.set(support, str(key::recovery_relief), int_value(1));
		state.set(support, str(key::disruption_pressure), int_value(1));
	} else if (family == key::neutral_dwelling) {
		// Dwellings grow towns by +1 per creature instead (_add_dwelling_town_growth).
	} else if (family == key::faction_outpost) {
		state.set(support, str(key::readiness_bonus), int_value(vmax(2, gd::mul(max0(gd::int_field(state, site, key::vision_radius, 0)), 2))));
		state.set(support, str(key::pressure_bonus), int_value(max0(gd::int_field(state, site, key::pressure_bonus, 0))));
		state.set(support, str(key::recovery_relief), int_value(1));
		state.set(support, str(key::disruption_pressure), int_value(1));
	} else if (family == key::frontier_shrine) {
		state.set(support, str(key::quality_bonus), int_value(2));
		state.set(support, str(key::pressure_bonus), int_value(1));
		state.set(support, str(key::growth_bonus_percent), int_value(6));
		state.set(support, str(key::recovery_relief), int_value(1));
		state.set(support, str(key::disruption_pressure), int_value(1));
	} else if (family == key::scouting_structure) {
		state.set(support, str(key::readiness_bonus), int_value(vmax(1, max0(gd::int_field(state, site, key::vision_radius, 0)))));
		state.set(support, str(key::pressure_bonus), int_value(1));
		state.set(support, str(key::disruption_pressure), int_value(1));
	} else if (family == key::transit_object) {
		state.set(support, str(key::readiness_bonus), int_value(1));
		state.set(support, str(key::recovery_relief), int_value(1));
		state.set(support, str(key::disruption_pressure), int_value(1));
	} else if (family == key::repeatable_service) {
		state.set(support, str(key::recovery_relief), int_value(1));
	}
	return support;
}

Atom _resource_site_family_short_label(State &state, Atom family_id) {
	(void)state;
	if (family_id == key::neutral_dwelling) {
		return key::dwelling;
	}
	if (family_id == key::faction_outpost) {
		return key::outpost;
	}
	if (family_id == key::frontier_shrine) {
		return key::shrine;
	}
	return family_id;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
