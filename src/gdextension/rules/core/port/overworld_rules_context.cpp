// OverworldRules for the human seat's context (Phase 7, slice 7.3): the active
// context, its actions and the action's briefing, a resource site's context
// summary and the encounter's pressure texts.

#include "aurelion_rules/port/overworld_rules_context.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/battle_payload.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/native_transit_rules.hpp"
#include "aurelion_rules/port/native_transit_rules_ai.hpp"
#include "aurelion_rules/port/native_transit_rules_turn.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/resource_node_payload_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

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
using gd::PackedRef;
using gd::str;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS, in order.
constexpr Atom kLiveStockpileResourceKeys[] = {key::gold, key::wood, key::ore, key::aetherglass, key::embergrain, key::peatwax, key::verdant_grafts, key::brass_scrip, key::memory_salt};

// String(x): stringify(), the engine's str() for a float, a container or an
// object.
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

// String(x.get(field, fallback)) of an untyped value.
Atom value_field_text(State &state, const Value &object, Atom field, Atom fallback) {
	return value_text(state, ai::vget(state, object, field, str(fallback)));
}

// d.get(field, {}) where the answer is kept or passed on: a new Dictionary when
// it is missing.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}

// session.overworld.get("resource_nodes", []) passed where an Array is typed.
ArrayRef resource_nodes_of(State &state, DictRef session, const char *where) {
	Value nodes;
	if (!state.lookup(session_view::overworld(state, session), str(key::resource_nodes), nodes)) {
		return state.new_array();
	}
	return ai::typed_array(nodes, where);
}

// separator.join(parts) of Strings built here.
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

// {"type": type} and {"type": type, field: value}.
DictRef typed_context(State &state, Atom type, Atom field, const Value &value) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::type), str(type));
	if (field != key::empty) {
		state.set(result, str(field), value);
	}
	return result;
}

// {"id": id, "label": label, "summary": summary}.
DictRef context_action(State &state, Atom id, Atom label, Atom summary) {
	const DictRef action = state.new_dict();
	state.set(action, str(key::id), str(id));
	state.set(action, str(key::label), str(label));
	state.set(action, str(key::summary), str(summary));
	return action;
}

