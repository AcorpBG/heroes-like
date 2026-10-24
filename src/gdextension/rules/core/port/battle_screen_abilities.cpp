// BattleRules for the battle screen (Phase 7, slice 7.9): ability roles,
// status and effect texts, the field objective preview and the tactical
// briefing.

#include "aurelion_rules/port/battle_screen.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <algorithm>
#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
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
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return string_of(state, state.get(dict, str(field), fallback));
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

// separator.join(array): each item as String(item).
Atom join_array(State &state, Atom separator, ArrayRef parts) {
	std::vector<Atom> atoms;
	for (const Value &part : gd::items(state, array_value(parts))) {
		atoms.push_back(string_of(state, part));
	}
	return join_atoms(state, separator, atoms);
}

// text.trim_suffix(suffix).
Atom trim_suffix(State &state, Atom text, Atom suffix) {
	if (!gd::ends_with(state, text, suffix)) {
		return text;
	}
	const std::string &source = state.text(text);
	return state.intern(source.substr(0, source.size() - state.text(suffix).size()));
}

// text.to_lower() of ASCII text (_distance_label answers only ASCII texts).
Atom to_lower(State &state, Atom text, const char *where) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		const unsigned char byte = static_cast<unsigned char>(c);
		if (byte >= 0x80) {
			throw state::NotPorted(std::string(where) + ": to_lower() of non-ASCII text");
		}
		if (byte >= 'A' && byte <= 'Z') {
			c = static_cast<char>(byte - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

// " (%s)" % modifier_text if modifier_text != "" else "".
Atom modifier_paren(State &state, Atom modifier_text) {
	return modifier_text != key::empty ? gd::format(state, key::s_3, { str(modifier_text) }) : static_cast<Atom>(key::empty);
}

// int(round((1.0 - float(d.get(field, 1.0))) * 100.0)).
int64_t reduction_pct(State &state, DictRef dict, Atom field) {
	return compat::float_to_int(compat::godot_round((1.0 - gd::float_field(state, dict, field, 1.0)) * 100.0));
}

// The body _ability_modifier_text and _effect_modifier_text share.
Atom modifier_text_of(State &state, DictRef owner) {
	Value modifiers;
	if (!state.lookup(owner, str(key::modifiers), modifiers)) {
		return key::empty; // the fallback {} has no modifiers
	}
	if (!gd::is_dict(modifiers)) {
		return key::empty;
	}
	std::vector<Atom> parts;
	for (const Atom modifier_key : { static_cast<Atom>(key::attack), static_cast<Atom>(key::defense), static_cast<Atom>(key::initiative), static_cast<Atom>(key::cohesion), static_cast<Atom>(key::momentum) }) {
		if (!state.has(modifiers.ref, str(modifier_key))) {
			continue;
		}
		const int64_t amount = gd::int_field(state, modifiers.ref, modifier_key, 0);
		if (amount == 0) {
			continue;
		}
		parts.push_back(gd::format(state, key::s_s_d_2, {
				str(port::battle_rules::_status_modifier_label(state, modifier_key)),
				str(amount > 0 ? static_cast<Atom>(key::plus) : static_cast<Atom>(key::empty)),
				int_value(amount),
		}));
	}
	return join_atoms(state, key::comma_space, parts);
}

DictRef session_battle(State &state, DictRef session) {
	return gd::as_dict(gd::index(state, session, str(key::battle)));
}

} // namespace

namespace battle_rules {

Atom _active_ability_role_line(State &state, DictRef stack, DictRef battle, DictRef target) {
	if (gd::is_empty(state, stack)) {
		return key::no_active_ability_role;
	}
	std::vector<Atom> role_lines;
	const DictRef fog_screen = _fog_screen_ability(state, stack);
	if (!gd::is_empty(state, fog_screen)) {
		const Atom fog_state = _fog_screen_available(state, stack, battle, fog_screen) ? static_cast<Atom>(key::reduces_incoming_damage_in_a_natural) : static_cast<Atom>(key::waits_for_a_natural_fog_bank);
		role_lines.push_back(gd::format(state, key::s_s, { str(text_or(state, fog_screen, key::name, str(key::fog_screen_2))), str(fog_state) }));
	}
	const DictRef readiness_writ = _readiness_writ_ability(state, stack);
	if (!gd::is_empty(state, readiness_writ)) {
		role_lines.push_back(gd::format(state, key::s_steadies_one_disrupted_allied_veteran, { str(text_or(state, readiness_writ, key::name, str(key::readiness_writ_name))) }));
	}
	for (const Value &ability : gd::field_items(state, stack, str(key::abilities))) {
		if (!gd::is_dict(ability)) {
			continue;
		}
		const Atom line = _ability_role_sentence(state, stack, ability.ref, battle, target);
		if (line != key::empty) {
			role_lines.push_back(line);
		}
		if (role_lines.size() >= 2) {
			break;
		}
	}
	if (role_lines.empty()) {
		return gd::format(state, key::role_base_s_pressure_no_special, { str(text_or(state, stack, key::role, str(key::combat))) });
	}
	return gd::format(state, key::role_s, { str(join_atoms(state, key::semicolon_space, role_lines)) });
}

Atom _ability_role_sentence(State &state, DictRef stack, DictRef ability, DictRef battle, DictRef target) {
	const Atom ability_id = text_or(state, ability, key::id, str(key::empty));
	// The fallback ability_id.capitalize() only when "name" is missing (it has no effect).
	Value name_value;
	const Atom name = state.lookup(ability, str(key::name), name_value) ? string_of(state, name_value) : gd::capitalize(state, ability_id);
	const Atom status_label = text_or(state, ability, key::status_label, str(key::status));
	const Atom modifier_text = _ability_modifier_text(state, ability);
	bool target_is_marked = false;
	if (!gd::is_empty(state, target)) {
		Value status_ids;
		if (state.lookup(ability, str(key::status_ids), status_ids)) {
			target_is_marked = spell_rules::has_any_effect_ids(state, target, battle, status_ids);
		} // the fallback [] marks nothing
	}
	const bool has_target = !gd::is_empty(state, target);
	if (ability_id == key::reach) {
		Value held_objective_types;
		if (state.lookup(ability, str(key::held_objective_types), held_objective_types) && !ai::vempty(state, held_objective_types)) {
			return gd::format(state, key::s_extends_melee_threat_across_a, { str(name) });
		}
		if (has_target && _stack_hex_distance(state, stack, target) <= 2) {
			return gd::format(state, key::s_keeps_melee_live_from_the, { str(name) });
		}
		return gd::format(state, key::s_extends_melee_threat_before_full, { str(name) });
	}
	if (ability_id == key::hookline) {
		return gd::format(state, key::s_makes_one_reduced_damage_strike, { str(name), str(status_label), str(modifier_paren(state, modifier_text)) });
	}
	if (ability_id == key::rot_cant) {
		return gd::format(state, key::s_applies_s_s_once_per, {
				str(name),
				str(status_label),
				str(modifier_paren(state, modifier_text)),
				int_value(gd::int_field(state, ability, key::target_min_tier, 1)),
		});
	}
	if (ability_id == key::harry) {
		const int64_t required_support = gd::int_field(state, ability, key::min_adjacent_allies_to_target, 0);
		if (required_support > 0) {
			return gd::format(state, key::s_applies_s_s_only_while, {
					str(name),
					str(status_label),
					str(modifier_paren(state, modifier_text)),
					int_value(required_support),
					str(required_support == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::s)),
			});
		}
		const Atom once = gd::int_field(state, ability, key::uses_per_battle, 0) == 1 ? static_cast<Atom>(key::once_per_battle) : static_cast<Atom>(key::empty);
		const Atom tier = gd::int_field(state, ability, key::target_min_tier, 1) > 1
				? gd::format(state, key::against_tier_d_veteran_lines, { int_value(gd::int_field(state, ability, key::target_min_tier, 1)) })
				: static_cast<Atom>(key::empty);
		return gd::format(state, key::s_applies_s_s_s_s, { str(name), str(status_label), str(modifier_paren(state, modifier_text)), str(once), str(tier) });
	}
	if (ability_id == key::obituary) {
		return gd::format(state, key::s_applies_s_s_once_per_2, {
				str(name),
				str(status_label),
				str(modifier_paren(state, modifier_text)),
				int_value(gd::int_field(state, ability, key::braced_target_min_tier, 2)),
		});
	}
	if (ability_id == key::brace) {
		if (gd::float_field(state, ability, key::held_objective_retaliation_multiplier, 1.0) > 1.0) {
			return gd::format(state, key::s_steadies_a_defended_line_applies, { str(name), str(status_label), str(modifier_paren(state, modifier_text)) });
		}
		return gd::format(state, key::s_turns_a_defended_retaliation_into, { str(name), str(status_label), str(modifier_paren(state, modifier_text)) });
	}
	if (ability_id == key::formation_guard) {
		return gd::format(state, key::s_steadies_allied_lanes_and_improves, { str(name) });
	}
	if (ability_id == key::resonance_relay) {
		return gd::format(state, key::s_synchronizes_two_or_more_separately, { str(name) });
	}
	if (ability_id == key::solar_array_lane) {
		return gd::format(state, key::s_screens_allied_sunvault_ranged_stacks, { str(name), int_value(reduction_pct(state, ability, key::incoming_melee_damage_multiplier)) });
	}
	if (ability_id == key::sporeglass_mend) {
		return gd::format(state, key::s_restores_up_to_d_surviving, { str(name), int_value(gd::int_field(state, ability, key::max_health_per_attack, 0)) });
	}
	if (ability_id == key::pressure_artillery) {
		return gd::format(state, key::s_deals_up_to_d_damage, {
				str(name),
				int_value(gd::int_field(state, ability, key::max_secondary_damage, 0)),
				str(text_or(state, ability, key::status_label, str(key::Overheated))),
				int_value(gd::int_field(state, ability, key::duration_rounds, 1)),
		});
	}
	if (ability_id == key::counter_ambush_flare) {
		return gd::format(state, key::s_removes_bonus_damage_from_backstab, { str(name) });
	}
	if (ability_id == key::foundry_aura) {
		return gd::format(state, key::s_hardens_overheated_combine_machinery_and, { str(name) });
	}
	if (ability_id == key::volley) {
		if (gd::bool_field(state, ability, key::requires_protected_lane, false)) {
			return gd::format(state, key::s_delivers_heavy_ranged_pressure_only, { str(name) });
		}
		return gd::format(state, key::s_rewards_an_open_firing_lane, { str(name), str(target_is_marked ? static_cast<Atom>(key::into_marked_targets) : static_cast<Atom>(key::empty)) });
	}
	if (ability_id == key::backstab) {
		const bool now = target_is_marked || (has_target && _health_ratio(state, target) <= gd::float_field(state, ability, key::health_threshold_ratio, 0.0));
		return gd::format(state, key::s_punishes_marked_or_wounded_targets, { str(name), str(now ? static_cast<Atom>(key::now) : static_cast<Atom>(key::empty)) });
	}
	if (ability_id == key::fogwake) {
		const bool now = has_target && _stack_is_hex_isolated(state, battle, target);
		return gd::format(state, key::s_strikes_harder_and_applies_s, {
				str(name),
				str(status_label),
				str(modifier_paren(state, modifier_text)),
				str(now ? static_cast<Atom>(key::now) : static_cast<Atom>(key::empty)),
		});
	}
	if (ability_id == key::bloodrush) {
		const int64_t clean_penalty_pct = reduction_pct(state, ability, key::clean_target_damage_multiplier);
		const bool isolated_payoff = gd::float_field(state, ability, key::isolated_damage_multiplier, 1.0) > 1.0;
		const bool target_is_isolated = isolated_payoff && has_target && _stack_is_hex_isolated(state, battle, target);
		const bool target_is_prepared = target_is_marked || target_is_isolated || (has_target && _health_ratio(state, target) <= gd::float_field(state, ability, key::wounded_threshold_ratio, 0.0));
		const Atom penalty = clean_penalty_pct > 0 ? gd::format(state, key::clean_primary_attacks_lose_d_damage, { int_value(clean_penalty_pct) }) : static_cast<Atom>(key::empty);
		return gd::format(state, key::s_hits_harder_through_wounded_or, {
				str(name),
				str(isolated_payoff ? static_cast<Atom>(key::or_against_isolated_prey) : static_cast<Atom>(key::empty)),
				str(target_is_prepared ? static_cast<Atom>(key::now) : static_cast<Atom>(key::empty)),
				str(penalty),
		});
	}
	if (ability_id == key::overheat) {
		if (spell_rules::has_effect_id(state, stack, battle, key::status_overheated)) {
			return gd::format(state, key::s_is_cooling_under_reduced_damage, { str(name) });
		}
		return gd::format(state, key::s_is_pressure_ready_for_one, { str(name) });
	}
	if (ability_id == key::shielding) {
		const int64_t ranged_reduction_pct = reduction_pct(state, ability, key::ranged_damage_multiplier);
		const int64_t ranged_return_pct = compat::float_to_int(compat::godot_round(gd::float_field(state, ability, key::ranged_damage_return_ratio, 0.0) * 100.0));
		const DictRef authored_shielding = _authored_ability_by_id(state, stack, key::shielding);
		const int64_t linked_screen_pct = gd::int_field(state, authored_shielding, key::linked_ranged_damage_reduction_pct, 0);
		if (ranged_return_pct > 0) {
			if (linked_screen_pct > 0) {
				return gd::format(state, key::s_blunts_d_of_incoming_ranged, { str(name), int_value(ranged_reduction_pct), int_value(ranged_return_pct), int_value(linked_screen_pct) });
			}
			return gd::format(state, key::s_blunts_d_of_incoming_ranged_2, { str(name), int_value(ranged_reduction_pct), int_value(ranged_return_pct) });
		}
		const int64_t committed_screen_pct = gd::int_field(state, authored_shielding, key::committed_assault_screen_reduction_pct, 0);
		if (committed_screen_pct > 0) {
			return gd::format(state, key::s_blunts_missiles_and_screens_allied, { str(name), int_value(committed_screen_pct) });
		}
		if (gd::int_field(state, ability, key::ally_ranged_melee_damage_reduction_pct, 0) > 0 || gd::int_field(state, ability, key::linebreaker_screen_bonus_pct, 0) > 0) {
			return gd::format(state, key::s_blunts_missiles_and_screens_allied_2, { str(name) });
		}
		if (gd::float_field(state, ability, key::harried_damage_multiplier, 1.0) > 1.0) {
			return gd::format(state, key::s_blunts_d_of_incoming_ranged_3, { str(name), int_value(ranged_reduction_pct) });
		}
		return gd::format(state, key::s_blunts_missile_pressure_and_helps, { str(name) });
	}
	if (text_or(state, ability, key::description, str(key::empty)) != key::empty) {
		return gd::format(state, key::s_colon_s_text, { str(name), str(text_or(state, ability, key::description, str(key::empty))) });
	}
	return name;
}

Atom _ability_modifier_text(State &state, DictRef ability) {
	return modifier_text_of(state, ability);
}

// The header's parameter is `key`; here key_name, so key:: stays the keys.
Atom _status_modifier_label(State &state, Atom key_name) {
	if (key_name == key::attack) {
		return key::Atk;
	}
	if (key_name == key::defense) {
		return key::Def;
	}
	if (key_name == key::initiative) {
		return key::Init;
	}
	if (key_name == key::cohesion) {
		return key::Coh;
	}
	if (key_name == key::momentum) {
		return key::Mom;
	}
	return gd::capitalize(state, key_name);
}

Atom _stack_status_pressure_line(State &state, DictRef stack, DictRef battle) {
	if (gd::is_empty(state, stack)) {
		return key::status_pressure_no_stack_selected;
	}
	const ArrayRef effects = spell_rules::active_effects_for_round(state, stack, gd::int_field(state, battle, key::round, 1));
	std::vector<Atom> parts;
	for (const Value &effect : gd::items(state, array_value(effects))) {
		if (!gd::is_dict(effect)) {
			continue;
		}
		const int64_t expires = gd::int_field(state, effect.ref, key::expires_after_round, gd::int_field(state, battle, key::round, 1));
		const int64_t rounds_left = gd::add(gd::sub(expires, gd::int_field(state, battle, key::round, 1)), 1);
		const Atom modifier_text = _effect_modifier_text(state, effect.ref);
		const Value kind_fallback = state.get(effect.ref, str(key::kind), str(key::status_title));
		parts.push_back(gd::format(state, key::s_dr_s, {
				str(text_or(state, effect.ref, key::label, kind_fallback)),
				int_value(std::max<int64_t>(1, rounds_left)),
				str(modifier_paren(state, modifier_text)),
		}));
	}
	if (!parts.empty()) {
		return gd::format(state, key::status_pressure_s, { str(join_atoms(state, key::semicolon_space, parts)) });
	}
	std::vector<Atom> pressure_bits;
	pressure_bits.push_back(gd::format(state, key::coh_d, { int_value(_stack_cohesion_total(state, stack, battle)) }));
	pressure_bits.push_back(gd::format(state, key::mom_d, { int_value(_stack_momentum_total(state, stack, battle)) }));
	if (gd::bool_field(state, stack, key::defending, false)) {
		pressure_bits.push_back(key::Defending);
	}
	if (_stack_is_isolated(state, battle, stack)) {
		pressure_bits.push_back(key::Isolated);
	}
	return gd::format(state, key::status_pressure_clear_s, { str(join_atoms(state, key::comma_space, pressure_bits)) });
}

Atom _stack_status_pressure_short(State &state, DictRef stack, DictRef battle) {
	const Atom line = _stack_status_pressure_line(state, stack, battle);
	return trim_suffix(state, gd::trim_prefix(state, line, key::status_pressure), key::period);
}

Atom _effect_modifier_text(State &state, DictRef effect) {
	return modifier_text_of(state, effect);
}

Atom _target_range_readiness_line(State &state, DictRef active_stack, DictRef target, DictRef battle) {
	if (gd::is_empty(state, active_stack)) {
		return key::target_range_no_active_stack;
	}
	if (gd::is_empty(state, target)) {
		const Atom distance = to_lower(state, _distance_label(state, gd::int_field(state, battle, key::distance, 1)), "BattleRules._target_range_readiness_line");
		return gd::format(state, key::target_range_select_an_enemy_stack, { str(distance) });
	}
	const DictRef legality = _attack_legality_for_target(state, active_stack, target, battle);
	const Atom readiness = gd::bool_field(state, legality, key::attackable, false) ? static_cast<Atom>(key::ready) : static_cast<Atom>(key::blocked);
	std::vector<Atom> options;
	if (gd::bool_field(state, legality, key::melee, false)) {
		options.push_back(key::Strike);
	}
	if (gd::bool_field(state, legality, key::ranged, false)) {
		options.push_back(key::Shoot);
	}
	if (options.empty()) {
		options.push_back(key::move_first);
	}
	return gd::format(state, key::target_range_s_is_s_at, {
			str(_stack_label(state, target)),
			str(readiness),
			int_value(gd::int_field(state, legality, key::hex_distance, -1)),
			str(join_atoms(state, key::or_, options)),
	});
}

Atom _field_objective_action_preview(State &state, DictRef battle, DictRef action_context) {
	const Atom acting_side = text_or(state, action_context, key::side, str(key::empty));
	if (acting_side != key::player && acting_side != key::enemy) {
		return key::empty;
	}
	const DictRef acting_stack = _get_stack_by_id(state, battle, text_or(state, action_context, key::battle_id, str(key::empty)));
	const DictRef target_stack = _get_stack_by_id(state, battle, text_or(state, action_context, key::target_battle_id, str(key::empty)));
	std::vector<Atom> notes;
	const ArrayRef objectives = _field_objectives(state, battle);
	for (const Value &objective : gd::items(state, array_value(objectives))) {
		if (!gd::is_dict(objective)) {
			continue;
		}
		const int64_t influence = _field_objective_action_influence(state, objective.ref, battle, acting_side, action_context, acting_stack, target_stack);
		if (influence <= 0) {
			continue;
		}
		const DictRef projection = _project_field_objective_state(state, objective.ref, acting_side, influence);
		const Atom label = _field_objective_label(state, objective.ref);
		if (gd::bool_field(state, projection, key::flipped, false)) {
			notes.push_back(gd::format(state, key::s_would_swing_to_s_control, { str(label), str(_side_label(acting_side)) }));
			continue;
		}
		if (text_or(state, objective.ref, key::control_side, str(key::neutral)) == acting_side) {
			notes.push_back(gd::format(state, key::s_hold_strengthens, { str(label) }));
			continue;
		}
		const Atom progress_side = text_or(state, projection, key::progress_side, str(key::empty));
		const int64_t progress_value = gd::int_field(state, projection, key::progress_value, 0);
		const Value threshold_fallback = state.get(objective.ref, str(key::capture_threshold), int_value(2));
		const int64_t threshold = gd::to_int(state, state.get(projection, str(key::capture_threshold), threshold_fallback));
		if (progress_side == acting_side && progress_value > 0) {
			notes.push_back(gd::format(state, key::s_moves_to_d_d_toward, { str(label), int_value(progress_value), int_value(threshold), str(_side_label(acting_side)) }));
		}
		if (notes.size() >= 2) {
			break;
		}
	}
	return join_atoms(state, key::semicolon_space, notes);
}

DictRef _project_field_objective_state(State &state, DictRef objective, Atom acting_side, int64_t amount) {
	const DictRef projection = gd::deep_duplicate_dict(state, objective);
	Atom controller = text_or(state, projection, key::control_side, str(key::neutral));
	Atom progress_side = text_or(state, projection, key::progress_side, str(key::empty));
	int64_t progress_value = std::max<int64_t>(0, gd::int_field(state, projection, key::progress_value, 0));
	const int64_t threshold = std::max<int64_t>(1, gd::int_field(state, projection, key::capture_threshold, 2));
	bool flipped = false;
	if (controller == acting_side) {
		if (progress_side != key::empty && progress_side != acting_side) {
			progress_value = std::max<int64_t>(0, gd::sub(progress_value, amount));
			if (progress_value <= 0) {
				progress_side = key::empty;
			}
		}
	} else {
		if (progress_side != key::empty && progress_side != acting_side) {
			progress_value = std::max<int64_t>(0, gd::sub(progress_value, amount));
			if (progress_value <= 0) {
				progress_side = acting_side;
				progress_value = amount;
			}
		} else {
			progress_side = acting_side;
			progress_value = gd::add(progress_value, amount);
		}
		if (progress_value >= threshold) {
			controller = acting_side;
			progress_side = key::empty;
			progress_value = 0;
			flipped = true;
		}
	}
	state.set(projection, str(key::control_side), str(controller));
	state.set(projection, str(key::progress_side), str(progress_side));
	state.set(projection, str(key::progress_value), int_value(progress_side != key::empty ? progress_value : 0));
	state.set(projection, str(key::capture_threshold), int_value(threshold));
	state.set(projection, str(key::flipped), gd::bool_value(flipped));
	return projection;
}

bool _should_surface_tactical_briefing(State &state, DictRef session) {
	// GDScript's session == null: a view is never null.
	const DictRef battle = session_battle(state, session);
	if (gd::is_empty(state, battle)) {
		return false;
	}
	if (gd::to_string(gd::index(state, session, str(key::scenario_status))) != key::in_progress) {
		return false;
	}
	if (gd::int_field(state, battle, key::round, 1) != 1) {
		return false;
	}
	Value briefing_state;
	if (!state.lookup(battle, str(key::tactical_briefing), briefing_state)) {
		return true; // the fallback {} is a Dictionary without "shown"
	}
	return gd::is_dict(briefing_state) && !gd::bool_field(state, briefing_state.ref, key::shown, false);
}

ArrayRef _tactical_briefing_lines(State &state, DictRef session) {
	const DictRef battle = session_battle(state, session);
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, gd::to_string(gd::index(state, session, str(key::scenario_id))));
	const ArrayRef lines = state.new_array();
	const Atom battlefield_line = _tactical_battlefield_line(state, session, battle);
	if (battlefield_line != key::empty) {
		state.append(lines, str(battlefield_line));
	}
	const Atom objective_line = _tactical_objective_line(state, session, battle, scenario);
	if (objective_line != key::empty) {
		state.append(lines, str(objective_line));
	}
	const Atom field_objective_line = _tactical_field_objective_line(state, battle);
	if (field_objective_line != key::empty) {
		state.append(lines, str(field_objective_line));
	}
	const Atom doctrine_line = _tactical_enemy_doctrine_line(state, battle);
	if (doctrine_line != key::empty) {
		state.append(lines, str(doctrine_line));
	}
	const Atom pressure_line = _tactical_opening_pressure_line(state, session, battle);
	if (pressure_line != key::empty) {
		state.append(lines, str(pressure_line));
	}
	const Atom decisive_line = _tactical_decisive_target_line(state, battle);
	if (decisive_line != key::empty) {
		state.append(lines, str(decisive_line));
	}
	const Atom caution_line = _tactical_caution_line(state, session, battle);
	if (caution_line != key::empty) {
		state.append(lines, str(caution_line));
	}
	return lines;
}

