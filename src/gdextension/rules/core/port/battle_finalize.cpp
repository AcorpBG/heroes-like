// Slice 09: the battle ends: a victory, a lost battle (the primary or another
// commander defeated, a defended town lost), a retreat, a surrender, an enemy's
// withdrawal and a stalemate; the encounter they resolve, its rewards and the
// exit animation snapshot.

#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/battle_rules_ai.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"

#include <algorithm>
#include <cstdint>
#include <initializer_list>
#include <string>
#include <string_view>

namespace aurelion::rules::port::battle_rules {

using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::Kind;
namespace key = state::key;

namespace {

// session.battle, session.flags and session.overworld: SessionData types them
// Dictionary. Read again at every use, as GDScript reads them.
DictRef session_battle(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::battle));
}

DictRef session_flags(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::flags));
}

DictRef session_overworld(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::overworld));
}

// session.scenario_status and the session's other String fields.
Atom session_text(State &state, const Value &session, Atom field) {
	return gd::to_string(gd::member(state, session, field));
}

// session == null or session.battle.is_empty()
bool no_battle(State &state, const Value &session) {
	return session.kind == Kind::Nil || gd::is_empty(state, session_battle(state, session));
}

// d.get(field, {}) of an untyped value: a new Dictionary when the key is missing.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// battle.get("context", {})
Value battle_context(State &state, DictRef battle) {
	return get_or_new_dict(state, battle, key::context);
}

// String(d.get(field, fallback)).
Atom text_field(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// String(x.get(field, fallback)) of an untyped value.
Atom vtext(State &state, const Value &object, Atom field, Atom fallback) {
	return gd::stringify(state, ai::vget(state, object, field, str(fallback)));
}

// separator.join(parts) of an Array: String.join takes it as a
// PackedStringArray, String(item) of every item, empty ones included.
Atom join_array(State &state, std::string_view separator, ArrayRef parts) {
	std::string joined;
	const int64_t size = state.array_size(parts);
	for (int64_t index = 0; index < size; ++index) {
		if (index > 0) {
			joined += separator;
		}
		joined += state.text(gd::stringify(state, state.at(parts, index)));
	}
	return state.intern(joined);
}

// [a, b, ...] of Strings: a new Array.
ArrayRef string_array(State &state, std::initializer_list<Atom> atoms) {
	const ArrayRef array = state.new_array();
	for (const Atom atom : atoms) {
		state.append(array, str(atom));
	}
	return array;
}

// {"ok": false, "message": message, "state": "invalid"}
DictRef refusal(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::state), str(key::invalid));
	return result;
}

// {"ok": true, "message": message, "state": result_state,
// "battle_exit_animation_snapshot": snapshot}
DictRef exit_result(State &state, Atom message, Atom result_state, DictRef snapshot) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::state), str(result_state));
	state.set(result, str(key::battle_exit_animation_snapshot), dict_value(snapshot));
	return result;
}

// {"state": result_state, "message": message}
DictRef state_and_message(State &state, Atom result_state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::state), str(result_state));
	state.set(result, str(key::message), str(message));
	return result;
}

// session.flags["last_battle_outcome"] = outcome
void set_last_outcome(State &state, const Value &session, Atom outcome) {
	state.set(session_flags(state, session), str(key::last_battle_outcome), str(outcome));
}

// session.battle = {}
void clear_battle(State &state, const Value &session) {
	gd::set_member(state, session, key::battle, dict_value(state.new_dict()));
}

// var scenario_result = ScenarioRules.evaluate_session(session)
// _append_nonempty_message(messages, String(scenario_result.get("message", "")))
// var final_message = " ".join(messages)
Atom evaluate_and_join(State &state, const Value &session, ArrayRef messages) {
	const DictRef scenario_result = scenario_rules::evaluate_session(state, gd::object_view(state, session));
	_append_nonempty_message(state, messages, text_field(state, scenario_result, key::message, key::empty));
	return join_array(state, " ", messages);
}

// if session.scenario_status == "in_progress" and final_message != "":
// 	session.flags["return_notice"] = final_message
void set_return_notice(State &state, const Value &session, Atom final_message) {
	if (session_text(state, session, key::scenario_status) == key::in_progress && final_message != key::empty) {
		state.set(session_flags(state, session), str(key::return_notice), str(final_message));
	}
}

// ANIMATION_STATE_PRIORITY.get(state, 1)
int64_t animation_state_priority(Atom anim_state) {
	if (anim_state == key::death_rout_remove) {
		return 100;
	}
	if (anim_state == key::retreat_withdraw_column || anim_state == key::surrender_stand_down) {
		return 95;
	}
	if (anim_state == key::retaliation_release) {
		return 86;
	}
	if (anim_state == key::status_expired) {
		return 85;
	}
	if (anim_state == key::status_applied) {
		return 84;
	}
	if (anim_state == key::hit_stagger) {
		return 80;
	}
	if (anim_state == key::melee_windup_release || anim_state == key::ranged_aim_release || anim_state == key::cast_support_anchor) {
		return 60;
	}
	if (anim_state == key::move_path_step) {
		return 58;
	}
	if (anim_state == key::defend_brace) {
		return 55;
	}
	if (anim_state == key::wait_hold) {
		return 54;
	}
	return 1;
}

// {"index": -1, "encounter": {}}
DictRef encounter_not_found(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::index), int_value(-1));
	state.set(result, str(key::encounter), dict_value(state.new_dict()));
	return result;
}

} // namespace

