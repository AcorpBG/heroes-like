// AiHeroRules: where a computer player's heroes fight and take things: guards,
// heroes, towns, sites and artifacts, the auto-resolved battles (the battle
// itself is Phase 2a's preview, ai_battle_preview.hpp), the battles a human
// fights, and their logs and events.

#include "aurelion_rules/port/ai_battle_preview.hpp"
#include "aurelion_rules/port/ai_hero_rules_turn.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules_turn.hpp"
#include "aurelion_rules/port/battle_payload.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_ai.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_turn.hpp"
#include "aurelion_rules/port/enemy_adventure_rules_turn.hpp"
#include "aurelion_rules/port/enemy_turn_rules_turn.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_progression_rules_turn.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/overworld_turn_playback_turn.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/player_identity_rules_turn.hpp"
#include "aurelion_rules/port/resource_node_payload_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules_turn.hpp"
#include "aurelion_rules/port/visit_building_rules_ai.hpp"

#include <cmath>
#include <cstdint>
#include <initializer_list>
#include <limits>
#include <string>
#include <unordered_set>

namespace aurelion::rules::port {

// Defined in enemy_states.cpp, which declares them for itself; no header does.
namespace enemy_adventure_rules {
gd::DictRef sync_commander_army_continuity(state::State &state, gd::DictRef commander_state, const state::Value &army_source, gd::Atom encounter_id);
gd::DictRef _normalize_enemy_progression(state::State &state, gd::DictRef commander_state);
} // namespace enemy_adventure_rules

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::float_value;
using gd::int_value;
using gd::PackedRef;
using gd::str;
using overworld_rules::Vector2i;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;
namespace player_rules = player_identity_rules;

constexpr int64_t kStopEncounter = 4;
constexpr int64_t kRecoveryDaysDefeated = 3;

double tunable(State &state, Atom name) {
	return ai::static_float(state, key::ai_hero_rules_script, name);
}

int64_t tunable_int(State &state, Atom name) {
	return ai::static_int(state, key::ai_hero_rules_script, name);
}

// var size: Vector2i = value
Vector2i as_vector2i(const Value &value) {
	if (!gd::is_vector2i(value)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(value) + "' to a variable of type 'Vector2i'.");
	}
	return {value.vx(), value.vy()};
}

Vector2i context_size(const State &state, DictRef context) {
	return as_vector2i(gd::index(state, context, str(key::map_size)));
}

int64_t checked_mod(int64_t a, int64_t b) {
	if (b == 0) {
		throw state::ScriptError("Division by zero error in operator '%'.");
	}
	return compat::int_mod(a, b);
}

int64_t checked_div(int64_t a, int64_t b) {
	if (b == 0) {
		throw state::ScriptError("Division by zero error in operator '/'.");
	}
	return compat::int_div(a, b);
}

// var x: Dictionary = d.get(field, {})
DictRef dict_field(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? gd::as_dict(found) : state.new_dict();
}

// var x: Dictionary = d.get(field, {}) if d.get(field, {}) is Dictionary else {}
DictRef dict_field_if(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) && gd::is_dict(found) ? found.ref : state.new_dict();
}

// var x: Array = d.get(field, [])
ArrayRef array_field(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? gd::as_array(found) : state.new_array();
}

// var x: Array = d.get(field, []) if d.get(field, []) is Array else []
ArrayRef array_field_if(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) && gd::is_array(found) ? found.ref : state.new_array();
}

// d.get(field, []) and d.get(field, {}) as untyped values.
Value list_field(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

Value map_field(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}

// d.get(outer, {}).get(inner, fallback)
Value nested_get(const State &state, DictRef dict, Atom outer, Atom inner, const Value &fallback) {
	Value found;
	if (!state.lookup(dict, str(outer), found)) {
		return fallback;
	}
	return ai::vget(state, found, inner, fallback);
}

// d.get(outer, {}).get(inner, [])
Value nested_list(State &state, DictRef dict, Atom outer, Atom inner) {
	Value found;
	if (state.lookup(dict, str(outer), found)) {
		if (!gd::is_dict(found)) {
			return ai::vget(state, found, inner, array_value(state.new_array()));
		}
		Value inner_found;
		if (state.lookup(found.ref, str(inner), inner_found)) {
			return inner_found;
		}
	}
	return array_value(state.new_array());
}

// session.overworld.encounters[index] as a Dictionary.
DictRef encounter_at(State &state, DictRef session, int64_t index) {
	const Value encounters = gd::index(state, session_view::overworld(state, session), str(key::encounters));
	return gd::as_dict(ai::vindex(state, encounters, int_value(index)));
}

// session.overworld.resource_nodes[index] as a Dictionary.
DictRef resource_node_at(State &state, DictRef session, int64_t index) {
	const Value nodes = gd::index(state, session_view::overworld(state, session), str(key::resource_nodes));
	return gd::as_dict(ai::vindex(state, nodes, int_value(index)));
}

Atom context_controller(State &state, DictRef context) {
	return gd::stringify(state, gd::index(state, context, str(key::controller)));
}

DictRef context_config(State &state, DictRef context) {
	return gd::as_dict(gd::index(state, context, str(key::config)));
}

// context.state.treasury
DictRef context_treasury(State &state, DictRef context) {
	return gd::as_dict(ai::vmember(state, gd::index(state, context, str(key::state)), key::treasury));
}

DictRef session_flags(State &state, DictRef session) {
	return gd::as_dict(gd::index(state, session, str(key::flags)));
}

int64_t session_day(const State &state, DictRef session) {
	return ai::session_int(state, session, key::day);
}

// int(search.dist[tile_index])
int64_t search_distance(const State &state, DictRef search, int64_t tile_index) {
	return gd::to_int(state, ai::vindex(state, gd::index(state, search, str(key::dist)), int_value(tile_index)));
}

// value.keys() of an untyped value.
ArrayRef keys_of(State &state, const Value &value) {
	if (!gd::is_dict(value)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'keys' in base '") + gd::type_name(value) + "'.");
	}
	return gd::keys(state, value.ref);
}

// [text, ...] of Strings.
ArrayRef string_list(State &state, std::initializer_list<Atom> texts) {
	const ArrayRef list = state.new_array();
	for (const Atom text : texts) {
		state.append(list, str(text));
	}
	return list;
}

// {"arrived": true}
DictRef arrived_result(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::arrived), bool_value(true));
	return result;
}

// {"arrived": true, "events": events}
DictRef arrived_events(State &state, const Value &events) {
	const DictRef result = arrived_result(state);
	state.set(result, str(key::events), events);
	return result;
}

// An event's target: kind, placement, label and position.
DictRef event_target(State &state, Atom kind, Atom placement_id, Atom label, int64_t x, int64_t y) {
	const DictRef target = state.new_dict();
	state.set(target, str(key::target_kind), str(kind));
	state.set(target, str(key::target_placement_id), str(placement_id));
	state.set(target, str(key::target_label), str(label));
	state.set(target, str(key::target_x), int_value(x));
	state.set(target, str(key::target_y), int_value(y));
	return target;
}

// String(key) in LIVE_RESOURCE_KEYS
bool live_resource(Atom name) {
	return name == key::gold || name == key::wood || name == key::ore || name == key::aetherglass || name == key::embergrain || name == key::peatwax || name == key::verdant_grafts || name == key::brass_scrip || name == key::memory_salt;
}

double empty_commander_power(State &state, const Value &stacks) {
	return ai_hero_rules::army_power(state, stacks, dict_value(state.new_dict()));
}

} // namespace