Atom _tactical_battlefield_line(State &state, DictRef session, DictRef battle) {
	std::vector<Atom> parts;
	parts.push_back(gd::capitalize(state, text_or(state, battle, key::terrain, str(key::plains))));
	parts.push_back(_distance_label(state, gd::int_field(state, battle, key::distance, 1)));
	const Atom identity_summary = _battlefield_identity_summary(state, battle);
	if (identity_summary != key::empty) {
		parts.push_back(identity_summary);
	}
	const ArrayRef tag_labels = _battlefield_tag_labels(state, battle);
	if (state.array_size(tag_labels) != 0) {
		parts.push_back(gd::format(state, key::tags_s_2, { str(join_array(state, key::comma_space, tag_labels)) }));
	}
	// The fallback {} matches no context type, as a missing context does.
	const Value context = gd::field(state, battle, key::context);
	if (_is_town_defense_context(state, context) || _is_town_assault_context(state, context)) {
		parts.push_back(_battle_context_label(state, session, state.get(battle, str(key::context), dict_value(state.new_dict()))));
	}
	return gd::format(state, key::battlefield_s, { str(join_atoms(state, key::space_bar_space, parts)) });
}

Atom _tactical_objective_line(State &state, DictRef session, DictRef battle, DictRef scenario) {
	// The fallback {} matches no context type, as a missing context does.
	const Value context = gd::field(state, battle, key::context);
	if (_is_town_defense_context(state, context)) {
		const Atom town_name = _town_name_from_placement_id(state, dict_value(session), text_or(state, context.ref, key::town_placement_id, str(key::empty)));
		return gd::format(state, key::battle_aim_hold_s_a_collapse, { str(town_name != key::empty ? town_name : static_cast<Atom>(key::the_walls)) });
	}
	if (_is_town_assault_context(state, context)) {
		const Atom assault_town_name = _town_name_from_placement_id(state, dict_value(session), text_or(state, context.ref, key::town_placement_id, str(key::empty)));
		return gd::format(state, key::battle_aim_take_s_breaking_the, { str(assault_town_name != key::empty ? assault_town_name : static_cast<Atom>(key::the_walls)) });
	}
	const DictRef encounter_objective = _encounter_objective_for_battle(state, session, battle, scenario);
	if (!gd::is_empty(state, encounter_objective)) {
		return gd::format(state, key::battle_aim_s, { str(scenario_rules::_objective_label(state, session, encounter_objective)) });
	}
	Value objectives;
	if (!state.lookup(scenario, str(key::objectives), objectives)) {
		return key::empty; // the fallback {} has no victory bucket, so no labels
	}
	if (gd::is_dict(objectives)) {
		const Value bucket = state.get(objectives.ref, str(key::victory), array_value(state.new_array()));
		const ArrayRef victory_labels = scenario_rules::_objective_labels_from_bucket(state, session, bucket, 1);
		if (state.array_size(victory_labels) != 0) {
			return gd::format(state, key::battle_aim_s, { str(string_of(state, state.at(victory_labels, 0))) });
		}
	}
	return key::empty;
}

