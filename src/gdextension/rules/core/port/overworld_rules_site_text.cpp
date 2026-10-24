// OverworldRules for the human seat's resource-site texts (Phase 7, slice 7.3):
// the site's surfaces, its control, route, guard and cadence lines, and the
// recruit source's inspection.

#include "aurelion_rules/port/overworld_rules_context.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_ai.hpp"
#include "aurelion_rules/port/native_transit_rules.hpp"
#include "aurelion_rules/port/native_transit_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/resource_node_payload_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/visit_building_rules_ai.hpp"

#include <algorithm>
#include <initializer_list>
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
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// String(x): stringify(), and the engine's for a float, a container or an object.
Atom string_of(State &state, const Value &value) {
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
Atom text_of(State &state, DictRef dict, Atom name, Atom fallback = key::empty) {
	return string_of(state, state.get(dict, str(name), str(fallback)));
}

// String(d.get(name, "")).strip_edges().
Atom stripped(State &state, DictRef dict, Atom name) {
	return gd::strip_edges(state, text_of(state, dict, name));
}

// d.get(name, {}) passed on: the value, or a new Dictionary when missing.
Value field_or_new_dict(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, str(name), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// d.get(name, []) passed on: the value, or a new Array when missing.
Value field_or_new_array(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, str(name), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// What `for x in d.get(name, [])` visits, copied: the loop's body makes calls
// that add nodes.
std::vector<Value> field_items_of(State &state, DictRef dict, Atom name) {
	const gd::Items listed = gd::field_items(state, dict, str(name));
	return std::vector<Value>(listed.begin(), listed.end());
}

// a + b of two Strings.
Atom append_text(State &state, Atom a, Atom b) {
	return state.intern(state.text(a) + state.text(b));
}

// separator.join(strings) of Strings.
Atom join_atoms(State &state, Atom separator, const std::vector<Atom> &strings) {
	std::string joined;
	for (size_t index = 0; index < strings.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(strings[index]);
	}
	return state.intern(joined);
}

// separator.join(strings) of an Array of Strings.
Atom join_array(State &state, Atom separator, ArrayRef strings) {
	std::vector<Atom> parts;
	const int64_t count = state.array_size(strings);
	for (int64_t index = 0; index < count; ++index) {
		parts.push_back(gd::to_string(state.at(strings, index)));
	}
	return join_atoms(state, separator, parts);
}

// An untyped Array of these Strings ([a, b, ...] and the appends after it).
ArrayRef string_list(State &state, const std::vector<Atom> &strings) {
	const ArrayRef list = state.new_array();
	for (const Atom text : strings) {
		state.append(list, str(text));
	}
	return list;
}

// separator.join(_non_empty_strings(parts)).
Atom join_non_empty(State &state, Atom separator, const std::vector<Atom> &parts) {
	return join_array(state, separator, overworld_rules::_non_empty_strings(state, string_list(state, parts)));
}

// ContentService.get_neutral_dwelling(id): no content table holds them.
DictRef neutral_dwelling_row(State &state, Atom dwelling_id) {
	return gd::as_dict(gd::call_method(state, gd::autoload(state, key::ContentService), key::get_neutral_dwelling, { str(dwelling_id) }));
}

} // namespace

namespace overworld_rules {

Atom describe_recruit_source_inspection(State &state, const Value &session, DictRef node, DictRef site) {
	if (!resource_site_is_recruit_source(state, site)) {
		return key::empty;
	}
	std::vector<Atom> lines;
	const Atom dwelling_label = _resource_site_neutral_dwelling_label(state, site);
	const Atom scope = stripped(state, site, key::dwelling_scope);
	if (dwelling_label != key::empty) {
		lines.push_back(gd::format(state, key::recruit_source_s_neutral_dwelling, { str(dwelling_label) }));
	} else if (scope == key::faction_linked) {
		lines.push_back(gd::format(state, key::recruit_source_s_faction_linked_muster, { str(text_of(state, site, key::name, key::recruit_source)) }));
	} else {
		lines.push_back(gd::format(state, key::recruit_source_s, { str(text_of(state, site, key::name, key::recruit_source)) }));
	}
	const Atom dwelling_id = text_of(state, site, key::neutral_dwelling_family_id);
	if (dwelling_id != key::empty) {
		const DictRef dwelling = neutral_dwelling_row(state, dwelling_id);
		const Atom summary = _short_player_text(state, text_of(state, dwelling, key::summary), 112);
		if (summary != key::empty) {
			lines.push_back(gd::format(state, key::identity_s, { str(summary) }));
		}
	}
	const Atom claim_line = _recruit_source_roster_line(state, key::Ready, dict_value(_resource_site_claim_recruits(state, site)), 4);
	if (claim_line != key::empty) {
		lines.push_back(claim_line);
	}
	const Atom weekly_line = _recruit_source_roster_line(state, key::Weekly, dict_value(_resource_site_weekly_recruits(state, site)), 4, creature_dwelling_rules::is_dwelling(state, site));
	if (weekly_line != key::empty) {
		lines.push_back(creature_dwelling_rules::is_dwelling(state, site)
						? gd::format(state, key::s_hired_here, { str(weekly_line) })
						: gd::format(state, key::s_to_nearest_held_town, { str(weekly_line) }));
	}
	if (creature_dwelling_rules::is_dwelling(state, site)) {
		const int64_t day = session.kind != Kind::Nil ? ai::session_int(state, gd::as_dict(session), key::day) : 1;
		const ArrayRef dwelling_guard = creature_dwelling_rules::full_guard(state, node, site, day);
		if (state.array_size(dwelling_guard) != 0) {
			const Atom guard_text = _describe_recruit_delta(state, dict_value(_stacks_to_recruits(state, dwelling_guard)));
			lines.push_back(gd::format(state, key::guard_s_which_every_side_must, { str(guard_text) }));
		}
	}
	// String(node.get("site_id", site.get("id", ""))).
	const Value id_fallback = state.get(site, str(key::id), str(key::empty));
	const Atom object_site_id = string_of(state, state.get(node, str(key::site_id), id_fallback));
	const DictRef map_object = gd::content_row(state, ContentTable::MapObjectForResourceSite, object_site_id);
	const Atom cadence = gd::trim_prefix(state, _interaction_cadence_label(state, _resource_site_interaction_cadence(state, site, map_object)), key::cadence_2);
	const Atom control_brief = _resource_site_control_brief(state, node, site);
	lines.push_back(gd::format(state, key::cadence_s_s, { str(cadence), str(control_brief) }));
	const Atom support_line = _recruit_source_support_readiness_line(state, session, node, site);
	if (support_line != key::empty) {
		lines.push_back(support_line);
	}
	const Atom route_line = _resource_site_route_line(state, session, node, site);
	if (route_line != key::empty) {
		lines.push_back(gd::format(state, key::route_s, { str(route_line) }));
	}
	const Atom guard_line = _resource_site_guard_or_contest_line(state, session, node, site);
	if (guard_line != key::empty) {
		lines.push_back(gd::format(state, key::guard_s, { str(guard_line) }));
	}
	lines.push_back(_recruit_source_why_line(state, site));
	return join_non_empty(state, key::newline, lines);
}

Atom _resource_site_neutral_dwelling_label(State &state, DictRef site) {
	const Atom dwelling_id = text_of(state, site, key::neutral_dwelling_family_id);
	if (dwelling_id == key::empty) {
		return key::empty;
	}
	const DictRef dwelling = neutral_dwelling_row(state, dwelling_id);
	if (gd::is_empty(state, dwelling)) {
		return dwelling_id;
	}
	return text_of(state, dwelling, key::name, dwelling_id);
}

Atom _resource_site_family_label(State &state, DictRef site) {
	const Atom family = text_of(state, site, key::family);
	if (family == key::mine) {
		return key::Mine;
	}
	if (family == key::neutral_dwelling) {
		return key::neutral_dwelling_2;
	}
	if (family == key::faction_outpost) {
		return key::faction_outpost_2;
	}
	if (family == key::frontier_shrine) {
		return key::frontier_shrine_2;
	}
	if (family == key::guarded_reward_site) {
		return key::guarded_reward_site_2;
	}
	if (family == key::scouting_structure) {
		return key::scouting_structure_2;
	}
	if (family == key::transit_object) {
		return key::transit_object_2;
	}
	if (family == key::repeatable_service) {
		return key::service_building;
	}
	return key::resource_site_2;
}

Atom describe_resource_site_surface(State &state, DictRef session, DictRef node, DictRef site) {
	site = resource_node_payload_rules::site_for_node(state, node, site);
	if (visit_building_rules::is_visit_building(state, site)) {
		const Atom name = text_of(state, site, key::name, key::visit_building_2);
		const Atom summary = visit_building_rules::summary(state, site);
		return join_non_empty(state, key::space_bar_space, { name, summary });
	}
	if (creature_dwelling_rules::is_dwelling(state, site)) {
		const Atom name = text_of(state, site, key::name, key::creature_dwelling_2);
		const Atom control = _resource_site_control_label(state, node, site);
		const Atom summary = creature_dwelling_rules::summary(state, node, site, ai::session_int(state, session, key::day));
		return join_non_empty(state, key::space_bar_space, { name, control, summary });
	}
	std::vector<Atom> parts;
	parts.push_back(_resource_site_role_label(state, node, site));
	parts.push_back(_resource_site_family_label(state, site));
	const Atom control_label = _resource_site_control_label(state, node, site);
	if (control_label != key::empty) {
		parts.push_back(control_label);
	}
	const Atom income_summary = _describe_resource_delta(state, field_or_new_dict(state, site, key::control_income));
	if (income_summary != key::empty) {
		parts.push_back(gd::format(state, key::s_s, { str(_resource_site_income_cadence_label(state, site)), str(income_summary) }));
	}
	const Atom weekly_summary = _describe_recruit_delta(state, dict_value(_resource_site_weekly_recruits(state, site)));
	if (weekly_summary != key::empty) {
		parts.push_back(gd::format(state, key::weekly_s_2, { str(weekly_summary) }));
	}
	const Atom claim_recruit_summary = _describe_recruit_delta(state, dict_value(_resource_site_claim_recruits(state, site)));
	if (claim_recruit_summary != key::empty) {
		parts.push_back(gd::format(state, key::field_recruits_s, { str(claim_recruit_summary) }));
	}
	const Atom reward_summary = _resource_site_reward_summary(state, site);
	if (reward_summary != key::empty && !_resource_site_is_persistent(state, site)) {
		parts.push_back(gd::format(state, key::reward_s, { str(reward_summary) }));
	}
	const DictRef response_state = _resource_site_response_state(state, session, node, site);
	if (text_of(state, node, key::collected_by_faction_id) == key::player && gd::int_field(state, response_state, key::watch_days, 0) > 0) {
		parts.push_back(key::support_order_ready);
	}
	return join_non_empty(state, key::space_bar_space, parts);
}

Atom describe_resource_site_control_inspection(State &state, const Value &session, DictRef node, DictRef site) {
	std::vector<Atom> lines;
	const Atom control_detail = _resource_site_control_detail(state, node, site);
	if (control_detail != key::empty) {
		lines.push_back(gd::format(state, key::control_s, { str(control_detail) }));
	}
	const Atom yield_line = _resource_site_yield_line(state, session, node, site);
	if (yield_line != key::empty) {
		lines.push_back(gd::format(state, key::economy_s_2, { str(yield_line) }));
	}
	const Atom route_line = _resource_site_route_line(state, session, node, site);
	if (route_line != key::empty) {
		lines.push_back(gd::format(state, key::route_s, { str(route_line) }));
	}
	const Atom guard_line = _resource_site_guard_or_contest_line(state, session, node, site);
	if (guard_line != key::empty) {
		lines.push_back(gd::format(state, key::guard_s, { str(guard_line) }));
	}
	const Atom recruit_source = describe_recruit_source_inspection(state, session, node, site);
	if (recruit_source != key::empty) {
		lines.push_back(recruit_source);
	}
	return join_atoms(state, key::newline, lines);
}

Atom describe_resource_site_interaction_surface(State &state, DictRef node, DictRef site) {
	const DictRef map_object = gd::content_row(state, ContentTable::MapObjectForResourceSite, text_of(state, node, key::site_id));
	const Atom cadence = _resource_site_interaction_cadence(state, site, map_object);
	std::vector<Atom> interaction_parts;
	interaction_parts.push_back(_interaction_cadence_label(state, cadence));
	if (visit_building_rules::is_visit_building(state, site)) {
		interaction_parts.clear();
		interaction_parts.push_back(gd::format(state, key::cadence_s, { str(visit_building_rules::cadence_label(state, site)) }));
		interaction_parts.push_back(key::visit_building_3);
	} else if (_resource_site_is_persistent(state, site)) {
		interaction_parts.push_back(key::capture_ownership);
		Value control_income;
		if (state.lookup(site, str(key::control_income), control_income) && gd::is_dict(control_income) && !gd::is_empty(state, control_income.ref)) {
			interaction_parts.push_back(key::income);
		}
		if (!gd::is_empty(state, _resource_site_weekly_recruits(state, site))) {
			interaction_parts.push_back(key::weekly_recruits_2);
		}
		if (state.has(site, str(key::response_profile))) {
			interaction_parts.push_back(key::support_response);
		}
	} else if (_resource_site_is_repeatable(state, site)) {
		interaction_parts.push_back(key::repeat_service);
	} else {
		interaction_parts.push_back(key::pickup_cache);
	}
	const Atom object_class = _resource_site_object_class_label(state, site, map_object);
	if (object_class != key::empty) {
		interaction_parts.insert(interaction_parts.begin(), object_class);
	}
	const Atom role_tags = _resource_site_role_tag_summary(state, site, map_object);
	if (role_tags != key::empty) {
		interaction_parts.push_back(role_tags);
	}
	return join_non_empty(state, key::space_bar_space, interaction_parts);
}

Atom _recruit_source_roster_line(State &state, Atom label, const Value &recruits, int64_t limit, bool dwelling_prices) {
	if (!gd::is_dict(recruits) || gd::is_empty(state, recruits.ref)) {
		return key::empty;
	}
	// for unit_id_value in recruits.keys(): a copy of the keys.
	const state::ValueList recruit_keys = state.dict(recruits.ref).keys.list();
	std::vector<Atom> unit_ids;
	for (const Value &unit_id_value : recruit_keys) {
		const Atom unit_id = string_of(state, unit_id_value);
		if (unit_id != key::empty) {
			unit_ids.push_back(unit_id);
		}
	}
	// unit_ids.sort(): Strings by code point, which is the UTF-8 byte order; equal
	// Strings are the same atom, so the sort's instability shows nowhere.
	std::sort(unit_ids.begin(), unit_ids.end(), [&state](Atom a, Atom b) { return state.text(a) < state.text(b); });
	std::vector<Atom> parts;
	for (const Atom unit_id : unit_ids) {
		const int64_t count = std::max<int64_t>(0, gd::to_int(state, state.get(recruits.ref, str(unit_id), int_value(0))));
		if (count <= 0) {
			continue;
		}
		const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
		const Atom unit_name = text_of(state, unit, key::name, unit_id);
		const Atom role_label = _unit_role_tier_label(state, unit);
		Atom cost_label = _describe_resource_delta(state, field_or_new_dict(state, unit, key::cost));
		if (dwelling_prices && gd::is_empty(state, creature_dwelling_rules::unit_cost(state, unit_id))) {
			cost_label = key::free;
		}
		const ArrayRef detail_parts = _non_empty_strings(state, string_list(state, { role_label, cost_label }));
		const Atom details = state.array_size(detail_parts) != 0
				? gd::format(state, key::s_3, { str(join_array(state, key::comma_space, detail_parts)) })
				: key::empty;
		parts.push_back(gd::format(state, key::d_s_s, { int_value(count), str(unit_name), str(details) }));
		if (static_cast<int64_t>(parts.size()) >= std::max<int64_t>(1, limit)) {
			break;
		}
	}
	const int64_t hidden_count = std::max<int64_t>(0, static_cast<int64_t>(unit_ids.size()) - static_cast<int64_t>(parts.size()));
	if (hidden_count > 0) {
		parts.push_back(gd::format(state, key::d_more_2, { int_value(hidden_count) }));
	}
	return !parts.empty() ? gd::format(state, key::s_colon_s_text, { str(label), str(join_atoms(state, key::comma_space, parts)) }) : key::empty;
}

Atom _unit_role_tier_label(State &state, DictRef unit) {
	const int64_t tier = std::max<int64_t>(1, gd::int_field(state, unit, key::tier, 1));
	Atom role = stripped(state, unit, key::role);
	if (role == key::empty) {
		role = gd::bool_field(state, unit, key::ranged, false) ? key::ranged : key::melee;
	}
	return gd::format(state, key::t_d_s, { int_value(tier), str(_humanize_id(state, role)) });
}

Atom _recruit_source_support_readiness_line(State &state, const Value &session, DictRef node, DictRef site) {
	const DictRef response_state = _resource_site_response_state(state, session, node, site);
	if (gd::int_field(state, response_state, key::watch_days, 0) <= 0) {
		return key::empty;
	}
	std::vector<Atom> parts;
	parts.push_back(text_of(state, response_state, key::action_label, key::support_response_2));
	const DictRef cost = _normalize_resource_dict(state, field_or_new_dict(state, response_state, key::resource_cost));
	const Atom cost_summary = _describe_resource_delta(state, dict_value(cost));
	if (cost_summary != key::empty) {
		Atom readiness = key::ready;
		if (session.kind != Kind::Nil && !_can_afford(state, gd::as_dict(session), dict_value(cost))) {
			const DictRef pool = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, gd::as_dict(session)), key::resources));
			const Atom shortfall = _describe_resource_delta(state, dict_value(_resource_pool_shortfall(state, pool, cost)));
			readiness = shortfall != key::empty ? gd::format(state, key::needs_s, { str(shortfall) }) : key::not_ready;
		}
		parts.push_back(gd::format(state, key::s_s, { str(cost_summary), str(readiness) }));
	}
	const int64_t movement_cost = gd::int_field(state, response_state, key::movement_cost, 0);
	if (movement_cost > 0) {
		// int(session.overworld.get("movement", {}).get("current", 0)) if session != null else 0.
		int64_t movement_left = 0;
		Value movement;
		if (session.kind != Kind::Nil && state.lookup(session_view::overworld(state, gd::as_dict(session)), str(key::movement), movement)) {
			movement_left = gd::to_int(state, ai::vget(state, movement, key::current, int_value(0)));
		}
		parts.push_back(gd::format(state, key::move_d_d, { int_value(movement_left), int_value(movement_cost) }));
	}
	const int64_t watch_days = gd::int_field(state, response_state, key::watch_days, 0);
	parts.push_back(gd::format(state, key::d_day_s, { int_value(watch_days), str(watch_days == 1 ? key::empty : key::s) }));
	const Atom impact_summary = _resource_site_response_effect_summary(state, response_state);
	if (impact_summary != key::empty) {
		parts.push_back(impact_summary);
	}
	return gd::format(state, key::support_s, { str(join_non_empty(state, key::space_bar_space, parts)) });
}

