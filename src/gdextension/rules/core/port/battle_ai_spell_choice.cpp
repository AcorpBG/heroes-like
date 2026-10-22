// Slice 09: BattleAiRules' spell choice: the damage and control spell scores,
// each candidate's score, every cast the hero can make now, the best of them,
// and whether the hero casts it against the mana conservation bar.

#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <initializer_list>
#include <string>

namespace aurelion::rules::port::battle_ai_rules {

using compat::absi;
using compat::engine_clamp;
using compat::engine_max;
using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::str;
namespace key = state::key;

namespace {

bool empty(const State &state, DictRef dict) {
	return gd::is_empty(state, dict);
}

Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

bool one_of(Atom value, std::initializer_list<Atom> atoms) {
	for (const Atom atom : atoms) {
		if (value == atom) {
			return true;
		}
	}
	return false;
}

// The untyped min(a, b) and max(a, b) of floats.
double variant_min_float(double a, double b) {
	return compat::variant_min({ compat::Number::of_float(a), compat::Number::of_float(b) }).f;
}

double variant_max_float(double a, double b) {
	return compat::variant_max({ compat::Number::of_float(a), compat::Number::of_float(b) }).f;
}

// s.to_lower() of ASCII text. Other text is left to GDScript: the Unicode case
// tables are not ported.
Atom lower_text(State &state, Atom text) {
	std::string lowered = state.text(text);
	bool changed = false;
	for (char &c : lowered) {
		if (static_cast<unsigned char>(c) >= 0x80) {
			throw state::NotPorted("BattleAiRules._shared_tactical_spell_conservation_delta: to_lower() of non-ASCII text");
		}
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
			changed = true;
		}
	}
	return changed ? state.intern(lowered) : text;
}

// float(max(0, 100 - SpellRulesScript.control_resistance_pct(battle, target, spell))) / 100.0
double control_success_chance(State &state, DictRef battle, DictRef target, DictRef spell) {
	const int64_t resistance_pct = spell_rules::control_resistance_pct(state, battle, target, spell);
	return static_cast<double>(engine_max<int64_t>(0, gd::sub(100, resistance_pct))) / 100.0;
}

// _objective_action_score(battle, String(active_stack.get("side", "")), "cast_spell", active_stack, target).
double cast_objective_score(State &state, DictRef battle, DictRef active_stack, DictRef target) {
	return _objective_action_score(state, battle, side_of(state, active_stack), key::cast_spell, active_stack, target);
}

// float(int(spell.get("mana_cost", 0)))
double mana_cost(const State &state, DictRef spell) {
	return static_cast<double>(gd::int_field(state, spell, key::mana_cost, 0));
}

// bool(check.get("ok", false))
bool check_ok(const State &state, DictRef check) {
	return gd::bool_field(state, check, key::ok, false);
}

// {"action": "cast_spell", "spell_id": ..., "target_battle_id": ..., "score": ...}
DictRef cast_candidate(State &state, Atom spell_id, Atom target_battle_id, double score) {
	const DictRef candidate = state.new_dict();
	state.set(candidate, str(key::action), str(key::cast_spell));
	state.set(candidate, str(key::spell_id), str(spell_id));
	state.set(candidate, str(key::target_battle_id), str(target_battle_id));
	state.set(candidate, str(key::score), gd::float_value(score));
	return candidate;
}

} // namespace

