// TownRules for the human seat's town services (Phase 7, slice 7.6): the read
// scope, responses, spell learning and specialties.

#include "aurelion_rules/port/town_rules_actions.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules_ai.hpp"
#include "aurelion_rules/port/town_rules.hpp"

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

// d.get(field, {}) of a value that may be stored or passed on: the field, or a
// new Dictionary.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// String(d.get(field, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// {"ok": false, "message": message}.
DictRef refusal(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

} // namespace

namespace town_rules {

void begin_read_scope(State &state, DictRef session) {
	// session == null: a view is never null.
	const Atom session_id = gd::stringify(state, gd::index(state, session, str(key::session_id)));
	const int64_t depth = ai::static_int(state, key::town_rules_script, key::_read_scope_depth);
	if (depth > 0 && session_id == gd::to_string(gd::static_var(state, key::town_rules_script, key::_read_scope_session_id))) {
		gd::set_static_var(state, key::town_rules_script, key::_read_scope_depth, int_value(gd::add(depth, 1)));
		return;
	}
	gd::set_static_var(state, key::town_rules_script, key::_read_scope_session_id, str(session_id));
	gd::set_static_var(state, key::town_rules_script, key::_read_scope_depth, int_value(1));
	gd::set_static_var(state, key::town_rules_script, key::_read_scope_cache, dict_value(state.new_dict()));
}

void end_read_scope(State &state, DictRef session) {
	// session == null: a view is never null.
	const int64_t depth = ai::static_int(state, key::town_rules_script, key::_read_scope_depth);
	if (depth <= 0 || gd::stringify(state, gd::index(state, session, str(key::session_id))) != gd::to_string(gd::static_var(state, key::town_rules_script, key::_read_scope_session_id))) {
		return;
	}
	const int64_t remaining = gd::sub(depth, 1);
	gd::set_static_var(state, key::town_rules_script, key::_read_scope_depth, int_value(remaining));
	if (remaining <= 0) {
		gd::set_static_var(state, key::town_rules_script, key::_read_scope_depth, int_value(0));
		gd::set_static_var(state, key::town_rules_script, key::_read_scope_session_id, str(key::empty));
		gd::set_static_var(state, key::town_rules_script, key::_read_scope_cache, dict_value(state.new_dict()));
	}
}

bool can_visit_active_town(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	return !gd::is_empty(state, town) && text_or(state, town, key::owner, key::neutral) == key::player;
}

ArrayRef get_response_actions(State &state, DictRef session) {
	if (_read_cache_has(state, session, key::response_actions)) {
		return gd::as_array(_read_cache_get(state, session, key::response_actions));
	}
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		const ArrayRef empty = state.new_array();
		_read_cache_store(state, session, key::response_actions, array_value(empty));
		return empty;
	}
	const ArrayRef actions = overworld_rules::get_town_response_actions(state, session, town);
	ai::append_array(state, actions, town_development_rules::service_actions(state, dict_value(session), town));
	_read_cache_store(state, session, key::response_actions, array_value(actions));
	return actions;
}

ArrayRef get_spell_learning_actions(State &state, DictRef session) {
	if (_read_cache_has(state, session, key::spell_learning_actions)) {
		return gd::as_array(_read_cache_get(state, session, key::spell_learning_actions));
	}
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town) || !active_hero_can_study(state, session, town)) {
		const ArrayRef empty = state.new_array();
		_read_cache_store(state, session, key::spell_learning_actions, array_value(empty));
		return empty;
	}

	const ArrayRef actions = state.new_array();
	const Value hero = field_or_new_dict(state, session_view::overworld(state, session), key::hero);
	const ArrayRef spell_ids = accessible_spell_ids(state, town);
	for (const Value &spell_id : gd::items(state, array_value(spell_ids))) {
		if (spell_rules::knows_spell(state, gd::as_dict(hero), gd::to_string(spell_id))) {
			continue;
		}
		const DictRef spell = gd::content_row(state, ContentTable::Spell, gd::to_string(spell_id));
		if (gd::is_empty(state, spell)) {
			continue;
		}
		const int64_t mana_cost = hero_progression_rules::adjusted_mana_cost(state, gd::as_dict(hero), gd::int_field(state, spell, key::mana_cost, 0), key::empty);
		const DictRef action = state.new_dict();
		state.set(action, str(key::id), str(gd::format(state, key::learn_spell_s, {spell_id})));
		state.set(action, str(key::label), str(gd::format(state, key::learn_s_d_mana, {str(gd::stringify(state, state.get(spell, str(key::name), spell_id))), int_value(mana_cost)})));
		const Atom spell_name = gd::stringify(state, state.get(spell, str(key::name), spell_id));
		const Atom inspection = spell_rules::describe_spell_inspection_line(state, gd::as_dict(hero), spell, state.new_dict());
		state.set(action, str(key::summary), str(gd::format(state, key::s_s_12, {str(spell_name), str(inspection)})));
		state.set(action, str(key::cost), int_value(mana_cost));
		state.set(action, str(key::category), str(spell_rules::spell_category_label(state, spell)));
		state.set(action, str(key::disabled), bool_value(false));
		state.append(actions, dict_value(action));
	}
	_read_cache_store(state, session, key::spell_learning_actions, array_value(actions));
	return actions;
}

