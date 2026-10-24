// BattleRules for the battle screen (Phase 7, slice 7.9): the battle context,
// commanders, pressure, doctrine and the field objective texts.

#include "aurelion_rules/port/battle_screen.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_spells.hpp"
#include "aurelion_rules/port/scenario_outcome.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <algorithm>
#include <initializer_list>
#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

using compat::engine_max;
using compat::engine_min;
using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
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

// d.get(field, {}) where the value is passed on: a new Dictionary when missing.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// String(d.get(outer, {}).get(inner, "")): a missing outer is the empty
// Dictionary's ""; an outer that is no Dictionary has no get() (a ScriptError,
// as in GDScript).
Atom nested_text(State &state, DictRef dict, Atom outer, Atom inner) {
	Value found;
	if (!state.lookup(dict, str(outer), found)) {
		return key::empty;
	}
	return string_of(state, ai::vget(state, found, inner, str(key::empty)));
}

// separator.join(parts) of Strings.
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

// a + b of Strings.
Atom concat(State &state, Atom a, Atom b) {
	return state.intern(state.text(a) + state.text(b));
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

// {"side": side}, the stack the side checks take.
DictRef side_stack(State &state, Atom side) {
	const DictRef stack = state.new_dict();
	state.set(stack, str(key::side), str(side));
	return stack;
}

// An Array literal of Strings.
ArrayRef string_array(State &state, std::initializer_list<Atom> texts) {
	const ArrayRef array = state.new_array();
	for (const Atom text : texts) {
		state.append(array, str(text));
	}
	return array;
}

// name not in names: names.append(name), for an ability's non-empty name.
void append_ability_name(State &state, std::vector<Atom> &names, DictRef ability) {
	const Atom name = text_or(state, ability, key::name, key::empty);
	if (name != key::empty && std::find(names.begin(), names.end(), name) == names.end()) {
		names.push_back(name);
	}
}

// controller in ["player", "enemy"].
bool is_player_or_enemy(Atom side) {
	return side == key::player || side == key::enemy;
}

// session.battle: SessionData types it Dictionary.
DictRef session_battle(State &state, DictRef session) {
	return gd::as_dict(gd::index(state, session, str(key::battle)));
}

// max(0, int(battle.get("max_rounds", 12)) - int(battle.get("round", 1)) + 1).
int64_t rounds_left(State &state, DictRef battle) {
	const int64_t max_rounds = gd::int_field(state, battle, key::max_rounds, 12);
	const int64_t round = gd::int_field(state, battle, key::round, 1);
	return engine_max<int64_t>(0, gd::add(gd::sub(max_rounds, round), 1));
}

} // namespace