// text.to_lower(): ASCII here, any other text by the engine (String::to_lower
// and its Unicode case tables, through an Expression).
Atom to_lower(State &state, Atom text) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		const unsigned char byte = static_cast<unsigned char>(c);
		if (byte >= 0x80) {
			const Value expression = gd::class_instantiate(state, key::Expression);
			const PackedRef names = gd::new_strings(state);
			gd::packed_append_string(state, names, key::text);
			gd::call_method(state, expression, key::parse, {str(key::text_to_lower), gd::strings_value(names)});
			const ArrayRef inputs = state.new_array();
			state.append(inputs, str(text));
			return gd::to_string(gd::call_method(state, expression, key::execute, {array_value(inputs)}));
		}
		if (byte >= 'A' && byte <= 'Z') {
			c = static_cast<char>(byte - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

} // namespace

namespace overworld_rules {

Atom describe_native_portal(State &state, DictRef session, DictRef node) {
	const DictRef indexed = native_transit_rules::nodes_by_id(state, resource_nodes_of(state, session, "OverworldRules.describe_native_portal"));
	const Atom error = native_transit_rules::contract_error(state, node, indexed);
	if (error != key::empty) {
		return gd::format(state, key::this_portal_has_an_invalid_destination, {str(error)});
	}
	const Atom name = native_portal_display_name(state, node);
	const Atom colour = field_text(state, native_transit_rules::network_colour(state, node), key::name, key::empty);
	const ArrayRef options = native_transit_rules::destinations(state, node);
	std::vector<Atom> places;
	for (const Value &destination : gd::items(state, array_value(options))) {
		const Value tile = native_transit_rules::point(state, ai::vget(state, destination, key::exit));
		if (is_tile_explored(state, session, tile.vx(), tile.vy(), tile.vz())) {
			places.push_back(state.intern(gd::format_pair(tile.vx(), tile.vy())));
		}
	}
	const Atom where = places.empty() ? key::empty : gd::format(state, key::s_3, {str(join_atoms(state, key::comma_space, places))});
	const int64_t option_count = state.array_size(options);
	Atom peer_name = key::empty;
	if (option_count > 0) {
		const Atom peer_id = value_field_text(state, state.at(options, 0), key::target_placement_id, key::empty);
		peer_name = native_portal_display_name(state, gd::as_dict(field_or_new_dict(state, indexed, peer_id)));
	}
	const Atom kind = native_transit_rules::portal_kind(state, node);
	if (kind == key::one_way_exit) {
		return gd::format(state, key::s_a_one_way_exit_travellers, {str(name), str(colour)});
	}
	if (kind == key::one_way_entrance) {
		if (option_count == 0) {
			return gd::format(state, key::s_a_one_way_portal_whose, {str(name)});
		}
		if (option_count == 1) {
			return gd::format(state, key::s_a_one_way_portal_to, {str(name), str(peer_name), str(where)});
		}
		return gd::format(state, key::s_a_one_way_portal_it, {str(name), int_value(option_count), str(peer_name), str(where)});
	}
	if (option_count == 0) {
		return gd::format(state, key::s_a_two_way_portal_whose, {str(name)});
	}
	if (option_count == 1) {
		return gd::format(state, key::s_a_two_way_portal_to, {str(name), str(peer_name), str(where)});
	}
	return gd::format(state, key::s_a_two_way_portal_it, {str(name), int_value(option_count), str(peer_name), str(where)});
}

DictRef perform_context_action(State &state, DictRef session, Atom action_id) {
	// session == null: a view is never null.
	if (action_id == key::collect_resource) {
		return collect_active_resource(state, session);
	}
	if (action_id == key::collect_artifact) {
		return collect_active_artifact(state, session);
	}
	if (action_id == key::capture_town) {
		return capture_active_town(state, session);
	}
	if (action_id == key::site_response) {
		return _issue_active_site_response(state, session);
	}
	if (gd::begins_with(state, action_id, key::build)) {
		return build_in_active_town(state, session, gd::trim_prefix(state, action_id, key::build));
	}
	if (gd::begins_with(state, action_id, key::recruit_2)) {
		return recruit_in_active_town(state, session, gd::trim_prefix(state, action_id, key::recruit_2));
	}
	return state.new_dict();
}

DictRef get_active_context(State &state, DictRef session) {
	normalize_overworld_state(state, session);
	const Vector2i pos = hero_position(state, session);
	if (!is_tile_visible(state, session, pos.x, pos.y)) {
		return typed_context(state, key::empty_2, key::empty, Value());
	}

	const DictRef guard_result = _find_guard_engagement_at_tile(state, session, pos.x, pos.y);
	if (gd::int_field(state, guard_result, key::index, -1) >= 0) {
		return typed_context(state, key::encounter, key::encounter, field_or_new_dict(state, guard_result, key::encounter));
	}

	const DictRef town_result = _find_active_town(state, session);
	if (gd::int_field(state, town_result, key::index, -1) >= 0) {
		return typed_context(state, key::town, key::town, field_or_new_dict(state, town_result, key::town));
	}

	const DictRef resource_result = _find_context_resource_node(state, session);
	if (gd::int_field(state, resource_result, key::index, -1) >= 0) {
		return typed_context(state, key::resource, key::node, field_or_new_dict(state, resource_result, key::node));
	}

	const DictRef artifact_result = _find_active_artifact_node(state, session);
	if (gd::int_field(state, artifact_result, key::index, -1) >= 0) {
		return typed_context(state, key::artifact, key::node, field_or_new_dict(state, artifact_result, key::node));
	}

	const DictRef encounter = get_active_encounter(state, session);
	if (!gd::is_empty(state, encounter)) {
		return typed_context(state, key::encounter, key::encounter, dict_value(encounter));
	}

	const DictRef rendezvous = _field_rendezvous_hero_at_tile(state, session, pos);
	if (!gd::is_empty(state, rendezvous)) {
		return typed_context(state, key::rendezvous, key::hero, dict_value(rendezvous));
	}

	return typed_context(state, key::empty_2, key::empty, Value());
}

ArrayRef get_context_actions(State &state, DictRef session) {
	const ArrayRef actions = state.new_array();
	const DictRef context = get_active_context(state, session);
	const Atom type = field_text(state, context, key::type, key::empty_2);
	if (type == key::town) {
		const Value town = field_or_new_dict(state, context, key::town);
		if (value_field_text(state, town, key::owner, key::neutral) != key::player) {
			const Atom owner = value_field_text(state, town, key::owner, key::neutral);
			Atom label = key::empty;
			if (owner == key::enemy && _town_requires_assault(state, gd::as_dict(town))) {
				label = key::assault_town;
			} else {
				label = owner == key::enemy ? key::capture_town_2 : key::claim_town;
			}
			const Atom summary = _context_action_summary(state, session, key::capture_town, context);
			state.append(actions, dict_value(context_action(state, key::capture_town, label, summary)));
		} else {
			const Atom summary = _context_action_summary(state, session, key::visit_town, context);
			state.append(actions, dict_value(context_action(state, key::visit_town, key::visit_town_2, summary)));
		}
	} else if (type == key::resource) {
		const Value node_value = field_or_new_dict(state, context, key::node);
		const DictRef node = gd::as_dict(node_value);
		const DictRef site = resource_node_payload_rules::site_for_node(state, node, state.new_dict());
		if (_resource_node_claimable_by_player(state, node, site, dict_value(session))) {
			const Atom collection_resource_id = resource_site_primary_stockpile_resource_id(state, site);
			// session.overworld.get("army", {}).get("stacks", [])
			Value army;
			const Value stacks = state.lookup(session_view::overworld(state, session), str(key::army), army)
					? ai::vget(state, army, key::stacks, array_value(state.new_array()))
					: array_value(state.new_array());
			const DictRef admission = hero_command_rules::army_addition_split(state, stacks, _resource_site_claim_recruits(state, site));
			const DictRef overflow = gd::as_dict(field_or_new_dict(state, admission, key::overflow));
			const Atom label = _resource_site_action_label(state, node, site);
			const Atom summary = gd::is_empty(state, overflow)
					? _context_action_summary(state, session, key::collect_resource, context)
					: gd::format(state, key::no_room_for_s_you_may, {str(_describe_recruit_count(state, overflow))});
			const DictRef action = state.new_dict();
			state.set(action, str(key::id), str(key::collect_resource));
			state.set(action, str(key::label), str(label));
			state.set(action, str(key::summary), str(summary));
			state.set(action, str(key::disabled), bool_value(false));
			state.set(action, str(key::resource_id), str(collection_resource_id));
			state.set(action, str(key::resource_icon_path), str(resource_icon_path(state, collection_resource_id)));
			state.append(actions, dict_value(action));
		} else if (_resource_site_is_persistent(state, site) && field_text(state, node, key::collected_by_faction_id, key::empty) == key::player) {
			const DictRef response_action = _resource_site_response_action(state, session, node, site);
			if (!gd::is_empty(state, response_action)) {
				state.append(actions, dict_value(response_action));
			}
		}
		const DictRef artifact_result = _find_active_artifact_node(state, session);
		if (gd::int_field(state, artifact_result, key::index, -1) >= 0) {
			const DictRef artifact_context = typed_context(state, key::artifact, key::node, field_or_new_dict(state, artifact_result, key::node));
			const Atom summary = _context_action_summary(state, session, key::collect_artifact, artifact_context);
			state.append(actions, dict_value(context_action(state, key::collect_artifact, key::recover_artifact, summary)));
		}
	} else if (type == key::artifact) {
		const Atom summary = _context_action_summary(state, session, key::collect_artifact, context);
		state.append(actions, dict_value(context_action(state, key::collect_artifact, key::recover_artifact, summary)));
	} else if (type == key::encounter) {
		const Atom summary = _context_action_summary(state, session, key::enter_battle, context);
		state.append(actions, dict_value(context_action(state, key::enter_battle, key::enter_battle_2, summary)));
	} else if (type == key::rendezvous) {
		// var hero: Dictionary = context.get("hero", {}) if ... is Dictionary else {}
		Value hero;
		const bool has_hero = state.lookup(context, str(key::hero), hero) && gd::is_dict(hero);
		const Atom hero_name = has_hero ? field_text(state, hero.ref, key::name, key::the_reserve_commander) : key::the_reserve_commander;
		const Atom summary = gd::format(state, key::meet_s_to_exchange_troops_artifacts, {str(hero_name)});
		state.append(actions, dict_value(context_action(state, key::open_rendezvous, key::Meet, summary)));
	}
	return actions;
}

Atom _resource_site_context_summary(State &state, DictRef session, DictRef node, DictRef site_value) {
	const DictRef site = resource_node_payload_rules::site_for_node(state, node, site_value);
	if (native_transit_rules::is_native(state, node)) {
		if (native_transit_rules::portal_kind(state, node) != key::empty) {
			return describe_native_portal(state, session, node);
		}
		const DictRef resolved = native_transit_rules::resolve(state, resource_nodes_of(state, session, "OverworldRules._resource_site_context_summary"), node, key::empty);
		if (!gd::bool_field(state, resolved, key::ok, false)) {
			return field_text(state, resolved, key::message, key::this_passage_is_unavailable);
		}
		// var exit: Vector3i = resolved.exit
		const Value exit = gd::index(state, resolved, str(key::exit));
		if (!gd::is_vector3i(exit)) {
			throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(exit) + "' to a variable of type 'Vector3i'.");
		}
		return gd::format(state, key::paired_passage_to_s_d_d, {str(exit.vz() > 0 ? key::the_underground : key::the_surface), int_value(exit.vx()), int_value(exit.vy())});
	}
	std::vector<Atom> parts;
	const Atom surface = describe_resource_site_surface(state, session, node, site);
	if (surface != key::empty) {
		parts.push_back(surface);
	}
	const Atom interaction_surface = describe_resource_site_interaction_surface(state, node, site);
	if (interaction_surface != key::empty) {
		parts.push_back(interaction_surface);
	}
	const Atom control_inspection = describe_resource_site_control_inspection(state, gd::dict_value(session), node, site);
	if (control_inspection != key::empty) {
		parts.push_back(control_inspection);
	}
	if (_resource_site_is_persistent(state, site)) {
		const Atom controller = player_identity_rules::resource_controller_id(state, node);
		if (controller == key::empty) {
			parts.push_back(key::control_unclaimed);
		} else if (controller == key::player) {
			parts.push_back(key::control_secured);
		} else {
			const DictRef faction = gd::content_row(state, ContentTable::Faction, controller);
			parts.push_back(gd::format(state, key::control_denied_by_s, {str(field_text(state, faction, key::name, controller))}));
		}
	}
	const Atom neutral_dwelling_label = _resource_site_neutral_dwelling_label(state, site);
	if (neutral_dwelling_label != key::empty) {
		parts.push_back(gd::format(state, key::neutral_family_s, {str(neutral_dwelling_label)}));
	}
	const Atom income_summary = _describe_resource_delta(state, field_or_new_dict(state, site, key::control_income));
	if (income_summary != key::empty) {
		parts.push_back(gd::format(state, key::s_s, {str(_resource_site_income_cadence_label(state, site)), str(income_summary)}));
	}
	const Atom weekly_summary = _describe_recruit_delta(state, dict_value(_resource_site_weekly_recruits(state, site)));
	if (weekly_summary != key::empty) {
		parts.push_back(gd::format(state, key::weekly_s_2, {str(weekly_summary)}));
	}
	const Atom claim_summary = _describe_recruit_delta(state, dict_value(_resource_site_claim_recruits(state, site)));
	if (claim_summary != key::empty) {
		parts.push_back(gd::format(state, key::field_recruits_s, {str(claim_summary)}));
	}
	const Atom reward_summary = _resource_site_reward_summary(state, site);
	if (reward_summary != key::empty) {
		parts.push_back(gd::format(state, key::reward_s, {str(reward_summary)}));
	}
	const Atom artifact_summary = _resource_site_artifact_summary(state, site);
	if (artifact_summary != key::empty) {
		parts.push_back(gd::format(state, key::holds_s, {str(artifact_summary)}));
	}
	const int64_t vision_radius = compat::engine_max<int64_t>(0, gd::int_field(state, site, key::vision_radius, 0));
	if (vision_radius > 0) {
		parts.push_back(gd::format(state, key::scout_ring_d, {int_value(vision_radius)}));
	}
	const int64_t pressure_guard = compat::engine_max<int64_t>(0, gd::int_field(state, site, key::pressure_guard, 0));
	if (pressure_guard > 0) {
		parts.push_back(gd::format(state, key::pressure_guard_d_2, {int_value(pressure_guard)}));
	}
	const DictRef town_support = _resource_site_town_support(state, site);
	std::vector<Atom> support_parts;
	if (gd::int_field(state, town_support, key::readiness_bonus, 0) > 0) {
		support_parts.push_back(gd::format(state, key::readiness_d, {int_value(gd::int_field(state, town_support, key::readiness_bonus, 0))}));
	}
	if (gd::int_field(state, town_support, key::quality_bonus, 0) > 0) {
		support_parts.push_back(gd::format(state, key::quality_d, {int_value(gd::int_field(state, town_support, key::quality_bonus, 0))}));
	}
	if (gd::int_field(state, town_support, key::pressure_bonus, 0) > 0) {
		support_parts.push_back(gd::format(state, key::pressure_d, {int_value(gd::int_field(state, town_support, key::pressure_bonus, 0))}));
	}
	if (gd::int_field(state, town_support, key::growth_bonus_percent, 0) > 0) {
		support_parts.push_back(gd::format(state, key::growth_d, {int_value(gd::int_field(state, town_support, key::growth_bonus_percent, 0))}));
	}
	if (gd::int_field(state, town_support, key::recovery_relief, 0) > 0) {
		support_parts.push_back(gd::format(state, key::recovery_d_2, {int_value(gd::int_field(state, town_support, key::recovery_relief, 0))}));
	}
	if (!support_parts.empty()) {
		parts.push_back(gd::format(state, key::town_support_s, {str(join_atoms(state, key::comma_space, support_parts))}));
	}
	const ArrayRef lesson_names = _resource_site_spell_names(state, site);
	if (state.array_size(lesson_names) != 0) {
		parts.push_back(gd::format(state, key::teaches_s_2, {str(_spell_list_text(state, lesson_names))}));
	}
	if (_resource_site_is_repeatable(state, site)) {
		const Atom service_summary = field_text(state, site, key::service_summary, key::empty);
		if (service_summary != key::empty) {
			parts.push_back(service_summary);
		}
		const Atom visit_cost_summary = _describe_resource_delta(state, dict_value(_resource_site_visit_cost(state, site)));
		if (visit_cost_summary != key::empty) {
			parts.push_back(gd::format(state, key::service_cost_s_2, {str(visit_cost_summary)}));
		}
		if (_resource_site_repeat_ready(state, session, node, site)) {
			parts.push_back(key::service_ready_2);
		} else if (gd::bool_field(state, node, key::collected, false)) {
			parts.push_back(gd::format(state, key::next_service_day_d_2, {int_value(_resource_site_next_visit_day(state, node, site))}));
		}
	}
	// var guard_profile = site.get("guard_profile", {}): read only.
	Value guard_profile;
	if (state.lookup(site, str(key::guard_profile), guard_profile) && gd::is_dict(guard_profile) && !gd::is_empty(state, guard_profile.ref)) {
		parts.push_back(gd::format(state, key::guard_s_s, {
				str(field_text(state, guard_profile.ref, key::threat, key::unknown)),
				str(field_text(state, guard_profile.ref, key::reward_tone, key::reward_site)),
		}));
	}
	Value transit_profile;
	if (state.lookup(site, str(key::transit_profile), transit_profile) && gd::is_dict(transit_profile) && !gd::is_empty(state, transit_profile.ref)) {
		parts.push_back(gd::format(state, key::transit_s_s, {
				str(field_text(state, transit_profile.ref, key::mode, key::route)),
				str(field_text(state, transit_profile.ref, key::route_role, key::link)),
		}));
	}
	const DictRef response_state = _resource_site_response_state(state, session, node, site);
	const DictRef delivery_state = _resource_site_delivery_state(state, session, node, site);
	if (gd::bool_field(state, response_state, key::active, false)) {
		const int64_t remaining_days = gd::int_field(state, response_state, key::remaining_days, 0);
		std::string response_line = state.text(gd::format(state, key::s_escort_d_day_s, {
				str(field_text(state, response_state, key::action_label, key::route_secure)),
				int_value(remaining_days),
				str(remaining_days == 1 ? key::empty : key::s),
		}));
		const Atom commander_name = field_text(state, response_state, key::commander_name, key::empty);
		if (commander_name != key::empty) {
			response_line += state.text(gd::format(state, key::s_detached_2, {str(commander_name)}));
		}
		const Atom impact_summary = _resource_site_response_effect_summary(state, response_state);
		if (impact_summary != key::empty) {
			response_line += state.text(gd::format(state, key::space_bar_space_s, {str(impact_summary)}));
		}
		parts.push_back(state.intern(response_line));
		if (gd::bool_field(state, delivery_state, key::active, false)) {
			parts.push_back(_resource_site_delivery_line(state, session, node, site));
		}
	} else if (field_text(state, node, key::collected_by_faction_id, key::empty) == key::player && gd::int_field(state, response_state, key::watch_days, 0) > 0) {
		const Atom ready_commander = field_text(state, response_state, key::commander_name, key::empty);
		if (ready_commander != key::empty) {
			parts.push_back(gd::format(state, key::commit_s_to_escort_s_and, {
					str(ready_commander),
					str(to_lower(state, field_text(state, response_state, key::action_label, key::route_security_2))),
			}));
		} else {
			parts.push_back(gd::format(state, key::order_s_to_steady_nearby_threat, {str(field_text(state, response_state, key::action_label, key::route_security_2))}));
		}
		const DictRef linked_town_result = _resource_node_linked_town(state, session, node, key::player);
		if (gd::int_field(state, linked_town_result, key::index, -1) >= 0) {
			const DictRef source_town = gd::as_dict(field_or_new_dict(state, linked_town_result, key::town));
			const DictRef delivery_plan = _player_reserve_delivery_plan(state, session, source_town, response_state);
			if (!gd::is_empty(state, delivery_plan)) {
				const Atom manifest_summary = _describe_recruit_delta(state, field_or_new_dict(state, delivery_plan, key::manifest));
				const int64_t eta_days = gd::int_field(state, delivery_plan, key::eta_days, 1);
				parts.push_back(gd::format(state, key::next_convoy_s_for_s_in, {
						str(manifest_summary),
						str(field_text(state, delivery_plan, key::target_label, key::the_front)),
						int_value(eta_days),
						str(eta_days == 1 ? key::empty : key::s),
				}));
			}
		}
	}
	if (parts.empty()) {
		return key::claim_the_site_to_add_its;
	}
	return join_atoms(state, key::space_bar_space, parts);
}

Atom resource_site_primary_stockpile_resource_id(State &state, DictRef site) {
	const DictRef rewards = _resource_site_claim_rewards(state, site);
	for (const Atom resource_id : kLiveStockpileResourceKeys) {
		if (resource_id != key::gold && gd::int_field(state, rewards, resource_id, 0) > 0) {
			return resource_id;
		}
	}
	return gd::int_field(state, rewards, key::gold, 0) > 0 ? key::gold : key::empty;
}

Atom _context_action_briefing(State &state, DictRef session, const Value &action, DictRef context) {
	if (!gd::is_dict(action)) {
		return key::review_the_current_tile_and_commit;
	}
	const Atom action_id = field_text(state, action.ref, key::id, key::empty);
	if (action_id == key::visit_town) {
		const Value town = field_or_new_dict(state, context, key::town);
		return gd::format(state, key::enter_s_now_to_review_construction, {str(_town_name(state, gd::as_dict(town)))});
	}
	if (action_id == key::capture_town) {
		const Value town = field_or_new_dict(state, context, key::town);
		const Atom owner = value_field_text(state, town, key::owner, key::neutral);
		if (owner == key::enemy) {
			if (_town_requires_assault(state, gd::as_dict(town))) {
				return gd::format(state, key::storm_s_now_the_hostile_garrison, {str(_town_name(state, gd::as_dict(town)))});
			}
			return gd::format(state, key::capture_s_from_the_hostile_garrison, {str(_town_name(state, gd::as_dict(town)))});
		}
		return gd::format(state, key::claim_s_now_to_secure_a, {str(_town_name(state, gd::as_dict(town)))});
	}
	if (action_id == key::collect_resource) {
		const DictRef node = gd::as_dict(field_or_new_dict(state, context, key::node));
		if (native_transit_rules::is_native(state, node)) {
			if (native_transit_rules::portal_kind(state, node) != key::empty) {
				return gd::format(state, key::step_through_the_s_costs_1, {str(native_portal_display_name(state, node))});
			}
			return key::use_the_paired_passage_costs_1;
		}
		const DictRef site = resource_node_payload_rules::site_for_node(state, node, state.new_dict());
		return gd::format(state, key::secure_s_now_to_s, {
				str(field_text(state, site, key::name, key::this_site)),
				str(_resource_site_opening_value(state, site)),
		});
	}
	if (action_id == key::site_response) {
		const DictRef node = gd::as_dict(field_or_new_dict(state, context, key::node));
		const DictRef site = resource_node_payload_rules::site_for_node(state, node, state.new_dict());
		const DictRef response_state = _resource_site_response_state(state, session, node, site);
		Atom command_clause = gd::format(state, key::commit_s_at_s, {
				str(field_text(state, response_state, key::action_label, key::secure_route)),
				str(field_text(state, site, key::name, key::the_frontier_site)),
		});
		if (field_text(state, response_state, key::commander_name, key::empty) != key::empty) {
			command_clause = gd::format(state, key::commit_s_to_s_at_s, {
					str(field_text(state, response_state, key::commander_name, key::empty)),
					str(to_lower(state, field_text(state, response_state, key::action_label, key::secure_the_route))),
					str(field_text(state, site, key::name, key::the_frontier_site)),
			});
		}
		const int64_t watch_days = gd::int_field(state, response_state, key::watch_days, 0);
		return gd::format(state, key::s_to_steady_the_local_route, {
				str(command_clause),
				int_value(watch_days),
				str(watch_days == 1 ? key::empty : key::s),
				int_value(gd::int_field(state, response_state, key::security_rating, 1)),
		});
	}
	if (action_id == key::collect_artifact) {
		const Value artifact_node = field_or_new_dict(state, context, key::node);
		const Atom artifact_name = artifact_rules::artifact_name(state, value_field_text(state, artifact_node, key::artifact_id, key::empty));
		const DictRef hero = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero));
		const Atom collection_state = artifact_rules::artifact_collection_state(
				state,
				hero,
				value_field_text(state, artifact_node, key::artifact_id, key::empty),
				gd::to_bool(ai::vget(state, artifact_node, key::collected, bool_value(false))),
				value_field_text(state, artifact_node, key::collected_by_faction_id, key::empty));
		return gd::format(state, key::recover_s_now_s, {str(artifact_name), str(collection_state)});
	}
	if (action_id == key::enter_battle) {
		const DictRef encounter = gd::as_dict(field_or_new_dict(state, context, key::encounter));
		const Atom delivery_pressure = _encounter_delivery_pressure_summary(state, session, encounter, true);
		if (delivery_pressure != key::empty) {
			return delivery_pressure;
		}
		return gd::format(state, key::break_s_now_before_the_host, {str(encounter_display_name(state, encounter))});
	}
	return field_text(state, action.ref, key::summary, key::review_the_current_tile_and_commit);
}

