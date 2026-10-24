// HeroCommandRules for the human seat's heroes in a town (Phase 7, slice 7.5):
// the town's hero list, tavern, transfers, hiring and garrison.

#include "aurelion_rules/port/overworld_rules_heroes.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules_context.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/town_rules_actions.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

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
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// HeroCommandRules.HERO_LIMIT.
constexpr int64_t kHeroLimit = 4;

// String(x) of any value: the engine's text for a float, a vector or a container.
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

// String(d.get(field, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, Atom fallback) {
	return string_of(state, state.get(dict, str(field), str(fallback)));
}

// {"ok": false, "message": message}.
DictRef refusal(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

// separator.join(parts).
Atom join_atoms(State &state, Atom separator, const std::vector<Atom> &parts) {
	std::string joined;
	bool first = true;
	for (const Atom part : parts) {
		if (!first) {
			joined += state.text(separator);
		}
		first = false;
		joined += state.text(part);
	}
	return state.intern(joined);
}

// normalize_session(session) with its defaults.
void normalize(State &state, DictRef session) {
	hero_command_rules::normalize_session(state, session, key::empty, state.new_dict(), state.new_dict());
}

} // namespace

namespace hero_progression_rules {

// enemy_states.cpp.
ArrayRef _normalize_specialty_id_list(State &state, const Value &value);
DictRef specialty_definition(State &state, Atom specialty_id);

Atom summarize_specialty_ids(State &state, const Value &specialty_ids, bool use_short_names) {
	const ArrayRef normalized = _normalize_specialty_id_list(state, specialty_ids);
	std::vector<Atom> names;
	for (const Value &specialty_id_value : gd::items(state, array_value(normalized))) {
		const Atom specialty_id = gd::stringify(state, specialty_id_value);
		const DictRef specialty = specialty_definition(state, specialty_id);
		if (gd::is_empty(state, specialty)) {
			continue;
		}
		const Atom field = use_short_names ? key::short_name : key::name;
		const Value name_fallback = state.get(specialty, str(key::name), str(specialty_id));
		const Atom label = string_of(state, state.get(specialty, str(field), name_fallback));
		if (label != key::empty && std::find(names.begin(), names.end(), label) == names.end()) {
			names.push_back(label);
		}
	}
	return join_atoms(state, key::comma_space, names);
}

} // namespace hero_progression_rules