namespace ai_hero_rules {

Atom hero_name(State &state, DictRef entry) {
	Value found;
	const bool has_commander = state.lookup(entry, str(key::enemy_commander_state), found) && gd::is_dict(found);
	const DictRef commander = has_commander ? found.ref : 0;
	Atom name = has_commander ? ai::string_or_empty(state, commander, key::name) : key::empty;
	if (name == key::empty) {
		const Atom roster_id = has_commander ? ai::string_or_empty(state, commander, key::roster_hero_id) : key::empty;
		name = ai::string_or_empty(state, gd::content_row(state, ContentTable::Hero, roster_id), key::name);
	}
	return name != key::empty ? name : key::enemy_hero_2;
}

void _store_entry(State &state, DictRef session, int64_t index, DictRef entry) {
	const DictRef overworld = session_view::overworld(state, session);
	Value found;
	if (!state.lookup(overworld, str(key::encounters), found)) {
		return;
	}
	const ArrayRef encounters = gd::as_array(found);
	if (index >= 0 && index < state.array_size(encounters)) {
		state.set_at(encounters, index, dict_value(entry));
		state.set(session_view::overworld(state, session), str(key::encounters), array_value(encounters));
	}
}

bool _is_resolved(State &state, DictRef session, Atom placement_id) {
	Value found;
	if (!state.lookup(session_view::overworld(state, session), str(key::resolved_encounters), found)) {
		return false;
	}
	return gd::in(state, str(placement_id), found);
}

void _mark_resolved(State &state, DictRef session, Atom placement_id) {
	const ArrayRef resolved = array_field_if(state, session_view::overworld(state, session), key::resolved_encounters);
	if (placement_id != key::empty && !gd::array_has(state, resolved, str(placement_id))) {
		state.append(resolved, str(placement_id));
	}
	state.set(session_view::overworld(state, session), str(key::resolved_encounters), array_value(resolved));
}

int64_t _max_affordable_with_market(State &state, DictRef session, DictRef town, DictRef pool, DictRef unit_cost, int64_t available) {
	int64_t low = 0;
	int64_t high = compat::engine_max<int64_t>(0, available);
	const DictRef market_memo = state.new_dict();
	while (low < high) {
		const int64_t middle = (low + high + 1) / 2;
		const DictRef cost = enemy_turn_rules::_scale_resource_pool(state, dict_value(unit_cost), middle);
		if (_market_cover(state, session, town, pool, cost, false, dict_value(market_memo))) {
			low = middle;
		} else {
			high = middle - 1;
		}
	}
	return low;
}

ArrayRef _recruit_town(State &state, DictRef session, DictRef context, int64_t index, DictRef reserve) {
	const DictRef treasury = context_treasury(state, context);
	const ArrayRef events = state.new_array();
	Value found;
	if (!state.lookup(session_view::overworld(state, session), str(key::towns), found)) {
		return events;
	}
	const ArrayRef towns = gd::as_array(found);
	if (index < 0 || index >= state.array_size(towns)) {
		return events;
	}
	const DictRef town = gd::as_dict(state.at(towns, index));
	const ArrayRef unit_ids = state.new_array();
	if (state.lookup(town, str(key::available_recruits), found)) {
		const ArrayRef recruit_keys = keys_of(state, found);
		const Value recruits = found;
		for (const Value &unit_id : gd::items(state, array_value(recruit_keys))) {
			if (gd::to_int(state, ai::vget(state, recruits, unit_id, int_value(0))) > 0) {
				state.append(unit_ids, str(gd::stringify(state, unit_id)));
			}
		}
	}
	gd::sort_custom(state, unit_ids, [&state](const Value &a, const Value &b) {
		const int64_t tier_a = gd::int_field(state, gd::content_row(state, ContentTable::Unit, a.ref), key::tier, 0);
		const int64_t tier_b = gd::int_field(state, gd::content_row(state, ContentTable::Unit, b.ref), key::tier, 0);
		return tier_a == tier_b ? gd::text(state, a) < gd::text(state, b) : tier_a > tier_b;
	});
	const int64_t unit_count = state.array_size(unit_ids);
	for (int64_t at = 0; at < unit_count; ++at) {
		const Atom unit_id = state.at(unit_ids, at).ref;
		const int64_t available = gd::to_int(state, nested_get(state, town, key::available_recruits, unit_id, int_value(0)));
		const DictRef cost = enemy_turn_rules::_enemy_recruit_cost(state, town, unit_id);
		const DictRef spendable = gd::duplicate_dict(state, treasury);
		const ArrayRef reserve_keys = gd::keys(state, reserve);
		for (const Value &reserve_key : gd::items(state, array_value(reserve_keys))) {
			const int64_t held = gd::to_int(state, state.get(spendable, reserve_key, int_value(0)));
			const int64_t kept = gd::to_int(state, gd::index(state, reserve, reserve_key));
			state.set(spendable, reserve_key, int_value(compat::engine_max<int64_t>(0, gd::sub(held, kept))));
		}
		const int64_t count = _max_affordable_with_market(state, session, town, spendable, cost, available);
		if (count <= 0) {
			continue;
		}
		const DictRef additions = state.new_dict();
		state.set(additions, str(unit_id), int_value(count));
		DictRef plan = hero_command_rules::army_addition_plan(state, list_field(state, town, key::garrison), additions);
		if (!gd::bool_field(state, plan, key::ok, false)) {
			plan = _make_room(state, gd::as_array(list_field(state, town, key::garrison)), unit_id, count);
		}
		if (!gd::bool_field(state, plan, key::ok, false)) {
			continue;
		}
		const DictRef total = enemy_turn_rules::_scale_resource_pool(state, dict_value(cost), count);
		_market_cover(state, session, town, treasury, total, true);
		enemy_turn_rules::_spend_from_pool(state, treasury, dict_value(total));
		{
			const Atom controller = context_controller(state, context);
			const ArrayRef bought = state.new_array();
			const DictRef stack = state.new_dict();
			state.set(stack, str(key::unit_id), str(unit_id));
			state.set(stack, str(key::count), int_value(count));
			state.append(bought, dict_value(stack));
			const double power = empty_commander_power(state, array_value(bought));
			_economy_add(state, session, controller, key::recruited_power, power);
		}
		{
			const Atom controller = context_controller(state, context);
			_economy_add(state, session, controller, key::recruit_gold, gd::float_field(state, total, key::gold, 0.0));
		}
		{
			const Atom controller = context_controller(state, context);
			_economy_add(state, session, controller, key::dismissed_power, gd::float_field(state, plan, key::dismissed_power, 0.0));
		}
		state.set(town, str(key::garrison), list_field(state, plan, key::stacks));
		const DictRef consumed = enemy_turn_rules::_consume_recruits(state, map_field(state, town, key::available_recruits), unit_id, count);
		state.set(town, str(key::available_recruits), dict_value(consumed));
		const DictRef selected = state.new_dict();
		state.set(selected, str(key::unit_id), str(unit_id));
		const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
		state.set(selected, str(key::unit_label), str(gd::stringify(state, state.get(unit, str(key::name), str(unit_id)))));
		state.set(selected, str(key::recruit_count), int_value(count));
		const DictRef destination = state.new_dict();
		state.set(destination, str(key::type), str(key::garrison));
		state.set(destination, str(key::public_reason), str(key::the_garrison));
		state.set(destination, str(key::reason_codes), array_value(string_list(state, {key::garrison})));
		state.set(selected, str(key::destination), dict_value(destination));
		const DictRef event = enemy_turn_rules::ai_town_recruit_event(state, session, context_config(state, context), town, selected);
		if (!gd::is_empty(state, event)) {
			state.append(events, dict_value(event));
		}
	}
	state.set_at(towns, index, dict_value(town));
	state.set(session_view::overworld(state, session), str(key::towns), array_value(towns));
	return events;
}

DictRef _make_room(State &state, ArrayRef garrison, Atom unit_id, int64_t count) {
	const ArrayRef stacks = gd::deep_duplicate_array(state, garrison);
	int64_t weakest = -1;
	double weakest_power = std::numeric_limits<double>::infinity();
	const int64_t stack_count = state.array_size(stacks);
	for (int64_t index = 0; index < stack_count; ++index) {
		const ArrayRef single = state.new_array();
		state.append(single, state.at(stacks, index));
		const double stack_power = empty_commander_power(state, array_value(single));
		if (stack_power < weakest_power) {
			weakest = index;
			weakest_power = stack_power;
		}
	}
	if (weakest < 0) {
		const DictRef refused = state.new_dict();
		state.set(refused, str(key::ok), bool_value(false));
		return refused;
	}
	{
		const ArrayRef bought = state.new_array();
		const DictRef stack = state.new_dict();
		state.set(stack, str(key::unit_id), str(unit_id));
		state.set(stack, str(key::count), int_value(count));
		state.append(bought, dict_value(stack));
		if (weakest_power >= empty_commander_power(state, array_value(bought))) {
			const DictRef refused = state.new_dict();
			state.set(refused, str(key::ok), bool_value(false));
			return refused;
		}
	}
	gd::remove_at(state, stacks, weakest);
	const DictRef additions = state.new_dict();
	state.set(additions, str(unit_id), int_value(count));
	const DictRef plan = hero_command_rules::army_addition_plan(state, array_value(stacks), additions);
	state.set(plan, str(key::dismissed_power), float_value(weakest_power));
	return plan;
}

DictRef _take_garrison(State &state, DictRef session, DictRef entry, DictRef town, DictRef context, bool fresh_hire) {
	const DictRef town_result = _find_town(state, session, ai::string_or_empty(state, town, key::placement_id));
	const int64_t index = gd::int_field(state, town_result, key::index, -1);
	if (index < 0) {
		return entry;
	}
	const ArrayRef towns = array_field(state, session_view::overworld(state, session), key::towns);
	const DictRef live_town = gd::as_dict(state.at(towns, index));
	ArrayRef garrison = array_field_if(state, live_town, key::garrison);
	const DictRef army = dict_field(state, entry, key::enemy_army);
	ArrayRef stacks = array_field_if(state, army, key::stacks);
	const Atom main_id = _main_hero_id(state, session, context_controller(state, context));
	const bool is_main = main_id == key::empty || main_id == ai::string_or_empty(state, entry, key::placement_id);
	const ArrayRef field_ids = _field_hero_ids(state, session, context_controller(state, context));
	const bool is_field = gd::array_has(state, field_ids, str(ai::string_or_empty(state, entry, key::placement_id)));
	if (fresh_hire) {
		if (empty_commander_power(state, array_value(stacks)) <= 0.0 && state.array_size(garrison) != 0) {
			const int64_t weakest = _weakest_stack_index(state, garrison);
			const ArrayRef single = state.new_array();
			state.append(single, state.at(garrison, weakest));
			const DictRef moved = _merge_stacks_into(state, array_value(stacks), array_value(single));
			stacks = gd::as_array(state.get(moved, str(key::stacks), array_value(stacks)));
			if (ai::vempty(state, list_field(state, moved, key::left))) {
				gd::remove_at(state, garrison, weakest);
			}
		}
	} else if (is_main || is_field || _ferries_from(state, session, context, live_town, main_id)) {
		const double brought = empty_commander_power(state, array_value(stacks));
		if (state.array_size(garrison) != 0 && !_town_threatened(state, session, context, live_town)) {
			const DictRef pickup = _garrison_pickup(state, stacks, garrison);
			stacks = gd::as_array(gd::index(state, pickup, str(key::stacks)));
			garrison = gd::as_array(gd::index(state, pickup, str(key::left)));
		}
		const DictRef defended = _leave_defense(state, session, context, live_town, stacks, garrison, is_main, brought);
		stacks = gd::as_array(gd::index(state, defended, str(key::stacks)));
		garrison = gd::as_array(gd::index(state, defended, str(key::garrison)));
	} else if (state.array_size(stacks) > 1) {
		const int64_t keep = _weakest_stack_index(state, stacks);
		const ArrayRef leaving = state.new_array();
		const int64_t stack_count = state.array_size(stacks);
		for (int64_t stack_index = 0; stack_index < stack_count; ++stack_index) {
			if (stack_index != keep) {
				state.append(leaving, state.at(stacks, stack_index));
			}
		}
		const DictRef deposited = _merge_stacks_into(state, array_value(garrison), array_value(leaving));
		garrison = gd::as_array(state.get(deposited, str(key::stacks), array_value(garrison)));
		const ArrayRef kept = state.new_array();
		state.append(kept, state.at(stacks, keep));
		stacks = kept;
		ai::append_array(state, stacks, gd::as_array(list_field(state, deposited, key::left)));
	}
	state.set(army, str(key::stacks), array_value(stacks));
	state.set(entry, str(key::enemy_army), dict_value(army));
	state.set(live_town, str(key::garrison), array_value(garrison));
	DictRef commander = dict_field(state, entry, key::enemy_commander_state);
	const ArrayRef spell_ids = enemy_turn_rules::_enemy_town_accessible_spell_ids(state, live_town);
	for (int64_t at = 0; at < state.array_size(spell_ids); ++at) {
		const Atom spell_id = gd::stringify(state, state.at(spell_ids, at));
		const DictRef learned = spell_rules::learn_spell(state, commander, spell_id);
		if (gd::bool_field(state, learned, key::ok, false)) {
			commander = gd::as_dict(state.get(learned, str(key::hero), dict_value(commander)));
		}
	}
	const DictRef synced = enemy_adventure_rules::sync_commander_army_continuity(state, commander, map_field(state, entry, key::enemy_army), key::encounter_mire_raid);
	state.set(entry, str(key::enemy_commander_state), dict_value(synced));
	state.set_at(towns, index, dict_value(live_town));
	state.set(session_view::overworld(state, session), str(key::towns), array_value(towns));
	return entry;
}

void _avoid_target(State &state, DictRef session, Atom placement_id, Atom target_id, int64_t until_day) {
	const int64_t index = _entry_index(state, session, placement_id);
	if (index < 0 || target_id == key::empty) {
		return;
	}
	const DictRef entry = encounter_at(state, session, index);
	const DictRef block = dict_field(state, entry, key::ai_hero);
	const DictRef avoid = dict_field_if(state, block, key::avoid);
	const ArrayRef avoid_keys = gd::keys(state, avoid);
	const int64_t key_count = state.array_size(avoid_keys);
	for (int64_t at = 0; at < key_count; ++at) {
		const Value avoid_key = state.at(avoid_keys, at);
		if (gd::to_int(state, gd::index(state, avoid, avoid_key)) < session_day(state, session)) {
			state.erase(avoid, avoid_key);
		}
	}
	state.set(avoid, str(target_id), int_value(until_day));
	state.set(block, str(key::avoid), dict_value(avoid));
	state.set(block, str(key::goal), dict_value(state.new_dict()));
	state.set(entry, str(key::ai_hero), dict_value(block));
	_store_entry(state, session, index, entry);
}

// The main army's preview against a rival hero sets what that hero needs: lost
// or too dear, the main army's power and the power the rival keeps, times
// HERO_ATTACK_RATIO; looking good, nothing. _main_shortfall then calls the field
// armies, which the strength estimate alone would not (ai-match-3142897504: a
// main army of 37,800 lost three previews to a raider of 25,200 that the
// estimate rated beatable, while that raider beat 16 field heroes one by one).
void _note_vetoed_need(State &state, DictRef session, DictRef context, DictRef entry, DictRef plan, bool looks_good) {
	if (ai::string_or_empty(state, plan, key::kind) != key::ai_hero || !placement_is_main(state, session, context, entry)) {
		return;
	}
	const Atom target_id = ai::string_or_empty(state, plan, key::id);
	const int64_t index = _entry_index(state, session, ai::string_or_empty(state, entry, key::placement_id));
	if (index < 0 || target_id == key::empty) {
		return;
	}
	const DictRef live = encounter_at(state, session, index);
	const DictRef block = dict_field(state, live, key::ai_hero);
	const DictRef needs = dict_field_if(state, block, key::vetoed_needs);
	if (looks_good && !state.has(needs, str(target_id))) {
		return;
	}
	// Only rivals in sight or seen in the last few days keep a need.
	std::unordered_set<Atom> hostile;
	for (const Value &threat : gd::items(state, array_value(_hostile_heroes(state, session, context_controller(state, context))))) {
		hostile.insert(gd::stringify(state, ai::vmember(state, threat, key::id)));
	}
	for (const Value &threat : gd::items(state, array_value(_recent_hostiles(state, session, context)))) {
		hostile.insert(gd::stringify(state, ai::vmember(state, threat, key::id)));
	}
	const ArrayRef need_keys = gd::keys(state, needs);
	const int64_t key_count = state.array_size(need_keys);
	for (int64_t at = 0; at < key_count; ++at) {
		const Value need_key = state.at(need_keys, at);
		if (hostile.count(gd::stringify(state, need_key)) == 0) {
			state.erase(needs, need_key);
		}
	}
	if (looks_good) {
		state.erase(needs, str(target_id));
	} else {
		const DictRef outcome = dict_field_if(state, dict_field_if(state, context, key::fight_preview), key::outcome);
		const DictRef defender = encounter_at(state, session, gd::int_field(state, plan, key::index, -1));
		const double kept = army_power(state, list_field(state, outcome, key::enemy_survivors), map_field(state, defender, key::enemy_commander_state));
		state.set(needs, str(target_id), float_value((hero_power(state, live) + kept) * tunable(state, key::HERO_ATTACK_RATIO)));
	}
	if (gd::is_empty(state, needs)) {
		state.erase(block, str(key::vetoed_needs));
	} else {
		state.set(block, str(key::vetoed_needs), dict_value(needs));
	}
	state.set(live, str(key::ai_hero), dict_value(block));
	_store_entry(state, session, index, live);
}

int64_t _creature_total(State &state, const Value &stacks) {
	int64_t total = 0;
	if (gd::is_array(stacks)) {
		for (const Value &stack : gd::items(state, stacks)) {
			if (gd::is_dict(stack)) {
				total = gd::add(total, compat::engine_max<int64_t>(0, gd::int_field(state, stack.ref, key::count, 0)));
			}
		}
	}
	return total;
}

DictRef _free_fight(State &state, DictRef session, DictRef context, DictRef entry, DictRef search) {
	const DictRef block = dict_field(state, entry, key::ai_hero);
	const int64_t reach = gd::to_int(state, nested_get(state, block, key::movement, key::current, int_value(0)));
	const double power = hero_power(state, entry);
	if (reach <= 0 || power <= 0.0) {
		return state.new_dict();
	}
	const DictRef avoid = dict_field_if(state, block, key::avoid);
	const ArrayRef encounters = array_field(state, session_view::overworld(state, session), key::encounters);
	const ArrayRef dangers = _dangers(state, session, context, entry);
	const Vector2i size = context_size(state, context);
	const int64_t level = level_rules::level_of(state, dict_value(entry));
	const DictRef nearest = state.new_dict();
	const DictRef stops = dict_field(state, search, key::stops);
	for (const Value &tile_key : gd::items(state, dict_value(stops))) {
		const int64_t tile_index = gd::to_int(state, tile_key);
		const int64_t distance = search_distance(state, search, tile_index);
		if (distance > reach) {
			continue;
		}
		if (state.array_size(dangers) != 0) {
			const int64_t x = checked_mod(tile_index, size.x);
			const int64_t y = checked_div(tile_index, size.x);
			if (_in_danger(state, dangers, x, y, level)) {
				continue;
			}
		}
		for (const Value &ref : gd::items(state, gd::index(state, stops, tile_key))) {
			if (gd::to_int(state, ai::vmember(state, ref, key::kind)) != kStopEncounter) {
				continue;
			}
			const Value ref_index = int_value(gd::to_int(state, ai::vmember(state, ref, key::index)));
			Value prior;
			if (!state.lookup(nearest, ref_index, prior) || distance < gd::to_int(state, ai::vmember(state, prior, key::distance))) {
				const DictRef near = state.new_dict();
				state.set(near, str(key::tile_index), int_value(tile_index));
				state.set(near, str(key::distance), int_value(distance));
				state.set(nearest, ref_index, dict_value(near));
			}
		}
	}
	const ArrayRef options = state.new_array();
	for (const Value &index_key : gd::items(state, dict_value(nearest))) {
		const int64_t guard_index = gd::to_int(state, index_key);
		const DictRef guard = gd::as_dict(state.at(encounters, guard_index));
		const Atom guard_id = ai::string_or_empty(state, guard, key::placement_id);
		if (player_rules::raid_controller_id(state, guard) != key::empty || gd::to_int(state, state.get(avoid, str(guard_id), int_value(-1))) >= session_day(state, session)) {
			continue;
		}
		const double guard_power = _guard_power(state, guard);
		if (guard_power <= 0.0 || guard_power > power * tunable(state, key::FREE_FIGHT_MAX_RATIO)) {
			continue;
		}
		const Value near = gd::index(state, nearest, index_key);
		const DictRef option = state.new_dict();
		state.set(option, str(key::kind), str(key::encounter));
		state.set(option, str(key::id), str(guard_id));
		state.set(option, str(key::index), int_value(guard_index));
		state.set(option, str(key::tile_index), int_value(gd::to_int(state, ai::vmember(state, near, key::tile_index))));
		state.set(option, str(key::distance), int_value(gd::to_int(state, ai::vmember(state, near, key::distance))));
		state.set(option, str(key::fight_power), float_value(guard_power));
		state.append(options, dict_value(option));
	}
	if (state.array_size(options) == 0) {
		return state.new_dict();
	}
	gd::sort_custom(state, options, [&state](const Value &a, const Value &b) {
		return gd::to_int(state, ai::vmember(state, a, key::distance)) < gd::to_int(state, ai::vmember(state, b, key::distance));
	});
	if (!state.has(context, str(key::costly_fights))) {
		state.set(context, str(key::costly_fights), dict_value(state.new_dict()));
	}
	const DictRef costly = gd::as_dict(gd::index(state, context, str(key::costly_fights)));
	const DictRef needs = _resource_needs(state, session, context);
	const ArrayRef stacks = gd::as_array(nested_list(state, entry, key::enemy_army, key::stacks));
	const int64_t army_key = gd::hash(state, array_value(stacks));
	int64_t previews = 0;
	// A host call (the preview battle) runs in this loop: read by index.
	for (int64_t at = 0; at < state.array_size(options); ++at) {
		const DictRef option = gd::as_dict(state.at(options, at));
		if (previews >= tunable_int(state, key::MAX_FREE_FIGHT_PREVIEWS)) {
			break;
		}
		const Atom costly_key = gd::format(state, key::s_s_d, {str(ai::string_or_empty(state, entry, key::placement_id)), str(gd::stringify(state, gd::index(state, option, str(key::id)))), int_value(army_key)});
		if (state.has(costly, str(costly_key))) {
			continue;
		}
		const int64_t option_index = gd::to_int(state, gd::index(state, option, str(key::index)));
		const double value = _guard_fight_value(state, session, context, entry, option_index, power, needs, search);
		if (std::isnan(value)) {
			continue;
		}
		previews += 1;
		const DictRef guard = gd::as_dict(state.at(encounters, gd::to_int(state, gd::index(state, option, str(key::index)))));
		const int64_t battle_number = gd::add(gd::int_field(state, context, key::auto_battle_count, 0), 1);
		state.set(context, str(key::preview_count), int_value(gd::add(gd::int_field(state, context, key::preview_count, 0), 1)));
		const int64_t started = gd::ticks_usec();
		const int64_t stop_below = _creature_total(state, array_value(stacks));
		const DictRef outcome = _simulate_battle(state, session, context, entry, guard, battle_number, stop_below);
		_profile_add(state, context, key::preview_ms, started);
		if (gd::bool_field(state, outcome, key::won, false)) {
			const int64_t survivors = _creature_total(state, list_field(state, outcome, key::hero_survivors));
			if (survivors >= _creature_total(state, array_value(stacks))) {
				const DictRef preview = state.new_dict();
				state.set(preview, str(key::key), str(_battle_key(state, entry, guard, battle_number)));
				state.set(preview, str(key::outcome), dict_value(outcome));
				state.set(context, str(key::fight_preview), dict_value(preview));
				const double loss = _expected_loss_value(state, power, gd::to_float(gd::index(state, option, str(key::fight_power))));
				state.set(option, str(key::value), float_value(value + loss));
				return option;
			}
		}
		state.set(costly, str(costly_key), bool_value(true));
	}
	return state.new_dict();
}

bool _gate_fight_looks_good(State &state, DictRef session, DictRef context, DictRef entry, DictRef plan) {
	DictRef fight = plan;
	if (gd::stringify(state, gd::index(state, plan, str(key::kind))) == key::gate) {
		if (!state.has(plan, str(key::far_guard))) {
			return true;
		}
		const double far_power = gd::to_float(gd::index(state, plan, str(key::far_fight_power)));
		fight = state.new_dict();
		state.set(fight, str(key::kind), str(key::encounter));
		state.set(fight, str(key::index), int_value(gd::to_int(state, gd::index(state, plan, str(key::far_guard)))));
		state.set(fight, str(key::value), float_value(gd::to_float(gd::index(state, plan, str(key::value)))));
		state.set(fight, str(key::fight_power), float_value(far_power));
		const double own_power = hero_power(state, entry);
		state.set(fight, str(key::estimated_loss), float_value(_expected_loss_value(state, own_power, far_power)));
	}
	if (_fight_looks_good(state, session, context, entry, fight, false)) {
		return true;
	}
	const Atom placement_id = ai::string_or_empty(state, entry, key::placement_id);
	const Atom target_id = gd::stringify(state, gd::index(state, plan, str(key::id)));
	const int64_t until_day = gd::add(session_day(state, session), tunable_int(state, key::AVOID_DAYS));
	_avoid_target(state, session, placement_id, target_id, until_day);
	return false;
}

DictRef _cornered_fight(State &state, DictRef session, DictRef entry, DictRef search, DictRef context) {
	if (gd::int_field(state, search, key::order_count, 0) > 1 && (gd::bool_field(state, search, key::capped, true) || _home_reachable(state, session, context, entry, search))) {
		return state.new_dict();
	}
	const double power = hero_power(state, entry);
	const ArrayRef encounters = array_field(state, session_view::overworld(state, session), key::encounters);
	const DictRef stops = dict_field(state, search, key::stops);
	DictRef best = state.new_dict();
	for (const Value &tile_key : gd::items(state, dict_value(stops))) {
		const int64_t tile_index = gd::to_int(state, tile_key);
		for (const Value &ref : gd::items(state, gd::index(state, stops, tile_key))) {
			if (gd::to_int(state, ai::vmember(state, ref, key::kind)) != kStopEncounter) {
				continue;
			}
			const int64_t ref_index = gd::to_int(state, ai::vmember(state, ref, key::index));
			const DictRef guard = gd::as_dict(state.at(encounters, ref_index));
			const Value fallback_id = state.get(guard, str(key::id), str(key::empty));
			const Atom encounter_id = gd::stringify(state, state.get(guard, str(key::encounter_id), fallback_id));
			const DictRef encounter_template = gd::content_row(state, ContentTable::Encounter, encounter_id);
			const Value guard_stacks = list_field(state, _neutral_army(state, guard), key::stacks);
			const Value guard_commander = map_field(state, encounter_template, key::enemy_commander);
			const double guard_power = army_power(state, guard_stacks, guard_commander);
			if (guard_power <= 0.0 || power < guard_power) {
				continue;
			}
			bool better = gd::is_empty(state, best) || guard_power < gd::to_float(gd::index(state, best, str(key::fight_power)));
			if (!better && gd::is_equal_approx(guard_power, gd::to_float(gd::index(state, best, str(key::fight_power))))) {
				better = search_distance(state, search, tile_index) < gd::to_int(state, gd::index(state, best, str(key::distance)));
			}
			if (better) {
				best = state.new_dict();
				state.set(best, str(key::kind), str(key::encounter));
				state.set(best, str(key::id), str(ai::string_or_empty(state, guard, key::placement_id)));
				state.set(best, str(key::index), int_value(gd::to_int(state, ai::vmember(state, ref, key::index))));
				state.set(best, str(key::value), float_value(1.0));
				state.set(best, str(key::tile_index), int_value(tile_index));
				state.set(best, str(key::distance), int_value(search_distance(state, search, tile_index)));
				state.set(best, str(key::fight_power), float_value(guard_power));
			}
		}
	}
	return best;
}

bool _home_reachable(State &state, DictRef session, DictRef context, DictRef entry, DictRef search) {
	const Value fallback_controller = str(player_rules::raid_controller_id(state, entry));
	const Atom controller = gd::stringify(state, state.get(context, str(key::controller), fallback_controller));
	const Vector2i size = state.has(context, str(key::map_size)) ? context_size(state, context) : overworld_rules::derive_map_size(state, session);
	const DictRef doors = _own_town_doors(state, session, controller, level_rules::level_of(state, dict_value(entry)), size);
	if (gd::is_empty(state, doors)) {
		return true;
	}
	Value found;
	const PackedRef dist = state.lookup(search, str(key::dist), found) ? gd::as_ints(found) : gd::new_ints(state);
	for (const Value &door : gd::items(state, dict_value(doors))) {
		const int64_t door_index = gd::to_int(state, door);
		if (door_index < gd::packed_size(state, dist) && gd::packed_int(state, dist, door_index) >= 0) {
			return true;
		}
	}
	return false;
}

DictRef _idle_fight(State &state, DictRef session, DictRef context, DictRef entry, DictRef search) {
	DictRef avoid = 0;
	{
		Value block;
		Value found;
		if (state.lookup(entry, str(key::ai_hero), block)) {
			found = ai::vget(state, block, key::avoid);
		}
		avoid = gd::is_dict(found) ? found.ref : state.new_dict();
	}
	const double power = hero_power(state, entry);
	const DictRef needs = _resource_needs(state, session, context);
	const ArrayRef encounters = array_field(state, session_view::overworld(state, session), key::encounters);
	const DictRef nearest = state.new_dict();
	const DictRef stops = dict_field(state, search, key::stops);
	for (const Value &tile_key : gd::items(state, dict_value(stops))) {
		for (const Value &ref : gd::items(state, gd::index(state, stops, tile_key))) {
			if (gd::to_int(state, ai::vmember(state, ref, key::kind)) != kStopEncounter) {
				continue;
			}
			const int64_t tile_index = gd::to_int(state, tile_key);
			const int64_t distance = search_distance(state, search, tile_index);
			const Value ref_index = int_value(gd::to_int(state, ai::vmember(state, ref, key::index)));
			Value prior;
			if (!state.lookup(nearest, ref_index, prior) || distance < gd::to_int(state, ai::vmember(state, prior, key::distance))) {
				const DictRef near = state.new_dict();
				state.set(near, str(key::tile_index), int_value(tile_index));
				state.set(near, str(key::distance), int_value(distance));
				state.set(nearest, ref_index, dict_value(near));
			}
		}
	}
	const ArrayRef options = state.new_array();
	for (const Value &index_key : gd::items(state, dict_value(nearest))) {
		const int64_t guard_index = gd::to_int(state, index_key);
		const DictRef guard = gd::as_dict(state.at(encounters, guard_index));
		if (gd::to_int(state, state.get(avoid, str(ai::string_or_empty(state, guard, key::placement_id)), int_value(-1))) >= session_day(state, session)) {
			continue;
		}
		const double value = _guard_fight_value(state, session, context, entry, guard_index, power, needs, search);
		if (std::isnan(value)) {
			continue;
		}
		const double guard_power = _guard_power(state, guard);
		const Value near = gd::index(state, nearest, index_key);
		const DictRef option = state.new_dict();
		state.set(option, str(key::kind), str(key::encounter));
		state.set(option, str(key::id), str(ai::string_or_empty(state, guard, key::placement_id)));
		state.set(option, str(key::index), int_value(guard_index));
		state.set(option, str(key::value), float_value(value));
		state.set(option, str(key::tile_index), int_value(gd::to_int(state, ai::vmember(state, near, key::tile_index))));
		state.set(option, str(key::distance), int_value(gd::to_int(state, ai::vmember(state, near, key::distance))));
		state.set(option, str(key::fight_power), float_value(guard_power));
		state.set(option, str(key::estimated_loss), float_value(_expected_loss_value(state, power, guard_power)));
		state.append(options, dict_value(option));
	}
	const double distance_cost = tunable(state, key::IDLE_FIGHT_DISTANCE_COST);
	gd::sort_custom(state, options, [&state, distance_cost](const Value &a, const Value &b) {
		const double a_cost = gd::to_float(ai::vmember(state, a, key::distance)) * distance_cost;
		const double a_score = gd::to_float(ai::vmember(state, a, key::value)) - a_cost;
		const double b_cost = gd::to_float(ai::vmember(state, b, key::distance)) * distance_cost;
		const double b_score = gd::to_float(ai::vmember(state, b, key::value)) - b_cost;
		return a_score > b_score;
	});
	const ArrayRef previewed = gd::slice(state, options, 0, tunable_int(state, key::MAX_IDLE_PREVIEWS));
	// A host call (the preview battle) runs in this loop: read by index.
	for (int64_t at = 0; at < state.array_size(previewed); ++at) {
		const DictRef option = gd::as_dict(state.at(previewed, at));
		if (_fight_looks_good(state, session, context, entry, option, true)) {
			return option;
		}
		const Atom placement_id = ai::string_or_empty(state, entry, key::placement_id);
		const Atom target_id = gd::stringify(state, gd::index(state, option, str(key::id)));
		const int64_t until_day = gd::add(session_day(state, session), tunable_int(state, key::AVOID_DAYS));
		_avoid_target(state, session, placement_id, target_id, until_day);
	}
	return state.new_dict();
}

void _forget_sighting(State &state, DictRef context, Atom id) {
	const Value known = ai::vget(state, gd::index(state, context, str(key::state)), key::ai_sightings);
	if (gd::is_dict(known) && state.has(known.ref, str(id))) {
		state.erase(known.ref, str(id));
	}
}

DictRef _claim_resource(State &state, DictRef session, DictRef context, int64_t index, DictRef plan) {
	const Atom controller = context_controller(state, context);
	DictRef entry = encounter_at(state, session, index);
	ArrayRef nodes = array_field(state, session_view::overworld(state, session), key::resource_nodes);
	const int64_t node_index = gd::int_field(state, plan, key::index, -1);
	if (node_index < 0 || node_index >= state.array_size(nodes)) {
		return arrived_result(state);
	}
	DictRef node = gd::as_dict(state.at(nodes, node_index));
	const DictRef site = resource_node_payload_rules::site_for_node(state, node, state.new_dict());
	const ArrayRef events = state.new_array();
	if (creature_dwelling_rules::is_dwelling(state, site) && creature_dwelling_rules::guard_blocks(state, node, site, controller, session_day(state, session))) {
		const ArrayRef guard_stacks = creature_dwelling_rules::guard_stacks(state, node, site, controller, session_day(state, session));
		const DictRef defender = state.new_dict();
		state.set(defender, str(key::placement_id), str(creature_dwelling_rules::guard_key(state, ai::string_or_empty(state, node, key::placement_id))));
		state.set(defender, str(key::encounter_id), str(key::encounter_dwelling_guard));
		const DictRef guard_army = state.new_dict();
		state.set(guard_army, str(key::id), str(key::dwelling_guard_2));
		state.set(guard_army, str(key::name), str(key::dwelling_guard));
		state.set(guard_army, str(key::stacks), array_value(guard_stacks));
		state.set(defender, str(key::enemy_army), dict_value(guard_army));
		const DictRef fight = _auto_resolve(state, session, context, index, defender);
		ai::append_array(state, events, gd::as_array(list_field(state, fight, key::events)));
		node = resource_node_at(state, session, node_index);
		const ArrayRef survivors = gd::as_array(list_field(state, fight, key::enemy_survivors));
		creature_dwelling_rules::record_guard_result(state, node, controller, survivors, gd::bool_field(state, fight, key::won, false), session_day(state, session));
		nodes = array_field(state, session_view::overworld(state, session), key::resource_nodes);
		state.set_at(nodes, node_index, dict_value(node));
		state.set(session_view::overworld(state, session), str(key::resource_nodes), array_value(nodes));
		if (!gd::bool_field(state, fight, key::won, false)) {
			return arrived_events(state, array_value(events));
		}
		entry = encounter_at(state, session, index);
	}
	const bool was_present = overworld_rules::resource_node_is_present(state, node, site);
	const DictRef node_before = gd::deep_duplicate_dict(state, node);
	const Value army_before = gd::duplicate_value(state, map_field(state, entry, key::enemy_army), true);
	const DictRef actor = gd::deep_duplicate_dict(state, entry);
	state.set(actor, str(key::target_kind), str(key::resource));
	state.set(actor, str(key::target_placement_id), str(ai::string_or_empty(state, node, key::placement_id)));
	const DictRef enemy_state = gd::as_dict(gd::index(state, context, str(key::state)));
	const DictRef result = enemy_adventure_rules::_secure_resource_target(state, session, actor, enemy_state, controller, context_config(state, context));
	const DictRef updated = gd::as_dict(state.get(result, str(key::encounter), dict_value(actor)));
	Value found;
	state.set(entry, str(key::enemy_army), state.lookup(updated, str(key::enemy_army), found) ? found : map_field(state, entry, key::enemy_army));
	DictRef commander = gd::as_dict(state.lookup(updated, str(key::enemy_commander_state), found) ? found : map_field(state, entry, key::enemy_commander_state));
	const DictRef claimed = resource_node_at(state, session, node_index);
	// A chart the side paid for shows it the whole level.
	if (visit_building_rules::is_visit_building(state, site) && visit_building_rules::reveals_level(state, site) && !gd::equal(state, dict_value(claimed), dict_value(node_before))) {
		_reveal_level(state, session, context, level_rules::level_of(state, dict_value(claimed)));
	}
	const int64_t experience = gd::int_field(state, enemy_adventure_rules::_resource_site_claim_rewards(state, site), key::experience, 0);
	if (experience > 0 && !gd::equal(state, dict_value(claimed), dict_value(node_before))) {
		const DictRef added = hero_progression_rules::add_experience(state, commander, experience);
		commander = enemy_adventure_rules::_normalize_enemy_progression(state, gd::as_dict(state.get(added, str(key::hero), dict_value(commander))));
	}
	state.set(entry, str(key::enemy_commander_state), dict_value(commander));
	_store_entry(state, session, index, entry);
	const bool opened = !gd::equal(state, list_field(state, node_before, key::package_block_tiles), list_field(state, claimed, key::package_block_tiles));
	if (was_present && (opened || !overworld_rules::resource_node_is_present(state, claimed, site))) {
		_clear_static_body(state, session, context, node_before);
	}
	ai::append_array(state, events, gd::as_array(list_field(state, result, key::ai_events)));
	const Value ai_event = map_field(state, result, key::ai_event);
	if (gd::is_dict(ai_event) && !gd::is_empty(state, ai_event.ref) && ai::vempty(state, list_field(state, result, key::ai_events))) {
		state.append(events, map_field(state, result, key::ai_event));
	}
	bool acted = state.array_size(events) != 0 || !gd::equal(state, dict_value(claimed), dict_value(node_before));
	if (!acted) {
		acted = !gd::equal(state, map_field(state, entry, key::enemy_army), army_before);
	}
	const DictRef claim_result = arrived_events(state, array_value(events));
	state.set(claim_result, str(key::acted), bool_value(acted));
	return claim_result;
}

void _clear_static_body(State &state, DictRef session, DictRef context, DictRef node) {
	state.set(context, str(key::topology_changed), bool_value(true));
	const int64_t level = level_rules::level_of(state, dict_value(node));
	if (!ai::vhas(state, gd::index(state, context, str(key::levels)), int_value(level))) {
		return;
	}
	const DictRef surface = gd::as_dict(ai::vindex(state, gd::index(state, context, str(key::levels)), int_value(level)));
	const Vector2i size = context_size(state, context);
	overworld_rules::Tiles tiles;
	Value package_mask;
	if (state.lookup(node, str(key::package_block_tiles), package_mask) && gd::is_array(package_mask)) {
		tiles = overworld_rules::_world_tiles_from_payload_array(state, package_mask);
	} else {
		tiles = overworld_rules::_map_object_world_body_tiles(state, overworld_rules::_map_object_for_resource_node(state, node), node);
	}
	const PackedRef blocked = gd::as_bytes(gd::index(state, surface, str(key::blocked)));
	for (const Vector2i tile : tiles) {
		if (tile.x >= 0 && tile.y >= 0 && tile.x < size.x && tile.y < size.y) {
			const ArrayRef rows = level_rules::terrain_rows(state, dict_value(session), level);
			const Value row = state.at(rows, tile.y);
			const Atom terrain = gd::stringify(state, ai::vindex(state, row, int_value(tile.x)));
			const int64_t cell = static_cast<int64_t>(tile.y) * static_cast<int64_t>(size.x) + static_cast<int64_t>(tile.x);
			gd::packed_set(state, blocked, cell, overworld_rules::terrain_id_is_passable(state, terrain) ? 0 : 1);
		}
	}
	state.set(surface, str(key::blocked), gd::bytes_value(blocked));
	state.erase(surface, str(key::open_zones));
}

DictRef _take_artifact(State &state, DictRef session, DictRef context, int64_t index, DictRef plan) {
	const Atom controller = context_controller(state, context);
	const DictRef entry = encounter_at(state, session, index);
	const ArrayRef nodes = array_field(state, session_view::overworld(state, session), key::artifact_nodes);
	const int64_t node_index = gd::int_field(state, plan, key::index, -1);
	if (node_index < 0 || node_index >= state.array_size(nodes) || gd::to_bool(ai::vget(state, state.at(nodes, node_index), key::collected, bool_value(false)))) {
		return arrived_result(state);
	}
	const DictRef node = gd::as_dict(state.at(nodes, node_index));
	state.set(node, str(key::collected), bool_value(true));
	player_rules::set_resource_controller(state, node, dict_value(session), controller);
	state.set(node, str(key::collected_day), int_value(session_day(state, session)));
	state.set_at(nodes, node_index, dict_value(node));
	state.set(session_view::overworld(state, session), str(key::artifact_nodes), array_value(nodes));
	const Atom artifact_id = ai::string_or_empty(state, node, key::artifact_id);
	const DictRef commander = dict_field(state, entry, key::enemy_commander_state);
	const DictRef claim = artifact_rules::claim_artifact(state, commander, artifact_id, key::Found, true);
	if (gd::bool_field(state, claim, key::ok, false)) {
		state.set(entry, str(key::enemy_commander_state), state.get(claim, str(key::hero), dict_value(commander)));
	}
	_store_entry(state, session, index, entry);
	state.set(context, str(key::topology_changed), bool_value(true));
	overworld_turn_playback::action(state, dict_value(session), entry, key::picks_up_an_artifact);
	const Atom label = artifact_rules::describe_artifact(state, artifact_id);
	const DictRef target = event_target(state, key::artifact, ai::string_or_empty(state, node, key::placement_id), label, gd::int_field(state, node, key::x, 0), gd::int_field(state, node, key::y, 0));
	const Atom summary = gd::format(state, key::s_picks_up_s, {str(hero_name(state, entry)), str(label)});
	const DictRef event = _event(state, session, context, key::ai_artifact_secured, entry, target, summary, string_list(state, {key::artifact_secured}));
	const ArrayRef events = state.new_array();
	state.append(events, dict_value(event));
	return arrived_events(state, array_value(events));
}

DictRef _fight_neutral(State &state, DictRef session, DictRef context, int64_t index, DictRef plan) {
	ArrayRef encounters = array_field(state, session_view::overworld(state, session), key::encounters);
	const int64_t guard_index = gd::int_field(state, plan, key::index, -1);
	if (guard_index < 0 || guard_index >= state.array_size(encounters)) {
		return arrived_result(state);
	}
	DictRef guard = gd::as_dict(state.at(encounters, guard_index));
	if (_is_resolved(state, session, ai::string_or_empty(state, guard, key::placement_id))) {
		return arrived_result(state);
	}
	const DictRef fight = _auto_resolve(state, session, context, index, guard);
	const ArrayRef events = gd::as_array(list_field(state, fight, key::events));
	encounters = array_field(state, session_view::overworld(state, session), key::encounters);
	guard = gd::as_dict(state.at(encounters, guard_index));
	if (gd::bool_field(state, fight, key::won, false)) {
		_mark_resolved(state, session, ai::string_or_empty(state, guard, key::placement_id));
		state.set(context, str(key::topology_changed), bool_value(true));
	} else {
		const DictRef army = gd::deep_duplicate_dict(state, _neutral_army(state, guard));
		Value survivors;
		if (!state.lookup(fight, str(key::enemy_survivors), survivors)) {
			survivors = list_field(state, army, key::stacks);
		}
		state.set(army, str(key::stacks), survivors);
		state.set(guard, str(key::enemy_army), dict_value(army));
		state.set_at(encounters, guard_index, dict_value(guard));
		state.set(session_view::overworld(state, session), str(key::encounters), array_value(encounters));
		const Value hero = ai::vindex(state, gd::index(state, session_view::overworld(state, session), str(key::encounters)), int_value(index));
		const Atom hero_id = gd::stringify(state, ai::vget(state, hero, key::placement_id, str(key::empty)));
		if (!_is_resolved(state, session, hero_id)) {
			_step_back_from_guard(state, session, index, plan);
			const Atom guard_id = ai::string_or_empty(state, guard, key::placement_id);
			const int64_t until_day = gd::add(session_day(state, session), tunable_int(state, key::AVOID_DAYS));
			_avoid_target(state, session, hero_id, guard_id, until_day);
		}
	}
	return arrived_events(state, array_value(events));
}

void _step_back_from_guard(State &state, DictRef session, int64_t index, DictRef plan) {
	const Value retreat = state.get(plan, str(key::retreat_tile), Value());
	if (!gd::is_vector2i(retreat)) {
		return;
	}
	const Vector2i tile = as_vector2i(retreat);
	const DictRef entry = gd::as_dict(ai::vindex(state, gd::index(state, session_view::overworld(state, session), str(key::encounters)), int_value(index)));
	if (tile.x == gd::int_field(state, entry, key::x, 0) && tile.y == gd::int_field(state, entry, key::y, 0)) {
		return;
	}
	if (_tile_blocked_for_standing(state, session, state.new_dict(), tile, overworld_level_rules::level_of(state, dict_value(entry)), ai::string_or_empty(state, entry, key::placement_id))) {
		return;
	}
	const DictRef before = overworld_level_rules::position(state, entry);
	state.set(entry, str(key::x), int_value(tile.x));
	state.set(entry, str(key::y), int_value(tile.y));
	overworld_turn_playback::move(state, dict_value(session), entry, before);
	_store_entry(state, session, index, entry);
	overworld_rules::invalidate_spatial_lookup(state, session);
}

DictRef _fight_ai_hero(State &state, DictRef session, DictRef context, int64_t index, DictRef plan) {
	ArrayRef encounters = array_field(state, session_view::overworld(state, session), key::encounters);
	const int64_t other_index = gd::int_field(state, plan, key::index, -1);
	if (other_index < 0 || other_index >= state.array_size(encounters)) {
		return arrived_result(state);
	}
	DictRef other = gd::as_dict(state.at(encounters, other_index));
	const DictRef fight = _auto_resolve(state, session, context, index, other);
	encounters = array_field(state, session_view::overworld(state, session), key::encounters);
	other = gd::as_dict(state.at(encounters, other_index));
	const Atom other_controller = player_rules::raid_controller_id(state, other);
	if (gd::bool_field(state, fight, key::won, false)) {
		_mark_resolved(state, session, ai::string_or_empty(state, other, key::placement_id));
		_record_hero_defeat(state, session, other_controller, other);
		_forget_sighting(state, context, ai::string_or_empty(state, other, key::placement_id));
	} else {
		const DictRef army = dict_field(state, other, key::enemy_army);
		Value survivors;
		if (!state.lookup(fight, str(key::enemy_survivors), survivors)) {
			survivors = list_field(state, army, key::stacks);
		}
		state.set(army, str(key::stacks), survivors);
		state.set(other, str(key::enemy_army), dict_value(army));
		state.set_at(encounters, other_index, dict_value(other));
		state.set(session_view::overworld(state, session), str(key::encounters), array_value(encounters));
	}
	return arrived_events(state, list_field(state, fight, key::events));
}

DictRef _meet_hero(State &state, DictRef session, DictRef context, int64_t index, DictRef plan) {
	const int64_t other_index = _entry_index(state, session, ai::string_or_empty(state, plan, key::id));
	if (other_index < 0 || _is_resolved(state, session, ai::string_or_empty(state, plan, key::id))) {
		return arrived_result(state);
	}
	const ArrayRef encounters = array_field(state, session_view::overworld(state, session), key::encounters);
	const DictRef entry = gd::as_dict(state.at(encounters, index));
	const DictRef other = gd::as_dict(state.at(encounters, other_index));
	if (!level_rules::same_level(state, dict_value(entry), dict_value(other))) {
		return arrived_result(state);
	}
	const int64_t dx = compat::absi(gd::sub(gd::int_field(state, entry, key::x, 0), gd::int_field(state, other, key::x, 0)));
	const int64_t dy = compat::absi(gd::sub(gd::int_field(state, entry, key::y, 0), gd::int_field(state, other, key::y, 0)));
	if (compat::engine_max(dx, dy) > 1) {
		return arrived_result(state);
	}
	const DictRef army = dict_field_if(state, entry, key::enemy_army);
	const DictRef other_army = dict_field_if(state, other, key::enemy_army);
	// The armies are pooled: the hero met ends with the strongest seven stacks
	// of both, the one that came with the rest (at least one creature).
	const ArrayRef theirs = gd::as_array(gd::duplicate_value(state, list_field(state, other_army, key::stacks), true));
	const ArrayRef ours = gd::as_array(gd::duplicate_value(state, list_field(state, army, key::stacks), true));
	const DictRef swap = _garrison_pickup(state, theirs, ours);
	if (gd::to_float(gd::index(state, swap, str(key::gain))) <= 0.0) {
		return arrived_result(state);
	}
	const DictRef merged = state.new_dict();
	state.set(merged, str(key::stacks), gd::index(state, swap, str(key::stacks)));
	ArrayRef kept = gd::as_array(gd::index(state, swap, str(key::left)));
	if (state.array_size(kept) == 0) {
		// One creature of the weakest stack that has more than one; with only
		// single creatures left, the weakest of them.
		const ArrayRef stacks = gd::as_array(gd::index(state, merged, str(key::stacks)));
		const ArrayRef several = state.new_array();
		for (const Value &stack : gd::items(state, array_value(stacks))) {
			if (gd::int_field(state, stack.ref, key::count, 0) > 1) {
				state.append(several, stack);
			}
		}
		kept = state.new_array();
		if (state.array_size(several) != 0) {
			const DictRef stack = gd::as_dict(state.at(several, _weakest_stack_index(state, several)));
			state.set(stack, str(key::count), int_value(gd::sub(gd::to_int(state, gd::index(state, stack, str(key::count))), 1)));
			const DictRef one = state.new_dict();
			state.set(one, str(key::unit_id), str(ai::string_or_empty(state, stack, key::unit_id)));
			state.set(one, str(key::count), int_value(1));
			state.append(kept, dict_value(one));
		} else if (state.array_size(stacks) > 1) {
			const int64_t weakest = _weakest_stack_index(state, stacks);
			state.append(kept, state.at(stacks, weakest));
			gd::remove_at(state, stacks, weakest);
		}
	}
	state.set(army, str(key::stacks), array_value(kept));
	state.set(entry, str(key::enemy_army), dict_value(army));
	{
		const DictRef commander = dict_field(state, entry, key::enemy_commander_state);
		state.set(entry, str(key::enemy_commander_state), dict_value(enemy_adventure_rules::sync_commander_army_continuity(state, commander, dict_value(army), key::encounter_mire_raid)));
	}
	state.set(other_army, str(key::stacks), gd::index(state, merged, str(key::stacks)));
	state.set(other, str(key::enemy_army), dict_value(other_army));
	{
		const DictRef commander = dict_field(state, other, key::enemy_commander_state);
		state.set(other, str(key::enemy_commander_state), dict_value(enemy_adventure_rules::sync_commander_army_continuity(state, commander, dict_value(other_army), key::encounter_mire_raid)));
	}
	const DictRef block = dict_field(state, entry, key::ai_hero);
	state.set(block, str(key::goal), dict_value(state.new_dict()));
	state.set(entry, str(key::ai_hero), dict_value(block));
	state.set_at(encounters, index, dict_value(entry));
	state.set_at(encounters, other_index, dict_value(other));
	state.set(session_view::overworld(state, session), str(key::encounters), array_value(encounters));
	const DictRef target = event_target(state, key::encounter, ai::string_or_empty(state, other, key::placement_id), hero_name(state, other), gd::int_field(state, other, key::x, 0), gd::int_field(state, other, key::y, 0));
	state.set(target, str(key::target_public_importance), str(key::low));
	const Atom summary = gd::format(state, key::s_hands_troops_to_s, {str(hero_name(state, entry)), str(hero_name(state, other))});
	const DictRef event = _event(state, session, context, key::ai_heroes_met, entry, target, summary, string_list(state, {key::troops_handed_over}));
	const ArrayRef events = state.new_array();
	state.append(events, dict_value(event));
	const DictRef result = arrived_result(state);
	state.set(result, str(key::acted), bool_value(true));
	state.set(result, str(key::events), array_value(events));
	return result;
}

// A town's garrison as the defender of an auto-resolved battle.
static DictRef _garrison_defender(State &state, DictRef town, Atom owner, const Value &garrison) {
	const DictRef defender = state.new_dict();
	state.set(defender, str(key::placement_id), str(gd::format(state, key::town_garrison_s, {str(ai::string_or_empty(state, town, key::placement_id))})));
	state.set(defender, str(key::encounter_id), str(key::encounter_mire_raid));
	const DictRef garrison_army = state.new_dict();
	state.set(garrison_army, str(key::id), str(key::town_garrison));
	state.set(garrison_army, str(key::name), str(gd::format(state, key::s_garrison, {str(enemy_turn_rules::_town_name(state, town))})));
	state.set(garrison_army, str(key::stacks), garrison);
	state.set(defender, str(key::enemy_army), dict_value(garrison_army));
	const Atom log_owner = owner == key::enemy ? player_rules::town_controller_id(state, town) : owner;
	state.set(defender, str(key::battle_log_owner), str(log_owner));
	return defender;
}

DictRef _attack_town(State &state, DictRef session, DictRef context, int64_t index, DictRef plan) {
	const Atom controller = context_controller(state, context);
	ArrayRef towns = array_field(state, session_view::overworld(state, session), key::towns);
	const int64_t town_index = gd::int_field(state, plan, key::index, -1);
	if (town_index < 0 || town_index >= state.array_size(towns)) {
		return arrived_result(state);
	}
	DictRef town = gd::as_dict(state.at(towns, town_index));
	const Atom owner = gd::stringify(state, state.get(town, str(key::owner), str(key::neutral)));
	if (owner == key::player) {
		const DictRef force = hero_command_rules::town_defense_force(state, session, town);
		const DictRef entry_hero = gd::as_dict(gd::index(state, force, str(key::hero)));
		if (!gd::bool_field(state, force, key::fits, true) && !gd::is_empty(state, entry_hero)) {
			// The hero on the entry and the garrison need more than the battle's seven
			// slots: the hero is fought first, the garrison on a later attack.
			const ArrayRef heroes = array_field(state, session_view::overworld(state, session), key::player_heroes);
			for (int64_t at = 0; at < state.array_size(heroes); ++at) {
				if (ai::string_or_empty(state, gd::as_dict(state.at(heroes, at)), key::id) == ai::string_or_empty(state, entry_hero, key::id)) {
					const DictRef hero_plan = state.new_dict();
					state.set(hero_plan, str(key::index), int_value(at));
					return _attack_player_hero(state, session, context, index, hero_plan);
				}
			}
		}
		if (gd::int_field(state, force, key::troops, 0) > 0) {
			const DictRef battle_context = state.new_dict();
			state.set(battle_context, str(key::type), str(key::town_defense));
			state.set(battle_context, str(key::town_placement_id), str(ai::string_or_empty(state, town, key::placement_id)));
			state.set(battle_context, str(key::defending_hero_id), str(key::empty));
			state.set(battle_context, str(key::raid_encounter_key), str(ai::string_or_empty(state, encounter_at(state, session, index), key::placement_id)));
			state.set(battle_context, str(key::trigger_faction_id), str(player_rules::faction_id(state, session, controller)));
			state.set(battle_context, str(key::trigger_player_id), str(ai::string_or_empty(state, player_rules::player(state, session, controller), key::player_id)));
			state.set(battle_context, str(key::defender_owner), str(key::player));
			const Atom attacker = hero_name(state, encounter_at(state, session, index));
			const Atom town_name = enemy_turn_rules::_town_name(state, town);
			const Atom summary = gd::format(state, key::s_attacks_s, {str(attacker), str(town_name)});
			return _start_player_battle(state, session, context, index, battle_context, summary, town);
		}
	}
	const ArrayRef events = state.new_array();
	// A hero standing in the town defends it. With the garrison in one battle when
	// every stack fits the battle's seven slots (stacks of one kind merging if
	// needed), else that hero first and the garrison after.
	const int64_t defender_index = _town_hero_defender_index(state, session, town, controller);
	double defender_power = 0.0;
	if (defender_index >= 0) {
		defender_power = hero_power(state, encounter_at(state, session, defender_index));
		ArrayRef encounters = array_field(state, session_view::overworld(state, session), key::encounters);
		DictRef defender = gd::as_dict(state.at(encounters, defender_index));
		const Value hero_stacks = gd::duplicate_value(state, list_field(state, dict_field(state, defender, key::enemy_army), key::stacks), true);
		const Value garrison_before = array_value(gd::deep_duplicate_array(state, array_field_if(state, town, key::garrison)));
		const DictRef together = hero_command_rules::entry_defense_plan(state, hero_stacks, garrison_before);
		const bool combined = gd::bool_field(state, together, key::fits, false) && empty_commander_power(state, garrison_before) > 0.0;
		if (combined) {
			const DictRef army = dict_field(state, defender, key::enemy_army);
			state.set(army, str(key::stacks), gd::index(state, together, str(key::stacks)));
			state.set(defender, str(key::enemy_army), dict_value(army));
			state.set_at(encounters, defender_index, dict_value(defender));
			state.set(session_view::overworld(state, session), str(key::encounters), array_value(encounters));
			state.set(town, str(key::garrison), array_value(state.new_array()));
			state.set_at(towns, town_index, dict_value(town));
			state.set(session_view::overworld(state, session), str(key::towns), array_value(towns));
		}
		const DictRef duel_plan = state.new_dict();
		state.set(duel_plan, str(key::index), int_value(defender_index));
		const DictRef duel = _fight_ai_hero(state, session, context, index, duel_plan);
		ai::append_array(state, events, gd::as_array(list_field(state, duel, key::events)));
		const bool defender_beaten = _is_resolved(state, session, ai::string_or_empty(state, encounter_at(state, session, defender_index), key::placement_id));
		if (combined && !defender_beaten) {
			// The town held: the survivors go back to the hero and the garrison.
			encounters = array_field(state, session_view::overworld(state, session), key::encounters);
			defender = gd::as_dict(state.at(encounters, defender_index));
			const DictRef army = dict_field(state, defender, key::enemy_army);
			const DictRef split = hero_command_rules::split_entry_defense(state, hero_stacks, garrison_before, list_field(state, army, key::stacks));
			state.set(army, str(key::stacks), gd::index(state, split, str(key::hero)));
			state.set(defender, str(key::enemy_army), dict_value(army));
			const DictRef commander = dict_field(state, defender, key::enemy_commander_state);
			state.set(defender, str(key::enemy_commander_state), dict_value(enemy_adventure_rules::sync_commander_army_continuity(state, commander, dict_value(army), key::encounter_mire_raid)));
			state.set_at(encounters, defender_index, dict_value(defender));
			state.set(session_view::overworld(state, session), str(key::encounters), array_value(encounters));
			towns = array_field(state, session_view::overworld(state, session), key::towns);
			town = gd::as_dict(state.at(towns, town_index));
			state.set(town, str(key::garrison), gd::index(state, split, str(key::garrison)));
			state.set_at(towns, town_index, dict_value(town));
			state.set(session_view::overworld(state, session), str(key::towns), array_value(towns));
		}
		if (_is_resolved(state, session, ai::string_or_empty(state, encounter_at(state, session, index), key::placement_id)) || !defender_beaten) {
			return arrived_events(state, array_value(events));
		}
		towns = array_field(state, session_view::overworld(state, session), key::towns);
		town = gd::as_dict(state.at(towns, town_index));
	}
	const ArrayRef garrison = array_field_if(state, town, key::garrison);
	if (empty_commander_power(state, array_value(garrison)) > 0.0) {
		const DictRef defender = _garrison_defender(state, town, owner, array_value(garrison));
		const DictRef fight = _auto_resolve(state, session, context, index, defender);
		ai::append_array(state, events, gd::as_array(list_field(state, fight, key::events)));
		towns = array_field(state, session_view::overworld(state, session), key::towns);
		town = gd::as_dict(state.at(towns, town_index));
		const Value left = !gd::bool_field(state, fight, key::won, false) ? list_field(state, fight, key::enemy_survivors) : array_value(state.new_array());
		state.set(town, str(key::garrison), left);
		state.set_at(towns, town_index, dict_value(town));
		state.set(session_view::overworld(state, session), str(key::towns), array_value(towns));
		if (!gd::bool_field(state, fight, key::won, false)) {
			return arrived_events(state, array_value(events));
		}
	}
	const Atom previous_owner = owner;
	const Atom previous_controller = owner == key::enemy ? player_rules::town_controller_id(state, town) : owner;
	const DictRef transition = overworld_rules::transition_town_control(state, session, ai::string_or_empty(state, town, key::placement_id), key::enemy, controller, key::ai_hero_capture);
	if (!gd::bool_field(state, transition, key::ok, false)) {
		return arrived_events(state, array_value(events));
	}
	state.set(context, str(key::topology_changed), bool_value(true));
	// A human buys a captured town's troops into its garrison at once, so a
	// passing hero cannot simply walk back in.
	ai::append_array(state, events, _recruit_town(state, session, context, town_index, state.new_dict()));
	const DictRef entry = encounter_at(state, session, index);
	if (previous_owner == key::enemy) {
		const DictRef door = level_rules::town_entrance(state, town);
		note_town_taken(state, session, previous_controller, hostile_record(state, ai::string_or_empty(state, entry, key::placement_id), controller, gd::int_field(state, door, key::x, 0), gd::int_field(state, door, key::y, 0), level_rules::level_of(state, dict_value(door)), hero_power(state, entry), _movement_max(state, entry)), ai::string_or_empty(state, town, key::placement_id));
	}
	const DictRef flags = session_flags(state, session);
	if (gd::bool_field(state, flags, key::ai_battle_log_enabled, false)) {
		const ArrayRef captures = array_field(state, flags, key::ai_capture_log);
		const DictRef capture = state.new_dict();
		state.set(capture, str(key::day), int_value(session_day(state, session)));
		state.set(capture, str(key::player_id), str(controller));
		state.set(capture, str(key::hero), str(hero_name(state, entry)));
		state.set(capture, str(key::hero_power), float_value(hero_power(state, entry)));
		state.set(capture, str(key::town_placement_id), str(ai::string_or_empty(state, town, key::placement_id)));
		state.set(capture, str(key::town), str(enemy_turn_rules::_town_name(state, town)));
		state.set(capture, str(key::from), str(previous_controller));
		state.set(capture, str(key::garrison_power), float_value(empty_commander_power(state, array_value(garrison)) + defender_power));
		state.append(captures, dict_value(capture));
		state.set(flags, str(key::ai_capture_log), array_value(captures));
	}
	overworld_turn_playback::action(state, dict_value(session), entry, key::captures_a_town);
	const DictRef target = event_target(state, key::town, ai::string_or_empty(state, town, key::placement_id), enemy_turn_rules::_town_name(state, town), gd::int_field(state, town, key::x, 0), gd::int_field(state, town, key::y, 0));
	const Atom summary = gd::format(state, key::s_captures_s, {str(hero_name(state, entry)), str(enemy_turn_rules::_town_name(state, town))});
	const ArrayRef reasons = string_list(state, {key::town_captured, previous_owner == key::player ? key::player_town : key::neutral_town});
	state.append(events, dict_value(_event(state, session, context, key::ai_town_captured, entry, target, summary, reasons)));
	return arrived_events(state, array_value(events));
}

// Battles against the human are played by the human, exactly like any other
// battle against an enemy hero. The payload is Phase 2a's port; the session
// takes the battle in its view's fields.
DictRef _start_player_battle(State &state, DictRef session, DictRef context, int64_t index, DictRef battle_context, Atom summary, DictRef target) {
	const DictRef entry = encounter_at(state, session, index);
	state.set(entry, str(key::battle_context), dict_value(battle_context));
	_store_entry(state, session, index, entry);
	const DictRef payload = battle_rules::create_battle_payload(state, dict_value(session), entry);
	if (gd::is_empty(state, payload)) {
		state.erase(entry, str(key::battle_context));
		_store_entry(state, session, index, entry);
		return arrived_result(state);
	}
	state.set(session, str(key::battle), dict_value(payload));
	state.set(session, str(key::game_state), str(key::battle));
	overworld_turn_playback::action(state, dict_value(session), entry, key::engages_a_defending_army);
	const bool town_defense = gd::stringify(state, state.get(battle_context, str(key::type), str(key::empty))) == key::town_defense;
	const Atom placement_id = gd::stringify(state, state.get(target, str(key::placement_id), state.get(target, str(key::id), str(key::empty))));
	const Atom label = town_defense ? enemy_turn_rules::_town_name(state, target) : gd::stringify(state, state.get(target, str(key::name), str(key::empty)));
	const DictRef event_fields = event_target(state, town_defense ? key::town : key::hero, placement_id, label, gd::int_field(state, entry, key::x, 0), gd::int_field(state, entry, key::y, 0));
	state.set(event_fields, str(key::target_public_importance), str(key::critical));
	const Atom event_type = town_defense ? key::ai_town_defense_battle_queued : key::ai_hero_intercept_battle_queued;
	const DictRef event = _event(state, session, context, event_type, entry, event_fields, summary, string_list(state, {key::battle_handoff}));
	const DictRef result = arrived_result(state);
	state.set(result, str(key::battle_started), bool_value(true));
	const ArrayRef messages = state.new_array();
	state.append(messages, str(summary));
	state.set(result, str(key::messages), array_value(messages));
	const ArrayRef events = state.new_array();
	state.append(events, dict_value(event));
	state.set(result, str(key::events), array_value(events));
	return result;
}

void _record_hero_defeat(State &state, DictRef session, Atom controller, DictRef entry) {
	const DictRef commander = dict_field(state, entry, key::enemy_commander_state);
	if (gd::is_empty(state, commander) || controller == key::empty) {
		return;
	}
	const DictRef advanced = enemy_adventure_rules::advance_commander_record(state, commander, key::defeated);
	const int64_t recovery_day = gd::add(session_day(state, session), kRecoveryDaysDefeated);
	enemy_adventure_rules::sync_commander_state_to_roster(state, session, controller, dict_value(advanced), key::recovering, key::empty, recovery_day, key::defeated);
}

bool _fight_looks_good(State &state, DictRef session, DictRef context, DictRef entry, DictRef plan, bool idle) {
	const Atom kind = gd::stringify(state, state.get(plan, str(key::kind), str(key::empty)));
	const bool town_fight = kind == key::town_hostile || kind == key::town_neutral;
	if (kind != key::encounter && kind != key::ai_hero && !town_fight) {
		return true;
	}
	DictRef defender = 0;
	const int64_t defender_index = gd::int_field(state, plan, key::index, -1);
	if (town_fight) {
		// A human's town is a real battle. A hero at the gate fights first, with the
		// garrison beside it when every stack fits; else it is the hero alone first.
		const ArrayRef towns = array_field(state, session_view::overworld(state, session), key::towns);
		if (defender_index < 0 || defender_index >= state.array_size(towns)) {
			return true;
		}
		const DictRef town = gd::as_dict(state.at(towns, defender_index));
		const Atom owner = gd::stringify(state, state.get(town, str(key::owner), str(key::neutral)));
		const ArrayRef garrison = array_field_if(state, town, key::garrison);
		if (owner == key::player) {
			return true;
		}
		const int64_t gate_hero = _town_hero_defender_index(state, session, town, context_controller(state, context));
		if (gate_hero >= 0) {
			defender = gd::deep_duplicate_dict(state, encounter_at(state, session, gate_hero));
			const DictRef army = dict_field(state, defender, key::enemy_army);
			const DictRef together = hero_command_rules::entry_defense_plan(state, list_field(state, army, key::stacks), array_value(garrison));
			if (gd::bool_field(state, together, key::fits, false) && empty_commander_power(state, array_value(garrison)) > 0.0) {
				state.set(army, str(key::stacks), gd::index(state, together, str(key::stacks)));
				state.set(defender, str(key::enemy_army), dict_value(army));
			}
		} else if (empty_commander_power(state, array_value(garrison)) > 0.0) {
			defender = _garrison_defender(state, town, owner, array_value(garrison));
		} else {
			return true;
		}
	} else {
		const ArrayRef encounters = array_field(state, session_view::overworld(state, session), key::encounters);
		if (defender_index < 0 || defender_index >= state.array_size(encounters)) {
			return true;
		}
		defender = gd::as_dict(state.at(encounters, defender_index));
	}
	// An overwhelming margin needs no second look, unless the defender's hero
	// can blast a big share of the army with one spell.
	const double power = hero_power(state, entry);
	double burst = 0.0;
	if (is_ai_hero(state, dict_value(defender))) {
		burst = _burst_share(state, entry, map_field(state, defender, key::enemy_commander_state));
	}
	if (gd::float_field(state, plan, key::fight_power, 0.0) > 0.0) {
		const double margin = gd::to_float(gd::index(state, plan, str(key::fight_power))) * tunable(state, key::CLEAR_WIN_RATIO);
		if (power >= margin && burst < tunable(state, key::SPELL_BURST_PREVIEW_SHARE)) {
			return true;
		}
	}
	state.set(context, str(key::preview_count), int_value(gd::add(gd::int_field(state, context, key::preview_count, 0), 1)));
	const int64_t battle_number = gd::add(gd::int_field(state, context, key::auto_battle_count, 0), 1);
	const int64_t started = gd::ticks_usec();
	const DictRef outcome = _simulate_battle(state, session, context, entry, defender, battle_number, 0);
	_profile_add(state, context, key::preview_ms, started);
	// The fight that follows is this same battle; keep it for the hero to use.
	const DictRef preview = state.new_dict();
	state.set(preview, str(key::key), str(_battle_key(state, entry, defender, battle_number)));
	state.set(preview, str(key::outcome), dict_value(outcome));
	state.set(context, str(key::fight_preview), dict_value(preview));
	if (!gd::bool_field(state, outcome, key::won, false)) {
		return false;
	}
	// A town is worth a costly win.
	if (town_fight) {
		return true;
	}
	const double army_before = empty_commander_power(state, nested_list(state, entry, key::enemy_army, key::stacks));
	const double army_after = empty_commander_power(state, list_field(state, outcome, key::hero_survivors));
	if (army_after < army_before * tunable(state, key::FIGHT_MIN_KEPT)) {
		return false;
	}
	if (idle && army_after >= army_before * tunable(state, key::IDLE_FIGHT_MIN_KEPT)) {
		return true;
	}
	if (state.has(plan, str(key::estimated_loss)) && army_before > 0.0) {
		const double kept_share = army_after / army_before;
		const double lost_share = 1.0 - kept_share;
		const double lost_power = power * lost_share;
		const double actual_loss = lost_power * tunable(state, key::TROOP_VALUE_PER_POWER);
		const double gain = gd::float_field(state, plan, key::value, 0.0) + gd::to_float(gd::index(state, plan, str(key::estimated_loss)));
		return gain - actual_loss > 0.0;
	}
	return true;
}

Atom _battle_key(State &state, DictRef entry, DictRef defender, int64_t battle_number) {
	const Atom entry_id = ai::string_or_empty(state, entry, key::placement_id);
	const Atom defender_id = ai::string_or_empty(state, defender, key::placement_id);
	const int64_t entry_hash = gd::hash(state, nested_list(state, entry, key::enemy_army, key::stacks));
	int64_t defender_hash = 0;
	if (player_rules::raid_controller_id(state, defender) == key::empty) {
		defender_hash = gd::hash(state, list_field(state, _neutral_army(state, defender), key::stacks));
	} else {
		defender_hash = gd::hash(state, nested_list(state, defender, key::enemy_army, key::stacks));
	}
	return gd::format(state, key::s_s_d_d_d, {str(entry_id), str(defender_id), int_value(battle_number), int_value(entry_hash), int_value(defender_hash)});
}

DictRef _auto_resolve(State &state, DictRef session, DictRef context, int64_t index, DictRef defender) {
	state.set(context, str(key::auto_battle_count), int_value(gd::add(gd::int_field(state, context, key::auto_battle_count, 0), 1)));
	DictRef entry = encounter_at(state, session, index);
	const DictRef preview = dict_field(state, context, key::fight_preview);
	state.erase(context, str(key::fight_preview));
	DictRef outcome = 0;
	const Atom preview_key = ai::string_or_empty(state, preview, key::key);
	if (preview_key == _battle_key(state, entry, defender, gd::to_int(state, gd::index(state, context, str(key::auto_battle_count))))) {
		outcome = dict_field(state, preview, key::outcome);
	} else {
		outcome = state.new_dict();
	}
	const bool previewed = !gd::is_empty(state, outcome);
	if (gd::is_empty(state, outcome)) {
		outcome = _simulate_battle(state, session, context, entry, defender, gd::to_int(state, gd::index(state, context, str(key::auto_battle_count))), 0);
	}
	if (!gd::bool_field(state, outcome, key::ok, false)) {
		const DictRef failed = state.new_dict();
		state.set(failed, str(key::won), bool_value(false));
		state.set(failed, str(key::ok), bool_value(false));
		return failed;
	}
	const Atom final_state = ai::string_or_empty(state, outcome, key::state);
	bool won = gd::bool_field(state, outcome, key::won, false);
	const DictRef hero_after = dict_field(state, outcome, key::hero_after);
	const ArrayRef hero_survivors = array_field(state, outcome, key::hero_survivors);
	const bool lost = gd::bool_field(state, outcome, key::lost, false);
	const ArrayRef enemy_survivors = array_field(state, outcome, key::enemy_survivors);
	const DictRef gained = dict_field(state, outcome, key::resources_gained);
	_add_pool(state, context_treasury(state, context), dict_value(gained));
	if (gd::bool_field(state, session_flags(state, session), key::ai_battle_log_enabled, false)) {
		_log_battle(state, session, context, entry, defender, outcome, previewed);
	}
	const ArrayRef events = state.new_array();
	const Atom label = _defender_label(state, defender);
	if (!lost) {
		entry = encounter_at(state, session, index);
		const DictRef army = dict_field(state, entry, key::enemy_army);
		state.set(army, str(key::stacks), array_value(hero_survivors));
		state.set(entry, str(key::enemy_army), dict_value(army));
		DictRef commander = dict_field(state, entry, key::enemy_commander_state);
		for (const Atom field : {key::level, key::experience, key::next_level_experience, key::command, key::spellbook, key::artifacts, key::specialties, key::pending_specialty_choices}) {
			if (state.has(hero_after, str(field))) {
				state.set(commander, str(field), gd::index(state, hero_after, str(field)));
			}
		}
		if (won) {
			state.set(commander, str(key::battle_wins), int_value(gd::add(gd::int_field(state, commander, key::battle_wins, 0), 1)));
		}
		commander = enemy_adventure_rules::_normalize_enemy_progression(state, commander);
		state.set(entry, str(key::enemy_commander_state), dict_value(enemy_adventure_rules::sync_commander_army_continuity(state, commander, dict_value(army), key::encounter_mire_raid)));
		_store_entry(state, session, index, entry);
		if (won) {
			overworld_turn_playback::action(state, dict_value(session), entry, gd::format(state, key::defeats_s, {str(label)}));
			const DictRef target = _defender_target(state, defender, label);
			const Atom summary = gd::format(state, key::s_defeats_s, {str(hero_name(state, entry)), str(label)});
			state.append(events, dict_value(_event(state, session, context, key::ai_guard_defeated, entry, target, summary, string_list(state, {key::guard_cleared}))));
		} else {
			overworld_turn_playback::action(state, dict_value(session), entry, gd::format(state, key::breaks_off_against_s, {str(label)}));
			const DictRef target = _defender_target(state, defender, label);
			const Atom summary = gd::format(state, key::s_fights_s_to_a_standstill, {str(hero_name(state, entry)), str(label)});
			state.append(events, dict_value(_event(state, session, context, key::ai_guard_defeated, entry, target, summary, string_list(state, {key::guard_held}))));
		}
	} else {
		won = false;
		entry = encounter_at(state, session, index);
		overworld_turn_playback::action(state, dict_value(session), entry, gd::format(state, key::falls_to_s, {str(label)}));
		_mark_resolved(state, session, ai::string_or_empty(state, entry, key::placement_id));
		_record_hero_defeat(state, session, context_controller(state, context), entry);
		state.set(context, str(key::topology_changed), bool_value(true));
		const DictRef target = _defender_target(state, defender, label);
		const Atom summary = gd::format(state, key::s_falls_fighting_s, {str(hero_name(state, entry)), str(label)});
		state.append(events, dict_value(_event(state, session, context, key::ai_hero_defeated, entry, target, summary, string_list(state, {key::hero_defeated}))));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::won), bool_value(won));
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::state), str(final_state));
	state.set(result, str(key::enemy_survivors), array_value(enemy_survivors));
	state.set(result, str(key::events), array_value(events));
	state.set(result, str(key::resources_gained), dict_value(gained));
	return result;
}

