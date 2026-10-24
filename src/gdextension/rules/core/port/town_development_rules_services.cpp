// TownDevelopmentRules for the human seat's town services (Phase 7, slice 7.6):
// the service actions and performing one.

#include "aurelion_rules/port/town_rules_actions.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/artifact_rules_turn.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/faction_town_services_turn.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/town_development_rules_ai.hpp"
#include "aurelion_rules/port/town_development_rules_turn.hpp"

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

// d.get(field, {}) and d.get(field, []) of a value that may be passed on or
// stored: the field, or a new container.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// String(d.get(field, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// String(d.field): a missing field is a ScriptError, as in GDScript.
Atom member_text(State &state, DictRef dict, Atom field) {
	return gd::stringify(state, gd::index(state, dict, str(field)));
}

// a + b of Strings.
Atom concat(State &state, Atom a, Atom b) {
	return state.intern(state.text(a) + state.text(b));
}

// value.get(field, {}) read only: false when the field is missing (the empty
// Dictionary), else the field's value. A value that is no Dictionary has no
// get() (a ScriptError, as in GDScript).
bool lookup_untyped(State &state, const Value &value, const Value &field, Value &out) {
	if (!gd::is_dict(value)) {
		out = ai::vget(state, value, field);
		return true;
	}
	return state.lookup(value.ref, field, out);
}

// {"ok": false, "message": message}.
DictRef refusal(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

// s.split(":") (allow_empty): the pieces between the colons.
std::vector<Atom> split_colons(State &state, Atom text) {
	const std::string &source = state.text(text);
	std::vector<std::string> pieces;
	size_t from = 0;
	while (true) {
		const size_t at = source.find(':', from);
		if (at == std::string::npos) {
			pieces.push_back(source.substr(from));
			break;
		}
		pieces.push_back(source.substr(from, at - from));
		from = at + 1;
	}
	std::vector<Atom> parts;
	parts.reserve(pieces.size());
	for (const std::string &piece : pieces) {
		parts.push_back(state.intern(piece));
	}
	return parts;
}

// parts[index] of a PackedStringArray: out of range is a ScriptError.
Atom part_at(const std::vector<Atom> &parts, size_t index) {
	if (index >= parts.size()) {
		throw state::ScriptError("Out of bounds get index '" + std::to_string(index) + "' (on base: 'PackedStringArray')");
	}
	return parts[index];
}

// int(session.day).
int64_t session_day(State &state, DictRef session) {
	return gd::to_int(state, gd::index(state, session, str(key::day)));
}

} // namespace

