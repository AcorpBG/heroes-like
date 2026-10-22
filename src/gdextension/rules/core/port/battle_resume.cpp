// A battle picked up again (Phase 2, slice 2b): BattleRules.normalize_battle_state,
// which a loaded save and every battle screen refresh run, and
// battle_payload_can_resume, with the helpers that check the battle's context
// still stands and bring an older or partial payload up to the current shape.

#include "aurelion_rules/port/battle_payload.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/battle_footprint.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/difficulty_rules.hpp"
#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

namespace aurelion::rules::port::battle_rules {

using compat::engine_clamp;
using compat::engine_max;
using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Kind;
namespace key = state::key;

namespace {

constexpr int64_t SAVE_VERSION = 9; // SessionStateStore.SAVE_VERSION
constexpr int64_t COHESION_MIN = 0;
constexpr int64_t COHESION_MAX = 10;
constexpr int64_t MOMENTUM_MAX = 4;
constexpr int64_t OBSTACLE_VARIANT_COUNT = 25;
constexpr int64_t ARMY_SLOT_COUNT = 7; // HeroCommandRules.ARMY_SLOT_COUNT
constexpr int64_t MAX_SPELL_RESISTANCE_PCT = 75; // SpellRules
constexpr int64_t MAX_CONTROL_RESISTANCE_PCT = 80; // SpellRules

// session.battle and session.overworld: SessionData types them Dictionary.
DictRef session_battle(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::battle));
}

DictRef session_overworld(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::overworld));
}

// session.scenario_id and the session's other String fields.
Atom session_text(State &state, const Value &session, Atom field) {
	return gd::to_string(gd::member(state, session, field));
}

// session == null or session.battle.is_empty()
bool no_battle(State &state, const Value &session) {
	return session.kind == Kind::Nil || gd::is_empty(state, session_battle(state, session));
}

// d.get(key, {}) where the Dictionary is passed on: the stored one, or a new one.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// d.get(key, []) where the Array is passed on: the stored one, or a new one.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// String(d.get(key, "")).
Atom string_of(State &state, DictRef dict, Atom field) {
	return gd::stringify(state, gd::field_or(state, dict, field, str(key::empty)));
}

// String(d.get(key, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return gd::stringify(state, gd::field_or(state, dict, field, fallback));
}

// int(d.get(key, fallback)) of a value the stack or the unit may hold.
int64_t int_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return gd::to_int(state, gd::field_or(state, dict, field, fallback));
}

// An untyped clamp() or max() of ints: an int.
int64_t clamp_int(int64_t value, int64_t low, int64_t high) {
	return engine_clamp<int64_t>(value, low, high);
}

// int(_find_town_by_placement(...).get("index", -1)) and its "town".
DictRef found_town(State &state, DictRef town_result) {
	return gd::as_dict(field_or_new_dict(state, town_result, key::town));
}

// OverworldRules._find_resource_node_by_placement(session, id).get("node", {}).
DictRef resource_node(State &state, const Value &session, Atom placement_id) {
	const DictRef found = overworld_rules::_find_resource_node_by_placement(state, gd::object_view(state, session), placement_id);
	return gd::as_dict(field_or_new_dict(state, found, key::node));
}

// resolved_key != "" and (resolved is Array) and resolved_key in resolved, of
// session.battle's resolved key and session.overworld.resolved_encounters.
bool battle_key_resolved(State &state, const Value &session) {
	const Atom resolved_key = string_of(state, session_battle(state, session), key::resolved_key);
	Value resolved;
	if (!state.lookup(session_overworld(state, session), str(key::resolved_encounters), resolved)) {
		return false;
	}
	return resolved_key != key::empty && gd::is_array(resolved) && gd::in(state, str(resolved_key), resolved);
}

} // namespace