Atom _context_action_summary(State &state, DictRef session, Atom action_id, DictRef context) {
	if (action_id == key::collect_resource) {
		const DictRef node = gd::as_dict(field_or_new_dict(state, context, key::node));
		const DictRef site = resource_node_payload_rules::site_for_node(state, node, state.new_dict());
		return _resource_site_context_summary(state, session, node, site);
	}
	if (action_id == key::collect_artifact) {
		const Value artifact_node = field_or_new_dict(state, context, key::node);
		const Atom artifact_id = value_field_text(state, artifact_node, key::artifact_id, key::empty);
		const Atom short_text = artifact_rules::describe_artifact_short(state, artifact_id);
		const DictRef hero = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero));
		const Atom collection_state = artifact_rules::artifact_collection_state(
				state,
				hero,
				artifact_id,
				gd::to_bool(ai::vget(state, artifact_node, key::collected, bool_value(false))),
				value_field_text(state, artifact_node, key::collected_by_faction_id, key::empty));
		const Atom impact = artifact_rules::describe_single_artifact_impact(state, artifact_id);
		return gd::format(state, key::recover_s_for_the_active_hero, {str(short_text), str(collection_state), str(impact)});
	}
	if (action_id == key::enter_battle) {
		const DictRef encounter = gd::as_dict(field_or_new_dict(state, context, key::encounter));
		return _encounter_pressure_summary(state, session, encounter, true);
	}
	// "visit_town", "capture_town" and any other action: the briefing of {"id": action_id}.
	const DictRef action = state.new_dict();
	state.set(action, str(key::id), str(action_id));
	return _context_action_briefing(state, session, dict_value(action), context);
}