Atom _recruit_source_why_line(State &state, DictRef site) {
	if (creature_dwelling_rules::is_dwelling(state, site)) {
		return key::why_hire_here_each_week_holding;
	}
	std::vector<Atom> reasons;
	if (!gd::is_empty(state, _resource_site_claim_recruits(state, site))) {
		reasons.push_back(key::adds_field_recruits);
	}
	if (!gd::is_empty(state, _resource_site_weekly_recruits(state, site))) {
		reasons.push_back(key::feeds_weekly_musters);
	}
	Value control_income;
	if (state.lookup(site, str(key::control_income), control_income) && gd::is_dict(control_income) && !gd::is_empty(state, control_income.ref)) {
		reasons.push_back(key::keeps_local_pay_flowing);
	}
	if (reasons.empty()) {
		return key::why_securing_it_strengthens_the_local;
	}
	return gd::format(state, key::why_capture_s, { str(join_atoms(state, key::comma_space, reasons)) });
}

Atom _resource_site_action_label(State &state, DictRef node, DictRef site) {
	if (native_transit_rules::is_native(state, node)) {
		const DictRef link = native_transit_rules::link_of(state, node);
		if (text_of(state, link, key::kind) == key::paired_cave) {
			// int(link.get("exit", {}).get("level", 0)).
			int64_t level = 0;
			Value exit;
			if (state.lookup(link, str(key::exit), exit)) {
				level = gd::to_int(state, ai::vget(state, exit, key::level, int_value(0)));
			}
			return level > 0 ? key::travel_underground : key::travel_to_surface;
		}
		return state.array_size(native_transit_rules::destinations(state, node)) != 0 ? key::step_through : key::Inspect;
	}
	const Atom authored_label = text_of(state, site, key::action_label);
	if (authored_label != key::empty) {
		return authored_label;
	}
	if (visit_building_rules::is_visit_building(state, site)) {
		return gd::format(state, key::visit_s, { str(text_of(state, site, key::name, key::Site)) });
	}
	if (creature_dwelling_rules::is_dwelling(state, site)) {
		if (creature_dwelling_rules::is_guarded(state, node, site, 1) && !creature_dwelling_rules::guard_beaten(state, node, key::player)) {
			return key::fight_the_guards;
		}
		return text_of(state, node, key::collected_by_faction_id) == key::player ? key::hire_creatures : key::visit_dwelling;
	}
	if (_resource_site_is_persistent(state, site)) {
		const Atom collected_by = text_of(state, node, key::collected_by_faction_id);
		if (collected_by != key::empty && collected_by != key::player) {
			return key::reclaim_site;
		}
	}
	const Atom family = text_of(state, site, key::family);
	if (family == key::mine) {
		return key::claim_mine;
	}
	if (family == key::neutral_dwelling) {
		return key::secure_dwelling;
	}
	if (family == key::faction_outpost) {
		return key::secure_outpost;
	}
	if (family == key::frontier_shrine) {
		return key::bind_shrine;
	}
	if (family == key::guarded_reward_site) {
		return key::search_vault;
	}
	if (family == key::scouting_structure) {
		return key::secure_watch;
	}
	if (family == key::transit_object) {
		return key::open_route_2;
	}
	if (family == key::repeatable_service) {
		return key::use_service;
	}
	return key::claim_site;
}

