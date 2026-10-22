// Layer 11: the battle's context afterwards. The town, site or route it was fought for, the fronts, and the enemy
// faction's pressure, treasury and siege; the town a victory or a loss changes hands, and its garrison commander.

#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"

#include <initializer_list>
#include <string>
#include <utility>
#include <vector>

namespace aurelion::rules::port {

namespace battle_rules {

using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Kind;
namespace key = state::key;

namespace {

// session.battle and session.overworld: SessionData types both Dictionary.
DictRef session_battle(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::battle));
}

DictRef session_overworld(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::overworld));
}

// session == null or session.battle.is_empty()
bool no_battle(State &state, const Value &session) {
	return session.kind == Kind::Nil || gd::is_empty(state, session_battle(state, session));
}

// The session as the overworld rules take it.
DictRef view(State &state, const Value &session) {
	return gd::object_view(state, session);
}

// String(d.get(field, "")).
Atom string_or_empty(const State &state, DictRef dict, Atom field) {
	return gd::string_field(state, dict, field, key::empty);
}

// source.get(field, fallback) of `var source: Dictionary = raw if raw is Dictionary else {}`: a value that is not a
// Dictionary reads as the empty one.
Value source_get(const State &state, const Value &source, Atom field, const Value &fallback) {
	return gd::is_dict(source) ? state.get(source.ref, str(field), fallback) : fallback;
}

// d.get(field, {}) and d.get(field, []): a new container when the key is missing.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

Value get_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// x.get(field, {}) of an untyped value.
Value vget_or_new_dict(State &state, const Value &object, Atom field) {
	if (gd::is_dict(object)) {
		return get_or_new_dict(state, object.ref, field);
	}
	return ai::vget(state, object, field);
}

// d.get(field, {}) if d.get(field, {}) is Dictionary else {}: the field's own Dictionary, or a new one.
DictRef own_dict_field(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// container[index] = value of an untyped Array (or Dictionary).
void vset_index(State &state, const Value &container, int64_t index, const Value &value) {
	if (gd::is_array(container)) {
		state.set_at(container.ref, index, value);
		return;
	}
	if (gd::is_dict(container)) {
		state.set(container.ref, int_value(index), value);
		return;
	}
	throw state::ScriptError(std::string("Invalid assignment of index on a base object of type '") + gd::type_name(container) + "'.");
}

// {"index": index, <field>: value}
DictRef index_result(State &state, int64_t index, Atom field, const Value &value) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::index), int_value(index));
	state.set(result, str(field), value);
	return result;
}

// {"summary": summary}
DictRef summary_result(State &state, Atom summary) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::summary), str(summary));
	return result;
}

// [a, b, ...] of Strings: a new Array.
ArrayRef string_array(State &state, std::initializer_list<Atom> atoms) {
	const ArrayRef array = state.new_array();
	for (const Atom atom : atoms) {
		state.append(array, str(atom));
	}
	return array;
}

// text if text != "" else fallback
Atom or_default(Atom text, Atom fallback) {
	return text != key::empty ? text : fallback;
}

// max(a, b) of two ints: an int.
int64_t imax(int64_t a, int64_t b) {
	return a < b ? b : a;
}

// The town found by placement, as the recovery pressures read it: d.get("town", {}).
Value found_town(State &state, const Value &session, Atom placement_id) {
	return get_or_new_dict(state, _find_town_by_placement(state, session, placement_id), key::town);
}

} // namespace

Atom _apply_battle_context_victory(State &state, const Value &session) {
	const Atom dwelling_placement = creature_dwelling_rules::placement_from_guard_key(state, string_or_empty(state, session_battle(state, session), key::resolved_key));
	if (dwelling_placement != key::empty) {
		return overworld_rules::capture_dwelling_after_guard_victory(state, view(state, session), dwelling_placement);
	}
	// A missing context's {} matches no context type, as null does.
	const Value context = gd::field(state, session_battle(state, session), key::context);
	if (_is_town_assault_context(state, context)) {
		const Atom town_name = _town_name_from_placement_id(state, session, string_or_empty(state, context.ref, key::town_placement_id));
		Atom message = overworld_rules::capture_town_by_placement(state, view(state, session), string_or_empty(state, context.ref, key::town_placement_id));
		if (message == key::empty) {
			message = gd::format(state, key::s_falls_to_the_assault, { str(or_default(town_name, key::the_town)) });
		}
		const Atom recovery_message = _apply_town_assault_recovery(state, session, key::victory);
		if (recovery_message != key::empty) {
			message = gd::format(state, key::s_s, { str(message), str(recovery_message) });
		}
		return message;
	}
	if (_is_resource_assault_context(state, context)) {
		const DictRef result = overworld_rules::capture_resource_after_defender_victory(state, view(state, session), string_or_empty(state, context.ref, key::resource_placement_id));
		if (gd::bool_field(state, result, key::ok, false)) {
			return string_or_empty(state, result, key::message);
		}
		return gd::format(state, key::s_is_retaken, { str(gd::string_field(state, context.ref, key::resource_site_name, key::the_field_site)) });
	}
	if (!_is_town_defense_context(state, context)) {
		return key::empty;
	}
	_set_enemy_siege_progress(state, session, _battle_context_controller_id(state, session, context.ref, Value()), 0);
	const Atom town_name = _town_name_from_placement_id(state, session, string_or_empty(state, context.ref, key::town_placement_id));
	Atom message = gd::format(state, key::s_repels_the_assault, { str(or_default(town_name, key::the_town)) });
	const Atom recovery_message = _apply_town_defense_recovery(state, session, key::victory);
	if (recovery_message != key::empty) {
		message = gd::format(state, key::s_s, { str(message), str(recovery_message) });
	}
	return message;
}