namespace battle_rules {

Atom _stack_ability_summary(State &state, DictRef stack) {
	std::vector<Atom> names;
	for (const Value &ability : gd::field_items(state, stack, str(key::abilities))) {
		if (gd::is_dict(ability)) {
			const Value fallback = state.get(ability.ref, str(key::id), str(key::empty));
			const Atom name = string_of(state, state.get(ability.ref, str(key::name), fallback));
			if (name != key::empty) {
				names.push_back(name);
			}
		}
	}
	const DictRef bramble_ground = _bramble_ground_ability(state, stack);
	append_ability_name(state, names, bramble_ground);
	const DictRef fog_screen = _fog_screen_ability(state, stack);
	append_ability_name(state, names, fog_screen);
	const DictRef readiness_writ = _readiness_writ_ability(state, stack);
	append_ability_name(state, names, readiness_writ);
	return join_atoms(state, key::comma_space, names);
}

Atom _battle_context_label(State &state, DictRef session, const Value &context) {
	if (!gd::is_dict(context)) {
		return key::field_engagement;
	}
	const DictRef context_dict = context.ref;
	if (_has_delivery_context(state, context)) {
		const Atom target_label = text_or(state, context_dict, key::delivery_target_label, key::the_front);
		if (text_or(state, context_dict, key::type, key::empty) == key::town_defense) {
			return gd::format(state, key::relief_defense_at_s, {str(target_label != key::empty ? target_label : static_cast<Atom>(key::the_walls))});
		}
		return gd::format(state, key::convoy_clash_near_s, {str(target_label != key::empty ? target_label : static_cast<Atom>(key::the_front))});
	}
	if (text_or(state, context_dict, key::type, key::empty) == key::hero_intercept) {
		const DictRef hero = hero_command_rules::hero_by_id(state, session, text_or(state, context_dict, key::target_hero_id, key::empty));
		const Atom hero_name = text_or(state, hero, key::name, key::the_road);
		return gd::format(state, key::interception_near_s, {str(hero_name)});
	}
	if (_is_town_assault_context(state, context)) {
		const Atom assault_town_name = _town_name_from_placement_id(state, dict_value(session), text_or(state, context_dict, key::town_placement_id, key::empty));
		const Atom shown = assault_town_name != key::empty ? assault_town_name : static_cast<Atom>(key::the_walls);
		const Atom role = text_or(state, context_dict, key::town_role, key::frontier);
		if (role == key::capital) {
			return gd::format(state, key::capital_assault_at_s, {str(shown)});
		}
		if (role == key::stronghold) {
			return gd::format(state, key::stronghold_assault_at_s, {str(shown)});
		}
		return gd::format(state, key::town_assault_at_s, {str(shown)});
	}
	if (text_or(state, context_dict, key::type, key::empty) != key::town_defense) {
		return key::field_engagement;
	}
	const Atom town_name = _town_name_from_placement_id(state, dict_value(session), text_or(state, context_dict, key::town_placement_id, key::empty));
	const Atom shown = town_name != key::empty ? town_name : static_cast<Atom>(key::the_walls);
	const Atom role = text_or(state, context_dict, key::town_role, key::frontier);
	if (role == key::capital) {
		return gd::format(state, key::capital_defense_at_s, {str(shown)});
	}
	if (role == key::stronghold) {
		return gd::format(state, key::stronghold_defense_at_s, {str(shown)});
	}
	return gd::format(state, key::town_defense_at_s, {str(shown)});
}

Atom _battlefield_identity_summary(State &state, DictRef battle) {
	std::vector<Atom> parts;
	if (_has_delivery_context(state, field_or_new_dict(state, battle, key::context))) {
		parts.push_back(key::the_fight_is_sitting_on_a);
	}
	if (_battle_has_tag(state, battle, key::fortress_lane)) {
		parts.push_back(key::fortress_lanes_compress_the_approach);
	}
	if (_battle_has_tag(state, battle, key::battery_nest)) {
		parts.push_back(key::battery_nests_punish_long_approaches);
	}
	if (_battle_has_tag(state, battle, key::wall_pressure)) {
		parts.push_back(key::wall_pressure_favors_late_breach_fighting);
	}
	if (_battle_has_tag(state, battle, key::reserve_wave)) {
		parts.push_back(key::reserve_waves_matter_after_the_opening);
	}
	const Atom terrain_effect = _terrain_effect_brief(state, battle);
	if (terrain_effect != key::empty) {
		parts.push_back(terrain_effect);
	}
	const Atom objective_brief = _field_objective_status_brief(state, battle);
	if (objective_brief != key::empty) {
		parts.push_back(to_lower(state, objective_brief));
	}
	if (parts.empty() && nested_text(state, battle, key::context, key::battlefront_summary) != key::empty) {
		return nested_text(state, battle, key::context, key::battlefront_summary);
	}
	return join_atoms(state, key::comma_space, parts);
}

Atom _distance_label(State &state, int64_t distance) {
	(void)state;
	switch (engine_max<int64_t>(0, distance)) {
		case 0:
			return key::lines_engaged;
		case 1:
			return key::closing_distance;
		default:
			return key::long_approach;
	}
}

DictRef _commander_state_for_side(State &state, DictRef battle, Atom side) {
	const Atom field = side == key::enemy ? static_cast<Atom>(key::enemy_hero) : static_cast<Atom>(key::player_commander_state);
	return gd::as_dict(field_or_new_dict(state, battle, field));
}

Atom _commander_role_label(State &state, DictRef battle, Atom side) {
	if (side == key::enemy) {
		return !gd::is_empty(state, _commander_state_for_side(state, battle, side)) ? static_cast<Atom>(key::enemy_commander_2) : static_cast<Atom>(key::uncommanded_host);
	}
	const Atom source_type = nested_text(state, battle, key::player_commander_source, key::type);
	if (source_type == key::active_hero) {
		return key::field_commander_2;
	}
	if (source_type == key::town_hero) {
		return key::town_defender;
	}
	if (source_type == key::town_captain_2) {
		return key::town_captain_3;
	}
	return key::Commander;
}

Atom _pressure_brief(State &state, DictRef session) {
	const DictRef battle = session_battle(state, session);
	if (gd::is_empty(state, battle)) {
		return key::no_pressure_data;
	}
	const Atom objective_pressure = _field_objective_pressure_brief(state, battle);
	if (objective_pressure != key::empty) {
		return objective_pressure;
	}
	const DictRef player_totals = _army_totals(state, battle, key::player);
	const DictRef enemy_totals = _army_totals(state, battle, key::enemy);
	const int64_t player_health = engine_max<int64_t>(1, gd::int_field(state, player_totals, key::health, 0));
	const int64_t enemy_health = engine_max<int64_t>(1, gd::int_field(state, enemy_totals, key::health, 0));
	const int64_t rounds_remaining = rounds_left(state, battle);
	const auto distance_open = [&]() { return gd::int_field(state, battle, key::distance, 1) > 0; };
	const auto round_now = [&]() { return gd::int_field(state, battle, key::round, 1); };
	if (_side_controls_field_objective_type(state, battle, key::enemy, key::cover_line) && _side_controls_field_objective_type(state, battle, key::enemy, key::lane_battery) && distance_open()) {
		return key::enemy_guns_are_firing_from_cover;
	}
	if (_side_controls_field_objective_type(state, battle, key::enemy, key::cover_line) && distance_open()) {
		return key::enemy_cover_lines_are_still_screening;
	}
	if (_side_controls_field_objective_type(state, battle, key::player, key::cover_line) && distance_open()) {
		return key::friendly_cover_is_blunting_the_opening;
	}
	if (_side_controls_field_objective_type(state, battle, key::enemy, key::obstruction_line) && distance_open()) {
		return key::enemy_obstructions_can_still_hold_weaker;
	}
	if (_side_controls_field_objective_type(state, battle, key::player, key::obstruction_line) && distance_open()) {
		return key::friendly_hands_now_own_the_choke;
	}
	if (_battle_has_tag(state, battle, key::battery_nest) && round_now() <= 2 && distance_open()) {
		return key::battery_lanes_are_still_punishing_the;
	}
	if (_battle_has_tag(state, battle, key::fortress_lane) && round_now() <= 2) {
		return key::fortress_lanes_are_compressing_the_assault;
	}
	if (_reserve_wave_is_active_for_side(state, battle, _capital_front_anchor_side(state, battle))) {
		return key::reserve_companies_are_reaching_the_line;
	}
	if (_battle_has_tag(state, battle, key::wall_pressure) && round_now() >= 3) {
		return key::the_breach_is_widening_late_melee;
	}
	if (_is_town_defense_context(state, field_or_new_dict(state, battle, key::context)) && enemy_health > player_health) {
		return key::the_walls_are_under_strain_a;
	}
	if (_is_town_assault_context(state, field_or_new_dict(state, battle, key::context)) && enemy_health >= player_health) {
		return key::the_breach_is_stalling_the_town;
	}
	if (rounds_remaining <= 2) {
		return key::the_clock_is_tightening_one_more;
	}
	if (enemy_health <= compat::float_to_int(compat::godot_round(static_cast<double>(player_health) * 0.65))) {
		return key::the_enemy_line_is_wavering;
	}
	if (player_health <= compat::float_to_int(compat::godot_round(static_cast<double>(enemy_health) * 0.65))) {
		return key::the_friendly_line_is_under_heavy;
	}
	if (round_now() >= 3) {
		const Atom player_doctrine = _side_doctrine_summary(state, battle, key::player);
		const Atom enemy_doctrine = _side_doctrine_summary(state, battle, key::enemy);
		if (player_doctrine != enemy_doctrine) {
			return gd::format(state, key::s_versus_s_is_defining_the, {str(player_doctrine), str(enemy_doctrine)});
		}
	}
	return key::the_exchange_is_still_balanced;
}

Atom _engagement_preview(State &state, DictRef active_stack, DictRef target, DictRef battle) {
	if (gd::is_empty(state, active_stack) || gd::is_empty(state, target)) {
		return key::no_engagement_forecast;
	}
	if (text_or(state, active_stack, key::side, key::empty) == text_or(state, target, key::side, key::empty)) {
		return key::friendly_stack_selected;
	}
	if (text_or(state, active_stack, key::side, key::empty) == key::player) {
		const DictRef click_intent = board_click_attack_intent_for_target(state, battle, text_or(state, target, key::battle_id, key::empty));
		const Atom action_label = text_or(state, click_intent, key::label, key::empty);
		if (action_label != key::empty) {
			return gd::format(state, key::board_click_will_s_s_now, {str(action_label), str(_stack_label(state, target))});
		}
		if (state.array_size(_legal_attack_target_ids_for_active_stack(state, battle)) != 0) {
			return gd::format(state, key::s_is_blocked_from_this_hex, {str(_stack_label(state, target))});
		}
		return gd::format(state, key::movement_is_needed_before_s_can, {str(_stack_label(state, target))});
	}
	return gd::format(state, key::s_is_threatening_s, {str(_stack_label(state, active_stack)), str(_stack_label(state, target))});
}

Atom _stack_focus_summary(State &state, DictRef stack, DictRef battle, bool is_active) {
	if (gd::is_empty(state, stack)) {
		return key::no_stack_is_selected;
	}
	const Atom side = text_or(state, stack, key::side, key::empty);
	const DictRef comparison_stack = is_active ? get_selected_target(state, battle) : get_active_stack(state, battle);
	std::vector<Atom> lines;
	lines.push_back(gd::format(state, key::s_s_s_14, {
			str(_stack_label(state, stack)),
			str(_side_label(side)),
			str(is_active ? static_cast<Atom>(key::acting_now) : static_cast<Atom>(key::empty)),
	}));
	const DictRef inspection_options = state.new_dict();
	state.set(inspection_options, str(key::include_name), gd::bool_value(false));
	lines.push_back(overworld_rules::describe_stack_inspection_line(state, stack, inspection_options));
	const int64_t min_damage = gd::int_field(state, stack, key::min_damage, 1);
	const int64_t max_damage = gd::int_field(state, stack, key::max_damage, 1);
	const int64_t speed = gd::int_field(state, stack, key::speed, 1);
	lines.push_back(gd::format(state, key::dmg_d_d_speed_d, {int_value(min_damage), int_value(max_damage), int_value(speed)}));
	const int64_t attack_total = _stack_attack_total(state, stack, battle);
	const int64_t defense_total = _stack_defense_total(state, stack, battle);
	const int64_t initiative_total = _stack_initiative_total(state, stack, battle);
	lines.push_back(gd::format(state, key::attack_d_defense_d_initiative_d, {int_value(attack_total), int_value(defense_total), int_value(initiative_total)}));
	const int64_t cohesion_total = _stack_cohesion_total(state, stack, battle);
	const int64_t momentum_total = _stack_momentum_total(state, stack, battle);
	const bool isolated = _stack_is_isolated(state, battle, stack);
	lines.push_back(gd::format(state, key::cohesion_d_momentum_d_s, {
			int_value(cohesion_total),
			int_value(momentum_total),
			str(isolated ? static_cast<Atom>(key::isolated) : static_cast<Atom>(key::empty)),
	}));
	if (gd::bool_field(state, stack, key::ranged, false)) {
		lines.push_back(gd::format(state, key::ranged_pressure_shots_d, {int_value(gd::int_field(state, stack, key::shots_remaining, 0))}));
	} else {
		const int64_t retaliations_left = gd::int_field(state, stack, key::retaliations_left, 0);
		const int64_t retaliations = gd::int_field(state, stack, key::retaliations, 0);
		lines.push_back(gd::format(state, key::melee_pressure_retaliations_d_d, {int_value(retaliations_left), int_value(retaliations)}));
	}
	if (gd::bool_field(state, stack, key::defending, false)) {
		lines.push_back(key::stance_defending);
	}
	const Atom effect_summary = spell_rules::effect_summary(state, stack, battle);
	lines.push_back(gd::format(state, key::effects_s, {str(effect_summary != key::empty ? effect_summary : static_cast<Atom>(key::none))}));
	const Atom town_defense = town_battle_rules::summary(state, battle, stack);
	if (town_defense != key::empty) {
		lines.push_back(concat(state, key::town_defense_2, town_defense));
	}
	lines.push_back(_stack_status_pressure_line(state, stack, battle));
	const Atom ability_summary = _stack_ability_summary(state, stack);
	if (ability_summary != key::empty) {
		lines.push_back(gd::format(state, key::abilities_s, {str(ability_summary)}));
	}
	lines.push_back(_active_ability_role_line(state, stack, battle, comparison_stack));
	if (is_active) {
		lines.push_back(_target_range_readiness_line(state, stack, comparison_stack, battle));
	}
	const Atom objective_summary = _field_objective_focus_line(state, battle, side, stack);
	if (objective_summary != key::empty) {
		lines.push_back(objective_summary);
	}
	return join_atoms(state, key::newline, lines);
}

Atom _side_doctrine_summary(State &state, DictRef battle, Atom side) {
	const Atom faction_id = _side_faction_id(state, battle, side);
	const auto round_now = [&]() { return gd::int_field(state, battle, key::round, 1); };
	if (faction_id == key::faction_embercourt) {
		const ArrayRef alive = _alive_stacks_for_side(state, battle, side);
		for (const Value &stack : gd::items(state, array_value(alive))) {
			if (gd::to_bool(ai::vget(state, stack, key::defending, gd::bool_value(false))) && !gd::is_empty(state, _charter_retaliation_aura_context(state, gd::as_dict(stack), battle))) {
				return key::the_charter_colossus_is_magnifying_the;
			}
		}
		if (_battle_has_tag(state, battle, key::fortress_lane) && _stack_is_anchor_side(state, side_stack(state, side), battle)) {
			if (_reserve_wave_is_active_for_side(state, battle, side)) {
				return key::fortress_lanes_are_feeding_reserve_columns;
			}
			return key::fortress_lanes_are_locking_the_assault;
		}
		if (_side_has_ability(state, battle, side, key::formation_guard) && _side_defending_count(state, battle, side) > 0 && _side_has_role_mix(state, battle, side)) {
			return key::pike_screens_are_feeding_lantern_volleys;
		}
		if (_side_has_ability(state, battle, side, key::formation_guard) && _side_defending_count(state, battle, side) > 0) {
			return key::pikewards_are_locking_the_firing_line;
		}
		if (round_now() >= 3 && _side_has_role_mix(state, battle, side)) {
			return key::formation_fire_is_tightening_the_line;
		}
		if (_side_defending_count(state, battle, side) > 0) {
			return key::shielded_volleys_are_covering_the_line;
		}
		return key::the_line_is_still_forming;
	}
	if (faction_id == key::faction_mireclaw) {
		if (_battle_has_tag(state, battle, key::wall_pressure) && _stack_is_assault_side(state, side_stack(state, side), battle) && round_now() >= 3) {
			return key::breach_packs_are_climbing_over_the;
		}
		if (_reserve_wave_is_active_for_side(state, battle, side) && _stack_is_anchor_side(state, side_stack(state, side), battle)) {
			return key::reserve_packs_are_flooding_the_breach;
		}
		if (_side_has_ability(state, battle, side, key::bloodrush) && _enemy_wounded_count(state, battle, side) > 0 && round_now() >= 3) {
			return key::rippers_are_driving_the_collapse;
		}
		if (_enemy_wounded_count(state, battle, side) > 0 && round_now() >= 3) {
			return key::blood_rush_finishers_are_cresting;
		}
		if (_enemy_wounded_count(state, battle, side) > 0) {
			return key::the_pack_is_scenting_weakness;
		}
		return key::the_pack_is_probing_for_the;
	}
	if (faction_id == key::faction_sunvault) {
		const int64_t positive_effect_count = _side_positive_effect_count(state, battle, side);
		const DictRef resonance_relay = _side_resonance_relay(state, battle, side);
		if (_battle_has_tag(state, battle, key::battery_nest) && _stack_is_anchor_side(state, side_stack(state, side), battle)) {
			if (_reserve_wave_is_active_for_side(state, battle, side)) {
				return key::battery_nests_are_rotating_fresh_arrays;
			}
			return key::battery_nests_are_turning_the_approach;
		}
		if (!gd::is_empty(state, resonance_relay) && positive_effect_count >= 3 && _battle_has_any_tags(state, battle, string_array(state, {key::elevated_fire, key::fortified_line}))) {
			return key::resonant_arrays_are_firing_in_sequence;
		}
		if (!gd::is_empty(state, resonance_relay) && positive_effect_count >= gd::int_field(state, resonance_relay, key::minimum_calibrated_stacks, 2)) {
			return key::relay_chants_are_syncing_the_line;
		}
		if (positive_effect_count >= 2) {
			return key::separate_calibrations_are_waiting_for_a;
		}
		if (!gd::is_empty(state, resonance_relay) && positive_effect_count >= 1) {
			return key::the_relay_is_waiting_for_a;
		}
		if (positive_effect_count >= 1) {
			return key::a_resonant_array_is_coming_online;
		}
		return key::the_array_is_still_gathering_signal;
	}
	if (faction_id == key::faction_thornwake) {
		if (_battle_has_any_tags(state, battle, string_array(state, {key::chokepoint, key::ambush_cover})) && _side_defending_count(state, battle, side) > 0) {
			return key::rooted_lanes_are_turning_the_fight;
		}
		if (_side_has_ability(state, battle, side, key::formation_guard)) {
			return key::graft_leaders_are_holding_the_regrowth;
		}
		if (round_now() >= 4) {
			return key::the_battlefield_is_starting_to_root;
		}
		return key::seed_carriers_are_looking_for_ground;
	}
	if (faction_id == key::faction_brasshollow) {
		if (_battle_has_any_tags(state, battle, string_array(state, {key::fortress_lane, key::wall_pressure})) && _side_has_ability(state, battle, side, key::shielding)) {
			return key::foundry_armor_is_turning_the_lane;
		}
		if (_side_has_ability(state, battle, side, key::volley)) {
			return key::boiler_crews_are_setting_pressure_shots;
		}
		if (round_now() >= 3) {
			return key::heat_and_contract_pressure_are_building;
		}
		return key::the_engines_are_still_coming_up;
	}
	if (faction_id == key::faction_veilmourn) {
		if (_battle_has_any_tags(state, battle, string_array(state, {key::fog_bank, key::ambush_cover})) && _side_has_ability(state, battle, side, key::backstab)) {
			return key::fog_lanes_are_opening_routes_into;
		}
		if (_enemy_wounded_count(state, battle, side) > 0) {
			return key::marked_victims_are_losing_their_clean;
		}
		if (_side_has_ability(state, battle, side, key::harry)) {
			return key::lantern_marks_are_testing_the_enemy;
		}
		return key::the_fog_fleet_is_measuring_the;
	}
	return key::no_doctrine_is_asserting_itself;
}

Atom _field_objective_progress_text(State &state, DictRef objective) {
	const Atom controller = text_or(state, objective, key::control_side, key::neutral);
	const Atom progress_side = text_or(state, objective, key::progress_side, key::empty);
	const int64_t progress_value = gd::int_field(state, objective, key::progress_value, 0);
	const int64_t threshold = engine_max<int64_t>(1, gd::int_field(state, objective, key::capture_threshold, 2));
	if (is_player_or_enemy(controller)) {
		if (progress_side != key::empty && progress_side != controller && progress_value > 0) {
			return gd::format(state, key::s_held_s_pressure_d_d, {
					str(_side_label(controller)),
					str(_side_label(progress_side)),
					int_value(progress_value),
					int_value(threshold),
			});
		}
		return gd::format(state, key::s_held, {str(_side_label(controller))});
	}
	if (progress_side != key::empty && progress_value > 0) {
		return gd::format(state, key::contested_toward_s_d_d, {str(_side_label(progress_side)), int_value(progress_value), int_value(threshold)});
	}
	return key::unclaimed;
}

Atom _field_objective_short_status(State &state, DictRef objective) {
	const Atom label = _field_objective_label(state, objective);
	const Atom progress = _field_objective_progress_text(state, objective);
	return gd::format(state, key::s_s, {str(label), str(progress)});
}

Atom _field_objective_status_brief(State &state, DictRef battle) {
	const ArrayRef objectives = _field_objectives(state, battle);
	if (state.array_size(objectives) == 0) {
		return key::empty;
	}
	const Value primary = state.at(objectives, 0);
	if (gd::is_dict(primary)) {
		return _field_objective_short_status(state, primary.ref);
	}
	return key::empty;
}

Atom _field_objective_pressure_summary(State &state, DictRef battle) {
	std::vector<Atom> parts;
	const ArrayRef objectives = _field_objectives(state, battle);
	for (const Value &objective : gd::items(state, array_value(objectives))) {
		if (!gd::is_dict(objective)) {
			continue;
		}
		const Atom short_status = _field_objective_short_status(state, objective.ref);
		const Atom summary = text_or(state, objective.ref, key::summary, key::empty);
		parts.push_back(gd::format(state, key::s_s_text, {str(short_status), str(summary)}));
		if (parts.size() >= 2) {
			break;
		}
	}
	return join_atoms(state, key::text_8, parts);
}

Atom _field_objective_pressure_brief(State &state, DictRef battle) {
	const ArrayRef objectives = _field_objectives(state, battle);
	for (const Value &objective_value : gd::items(state, array_value(objectives))) {
		if (!gd::is_dict(objective_value)) {
			continue;
		}
		const DictRef objective = objective_value.ref;
		const Atom objective_type = text_or(state, objective, key::type, key::empty);
		const Atom controller = text_or(state, objective, key::control_side, key::neutral);
		const int64_t urgency_round = gd::int_field(state, objective, key::urgency_round, 2);
		const auto distance_open = [&]() { return gd::int_field(state, battle, key::distance, 1) > 0; };
		const auto urgent = [&]() { return gd::int_field(state, battle, key::round, 1) >= urgency_round; };
		const auto labelled = [&](Atom pattern) { return gd::format(state, pattern, {str(_field_objective_label(state, objective))}); };
		if (objective_type == key::lane_battery) {
			if (controller == key::enemy && distance_open()) {
				return labelled(key::s_still_controls_the_firing_lane);
			}
			if (controller == key::player && distance_open()) {
				return labelled(key::s_now_favors_the_friendly_guns);
			}
		} else if (objective_type == key::cover_line) {
			if (controller == key::enemy && distance_open()) {
				return labelled(key::s_is_still_screening_the_enemy);
			}
			if (controller == key::player && distance_open()) {
				return labelled(key::friendly_cover_is_blunting_the_opening_2);
			}
		} else if (objective_type == key::obstruction_line) {
			if (controller == key::enemy && distance_open()) {
				return labelled(key::s_is_still_compressing_the_approach);
			}
			if (controller == key::player && distance_open()) {
				return labelled(key::s_has_turned_the_choke_back);
			}
		} else if (objective_type == key::ritual_pylon) {
			if (controller == key::enemy && urgent()) {
				return labelled(key::s_is_grinding_the_line_s);
			}
			if (controller == key::player && urgent()) {
				return labelled(key::s_now_breaks_the_enemy_rhythm);
			}
		} else if (objective_type == key::supply_post) {
			if (controller == key::enemy && _battle_has_tag(state, battle, key::reserve_wave)) {
				return labelled(key::s_is_feeding_enemy_reserves_to);
			}
			if (controller == key::player && _battle_has_tag(state, battle, key::reserve_wave)) {
				return labelled(key::s_is_delaying_enemy_reserve_timing);
			}
		} else if (objective_type == key::signal_beacon) {
			if (controller == key::enemy) {
				return labelled(key::s_is_keeping_enemy_command_ahead);
			}
			if (controller == key::player) {
				return labelled(key::s_is_stabilizing_friendly_command_tempo);
			}
		} else if (objective_type == key::breach_point) {
			if (is_player_or_enemy(controller) && urgent()) {
				return labelled(key::s_is_deciding_the_melee_collapse);
			}
		} else if (objective_type == key::hazard_zone) {
			if (controller == key::enemy && urgent()) {
				return labelled(key::s_is_still_punishing_the_approach);
			}
			if (controller == key::player && urgent()) {
				return labelled(key::s_has_been_turned_back_on);
			}
		}
	}
	return key::empty;
}

Atom _field_objective_urgency_summary(State &state, DictRef session, DictRef battle) {
	std::vector<Atom> parts;
	std::vector<Atom> urgent;
	const ArrayRef objectives = _field_objectives(state, battle);
	for (const Value &objective : gd::items(state, array_value(objectives))) {
		if (gd::is_dict(objective) && gd::int_field(state, battle, key::round, 1) >= gd::int_field(state, objective.ref, key::urgency_round, 2)) {
			urgent.push_back(_field_objective_short_status(state, objective.ref));
		}
	}
	if (urgent.empty()) {
		const Atom objective_brief = _field_objective_status_brief(state, battle);
		if (objective_brief != key::empty) {
			parts.push_back(objective_brief);
		}
	} else {
		const std::vector<Atom> shown(urgent.begin(), urgent.begin() + static_cast<std::ptrdiff_t>(engine_min<size_t>(2, urgent.size())));
		parts.push_back(gd::format(state, key::active_pressure_s, {str(join_atoms(state, key::semicolon_space, shown))}));
	}
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, gd::to_string(gd::index(state, session, str(key::scenario_id))));
	const Atom scenario_line = gd::strip_edges(state, gd::trim_prefix(state, _tactical_objective_line(state, session, battle, scenario), key::battle_aim_2));
	if (scenario_line != key::empty) {
		parts.push_back(scenario_line);
	}
	const int64_t rounds_remaining = rounds_left(state, battle);
	if (rounds_remaining <= 2) {
		parts.push_back(gd::format(state, key::d_round_s_remain_before_stalemate, {
				int_value(rounds_remaining),
				str(rounds_remaining == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::s)),
		}));
	}
	if (!_battle_retreat_allowed(state, battle)) {
		parts.push_back(key::retreat_locked);
	}
	return join_atoms(state, key::space_bar_space, parts);
}