bool normalize_battle_state(State &state, const Value &session) {
	if (no_battle(state, session)) {
		return false;
	}
	gd::set_member(state, session, key::save_version, int_value(SAVE_VERSION));
	difficulty_rules::normalize_session(state, gd::object_view(state, session));

	const DictRef battle_context_seed = _battle_context_seed(state, session);
	const DictRef normalized_context = _normalized_battle_context(state, session, dict_value(battle_context_seed));
	if (!_battle_context_is_restorable(state, session, normalized_context)) {
		return false;
	}
	if (_battle_context_already_resolved(state, session, normalized_context)) {
		return false;
	}
	_sync_battle_context_anchors(state, session, normalized_context);

	if (!state.has(session_battle(state, session), str(key::stacks))) {
		DictRef encounter_stub = _current_battle_encounter_placement(state, session);
		if (gd::is_empty(state, encounter_stub)) {
			encounter_stub = _synthetic_battle_encounter_placement(state, session, dict_value(normalized_context));
		}
		if (gd::is_empty(state, encounter_stub)) {
			return false;
		}
		state.set(encounter_stub, str(key::battle_context), dict_value(gd::deep_duplicate_dict(state, normalized_context)));
		gd::set_member(state, session, key::battle, dict_value(create_battle_payload(state, session, encounter_stub)));
		return !gd::is_empty(state, session_battle(state, session));
	}

	// Nothing below assigns session.battle, so its Dictionary is the one to fill.
	const DictRef battle = session_battle(state, session);
	const ArrayRef stacks = state.new_array();
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		DictRef normalized = _normalize_stack(state, stack);
		if (!gd::is_empty(state, normalized)) {
			normalized = spell_rules::normalize_stack_effects(state, normalized);
			state.append(stacks, dict_value(normalized));
		}
	}
	state.set(battle, str(key::stacks), array_value(stacks));
	state.set(battle, str(key::context), dict_value(normalized_context));
	const bool town_defense_context = _is_town_defense_context(state, field_or_new_dict(state, battle, key::context));
	state.set(battle, str(key::retreat_allowed),
			bool_value(town_defense_context ? false : gd::to_bool(gd::field_or(state, battle, key::retreat_allowed, bool_value(true)))));
	state.set(battle, str(key::surrender_allowed),
			bool_value(town_defense_context ? false : gd::to_bool(gd::field_or(state, battle, key::surrender_allowed, bool_value(true)))));
	state.set(battle, str(key::enemy_withdrawal_allowed),
			bool_value(_enemy_withdrawal_allowed(state, session, normalized_context, _current_battle_encounter_placement(state, session))));
	state.set(battle, str(key::recent_events), array_value(_normalize_recent_events(state, field_or_new_array(state, battle, key::recent_events))));
	state.set(battle, str(key::battle_presentation_event_serial),
			int_value(engine_max<int64_t>(0, int_or(state, battle, key::battle_presentation_event_serial, int_value(0)))));
	state.set(battle, str(key::battle_presentation_events),
			array_value(_normalize_presentation_event_queue(state, field_or_new_array(state, battle, key::battle_presentation_events))));
	state.set(battle, str(key::battle_presentation_speed),
			str(_normalize_presentation_speed(state, text_or(state, battle, key::battle_presentation_speed, str(key::normal)))));
	state.set(battle, str(key::stack_animation_states),
			dict_value(_normalize_stack_animation_states(state, field_or_new_dict(state, battle, key::stack_animation_states))));
	state.set(battle, str(key::animation_event_serial),
			int_value(engine_max<int64_t>(0, int_or(state, battle, key::animation_event_serial, int_value(0)))));
	state.set(battle, str(key::battle_animation_events),
			array_value(_normalize_animation_event_queue(state, field_or_new_array(state, battle, key::battle_animation_events))));
	state.set(battle, str(key::tactical_briefing),
			dict_value(_normalize_tactical_briefing_state(state, field_or_new_dict(state, battle, key::tactical_briefing), session)));
	state.set(battle, str(key::round), int_value(engine_max<int64_t>(1, int_or(state, battle, key::round, int_value(1)))));
	state.set(battle, str(key::max_rounds), int_value(engine_max<int64_t>(1, int_or(state, battle, key::max_rounds, int_value(12)))));
	_ensure_damage_rng_state(state, session, battle);
	state.set(battle, str(key::commander_spell_cast_rounds),
			dict_value(_normalize_commander_spell_cast_rounds(state, field_or_new_dict(state, battle, key::commander_spell_cast_rounds))));
	state.set(battle, str(key::player_orders_given), int_value(engine_max<int64_t>(0, int_or(state, battle, key::player_orders_given, int_value(0)))));
	state.set(battle, str(key::terrain), str(text_or(state, battle, key::terrain, str(key::plains))));
	{
		const Value battle_position = field_or_new_dict(state, battle, key::position);
		const DictRef where = state.new_dict();
		const int64_t hero_x = overworld_rules::hero_position(state, gd::object_view(state, session)).x;
		state.set(where, str(key::x), int_value(gd::to_int(state, ai::vget(state, battle_position, key::x, int_value(hero_x)))));
		const int64_t hero_y = overworld_rules::hero_position(state, gd::object_view(state, session)).y;
		state.set(where, str(key::y), int_value(gd::to_int(state, ai::vget(state, battle_position, key::y, int_value(hero_y)))));
		state.set(where, str(key::level), int_value(overworld_level_rules::level_of(state, battle_position)));
		state.set(battle, str(key::position), dict_value(overworld_level_rules::position(state, where)));
	}
	const DictRef encounter = gd::content_row(state, ContentTable::Encounter, string_of(state, battle, key::encounter_id));
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, session_text(state, session, key::scenario_id));
	const DictRef encounter_placement = _current_battle_encounter_placement(state, session);
	state.set(battle, str(key::resolved_key), str(_normalized_battle_resolved_key(state, session, encounter_placement, normalized_context)));
	state.set(battle, str(key::encounter_name), str(_battle_name(state, session, encounter, normalized_context, encounter_placement)));
	state.set(battle, str(key::encounter_difficulty), str(_battle_difficulty_value(state, encounter_placement, encounter)));
	if (gd::strip_edges(state, string_of(state, battle, key::enemy_army_name)) == key::empty) {
		const Atom normalized_enemy_army_name = _enemy_force_name_from_battle_army_id(state, battle, session);
		state.set(battle, str(key::enemy_army_name), str(normalized_enemy_army_name != key::empty ? normalized_enemy_army_name : key::enemy_force));
	}
	{
		const ArrayRef tags = _normalized_battlefield_tags(state, encounter, field_or_new_dict(state, battle, key::context));
		state.set(battle, str(key::battlefield_tags),
				array_value(_with_army_battlefield_tags(state, tags, gd::as_array(field_or_new_array(state, battle, key::stacks)))));
	}
	state.set(battle, str(key::field_objectives),
			array_value(_normalize_field_objectives(state, field_or_new_array(state, battle, key::field_objectives), encounter, encounter_placement,
					scenario, field_or_new_dict(state, battle, key::context))));
	// The band is derived from the stack hexes: set at creation, after every move and kill, and each round.
	state.set(battle, str(key::distance), int_value(clamp_int(int_or(state, battle, key::distance, int_value(2)), 0, 2)));
	// Saves from before obstacles load with an open field.
	state.set(battle, str(key::obstacles), array_value(_normalize_battle_obstacles(state, field_or_new_array(state, battle, key::obstacles))));
	state.set(battle, str(key::hex_board), dict_value(_hex_board_descriptor(state)));
	_ensure_battle_hex_state(state, battle);
	state.set(battle, str(key::player_commander_state),
			dict_value(_normalize_player_commander_state(state, session, field_or_new_dict(state, battle, key::player_commander_state),
					field_or_new_dict(state, battle, key::player_commander_source), field_or_new_dict(state, battle, key::context))));
	{
		const DictRef commander = gd::as_dict(field_or_new_dict(state, battle, key::player_commander_state));
		const DictRef bonuses = artifact_rules::aggregate_bonuses(state, gd::as_dict(field_or_new_dict(state, battle, key::player_commander_state)));
		state.set(battle, str(key::player_hero), dict_value(_hero_payload_from_state(state, commander, bonuses, session, key::player)));
	}
	state.set(battle, str(key::enemy_hero),
			dict_value(_normalize_enemy_hero_state(state, field_or_new_dict(state, battle, key::enemy_hero), encounter, encounter_placement)));
	state.set(battle, str(key::enemy_hero_payload),
			dict_value(_enemy_hero_payload_from_state(state, gd::as_dict(field_or_new_dict(state, battle, key::enemy_hero)),
					field_or_new_dict(state, battle, key::enemy_hero_payload), session)));

	state.set(battle, str(key::waited_stack_ids), array_value(_normalize_waited_stack_ids(state, battle)));
	const Value current_turn_order = field_or_new_array(state, battle, key::turn_order);
	if (int_or(state, battle, key::round, int_value(1)) <= 1 && gd::is_array(current_turn_order) && state.array_size(current_turn_order.ref) == 0) {
		_prepare_round(state, battle, 1);
	} else {
		const Value turn_order = field_or_new_array(state, battle, key::turn_order);
		if (!gd::is_array(turn_order) || state.array_size(turn_order.ref) == 0) {
			_prepare_round(state, battle, int_or(state, battle, key::round, int_value(1)));
		} else {
			state.set(battle, str(key::turn_order), turn_order);
			state.set(battle, str(key::turn_index),
					int_value(clamp_int(int_or(state, battle, key::turn_index, int_value(0)), 0, engine_max<int64_t>(state.array_size(turn_order.ref) - 1, 0))));
			Atom active_id = string_of(state, battle, key::active_stack_id);
			if (active_id == key::empty || gd::is_empty(state, _get_stack_by_id(state, battle, active_id))) {
				active_id = _advance_to_next_alive(state, battle, int_or(state, battle, key::turn_index, int_value(0)));
				state.set(battle, str(key::active_stack_id), str(active_id));
			}
			const DictRef active = get_active_stack(state, battle);
			// Normalization runs on every UI refresh. It must not replace a live
			// player selection with the first preferred target after Next/Prev.
			if (string_of(state, active, key::side) == key::player
					&& _selected_target_can_remain_for_active_stack(state, battle, active, string_of(state, battle, key::selected_target_id))) {
				_clear_stale_selected_target_closing(state, battle, true);
			} else {
				_assign_default_target(state, battle);
			}
		}
	}
	return !gd::is_empty(state, session_battle(state, session));
}