Atom _apply_battle_context_stalemate(State &state, const Value &session) {
	const Value context = gd::field(state, session_battle(state, session), key::context);
	if (_is_town_assault_context(state, context)) {
		const Atom town_name = _town_name_from_placement_id(state, session, string_or_empty(state, context.ref, key::town_placement_id));
		Atom message = gd::format(state, key::s_holds_through_the_assault_and, { str(or_default(town_name, key::the_town)) });
		const Atom recovery_message = _apply_town_assault_recovery(state, session, key::stalemate);
		const Atom front_message = _stabilize_hostile_town_front(state, session, key::repelled_assault, 0);
		if (recovery_message != key::empty) {
			message = gd::format(state, key::s_s, { str(message), str(recovery_message) });
		}
		if (front_message != key::empty) {
			message = gd::format(state, key::s_s, { str(message), str(front_message) });
		}
		return message;
	}
	if (_is_resource_assault_context(state, context)) {
		return gd::format(state, key::s_holds_through_the_assault_and, { str(gd::string_field(state, context.ref, key::resource_site_name, key::the_field_site)) });
	}
	if (!_is_town_defense_context(state, context)) {
		return key::empty;
	}
	const Atom town_name = _town_name_from_placement_id(state, session, string_or_empty(state, context.ref, key::town_placement_id));
	Atom message = gd::format(state, key::s_holds_through_the_assault_but, { str(or_default(town_name, key::the_town)) });
	const Atom recovery_message = _apply_town_defense_recovery(state, session, key::stalemate);
	if (recovery_message != key::empty) {
		message = gd::format(state, key::s_s, { str(message), str(recovery_message) });
	}
	return message;
}

Atom _battle_context_controller_id(State &state, const Value &session, DictRef context, const Value &raw_context) {
	// The callees convert a raw context that is not a Dictionary to {} as this function does.
	const Value source = gd::is_dict(raw_context) ? raw_context : Value();
	Atom player_id = string_or_empty(state, context, key::trigger_player_id);
	if (player_id == key::empty) {
		player_id = gd::to_string(source_get(state, source, key::spawned_by_player_id, source_get(state, source, key::trigger_player_id, str(key::empty))));
	}
	if (player_id != key::empty) {
		return player_id;
	}
	if (string_or_empty(state, context, key::type) == key::town_assault) {
		const DictRef town = gd::as_dict(found_town(state, session, _battle_context_town_placement_id(state, session, context, source)));
		if (string_or_empty(state, town, key::controlling_player_id) != key::empty) {
			return gd::to_string(gd::index(state, town, str(key::controlling_player_id)));
		}
	}
	if (string_or_empty(state, context, key::type) == key::resource_assault) {
		const Atom resource_placement_id = _battle_context_resource_placement_id(state, context, source);
		// A null session finds no node ({}), whose defender has no player record and which nobody collected.
		if (session.kind != Kind::Nil) {
			const DictRef node_result = overworld_rules::_find_resource_node_by_placement(state, view(state, session), resource_placement_id);
			const DictRef node = gd::as_dict(get_or_new_dict(state, node_result, key::node));
			const Atom defender = player_identity_rules::defender_controller_id(state, node);
			if (!gd::is_empty(state, player_identity_rules::player(state, view(state, session), defender))) {
				return defender;
			}
			if (string_or_empty(state, node, key::collected_by_player_id) != key::empty) {
				return gd::to_string(gd::index(state, node, str(key::collected_by_player_id)));
			}
		}
	}
	return _battle_context_trigger_faction_id(state, session, context, source, state.new_dict());
}

Atom _battle_context_resource_placement_id(State &state, DictRef context, const Value &raw_context) {
	Atom placement_id = string_or_empty(state, context, key::resource_placement_id);
	if (placement_id != key::empty) {
		return placement_id;
	}
	const Value source = gd::is_dict(raw_context) ? raw_context : Value();
	if (gd::to_string(source_get(state, source, key::target_kind, str(key::empty))) == key::resource) {
		placement_id = gd::to_string(source_get(state, source, key::target_placement_id, str(key::empty)));
		if (placement_id != key::empty) {
			return placement_id;
		}
	}
	placement_id = gd::to_string(source_get(state, source, key::resource_placement_id, str(key::empty)));
	if (placement_id != key::empty) {
		return placement_id;
	}
	const Atom resolved_key = gd::to_string(source_get(state, source, key::placement_id, source_get(state, source, key::resolved_key, str(key::empty))));
	if (gd::begins_with(state, resolved_key, key::resource_defense)) {
		return gd::trim_prefix(state, resolved_key, key::resource_defense);
	}
	return key::empty;
}