double _damage_spell_score(State &state, DictRef enemy_hero, DictRef battle, DictRef active_stack, DictRef target, DictRef spell, DictRef damage_projection) {
	DictRef projection = damage_projection;
	if (empty(state, projection)) {
		projection = spell_rules::battle_spell_damage_projection(state, enemy_hero, battle, target, spell);
	}
	const int64_t damage = gd::int_field(state, projection, key::final_damage, 0);
	const int64_t raw_damage = engine_max<int64_t>(1, gd::int_field(state, projection, key::raw_damage, damage));
	const int64_t resistance_pct = gd::int_field(state, projection, key::resistance_pct, 0);
	const double damage_efficiency = engine_clamp(static_cast<double>(damage) / static_cast<double>(raw_damage), 0.0, 1.0);
	double score = (_attack_score(state, active_stack, target, battle, true) + 1.5) * (0.35 + (damage_efficiency * 0.65));
	const double damage_share = variant_min_float(1.0, static_cast<double>(damage) / static_cast<double>(engine_max<int64_t>(1, gd::int_field(state, target, key::total_health, 0))));
	score += damage_share * _w(state, key::spell_damage_share);
	score -= static_cast<double>(resistance_pct) * 0.06;
	const DictRef status_effect = _status_effect_from_spell(state, spell);
	const Atom status_id = gd::string_field(state, status_effect, key::effect_id, key::empty);
	const bool status_rider_fresh = status_id != key::empty
			&& !spell_rules::has_effect_id(state, target, battle, status_id)
			&& !_stack_has_control_effect(state, target, battle);
	if (status_id != key::empty && !spell_rules::has_effect_id(state, target, battle, status_id)) {
		if (spell_rules::target_is_immune_to_status(state, target, battle, status_id)) {
			score -= 2.0;
		} else if (!status_rider_fresh) {
			score -= 1.5;
		} else {
			const double success_chance = control_success_chance(state, battle, target, spell);
			score += 2.0 * success_chance;
			score += _allied_status_synergy_score(state, battle, side_of(state, active_stack), status_id) * success_chance;
			score += _status_tactical_value(state, status_id, target) * success_chance;
		}
		if (status_id == key::status_harried && _health_ratio(state, target) <= 0.75) {
			score += 1.0;
		}
	}
	// status_effect.get("modifiers", {}): a missing key reads as an empty
	// Dictionary, whose cohesion is 0.
	Value status_modifiers;
	const bool has_modifiers = state.lookup(status_effect, str(key::modifiers), status_modifiers);
	if (status_rider_fresh && has_modifiers && gd::is_dict(status_modifiers) && gd::int_field(state, status_modifiers.ref, key::cohesion, 0) < 0) {
		score += static_cast<double>(absi(gd::int_field(state, status_modifiers.ref, key::cohesion, 0))) * 1.3;
	}
	if (_stack_cohesion_total(state, target, battle) <= 4) {
		score += 1.5;
	}
	if (_battle_has_tag(state, battle, key::fog_bank)) {
		score += 1.5;
	}
	if (_battle_has_tag(state, battle, key::battery_nest) && _stack_is_anchor_side(state, active_stack, battle)) {
		score += 1.5;
	}
	if (_battle_has_tag(state, battle, key::wall_pressure)
			&& status_id == key::status_harried
			&& _stack_is_assault_side(state, active_stack, battle)
			&& gd::int_field(state, battle, key::round, 1) >= 3) {
		score += 1.0;
	}
	if (_battle_has_tag(state, battle, key::bog_channels) && status_id == key::status_harried) {
		score += 1.5;
	}
	if (_hero_has_trait(state, battle, side_of(state, active_stack), key::bogwise)
			&& (_battle_has_tag(state, battle, key::bog_channels) || gd::string_field(state, battle, key::terrain, key::empty) == key::mire)) {
		score += 1.0;
	}
	if (_hero_has_trait(state, battle, side_of(state, active_stack), key::packhunter) && _health_ratio(state, target) <= 0.75) {
		score += 1.0;
	}
	score += cast_objective_score(state, battle, active_stack, target);
	score -= mana_cost(state, spell) * 0.25;
	return score;
}