DictRef _synthetic_battle_encounter_placement(State &state, const Value &session, const Value &context) {
	if (no_battle(state, session)) {
		return state.new_dict();
	}
	const DictRef synthetic_context = gd::is_dict(context) ? context.ref : state.new_dict();
	const Value position = get_or_new_dict(state, session_battle(state, session), key::position);
	Atom placement_id = text_field(state, session_battle(state, session), key::resolved_key, key::empty);
	if (placement_id == key::empty && _is_town_assault_context(state, dict_value(synthetic_context))) {
		const Atom town_placement_id = text_field(state, synthetic_context, key::town_placement_id, key::empty);
		if (town_placement_id != key::empty) {
			placement_id = gd::format(state, key::town_assault_s, { str(town_placement_id) });
		}
	}
	const Atom encounter_id = text_field(state, session_battle(state, session), key::encounter_id, key::empty);
	const int64_t x = gd::to_int(state, ai::vget(state, position, key::x, int_value(overworld_rules::hero_position(state, gd::object_view(state, session)).x)));
	const int64_t y = gd::to_int(state, ai::vget(state, position, key::y, int_value(overworld_rules::hero_position(state, gd::object_view(state, session)).y)));
	const int64_t combat_seed = gd::int_field(state, session_battle(state, session), key::combat_seed, 0);
	const DictRef battle_context_copy = gd::deep_duplicate_dict(state, synthetic_context);
	const DictRef synthetic = state.new_dict();
	state.set(synthetic, str(key::placement_id), str(placement_id));
	state.set(synthetic, str(key::encounter_id), str(encounter_id));
	state.set(synthetic, str(key::x), int_value(x));
	state.set(synthetic, str(key::y), int_value(y));
	state.set(synthetic, str(key::combat_seed), int_value(combat_seed));
	state.set(synthetic, str(key::battle_context), dict_value(battle_context_copy));
	if (overworld_level_rules::level_of(state, position) != 0) {
		state.set(synthetic, str(key::level), int_value(overworld_level_rules::level_of(state, position)));
	}
	if (text_field(state, synthetic_context, key::trigger_player_id, key::empty) != key::empty) {
		state.set(synthetic, str(key::spawned_by_player_id), str(gd::stringify(state, gd::index(state, synthetic_context, str(key::trigger_player_id)))));
		state.set(synthetic, str(key::spawned_by_faction_id), str(text_field(state, synthetic_context, key::trigger_faction_id, key::empty)));
	}
	if (_is_resource_assault_context(state, dict_value(synthetic_context))) {
		state.set(synthetic, str(key::target_kind), str(key::resource));
		state.set(synthetic, str(key::target_placement_id), str(text_field(state, synthetic_context, key::resource_placement_id, key::empty)));
		state.set(synthetic, str(key::target_label), str(text_field(state, synthetic_context, key::resource_site_name, key::empty)));
		state.set(synthetic, str(key::spawned_by_faction_id), str(text_field(state, synthetic_context, key::trigger_faction_id, key::empty)));
	}
	return synthetic;
}

DictRef _find_encounter_by_key(State &state, const Value &session, Atom encounter_key) {
	if (session.kind == Kind::Nil || encounter_key == key::empty) {
		return encounter_not_found(state);
	}
	// The default [] has no encounters.
	Value encounters;
	if (state.lookup(session_overworld(state, session), str(key::encounters), encounters)) {
		const int64_t size = ai::vsize(state, encounters);
		for (int64_t index = 0; index < size; ++index) {
			const Value encounter = ai::vindex(state, encounters, int_value(index));
			if (gd::is_dict(encounter) && overworld_rules::encounter_key(state, encounter.ref) == encounter_key) {
				const DictRef result = state.new_dict();
				state.set(result, str(key::index), int_value(index));
				state.set(result, str(key::encounter), encounter);
				return result;
			}
		}
	}
	return encounter_not_found(state);
}

Atom _retreat_action_summary(State &state, const Value &session) {
	if (no_battle(state, session)) {
		return key::no_battle_is_active_text;
	}
	const DictRef battle = session_battle(state, session);
	if (_is_town_defense_context(state, battle_context(state, battle))) {
		return key::retreat_is_locked_while_defending_a;
	}
	if (!_battle_retreat_allowed(state, battle)) {
		return key::retreat_is_locked_in_this_battle;
	}
	const DictRef player_totals = _army_totals(state, battle, key::player);
	const int64_t stacks = gd::int_field(state, player_totals, key::stacks, 0);
	const ArrayRef clauses = string_array(state, {
			gd::format(state, key::break_contact_and_preserve_d_surviving, { int_value(stacks), str(stacks == 1 ? key::empty : key::s) }),
	});
	const DictRef preview = _build_withdrawal_aftermath_preview(state, session, key::retreat);
	const Atom aftermath_summary = _withdrawal_preview_summary(state, preview, key::retreat);
	if (aftermath_summary != key::empty) {
		state.append(clauses, str(aftermath_summary));
	}
	return gd::format(state, key::s_4, { str(join_array(state, " | ", clauses)) });
}

Atom _surrender_action_summary(State &state, const Value &session) {
	if (no_battle(state, session)) {
		return key::no_battle_is_active_text;
	}
	if (_is_town_defense_context(state, battle_context(state, session_battle(state, session)))) {
		return key::surrender_is_locked_while_defending_a;
	}
	if (!_battle_surrender_allowed(state, session_battle(state, session))) {
		return key::surrender_is_locked_in_this_battle;
	}
	const DictRef player_totals = _army_totals(state, session_battle(state, session), key::player);
	const int64_t stacks = gd::int_field(state, player_totals, key::stacks, 0);
	const ArrayRef clauses = string_array(state, {
			gd::format(state, key::yield_the_field_and_preserve_d, { int_value(stacks), str(stacks == 1 ? key::empty : key::s) }),
	});
	const DictRef preview = _build_withdrawal_aftermath_preview(state, session, key::surrender);
	const Atom aftermath_summary = _withdrawal_preview_summary(state, preview, key::surrender);
	if (aftermath_summary != key::empty) {
		state.append(clauses, str(aftermath_summary));
	}
	return gd::format(state, key::s_4, { str(join_array(state, " | ", clauses)) });
}

DictRef _current_battle_encounter_placement(State &state, const Value &session) {
	if (no_battle(state, session)) {
		return state.new_dict();
	}
	const DictRef found = _find_encounter_by_key(state, session, text_field(state, session_battle(state, session), key::resolved_key, key::empty));
	const DictRef encounter = gd::as_dict(gd::field(state, found, key::encounter));
	if (!gd::is_empty(state, encounter)) {
		return encounter;
	}
	return _synthetic_battle_encounter_placement(state, session, battle_context(state, session_battle(state, session)));
}

ArrayRef _beaten_enemy_stacks(State &state, DictRef battle) {
	const ArrayRef beaten = state.new_array();
	for (const Value &stack_value : gd::field_items(state, battle, str(key::stacks))) {
		if (!gd::is_dict(stack_value) || text_field(state, stack_value.ref, key::side, key::empty) != key::enemy) {
			continue;
		}
		const int64_t count = std::max<int64_t>(0, gd::sub(gd::int_field(state, stack_value.ref, key::base_count, 0), _alive_count(state, stack_value.ref)));
		if (count > 0) {
			const DictRef entry = state.new_dict();
			state.set(entry, str(key::unit_id), str(text_field(state, stack_value.ref, key::unit_id, key::empty)));
			state.set(entry, str(key::count), int_value(count));
			state.append(beaten, dict_value(entry));
		}
	}
	return beaten;
}