Atom _battle_context_town_placement_id(State &state, const Value &session, DictRef context, const Value &raw_context) {
	Atom placement_id = string_or_empty(state, context, key::town_placement_id);
	if (placement_id != key::empty) {
		return placement_id;
	}
	const Value source = gd::is_dict(raw_context) ? raw_context : Value();
	if (gd::to_string(source_get(state, source, key::target_kind, str(key::empty))) == key::town) {
		placement_id = gd::to_string(source_get(state, source, key::target_placement_id, str(key::empty)));
		if (placement_id != key::empty) {
			return placement_id;
		}
	}
	const Atom resolved_key = gd::to_string(source_get(state, source, key::placement_id, source_get(state, source, key::resolved_key, str(key::empty))));
	if (gd::begins_with(state, resolved_key, key::town_assault_2)) {
		placement_id = gd::trim_prefix(state, resolved_key, key::town_assault_2);
		if (placement_id != key::empty) {
			return placement_id;
		}
	}
	int64_t position_x = 0;
	int64_t position_y = 0;
	Value position;
	if (gd::is_dict(source) && state.lookup(source.ref, str(key::position), position) && gd::is_dict(position)) {
		position_x = gd::int_field(state, position.ref, key::x, 0);
		position_y = gd::int_field(state, position.ref, key::y, 0);
	}
	const int64_t x = gd::to_int(state, source_get(state, source, key::x, int_value(position_x)));
	const int64_t y = gd::to_int(state, source_get(state, source, key::y, int_value(position_y)));
	// LevelRules.level_of({}) and of null are both 0.
	const DictRef found = _find_town_at_position(state, session, x, y, overworld_level_rules::level_of(state, source));
	return gd::to_string(ai::vget(state, get_or_new_dict(state, found, key::town), key::placement_id, str(key::empty)));
}

Atom _battle_context_trigger_faction_id(State &state, const Value &session, DictRef context, const Value &raw_context, DictRef town) {
	Atom faction_id = string_or_empty(state, context, key::trigger_faction_id);
	if (faction_id != key::empty) {
		return faction_id;
	}
	const Value source = gd::is_dict(raw_context) ? raw_context : Value();
	faction_id = gd::to_string(source_get(state, source, key::spawned_by_faction_id, source_get(state, source, key::trigger_faction_id, str(key::empty))));
	if (faction_id != key::empty) {
		return faction_id;
	}
	DictRef town_state = town;
	if (gd::is_empty(state, town_state)) {
		town_state = gd::as_dict(found_town(state, session, _battle_context_town_placement_id(state, session, context, raw_context)));
	}
	if (gd::is_empty(state, town_state)) {
		return key::empty;
	}
	const DictRef town_row = gd::content_row(state, ContentTable::Town, string_or_empty(state, town_state, key::town_id));
	return string_or_empty(state, town_row, key::faction_id);
}

bool _is_resource_assault_context(State &state, const Value &context) {
	return gd::is_dict(context) && string_or_empty(state, context.ref, key::type) == key::resource_assault;
}

Atom _battle_enemy_faction_id(State &state, const Value &session) {
	if (no_battle(state, session)) {
		return key::empty;
	}
	const Value context = gd::field(state, session_battle(state, session), key::context);
	Atom faction_id = key::empty;
	if (_is_town_defense_context(state, context) || _is_town_assault_context(state, context) || _is_resource_assault_context(state, context)) {
		faction_id = _battle_context_controller_id(state, session, context.ref, Value());
		if (_enemy_state_exists(state, session, faction_id)) {
			return faction_id;
		}
	}
	const DictRef encounter = _current_battle_encounter_placement(state, session);
	faction_id = player_identity_rules::raid_controller_id(state, encounter);
	if (_enemy_state_exists(state, session, faction_id)) {
		return faction_id;
	}
	faction_id = _side_faction_id(state, session_battle(state, session), key::enemy);
	return _enemy_state_exists(state, session, faction_id) ? faction_id : key::empty;
}

Atom _battle_enemy_label(State &state, const Value &session, Atom faction_id) {
	if (faction_id != key::empty) {
		// PlayerRules.faction_id(null, controller) finds no player record: the controller.
		const Atom content_id = session.kind == Kind::Nil ? faction_id : player_identity_rules::faction_id(state, view(state, session), faction_id);
		const DictRef faction = gd::content_row(state, ContentTable::Faction, content_id);
		return gd::to_string(state.get(faction, str(key::name), str(faction_id)));
	}
	if (no_battle(state, session)) {
		return key::the_opposing_host;
	}
	const DictRef battle = session_battle(state, session);
	return gd::to_string(state.get(battle, str(key::encounter_name), state.get(battle, str(key::encounter_id), str(key::the_opposing_host))));
}

Atom _side_faction_id(State &state, DictRef battle, Atom side) {
	// The counts Dictionary, keyed by String, in insertion order.
	std::vector<std::pair<Atom, int64_t>> counts;
	const ArrayRef stacks = _alive_stacks_for_side(state, battle, side);
	const int64_t size = state.array_size(stacks);
	for (int64_t index = 0; index < size; ++index) {
		const Atom faction_id = gd::to_string(ai::vget(state, state.at(stacks, index), key::faction_id, str(key::empty)));
		if (faction_id == key::empty) {
			continue;
		}
		bool counted = false;
		for (std::pair<Atom, int64_t> &entry : counts) {
			if (entry.first == faction_id) {
				entry.second = gd::add(entry.second, 1);
				counted = true;
				break;
			}
		}
		if (!counted) {
			counts.emplace_back(faction_id, 1);
		}
	}
	Atom best_id = key::empty;
	int64_t best_count = -1;
	for (const std::pair<Atom, int64_t> &entry : counts) {
		if (entry.second > best_count) {
			best_count = entry.second;
			best_id = entry.first;
		}
	}
	return best_id;
}

bool _enemy_state_exists(State &state, const Value &session, Atom faction_id) {
	if (session.kind == Kind::Nil || faction_id == key::empty) {
		return false;
	}
	for (const Value &enemy_state : gd::field_items(state, session_overworld(state, session), str(key::enemy_states))) {
		if (gd::is_dict(enemy_state) && player_identity_rules::controller_id(state, enemy_state.ref, key::empty) == faction_id) {
			return true;
		}
	}
	return false;
}