Atom _resource_site_role_label(State &state, DictRef node, DictRef site) {
	if (_resource_site_is_persistent(state, site)) {
		const Atom family = text_of(state, site, key::family);
		if (family == key::mine) {
			return key::persistent_economy_site;
		}
		if (family == key::neutral_dwelling) {
			return key::persistent_recruit_site;
		}
		if (family == key::faction_outpost || family == key::scouting_structure || family == key::transit_object) {
			return key::transit_support_object;
		}
		if (family == key::frontier_shrine) {
			return key::support_shrine;
		}
		if (family == key::guarded_reward_site) {
			return key::persistent_reward_site;
		}
		return key::persistent_economy_site;
	}
	if (_resource_site_is_repeatable(state, site)) {
		return key::repeatable_service_2;
	}
	const Atom site_id = text_of(state, node, key::site_id);
	const DictRef map_object = gd::content_row(state, ContentTable::MapObjectForResourceSite, site_id);
	// Both answers are the same text, as in GDScript.
	if (text_of(state, map_object, key::family) == key::pickup) {
		return key::pickup_cache_2;
	}
	return key::pickup_cache_2;
}

Atom _resource_site_control_label(State &state, DictRef node, DictRef site) {
	if (_resource_site_is_persistent(state, site)) {
		const Atom controller = player_identity_rules::resource_controller_id(state, node);
		if (controller == key::empty) {
			return key::Unclaimed;
		}
		if (controller == key::player) {
			return key::player_held;
		}
		const Atom name = _controller_display_name(state, controller, text_of(state, node, key::collected_by_faction_id));
		return gd::format(state, key::ai_held_s, { str(name) });
	}
	if (gd::bool_field(state, node, key::collected, false)) {
		return key::Collected;
	}
	return key::Unclaimed;
}