namespace hero_command_rules {

using hero_progression_rules::summarize_specialty_ids;


Atom hero_profile_summary(State &state, DictRef payload, bool include_focus) {
	const DictRef template_row = hero_template(state, payload);
	if (gd::is_empty(state, template_row)) {
		return key::empty;
	}
	std::vector<Atom> parts;
	const Atom roster_summary = text_or(state, template_row, key::roster_summary, key::empty);
	if (roster_summary != key::empty) {
		parts.push_back(roster_summary);
	} else {
		parts.push_back(hero_archetype_label(state, template_row));
	}
	// template.get("starting_specialties", []): a missing list is a new [].
	const Atom starting_specialties = summarize_specialty_ids(state, state.get(template_row, str(key::starting_specialties), array_value(state.new_array())));
	if (starting_specialties != key::empty) {
		parts.push_back(gd::format(state, key::starts_s, {str(starting_specialties)}));
	}
	if (include_focus) {
		const Atom focus_specialties = summarize_specialty_ids(state, state.get(template_row, str(key::specialty_focus_ids), array_value(state.new_array())));
		if (focus_specialties != key::empty) {
			parts.push_back(gd::format(state, key::focus_s, {str(focus_specialties)}));
		}
	}
	return join_atoms(state, key::space_bar_space, parts);
}

ArrayRef get_town_switch_actions(State &state, DictRef session, DictRef town) {
	normalize(state, session);
	const ArrayRef actions = state.new_array();
	const Atom active_hero_id = text_or(state, session_view::overworld(state, session), key::active_hero_id, key::empty);
	const ArrayRef stationed = stationed_heroes(state, session, town);
	for (const Value &hero : gd::items(state, array_value(stationed))) {
		const Atom hero_id = text_or(state, gd::as_dict(hero), key::id, key::empty);
		const DictRef action = state.new_dict();
		state.set(action, str(key::id), str(gd::format(state, key::switch_hero_s, {str(hero_id)})));
		state.set(action, str(key::label), str(gd::format(state, key::command_s, {str(text_or(state, hero.ref, key::name, hero_id))})));
		state.set(action, str(key::summary), str(_hero_roster_line(state, hero.ref, active_hero_id)));
		state.set(action, str(key::disabled), bool_value(hero_id == active_hero_id));
		state.append(actions, dict_value(action));
	}
	return actions;
}

DictRef town_visiting_hero(State &state, DictRef session, DictRef town) {
	const Atom garrison_id = text_or(state, town_garrison_hero(state, session, town), key::id, key::empty);
	const ArrayRef visitors = state.new_array();
	const ArrayRef stationed = stationed_heroes(state, session, town);
	for (const Value &hero : gd::items(state, array_value(stationed))) {
		if (text_or(state, gd::as_dict(hero), key::id, key::empty) != garrison_id) {
			state.append(visitors, hero);
		}
	}
	// session != null: a view is never null.
	const Atom active_hero_id = text_or(state, session_view::overworld(state, session), key::active_hero_id, key::empty);
	for (const Value &hero : gd::items(state, array_value(visitors))) {
		if (text_or(state, gd::as_dict(hero), key::id, key::empty) == active_hero_id) {
			return hero.ref;
		}
	}
	return state.array_size(visitors) != 0 ? gd::as_dict(state.at(visitors, 0)) : state.new_dict();
}

DictRef set_town_garrison_hero(State &state, DictRef session, DictRef town, Atom hero_id) {
	normalize(state, session);
	const DictRef live_town = _live_town(state, session, town);
	if (gd::is_empty(state, live_town)) {
		return refusal(state, key::no_town_is_available_for_its);
	}
	if (text_or(state, live_town, key::owner, key::neutral) != key::player) {
		return refusal(state, key::only_your_towns_take_a_garrison);
	}
	const DictRef current = town_garrison_hero(state, session, live_town);
	const Atom current_id = text_or(state, current, key::id, key::empty);
	if (hero_id == key::empty) {
		if (gd::is_empty(state, current)) {
			return refusal(state, key::no_hero_holds_the_garrison);
		}
		const DictRef visitor = town_visiting_hero(state, session, live_town);
		if (!gd::is_empty(state, visitor)) {
			return refusal(state, gd::format(state, key::s_already_waits_at_the_gate, {str(text_or(state, visitor, key::name, key::a_hero))}));
		}
		_write_town_garrison_hero(state, session, live_town, key::empty);
		state.set(town, str(key::garrison_hero_id), str(key::empty));
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(true));
		state.set(result, str(key::operation), str(key::release));
		state.set(result, str(key::hero_id), str(current_id));
		state.set(result, str(key::message), str(gd::format(state, key::s_leaves_the_garrison_and_waits, {str(text_or(state, current, key::name, key::the_hero_text))})));
		return result;
	}
	if (hero_id == current_id) {
		return refusal(state, gd::format(state, key::s_already_holds_the_garrison, {str(text_or(state, current, key::name, key::that_hero))}));
	}
	const DictRef hero = hero_by_id(state, session, hero_id);
	if (gd::is_empty(state, hero) || !_hero_is_stationed_at_town(state, hero, live_town)) {
		return refusal(state, key::only_a_hero_at_this_town);
	}
	const Atom hero_name = text_or(state, hero, key::name, key::the_hero_text);
	if (gd::is_empty(state, current)) {
		// var town_stacks: Array = live_town.get("garrison", []) if ... is Array else []
		Value garrison;
		const ArrayRef town_stacks = state.lookup(live_town, str(key::garrison), garrison) && gd::is_array(garrison) ? garrison.ref : state.new_array();
		const ArrayRef merged = merge_stacks_into_army(state, _holder_stacks(state, session, live_town, hero_id), town_stacks);
		if (state.array_size(merged) == 0 && _valid_stack_count(state, array_value(town_stacks)) > 0) {
			return refusal(state, gd::format(state, key::s_s_army_has_no_room, {str(hero_name)}));
		}
		if (_valid_stack_count(state, array_value(town_stacks)) > 0) {
			_set_holder_stacks(state, session, live_town, hero_id, merged);
			_set_holder_stacks(state, session, live_town, key::garrison, state.new_array());
		}
		_write_town_garrison_hero(state, session, live_town, hero_id);
		state.set(town, str(key::garrison_hero_id), str(hero_id));
		state.set(town, str(key::garrison), array_value(state.new_array()));
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(true));
		state.set(result, str(key::operation), str(key::garrison));
		state.set(result, str(key::hero_id), str(hero_id));
		state.set(result, str(key::message), str(gd::format(state, key::s_takes_command_of_the_garrison, {str(hero_name)})));
		return result;
	}
	_write_town_garrison_hero(state, session, live_town, hero_id);
	state.set(town, str(key::garrison_hero_id), str(hero_id));
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::operation), str(key::swap));
	state.set(result, str(key::hero_id), str(hero_id));
	state.set(result, str(key::released_hero_id), str(current_id));
	state.set(result, str(key::message), str(gd::format(state, key::s_takes_the_garrison_s_waits, {str(hero_name), str(text_or(state, current, key::name, key::the_other_hero))})));
	return result;
}