Atom _encounter_delivery_pressure_summary(State &state, DictRef session, DictRef encounter, bool for_battle_prompt) {
	const DictRef delivery_context = delivery_interception_context_for_encounter(state, session, encounter);
	if (!gd::bool_field(state, delivery_context, key::active, false)) {
		return key::empty;
	}
	const Atom encounter_name = encounter_display_name(state, encounter);
	const Value pressure_label = state.get(delivery_context, str(key::pressure_label), str(key::the_relief_lane));
	const Atom route_label = value_text(state, state.get(delivery_context, str(key::route_label), pressure_label));
	const Atom recruit_summary = field_text(state, delivery_context, key::recruit_summary, key::the_convoy_2);
	// var interception_state: Dictionary = delivery_context.get("interception", {}): read only.
	bool blocks_delivery = false;
	Value interception_state;
	if (state.lookup(delivery_context, str(key::interception), interception_state)) {
		blocks_delivery = gd::bool_field(state, gd::as_dict(interception_state), key::blocks_delivery, false);
	}
	if (for_battle_prompt) {
		if (blocks_delivery) {
			return gd::format(state, key::break_s_now_to_reopen_s, {str(encounter_name), str(route_label), str(recruit_summary)});
		}
		return gd::format(state, key::break_s_now_to_keep_s, {
				str(encounter_name),
				str(recruit_summary),
				str(field_text(state, delivery_context, key::target_label, key::the_front)),
		});
	}
	if (blocks_delivery) {
		return gd::format(state, key::s_is_on_s_if_left, {
				str(encounter_name),
				str(route_label),
				str(recruit_summary),
				str(field_text(state, delivery_context, key::target_label, key::the_front)),
		});
	}
	return gd::format(state, key::s_is_hunting_s_breaking_it, {
			str(encounter_name),
			str(route_label),
			str(recruit_summary),
			str(field_text(state, delivery_context, key::target_label, key::the_front)),
	});
}