double _spell_candidate_score(State &state, DictRef enemy_hero, DictRef battle, DictRef active_stack, DictRef target, DictRef spell, DictRef behavior, ArrayRef hostiles, double role_modifier, DictRef damage_projection) {
	const Atom effect_type = gd::string_field(state, behavior, key::effect_type, key::empty);
	double score = 0.0;
	if (effect_type == key::damage_enemy) {
		score = _damage_spell_score(state, enemy_hero, battle, active_stack, target, spell, damage_projection);
	} else if (effect_type == key::control_enemy) {
		score = _control_spell_score(state, battle, active_stack, target, spell);
	} else if (effect_type == key::recover_ally) {
		score = _recovery_spell_score_for_target(state, enemy_hero, battle, active_stack, target, spell);
	} else if (effect_type == key::cleanse_ally) {
		score = _cleanse_spell_score_for_target(state, battle, active_stack, target, spell);
	} else if (one_of(effect_type, { key::defense_buff, key::initiative_buff, key::attack_buff })) {
		score = _buff_spell_score(state, battle, active_stack, target, hostiles, spell);
	} else {
		score = -9999.0;
	}
	const double metadata_modifier = _spell_metadata_value_modifier(state, battle, active_stack, target, spell, behavior);
	return score + metadata_modifier + role_modifier;
}

double _control_spell_score(State &state, DictRef battle, DictRef active_stack, DictRef target, DictRef spell) {
	const DictRef status_effect = _status_effect_from_spell(state, spell);
	const Atom status_id = gd::string_field(state, status_effect, key::effect_id, key::empty);
	if (status_id != key::empty && spell_rules::target_is_immune_to_status(state, target, battle, status_id)) {
		return -9999.0;
	}
	const double success_chance = control_success_chance(state, battle, target, spell);
	double score = 3.0 + (_attack_score(state, active_stack, target, battle, true) * 0.35);
	const bool already_controlled = _stack_has_control_effect(state, target, battle);
	score += _target_immediate_threat_score(state, active_stack, target, battle) * 0.75;
	if (status_id != key::empty && !spell_rules::has_effect_id(state, target, battle, status_id)) {
		score += 3.0 * success_chance;
		score += _allied_status_synergy_score(state, battle, side_of(state, active_stack), status_id) * success_chance;
		score += _status_tactical_value(state, status_id, target) * success_chance;
	} else if (status_id != key::empty) {
		score -= 4.0;
	}
	if (already_controlled) {
		score -= 5.0;
	}
	if (_health_ratio(state, target) > 0.5) {
		score += 1.25;
	}
	if (success_chance <= 0.25) {
		score -= 2.0;
	}
	if (gd::bool_field(state, target, key::ranged, false) && gd::int_field(state, target, key::shots_remaining, 0) > 0) {
		score += 1.0;
	}
	if (_stack_cohesion_total(state, target, battle) <= 4) {
		score += 1.0;
	}
	score += cast_objective_score(state, battle, active_stack, target);
	score -= mana_cost(state, spell) * 0.2;
	return score * variant_max_float(0.15, success_chance);
}