int64_t _adjust_enemy_pressure(State &state, const Value &session, Atom faction_id, int64_t delta) {
	if (session.kind == Kind::Nil || faction_id == key::empty || delta == 0) {
		return 0;
	}
	const DictRef overworld = session_overworld(state, session);
	// A missing enemy_states' [] has no state to adjust.
	Value states;
	if (!state.lookup(overworld, str(key::enemy_states), states) || !gd::is_array(states)) {
		return 0;
	}
	const int64_t size = state.array_size(states.ref);
	for (int64_t index = 0; index < size; ++index) {
		const Value enemy_state = state.at(states.ref, index);
		if (!gd::is_dict(enemy_state) || player_identity_rules::controller_id(state, enemy_state.ref, key::empty) != faction_id) {
			continue;
		}
		const int64_t current = imax(0, gd::int_field(state, enemy_state.ref, key::pressure, 0));
		const int64_t updated = imax(0, gd::add(current, delta));
		state.set(enemy_state.ref, str(key::pressure), int_value(updated));
		state.set_at(states.ref, index, enemy_state);
		state.set(overworld, str(key::enemy_states), states);
		return gd::sub(updated, current);
	}
	return 0;
}

void _add_enemy_treasury_resources(State &state, const Value &session, Atom faction_id, DictRef delta) {
	if (session.kind == Kind::Nil || faction_id == key::empty || gd::is_empty(state, delta)) {
		return;
	}
	const DictRef overworld = session_overworld(state, session);
	Value states;
	if (!state.lookup(overworld, str(key::enemy_states), states) || !gd::is_array(states)) {
		return;
	}
	const int64_t size = state.array_size(states.ref);
	for (int64_t index = 0; index < size; ++index) {
		const Value enemy_state = state.at(states.ref, index);
		if (!gd::is_dict(enemy_state) || player_identity_rules::controller_id(state, enemy_state.ref, key::empty) != faction_id) {
			continue;
		}
		const DictRef treasury = ai::duplicate_field(state, enemy_state.ref, key::treasury);
		const ArrayRef resource_keys = gd::keys(state, delta);
		const int64_t key_count = state.array_size(resource_keys);
		for (int64_t key_index = 0; key_index < key_count; ++key_index) {
			const Value resource_key = str(gd::to_string(state.at(resource_keys, key_index)));
			const int64_t held = gd::to_int(state, state.get(treasury, resource_key, int_value(0)));
			const int64_t added = gd::to_int(state, state.get(delta, resource_key, int_value(0)));
			state.set(treasury, resource_key, int_value(imax(0, gd::add(held, added))));
		}
		state.set(enemy_state.ref, str(key::treasury), dict_value(treasury));
		state.set_at(states.ref, index, enemy_state);
		state.set(overworld, str(key::enemy_states), states);
		return;
	}
}

void _set_enemy_siege_progress(State &state, const Value &session, Atom faction_id, int64_t progress) {
	if (session.kind == Kind::Nil || faction_id == key::empty) {
		return;
	}
	const DictRef overworld = session_overworld(state, session);
	// A missing enemy_states' new [] is written back below.
	const Value states = get_or_new_array(state, overworld, key::enemy_states);
	if (!gd::is_array(states)) {
		return;
	}
	const int64_t size = state.array_size(states.ref);
	for (int64_t index = 0; index < size; ++index) {
		const Value enemy_state = state.at(states.ref, index);
		if (!gd::is_dict(enemy_state)) {
			continue;
		}
		if (player_identity_rules::controller_id(state, enemy_state.ref, key::empty) != faction_id) {
			continue;
		}
		state.set(enemy_state.ref, str(key::siege_progress), int_value(imax(0, progress)));
		state.set_at(states.ref, index, enemy_state);
		break;
	}
	state.set(overworld, str(key::enemy_states), states);
}

Atom _apply_front_pressure_shift(State &state, const Value &session, Atom faction_id, int64_t delta, Atom outcome) {
	const int64_t applied = _adjust_enemy_pressure(state, session, faction_id, delta);
	if (applied == 0) {
		return key::empty;
	}
	const Atom faction_name = _battle_enemy_label(state, session, faction_id);
	if (applied > 0) {
		Atom reason = key::the_broken_contact;
		if (outcome == key::surrender) {
			reason = key::the_capitulation;
		} else if (outcome == key::hero_defeat || outcome == key::defeat) {
			reason = key::the_rout;
		} else if (outcome == key::town_lost) {
			reason = key::the_collapse_at_the_walls;
		}
		return gd::format(state, key::s_front_pressure_rises_by_d, { str(faction_name), int_value(applied), str(reason) });
	}
	return gd::format(state, key::s_front_pressure_drops_by_d, { str(faction_name), int_value(compat::absi(applied)) });
}

DictRef _apply_victory_front_aftermath(State &state, const Value &session) {
	if (no_battle(state, session)) {
		return summary_result(state, key::empty);
	}
	const Atom faction_id = _battle_enemy_faction_id(state, session);
	if (faction_id == key::empty) {
		return summary_result(state, key::empty);
	}
	const DictRef encounter = _current_battle_encounter_placement(state, session);
	int64_t pressure_delta = -1;
	if (
			_is_town_defense_context(state, gd::field(state, session_battle(state, session), key::context))
			|| _is_town_assault_context(state, gd::field(state, session_battle(state, session), key::context))
			|| string_or_empty(state, encounter, key::spawned_by_faction_id) != key::empty) {
		pressure_delta = -2;
	}
	const Atom pressure_summary = _apply_front_pressure_shift(state, session, faction_id, pressure_delta, key::victory);
	return summary_result(state, pressure_summary);
}