DictRef _battle_victory_rewards(State &state, const Value &session, DictRef encounter) {
	const DictRef battle = session_battle(state, session);
	const ArrayRef beaten = _beaten_enemy_stacks(state, battle);
	const Value commander = get_or_new_dict(state, battle, key::enemy_hero);
	const DictRef rewards = battle_rewards_for_strength(state, encounter, array_value(beaten), commander);
	return difficulty_rules::scale_reward_resources(state, gd::object_view(state, session), dict_value(rewards));
}

DictRef _finalize_victory(State &state, const Value &session) {
	DictRef snapshot_context;
	Value context_value;
	if (state.lookup(session_battle(state, session), str(key::context), context_value) && gd::is_dict(context_value)) {
		snapshot_context = gd::deep_duplicate_dict(state, context_value.ref);
	} else {
		snapshot_context = state.new_dict();
	}
	const DictRef encounter_snapshot = _battle_resolution_static_encounter_snapshot(state, session);
	const DictRef resolution_context_snapshot = state.new_dict();
	state.set(resolution_context_snapshot, str(key::context), dict_value(snapshot_context));
	state.set(resolution_context_snapshot, str(key::encounter), dict_value(encounter_snapshot));
	state.set(resolution_context_snapshot, str(key::resolution_state), str(key::victory));
	state.set(resolution_context_snapshot, str(key::snapshot_policy), str(key::pre_resolution_route_context));

	const ArrayRef messages = state.new_array();
	Atom base_summary = _apply_battle_context_victory(state, session);
	if (base_summary == key::empty) {
		base_summary = key::the_enemy_host_breaks_and_the;
	}
	state.append(messages, str(base_summary));
	if (!_is_town_assault_context(state, battle_context(state, session_battle(state, session)))) {
		_mark_resolved_encounter(state, session, text_field(state, session_battle(state, session), key::resolved_key, key::empty));
	}

	const DictRef encounter = gd::content_row(state, state::ContentTable::Encounter, text_field(state, session_battle(state, session), key::encounter_id, key::empty));
	const DictRef victory_rewards = _battle_victory_rewards(state, session, encounter);
	const int64_t reward_bonus_pct = gd::int_field(state, _hero_payload_for_side(state, session_battle(state, session), key::player), key::reward_bonus_pct, 0);
	const DictRef rewards = overworld_rules::apply_reward_bonus(state, dict_value(victory_rewards), reward_bonus_pct);
	overworld_rules::_add_resources(state, gd::object_view(state, session), dict_value(rewards));
	const Atom reward_summary = overworld_rules::_describe_resource_delta(state, dict_value(rewards));
	const Atom reward_detail = overworld_rules::_describe_reward_delta(state, dict_value(rewards));
	if (reward_summary != key::empty) {
		state.append(messages, str(gd::format(state, key::battle_rewards_s, { str(reward_summary) })));
	}
	const int64_t experience_amount = std::max<int64_t>(0, gd::int_field(state, rewards, key::experience, 0));
	if (experience_amount > 0) {
		const Atom hero_name = text_field(state, _player_commander_state(state, session), key::name, key::the_commander);
		const int64_t gained = hero_progression_rules::experience_with_bonus(state, _player_commander_state(state, session), experience_amount);
		state.append(messages, str(gd::format(state, key::s_gains_d_experience, { str(hero_name), int_value(gained) })));
	}
	ai::append_array(state, messages, _award_commander_experience(state, session, experience_amount));
	const int64_t recovered = _apply_victory_recovery(state, session_battle(state, session), key::player);
	if (recovered > 0) {
		state.append(messages, str(gd::format(state, key::field_surgeons_return_d_fallen_creature, { int_value(recovered), str(recovered == 1 ? key::empty : key::s) })));
	}
	const DictRef commander_after = gd::deep_duplicate_dict(state, _player_commander_state(state, session));
	const int64_t mana_regained = _apply_victory_mana(state, commander_after, session_battle(state, session), key::player);
	if (mana_regained > 0) {
		state.set(session_battle(state, session), str(key::player_commander_state), dict_value(commander_after));
		state.append(messages, str(gd::format(state, key::s_draws_d_mana_from_the, { str(text_field(state, commander_after, key::name, key::the_commander)), int_value(mana_regained) })));
	}
	_sync_player_force_from_battle(state, session);
	const DictRef artifact_salvage = _apply_player_battle_salvage_reward(state, session);
	_append_nonempty_message(state, messages, text_field(state, artifact_salvage, key::message, key::empty));
	const DictRef front_result = _apply_victory_front_aftermath(state, session);
	_append_nonempty_message(state, messages, text_field(state, front_result, key::summary, key::empty));
	const Atom commander_aftermath = _resolve_enemy_commander_aftermath(state, session, key::defeated);
	_finish_enemy_battle_task_assignment(state, session, key::failed, key::invalid_battle_defeat);
	_append_nonempty_message(state, messages, commander_aftermath);
	const Atom delivery_summary = _apply_delivery_route_aftermath(state, session, key::victory);
	_append_nonempty_message(state, messages, delivery_summary);
	_sync_enemy_force_from_battle(state, session, true);
	hero_command_rules::commit_active_hero(state, gd::object_view(state, session));
	overworld_rules::refresh_fog_of_war(state, gd::object_view(state, session));

	_apply_encounter_victory_flags(state, session, encounter);

	set_last_outcome(state, session, key::victory);
	const DictRef details = state.new_dict();
	state.set(details, str(key::resource_summary), str(reward_summary != key::empty ? gd::format(state, key::battle_rewards_s, { str(reward_summary) }) : key::empty));
	state.set(details, str(key::reward_summary), str(reward_detail != key::empty ? gd::format(state, key::rewards_s, { str(reward_detail) }) : key::empty));
	state.set(details, str(key::artifact_summary), str(text_field(state, artifact_salvage, key::message, key::empty)));
	state.set(details, str(key::pressure_summary), str(text_field(state, front_result, key::summary, key::empty)));
	state.set(details, str(key::recovery_summary), str(commander_aftermath));
	state.set(details, str(key::logistics_summary), str(delivery_summary));
	_record_battle_aftermath(state, session, key::victory, base_summary, details);
	clear_battle(state, session);
	const Atom final_message = evaluate_and_join(state, session, messages);
	set_return_notice(state, session, final_message);
	const DictRef result = state.new_dict();
	state.set(result, str(key::state), str(key::victory));
	state.set(result, str(key::message), str(final_message));
	state.set(result, str(key::battle_resolution_context_snapshot), dict_value(resolution_context_snapshot));
	return result;
}