void _log_battle(State &state, DictRef session, DictRef context, DictRef entry, DictRef defender, DictRef outcome, bool previewed) {
	ArrayRef defender_stacks = 0;
	Value found;
	if (state.lookup(defender, str(key::enemy_army), found) && gd::is_dict(found) && state.has(found.ref, str(key::stacks))) {
		defender_stacks = gd::as_array(gd::index(state, found.ref, str(key::stacks)));
	} else {
		defender_stacks = gd::as_array(list_field(state, _neutral_army(state, defender), key::stacks));
	}
	const Atom placement_id = ai::string_or_empty(state, defender, key::placement_id);
	Atom kind = key::guard;
	if (is_ai_hero(state, dict_value(defender))) {
		kind = key::hero;
	} else if (gd::begins_with(state, placement_id, key::town_garrison_2)) {
		kind = key::town;
	}
	const DictRef commander = dict_field_if(state, entry, key::enemy_commander_state);
	const DictRef hero_after = dict_field(state, outcome, key::hero_after);
	ArrayRef stacks = 0;
	if (!state.lookup(entry, str(key::enemy_army), found)) {
		stacks = state.new_array();
	} else if (gd::is_dict(found)) {
		stacks = gd::as_array(list_field(state, found.ref, key::stacks));
	} else {
		stacks = state.new_array();
	}
	const double power = army_power(state, array_value(stacks), dict_value(commander));
	const Value defender_commander = kind == key::hero ? map_field(state, defender, key::enemy_commander_state) : dict_value(state.new_dict());
	const double defender_power = army_power(state, array_value(defender_stacks), defender_commander);
	const bool won = gd::bool_field(state, outcome, key::won, false);
	const bool lost = gd::bool_field(state, outcome, key::lost, false);
	const ArrayRef records = array_field(state, session_flags(state, session), key::ai_battle_log);
	const DictRef record = state.new_dict();
	state.set(record, str(key::day), int_value(session_day(state, session)));
	state.set(record, str(key::player_id), str(context_controller(state, context)));
	state.set(record, str(key::hero_placement_id), str(ai::string_or_empty(state, entry, key::placement_id)));
	state.set(record, str(key::hero), str(hero_name(state, entry)));
	state.set(record, str(key::hero_level), int_value(gd::int_field(state, commander, key::level, 1)));
	int64_t experience_gained = 0;
	if (!lost) {
		experience_gained = compat::engine_max<int64_t>(0, gd::sub(gd::int_field(state, hero_after, key::experience, 0), gd::int_field(state, commander, key::experience, 0)));
	}
	state.set(record, str(key::experience_gained), int_value(experience_gained));
	state.set(record, str(key::x), int_value(gd::int_field(state, entry, key::x, 0)));
	state.set(record, str(key::y), int_value(gd::int_field(state, entry, key::y, 0)));
	state.set(record, str(key::stacks), array_value(gd::deep_duplicate_array(state, stacks)));
	state.set(record, str(key::power), float_value(power));
	state.set(record, str(key::survivors), lost ? array_value(state.new_array()) : gd::duplicate_value(state, list_field(state, outcome, key::hero_survivors), true));
	state.set(record, str(key::survivor_power), float_value(lost ? 0.0 : army_power(state, list_field(state, outcome, key::hero_survivors), dict_value(hero_after))));
	{
		const double expected = _expected_loss_value(state, power, defender_power);
		const double scaled = power * tunable(state, key::TROOP_VALUE_PER_POWER);
		state.set(record, str(key::estimated_loss_share), float_value(expected / compat::engine_max(0.001, scaled)));
	}
	state.set(record, str(key::defender_kind), str(kind));
	state.set(record, str(key::defender), str(_defender_label(state, defender)));
	{
		const Value fallback_owner = str(player_rules::raid_controller_id(state, defender));
		state.set(record, str(key::defender_player_id), str(gd::stringify(state, state.get(defender, str(key::battle_log_owner), fallback_owner))));
	}
	state.set(record, str(key::defender_stacks), array_value(gd::deep_duplicate_array(state, defender_stacks)));
	state.set(record, str(key::defender_power), float_value(defender_power));
	state.set(record, str(key::defender_survivors), won ? array_value(state.new_array()) : gd::duplicate_value(state, list_field(state, outcome, key::enemy_survivors), true));
	state.set(record, str(key::result), str(won ? key::won : (lost ? key::lost : key::standstill)));
	state.set(record, str(key::previewed), bool_value(previewed));
	state.set(record, str(key::resources_gained), gd::duplicate_value(state, map_field(state, outcome, key::resources_gained), true));
	state.set(record, str(key::commander), dict_value(_commander_brief(state, dict_value(commander))));
	state.set(record, str(key::defender_commander), dict_value(kind == key::hero ? _commander_brief(state, map_field(state, defender, key::enemy_commander_state)) : state.new_dict()));
	state.set(record, str(key::resolution), gd::duplicate_value(state, map_field(state, outcome, key::resolution), true));
	state.append(records, dict_value(record));
	state.set(session_flags(state, session), str(key::ai_battle_log), array_value(records));
}