DictRef _live_town(State &state, DictRef session, DictRef town) {
	const Atom placement_id = text_or(state, town, key::placement_id, key::empty);
	for (const Value &entry : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (gd::is_dict(entry) && text_or(state, entry.ref, key::placement_id, key::empty) == placement_id) {
			return entry.ref;
		}
	}
	return state.new_dict();
}

void _write_town_garrison_hero(State &state, DictRef session, DictRef town, Atom hero_id) {
	const DictRef live_town = _live_town(state, session, town);
	if (gd::is_empty(state, live_town)) {
		return;
	}
	if (hero_id == key::empty) {
		state.erase(live_town, str(key::garrison_hero_id));
	} else {
		state.set(live_town, str(key::garrison_hero_id), str(hero_id));
	}
}

ArrayRef get_tavern_actions(State &state, DictRef session, DictRef town) {
	normalize(state, session);
	const ArrayRef actions = state.new_array();
	// session == null: a view is never null.
	if (gd::is_empty(state, town) || !town_has_hall(state, town)) {
		return actions;
	}
	if (player_hero_count(state, session) >= kHeroLimit) {
		return actions;
	}

	const ArrayRef offer_ids = tavern_offer_ids(state, session);
	for (const Value &hero_id_value : gd::items(state, array_value(offer_ids))) {
		const Atom hero_id = gd::to_string(hero_id_value);
		const DictRef template_row = gd::content_row(state, ContentTable::Hero, hero_id);
		if (gd::is_empty(state, template_row)) {
			continue;
		}
		const DictRef cost = hero_recruit_cost(state, template_row);
		const DictRef offer = tavern_offer(state, session, hero_id, -1);
		const Atom action_id = gd::format(state, key::hire_hero_s, {hero_id_value});
		const Atom label = gd::format(state, key::hire_s, {str(text_or(state, template_row, key::name, hero_id))});
		const Atom profile = hero_profile_summary(state, template_row, true);
		const int64_t level = gd::int_field(state, offer, key::level, 1);
		// offer.get("army", {}): a missing army reads as {}.
		const Atom army_summary = _army_summary(state, state.get(offer, str(key::army), dict_value(state.new_dict())));
		const Atom cost_text = _describe_resources(state, dict_value(cost));
		const Atom summary = gd::format(state, key::s_level_d_army_s_cost, {str(profile), int_value(level), str(army_summary), str(cost_text)});
		const DictRef action = state.new_dict();
		state.set(action, str(key::id), str(action_id));
		state.set(action, str(key::label), str(label));
		state.set(action, str(key::summary), str(summary));
		state.set(action, str(key::disabled), bool_value(!_can_afford(state, session, dict_value(cost))));
		state.append(actions, dict_value(action));
	}
	return actions;
}