Atom _tactical_field_objective_line(State &state, DictRef battle) {
	const Atom objective_summary = _field_objective_pressure_summary(state, battle);
	return objective_summary != key::empty ? gd::format(state, key::battlefield_objective_s, { str(objective_summary) }) : static_cast<Atom>(key::empty);
}

Atom _tactical_enemy_doctrine_line(State &state, DictRef battle) {
	const DictRef commander_state = _commander_state_for_side(state, battle, key::enemy);
	const Atom doctrine = _side_doctrine_summary(state, battle, key::enemy);
	const Atom commander_name = text_or(state, commander_state, key::name, str(key::enemy_command));
	const ArrayRef trait_labels = _battle_trait_labels(state, _normalized_battle_traits(state, dict_value(commander_state)));
	std::vector<Atom> parts;
	parts.push_back(gd::format(state, key::s_s_text, { str(commander_name), str(doctrine) }));
	if (state.array_size(trait_labels) != 0) {
		parts.push_back(gd::format(state, key::traits_s, { str(join_array(state, key::comma_space, trait_labels)) }));
	}
	return gd::format(state, key::enemy_doctrine_s, { str(join_atoms(state, key::space_bar_space, parts)) });
}

Atom _tactical_opening_pressure_line(State &state, DictRef session, DictRef battle) {
	const DictRef player_totals = _army_totals(state, battle, key::player);
	const DictRef enemy_totals = _army_totals(state, battle, key::enemy);
	const Atom pressure = _pressure_brief(state, session);
	const int64_t player_ranged = gd::int_field(state, player_totals, key::ranged_stacks, 0);
	const int64_t enemy_ranged = gd::int_field(state, enemy_totals, key::ranged_stacks, 0);
	const Atom withdrawal = _withdrawal_pressure_label(state, battle, _battle_retreat_allowed(state, battle));
	return gd::format(state, key::opening_pressure_s_friendly_ranged_d, { str(pressure), int_value(player_ranged), int_value(enemy_ranged), str(withdrawal) });
}