DictRef _battle_resolution_static_encounter_snapshot(State &state, const Value &session) {
	if (no_battle(state, session)) {
		return state.new_dict();
	}
	// A context that is missing or not a Dictionary is {}, whose type is "".
	Value context;
	if (!state.lookup(session_battle(state, session), str(key::context), context) || !gd::is_dict(context)
			|| text_field(state, context.ref, key::type, key::empty) != key::encounter) {
		return state.new_dict();
	}
	const DictRef encounter = _current_battle_encounter_placement(state, session);
	const Atom placement_id = gd::strip_edges(state, text_field(state, encounter, key::placement_id, key::empty));
	const Value id_fallback = state.get(encounter, str(key::id), str(key::empty));
	const Atom encounter_id = gd::strip_edges(state, gd::stringify(state, state.get(encounter, str(key::encounter_id), id_fallback)));
	if (placement_id == key::empty || encounter_id == key::empty
			|| gd::strip_edges(state, text_field(state, encounter, key::spawned_by_faction_id, key::empty)) != key::empty) {
		return state.new_dict();
	}
	const DictRef snapshot = state.new_dict();
	state.set(snapshot, str(key::placement_id), str(placement_id));
	state.set(snapshot, str(key::encounter_id), str(encounter_id));
	state.set(snapshot, str(key::x), int_value(gd::int_field(state, encounter, key::x, -1)));
	state.set(snapshot, str(key::y), int_value(gd::int_field(state, encounter, key::y, -1)));
	state.set(snapshot, str(key::spawned_by_faction_id), str(key::empty));
	return snapshot;
}

DictRef _finalize_player_battle_loss(State &state, const Value &session) {
	if (_is_town_defense_context(state, battle_context(state, session_battle(state, session)))) {
		return _finalize_town_defense_loss(state, session);
	}
	if (hero_command_rules::active_hero_is_primary(state, gd::object_view(state, session))) {
		if (!player_elimination_rules::applies(state, gd::object_view(state, session))) {
			if (_is_town_assault_context(state, battle_context(state, session_battle(state, session)))) {
				return _finalize_primary_defeat(state, session, key::the_assault_collapses_beneath_the_walls, key::defeat);
			}
			return _finalize_primary_defeat(state, session, key::the_field_army_collapses_and_the, key::defeat);
		}
		// On a generated map losing the starting hero does not end the game:
		// another hero leads.
		hero_command_rules::hand_over_primary(state, gd::object_view(state, session), text_field(state, session_overworld(state, session), key::active_hero_id, key::empty));
	}
	return _finalize_secondary_hero_defeat(state, session);
}

DictRef _finalize_primary_defeat(State &state, const Value &session, Atom base_summary, Atom outcome_id) {
	_sync_player_force_from_battle(state, session);
	_record_enemy_commander_battle_continuity(state, session, key::rout_victory);
	_finish_enemy_battle_task_assignment(state, session, key::completed, key::valid);
	const Atom commander_summary = _enemy_commander_exit_reaction(state, session, key::rout_victory);
	_apply_enemy_victory_specialties(state, session);
	_sync_enemy_force_from_battle(state, session, false);
	Atom front_summary = key::empty;
	if (_is_town_assault_context(state, battle_context(state, session_battle(state, session)))) {
		front_summary = _stabilize_hostile_town_front(state, session, key::broken_assault, 2);
	}
	const DictRef collapse_aftermath = _apply_collapse_aftermath(state, session, outcome_id);
	const Atom delivery_summary = _apply_delivery_route_aftermath(state, session, outcome_id);
	overworld_rules::refresh_fog_of_war(state, gd::object_view(state, session));
	set_last_outcome(state, session, outcome_id);
	state.set(session_flags(state, session), str(key::campaign), str(key::defeat));
	if (session_text(state, session, key::scenario_status) == key::in_progress) {
		gd::set_member(state, session, key::scenario_status, str(key::defeat));
		if (session_text(state, session, key::scenario_summary) == key::empty) {
			gd::set_member(state, session, key::scenario_summary, str(key::the_primary_commander_is_defeated));
		}
	}
	const DictRef details = state.new_dict();
	state.set(details, str(key::display_outcome), str(key::rout));
	state.set(details, str(key::resource_summary), str(text_field(state, collapse_aftermath, key::resource_summary, key::empty)));
	state.set(details, str(key::pressure_summary), str(text_field(state, collapse_aftermath, key::pressure_summary, key::empty)));
	state.set(details, str(key::recovery_summary), str(text_field(state, collapse_aftermath, key::recovery_summary, key::empty)));
	state.set(details, str(key::front_summary), str(front_summary));
	state.set(details, str(key::logistics_summary), str(delivery_summary));
	state.set(details, str(key::commander_summary), str(commander_summary));
	_record_battle_aftermath(state, session, outcome_id, base_summary, details);
	clear_battle(state, session);
	const DictRef scenario_result = scenario_rules::evaluate_session(state, gd::object_view(state, session));
	const ArrayRef parts = string_array(state, {
			base_summary,
			text_field(state, collapse_aftermath, key::summary, key::empty),
			commander_summary,
			front_summary,
			delivery_summary,
			text_field(state, scenario_result, key::message, key::empty),
	});
	const Atom final_message = _join_messages(state, parts);
	return state_and_message(state, key::defeat, final_message);
}