DictRef recruit_hero_at_town(State &state, DictRef session, DictRef town, Atom hero_id) {
	normalize(state, session);
	// session == null: a view is never null.
	if (gd::is_empty(state, town)) {
		return refusal(state, key::no_town_is_available_for_hero);
	}
	if (text_or(state, town, key::owner, key::neutral) != key::player) {
		return refusal(state, key::only_controlled_towns_can_hire_new);
	}
	if (!town_has_hall(state, town)) {
		return refusal(state, key::a_wayfarers_hall_is_required_before);
	}
	const ArrayRef offer = tavern_offer_ids(state, session);
	if (!gd::array_has(state, offer, str(hero_id))) {
		return refusal(state, key::that_commander_is_not_in_this);
	}
	if (player_hero_count(state, session) >= kHeroLimit) {
		return refusal(state, key::the_command_limit_has_already_been);
	}

	const DictRef template_row = gd::content_row(state, ContentTable::Hero, hero_id);
	const DictRef cost = hero_recruit_cost(state, template_row);
	if (!_can_afford(state, session, dict_value(cost))) {
		return refusal(state, gd::format(state, key::insufficient_resources_to_hire_s, {str(text_or(state, template_row, key::name, hero_id))}));
	}

	_spend_resources(state, session, dict_value(cost));
	const DictRef position = overworld_level_rules::town_entrance(state, town);
	// The hero arrives exactly as the tavern card showed: level and army.
	const DictRef hired = tavern_offer(state, session, hero_id, -1);
	const int64_t level = gd::int_field(state, hired, key::level, 1);
	// hired.get("army", {}): a missing army is a new {}.
	const Value army = state.get(hired, str(key::army), dict_value(state.new_dict()));
	const DictRef hero = build_recruited_hero(state, template_row, position, dict_value(session), level, army, key::empty, key::empty);
	const DictRef overworld = session_view::overworld(state, session);
	// var heroes = session.overworld.get("player_heroes", []), [] unless an Array.
	Value heroes;
	if (!state.lookup(overworld, str(key::player_heroes), heroes) || !gd::is_array(heroes)) {
		heroes = array_value(state.new_array());
	}
	state.append(heroes.ref, dict_value(hero));
	state.set(overworld, str(key::player_heroes), heroes);
	// The hired hero's tavern place stays empty until the next weekly draw.
	ai::array_erase(state, offer, str(hero_id));
	const DictRef rotation = state.new_dict();
	state.set(rotation, str(key::week), int_value(tavern_week(state, session)));
	state.set(rotation, str(key::hero_ids), array_value(offer));
	state.set(overworld, str(key::tavern_rotation), dict_value(rotation));
	normalize(state, session);
	const DictRef town_row = gd::content_row(state, ContentTable::Town, text_or(state, town, key::town_id, key::empty));
	const Value town_fallback = state.get(town, str(key::town_id), str(key::the_town_2));
	const Atom town_name = string_of(state, state.get(town_row, str(key::name), town_fallback));
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::message), str(gd::format(state, key::s_joins_the_command_roster_at, {str(text_or(state, hero, key::name, hero_id)), str(town_name)})));
	return result;
}

ArrayRef get_town_transfer_actions(State &state, DictRef session, DictRef town) {
	normalize(state, session);
	const ArrayRef actions = state.new_array();
	// session == null: a view is never null.
	if (gd::is_empty(state, town)) {
		return actions;
	}
	const ArrayRef holders = _stationed_holder_ids(state, session, town);
	if (state.array_size(holders) < 2) {
		return actions;
	}

	for (const Value &source_value : gd::items(state, array_value(holders))) {
		const Atom source_holder = gd::to_string(source_value);
		for (const Value &target_value : gd::items(state, array_value(holders))) {
			const Atom target_holder = gd::to_string(target_value);
			if (source_holder == target_holder) {
				continue;
			}
			const ArrayRef listed_stacks = _holder_stacks(state, session, town, source_holder);
			for (const Value &stack : gd::items(state, array_value(listed_stacks))) {
				if (!gd::is_dict(stack)) {
					continue;
				}
				const Atom unit_id = text_or(state, stack.ref, key::unit_id, key::empty);
				const int64_t count = gd::int_field(state, stack.ref, key::count, 0);
				if (unit_id == key::empty || count <= 0) {
					continue;
				}
				const DictRef addition = state.new_dict();
				state.set(addition, str(unit_id), int_value(1));
				const DictRef admission = army_addition_plan(state, array_value(_holder_stacks(state, session, town, target_holder)), addition);
				const ArrayRef source_stacks = _holder_stacks(state, session, town, source_holder);
				const ArrayRef amount_tokens = _transfer_amount_tokens(state, count);
				for (const Value &amount_value : gd::items(state, array_value(amount_tokens))) {
					const Atom amount_token = gd::to_string(amount_value);
					const Atom amount_label = _transfer_amount_label(state, amount_token, count);
					const Atom unit_name = text_or(state, gd::content_row(state, ContentTable::Unit, unit_id), key::name, unit_id);
					Atom blocker = gd::bool_field(state, admission, key::ok, false) ? static_cast<Atom>(key::empty) : text_or(state, admission, key::message, key::empty);
					if (blocker == key::empty && _transfer_empties_hero_army(state, source_holder, array_value(source_stacks), _resolve_transfer_amount(state, amount_token, count), count, true)) {
						blocker = _last_stack_message(state, session, town, source_holder);
					}
					const Atom action_id = gd::format(state, key::transfer_s_s_s_s, {str(source_holder), str(target_holder), str(unit_id), str(amount_token)});
					const Atom label = gd::format(state, key::move_s_s, {str(amount_label), str(unit_name)});
					const Atom source_label = _holder_label(state, session, town, source_holder);
					const Atom target_label = _holder_label(state, session, town, target_holder);
					const Atom blocker_text = blocker != key::empty ? state.intern(state.text(key::space_bar_space) + state.text(blocker)) : static_cast<Atom>(key::empty);
					const DictRef action = state.new_dict();
					state.set(action, str(key::id), str(action_id));
					state.set(action, str(key::label), str(label));
					state.set(action, str(key::summary), str(gd::format(state, key::s_s_s_11, {str(source_label), str(target_label), str(blocker_text)})));
					state.set(action, str(key::disabled), bool_value(blocker != key::empty));
					state.append(actions, dict_value(action));
				}
			}
		}
	}
	return actions;
}