ArrayRef get_specialty_actions(State &state, DictRef session) {
	if (_read_cache_has(state, session, key::specialty_actions)) {
		return gd::as_array(_read_cache_get(state, session, key::specialty_actions));
	}
	const ArrayRef actions = hero_progression_rules::get_choice_actions(state, gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero)));
	_read_cache_store(state, session, key::specialty_actions, array_value(actions));
	return actions;
}

DictRef perform_response_action(State &state, DictRef session, Atom action_id) {
	if (gd::begins_with(state, action_id, key::town_)) {
		const DictRef town = get_active_town(state, session);
		const int64_t previous_max = hero_command_rules::movement_max_for_hero(state, gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero)), dict_value(session));
		const DictRef result = town_development_rules::perform_service(state, dict_value(session), town, action_id);
		if (!gd::bool_field(state, result, key::ok, false)) {
			return result;
		}
		overworld_rules::_sync_movement_to_hero(state, session, previous_max);
		return _finalize_town_result(state, session, true, text_or(state, result, key::message, key::empty));
	}
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return refusal(state, key::no_town_is_available_for_strategic);
	}
	return overworld_rules::perform_town_response_action(state, session, town, action_id);
}

DictRef learn_spell_at_active_town(State &state, DictRef session, Atom spell_id) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return refusal(state, key::no_town_archives_are_available_here);
	}
	if (!active_hero_can_study(state, session, town)) {
		return refusal(state, key::the_hero_must_visit_an_owned);
	}
	if (!gd::array_has(state, accessible_spell_ids(state, town), str(spell_id))) {
		return refusal(state, key::that_spell_is_not_catalogued_in);
	}

	const DictRef overworld = session_view::overworld(state, session);
	const Value hero_value = field_or_new_dict(state, overworld, key::hero);
	const DictRef hero = gd::is_dict(hero_value) ? hero_value.ref : state.new_dict();
	const DictRef result = spell_rules::learn_spell(state, hero, spell_id);
	if (!gd::bool_field(state, result, key::ok, false)) {
		return refusal(state, text_or(state, result, key::message, key::study_failed));
	}

	state.set(overworld, str(key::hero), state.get(result, str(key::hero), dict_value(hero)));
	const Atom learned = text_or(state, result, key::message, key::spell_learned);
	const Atom message = gd::format(state, key::s_in_s, {str(learned), str(_town_name(state, town))});
	return _finalize_town_result(state, session, true, message);
}

bool active_hero_can_study(State &state, DictRef session, DictRef town) {
	// session == null: a view is never null.
	if (gd::is_empty(state, town) || text_or(state, town, key::owner, key::empty) != key::player) {
		return false;
	}
	const Atom active_hero_id = ai::string_or_empty(state, session_view::overworld(state, session), key::active_hero_id);
	const DictRef hero = hero_command_rules::hero_inspection_snapshot(state, session, active_hero_id);
	return !gd::is_empty(state, hero) && hero_command_rules::_hero_is_stationed_at_town(state, hero, town);
}

DictRef choose_specialty_at_active_town(State &state, DictRef session, Atom specialty_id) {
	return overworld_rules::choose_specialty(state, session, specialty_id, key::empty);
}

} // namespace town_rules

} // namespace aurelion::rules::port