Atom _field_objective_focus_line(State &state, DictRef battle, Atom side, DictRef stack) {
	if (side == key::empty) {
		return key::empty;
	}
	const bool preferred_ranged = gd::bool_field(state, stack, key::ranged, false);
	const ArrayRef objectives = _field_objectives(state, battle);
	for (const Value &objective_value : gd::items(state, array_value(objectives))) {
		if (!gd::is_dict(objective_value)) {
			continue;
		}
		const DictRef objective = objective_value.ref;
		const Atom controller = text_or(state, objective, key::control_side, key::neutral);
		const Atom objective_type = text_or(state, objective, key::type, key::empty);
		const auto labelled = [&](Atom pattern) { return gd::format(state, pattern, {str(_field_objective_label(state, objective))}); };
		if (controller == side) {
			if (objective_type == key::lane_battery) {
				if (preferred_ranged) {
					return labelled(key::objective_s_supports_this_firing_line);
				}
			} else if (objective_type == key::cover_line) {
				return labelled(key::objective_s_is_screening_this_side);
			} else if (objective_type == key::obstruction_line) {
				return labelled(key::objective_s_is_choking_the_lane);
			} else if (objective_type == key::supply_post) {
				return labelled(key::objective_s_is_keeping_this_side);
			} else if (objective_type == key::signal_beacon) {
				return labelled(key::objective_s_is_guiding_command_tempo);
			} else if (objective_type == key::breach_point) {
				return labelled(key::objective_s_currently_favors_this_side);
			} else if (objective_type == key::ritual_pylon || objective_type == key::hazard_zone) {
				return labelled(key::objective_s_currently_pressures_the_enemy);
			}
		} else if (is_player_or_enemy(controller)) {
			if (objective_type == key::lane_battery) {
				if (preferred_ranged || gd::int_field(state, battle, key::distance, 1) > 0) {
					return labelled(key::objective_s_is_still_working_against);
				}
			} else if (objective_type == key::cover_line) {
				return labelled(key::objective_s_is_still_screening_the);
			} else if (objective_type == key::obstruction_line) {
				return labelled(key::objective_s_is_still_clogging_this);
			} else if (objective_type == key::ritual_pylon || objective_type == key::hazard_zone) {
				return labelled(key::objective_s_is_dragging_this_side);
			} else if (objective_type == key::supply_post || objective_type == key::signal_beacon || objective_type == key::breach_point) {
				return labelled(key::objective_s_is_still_in_hostile);
			}
		}
	}
	return key::empty;
}