namespace town_development_rules {

bool visiting_active_hero(State &state, const Value &session, DictRef town) {
	const DictRef view = gd::as_dict(session);
	// String(session.overworld.get("hero", {}).get("id", "")), read only.
	Atom id = key::empty;
	Value hero;
	if (state.lookup(session_view::overworld(state, view), str(key::hero), hero)) {
		id = gd::stringify(state, ai::vget(state, hero, key::id, str(key::empty)));
	}
	for (const Value &stationed : gd::items(state, array_value(hero_command_rules::stationed_heroes(state, view, town)))) {
		if (gd::stringify(state, ai::vget(state, stationed, key::id, str(key::empty))) == id) {
			return true;
		}
	}
	return false;
}

ArrayRef objective_artifact_ids(State &state, const Value &session) {
	if (session.kind == state::Kind::Nil) {
		return state.new_array();
	}
	// load("res://scripts/core/ScenarioRules.gd").objective_artifact_ids(session).
	return scenario_rules::objective_artifact_ids(state, gd::as_dict(session));
}

ArrayRef service_actions(State &state, const Value &session, DictRef town) {
	const ArrayRef actions = state.new_array();
	if (gd::is_empty(state, town) || !gd::equal(state, state.get(town, str(key::owner), str(key::empty)), str(key::player))) {
		return actions;
	}
	const DictRef view = gd::as_dict(session);
	const DictRef overworld = session_view::overworld(state, view);
	const DictRef resources = gd::as_dict(field_or_new_dict(state, overworld, key::resources));
	const DictRef hero = gd::as_dict(field_or_new_dict(state, overworld, key::hero));
	const bool present = visiting_active_hero(state, session, town);
	for (const Value &id : gd::items(state, array_value(active_buildings(state, town)))) {
		const Atom building_id = gd::stringify(state, id);
		const DictRef b = gd::content_row(state, ContentTable::Building, building_id);
		if (state.has(b, str(key::hero_visit_reward)) && present) {
			const ArrayRef claimed = gd::as_array(field_or_new_array(state, hero, key::town_training_claims));
			const DictRef action = state.new_dict();
			state.set(action, str(key::id), str(concat(state, key::town_train_2, building_id)));
			state.set(action, str(key::label), str(concat(state, key::visit_2, member_text(state, b, key::name))));
			state.set(action, str(key::summary), str(member_text(state, b, key::description)));
			state.set(action, str(key::disabled), bool_value(gd::array_has(state, claimed, id)));
			state.append(actions, dict_value(action));
		}
		if (state.has(b, str(key::faction_service)) && present) {
			const Atom reason = faction_town_services::unavailable_reason(state, hero, town, b, session_day(state, view), resources);
			const DictRef service = gd::as_dict(gd::index(state, b, str(key::faction_service)));
			// An exchange's description already names what it takes.
			Atom cost_line = key::empty;
			if (text_or(state, service, key::kind, key::empty) != key::resource_exchange) {
				cost_line = gd::format(state, key::cost_s_3, {str(cost_text(state, gd::as_dict(field_or_new_dict(state, service, key::cost))))});
			}
			const DictRef action = state.new_dict();
			state.set(action, str(key::id), str(concat(state, key::town_faction_2, building_id)));
			const Atom label = concat(state, concat(state, member_text(state, service, key::label), key::text_5), cost_text(state, gd::as_dict(field_or_new_dict(state, service, key::cost))));
			state.set(action, str(key::label), str(label));
			state.set(action, str(key::summary), str(gd::format(state, key::s_s_once_per_week_per, {str(member_text(state, service, key::description)), str(cost_line), str(text_or(state, service, key::scope, key::town)), str(reason)})));
			state.set(action, str(key::disabled), bool_value(reason != key::empty));
			state.append(actions, dict_value(action));
		}
		const Atom target = text_or(state, b, key::unlock_unit_id, key::empty);
		const Atom base = text_or(state, gd::content_row(state, ContentTable::Unit, target), key::upgrade_from, key::empty);
		if (base != key::empty) {
			for (const Value &holder : gd::items(state, array_value(hero_command_rules::_stationed_holder_ids(state, view, town)))) {
				int64_t count = 0;
				for (const Value &stack : gd::items(state, array_value(hero_command_rules::_holder_stacks(state, view, town, gd::stringify(state, holder))))) {
					if (gd::equal(state, ai::vget(state, stack, key::unit_id, str(key::empty)), str(base))) {
						count = gd::add(count, gd::to_int(state, ai::vget(state, stack, key::count, int_value(0))));
					}
				}
				if (count <= 0) {
					continue;
				}
				const DictRef cost = upgrade_cost(state, base, target, count);
				const DictRef action = state.new_dict();
				state.set(action, str(key::id), str(gd::format(state, key::town_upgrade_s_s, {holder, str(base)})));
				const Value base_name = state.get(gd::content_row(state, ContentTable::Unit, base), str(key::name), str(base));
				const Atom holder_label = hero_command_rules::_holder_label(state, view, town, gd::stringify(state, holder));
				state.set(action, str(key::label), str(gd::format(state, key::upgrade_d_s_s, {int_value(count), base_name, str(holder_label)})));
				const Value target_name = state.get(gd::content_row(state, ContentTable::Unit, target), str(key::name), str(target));
				state.set(action, str(key::summary), str(gd::format(state, key::train_the_entire_stack_into_s, {target_name, str(cost_text(state, cost))})));
				state.set(action, str(key::disabled), bool_value(!can_pay(state, resources, cost)));
				state.append(actions, dict_value(action));
			}
		}
		if (gd::bool_field(state, b, key::artifact_exchange, false) && present) {
			const int64_t day = session_day(state, view);
			const int64_t week = compat::engine_max<int64_t>(0, compat::int_div(gd::sub(day, 1), 7));
			// town.get("artifact_shop_purchases", {}).get(str(week), []), read only.
			ArrayRef sold = 0;
			{
				Value purchases;
				Value sold_value;
				if (state.lookup(town, str(key::artifact_shop_purchases), purchases) && lookup_untyped(state, purchases, str(gd::stringify(state, int_value(week))), sold_value)) {
					sold = gd::as_array(sold_value);
				} else {
					sold = state.new_array();
				}
			}
			const ArrayRef objective_ids = objective_artifact_ids(state, session);
			for (const Value &aid : gd::items(state, array_value(offers(state, town, session_day(state, view), objective_ids)))) {
				const DictRef a = gd::content_row(state, ContentTable::Artifact, gd::stringify(state, aid));
				const int64_t cost = price(state, a);
				const DictRef action = state.new_dict();
				state.set(action, str(key::id), str(concat(state, key::town_buy_2, gd::stringify(state, aid))));
				state.set(action, str(key::label), str(gd::format(state, key::buy_s_d_gold, {state.get(a, str(key::name), aid), int_value(cost)})));
				state.set(action, str(key::summary), str(artifact_rules::artifact_effect_summary(state, gd::stringify(state, aid))));
				const bool disabled = gd::array_has(state, sold, aid) || artifact_rules::has_artifact(state, hero, gd::stringify(state, aid)) ||
						gd::int_field(state, resources, key::gold, 0) < cost;
				state.set(action, str(key::disabled), bool_value(disabled));
				state.append(actions, dict_value(action));
			}
			const DictRef artifacts = artifact_rules::normalize_hero_artifacts(state, field_or_new_dict(state, hero, key::artifacts));
			for (const Value &aid : gd::field_items(state, artifacts, str(key::inventory))) {
				const DictRef a = gd::content_row(state, ContentTable::Artifact, gd::stringify(state, aid));
				if (gd::bool_field(state, a, key::quest_item, false) || gd::array_has(state, objective_ids, str(gd::stringify(state, aid)))) {
					continue;
				}
				const DictRef action = state.new_dict();
				state.set(action, str(key::id), str(concat(state, key::town_sell_2, gd::stringify(state, aid))));
				state.set(action, str(key::label), str(gd::format(state, key::sell_s_d_gold, {state.get(a, str(key::name), aid), int_value(compat::int_div(price(state, a), 2))})));
				state.set(action, str(key::summary), str(key::sell_this_unequipped_artifact_the_sale));
				state.set(action, str(key::disabled), bool_value(false));
				state.append(actions, dict_value(action));
			}
		}
	}
	return actions;
}

Atom cost_text(State &state, DictRef cost) {
	std::string joined;
	bool first = true;
	for (const Value &resource : gd::items(state, dict_value(cost))) {
		const Atom name = gd::replace(state, gd::stringify(state, resource), key::_, key::space);
		const Atom part = gd::format(state, key::_d_s, {int_value(gd::to_int(state, gd::index(state, cost, resource))), str(name)});
		if (!first) {
			joined += state.text(key::comma_space);
		}
		joined += state.text(part);
		first = false;
	}
	return state.intern(joined);
}

DictRef perform_service(State &state, const Value &session, DictRef town, Atom action_id) {
	// Rebuild authorization from current location, ownership, stock and funds.
	bool allowed = false;
	for (const Value &action : gd::items(state, array_value(service_actions(state, session, town)))) {
		if (gd::equal(state, ai::vmember(state, action, key::id), str(action_id)) && !gd::to_bool(ai::vget(state, action, key::disabled, bool_value(false)))) {
			allowed = true;
			break;
		}
	}
	if (!allowed) {
		return refusal(state, key::this_town_service_is_no_longer);
	}
	const std::vector<Atom> parts = split_colons(state, action_id);
	const DictRef view = gd::as_dict(session);
	const DictRef overworld = session_view::overworld(state, view);
	DictRef hero = gd::as_dict(gd::duplicate_value(state, field_or_new_dict(state, overworld, key::hero), true));
	const DictRef resources = gd::as_dict(gd::duplicate_value(state, field_or_new_dict(state, overworld, key::resources), true));
	Atom message = key::empty;
	const Atom kind = part_at(parts, 0);
	if (kind == key::town_faction) {
		const DictRef result = faction_town_services::perform(state, hero, town, gd::content_row(state, ContentTable::Building, part_at(parts, 1)), session_day(state, view), resources);
		if (!gd::truthy(state, gd::index(state, result, str(key::ok)))) {
			return result;
		}
		hero = gd::as_dict(gd::index(state, result, str(key::hero)));
		message = gd::to_string(gd::index(state, result, str(key::message)));
	} else if (kind == key::town_train) {
		const DictRef b = gd::content_row(state, ContentTable::Building, part_at(parts, 1));
		const DictRef result = train_hero(state, hero, town, part_at(parts, 1));
		if (!gd::truthy(state, gd::index(state, result, str(key::ok)))) {
			return result;
		}
		hero = gd::as_dict(gd::index(state, result, str(key::hero)));
		message = member_text(state, b, key::description);
	} else if (kind == key::town_upgrade) {
		const Atom base = part_at(parts, 2);
		const ArrayRef stacks = hero_command_rules::_holder_stacks(state, view, town, part_at(parts, 1));
		const DictRef result = upgrade_army(state, town, stacks, base, resources);
		if (!gd::truthy(state, gd::index(state, result, str(key::ok)))) {
			return result;
		}
		hero_command_rules::_set_holder_stacks(state, view, town, part_at(parts, 1), gd::as_array(gd::index(state, result, str(key::stacks))));
		const Value count = gd::index(state, result, str(key::count));
		message = gd::format(state, key::upgraded_d_creatures_for_s, {count, str(cost_text(state, gd::as_dict(gd::index(state, result, str(key::cost)))))});
	} else if (kind == key::town_buy) {
		const int64_t day = session_day(state, view);
		const DictRef result = trade_artifact(state, hero, town, day, part_at(parts, 1), true, resources, objective_artifact_ids(state, session));
		if (!gd::bool_field(state, result, key::ok, false)) {
			return result;
		}
		hero = gd::as_dict(gd::index(state, result, str(key::hero)));
		const Atom name = text_or(state, gd::content_row(state, ContentTable::Artifact, part_at(parts, 1)), key::name, part_at(parts, 1));
		message = concat(state, concat(state, key::bought_3, name), key::period);
	} else if (kind == key::town_sell) {
		const int64_t day = session_day(state, view);
		const DictRef result = trade_artifact(state, hero, town, day, part_at(parts, 1), false, resources, objective_artifact_ids(state, session));
		if (!gd::bool_field(state, result, key::ok, false)) {
			return result;
		}
		hero = gd::as_dict(gd::index(state, result, str(key::hero)));
		const Atom name = text_or(state, gd::content_row(state, ContentTable::Artifact, part_at(parts, 1)), key::name, part_at(parts, 1));
		message = concat(state, concat(state, key::sold_2, name), key::period);
	}
	if (kind != key::town_upgrade) {
		state.set(overworld, str(key::hero), dict_value(hero));
	}
	state.set(overworld, str(key::resources), dict_value(resources));
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::message), str(message));
	return result;
}

} // namespace town_development_rules

} // namespace aurelion::rules::port