Atom _resource_site_control_brief(State &state, DictRef node, DictRef site) {
	if (_resource_site_is_persistent(state, site)) {
		const Atom controller = player_identity_rules::resource_controller_id(state, node);
		if (controller == key::empty) {
			return key::control_unclaimed;
		}
		if (controller == key::player) {
			return key::control_player_held;
		}
		const Atom name = _controller_display_name(state, controller, text_of(state, node, key::collected_by_faction_id));
		return gd::format(state, key::control_held_by_s, { str(name) });
	}
	if (gd::bool_field(state, node, key::collected, false)) {
		const Atom controller = player_identity_rules::resource_controller_id(state, node);
		if (controller == key::empty || controller == key::player) {
			return key::state_collected;
		}
		const Atom name = _controller_display_name(state, controller, text_of(state, node, key::collected_by_faction_id));
		return gd::format(state, key::state_collected_by_s, { str(name) });
	}
	return key::state_uncollected;
}

Atom _resource_site_control_detail(State &state, DictRef node, DictRef site) {
	if (visit_building_rules::is_visit_building(state, site)) {
		return gd::format(state, key::stays_on_the_map_each_visit, { str(visit_building_rules::cadence_label(state, site)) });
	}
	if (_resource_site_is_persistent(state, site)) {
		const Atom controller = player_identity_rules::resource_controller_id(state, node);
		if (controller == key::empty) {
			return key::unclaimed_capture_flips_control;
		}
		const Atom income = _describe_resource_delta(state, field_or_new_dict(state, site, key::control_income));
		const Atom held_effects = income != key::empty ? key::income_and_support : key::support;
		if (controller == key::player) {
			const bool plural = state.text(held_effects).find(state.text(key::and_)) != std::string::npos;
			return gd::format(state, key::player_held_s_stay_s_active, { str(held_effects), str(plural ? key::empty : key::s) });
		}
		const Atom name = _controller_display_name(state, controller, text_of(state, node, key::collected_by_faction_id));
		return gd::format(state, key::s_held_reclaim_to_deny_its, { str(name), str(held_effects) });
	}
	if (gd::bool_field(state, node, key::collected, false)) {
		const int64_t collected_day = gd::int_field(state, node, key::collected_day, 0);
		const Atom day_clause = collected_day > 0 ? gd::format(state, key::on_day_d_2, { int_value(collected_day) }) : key::empty;
		const Atom controller = player_identity_rules::resource_controller_id(state, node);
		if (controller == key::empty || controller == key::player) {
			return gd::format(state, key::collected_s, { str(day_clause) });
		}
		const Atom name = _controller_display_name(state, controller, text_of(state, node, key::collected_by_faction_id));
		return gd::format(state, key::collected_by_s_s, { str(name), str(day_clause) });
	}
	return key::uncollected_one_visit_can_claim_it;
}