DictRef _apply_collapse_aftermath(State &state, const Value &session, Atom outcome) {
	const DictRef preview = _build_collapse_aftermath_preview(state, session, outcome);
	Atom resource_summary = key::empty;
	Value resource_loss;
	if (state.lookup(preview, str(key::resource_loss), resource_loss) && gd::is_dict(resource_loss) && !gd::is_empty(state, resource_loss.ref)) {
		overworld_rules::_spend_resources(state, view(state, session), resource_loss);
		_add_enemy_treasury_resources(state, session, string_or_empty(state, preview, key::enemy_faction_id), resource_loss.ref);
		resource_summary = _collapse_resource_summary(state, outcome, resource_loss.ref, gd::string_field(state, preview, key::enemy_label, key::the_enemy));
	}
	const Atom pressure_summary = _apply_front_pressure_shift(
			state,
			session,
			string_or_empty(state, preview, key::enemy_faction_id),
			gd::int_field(state, preview, key::pressure_delta, 0),
			outcome);
	const Atom recovery_summary = _apply_collapse_recovery_pressure(
			state,
			session,
			string_or_empty(state, preview, key::nearest_town_placement_id),
			gd::int_field(state, preview, key::recovery_pressure, 0),
			outcome);
	Atom summary = _join_messages(state, string_array(state, { resource_summary, pressure_summary, recovery_summary }));
	if (summary == key::empty) {
		summary = key::the_routed_survivors_leave_nothing_organized;
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::summary), str(summary));
	state.set(result, str(key::resource_summary), str(resource_summary));
	state.set(result, str(key::pressure_summary), str(pressure_summary));
	state.set(result, str(key::recovery_summary), str(recovery_summary));
	return result;
}

DictRef _apply_withdrawal_aftermath(State &state, const Value &session, Atom outcome) {
	const DictRef preview = _build_withdrawal_aftermath_preview(state, session, outcome);
	Atom resource_summary = key::empty;
	Value resource_loss;
	if (state.lookup(preview, str(key::resource_loss), resource_loss) && gd::is_dict(resource_loss) && !gd::is_empty(state, resource_loss.ref)) {
		overworld_rules::_spend_resources(state, view(state, session), resource_loss);
		_add_enemy_treasury_resources(state, session, string_or_empty(state, preview, key::enemy_faction_id), resource_loss.ref);
		resource_summary = _withdrawal_resource_summary(state, outcome, resource_loss.ref, gd::string_field(state, preview, key::enemy_label, key::the_enemy));
	}
	const Atom army_summary = _apply_active_hero_aftermath_losses(state, session, gd::int_field(state, preview, key::casualty_units, 0), outcome);
	const Atom pressure_summary = _apply_front_pressure_shift(
			state,
			session,
			string_or_empty(state, preview, key::enemy_faction_id),
			gd::int_field(state, preview, key::pressure_delta, 0),
			outcome);
	const Atom recovery_summary = _apply_withdrawal_recovery_pressure(
			state,
			session,
			string_or_empty(state, preview, key::nearest_town_placement_id),
			gd::int_field(state, preview, key::recovery_pressure, 0),
			outcome);
	Atom summary = _join_messages(state, string_array(state, { resource_summary, army_summary, pressure_summary, recovery_summary }));
	if (summary == key::empty) {
		summary = outcome == key::surrender ? key::the_surrender_terms_keep_the_survivors : key::the_rearguard_keeps_the_withdrawal_orderly;
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::summary), str(summary));
	state.set(result, str(key::resource_summary), str(resource_summary));
	state.set(result, str(key::army_summary), str(army_summary));
	state.set(result, str(key::pressure_summary), str(pressure_summary));
	state.set(result, str(key::recovery_summary), str(recovery_summary));
	return result;
}

Atom _apply_collapse_recovery_pressure(State &state, const Value &session, Atom town_placement_id, int64_t pressure, Atom outcome) {
	if (town_placement_id == key::empty || pressure <= 0) {
		return key::empty;
	}
	Atom source = key::broken_field_army;
	if (outcome == key::town_lost) {
		source = key::breached_walls;
	}
	// OverworldRules.apply_town_recovery_pressure answers "" for a null session.
	if (session.kind == Kind::Nil) {
		return key::empty;
	}
	return overworld_rules::apply_town_recovery_pressure(state, view(state, session), town_placement_id, pressure, source);
}

Atom _apply_withdrawal_recovery_pressure(State &state, const Value &session, Atom town_placement_id, int64_t pressure, Atom outcome) {
	if (town_placement_id == key::empty || pressure <= 0) {
		return key::empty;
	}
	const Atom source = outcome == key::surrender ? key::surrender_column : key::scattered_survivors;
	if (session.kind == Kind::Nil) {
		return key::empty;
	}
	return overworld_rules::apply_town_recovery_pressure(state, view(state, session), town_placement_id, pressure, source);
}

Atom _apply_town_assault_recovery(State &state, const Value &session, Atom outcome) {
	const Value context = gd::field(state, session_battle(state, session), key::context);
	if (!_is_town_assault_context(state, context)) {
		return key::empty;
	}
	const int64_t pressure = _town_assault_recovery_pressure(state, session, outcome);
	if (pressure <= 0) {
		return key::empty;
	}
	const Atom source = outcome == key::victory ? key::stormed_walls : key::contested_walls;
	return overworld_rules::apply_town_recovery_pressure(state, view(state, session), string_or_empty(state, context.ref, key::town_placement_id), pressure, source);
}