DictRef _finalize_secondary_hero_defeat(State &state, const Value &session) {
	_record_enemy_commander_battle_continuity(state, session, key::rout_victory);
	_finish_enemy_battle_task_assignment(state, session, key::completed, key::valid);
	const Atom commander_summary = _enemy_commander_exit_reaction(state, session, key::rout_victory);
	_apply_enemy_victory_specialties(state, session);
	_sync_enemy_force_from_battle(state, session, false);
	Atom front_summary = key::empty;
	if (_is_town_assault_context(state, battle_context(state, session_battle(state, session)))) {
		front_summary = _stabilize_hostile_town_front(state, session, key::broken_assault, 2);
	}
	const DictRef collapse_aftermath = _apply_collapse_aftermath(state, session, key::hero_defeat);
	const Atom delivery_summary = _apply_delivery_route_aftermath(state, session, key::hero_defeat);
	const DictRef removal = hero_command_rules::remove_active_hero_after_defeat(state, gd::object_view(state, session));
	set_last_outcome(state, session, key::hero_defeat);
	const ArrayRef messages = string_array(state, { text_field(state, removal, key::message, key::a_commander_falls_in_battle) });
	_append_nonempty_message(state, messages, text_field(state, collapse_aftermath, key::summary, key::empty));
	_append_nonempty_message(state, messages, commander_summary);
	_append_nonempty_message(state, messages, front_summary);
	_append_nonempty_message(state, messages, delivery_summary);
	const Atom next_active_name = text_field(state, removal, key::next_active_name, key::empty);
	if (next_active_name != key::empty) {
		state.append(messages, str(gd::format(state, key::s_takes_command, { str(next_active_name) })));
	}
	const DictRef details = state.new_dict();
	state.set(details, str(key::display_outcome), str(key::rout));
	state.set(details, str(key::resource_summary), str(text_field(state, collapse_aftermath, key::resource_summary, key::empty)));
	state.set(details, str(key::pressure_summary), str(text_field(state, collapse_aftermath, key::pressure_summary, key::empty)));
	state.set(details, str(key::recovery_summary), str(text_field(state, collapse_aftermath, key::recovery_summary, key::empty)));
	state.set(details, str(key::front_summary), str(front_summary));
	state.set(details, str(key::logistics_summary), str(delivery_summary));
	state.set(details, str(key::commander_summary), str(commander_summary));
	_record_battle_aftermath(state, session, key::hero_defeat, gd::stringify(state, state.at(messages, 0)), details);
	clear_battle(state, session);
	overworld_rules::refresh_fog_of_war(state, gd::object_view(state, session));
	// On a generated map the game ends only when no town and no hero is left.
	if (player_elimination_rules::applies(state, gd::object_view(state, session))
			&& session_text(state, session, key::scenario_status) == key::in_progress
			&& player_elimination_rules::human_has_nothing_left(state, gd::object_view(state, session))) {
		state.set(session_flags(state, session), str(key::campaign), str(key::defeat));
		gd::set_member(state, session, key::scenario_status, str(key::defeat));
		gd::set_member(state, session, key::scenario_summary, str(key::your_realm_has_no_town_and));
	}
	const Atom final_message = evaluate_and_join(state, session, messages);
	set_return_notice(state, session, final_message);
	return state_and_message(state, session_text(state, session, key::scenario_status) == key::defeat ? key::defeat : key::hero_defeat, final_message);
}

DictRef _finalize_retreat(State &state, const Value &session) {
	if (_is_town_defense_context(state, battle_context(state, session_battle(state, session)))) {
		return refusal(state, key::town_defenders_cannot_retreat_text);
	}
	const DictRef exit_animation_snapshot = _battle_exit_animation_snapshot(state, session_battle(state, session), key::retreat);
	Atom base_summary = key::the_army_withdraws_from_battle;
	if (_is_town_assault_context(state, battle_context(state, session_battle(state, session)))) {
		base_summary = key::the_assault_breaks_off_from_the;
	}
	const ArrayRef messages = string_array(state, { base_summary });
	_sync_player_force_from_battle(state, session);
	_record_enemy_commander_battle_continuity(state, session, key::pursuit_victory);
	_finish_enemy_battle_task_assignment(state, session, key::completed, key::valid);
	const Atom commander_summary = _enemy_commander_exit_reaction(state, session, key::pursuit_victory);
	_apply_enemy_victory_specialties(state, session);
	_sync_enemy_force_from_battle(state, session, false);
	Atom front_summary = key::empty;
	if (_is_town_assault_context(state, battle_context(state, session_battle(state, session)))) {
		front_summary = _stabilize_hostile_town_front(state, session, key::withdrawn_assault, 1);
		_append_nonempty_message(state, messages, front_summary);
	}
	const DictRef aftermath = _apply_withdrawal_aftermath(state, session, key::retreat);
	_append_nonempty_message(state, messages, text_field(state, aftermath, key::summary, key::empty));
	_append_nonempty_message(state, messages, commander_summary);
	const Atom delivery_summary = _apply_delivery_route_aftermath(state, session, key::retreat);
	_append_nonempty_message(state, messages, delivery_summary);
	hero_command_rules::commit_active_hero(state, gd::object_view(state, session));
	overworld_rules::refresh_fog_of_war(state, gd::object_view(state, session));
	set_last_outcome(state, session, key::retreat);
	const DictRef retreat_details = gd::deep_duplicate_dict(state, aftermath);
	state.set(retreat_details, str(key::display_outcome), str(key::withdrawal));
	state.set(retreat_details, str(key::front_summary), str(front_summary));
	state.set(retreat_details, str(key::logistics_summary), str(delivery_summary));
	state.set(retreat_details, str(key::commander_summary), str(commander_summary));
	_record_battle_aftermath(state, session, key::retreat, base_summary, retreat_details);
	clear_battle(state, session);
	const Atom final_message = evaluate_and_join(state, session, messages);
	set_return_notice(state, session, final_message);
	return exit_result(state, final_message, key::retreat, exit_animation_snapshot);
}

DictRef _finalize_surrender(State &state, const Value &session) {
	if (_is_town_defense_context(state, battle_context(state, session_battle(state, session)))) {
		return refusal(state, key::town_defenders_cannot_surrender_text);
	}
	const DictRef exit_animation_snapshot = _battle_exit_animation_snapshot(state, session_battle(state, session), key::surrender);
	Atom base_summary = key::the_commander_lowers_the_banners_and;
	if (_is_town_assault_context(state, battle_context(state, session_battle(state, session)))) {
		base_summary = key::the_commander_yields_the_assault_beneath;
	}
	const ArrayRef messages = string_array(state, { base_summary });
	_sync_player_force_from_battle(state, session);
	_record_enemy_commander_battle_continuity(state, session, key::capitulation);
	_finish_enemy_battle_task_assignment(state, session, key::completed, key::valid);
	const Atom commander_summary = _enemy_commander_exit_reaction(state, session, key::capitulation);
	_apply_enemy_victory_specialties(state, session);
	_sync_enemy_force_from_battle(state, session, false);
	Atom front_summary = key::empty;
	if (_is_town_assault_context(state, battle_context(state, session_battle(state, session)))) {
		front_summary = _stabilize_hostile_town_front(state, session, key::yielded_assault, 2);
		_append_nonempty_message(state, messages, front_summary);
	}
	const DictRef aftermath = _apply_withdrawal_aftermath(state, session, key::surrender);
	_append_nonempty_message(state, messages, text_field(state, aftermath, key::summary, key::empty));
	_append_nonempty_message(state, messages, commander_summary);
	const Atom delivery_summary = _apply_delivery_route_aftermath(state, session, key::surrender);
	_append_nonempty_message(state, messages, delivery_summary);
	hero_command_rules::commit_active_hero(state, gd::object_view(state, session));
	overworld_rules::refresh_fog_of_war(state, gd::object_view(state, session));
	set_last_outcome(state, session, key::surrender);
	const DictRef surrender_details = gd::deep_duplicate_dict(state, aftermath);
	state.set(surrender_details, str(key::front_summary), str(front_summary));
	state.set(surrender_details, str(key::logistics_summary), str(delivery_summary));
	state.set(surrender_details, str(key::commander_summary), str(commander_summary));
	_record_battle_aftermath(state, session, key::surrender, base_summary, surrender_details);
	clear_battle(state, session);
	const Atom final_message = evaluate_and_join(state, session, messages);
	set_return_notice(state, session, final_message);
	return exit_result(state, final_message, key::surrender, exit_animation_snapshot);
}