ArrayRef _battle_spell_candidates(State &state, DictRef battle, DictRef active_stack, DictRef enemy_hero, ArrayRef targets, ArrayRef lethal_flags) {
	const ArrayRef candidates = state.new_array();
	const Atom acting_side = side_of(state, active_stack);
	const ArrayRef allies = _alive_stacks_for_side(state, battle, side_of(state, active_stack));
	const ArrayRef hostiles = _alive_stacks_for_side(state, battle, _opposing_side(acting_side));
	// validate_battle_spell in two parts: the checks that do not depend on the
	// target run once per spell, on one ready copy of the hero.
	const DictRef hero_copy = gd::deep_duplicate_dict(state, enemy_hero);
	const DictRef caster = spell_rules::ensure_hero_spellbook(state, hero_copy, state.new_dict());
	const ArrayRef spells = spell_rules::known_spells(state, enemy_hero, key::battle);
	for (const Value &spell_value : gd::items(state, array_value(spells))) {
		if (!gd::is_dict(spell_value)) {
			continue;
		}
		const DictRef spell = spell_value.ref;
		const DictRef behavior = spell_rules::battle_spell_behavior(state, spell);
		if (empty(state, behavior) || gd::string_field(state, behavior, key::resolution_type, key::empty) == key::unsupported) {
			continue;
		}
		if (!check_ok(state, spell_rules::battle_spell_cast_check(state, caster, spell, active_stack, acting_side))) {
			continue;
		}
		const double role_modifier = _commander_spell_role_modifier(state, enemy_hero, behavior);
		const Atom effect_type = gd::string_field(state, behavior, key::effect_type, key::empty);
		if (effect_type == key::damage_enemy || effect_type == key::control_enemy) {
			const bool damages = effect_type == key::damage_enemy;
			for (const Value &target_value : gd::items(state, array_value(targets))) {
				if (!gd::is_dict(target_value)) {
					continue;
				}
				const DictRef target = target_value.ref;
				if (!check_ok(state, spell_rules::battle_spell_target_check(state, battle, active_stack, target, spell, acting_side))) {
					continue;
				}
				const DictRef projection = damages ? spell_rules::battle_spell_damage_projection(state, enemy_hero, battle, target, spell) : state.new_dict();
				const Atom spell_id = gd::string_field(state, spell, key::id, key::empty);
				const Atom target_id = gd::string_field(state, target, key::battle_id, key::empty);
				const double score = _spell_candidate_score(state, enemy_hero, battle, active_stack, target, spell, behavior, hostiles, role_modifier, projection);
				const DictRef candidate = cast_candidate(state, spell_id, target_id, score);
				state.append(candidates, dict_value(candidate));
				const bool lethal = damages ? _damage_candidate_is_lethal(state, candidate, battle, enemy_hero, target, projection) : false;
				state.append(lethal_flags, bool_value(lethal));
			}
		} else if (one_of(effect_type, { key::defense_buff, key::recover_ally, key::cleanse_ally })) {
			for (const Value &ally_value : gd::items(state, array_value(allies))) {
				if (!gd::is_dict(ally_value)) {
					continue;
				}
				const DictRef ally = ally_value.ref;
				if (effect_type == key::recover_ally && _stack_missing_health(state, ally) <= 0) {
					continue;
				}
				if (_allied_spell_candidate_suppressed_by_active_buff(state, effect_type, ally, battle, spell)) {
					continue;
				}
				if (!check_ok(state, spell_rules::battle_spell_target_check(state, battle, active_stack, ally, spell, acting_side))) {
					continue;
				}
				const Atom spell_id = gd::string_field(state, spell, key::id, key::empty);
				const Atom target_id = gd::string_field(state, ally, key::battle_id, key::empty);
				const double score = _spell_candidate_score(state, enemy_hero, battle, active_stack, ally, spell, behavior, hostiles, role_modifier, state.new_dict());
				state.append(candidates, dict_value(cast_candidate(state, spell_id, target_id, score)));
				state.append(lethal_flags, bool_value(false));
			}
		} else if (effect_type == key::initiative_buff || effect_type == key::attack_buff) {
			for (const Value &ally_value : gd::items(state, array_value(allies))) {
				if (!gd::is_dict(ally_value)) {
					continue;
				}
				const DictRef ally = ally_value.ref;
				if (_spell_buff_already_active(state, ally, battle, spell)) {
					continue;
				}
				if (!check_ok(state, spell_rules::battle_spell_target_check(state, battle, active_stack, ally, spell, acting_side))) {
					continue;
				}
				const Atom spell_id = gd::string_field(state, spell, key::id, key::empty);
				const Atom target_id = gd::string_field(state, ally, key::battle_id, key::empty);
				const double score = _spell_candidate_score(state, enemy_hero, battle, active_stack, ally, spell, behavior, hostiles, role_modifier, state.new_dict());
				state.append(candidates, dict_value(cast_candidate(state, spell_id, target_id, score)));
				state.append(lethal_flags, bool_value(false));
			}
		}
	}
	return candidates;
}