Atom _apply_town_defense_recovery(State &state, const Value &session, Atom outcome) {
	const Value context = gd::field(state, session_battle(state, session), key::context);
	if (!_is_town_defense_context(state, context)) {
		return key::empty;
	}
	const int64_t pressure = _town_defense_recovery_pressure(state, session, outcome);
	if (pressure <= 0) {
		return key::empty;
	}
	Atom source = key::empty;
	if (outcome == key::victory) {
		source = key::repelled_assault;
	} else if (outcome == key::stalemate) {
		source = key::battered_walls;
	} else if (outcome == key::loss) {
		source = key::breached_walls;
	}
	return overworld_rules::apply_town_recovery_pressure(state, view(state, session), string_or_empty(state, context.ref, key::town_placement_id), pressure, source);
}

int64_t _town_assault_recovery_pressure(State &state, const Value &session, Atom outcome) {
	if (no_battle(state, session)) {
		return 0;
	}
	const Value context = get_or_new_dict(state, session_battle(state, session), key::context);
	const Value town = found_town(state, session, gd::to_string(ai::vget(state, context, key::town_placement_id, str(key::empty))));
	// _army_strength_from_stacks counts nothing in a missing garrison's [] or in null.
	const int64_t garrison_strength = _army_strength_from_stacks(state, ai::vget(state, town, key::garrison, Value()));
	int64_t pressure = imax(1, compat::float_to_int(compat::godot_round(static_cast<double>(imax(1, garrison_strength)) / 220.0)));
	if (outcome == key::victory) {
		pressure = gd::add(pressure, 1);
	}
	const Atom role = overworld_rules::town_strategic_role(state, gd::as_dict(town));
	if (role == key::capital) {
		pressure = gd::add(pressure, 1);
	} else if (role == key::stronghold) {
		pressure = gd::add(pressure, 1);
	}
	return compat::engine_clamp<int64_t>(pressure, 1, 5);
}

int64_t _town_defense_recovery_pressure(State &state, const Value &session, Atom outcome) {
	if (no_battle(state, session)) {
		return 0;
	}
	const Value context = get_or_new_dict(state, session_battle(state, session), key::context);
	const DictRef encounter_result = _find_encounter_by_key(state, session, string_or_empty(state, session_battle(state, session), key::resolved_key));
	const Value army = vget_or_new_dict(state, get_or_new_dict(state, encounter_result, key::encounter), key::enemy_army);
	// A missing stacks' [] counts nothing, as null does.
	const int64_t assault_strength = _army_strength_from_stacks(state, ai::vget(state, army, key::stacks, Value()));
	int64_t pressure = imax(1, compat::float_to_int(compat::godot_round(static_cast<double>(imax(1, assault_strength)) / 180.0)));
	if (outcome == key::stalemate) {
		pressure = gd::add(pressure, 1);
	} else if (outcome == key::loss) {
		pressure = gd::add(pressure, 2);
	}
	const Value town = found_town(state, session, gd::to_string(ai::vget(state, context, key::town_placement_id, str(key::empty))));
	const Atom role = overworld_rules::town_strategic_role(state, gd::as_dict(town));
	if (role == key::capital) {
		pressure = gd::add(pressure, 1);
	} else if (role == key::stronghold) {
		pressure = gd::add(pressure, 1);
	}
	return compat::engine_clamp<int64_t>(pressure, 1, 6);
}

Atom _apply_delivery_route_aftermath(State &state, const Value &session, Atom outcome) {
	if (no_battle(state, session)) {
		return key::empty;
	}
	if (gd::bool_field(state, session_battle(state, session), key::delivery_outcome_applied, false)) {
		return key::empty;
	}
	const Value context = get_or_new_dict(state, session_battle(state, session), key::context);
	const Atom node_placement_id = gd::to_string(ai::vget(state, context, key::delivery_node_placement_id, str(key::empty)));
	if (node_placement_id == key::empty) {
		return key::empty;
	}
	state.set(session_battle(state, session), str(key::delivery_outcome_applied), bool_value(true));
	const DictRef result = overworld_rules::apply_delivery_interception_outcome(state, view(state, session), node_placement_id, outcome);
	return string_or_empty(state, result, key::summary);
}

void _apply_enemy_victory_specialties(State &state, const Value &session) {
	if (no_battle(state, session)) {
		return;
	}
	_apply_victory_recovery(state, session_battle(state, session), key::enemy);
	// A missing enemy_hero's {} is empty.
	Value commander_state;
	if (state.lookup(session_battle(state, session), str(key::enemy_hero), commander_state) && gd::is_dict(commander_state) && !gd::is_empty(state, commander_state.ref)) {
		const DictRef updated = gd::deep_duplicate_dict(state, commander_state.ref);
		if (_apply_victory_mana(state, updated, session_battle(state, session), key::enemy) > 0) {
			state.set(session_battle(state, session), str(key::enemy_hero), dict_value(updated));
		}
	}
}

void _capture_town_after_assault(State &state, const Value &session, Atom town_placement_id, ArrayRef enemy_survivors) {
	const DictRef town_result = _find_town_by_placement(state, session, town_placement_id);
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return;
	}
	const Value context = get_or_new_dict(state, session_battle(state, session), key::context);
	const Atom controller_id = _battle_context_controller_id(state, session, gd::as_dict(context), Value());
	const DictRef transition = overworld_rules::transition_town_control(state, view(state, session), town_placement_id, key::enemy, controller_id, key::retaken_town);
	Value town;
	if (!state.lookup(transition, str(key::town), town)) {
		town = get_or_new_dict(state, town_result, key::town);
	}
	const Value towns = get_or_new_array(state, session_overworld(state, session), key::towns);
	state.set(gd::as_dict(town), str(key::garrison), array_value(gd::deep_duplicate_array(state, enemy_survivors)));
	vset_index(state, towns, gd::int_field(state, town_result, key::index, -1), town);
	state.set(session_overworld(state, session), str(key::towns), towns);
}