DictRef _finalize_enemy_withdrawal(State &state, const Value &session, Atom outcome_id) {
	if (no_battle(state, session)) {
		return refusal(state, key::no_battle_is_active_text);
	}
	const Value context = battle_context(state, session_battle(state, session));
	if (_is_town_defense_context(state, context) || _is_town_assault_context(state, context)) {
		return refusal(state, key::enemy_withdrawal_is_locked_for_town);
	}
	const bool surrendered = outcome_id == key::enemy_surrender;
	const Atom event_outcome = surrendered ? key::surrender : key::retreat;
	const DictRef exit_animation_snapshot = _battle_exit_animation_snapshot(state, session_battle(state, session), event_outcome);
	const Atom base_summary = surrendered ? key::the_enemy_host_lowers_its_banners : key::the_enemy_host_withdraws_and_concedes;
	const ArrayRef messages = string_array(state, { base_summary });
	const DictRef encounter = gd::content_row(state, state::ContentTable::Encounter, text_field(state, session_battle(state, session), key::encounter_id, key::empty));
	const DictRef rewards = _battle_victory_rewards(state, session, encounter);
	// Award experience before the force sync copies the commander back to the
	// overworld; awarding afterwards only updated the discarded battle copy.
	const ArrayRef experience_messages = state.new_array();
	const int64_t experience_amount = std::max<int64_t>(0, gd::int_field(state, rewards, key::experience, 0));
	if (experience_amount > 0) {
		const Atom hero_name = text_field(state, _player_commander_state(state, session), key::name, key::the_commander);
		state.append(experience_messages, str(gd::format(state, key::s_gains_d_experience, { str(hero_name), int_value(experience_amount) })));
		ai::append_array(state, experience_messages, _award_commander_experience(state, session, experience_amount));
	}
	_sync_player_force_from_battle(state, session);
	const Atom enemy_faction_id = _battle_enemy_faction_id(state, session);
	const Atom front_summary = _apply_front_pressure_shift(state, session, enemy_faction_id, -1, key::victory);
	_append_nonempty_message(state, messages, front_summary);
	const Atom commander_summary = _resolve_enemy_commander_aftermath(state, session, key::stalemate);
	_finish_enemy_battle_task_assignment(state, session, key::failed, key::invalid_battle_withdrawal);
	_append_nonempty_message(state, messages, commander_summary);
	const Atom delivery_summary = _apply_delivery_route_aftermath(state, session, key::victory);
	_append_nonempty_message(state, messages, delivery_summary);
	_sync_enemy_force_from_battle(state, session, true);
	overworld_rules::_add_resources(state, gd::object_view(state, session), dict_value(rewards));
	const Atom reward_summary = overworld_rules::_describe_resource_delta(state, dict_value(rewards));
	if (reward_summary != key::empty) {
		state.append(messages, str(gd::format(state, key::battle_rewards_s, { str(reward_summary) })));
	}
	ai::append_array(state, messages, experience_messages);
	hero_command_rules::commit_active_hero(state, gd::object_view(state, session));
	overworld_rules::refresh_fog_of_war(state, gd::object_view(state, session));
	_apply_encounter_victory_flags(state, session, encounter);
	set_last_outcome(state, session, outcome_id);
	const DictRef details = state.new_dict();
	state.set(details, str(key::display_outcome), str(surrendered ? key::surrender : key::withdrawal));
	state.set(details, str(key::resource_summary), str(reward_summary != key::empty ? gd::format(state, key::battle_rewards_s, { str(reward_summary) }) : key::empty));
	state.set(details, str(key::pressure_summary), str(front_summary));
	state.set(details, str(key::recovery_summary), str(commander_summary));
	state.set(details, str(key::logistics_summary), str(delivery_summary));
	_record_battle_aftermath(state, session, outcome_id, base_summary, details);
	clear_battle(state, session);
	const Atom final_message = evaluate_and_join(state, session, messages);
	set_return_notice(state, session, final_message);
	return exit_result(state, final_message, key::victory, exit_animation_snapshot);
}

void _apply_encounter_victory_flags(State &state, const Value &session, DictRef encounter) {
	if (session.kind == Kind::Nil) {
		return;
	}
	// The default [] is an Array without flags.
	Value victory_flags;
	if (!state.lookup(encounter, str(key::victory_flags), victory_flags) || !gd::is_array(victory_flags)) {
		return;
	}
	const DictRef flags = session_flags(state, session);
	for (const Value &flag_value : gd::items(state, victory_flags)) {
		state.set(flags, str(gd::stringify(state, flag_value)), bool_value(true));
	}
}

DictRef _finalize_stalemate(State &state, const Value &session) {
	const ArrayRef messages = state.new_array();
	Atom base_summary = _apply_battle_context_stalemate(state, session);
	if (base_summary == key::empty) {
		base_summary = key::both_armies_disengage_before_a_decisive;
	}
	state.append(messages, str(base_summary));
	_sync_player_force_from_battle(state, session);
	_record_enemy_commander_battle_continuity(state, session, key::stalemate);
	_finish_enemy_battle_task_assignment(state, session, key::suspended, key::battle_stalemate);
	_sync_enemy_force_from_battle(state, session, false);
	const Atom delivery_summary = _apply_delivery_route_aftermath(state, session, key::stalemate);
	_append_nonempty_message(state, messages, delivery_summary);
	hero_command_rules::commit_active_hero(state, gd::object_view(state, session));
	overworld_rules::refresh_fog_of_war(state, gd::object_view(state, session));
	set_last_outcome(state, session, key::stalemate);
	const DictRef details = state.new_dict();
	state.set(details, str(key::logistics_summary), str(delivery_summary));
	_record_battle_aftermath(state, session, key::stalemate, base_summary, details);
	clear_battle(state, session);
	const Atom final_message = evaluate_and_join(state, session, messages);
	set_return_notice(state, session, final_message);
	return state_and_message(state, key::stalemate, final_message);
}

