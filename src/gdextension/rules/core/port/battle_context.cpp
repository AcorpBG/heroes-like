// The battle context of an encounter (BattleRules._normalized_battle_context and its fields), a town's
// battlefront and a delivery's interception (OverworldRules).

#include "aurelion_rules/port/battle_payload.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <algorithm>
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
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// String(d.get(key, "")) and String(d.get(key, fallback)).
Atom str_field(State &state, DictRef dict, Atom field) {
	return gd::stringify(state, state.get(dict, str(field), str(key::empty)));
}

Atom str_field_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return gd::stringify(state, state.get(dict, str(field), fallback));
}

// d.get(key, {}) / d.get(key, []) where the result is kept: the value, or a new container.
Value dict_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

Value array_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// lookup.get("town", {}) of a {"index": i, "town": town} result (the item is always a Dictionary).
DictRef found_dict(State &state, DictRef found, Atom field) {
	return gd::as_dict(dict_or_new(state, found, field));
}

// session.overworld of the battle's session.
DictRef session_overworld(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::overworld));
}

// OverworldRules._find_resource_node_by_placement(session, placement_id).get("node", {}): a null
// session answers {"index": -1, "node": {}}.
DictRef resource_node_of(State &state, const Value &session, Atom placement_id) {
	if (session.kind == Kind::Nil) {
		return state.new_dict();
	}
	return found_dict(state, overworld_rules::_find_resource_node_by_placement(state, gd::object_view(state, session), placement_id), key::node);
}

// The interception state literal of _resource_site_delivery_interception (empty_state) and of
// delivery_interception_context_for_encounter's empty context.
DictRef empty_interception(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::active), bool_value(false));
	state.set(result, str(key::arrived), bool_value(false));
	state.set(result, str(key::blocks_delivery), bool_value(false));
	state.set(result, str(key::goal_distance), int_value(9999));
	state.set(result, str(key::strength), int_value(0));
	state.set(result, str(key::encounter_key), str(key::empty));
	state.set(result, str(key::encounter_name), str(key::empty));
	state.set(result, str(key::summary), str(key::empty));
	return result;
}

// delivery_interception_context_for_encounter's empty_context.
DictRef empty_delivery_context(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::active), bool_value(false));
	state.set(result, str(key::node_placement_id), str(key::empty));
	state.set(result, str(key::site_name), str(key::empty));
	state.set(result, str(key::origin_town_id), str(key::empty));
	state.set(result, str(key::origin_town_label), str(key::empty));
	state.set(result, str(key::target_kind), str(key::empty));
	state.set(result, str(key::target_id), str(key::empty));
	state.set(result, str(key::target_label), str(key::empty));
	state.set(result, str(key::route_label), str(key::empty));
	state.set(result, str(key::pressure_label), str(key::empty));
	state.set(result, str(key::arrival_day), int_value(0));
	state.set(result, str(key::recruit_summary), str(key::empty));
	state.set(result, str(key::manifest), dict_value(state.new_dict()));
	state.set(result, str(key::manifest_value), int_value(0));
	state.set(result, str(key::interception), dict_value(empty_interception(state)));
	return result;
}

// The delivery fields every normalized battle context ends with, in their order.
struct DeliveryFields {
	Atom node_placement_id;
	Atom site_name;
	Atom origin_town_id;
	Atom origin_town_label;
	Atom target_kind;
	Atom target_id;
	Atom target_label;
	Atom route_label;
	Atom pressure_label;
	Atom recruit_summary;
	int64_t arrival_day;
};

void set_delivery_fields(State &state, DictRef result, const DeliveryFields &fields) {
	state.set(result, str(key::delivery_node_placement_id), str(fields.node_placement_id));
	state.set(result, str(key::delivery_site_name), str(fields.site_name));
	state.set(result, str(key::delivery_origin_town_id), str(fields.origin_town_id));
	state.set(result, str(key::delivery_origin_town_label), str(fields.origin_town_label));
	state.set(result, str(key::delivery_target_kind), str(fields.target_kind));
	state.set(result, str(key::delivery_target_id), str(fields.target_id));
	state.set(result, str(key::delivery_target_label), str(fields.target_label));
	state.set(result, str(key::delivery_route_label), str(fields.route_label));
	state.set(result, str(key::delivery_pressure_label), str(fields.pressure_label));
	state.set(result, str(key::delivery_recruit_summary), str(fields.recruit_summary));
	state.set(result, str(key::delivery_arrival_day), int_value(fields.arrival_day));
}