bool battle_payload_can_resume(State &state, const Value &session) {
	if (session.kind == Kind::Nil || session_text(state, session, key::scenario_id) == key::empty
			|| session_text(state, session, key::scenario_status) != key::in_progress || gd::is_empty(state, session_battle(state, session))) {
		return false;
	}
	const DictRef battle_context_seed = _battle_context_seed(state, session);
	const DictRef normalized_context = _normalized_battle_context(state, session, dict_value(battle_context_seed));
	if (!_battle_context_is_restorable(state, session, normalized_context)) {
		return false;
	}
	if (_battle_context_already_resolved(state, session, normalized_context)) {
		return false;
	}
	if (state.has(session_battle(state, session), str(key::stacks))) {
		return _battle_has_living_opposition(state, session_battle(state, session));
	}
	DictRef encounter_stub = _current_battle_encounter_placement(state, session);
	if (gd::is_empty(state, encounter_stub)) {
		encounter_stub = _synthetic_battle_encounter_placement(state, session, dict_value(normalized_context));
	}
	return !gd::is_empty(state, encounter_stub)
			&& text_or(state, encounter_stub, key::encounter_id, gd::field_or(state, session_battle(state, session), key::encounter_id, str(key::empty))) != key::empty;
}

DictRef _battle_context_seed(State &state, const Value &session) {
	if (no_battle(state, session)) {
		return state.new_dict();
	}
	const DictRef seed = gd::deep_duplicate_dict(state, session_battle(state, session));
	state.erase(seed, str(key::_live_action_playback_capture));
	state.set(seed, str(key::placement_id),
			str(text_or(state, seed, key::resolved_key, gd::field_or(state, seed, key::placement_id, str(key::empty)))));
	if (!state.has(seed, str(key::battle_context)) && gd::is_dict(field_or_new_dict(state, seed, key::context))) {
		state.set(seed, str(key::battle_context), dict_value(gd::deep_duplicate_dict(state, gd::as_dict(field_or_new_dict(state, seed, key::context)))));
	}
	const Value position = field_or_new_dict(state, seed, key::position);
	if (gd::is_dict(position)) {
		state.set(seed, str(key::x), int_value(gd::int_field(state, position.ref, key::x, 0)));
		state.set(seed, str(key::y), int_value(gd::int_field(state, position.ref, key::y, 0)));
	}
	return seed;
}