Atom _resource_site_route_line(State &state, const Value &session_value, DictRef node, DictRef site) {
	std::vector<Atom> parts;
	if (session_value.kind == Kind::Nil || gd::is_empty(state, node)) {
		return key::empty;
	}
	const DictRef session = gd::as_dict(session_value);
	const DictRef linked_town_result = _resource_node_linked_town(state, session, node, key::player);
	if (gd::int_field(state, linked_town_result, key::index, -1) >= 0) {
		const DictRef town = gd::as_dict(field_or_new_dict(state, linked_town_result, key::town));
		parts.push_back(gd::format(state, key::linked_s, { str(_town_name(state, town)) }));
	} else if (text_of(state, node, key::collected_by_faction_id) == key::player) {
		parts.push_back(key::no_owned_town_support_in_range);
	}
	const DictRef response_state = _resource_site_response_state(state, session, node, site);
	if (gd::bool_field(state, response_state, key::active, false)) {
		const Atom action_label = text_of(state, response_state, key::action_label, key::route_security);
		const int64_t remaining_days = gd::int_field(state, response_state, key::remaining_days, 0);
		const Atom plural = gd::int_field(state, response_state, key::remaining_days, 0) == 1 ? key::empty : key::s;
		Atom response_line = gd::format(state, key::s_active_d_day_s, { str(action_label), int_value(remaining_days), str(plural) });
		if (text_of(state, response_state, key::commander_name) != key::empty) {
			const Atom detached = gd::format(state, key::s_detached, { str(text_of(state, response_state, key::commander_name)) });
			response_line = append_text(state, response_line, detached);
		}
		parts.push_back(response_line);
	} else if (text_of(state, node, key::collected_by_faction_id) == key::player && gd::int_field(state, response_state, key::watch_days, 0) > 0) {
		parts.push_back(gd::format(state, key::s_available, { str(text_of(state, response_state, key::action_label, key::route_security)) }));
	}
	const Atom delivery_line = _resource_site_delivery_line(state, session, node, site);
	if (delivery_line != key::empty) {
		parts.push_back(delivery_line);
	}
	return join_non_empty(state, key::space_bar_space, parts);
}