// String(context.get(context_field, delivery_context.get(delivery_field, ""))).
Atom delivery_text(State &state, DictRef context, Atom context_field, DictRef delivery_context, Atom delivery_field) {
	const Value fallback = state.get(delivery_context, str(delivery_field), str(key::empty));
	return gd::stringify(state, state.get(context, str(context_field), fallback));
}

} // namespace

namespace battle_rules {

Atom _battle_context_target_hero_id(State &state, const Value &session, DictRef context, const Value &raw_context) {
	Atom target_hero_id = str_field(state, context, key::target_hero_id);
	if (target_hero_id == key::empty) {
		// A missing player_commander_source is {}, whose hero_id is "".
		Value commander_source;
		if (gd::is_dict(raw_context) && state.lookup(raw_context.ref, str(key::player_commander_source), commander_source) && gd::is_dict(commander_source)) {
			target_hero_id = str_field(state, commander_source.ref, key::hero_id);
		}
	}
	if (target_hero_id == key::empty) {
		target_hero_id = str_field(state, session_overworld(state, session), key::active_hero_id);
	}
	if (target_hero_id == key::empty) {
		// session.overworld.get("hero", {}) is Dictionary: a missing hero is {}, whose id is "".
		Value hero;
		if (state.lookup(session_overworld(state, session), str(key::hero), hero) && gd::is_dict(hero)) {
			target_hero_id = str_field(state, hero.ref, key::id);
		}
	}
	if (target_hero_id == key::empty) {
		return key::empty;
	}
	// HeroCommandRules.hero_by_id(null, id) is {}.
	if (session.kind == Kind::Nil || gd::is_empty(state, hero_command_rules::hero_by_id(state, gd::object_view(state, session), target_hero_id))) {
		return key::empty;
	}
	return target_hero_id;
}

DictRef _normalized_battle_context(State &state, const Value &session, const Value &raw_context) {
	const DictRef normalized = _normalized_battle_context_fields(state, session, raw_context);
	const DictRef source = gd::is_dict(raw_context) ? raw_context.ref : state.new_dict();
	// context: source.get("battle_context", source) when it is a Dictionary, else {} (merging {} adds nothing).
	const Value context = state.get(source, str(key::battle_context), dict_value(source));
	const DictRef identity_context = gd::duplicate_dict(state, normalized);
	if (gd::is_dict(context)) {
		gd::merge(state, identity_context, context.ref, true);
	}
	const Atom controller = _battle_context_controller_id(state, session, identity_context, dict_value(source));
	// PlayerRules.player(null, controller) is {}.
	if (session.kind != Kind::Nil) {
		const DictRef view = gd::object_view(state, session);
		if (!gd::is_empty(state, player_identity_rules::player(state, view, controller))) {
			state.set(normalized, str(key::trigger_player_id), str(controller));
			state.set(normalized, str(key::trigger_faction_id), str(player_identity_rules::faction_id(state, view, controller)));
		}
	}
	return normalized;
}

DictRef _normalized_battle_context_fields(State &state, const Value &session, const Value &raw_context) {
	DictRef context = state.new_dict();
	const bool raw_is_dict = gd::is_dict(raw_context);
	if (raw_is_dict) {
		Value nested;
		if (state.lookup(raw_context.ref, str(key::battle_context), nested) && gd::is_dict(nested)) {
			context = nested.ref;
		} else {
			context = raw_context.ref;
		}
	}
	Atom context_type = str_field(state, context, key::type);
	if (context_type == key::empty && raw_is_dict) {
		const DictRef placement = raw_context.ref;
		if (str_field(state, placement, key::spawned_by_faction_id) != key::empty && str_field(state, placement, key::target_kind) == key::town) {
			const DictRef target_town = found_dict(state, _find_town_by_placement(state, session, str_field(state, placement, key::target_placement_id)), key::town);
			// A strategic town target is not a siege. Field contact with a
			// marching raid must use the active hero's army, not a remote town's
			// garrison. Real siege owners supply an explicit context; retain
			// legacy inference only at this town's actual position/entrance.
			const int64_t contact_x = gd::int_field(state, placement, key::x, -9999);
			const int64_t contact_y = gd::int_field(state, placement, key::y, -9999);
			const int64_t contact_level = overworld_level_rules::level_of(state, raw_context);
			const DictRef contact_town = found_dict(state, _find_town_at_position(state, session, contact_x, contact_y, contact_level), key::town);
			const bool at_target_town = !gd::is_empty(state, contact_town) && str_field(state, contact_town, key::placement_id) == str_field(state, target_town, key::placement_id);
			const Atom target_owner = str_field_or(state, target_town, key::owner, str(key::neutral));
			const ArrayRef target_reason_codes = _normalize_string_array(state, state.get(placement, str(key::target_reason_codes), Value()));
			const bool neutral_expansion = target_owner == key::neutral && (gd::array_has(state, target_reason_codes, str(key::town_expansion)) || gd::array_has(state, target_reason_codes, str(key::neutral_town_claim)) || gd::array_has(state, target_reason_codes, str(key::neutral_town_siege)));
			if (at_target_town && (target_owner == key::player || neutral_expansion)) {
				const Value placement_fallback = state.get(placement, str(key::target_placement_id), str(key::empty));
				const Atom town_placement_id = str_field_or(state, target_town, key::placement_id, placement_fallback);
				const Atom raid_encounter_key = overworld_rules::encounter_key(state, placement);
				const Atom trigger_faction_id = str_field(state, placement, key::spawned_by_faction_id);
				context = state.new_dict();
				state.set(context, str(key::type), str(key::town_defense));
				state.set(context, str(key::town_placement_id), str(town_placement_id));
				state.set(context, str(key::defending_hero_id), str(key::empty));
				state.set(context, str(key::raid_encounter_key), str(raid_encounter_key));
				state.set(context, str(key::trigger_faction_id), str(trigger_faction_id));
				state.set(context, str(key::defender_owner), str(target_owner));
				context_type = key::town_defense;
			}
		} else if (str_field(state, placement, key::encounter_id) == key::encounter_town_assault || gd::begins_with(state, str_field(state, placement, key::placement_id), key::town_assault_2)) {
			const Atom assault_town_placement_id = _battle_context_town_placement_id(state, session, context, raw_context);
			if (assault_town_placement_id != key::empty) {
				const DictRef assault_town = found_dict(state, _find_town_by_placement(state, session, assault_town_placement_id), key::town);
				const Atom trigger_faction_id = _battle_context_trigger_faction_id(state, session, context, raw_context, assault_town);
				context = state.new_dict();
				state.set(context, str(key::type), str(key::town_assault));
				state.set(context, str(key::town_placement_id), str(assault_town_placement_id));
				state.set(context, str(key::trigger_faction_id), str(trigger_faction_id));
				context_type = key::town_assault;
			}
		} else if (str_field(state, placement, key::encounter_id) == key::encounter_resource_defense || gd::begins_with(state, str_field(state, placement, key::placement_id), key::resource_defense)) {
			const Atom resource_placement_id = _battle_context_resource_placement_id(state, context, raw_context);
			if (resource_placement_id != key::empty) {
				const DictRef node = resource_node_of(state, session, resource_placement_id);
				const DictRef site = gd::content_row(state, ContentTable::ResourceSite, str_field(state, node, key::site_id));
				const Atom resource_site_id = str_field(state, node, key::site_id);
				const Atom resource_site_name = str_field_or(state, site, key::name, str(resource_placement_id));
				const Value collected_by = state.get(node, str(key::collected_by_faction_id), str(key::empty));
				const Atom trigger_faction_id = str_field_or(state, node, key::ai_defended_by_faction_id, collected_by);
				context = state.new_dict();
				state.set(context, str(key::type), str(key::resource_assault));
				state.set(context, str(key::resource_placement_id), str(resource_placement_id));
				state.set(context, str(key::resource_site_id), str(resource_site_id));
				state.set(context, str(key::resource_site_name), str(resource_site_name));
				state.set(context, str(key::trigger_faction_id), str(trigger_faction_id));
				context_type = key::resource_assault;
			}
		} else if (str_field(state, placement, key::spawned_by_faction_id) != key::empty && str_field(state, placement, key::target_kind) == key::hero) {
			const Atom intercept_target_hero_id = _battle_context_target_hero_id(state, session, context, raw_context);
			if (intercept_target_hero_id != key::empty) {
				const Atom trigger_faction_id = str_field(state, placement, key::spawned_by_faction_id);
				context = state.new_dict();
				state.set(context, str(key::type), str(key::hero_intercept));
				state.set(context, str(key::target_hero_id), str(intercept_target_hero_id));
				state.set(context, str(key::trigger_faction_id), str(trigger_faction_id));
				context_type = key::hero_intercept;
			}
		}
	}
	// OverworldRules.delivery_interception_context_for_encounter(null, ...) is its empty context.
	DictRef delivery_context;
	if (session.kind == Kind::Nil) {
		delivery_context = empty_delivery_context(state);
	} else {
		delivery_context = overworld_rules::delivery_interception_context_for_encounter(state, gd::object_view(state, session), raw_is_dict ? raw_context.ref : state.new_dict());
	}
	DeliveryFields delivery;
	delivery.node_placement_id = delivery_text(state, context, key::delivery_node_placement_id, delivery_context, key::node_placement_id);
	delivery.site_name = delivery_text(state, context, key::delivery_site_name, delivery_context, key::site_name);
	delivery.origin_town_id = delivery_text(state, context, key::delivery_origin_town_id, delivery_context, key::origin_town_id);
	delivery.origin_town_label = delivery_text(state, context, key::delivery_origin_town_label, delivery_context, key::origin_town_label);
	delivery.target_kind = delivery_text(state, context, key::delivery_target_kind, delivery_context, key::target_kind);
	delivery.target_id = delivery_text(state, context, key::delivery_target_id, delivery_context, key::target_id);
	delivery.target_label = delivery_text(state, context, key::delivery_target_label, delivery_context, key::target_label);
	delivery.route_label = delivery_text(state, context, key::delivery_route_label, delivery_context, key::route_label);
	delivery.pressure_label = delivery_text(state, context, key::delivery_pressure_label, delivery_context, key::pressure_label);
	delivery.recruit_summary = delivery_text(state, context, key::delivery_recruit_summary, delivery_context, key::recruit_summary);
	const Value arrival_fallback = state.get(delivery_context, str(key::arrival_day), int_value(0));
	delivery.arrival_day = compat::engine_max<int64_t>(0, gd::to_int(state, state.get(context, str(key::delivery_arrival_day), arrival_fallback)));
	if (context_type == key::hero_intercept) {
		const Atom target_hero_id = _battle_context_target_hero_id(state, session, context, raw_context);
		const Atom trigger_faction_id = _battle_context_trigger_faction_id(state, session, context, raw_context, state.new_dict());
		const DictRef result = state.new_dict();
		state.set(result, str(key::type), str(key::hero_intercept));
		state.set(result, str(key::town_placement_id), str(key::empty));
		state.set(result, str(key::town_role), str(key::frontier));
		state.set(result, str(key::battlefront_summary), str(key::empty));
		state.set(result, str(key::battlefront_tags), array_value(state.new_array()));
		state.set(result, str(key::target_hero_id), str(target_hero_id));
		state.set(result, str(key::trigger_faction_id), str(trigger_faction_id));
		set_delivery_fields(state, result, delivery);
		return result;
	}
	if (context_type == key::resource_assault) {
		const Atom resource_placement_id = _battle_context_resource_placement_id(state, context, raw_context);
		const DictRef node = resource_node_of(state, session, resource_placement_id);
		const Value site_id_fallback = state.get(context, str(key::resource_site_id), str(key::empty));
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, str_field_or(state, node, key::site_id, site_id_fallback));
		const Atom resource_site_id = str_field_or(state, node, key::site_id, state.get(context, str(key::resource_site_id), str(key::empty)));
		const Atom resource_site_name = str_field_or(state, site, key::name, state.get(context, str(key::resource_site_name), str(resource_placement_id)));
		const Value collected_by = state.get(node, str(key::collected_by_faction_id), str(key::empty));
		const Value defended_by = state.get(node, str(key::ai_defended_by_faction_id), collected_by);
		const Atom trigger_faction_id = str_field_or(state, context, key::trigger_faction_id, defended_by);
		const DictRef result = state.new_dict();
		state.set(result, str(key::type), str(key::resource_assault));
		state.set(result, str(key::town_placement_id), str(key::empty));
		state.set(result, str(key::town_role), str(key::frontier));
		state.set(result, str(key::battlefront_summary), str(key::empty));
		state.set(result, str(key::battlefront_tags), array_value(state.new_array()));
		state.set(result, str(key::resource_placement_id), str(resource_placement_id));
		state.set(result, str(key::resource_site_id), str(resource_site_id));
		state.set(result, str(key::resource_site_name), str(resource_site_name));
		state.set(result, str(key::trigger_faction_id), str(trigger_faction_id));
		set_delivery_fields(state, result, delivery);
		return result;
	}
	if (context_type != key::town_defense && context_type != key::town_assault) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::type), str(key::encounter));
		state.set(result, str(key::town_placement_id), str(key::empty));
		state.set(result, str(key::town_role), str(key::frontier));
		state.set(result, str(key::battlefront_summary), str(key::empty));
		state.set(result, str(key::battlefront_tags), array_value(state.new_array()));
		set_delivery_fields(state, result, delivery);
		return result;
	}
	const Atom town_placement_id = _battle_context_town_placement_id(state, session, context, raw_context);
	const DictRef town = found_dict(state, _find_town_by_placement(state, session, town_placement_id), key::town);
	const DictRef battlefront = overworld_rules::town_battlefront_profile(state, town);
	const Atom defending_hero_id = str_field(state, context, key::defending_hero_id);
	const Atom raid_encounter_key = str_field(state, context, key::raid_encounter_key);
	const Atom trigger_faction_id = _battle_context_trigger_faction_id(state, session, context, raw_context, town);
	const Value owner_fallback = state.get(town, str(key::owner), str(context_type == key::town_defense ? key::player : key::enemy));
	const Atom defender_owner = str_field_or(state, context, key::defender_owner, owner_fallback);
	const Atom town_role = overworld_rules::town_strategic_role(state, town);
	const Atom battlefront_summary = str_field(state, battlefront, key::summary);
	const Value battlefront_tags = array_or_new(state, battlefront, key::tags);
	const DictRef result = state.new_dict();
	state.set(result, str(key::type), str(context_type));
	state.set(result, str(key::town_placement_id), str(town_placement_id));
	state.set(result, str(key::defending_hero_id), str(defending_hero_id));
	state.set(result, str(key::raid_encounter_key), str(raid_encounter_key));
	state.set(result, str(key::trigger_faction_id), str(trigger_faction_id));
	state.set(result, str(key::defender_owner), str(defender_owner));
	state.set(result, str(key::town_role), str(town_role));
	state.set(result, str(key::battlefront_summary), str(battlefront_summary));
	state.set(result, str(key::battlefront_tags), battlefront_tags);
	set_delivery_fields(state, result, delivery);
	return result;
}