bool _battle_context_is_restorable(State &state, const Value &session, DictRef context) {
	const Atom type = text_or(state, context, key::type, str(key::encounter));
	if (type == key::hero_intercept) {
		const Atom target_hero_id = string_of(state, context, key::target_hero_id);
		return target_hero_id != key::empty && !gd::is_empty(state, hero_command_rules::hero_by_id(state, gd::object_view(state, session), target_hero_id));
	}
	if (type == key::resource_assault) {
		const DictRef node = resource_node(state, session, string_of(state, context, key::resource_placement_id));
		if (gd::is_empty(state, node)) {
			return false;
		}
		const Atom collector = string_of(state, node, key::collected_by_faction_id);
		if (collector == key::empty || collector == key::player) {
			return false;
		}
		const Value defender_army = field_or_new_dict(state, node, key::ai_defender_army);
		return gd::is_dict(defender_army) && _army_strength_from_stacks(state, field_or_new_array(state, defender_army.ref, key::stacks)) > 0;
	}
	if (type == key::town_defense || type == key::town_assault) {
		return gd::int_field(state, _find_town_by_placement(state, session, string_of(state, context, key::town_placement_id)), key::index, -1) >= 0;
	}
	return true;
}

bool _battle_context_already_resolved(State &state, const Value &session, DictRef context) {
	if (no_battle(state, session)) {
		return true;
	}
	const Atom type = text_or(state, context, key::type, str(key::encounter));
	if (type == key::hero_intercept) {
		// The intercepting map host is retired as soon as combat begins so it
		// cannot trigger twice; the live battle payload remains resumable.
		return false;
	}
	if (type == key::town_assault) {
		const DictRef assaulted_town = found_town(state, _find_town_by_placement(state, session, string_of(state, context, key::town_placement_id)));
		return gd::is_empty(state, assaulted_town) || text_or(state, assaulted_town, key::owner, str(key::neutral)) != key::enemy;
	}
	if (type == key::town_defense) {
		const DictRef defended_town = found_town(state, _find_town_by_placement(state, session, string_of(state, context, key::town_placement_id)));
		const Atom defender_owner = text_or(state, context, key::defender_owner, str(key::player));
		return gd::is_empty(state, defended_town) || text_or(state, defended_town, key::owner, str(key::neutral)) != defender_owner;
	}
	if (type == key::resource_assault) {
		const DictRef node = resource_node(state, session, string_of(state, context, key::resource_placement_id));
		if (gd::is_empty(state, node) || string_of(state, node, key::collected_by_faction_id) == key::player) {
			return true;
		}
	}
	return battle_key_resolved(state, session);
}