Atom _keep_enemy_hero_after_town_capture(State &state, const Value &session, Atom town_placement_id, ArrayRef enemy_survivors) {
	const DictRef encounter_result = _find_encounter_by_key(state, session, string_or_empty(state, session_battle(state, session), key::resolved_key));
	const int64_t index = gd::int_field(state, encounter_result, key::index, -1);
	const DictRef town = gd::as_dict(found_town(state, session, town_placement_id));
	if (index < 0 || gd::is_empty(state, town)) {
		return key::empty;
	}
	const Value encounters = get_or_new_array(state, session_overworld(state, session), key::encounters);
	const DictRef encounter = gd::as_dict(get_or_new_dict(state, encounter_result, key::encounter));
	const DictRef army = own_dict_field(state, encounter, key::enemy_army);
	state.set(army, str(key::stacks), array_value(gd::deep_duplicate_array(state, enemy_survivors)));
	state.set(encounter, str(key::enemy_army), dict_value(army));
	// A missing enemy_hero's {} is empty.
	Value commander_state;
	if (state.lookup(session_battle(state, session), str(key::enemy_hero), commander_state) && gd::is_dict(commander_state) && !gd::is_empty(state, commander_state.ref)) {
		const DictRef updated_commander = enemy_adventure_rules::advance_commander_record(
				state,
				_apply_enemy_commander_battle_memory(state, session, commander_state.ref),
				key::town_captured);
		const DictRef synced = enemy_adventure_rules::sync_commander_army_continuity(state, updated_commander, dict_value(army), string_or_empty(state, encounter, key::encounter_id));
		state.set(encounter, str(key::enemy_commander_state), dict_value(synced));
	}
	const DictRef entrance = overworld_level_rules::town_entrance(state, town);
	state.set(encounter, str(key::x), int_value(gd::to_int(state, state.get(entrance, str(key::x), state.get(encounter, str(key::x), int_value(0))))));
	state.set(encounter, str(key::y), int_value(gd::to_int(state, state.get(entrance, str(key::y), state.get(encounter, str(key::y), int_value(0))))));
	state.set(encounter, str(key::level), int_value(overworld_level_rules::level_of(state, dict_value(entrance))));
	state.erase(encounter, str(key::battle_context));
	vset_index(state, encounters, index, dict_value(encounter));
	state.set(session_overworld(state, session), str(key::encounters), encounters);
	overworld_rules::invalidate_spatial_lookup(state, view(state, session));
	const Atom commander_name = enemy_adventure_rules::commander_display_name(state, get_or_new_dict(state, encounter, key::enemy_commander_state), false);
	return gd::format(state, key::s_holds_s, { str(commander_name), str(_town_name(state, town)) });
}

Atom _station_enemy_commander_after_town_capture(State &state, const Value &session, Atom town_placement_id, ArrayRef enemy_survivors) {
	if (no_battle(state, session) || town_placement_id == key::empty) {
		return key::empty;
	}
	const Atom faction_id = _battle_enemy_faction_id(state, session);
	if (faction_id == key::empty) {
		return key::empty;
	}
	// A missing enemy_hero's {} is empty.
	Value commander_state;
	if (!state.lookup(session_battle(state, session), str(key::enemy_hero), commander_state) || !gd::is_dict(commander_state) || gd::is_empty(state, commander_state.ref)) {
		return key::empty;
	}
	const DictRef town_result = _find_town_by_placement(state, session, town_placement_id);
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return key::empty;
	}
	const DictRef town = gd::as_dict(get_or_new_dict(state, town_result, key::town));
	if (gd::string_field(state, town, key::owner, key::neutral) != key::enemy) {
		return key::empty;
	}
	const Atom defense_placement_id = gd::format(state, key::town_defense_s, { str(town_placement_id) });
	DictRef updated_commander = enemy_adventure_rules::advance_commander_record(
			state,
			_apply_enemy_commander_battle_memory(state, session, commander_state.ref),
			key::town_captured);
	const DictRef army_source = state.new_dict();
	state.set(army_source, str(key::stacks), array_value(enemy_survivors));
	updated_commander = enemy_adventure_rules::sync_commander_army_continuity(state, updated_commander, dict_value(army_source), defense_placement_id);
	state.set(session_battle(state, session), str(key::enemy_hero), dict_value(updated_commander));
	const DictRef front = own_dict_field(state, town, key::front);
	const Atom front_state = string_or_empty(state, front, key::state) != key::empty ? gd::string_field(state, front, key::state, key::stabilizing) : key::stabilizing;
	state.set(front, str(key::state), str(front_state));
	state.set(front, str(key::faction_id), str(faction_id));
	// session.day: nothing below changes it.
	const int64_t day = gd::to_int(state, gd::member(state, session, key::day));
	state.set(front, str(key::last_defended_day), int_value(day));
	state.set(front, str(key::defense_until_day), int_value(imax(gd::int_field(state, front, key::defense_until_day, 0), gd::add(day, 3))));
	state.set(front, str(key::stabilize_until_day), int_value(imax(gd::int_field(state, front, key::stabilize_until_day, 0), gd::add(day, 3))));
	state.set(front, str(key::source), str(key::strategic_ai_defended_town_capture_stationing));
	state.set(town, str(key::front), dict_value(front));
	state.set(town, str(key::ai_defended_by_faction_id), str(faction_id));
	state.set(town, str(key::ai_defended_day), int_value(day));
	state.set(town, str(key::ai_defense_until_day), int_value(imax(gd::int_field(state, town, key::ai_defense_until_day, 0), gd::add(day, 3))));
	const int64_t defense_rating = gd::int_field(state, town, key::ai_defense_rating, 0);
	state.set(town, str(key::ai_defense_rating), int_value(imax(defense_rating, enemy_adventure_rules::_army_strength(state, array_value(enemy_survivors)))));
	const int64_t reinforced_strength = gd::int_field(state, town, key::ai_defense_reinforced_strength, 0);
	state.set(town, str(key::ai_defense_reinforced_strength), int_value(imax(reinforced_strength, enemy_adventure_rules::_army_strength(state, array_value(enemy_survivors)))));
	state.set(town, str(key::ai_defender_commander_state), dict_value(updated_commander));
	state.set(town, str(key::ai_defender_roster_hero_id), str(string_or_empty(state, updated_commander, key::roster_hero_id)));
	const Value towns = get_or_new_array(state, session_overworld(state, session), key::towns);
	vset_index(state, towns, gd::int_field(state, town_result, key::index, -1), dict_value(town));
	state.set(session_overworld(state, session), str(key::towns), towns);
	enemy_adventure_rules::sync_commander_state_to_roster(
			state,
			view(state, session),
			faction_id,
			dict_value(updated_commander),
			key::active,
			defense_placement_id,
			-1,
			key::town_captured);
	const Atom commander_name = enemy_adventure_rules::commander_display_name(state, dict_value(updated_commander), true);
	return gd::format(state, key::s_holds_s_as_the_new, { str(commander_name), str(_town_name(state, town)) });
}