DictRef _best_spell_action(State &state, DictRef battle, DictRef active_stack, DictRef enemy_hero, ArrayRef targets) {
	if (_commander_spell_cast_this_round(state, battle, side_of(state, active_stack))) {
		return state.new_dict();
	}
	DictRef best = state.new_dict();
	bool best_lethal = false;
	const ArrayRef lethal_flags = state.new_array();
	const ArrayRef candidates = _battle_spell_candidates(state, battle, active_stack, enemy_hero, targets, lethal_flags);
	// _spell_candidate_beats, with each candidate's lethality worked out once.
	const int64_t count = state.array_size(candidates);
	for (int64_t index = 0; index < count; ++index) {
		const DictRef candidate = gd::as_dict(state.at(candidates, index));
		const bool lethal = gd::to_bool(state.at(lethal_flags, index));
		if (empty(state, best) || (lethal && !best_lethal) || (lethal == best_lethal && _candidate_beats(state, candidate, best))) {
			best = candidate;
			best_lethal = lethal;
		}
	}
	return best;
}

bool _hero_cast_worthwhile(State &state, DictRef best_spell, DictRef best_attack, DictRef battle, DictRef active_stack, ArrayRef hostile_targets, DictRef commander_payload, bool lethal_spell_available, bool lethal_attack_available, bool support_needs_pressure) {
	if (empty(state, best_spell)) {
		return false;
	}
	if (lethal_spell_available) {
		return true;
	}
	const DictRef spell = gd::content_row(state, state::ContentTable::Spell, gd::string_field(state, best_spell, key::spell_id, key::empty));
	const DictRef behavior = spell_rules::battle_spell_behavior(state, spell);
	if (empty(state, behavior)) {
		return false;
	}
	const Atom target_id = gd::string_field(state, best_spell, key::target_battle_id, key::empty);
	if (lethal_attack_available
			&& one_of(gd::string_field(state, behavior, key::effect_type, key::empty), { key::damage_enemy, key::control_enemy })
			&& target_id == gd::string_field(state, best_attack, key::target_battle_id, key::empty)) {
		return false;
	}
	const DictRef target_stack = _stack_by_battle_id(state, battle, target_id);
	const double conservation_bar = _shared_tactical_spell_conservation_delta(state, battle, active_stack, target_stack, hostile_targets, commander_payload, behavior, support_needs_pressure);
	return gd::float_field(state, best_spell, key::score, -9999.0) >= conservation_bar;
}

double _shared_tactical_spell_conservation_delta(State &state, DictRef battle, DictRef active_stack, DictRef target_stack, ArrayRef hostile_targets, DictRef commander_payload, DictRef behavior, bool support_needs_pressure) {
	const Atom effect_type = gd::string_field(state, behavior, key::effect_type, key::empty);
	double delta = _w(state, key::spell_bar_default);
	if (effect_type == key::damage_enemy) {
		delta = _w(state, key::spell_bar_damage);
	} else if (effect_type == key::control_enemy) {
		delta = _w(state, key::spell_bar_control);
	} else if (effect_type == key::recover_ally || effect_type == key::cleanse_ally) {
		delta = _w(state, key::spell_bar_recovery);
	} else if (one_of(effect_type, { key::defense_buff, key::initiative_buff, key::attack_buff })) {
		// The condition first, then only the branch it picks.
		if (!support_needs_pressure || _support_spell_has_active_pressure(state, battle, active_stack, target_stack, hostile_targets)) {
			delta = _w(state, key::spell_bar_buff);
		} else {
			delta = 100.0;
		}
	}
	const Atom command_path = lower_text(state, gd::string_field(state, commander_payload, key::command_path, key::empty));
	const Atom archetype = lower_text(state, gd::string_field(state, commander_payload, key::archetype, key::empty));
	if (command_path == key::magic
			|| one_of(archetype, { key::hexcaller, key::starseer, key::rootoracle, key::denaugur, key::drumoracle, key::fogprophet, key::funeralhexer,
					   key::artillerist, key::sharpshooter, key::beaconscribe, key::pressuremath, key::slagalchemist, key::heatrice })) {
		delta -= _w(state, key::spell_bar_caster_discount);
	}
	return variant_max_float(0.75, delta);
}

} // namespace aurelion::rules::port::battle_ai_rules