Atom _terrain_effect_brief(State &state, DictRef battle) {
	if (gd::is_empty(state, battle)) {
		return key::empty;
	}
	std::vector<Atom> parts;
	const int64_t distance = gd::int_field(state, battle, key::distance, 1);
	if (distance > 0) {
		if (_side_controls_field_objective_type(state, battle, key::enemy, key::cover_line)) {
			parts.push_back(key::enemy_cover_still_screens_ranged_stacks);
		} else if (_side_controls_field_objective_type(state, battle, key::player, key::cover_line)) {
			parts.push_back(key::friendly_cover_is_screening_the_firing);
		}
		if (_side_controls_field_objective_type(state, battle, key::enemy, key::obstruction_line)) {
			parts.push_back(gd::format(state, key::enemy_obstruction_can_hold_weak_advances, {str(to_lower(state, _distance_label(state, distance)))}));
		} else if (_side_controls_field_objective_type(state, battle, key::player, key::obstruction_line)) {
			parts.push_back(key::friendly_obstruction_forces_the_enemy_to);
		}
	}
	return join_atoms(state, key::space_bar_space, parts);
}

DictRef _latest_animation_event(State &state, DictRef battle) {
	const ArrayRef events = animation_event_queue(state, battle);
	DictRef latest = state.new_dict();
	int64_t latest_serial = -1;
	for (const Value &event : gd::items(state, array_value(events))) {
		if (!gd::is_dict(event)) {
			continue;
		}
		const int64_t serial = gd::int_field(state, event.ref, key::serial, 0);
		if (gd::is_empty(state, latest) || serial >= latest_serial) {
			latest = event.ref;
			latest_serial = serial;
		}
	}
	return gd::as_dict(gd::engine_duplicate(state, dict_value(latest), true));
}