Atom _resource_site_guard_or_contest_line(State &state, const Value &session, DictRef node, DictRef site) {
	// _resource_site_guard_encounter answers {} for a null session.
	const DictRef guard_encounter = session.kind == Kind::Nil
			? state.new_dict()
			: _resource_site_guard_encounter(state, gd::as_dict(session), node, site, Value());
	if (!gd::is_empty(state, guard_encounter)) {
		const DictRef guard = _resource_site_guard_link_for_encounter(state, guard_encounter);
		Atom line = gd::format(state, key::guarded_by_s, { str(encounter_display_name(state, guard_encounter)) });
		if (_resource_site_guard_blocks_node(state, guard_encounter, node)) {
			line = append_text(state, line, key::clear_guard_to_use_site);
		} else if (gd::bool_field(state, guard, key::blocks_approach, false)) {
			line = append_text(state, line, key::blocks_approach_2);
		}
		return line;
	}
	const Atom controller = player_identity_rules::resource_controller_id(state, node);
	if (controller == key::empty) {
		return key::empty;
	}
	const DictRef contest_encounter = _resource_site_contest_encounter(state, session, node, controller);
	if (!gd::is_empty(state, contest_encounter)) {
		return gd::format(state, key::s_is_contesting_this_site, { str(encounter_display_name(state, contest_encounter)) });
	}
	// _resource_site_under_threat answers false for a null session.
	if (session.kind != Kind::Nil && _resource_site_under_threat(state, gd::as_dict(session), node, controller)) {
		return key::hostile_pressure_is_contesting_this_site;
	}
	return key::empty;
}