void _economy_add(State &state, DictRef session, Atom controller, Atom field, double amount) {
	if (amount == 0.0 || !gd::bool_field(state, session_flags(state, session), key::ai_battle_log_enabled, false)) {
		return;
	}
	const DictRef log = dict_field(state, session_flags(state, session), key::ai_economy_log);
	const DictRef row = dict_field(state, log, controller);
	const double before = gd::to_float(state.get(row, str(field), float_value(0.0)));
	state.set(row, str(field), float_value(before + amount));
	state.set(log, str(controller), dict_value(row));
	state.set(session_flags(state, session), str(key::ai_economy_log), dict_value(log));
}

DictRef _commander_brief(State &state, const Value &commander) {
	if (!gd::is_dict(commander) || gd::is_empty(state, commander.ref)) {
		return state.new_dict();
	}
	const DictRef source = commander.ref;
	const DictRef command = dict_field_if(state, source, key::command);
	const DictRef spellbook = dict_field_if(state, source, key::spellbook);
	_sync_power_memos(state);
	const DictRef brief = state.new_dict();
	state.set(brief, str(key::level), int_value(gd::int_field(state, source, key::level, 1)));
	state.set(brief, str(key::attack), int_value(gd::int_field(state, command, key::attack, 0)));
	state.set(brief, str(key::defense), int_value(gd::int_field(state, command, key::defense, 0)));
	state.set(brief, str(key::power), int_value(gd::int_field(state, command, key::power, 0)));
	state.set(brief, str(key::knowledge), int_value(gd::int_field(state, command, key::knowledge, 0)));
	Value found;
	const bool has_spells = state.lookup(spellbook, str(key::known_spell_ids), found) && gd::is_array(found);
	state.set(brief, str(key::spells), array_value(has_spells ? gd::duplicate_array(state, found.ref) : state.new_array()));
	const bool has_mana = state.lookup(spellbook, str(key::mana), found) && gd::is_dict(found);
	state.set(brief, str(key::mana), dict_value(has_mana ? gd::duplicate_dict(state, found.ref) : state.new_dict()));
	state.set(brief, str(key::spell_damage_per_round), float_value(_spell_damage_per_round(state, source)));
	return brief;
}