DictRef transfer_town_stack(State &state, DictRef session, DictRef town, Atom source_holder, Atom target_holder, Atom unit_id, Atom amount_token) {
	normalize(state, session);
	// session == null: a view is never null.
	if (gd::is_empty(state, town)) {
		return refusal(state, key::no_town_is_available_for_army_2);
	}
	if (source_holder == target_holder) {
		return refusal(state, key::choose_a_different_transfer_target);
	}
	const ArrayRef stationed_holders = _stationed_holder_ids(state, session, town);
	if (!gd::array_has(state, stationed_holders, str(source_holder)) || !gd::array_has(state, stationed_holders, str(target_holder))) {
		return refusal(state, key::transfer_orders_are_limited_to_the);
	}
	if (unit_id == key::empty) {
		return refusal(state, key::that_transfer_order_is_missing_a);
	}

	const ArrayRef source_stacks = _holder_stacks(state, session, town, source_holder);
	const int64_t source_index = _stack_index_by_unit(state, source_stacks, unit_id);
	if (source_index < 0) {
		return refusal(state, key::that_stack_is_no_longer_available);
	}
	const Value source_stack = state.at(source_stacks, source_index);
	const int64_t available = gd::to_int(state, ai::vget(state, source_stack, key::count, int_value(0)));
	const int64_t transfer_count = _resolve_transfer_amount(state, amount_token, available);
	if (transfer_count <= 0) {
		return refusal(state, key::no_troops_are_available_for_transfer);
	}
	if (_transfer_empties_hero_army(state, source_holder, array_value(source_stacks), transfer_count, available, true)) {
		return refusal(state, _last_stack_message(state, session, town, source_holder));
	}

	const DictRef addition = state.new_dict();
	state.set(addition, str(unit_id), int_value(transfer_count));
	const DictRef admission = army_addition_plan(state, array_value(_holder_stacks(state, session, town, target_holder)), addition);
	if (!gd::bool_field(state, admission, key::ok, false)) {
		return admission;
	}
	// source_stack is a Dictionary: _stack_index_by_unit finds only those.
	state.set(source_stack.ref, str(key::count), int_value(gd::sub(available, transfer_count)));
	if (gd::int_field(state, source_stack.ref, key::count, 0) > 0) {
		state.set_at(source_stacks, source_index, source_stack);
	} else {
		gd::remove_at(state, source_stacks, source_index);
	}

	// var target_stacks: Array = admission.get("stacks", [])
	const ArrayRef target_stacks = gd::as_array(state.get(admission, str(key::stacks), array_value(state.new_array())));

	_set_holder_stacks(state, session, town, source_holder, source_stacks);
	_set_holder_stacks(state, session, town, target_holder, target_stacks);
	commit_active_hero(state, session);

	const Atom unit_name = text_or(state, gd::content_row(state, ContentTable::Unit, unit_id), key::name, unit_id);
	const Atom source_label = _holder_label(state, session, town, source_holder);
	const Atom target_label = _holder_label(state, session, town, target_holder);
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::message), str(gd::format(state, key::moved_d_s_from_s_to, {int_value(transfer_count), str(unit_name), str(source_label), str(target_label)})));
	return result;
}