DictRef _finalize_town_defense_loss(State &state, const Value &session) {
	const Value context = battle_context(state, session_battle(state, session));
	const ArrayRef messages = state.new_array();
	const Atom defender_owner = gd::is_dict(context) ? text_field(state, context.ref, key::defender_owner, key::player) : key::player;
	const Atom town_name = _town_name_from_placement_id(state, session, vtext(state, context, key::town_placement_id, key::empty));
	const Atom base_summary = town_name != key::empty ? gd::format(state, key::s_falls_after_the_walls_are, { str(town_name) }) : key::the_town_falls_after_the_walls;
	Atom defending_hero_id = key::empty;
	{
		Value commander_source;
		if (state.lookup(session_battle(state, session), str(key::player_commander_source), commander_source)) {
			defending_hero_id = vtext(state, commander_source, key::hero_id, key::empty);
		}
	}
	_sync_player_force_from_battle(state, session);
	const DictRef survivor_filters = state.new_dict();
	state.set(survivor_filters, str(key::source_type), str(key::encounter_army));
	state.set(survivor_filters, str(key::encounter_key), str(text_field(state, session_battle(state, session), key::resolved_key, key::empty)));
	const ArrayRef enemy_survivors = _battle_survivor_stacks(state, session, key::enemy, survivor_filters);
	// An enemy hero takes the town and stays a hero with its surviving army;
	// only armies without a hero become the new garrison.
	const DictRef attacker_result = _find_encounter_by_key(state, session, text_field(state, session_battle(state, session), key::resolved_key, key::empty));
	const DictRef attacker = gd::as_dict(gd::field(state, attacker_result, key::encounter));
	const bool hero_attacker = gd::is_dict(gd::field(state, attacker, key::ai_hero));
	_capture_town_after_assault(state, session, vtext(state, context, key::town_placement_id, key::empty), hero_attacker ? state.new_array() : enemy_survivors);
	const Atom recovery_message = _apply_town_defense_recovery(state, session, key::loss);
	if (!hero_attacker) {
		_mark_resolved_encounter(state, session, text_field(state, session_battle(state, session), key::resolved_key, key::empty));
	}
	_set_enemy_siege_progress(state, session, _battle_context_controller_id(state, session, gd::as_dict(context), dict_value(state.new_dict())), 0);
	Atom commander_aftermath = key::empty;
	if (hero_attacker) {
		commander_aftermath = _keep_enemy_hero_after_town_capture(state, session, vtext(state, context, key::town_placement_id, key::empty), enemy_survivors);
	} else {
		commander_aftermath = _station_enemy_commander_after_town_capture(state, session, vtext(state, context, key::town_placement_id, key::empty), enemy_survivors);
	}
	_finish_enemy_battle_task_assignment(state, session, key::completed, key::valid);
	state.append(messages, str(base_summary));
	_append_nonempty_message(state, messages, recovery_message);
	_append_nonempty_message(state, messages, commander_aftermath);
	const Atom delivery_summary = _apply_delivery_route_aftermath(state, session, key::town_lost);
	_append_nonempty_message(state, messages, delivery_summary);

	const DictRef defending_hero = defender_owner == key::player ? hero_command_rules::hero_by_id(state, gd::object_view(state, session), defending_hero_id) : state.new_dict();
	if (!gd::is_empty(state, defending_hero)) {
		if (gd::bool_field(state, defending_hero, key::is_primary, false) && player_elimination_rules::applies(state, gd::object_view(state, session))) {
			hero_command_rules::hand_over_primary(state, gd::object_view(state, session), defending_hero_id);
		} else if (gd::bool_field(state, defending_hero, key::is_primary, false)) {
			const DictRef defeat_result = _finalize_primary_defeat(state, session, key::the_primary_commander_is_defeated, key::town_lost);
			Value report;
			if (!state.lookup(session_flags(state, session), str(key::last_battle_aftermath), report)) {
				report = dict_value(state.new_dict());
			}
			if (gd::is_dict(report)) {
				state.set(report.ref, str(key::summary), str(base_summary));
				state.set(report.ref, str(key::recovery_summary), str(_join_messages(state, string_array(state, { recovery_message, commander_aftermath }))));
				state.set(session_flags(state, session), str(key::last_battle_aftermath), report);
			}
			_append_nonempty_message(state, messages, text_field(state, defeat_result, key::message, key::empty));
			return state_and_message(state, key::defeat, join_array(state, " ", messages));
		}
		const DictRef removal = _remove_hero_by_id_after_defeat(state, session, defending_hero_id);
		_append_nonempty_message(state, messages, text_field(state, removal, key::message, key::empty));
	}

	DictRef collapse_aftermath;
	if (defender_owner == key::player) {
		collapse_aftermath = _apply_collapse_aftermath(state, session, key::town_lost);
	} else {
		collapse_aftermath = state.new_dict();
		state.set(collapse_aftermath, str(key::summary), str(gd::format(state, key::s_is_absorbed_into_the_enemy, { str(town_name != key::empty ? town_name : key::the_neutral_town) })));
		state.set(collapse_aftermath, str(key::resource_summary), str(key::empty));
		state.set(collapse_aftermath, str(key::pressure_summary), str(key::empty));
		state.set(collapse_aftermath, str(key::recovery_summary), str(key::empty));
	}
	_append_nonempty_message(state, messages, text_field(state, collapse_aftermath, key::summary, key::empty));
	set_last_outcome(state, session, key::town_lost);
	const DictRef details = state.new_dict();
	state.set(details, str(key::display_outcome), str(key::collapse));
	state.set(details, str(key::resource_summary), str(text_field(state, collapse_aftermath, key::resource_summary, key::empty)));
	state.set(details, str(key::pressure_summary), str(text_field(state, collapse_aftermath, key::pressure_summary, key::empty)));
	const ArrayRef recovery_parts = string_array(state, {
			text_field(state, collapse_aftermath, key::recovery_summary, key::empty),
			recovery_message,
			commander_aftermath,
	});
	state.set(details, str(key::recovery_summary), str(_join_messages(state, recovery_parts)));
	state.set(details, str(key::logistics_summary), str(delivery_summary));
	_record_battle_aftermath(state, session, key::town_lost, base_summary, details);
	clear_battle(state, session);
	overworld_rules::refresh_fog_of_war(state, gd::object_view(state, session));
	const Atom final_message = evaluate_and_join(state, session, messages);
	set_return_notice(state, session, final_message);
	return state_and_message(state, session_text(state, session, key::scenario_status) != key::in_progress ? key::defeat : key::town_lost, final_message);
}