bool _battle_has_living_opposition(State &state, DictRef battle) {
	if (gd::is_empty(state, battle)) {
		return false;
	}
	bool player_alive = false;
	bool enemy_alive = false;
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (!gd::is_dict(stack) || _alive_count(state, stack.ref) <= 0) {
			continue;
		}
		const Atom side = string_of(state, stack.ref, key::side);
		if (side == key::player) {
			player_alive = true;
		} else if (side == key::enemy) {
			enemy_alive = true;
		}
		if (player_alive && enemy_alive) {
			return true;
		}
	}
	return false;
}

void _sync_battle_context_anchors(State &state, const Value &session, DictRef context) {
	if (no_battle(state, session) || session_text(state, session, key::scenario_status) != key::in_progress) {
		return;
	}
	const Atom type = string_of(state, context, key::type);
	if (type == key::hero_intercept) {
		const Atom target_hero_id = string_of(state, context, key::target_hero_id);
		if (target_hero_id != key::empty && !gd::is_empty(state, hero_command_rules::hero_by_id(state, gd::object_view(state, session), target_hero_id))) {
			state.set(session_overworld(state, session), str(key::active_hero_id), str(target_hero_id));
			hero_command_rules::_sync_active_hero_mirror(state, gd::object_view(state, session));
		}
	} else if (type == key::town_defense || type == key::town_assault) {
		const DictRef town_result = _find_town_by_placement(state, session, string_of(state, context, key::town_placement_id));
		const int64_t town_index = gd::int_field(state, town_result, key::index, -1);
		if (town_index < 0) {
			return;
		}
		const Value towns = field_or_new_array(state, session_overworld(state, session), key::towns);
		const Value town = field_or_new_dict(state, town_result, key::town);
		if (_is_town_defense_context(state, dict_value(context))) {
			state.set(gd::as_dict(town), str(key::owner), str(text_or(state, context, key::defender_owner, str(key::player))));
		} else {
			state.set(gd::as_dict(town), str(key::owner), str(key::enemy));
		}
		state.set_at(gd::as_array(towns), town_index, town);
		state.set(session_overworld(state, session), str(key::towns), towns);
		state.set(session_battle(state, session), str(key::position), dict_value(overworld_level_rules::town_entrance(state, gd::as_dict(town))));
	} else if (type == key::resource_assault) {
		const DictRef node = resource_node(state, session, string_of(state, context, key::resource_placement_id));
		if (!gd::is_empty(state, node)) {
			state.set(session_battle(state, session), str(key::position), dict_value(overworld_level_rules::position(state, node)));
		}
	}
}

Atom _normalized_battle_resolved_key(State &state, const Value &session, DictRef encounter_placement, DictRef context) {
	Atom resolved_key = string_of(state, session_battle(state, session), key::resolved_key);
	if (resolved_key != key::empty) {
		return resolved_key;
	}
	if (!gd::is_empty(state, encounter_placement)) {
		resolved_key = overworld_rules::encounter_key(state, encounter_placement);
		if (resolved_key != key::empty) {
			return resolved_key;
		}
	}
	if (_is_town_assault_context(state, dict_value(context))) {
		const Atom town_placement_id = string_of(state, context, key::town_placement_id);
		if (town_placement_id != key::empty) {
			return gd::format(state, key::town_assault_s, { str(town_placement_id) });
		}
	}
	if (_is_resource_assault_context(state, dict_value(context))) {
		const Atom resource_placement_id = string_of(state, context, key::resource_placement_id);
		if (resource_placement_id != key::empty) {
			return gd::format(state, key::resource_defense_s, { str(resource_placement_id) });
		}
	}
	return key::empty;
}