Atom _army_summary(State &state, const Value &army) {
	// army.get("stacks", []) if army is Dictionary else []: [] has no troops.
	Value stacks;
	if (!gd::is_dict(army) || !state.lookup(army.ref, str(key::stacks), stacks)) {
		stacks = array_value(state.new_array());
	}
	return _stack_summary_from_array(state, stacks);
}

Atom _stack_summary_from_array(State &state, const Value &stacks) {
	if (!gd::is_array(stacks)) {
		return key::no_troops;
	}
	std::vector<Atom> parts;
	for (const Value &stack : gd::items(state, stacks)) {
		if (!gd::is_dict(stack)) {
			continue;
		}
		const int64_t count = gd::int_field(state, stack.ref, key::count, 0);
		if (count <= 0) {
			continue;
		}
		const Atom unit_id = text_or(state, stack.ref, key::unit_id, key::empty);
		const Atom unit_name = text_or(state, gd::content_row(state, ContentTable::Unit, unit_id), key::name, unit_id);
		parts.push_back(gd::format(state, key::s_x_d, {str(unit_name), int_value(count)}));
	}
	return parts.empty() ? static_cast<Atom>(key::no_troops) : join_atoms(state, key::comma_space, parts);
}

ArrayRef _transfer_amount_tokens(State &state, int64_t count) {
	const ArrayRef tokens = state.new_array();
	if (count <= 0) {
		return tokens;
	}
	state.append(tokens, str(key::n1));
	if (count > 1) {
		state.append(tokens, str(key::half));
		state.append(tokens, str(key::all));
	}
	return tokens;
}

Atom _transfer_amount_label(State &state, Atom amount_token, int64_t available) {
	if (amount_token == key::all) {
		return key::all;
	}
	if (amount_token == key::half) {
		return key::half;
	}
	return gd::stringify(state, int_value(_resolve_transfer_amount(state, amount_token, available)));
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
				? gd::to_int(state, ai::vget(state, resources, str(string_of(state, cost_key)), int_value(0)))
				: 0;
		if (available < gd::to_int(state, gd::index(state, cost.ref, cost_key))) {
			return false;
		}
	}
	return true;
}

void _spend_resources(State &state, DictRef session, const Value &cost) {
	const DictRef overworld = session_view::overworld(state, session);
	// session.overworld.get("resources", {}).duplicate(true)
	Value found;
	if (!state.lookup(overworld, str(key::resources), found)) {
		found = dict_value(state.new_dict());
	}
	const Value resources = gd::engine_duplicate(state, found, true);
	if (gd::is_dict(cost)) {
		const ArrayRef cost_keys = gd::keys(state, cost.ref);
		for (const Value &cost_key : gd::items(state, array_value(cost_keys))) {
			const Atom resource_key = string_of(state, cost_key);
			const int64_t held = gd::to_int(state, ai::vget(state, resources, str(resource_key), int_value(0)));
			const int64_t spent = gd::to_int(state, gd::index(state, cost.ref, cost_key));
			state.set(gd::as_dict(resources), str(resource_key), int_value(compat::engine_max<int64_t>(0, gd::sub(held, spent))));
		}
	}
	state.set(overworld, str(key::resources), resources);
}

Atom _describe_resources(State &state, const Value &resources) {
	const DictRef normalized = _normalize_resources(state, resources);
	std::vector<Atom> parts;
	const ArrayRef resource_keys = gd::keys(state, normalized);
	// keys.sort(): every key is a String (code point order, the UTF-8 byte order).
	gd::sort_custom(state, resource_keys, [&state](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
	for (const Value &resource_key : gd::items(state, array_value(resource_keys))) {
		const int64_t amount = gd::to_int(state, state.get(normalized, resource_key, int_value(0)));
		if (amount > 0) {
			parts.push_back(gd::format(state, key::_d_s, {int_value(amount), resource_key}));
		}
	}
	return parts.empty() ? static_cast<Atom>(key::free) : join_atoms(state, key::comma_space, parts);
}

} // namespace hero_command_rules

} // namespace aurelion::rules::port