void _mark_resolved_encounter(State &state, const Value &session, Atom resolved_key) {
	if (session.kind == Kind::Nil || resolved_key == key::empty || gd::begins_with(state, resolved_key, key::dwelling_guard_3)) {
		return;
	}
	Value resolved;
	if (!state.lookup(session_overworld(state, session), str(key::resolved_encounters), resolved) || !gd::is_array(resolved)) {
		resolved = array_value(state.new_array());
	}
	if (!gd::array_has(state, resolved.ref, str(resolved_key))) {
		state.append(resolved.ref, str(resolved_key));
	}
	state.set(session_overworld(state, session), str(key::resolved_encounters), resolved);
}

DictRef _battle_exit_animation_snapshot(State &state, DictRef battle, Atom outcome) {
	if (gd::is_empty(state, battle)) {
		return state.new_dict();
	}
	const DictRef snapshot = gd::deep_duplicate_dict(state, battle);
	state.erase(snapshot, str(key::_live_action_playback_capture));
	state.set(snapshot, str(key::presentation_mode), str(key::battle_exit_animation));
	state.set(snapshot, str(key::presentation_outcome), str(outcome));
	state.set(snapshot, str(key::presentation_policy), str(key::pre_resolution_animation_snapshot));
	// A missing queue normalizes as its default {} or [] does: to an empty one.
	const DictRef animation_states = _normalize_stack_animation_states(state, state.get(snapshot, str(key::stack_animation_states), Value()));
	state.set(snapshot, str(key::stack_animation_states), dict_value(animation_states));
	const ArrayRef animation_events = _normalize_animation_event_queue(state, state.get(snapshot, str(key::battle_animation_events), Value()));
	state.set(snapshot, str(key::battle_animation_events), array_value(animation_events));
	const ArrayRef presentation_events = _normalize_presentation_event_queue(state, state.get(snapshot, str(key::battle_presentation_events), Value()));
	state.set(snapshot, str(key::battle_presentation_events), array_value(presentation_events));
	const Atom speed = _normalize_presentation_speed(state, text_field(state, snapshot, key::battle_presentation_speed, key::normal));
	state.set(snapshot, str(key::battle_presentation_speed), str(speed));
	return snapshot;
}

Atom _normalize_presentation_speed(State &state, Atom speed) {
	// speed.strip_edges().to_lower() in [PRESENTATION_SPEED_NORMAL, _FAST,
	// _INSTANT]. Outside ASCII only U+0130 (whose lowercase is "i") can lower
	// into a letter of a speed; any other such character leaves the text
	// outside ASCII, so it is no speed.
	const std::string &text = state.text(gd::strip_edges(state, speed));
	std::string lowered;
	lowered.reserve(text.size());
	bool dotted_capital_i = false;
	for (size_t index = 0; index < text.size(); ++index) {
		const unsigned char c = static_cast<unsigned char>(text[index]);
		if (c < 0x80) {
			lowered += static_cast<char>(c >= 'A' && c <= 'Z' ? c - 'A' + 'a' : c);
			continue;
		}
		if (c == 0xC4 && index + 1 < text.size() && static_cast<unsigned char>(text[index + 1]) == 0xB0) {
			dotted_capital_i = true;
			++index;
			continue;
		}
		return key::normal;
	}
	if (dotted_capital_i) {
		throw state::NotPorted("BattleRules._normalize_presentation_speed: to_lower() of U+0130");
	}
	if (lowered == "fast") {
		return key::fast;
	}
	if (lowered == "instant") {
		return key::instant;
	}
	return key::normal;
}

DictRef _normalize_stack_animation_states(State &state, const Value &value) {
	const DictRef normalized = state.new_dict();
	if (!gd::is_dict(value)) {
		return normalized;
	}
	for (const Value &battle_id_key : gd::items(state, value)) {
		// A record that is not a Dictionary is {}, whose state is "".
		const Value record_value = state.get(value.ref, battle_id_key, Value());
		if (!gd::is_dict(record_value)) {
			continue;
		}
		const DictRef record = record_value.ref;
		const Atom anim_state = gd::strip_edges(state, text_field(state, record, key::state, key::empty));
		if (anim_state == key::empty) {
			continue;
		}
		const Atom battle_id = gd::strip_edges(state, gd::stringify(state, state.get(record, str(key::battle_id), battle_id_key)));
		const DictRef entry = state.new_dict();
		state.set(entry, str(key::event_id), str(text_field(state, record, key::event_id, key::empty)));
		state.set(entry, str(key::state), str(anim_state));
		state.set(entry, str(key::battle_id), str(battle_id));
		state.set(entry, str(key::target_battle_id), str(text_field(state, record, key::target_battle_id, key::empty)));
		state.set(entry, str(key::source_battle_id), str(text_field(state, record, key::source_battle_id, key::empty)));
		state.set(entry, str(key::from_q), int_value(gd::int_field(state, record, key::from_q, -1)));
		state.set(entry, str(key::from_r), int_value(gd::int_field(state, record, key::from_r, -1)));
		state.set(entry, str(key::to_q), int_value(gd::int_field(state, record, key::to_q, -1)));
		state.set(entry, str(key::to_r), int_value(gd::int_field(state, record, key::to_r, -1)));
		state.set(entry, str(key::spell_id), str(text_field(state, record, key::spell_id, key::empty)));
		state.set(entry, str(key::resolution_type), str(text_field(state, record, key::resolution_type, key::empty)));
		state.set(entry, str(key::priority), int_value(gd::to_int(state, state.get(record, str(key::priority), int_value(animation_state_priority(anim_state))))));
		state.set(entry, str(key::serial), int_value(std::max<int64_t>(0, gd::int_field(state, record, key::serial, 0))));
		state.set(entry, str(key::round), int_value(std::max<int64_t>(1, gd::int_field(state, record, key::round, 1))));
		state.set(entry, str(key::turn_index), int_value(std::max<int64_t>(0, gd::int_field(state, record, key::turn_index, 0))));
		state.set(normalized, str(battle_id), dict_value(entry));
	}
	return normalized;
}

} // namespace aurelion::rules::port::battle_rules