DictRef _normalize_player_commander_state(State &state, const Value &session, const Value &existing_state, const Value &source, const Value &context) {
	// String((source if source is Dictionary else {}).get(field, "")).
	const auto source_text = [&](Atom field) {
		return gd::is_dict(source) ? string_of(state, source.ref, field) : key::empty;
	};
	if (gd::is_dict(existing_state) && !gd::is_empty(state, existing_state.ref)) {
		if (source_text(key::type) == key::town_captain_2) {
			return _normalize_town_captain(state, existing_state.ref);
		}
		return hero_progression_rules::ensure_hero_progression(state, spell_rules::ensure_hero_spellbook(state, existing_state.ref, state.new_dict()));
	}
	const Atom source_type = source_text(key::type);
	if (source_type == key::active_hero || source_type == key::town_hero) {
		const DictRef hero = hero_command_rules::hero_by_id(state, gd::object_view(state, session), source_text(key::hero_id));
		if (!gd::is_empty(state, hero)) {
			return hero;
		}
	}
	if (_is_town_defense_context(state, context)) {
		const Atom town_placement_id = gd::is_dict(context) ? string_of(state, context.ref, key::town_placement_id) : key::empty;
		return _town_captain_state(state, found_town(state, _find_town_by_placement(state, session, town_placement_id)));
	}
	return gd::as_dict(field_or_new_dict(state, session_overworld(state, session), key::hero));
}

Atom _enemy_force_name_from_battle_army_id(State &state, DictRef battle, const Value &session) {
	const Atom army_id = gd::strip_edges(state, string_of(state, battle, key::enemy_army_id));
	if (army_id != key::empty) {
		const DictRef army = gd::content_row(state, ContentTable::ArmyGroup, army_id);
		const Atom army_name = gd::strip_edges(state, string_of(state, army, key::name));
		if (army_name != key::empty) {
			return army_name;
		}
	}
	if (_is_town_assault_context(state, field_or_new_dict(state, battle, key::context))
			|| _is_town_defense_context(state, field_or_new_dict(state, battle, key::context))) {
		const Value context = field_or_new_dict(state, battle, key::context);
		const Atom town_name = _town_name_from_placement_id(state, session, gd::stringify(state, ai::vget(state, context, key::town_placement_id, str(key::empty))));
		if (town_name != key::empty) {
			return gd::format(state, key::s_garrison, { str(town_name) });
		}
	}
	return key::empty;
}