Atom _defender_label(State &state, DictRef defender) {
	if (is_ai_hero(state, dict_value(defender))) {
		return hero_name(state, defender);
	}
	Value found;
	if (state.lookup(defender, str(key::enemy_army), found) && gd::is_dict(found)) {
		const Atom name = ai::string_or_empty(state, found.ref, key::name);
		if (name != key::empty) {
			return name;
		}
	}
	return overworld_rules::encounter_display_name(state, defender);
}

DictRef _defender_target(State &state, DictRef defender, Atom label) {
	return event_target(state, key::encounter, ai::string_or_empty(state, defender, key::placement_id), label, gd::int_field(state, defender, key::x, 0), gd::int_field(state, defender, key::y, 0));
}

DictRef _find_town(State &state, DictRef session, Atom placement_id) {
	const DictRef result = state.new_dict();
	Value found;
	if (state.lookup(session_view::overworld(state, session), str(key::towns), found)) {
		const ArrayRef towns = gd::as_array(found);
		const int64_t town_count = state.array_size(towns);
		for (int64_t index = 0; index < town_count; ++index) {
			const Value town = state.at(towns, index);
			if (gd::is_dict(town) && ai::string_or_empty(state, town.ref, key::placement_id) == placement_id) {
				state.set(result, str(key::index), int_value(index));
				state.set(result, str(key::town), town);
				return result;
			}
		}
	}
	state.set(result, str(key::index), int_value(-1));
	state.set(result, str(key::town), dict_value(state.new_dict()));
	return result;
}