Atom _tactical_decisive_target_line(State &state, DictRef battle) {
	const DictRef target = _priority_enemy_stack_for_briefing(state, battle);
	if (gd::is_empty(state, target)) {
		return key::empty;
	}
	return gd::format(state, key::decisive_target_s_s, { str(_stack_label(state, target)), str(_priority_target_reason(state, target, battle)) });
}

Atom _tactical_caution_line(State &state, DictRef session, DictRef battle) {
	(void)session;
	if (_battle_has_tag(state, battle, key::battery_nest) && gd::int_field(state, battle, key::distance, 1) > 0) {
		return key::tactical_caution_the_approach_stays_exposed;
	}
	if (_side_controls_field_objective_type(state, battle, key::enemy, key::cover_line) && gd::int_field(state, battle, key::distance, 1) > 0) {
		return key::tactical_caution_enemy_cover_still_screens;
	}
	if (_side_controls_field_objective_type(state, battle, key::enemy, key::obstruction_line) && gd::int_field(state, battle, key::distance, 1) > 0) {
		return key::tactical_caution_the_obstruction_line_can;
	}
	if (_battle_has_tag(state, battle, key::fortress_lane)) {
		return key::tactical_caution_fortress_lanes_compress_melee;
	}
	if (_battle_has_tag(state, battle, key::wall_pressure) && gd::int_field(state, battle, key::round, 1) <= 2) {
		return key::tactical_caution_delay_the_breach_now;
	}
	const DictRef player_totals = _army_totals(state, battle, key::player);
	const DictRef enemy_totals = _army_totals(state, battle, key::enemy);
	if (gd::int_field(state, enemy_totals, key::ranged_stacks, 0) > gd::int_field(state, player_totals, key::ranged_stacks, 0) && gd::int_field(state, battle, key::distance, 1) > 0) {
		return key::tactical_caution_enemy_shooting_outranges_your;
	}
	if (gd::int_field(state, player_totals, key::ranged_stacks, 0) > gd::int_field(state, enemy_totals, key::ranged_stacks, 0) && gd::int_field(state, battle, key::distance, 1) > 0) {
		return key::tactical_edge_you_own_the_cleaner;
	}
	const Value context = gd::field(state, battle, key::context);
	if (_is_town_defense_context(state, context)) {
		return key::tactical_caution_retreat_is_locked_on;
	}
	if (_is_town_assault_context(state, context)) {
		return key::tactical_caution_if_the_breach_stalls;
	}
	return key::empty;
}

} // namespace battle_rules

} // namespace aurelion::rules::port