DictRef _normalize_stack(State &state, const Value &stack_value) {
	if (!gd::is_dict(stack_value)) {
		return state.new_dict();
	}
	const DictRef stack = stack_value.ref;
	const Atom unit_id = string_of(state, stack, key::unit_id);
	if (unit_id == key::empty) {
		return state.new_dict();
	}
	const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
	if (gd::is_empty(state, unit)) {
		return state.new_dict();
	}
	// stack.get(field, unit.get(field, fallback)).
	const auto stack_or_unit = [&](Atom field, Atom unit_field, const Value &fallback) {
		return gd::field_or(state, stack, field, gd::field_or(state, unit, unit_field, fallback));
	};
	// Creature health is battle state, like total_health: Hardened Ranks raises
	// it when the battle starts. Content hp only fills in for stacks without it.
	const int64_t unit_hp = engine_max<int64_t>(1, gd::to_int(state, stack_or_unit(key::unit_hp, key::hp, int_value(1))));
	const int64_t cohesion_base = _cohesion_base_for_unit(state, unit);
	const DictRef normalized_hex = _normalize_hex_cell(state, field_or_new_dict(state, stack, key::hex));
	const Atom faction_id = gd::stringify(state, stack_or_unit(key::faction_id, key::faction_id, str(key::empty)));
	Atom affiliation = gd::stringify(state, stack_or_unit(key::affiliation, key::affiliation, str(key::empty)));
	if (affiliation == key::empty) {
		affiliation = faction_id != key::empty ? key::faction : key::neutral;
	}
	const DictRef normalized = state.new_dict();
	{
		const Atom default_id = gd::format(state, key::s_s_7, { str(text_or(state, stack, key::side, str(key::stack))), str(unit_id) });
		state.set(normalized, str(key::battle_id), str(text_or(state, stack, key::battle_id, str(default_id))));
	}
	state.set(normalized, str(key::side), str(text_or(state, stack, key::side, str(key::player))));
	state.set(normalized, str(key::battle_footprint), int_value(battle_footprint::width(state, stack)));
	state.set(normalized, str(key::battle_visual_scale),
			gd::float_value(engine_clamp<double>(gd::to_float(gd::field_or(state, stack, key::battle_visual_scale, gd::float_value(1.0))), 0.65, 1.6)));
	state.set(normalized, str(key::faction_id), str(faction_id));
	state.set(normalized, str(key::affiliation), str(affiliation));
	state.set(normalized, str(key::unit_id), str(unit_id));
	state.set(normalized, str(key::name), str(gd::stringify(state, stack_or_unit(key::name, key::name, str(unit_id)))));
	state.set(normalized, str(key::tier), int_value(clamp_int(gd::to_int(state, stack_or_unit(key::tier, key::tier, int_value(1))), 1, 7)));
	state.set(normalized, str(key::unit_hp), int_value(unit_hp));
	state.set(normalized, str(key::total_health),
			int_value(engine_max<int64_t>(0, int_or(state, stack, key::total_health, int_value(gd::mul(int_or(state, stack, key::base_count, int_value(0)), unit_hp))))));
	state.set(normalized, str(key::town_shield_hp), int_value(engine_max<int64_t>(0, int_or(state, stack, key::town_shield_hp, int_value(0)))));
	state.set(normalized, str(key::base_count), int_value(engine_max<int64_t>(0, int_or(state, stack, key::base_count, int_value(0)))));
	state.set(normalized, str(key::attack), int_value(gd::to_int(state, stack_or_unit(key::attack, key::attack, int_value(0)))));
	state.set(normalized, str(key::defense), int_value(gd::to_int(state, stack_or_unit(key::defense, key::defense, int_value(0)))));
	state.set(normalized, str(key::min_damage), int_value(gd::to_int(state, stack_or_unit(key::min_damage, key::min_damage, int_value(1)))));
	state.set(normalized, str(key::max_damage), int_value(gd::to_int(state, stack_or_unit(key::max_damage, key::max_damage, int_value(1)))));
	state.set(normalized, str(key::initiative), int_value(gd::to_int(state, stack_or_unit(key::initiative, key::initiative, int_value(1)))));
	state.set(normalized, str(key::speed), int_value(gd::to_int(state, stack_or_unit(key::speed, key::speed, int_value(1)))));
	state.set(normalized, str(key::ranged), bool_value(gd::to_bool(stack_or_unit(key::ranged, key::ranged, bool_value(false)))));
	state.set(normalized, str(key::retaliations),
			int_value(engine_max<int64_t>(0, gd::to_int(state, stack_or_unit(key::retaliations, key::retaliations, int_value(1))))));
	state.set(normalized, str(key::retaliations_left),
			int_value(engine_max<int64_t>(0, gd::to_int(state, stack_or_unit(key::retaliations_left, key::retaliations, int_value(1))))));
	state.set(normalized, str(key::shots_remaining),
			int_value(engine_max<int64_t>(0, gd::to_int(state, stack_or_unit(key::shots_remaining, key::shots, int_value(0))))));
	state.set(normalized, str(key::spell_resistance_pct),
			int_value(clamp_int(gd::to_int(state, stack_or_unit(key::spell_resistance_pct, key::spell_resistance_pct, int_value(0))), 0, MAX_SPELL_RESISTANCE_PCT)));
	state.set(normalized, str(key::control_resistance_pct),
			int_value(clamp_int(gd::to_int(state, stack_or_unit(key::control_resistance_pct, key::control_resistance_pct, int_value(0))), 0, MAX_CONTROL_RESISTANCE_PCT)));
	state.set(normalized, str(key::spell_school_resistance_pct),
			dict_value(spell_rules::normalize_school_resistance(state,
					gd::field_or(state, stack, key::spell_school_resistance_pct, field_or_new_dict(state, unit, key::spell_school_resistance_pct)))));
	state.set(normalized, str(key::status_immunity_ids),
			array_value(spell_rules::normalize_status_immunity_ids(state,
					gd::field_or(state, stack, key::status_immunity_ids, field_or_new_array(state, unit, key::status_immunity_ids)))));
	state.set(normalized, str(key::defending), bool_value(gd::to_bool(gd::field_or(state, stack, key::defending, bool_value(false)))));
	state.set(normalized, str(key::cohesion_base), int_value(clamp_int(int_or(state, stack, key::cohesion_base, int_value(cohesion_base)), COHESION_MIN, COHESION_MAX)));
	state.set(normalized, str(key::cohesion),
			int_value(clamp_int(int_or(state, stack, key::cohesion, gd::field_or(state, stack, key::cohesion_base, int_value(cohesion_base))), COHESION_MIN, COHESION_MAX)));
	state.set(normalized, str(key::momentum), int_value(clamp_int(int_or(state, stack, key::momentum, int_value(0)), 0, MOMENTUM_MAX)));
	state.set(normalized, str(key::hex), dict_value(normalized_hex));
	state.set(normalized, str(key::abilities), array_value(_normalize_unit_abilities(state, field_or_new_array(state, unit, key::abilities))));
	{
		const Value ability_uses = field_or_new_dict(state, stack, key::ability_uses);
		state.set(normalized, str(key::ability_uses), dict_value(gd::is_dict(ability_uses) ? gd::deep_duplicate_dict(state, ability_uses.ref) : state.new_dict()));
		const Value effects = field_or_new_array(state, stack, key::effects);
		state.set(normalized, str(key::effects), array_value(gd::is_array(effects) ? gd::deep_duplicate_array(state, effects.ref) : state.new_array()));
	}
	state.set(normalized, str(key::source_type), str(string_of(state, stack, key::source_type)));
	state.set(normalized, str(key::source_hero_id), str(string_of(state, stack, key::source_hero_id)));
	state.set(normalized, str(key::source_town_placement_id), str(string_of(state, stack, key::source_town_placement_id)));
	state.set(normalized, str(key::source_encounter_key), str(string_of(state, stack, key::source_encounter_key)));
	// Surviving stacks return to their original army slots after disk resume.
	const int64_t army_slot_index = int_or(state, stack, key::army_slot_index, int_value(-1));
	if (army_slot_index >= 0 && army_slot_index < ARMY_SLOT_COUNT) {
		state.set(normalized, str(key::army_slot_index), int_value(army_slot_index));
	}
	return normalized;
}