Atom _animation_event_action_text(State &state, Atom event_id, Atom actor_label, Atom source_label, Atom target_label, DictRef event) {
	if (event_id == key::battle_unit_move) {
		const int64_t to_q = gd::int_field(state, event, key::to_q, -1);
		const int64_t to_r = gd::int_field(state, event, key::to_r, -1);
		if (to_q >= 0 && to_r >= 0) {
			return gd::format(state, key::s_moves_to_d_d, {str(actor_label), int_value(to_q), int_value(to_r)});
		}
		return gd::format(state, key::s_moves, {str(actor_label)});
	}
	if (event_id == key::battle_unit_melee_attack) {
		return gd::format(state, key::s_strikes_s, {str(actor_label), str(target_label != key::empty ? target_label : static_cast<Atom>(key::the_target_text))});
	}
	if (event_id == key::battle_unit_ranged_attack) {
		return gd::format(state, key::s_fires_on_s, {str(actor_label), str(target_label != key::empty ? target_label : static_cast<Atom>(key::the_target_text))});
	}
	if (event_id == key::battle_unit_hit) {
		if (source_label != key::empty) {
			return gd::format(state, key::s_is_hit_by_s, {str(actor_label), str(source_label)});
		}
		return gd::format(state, key::s_is_hit, {str(actor_label)});
	}
	if (event_id == key::battle_unit_death) {
		return gd::format(state, key::s_falls, {str(actor_label)});
	}
	if (event_id == key::battle_unit_cast) {
		const Atom spell_id = gd::strip_edges(state, text_or(state, event, key::spell_id, key::empty));
		if (spell_id != key::empty) {
			return gd::format(state, key::s_casts_s, {str(actor_label), str(gd::capitalize(state, spell_id))});
		}
		return gd::format(state, key::s_casts, {str(actor_label)});
	}
	if (event_id == key::battle_status_applied) {
		if (source_label != key::empty) {
			return gd::format(state, key::s_is_affected_by_s, {str(actor_label), str(source_label)});
		}
		return gd::format(state, key::s_gains_a_status_effect, {str(actor_label)});
	}
	if (event_id == key::battle_status_expired) {
		return gd::format(state, key::s_has_a_status_cleared, {str(actor_label)});
	}
	if (event_id == key::battle_unit_defend) {
		return gd::format(state, key::s_braces, {str(actor_label)});
	}
	if (event_id == key::battle_unit_wait) {
		return gd::format(state, key::s_waits, {str(actor_label)});
	}
	if (event_id == key::battle_retaliation) {
		return gd::format(state, key::retaliates_against_text, {str(actor_label), str(target_label != key::empty ? target_label : static_cast<Atom>(key::the_attacker))});
	}
	if (event_id == key::battle_unit_retreat) {
		return gd::format(state, key::s_retreats, {str(actor_label)});
	}
	if (event_id == key::battle_unit_surrender) {
		return gd::format(state, key::s_surrenders, {str(actor_label)});
	}
	return key::empty;
}