Atom _stabilize_hostile_town_front(State &state, const Value &session, Atom source, int64_t bonus_days) {
	if (no_battle(state, session)) {
		return key::empty;
	}
	const Value context = gd::field(state, session_battle(state, session), key::context);
	if (!_is_town_assault_context(state, context)) {
		return key::empty;
	}
	const Atom town_placement_id = string_or_empty(state, context.ref, key::town_placement_id);
	const Atom faction_id = _battle_context_controller_id(state, session, context.ref, Value());
	const DictRef result = overworld_rules::stabilize_town_front(state, view(state, session), town_placement_id, faction_id, source, bonus_days);
	if (!gd::bool_field(state, result, key::ok, false)) {
		return key::empty;
	}
	// var front: Dictionary = result.get("front", {}): a missing front's {} has no days_remaining. The town name
	// read in between changes nothing.
	int64_t days_remaining = 0;
	Value front;
	if (state.lookup(result, str(key::front), front)) {
		days_remaining = gd::int_field(state, gd::as_dict(front), key::days_remaining, 0);
	}
	const Atom town_name = _town_name_from_placement_id(state, session, town_placement_id);
	const Atom label = or_default(town_name, key::the_town);
	if (days_remaining > 0) {
		return gd::format(state, key::s_shifts_onto_stabilization_orders_for, { str(label), int_value(days_remaining), str(days_remaining == 1 ? key::empty : key::s) });
	}
	return gd::format(state, key::s_stays_on_stabilization_orders, { str(label) });
}

DictRef _find_town_by_placement(State &state, const Value &session, Atom placement_id) {
	if (session.kind == Kind::Nil || placement_id == key::empty) {
		return index_result(state, -1, key::town, dict_value(state.new_dict()));
	}
	// A missing towns' [] has no town.
	Value towns;
	if (state.lookup(session_overworld(state, session), str(key::towns), towns)) {
		const int64_t size = ai::vsize(state, towns);
		for (int64_t index = 0; index < size; ++index) {
			const Value town = ai::vindex(state, towns, int_value(index));
			if (gd::is_dict(town) && string_or_empty(state, town.ref, key::placement_id) == placement_id) {
				return index_result(state, index, key::town, town);
			}
		}
	}
	return index_result(state, -1, key::town, dict_value(state.new_dict()));
}

DictRef _find_town_at_position(State &state, const Value &session, int64_t x, int64_t y, int64_t level) {
	if (session.kind == Kind::Nil) {
		return index_result(state, -1, key::town, dict_value(state.new_dict()));
	}
	Value towns;
	if (state.lookup(session_overworld(state, session), str(key::towns), towns)) {
		const int64_t size = ai::vsize(state, towns);
		for (int64_t index = 0; index < size; ++index) {
			const Value town = ai::vindex(state, towns, int_value(index));
			if (!gd::is_dict(town) || !overworld_level_rules::on_level(state, town, level)) {
				continue;
			}
			const DictRef entrance = overworld_level_rules::town_entrance(state, town.ref);
			const bool at_town = gd::to_int(state, state.get(town.ref, str(key::x), int_value(-9999))) == x
					&& gd::to_int(state, state.get(town.ref, str(key::y), int_value(-9999))) == y;
			if (at_town
					|| (gd::to_int(state, gd::index(state, entrance, str(key::x))) == x
							&& gd::to_int(state, gd::index(state, entrance, str(key::y))) == y)) {
				return index_result(state, index, key::town, town);
			}
		}
	}
	return index_result(state, -1, key::town, dict_value(state.new_dict()));
}

Atom _town_name(State &state, DictRef town) {
	if (gd::is_empty(state, town)) {
		return key::empty;
	}
	const DictRef town_template = gd::content_row(state, ContentTable::Town, string_or_empty(state, town, key::town_id));
	return gd::to_string(state.get(town_template, str(key::name), state.get(town, str(key::town_id), str(key::Town))));
}

Atom _town_name_from_placement_id(State &state, const Value &session, Atom placement_id) {
	return _town_name(state, gd::as_dict(found_town(state, session, placement_id)));
}

} // namespace battle_rules

} // namespace aurelion::rules::port