DictRef _resource_site_contest_encounter(State &state, const Value &session_value, DictRef node, Atom controller_id) {
	if (session_value.kind == Kind::Nil) {
		return state.new_dict();
	}
	const DictRef session = gd::as_dict(session_value);
	DictRef best = state.new_dict();
	const std::vector<Value> encounters = field_items_of(state, session_view::overworld(state, session), key::encounters);
	for (const Value &encounter : encounters) {
		if (!gd::is_dict(encounter) || is_encounter_resolved(state, session, encounter.ref)) {
			continue;
		}
		if (player_identity_rules::raid_controller_id(state, encounter.ref) == key::empty
				|| player_identity_rules::allied(state, dict_value(session), player_identity_rules::raid_controller_id(state, encounter.ref), controller_id)) {
			continue;
		}
		if (text_of(state, encounter.ref, key::target_kind) != key::resource) {
			continue;
		}
		if (text_of(state, encounter.ref, key::target_placement_id) != text_of(state, node, key::placement_id)) {
			continue;
		}
		if (gd::is_empty(state, best) || gd::int_field(state, encounter.ref, key::goal_distance, 9999) < gd::int_field(state, best, key::goal_distance, 9999)) {
			best = encounter.ref;
		}
	}
	return best;
}

Atom _resource_site_object_class_label(State &state, DictRef site, DictRef map_object) {
	Atom primary_class = stripped(state, map_object, key::primary_class);
	if (primary_class == key::empty) {
		primary_class = stripped(state, site, key::family);
	}
	if (primary_class == key::empty) {
		return key::empty;
	}
	return gd::format(state, key::class_s, { str(_humanize_id(state, primary_class)) });
}