ArrayRef _normalize_string_array(State &state, const Value &value) {
	const ArrayRef normalized = state.new_array();
	if (gd::is_array(value)) {
		for (const Value &entry : gd::items(state, value)) {
			const Atom text = gd::stringify(state, entry);
			if (text != key::empty && !gd::array_has(state, normalized, str(text))) {
				state.append(normalized, str(text));
			}
		}
	}
	return normalized;
}

} // namespace battle_rules

namespace overworld_rules {

DictRef town_battlefront_profile(State &state, DictRef town) {
	return _town_battlefront_profile(state, town);
}

// The session is a view, never null.
DictRef delivery_interception_context_for_encounter(State &state, DictRef session, DictRef encounter) {
	const DictRef empty_context = empty_delivery_context(state);
	if (gd::is_empty(state, encounter)) {
		return empty_context;
	}
	const Atom explicit_node_id = str_field(state, encounter, key::delivery_intercept_node_placement_id);
	const DictRef overworld = session_view::overworld(state, session);
	DictRef best = gd::deep_duplicate_dict(state, empty_context);
	for (const Value &node_value : gd::field_items(state, overworld, str(key::resource_nodes))) {
		if (!gd::is_dict(node_value)) {
			continue;
		}
		const DictRef node = node_value.ref;
		if (explicit_node_id != key::empty && str_field(state, node, key::placement_id) != explicit_node_id) {
			continue;
		}
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, str_field(state, node, key::site_id));
		const DictRef delivery_state = _resource_site_delivery_state(state, session, node, site);
		if (!gd::bool_field(state, delivery_state, key::active, false) || str_field(state, delivery_state, key::controller_id) != key::player) {
			continue;
		}
		if (!_delivery_encounter_matches_node(state, session, encounter, node, delivery_state)) {
			continue;
		}
		const Atom target_label = str_field_or(state, delivery_state, key::target_label, str(key::the_front));
		const Atom site_name = str_field_or(state, site, key::name, str(key::frontier_route));
		const Atom route_label = gd::format(state, key::s_convoy_to_s, {str(site_name), str(target_label)});
		Atom pressure_label = route_label;
		const Atom delivery_kind = str_field(state, delivery_state, key::target_kind);
		if (delivery_kind == key::town) {
			pressure_label = gd::format(state, key::s_relief_lane, {str(target_label)});
		} else if (delivery_kind == key::hero) {
			pressure_label = gd::format(state, key::s_convoy, {str(target_label)});
		}
		const Atom node_placement_id = str_field(state, node, key::placement_id);
		const Atom origin_town_id = str_field(state, delivery_state, key::origin_town_id);
		const Atom origin_town_label = str_field(state, delivery_state, key::origin_town_label);
		const Atom target_kind = str_field(state, delivery_state, key::target_kind);
		const Atom target_id = str_field(state, delivery_state, key::target_id);
		const int64_t arrival_day = gd::int_field(state, delivery_state, key::arrival_day, 0);
		const Atom recruit_summary = str_field(state, delivery_state, key::recruit_summary);
		const DictRef manifest = _normalize_recruit_payload(state, dict_or_new(state, delivery_state, key::manifest));
		const int64_t manifest_value = gd::int_field(state, delivery_state, key::manifest_value, 0);
		const DictRef interception = _resource_site_delivery_interception(state, session, node, site);
		const DictRef candidate = state.new_dict();
		state.set(candidate, str(key::active), bool_value(true));
		state.set(candidate, str(key::node_placement_id), str(node_placement_id));
		state.set(candidate, str(key::site_name), str(site_name));
		state.set(candidate, str(key::origin_town_id), str(origin_town_id));
		state.set(candidate, str(key::origin_town_label), str(origin_town_label));
		state.set(candidate, str(key::target_kind), str(target_kind));
		state.set(candidate, str(key::target_id), str(target_id));
		state.set(candidate, str(key::target_label), str(target_label));
		state.set(candidate, str(key::route_label), str(route_label));
		state.set(candidate, str(key::pressure_label), str(pressure_label));
		state.set(candidate, str(key::arrival_day), int_value(arrival_day));
		state.set(candidate, str(key::recruit_summary), str(recruit_summary));
		state.set(candidate, str(key::manifest), dict_value(manifest));
		state.set(candidate, str(key::manifest_value), int_value(manifest_value));
		state.set(candidate, str(key::interception), dict_value(interception));
		if (!gd::bool_field(state, best, key::active, false)) {
			best = candidate;
			if (explicit_node_id != key::empty) {
				break;
			}
			continue;
		}
		if (gd::int_field(state, candidate, key::manifest_value, 0) > gd::int_field(state, best, key::manifest_value, 0)) {
			best = candidate;
			continue;
		}
		if (gd::int_field(state, candidate, key::manifest_value, 0) == gd::int_field(state, best, key::manifest_value, 0) && gd::int_field(state, candidate, key::arrival_day, 0) < gd::int_field(state, best, key::arrival_day, 0)) {
			best = candidate;
		}
	}
	if (explicit_node_id != key::empty && !gd::bool_field(state, best, key::active, false)) {
		return empty_context;
	}
	return best;
}