Atom _stack_summary_line(State &state, DictRef stack, DictRef battle, Atom active_id, Atom selected_id) {
	std::vector<Atom> markers;
	if (text_or(state, stack, key::battle_id, key::empty) == active_id) {
		markers.push_back(key::ACT);
	}
	if (text_or(state, stack, key::battle_id, key::empty) == selected_id) {
		markers.push_back(key::TGT);
	}
	Atom role_summary = key::empty;
	if (gd::bool_field(state, stack, key::ranged, false)) {
		role_summary = gd::format(state, key::shots_d, {int_value(gd::int_field(state, stack, key::shots_remaining, 0))});
	} else {
		const int64_t retaliations_left = gd::int_field(state, stack, key::retaliations_left, 0);
		const int64_t retaliations = gd::int_field(state, stack, key::retaliations, 0);
		role_summary = gd::format(state, key::retal_d_d, {int_value(retaliations_left), int_value(retaliations)});
	}
	const Atom ability_summary = _stack_ability_summary(state, stack);
	const DictRef selected_target = get_selected_target(state, battle);
	const Atom ability_role = gd::trim_prefix(state, _active_ability_role_line(state, stack, battle, selected_target), key::role_2);
	const Atom effect_summary = spell_rules::effect_summary(state, stack, battle);
	const Atom status_pressure = _stack_status_pressure_short(state, stack, battle);
	const Atom stance = gd::bool_field(state, stack, key::defending, false) ? static_cast<Atom>(key::defending_2) : static_cast<Atom>(key::empty);
	const Atom marker_text = !markers.empty() ? gd::format(state, key::s_8, {str(join_atoms(state, key::comma, markers))}) : static_cast<Atom>(key::empty);
	const Atom inspection_line = overworld_rules::describe_stack_inspection_line(state, stack, state.new_dict());
	const int64_t attack_total = _stack_attack_total(state, stack, battle);
	const int64_t defense_total = _stack_defense_total(state, stack, battle);
	const int64_t initiative_total = _stack_initiative_total(state, stack, battle);
	const int64_t cohesion_total = _stack_cohesion_total(state, stack, battle);
	const int64_t momentum_total = _stack_momentum_total(state, stack, battle);
	const bool isolated = _stack_is_isolated(state, battle, stack);
	const Atom pressure_text = gd::format(state, key::s_coh_d_mom_d_s, {
			str(role_summary),
			int_value(cohesion_total),
			int_value(momentum_total),
			str(isolated ? static_cast<Atom>(key::iso) : static_cast<Atom>(key::empty)),
	});
	Atom role_text = key::empty;
	if (ability_role != key::empty) {
		role_text = gd::format(state, key::role_s_2, {str(ability_role)});
	} else if (ability_summary != key::empty) {
		role_text = gd::format(state, key::space_bar_space_s, {str(ability_summary)});
	}
	Atom status_text = key::empty;
	if (status_pressure != key::empty) {
		status_text = gd::format(state, key::status_s_2, {str(status_pressure)});
	} else if (effect_summary != key::empty) {
		status_text = gd::format(state, key::space_bar_space_s, {str(effect_summary)});
	}
	return gd::format(state, key::s_s_atk_d_def_d, {
			str(marker_text),
			str(inspection_line),
			int_value(attack_total),
			int_value(defense_total),
			int_value(initiative_total),
			str(pressure_text),
			str(stance),
			str(role_text),
			str(status_text),
	});
}

} // namespace battle_rules

} // namespace aurelion::rules::port