Atom _resource_site_interaction_cadence(State &state, DictRef site, DictRef map_object) {
	// map_object.get("interaction", {}): a missing one is an empty Dictionary.
	Value interaction;
	if (state.lookup(map_object, str(key::interaction), interaction) && gd::is_dict(interaction)) {
		const Atom cadence = stripped(state, interaction.ref, key::cadence);
		if (cadence != key::empty) {
			return cadence;
		}
	}
	if (_resource_site_is_persistent(state, site)) {
		return key::persistent_control;
	}
	if (_resource_site_is_repeatable(state, site)) {
		return key::repeatable;
	}
	return key::one_time;
}

Atom _interaction_cadence_label(State &state, Atom cadence) {
	if (cadence == key::persistent_control) {
		return key::cadence_persistent_control;
	}
	if (cadence == key::one_time) {
		return key::cadence_one_time;
	}
	if (cadence == key::repeatable) {
		return key::cadence_repeatable;
	}
	if (cadence == key::repeatable_daily) {
		return key::cadence_repeatable_daily;
	}
	if (cadence == key::repeatable_weekly) {
		return key::cadence_repeatable_weekly;
	}
	if (cadence == key::cooldown_days) {
		return key::cadence_cooldown_days;
	}
	if (cadence == key::conditional) {
		return key::cadence_conditional;
	}
	if (cadence == key::none) {
		return key::cadence_none;
	}
	return cadence != key::empty ? gd::format(state, key::cadence_s, { str(_humanize_id(state, cadence)) }) : key::empty;
}

Atom _resource_site_role_tag_summary(State &state, DictRef site, DictRef map_object) {
	ArrayRef roles = _string_array(state, field_or_new_array(state, map_object, key::secondary_tags));
	if (state.array_size(roles) == 0) {
		roles = _string_array(state, field_or_new_array(state, map_object, key::map_roles));
	}
	if (state.array_size(roles) == 0) {
		roles = _fallback_resource_site_roles(state, site);
	}
	std::vector<Atom> visible;
	const int64_t count = state.array_size(roles);
	for (int64_t index = 0; index < count; ++index) {
		const Atom label = _humanize_id(state, gd::to_string(state.at(roles, index)));
		if (label != key::empty && std::find(visible.begin(), visible.end(), label) == visible.end()) {
			visible.push_back(label);
		}
		if (visible.size() >= 3) {
			break;
		}
	}
	return !visible.empty() ? gd::format(state, key::roles_s, { str(join_atoms(state, key::comma_space, visible)) }) : key::empty;
}

ArrayRef _fallback_resource_site_roles(State &state, DictRef site) {
	const Atom family = text_of(state, site, key::family);
	std::vector<Atom> roles;
	if (family == key::mine) {
		roles = { key::income };
	} else if (family == key::neutral_dwelling) {
		roles = { key::recruit_source_2, key::weekly_muster };
	} else if (family == key::faction_outpost) {
		roles = { key::frontier_watch_2, key::route_support };
	} else if (family == key::frontier_shrine) {
		roles = { key::spell_route, key::recovery };
	} else if (family == key::transit_object) {
		roles = { key::route_link };
	} else if (family == key::repeatable_service) {
		roles = { key::service };
	} else {
		roles = { key::route_pacing };
	}
	// -> Array[String]: the literal is returned typed.
	const ArrayRef result = gd::new_typed_array(state, state::variant_type::STRING);
	for (const Atom role : roles) {
		state.append(result, str(role));
	}
	return result;
}

Atom _controller_display_name(State &state, Atom controller_id, Atom faction_id) {
	if (controller_id == key::enemy) {
		return key::enemy;
	}
	const DictRef faction = gd::content_row(state, ContentTable::Faction, faction_id != key::empty ? faction_id : controller_id);
	if (!gd::is_empty(state, faction)) {
		const Atom label = text_of(state, faction, key::name, controller_id);
		if (gd::begins_with(state, controller_id, key::player_)) {
			return gd::format(state, key::s_player_s, { str(label), str(gd::trim_prefix(state, controller_id, key::player_)) });
		}
		return label;
	}
	return controller_id;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