DictRef _town_battlefront_profile(State &state, DictRef town) {
	const Atom role = _town_strategic_role(state, town);
	const Atom faction_id = _town_faction_id(state, town);
	const DictRef capital_project = _town_capital_project_state(state, town, Value(), state.new_dict(), state.new_dict());
	const bool project_active = gd::bool_field(state, capital_project, key::active, false);
	std::vector<Atom> tags;
	Atom label = key::empty;
	Atom summary = key::empty;
	if (faction_id == key::faction_embercourt) {
		label = key::fortress_lanes;
		tags.push_back(key::fortress_lane);
		summary = key::fortress_lanes_compress_the_approach_and;
		if (role == key::capital || project_active) {
			tags.push_back(key::reserve_wave);
			summary = key::fortress_lanes_compress_the_approach_while;
		}
	} else if (faction_id == key::faction_mireclaw) {
		label = key::wall_pressure_2;
		tags.push_back(key::wall_pressure);
		summary = key::flooded_breach_lanes_reward_late_pack;
		if (role == key::capital || project_active) {
			tags.push_back(key::reserve_wave);
			tags.push_back(key::bog_channels);
			summary = key::flooded_breach_lanes_and_reserve_packs;
		}
	} else if (faction_id == key::faction_sunvault) {
		label = key::battery_nests;
		tags.push_back(key::battery_nest);
		summary = key::battery_nests_lengthen_the_approach_and;
		if (role == key::capital || project_active) {
			tags.push_back(key::reserve_wave);
			tags.push_back(key::elevated_fire);
			summary = key::battery_nests_lengthen_the_approach_while;
		}
	} else if (faction_id == key::faction_thornwake) {
		label = key::rooted_roads;
		tags.push_back(key::chokepoint);
		summary = key::rooted_roads_slow_the_approach_and;
		if (role == key::capital || project_active) {
			tags.push_back(key::reserve_wave);
			tags.push_back(key::ambush_cover);
			summary = key::rooted_roads_and_nursery_reserves_make;
		}
	} else if (faction_id == key::faction_brasshollow) {
		label = key::siege_stages;
		tags.push_back(key::fortress_lane);
		summary = key::siege_stages_compress_the_approach_around;
		if (role == key::capital || project_active) {
			tags.push_back(key::reserve_wave);
			tags.push_back(key::wall_pressure);
			summary = key::siege_stages_and_foundry_reserves_turn;
		}
	} else if (faction_id == key::faction_veilmourn) {
		label = key::fog_lanes;
		tags.push_back(key::fog_bank);
		summary = key::fog_lanes_break_clean_approaches_and;
		if (role == key::capital || project_active) {
			tags.push_back(key::reserve_wave);
			tags.push_back(key::ambush_cover);
			summary = key::fog_lanes_and_black_sail_reserves;
		}
	}
	const bool has_reserve_wave = std::find(tags.begin(), tags.end(), static_cast<Atom>(key::reserve_wave)) != tags.end();
	if (role == key::capital && !has_reserve_wave) {
		tags.push_back(key::reserve_wave);
	} else if (role == key::stronghold && project_active && !has_reserve_wave) {
		tags.push_back(key::reserve_wave);
	}
	const ArrayRef normalized_tags = state.new_array();
	for (const Atom tag_id : tags) {
		if (tag_id != key::empty && !gd::array_has(state, normalized_tags, str(tag_id))) {
			state.append(normalized_tags, str(tag_id));
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::role), str(role));
	state.set(result, str(key::faction_id), str(faction_id));
	state.set(result, str(key::project_active), bool_value(project_active));
	state.set(result, str(key::label), str(label));
	state.set(result, str(key::summary), str(summary));
	state.set(result, str(key::tags), array_value(normalized_tags));
	return result;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