ArrayRef _normalize_battle_obstacles(State &state, const Value &value) {
	const ArrayRef normalized = state.new_array();
	if (!gd::is_array(value)) {
		return normalized;
	}
	const DictRef taken = state.new_dict();
	for (const Value &entry : gd::items(state, value)) {
		if (!gd::is_dict(entry)) {
			continue;
		}
		const ArrayRef cells = state.new_array();
		for (const Value &cell_value : gd::field_items(state, entry.ref, str(key::cells))) {
			const DictRef cell = _normalize_hex_cell(state, cell_value);
			if (gd::is_empty(state, cell) || state.has(taken, str(_hex_key(state, cell)))) {
				continue;
			}
			state.append(cells, dict_value(cell));
		}
		if (state.array_size(cells) == 0) {
			continue;
		}
		for (int64_t index = 0; index < state.array_size(cells); ++index) {
			state.set(taken, str(_hex_key(state, gd::as_dict(state.at(cells, index)))), bool_value(true));
		}
		const Atom kind = text_or(state, entry.ref, key::kind, str(key::rock));
		const DictRef obstacle = state.new_dict();
		state.set(obstacle, str(key::id),
				str(text_or(state, entry.ref, key::id, str(gd::format(state, key::o_d, { int_value(gd::add(state.array_size(normalized), 1)) })))));
		state.set(obstacle, str(key::kind), str(kind == key::rock || kind == key::deadwood ? kind : key::rock));
		state.set(obstacle, str(key::size), int_value(state.array_size(cells)));
		state.set(obstacle, str(key::variant), int_value(clamp_int(int_or(state, entry.ref, key::variant, int_value(0)), 0, OBSTACLE_VARIANT_COUNT - 1)));
		state.set(obstacle, str(key::cells), array_value(cells));
		state.append(normalized, dict_value(obstacle));
	}
	return normalized;
}

ArrayRef _normalize_waited_stack_ids(State &state, DictRef battle) {
	const ArrayRef normalized = state.new_array();
	const ArrayRef ids = waited_stack_ids(state, battle);
	for (int64_t index = 0; index < state.array_size(ids); ++index) {
		const Atom battle_id = gd::stringify(state, state.at(ids, index));
		if (battle_id != key::empty && !gd::array_has(state, normalized, str(battle_id)) && !gd::is_empty(state, _get_stack_by_id(state, battle, battle_id))) {
			state.append(normalized, str(battle_id));
		}
	}
	return normalized;
}

DictRef _normalize_tactical_briefing_state(State &state, const Value &value, const Value &session) {
	const DictRef battle = session_battle(state, session);
	const Atom signature = gd::format(state, key::s_bar_s, { str(string_of(state, battle, key::encounter_id)), str(string_of(state, battle, key::resolved_key)) });
	const DictRef previous = gd::is_dict(value) ? value.ref : state.new_dict();
	const DictRef briefing = state.new_dict();
	state.set(briefing, str(key::signature), str(signature));
	if (string_of(state, previous, key::signature) != signature) {
		state.set(briefing, str(key::shown), bool_value(false));
		state.set(briefing, str(key::shown_round), int_value(0));
	} else {
		state.set(briefing, str(key::shown), bool_value(gd::to_bool(gd::field_or(state, previous, key::shown, bool_value(false)))));
		state.set(briefing, str(key::shown_round), int_value(engine_max<int64_t>(0, int_or(state, previous, key::shown_round, int_value(0)))));
	}
	const Value recent_events = field_or_new_array(state, session_battle(state, session), key::recent_events);
	if (!gd::to_bool(gd::field_or(state, briefing, key::shown, bool_value(false)))
			&& (int_or(state, session_battle(state, session), key::round, int_value(1)) > 1
					|| (gd::is_array(recent_events) && state.array_size(recent_events.ref) != 0))) {
		state.set(briefing, str(key::shown), bool_value(true));
		state.set(briefing, str(key::shown_round), int_value(engine_max<int64_t>(1, int_or(state, session_battle(state, session), key::round, int_value(1)))));
	}
	return briefing;
}

} // namespace aurelion::rules::port::battle_rules