void _add_pool(State &state, DictRef pool, const Value &delta) {
	if (!gd::is_dict(delta)) {
		return;
	}
	const ArrayRef delta_keys = gd::keys(state, delta.ref);
	const int64_t key_count = state.array_size(delta_keys);
	for (int64_t at = 0; at < key_count; ++at) {
		const Value resource = state.at(delta_keys, at);
		if (live_resource(gd::stringify(state, resource))) {
			const int64_t held = gd::to_int(state, state.get(pool, resource, int_value(0)));
			const int64_t added = gd::to_int(state, gd::index(state, delta.ref, resource));
			state.set(pool, resource, int_value(gd::add(held, added)));
		}
	}
}

DictRef _event(State &state, DictRef session, DictRef context, Atom event_type, DictRef actor, DictRef target, Atom summary, ArrayRef reason_codes) {
	const DictRef target_with_reasons = gd::deep_duplicate_dict(state, target);
	state.set(target_with_reasons, str(key::target_reason_codes), array_value(reason_codes));
	const DictRef config = context_config(state, context);
	const DictRef options = state.new_dict();
	state.set(options, str(key::summary), str(summary));
	state.set(options, str(key::actor_label), str(hero_name(state, actor)));
	state.set(options, str(key::state_policy), str(key::durable_state_reference));
	state.set(options, str(key::public_importance), str(gd::stringify(state, state.get(target, str(key::target_public_importance), str(key::medium)))));
	return enemy_adventure_rules::build_ai_event_record(state, session, config, event_type, actor, target_with_reasons, options);
}

} // namespace ai_hero_rules

} // namespace aurelion::rules::port