Atom _encounter_pressure_summary(State &state, DictRef session, DictRef encounter, bool for_battle_prompt) {
	const Atom delivery_pressure = _encounter_delivery_pressure_summary(state, session, encounter, for_battle_prompt);
	if (delivery_pressure != key::empty) {
		return delivery_pressure;
	}

	const Atom encounter_name = encounter_display_name(state, encounter);
	if (field_text(state, encounter, key::spawned_by_faction_id, key::empty) == key::empty) {
		const Atom readability = describe_encounter_compact_readability(state, session, encounter);
		if (for_battle_prompt) {
			const Atom terrain_name = _terrain_name_at(state, session, gd::int_field(state, encounter, key::x, 0), gd::int_field(state, encounter, key::y, 0));
			const Atom battle_order = gd::format(state, key::break_s_on_s_before_the, {str(encounter_name), str(terrain_name)});
			return readability == key::empty ? battle_order : gd::format(state, key::s_s_2, {str(battle_order), str(readability)});
		}
		return readability != key::empty ? gd::format(state, key::scout_report_s, {str(readability)}) : key::approach_strength_unknown_beyond_authored_scouting;
	}

	const Atom target_kind = field_text(state, encounter, key::target_kind, key::empty);
	const Atom target_label = field_text(state, encounter, key::target_label, key::the_frontier);
	const int64_t goal_distance = gd::int_field(state, encounter, key::goal_distance, 9999);
	const bool pressuring = gd::bool_field(state, encounter, key::arrived, false) || goal_distance <= 0;
	if (target_kind == key::hero) {
		if (for_battle_prompt) {
			return gd::format(state, key::break_s_now_before_it_pins, {str(encounter_name), str(target_label)});
		}
		if (pressuring || goal_distance <= 1) {
			return gd::format(state, key::s_is_on_s_s_march, {str(encounter_name), str(target_label)});
		}
		return gd::format(state, key::s_is_hunting_s_across_the, {str(encounter_name), str(target_label)});
	}
	if (target_kind == key::town) {
		if (for_battle_prompt) {
			return gd::format(state, key::break_s_now_before_it_reaches, {str(encounter_name), str(target_label)});
		}
		if (pressuring || goal_distance <= 1) {
			return gd::format(state, key::s_already_presses_s_and_can, {str(encounter_name), str(target_label)});
		}
		return gd::format(state, key::s_is_marching_on_s, {str(encounter_name), str(target_label)});
	}
	if (target_kind == key::resource) {
		if (for_battle_prompt) {
			return gd::format(state, key::break_s_now_before_it_denies, {str(encounter_name), str(target_label)});
		}
		return gd::format(state, key::s_is_moving_to_deny_s, {str(encounter_name), str(target_label)});
	}
	if (target_kind == key::artifact) {
		if (for_battle_prompt) {
			return gd::format(state, key::break_s_now_before_it_secures, {str(encounter_name), str(target_label)});
		}
		return gd::format(state, key::s_is_closing_on_s, {str(encounter_name), str(target_label)});
	}
	if (target_kind == key::encounter) {
		if (for_battle_prompt) {
			return gd::format(state, key::break_s_now_before_it_locks, {str(encounter_name), str(target_label)});
		}
		return gd::format(state, key::s_is_trying_to_lock_down, {str(encounter_name), str(target_label)});
	}
	if (for_battle_prompt) {
		return gd::format(state, key::break_s_now_before_the_host, {str(encounter_name)});
	}
	return key::this_host_is_moving_through_the;
}

Atom _resource_site_opening_value(State &state, DictRef site) {
	const Atom family = field_text(state, site, key::family, key::empty);
	if (family == key::faction_outpost) {
		return key::extend_scouting_and_hold_the_frontier;
	}
	if (family == key::frontier_shrine) {
		return key::keep_spell_routes_and_recovery_lanes;
	}
	if (family == key::neutral_dwelling) {
		return key::feed_musters_into_the_nearest_town;
	}
	return key::strengthen_your_early_reserves;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
