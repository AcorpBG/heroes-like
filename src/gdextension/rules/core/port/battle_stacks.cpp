// Phase 2a: a battle stack from its unit and its abilities, the field objectives, and a town battle's buildings on
// the field (TownBattleRules.prepare).

#include "aurelion_rules/port/battle_payload.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/phase2a_deps.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include <initializer_list>
#include <string>
#include <unordered_set>
#include <utility>
#include <vector>

namespace aurelion::rules::port {

namespace {

using compat::engine_clamp;
using compat::engine_max;
using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::float_value;
using gd::int_value;
using gd::str;
namespace key = state::key;

// SpellRules.MAX_SPELL_RESISTANCE_PCT and MAX_CONTROL_RESISTANCE_PCT.
constexpr int64_t kMaxSpellResistancePct = 75;
constexpr int64_t kMaxControlResistancePct = 80;

// x.get(key, fallback) on an untyped value: only a Dictionary has a two-argument
// get (Array.get and Object.get take one), so anything else stops the script.
[[noreturn]] void no_two_argument_get(const Value &target) {
	throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' with two arguments in base '") + gd::type_name(target) + "'.");
}

Value variant_get(const State &state, const Value &target, Atom field, const Value &fallback) {
	if (!gd::is_dict(target)) {
		no_two_argument_get(target);
	}
	return state.get(target.ref, str(field), fallback);
}

void put(State &state, DictRef dict, Atom field, const Value &value) {
	state.set(dict, str(field), value);
}

// An Array literal of Strings: a new Array on every evaluation.
ArrayRef string_array(State &state, std::initializer_list<Atom> texts) {
	const ArrayRef array = state.new_array();
	for (const Atom text : texts) {
		state.append(array, str(text));
	}
	return array;
}

// The reads _normalize_unit_abilities makes of an authored ability, each written
// under the same field of the normalized one.

// String(entry.get(field, fallback)).
void put_text(State &state, DictRef normalized, DictRef entry, Atom field, Atom fallback) {
	put(state, normalized, field, str(gd::string_field(state, entry, field, fallback)));
}

// bool(entry.get(field, fallback)).
void put_flag(State &state, DictRef normalized, DictRef entry, Atom field, bool fallback) {
	put(state, normalized, field, bool_value(gd::bool_field(state, entry, field, fallback)));
}

// clampf(float(entry.get(field, fallback)), lo, hi).
void put_clamped_float(State &state, DictRef normalized, DictRef entry, Atom field, double fallback, double lo, double hi) {
	put(state, normalized, field, float_value(engine_clamp<double>(gd::float_field(state, entry, field, fallback), lo, hi)));
}

// clampi(int(entry.get(field, fallback)), lo, hi), and the untyped clamp() of
// those ints (an int, the same one: lo <= hi everywhere).
void put_clamped_int(State &state, DictRef normalized, DictRef entry, Atom field, int64_t fallback, int64_t lo, int64_t hi) {
	put(state, normalized, field, int_value(engine_clamp<int64_t>(gd::int_field(state, entry, field, fallback), lo, hi)));
}

// maxi(lo, int(entry.get(field, fallback))), and the untyped max() of those ints.
void put_at_least(State &state, DictRef normalized, DictRef entry, Atom field, int64_t fallback, int64_t lo) {
	put(state, normalized, field, int_value(engine_max<int64_t>(lo, gd::int_field(state, entry, field, fallback))));
}

// _normalize_string_array(entry.get(field, [texts])): the fallback literal is
// made only when the key is missing (the callee only reads it).
void put_strings(State &state, DictRef normalized, DictRef entry, Atom field, std::initializer_list<Atom> fallback) {
	Value found;
	const Value value = state.lookup(entry, str(field), found) ? found : array_value(string_array(state, fallback));
	put(state, normalized, field, array_value(battle_rules::_normalize_string_array(state, value)));
}

// _normalize_ability_modifiers(entry.get(field, {name: amount, ...})), the
// literal in its order, made only when the key is missing.
void put_modifiers(State &state, DictRef normalized, DictRef entry, Atom field, std::initializer_list<std::pair<Atom, int64_t>> fallback) {
	Value value;
	if (!state.lookup(entry, str(field), value)) {
		const DictRef literal = state.new_dict();
		for (const auto &modifier : fallback) {
			state.set(literal, str(modifier.first), int_value(modifier.second));
		}
		value = dict_value(literal);
	}
	put(state, normalized, field, dict_value(battle_rules::_normalize_ability_modifiers(state, value)));
}

// The "id", "name" and "description" every normalized ability starts with.
void put_identity(State &state, DictRef normalized, DictRef entry, Atom ability_id, Atom default_name) {
	put(state, normalized, key::id, str(ability_id));
	put_text(state, normalized, entry, key::name, default_name);
	put_text(state, normalized, entry, key::description, key::empty);
}

} // namespace

namespace battle_rules {

DictRef _build_battle_stack(State &state, Atom unit_id, int64_t count, Atom side, int64_t index, DictRef source, int64_t army_slot_index) {
	const DictRef unit = gd::content_row(state, state::ContentTable::Unit, unit_id);
	if (gd::is_empty(state, unit)) {
		return state.new_dict();
	}
	const int64_t unit_hp = engine_max<int64_t>(1, gd::int_field(state, unit, key::hp, 1));
	const int64_t cohesion_base = _cohesion_base_for_unit(state, unit);
	const Atom faction_id = gd::string_field(state, unit, key::faction_id, key::empty);
	// load_json(...).get("units", {}).get(unit_id, {}) is only read: a missing
	// key reads as an empty body.
	const DictRef manifest = gd::content_file(state, key::unit_battle_size_manifest_path);
	bool has_body = false;
	DictRef body = 0;
	Value units;
	if (state.lookup(manifest, str(key::units), units)) {
		if (!gd::is_dict(units)) {
			no_two_argument_get(units);
		}
		Value found;
		if (state.lookup(units.ref, str(unit_id), found)) {
			body = gd::as_dict(found);
			has_body = true;
		}
	}
	Atom affiliation = gd::string_field(state, unit, key::affiliation, key::empty);
	if (affiliation == key::empty) {
		affiliation = faction_id != key::empty ? key::faction : key::neutral;
	}
	const int64_t footprint = has_body ? gd::int_field(state, body, key::footprint, 1) : 1;
	const double visual_scale = has_body ? gd::float_field(state, body, key::visual_scale, 1.0) : 1.0;
	const DictRef stack = state.new_dict();
	put(state, stack, key::battle_id, str(gd::format(state, key::s_d_s_2, { str(side), int_value(index), str(unit_id) })));
	put(state, stack, key::side, str(side));
	put(state, stack, key::faction_id, str(faction_id));
	put(state, stack, key::affiliation, str(affiliation));
	put(state, stack, key::unit_id, str(unit_id));
	put(state, stack, key::army_slot_index, int_value(army_slot_index >= 0 && army_slot_index < 7 ? army_slot_index : index));
	put(state, stack, key::battle_footprint, int_value(footprint == 2 ? 2 : 1));
	put(state, stack, key::battle_visual_scale, float_value(engine_clamp<double>(visual_scale, 0.65, 1.6)));
	put(state, stack, key::name, str(gd::string_field(state, unit, key::name, unit_id)));
	put(state, stack, key::tier, int_value(engine_clamp<int64_t>(gd::int_field(state, unit, key::tier, 1), 1, 7)));
	put(state, stack, key::unit_hp, int_value(unit_hp));
	put(state, stack, key::total_health, int_value(gd::mul(engine_max<int64_t>(0, count), unit_hp)));
	put(state, stack, key::base_count, int_value(engine_max<int64_t>(0, count)));
	put(state, stack, key::attack, int_value(gd::int_field(state, unit, key::attack, 0)));
	put(state, stack, key::defense, int_value(gd::int_field(state, unit, key::defense, 0)));
	put(state, stack, key::min_damage, int_value(gd::int_field(state, unit, key::min_damage, 1)));
	put(state, stack, key::max_damage, int_value(gd::int_field(state, unit, key::max_damage, 1)));
	put(state, stack, key::initiative, int_value(gd::int_field(state, unit, key::initiative, 1)));
	put(state, stack, key::speed, int_value(gd::int_field(state, unit, key::speed, 1)));
	put(state, stack, key::ranged, bool_value(gd::bool_field(state, unit, key::ranged, false)));
	put(state, stack, key::retaliations, int_value(engine_max<int64_t>(0, gd::int_field(state, unit, key::retaliations, 1))));
	put(state, stack, key::retaliations_left, int_value(engine_max<int64_t>(0, gd::int_field(state, unit, key::retaliations, 1))));
	put(state, stack, key::shots_remaining, int_value(gd::int_field(state, unit, key::shots, 0)));
	put(state, stack, key::spell_resistance_pct, int_value(engine_clamp<int64_t>(gd::int_field(state, unit, key::spell_resistance_pct, 0), 0, kMaxSpellResistancePct)));
	put(state, stack, key::control_resistance_pct, int_value(engine_clamp<int64_t>(gd::int_field(state, unit, key::control_resistance_pct, 0), 0, kMaxControlResistancePct)));
	// The {} and [] fallbacks below are only read: a missing key (Nil) normalizes
	// as the empty container does.
	put(state, stack, key::spell_school_resistance_pct, dict_value(spell_rules::normalize_school_resistance(state, gd::field(state, unit, key::spell_school_resistance_pct))));
	put(state, stack, key::status_immunity_ids, array_value(spell_rules::normalize_status_immunity_ids(state, gd::field(state, unit, key::status_immunity_ids))));
	put(state, stack, key::defending, bool_value(false));
	put(state, stack, key::cohesion_base, int_value(cohesion_base));
	put(state, stack, key::cohesion, int_value(cohesion_base));
	put(state, stack, key::momentum, int_value(0));
	put(state, stack, key::hex, dict_value(state.new_dict()));
	put(state, stack, key::abilities, array_value(_normalize_unit_abilities(state, gd::field(state, unit, key::abilities))));
	put(state, stack, key::ability_uses, dict_value(state.new_dict()));
	put(state, stack, key::effects, array_value(state.new_array()));
	put(state, stack, key::source_type, str(gd::string_field(state, source, key::source_type, key::empty)));
	put(state, stack, key::source_hero_id, str(gd::string_field(state, source, key::hero_id, key::empty)));
	put(state, stack, key::source_town_placement_id, str(gd::string_field(state, source, key::town_placement_id, key::empty)));
	put(state, stack, key::source_encounter_key, str(gd::string_field(state, source, key::encounter_key, key::empty)));
	return stack;
}

ArrayRef _normalize_unit_abilities(State &state, const Value &value) {
	const ArrayRef abilities = state.new_array();
	// seen stays local: the ids appended so far.
	std::unordered_set<Atom> seen;
	if (!gd::is_array(value)) {
		return abilities;
	}
	for (const Value &entry_value : gd::items(state, value)) {
		if (!gd::is_dict(entry_value)) {
			continue;
		}
		const DictRef entry = entry_value.ref;
		const Atom ability_id = gd::string_field(state, entry, key::id, key::empty);
		if (ability_id == key::empty || seen.count(ability_id) != 0) {
			continue;
		}
		const DictRef normalized = state.new_dict();
		if (ability_id == key::reach) {
			put_identity(state, normalized, entry, ability_id, key::Reach);
			put_clamped_float(state, normalized, entry, key::distance_one_multiplier, 1.0, 0.5, 1.5);
			if (state.has(entry, str(key::held_objective_types))) {
				put_strings(state, normalized, entry, key::held_objective_types, {});
			}
		} else if (ability_id == key::hookline) {
			put_identity(state, normalized, entry, ability_id, key::Hookline);
			put_clamped_float(state, normalized, entry, key::distance_one_multiplier, 0.5, 0.0, 1.0);
			put_at_least(state, normalized, entry, key::uses_per_battle, 1, 1);
			put_at_least(state, normalized, entry, key::available_from_round, 1, 1);
			put_text(state, normalized, entry, key::status_id, key::status_rooted);
			put_text(state, normalized, entry, key::status_label, key::pinned_label);
			put_at_least(state, normalized, entry, key::duration_rounds, 1, 1);
			put_modifiers(state, normalized, entry, key::modifiers, {});
		} else if (ability_id == key::rot_cant) {
			put_identity(state, normalized, entry, ability_id, key::rot_cant_2);
			put_text(state, normalized, entry, key::status_id, key::status_harried);
			put_text(state, normalized, entry, key::status_label, key::rot_called_label);
			put_at_least(state, normalized, entry, key::duration_rounds, 1, 1);
			put_at_least(state, normalized, entry, key::uses_per_battle, 1, 1);
			put_at_least(state, normalized, entry, key::available_from_round, 1, 1);
			put_at_least(state, normalized, entry, key::target_min_tier, 2, 2);
			put_clamped_float(state, normalized, entry, key::ai_target_priority_bonus, 0.25, 0.0, 4.0);
			put_modifiers(state, normalized, entry, key::modifiers, { { key::cohesion, -1 }, { key::retaliation, -5 } });
			put_clamped_float(state, normalized, entry, key::wounded_threshold_ratio, 0.5, 0.1, 1.0);
			put_clamped_float(state, normalized, entry, key::wounded_damage_multiplier, 1.02, 1.0, 1.25);
		} else if (ability_id == key::brace) {
			put_identity(state, normalized, entry, ability_id, key::Brace);
			put_clamped_float(state, normalized, entry, key::retaliation_multiplier, 1.0, 1.0, 2.0);
			put_at_least(state, normalized, entry, key::defending_cohesion_bonus, 0, 0);
			put_text(state, normalized, entry, key::status_id, key::status_staggered);
			put_text(state, normalized, entry, key::status_label, key::staggered_label);
			put_at_least(state, normalized, entry, key::duration_rounds, 1, 1);
			put_modifiers(state, normalized, entry, key::modifiers, { { key::initiative, -2 } });
			if (state.has(entry, str(key::grants_base_cohesion))) {
				put_flag(state, normalized, entry, key::grants_base_cohesion, true);
			}
			if (state.has(entry, str(key::held_objective_retaliation_multiplier))) {
				put_clamped_float(state, normalized, entry, key::held_objective_retaliation_multiplier, 1.0, 1.0, 2.0);
				put_strings(state, normalized, entry, key::held_objective_types, {});
			}
			if (state.has(entry, str(key::ally_retaliation_multiplier))) {
				put_clamped_float(state, normalized, entry, key::ally_retaliation_multiplier, 1.0, 1.0, 1.25);
				put_clamped_int(state, normalized, entry, key::ally_retaliation_min_tier, 1, 1, 7);
				put_text(state, normalized, entry, key::ally_retaliation_role, key::melee);
				put_flag(state, normalized, entry, key::ally_retaliation_requires_defending, true);
				put_clamped_float(state, normalized, entry, key::ally_retaliation_ai_defend_bonus, 0.0, 0.0, 4.0);
			}
		} else if (ability_id == key::harry) {
			put_identity(state, normalized, entry, ability_id, key::Harry);
			put_text(state, normalized, entry, key::status_id, key::status_harried);
			put_text(state, normalized, entry, key::status_label, key::harried_label);
			put_at_least(state, normalized, entry, key::duration_rounds, 2, 1);
			put_at_least(state, normalized, entry, key::uses_per_battle, 0, 0);
			put_at_least(state, normalized, entry, key::target_min_tier, 1, 1);
			put_modifiers(state, normalized, entry, key::modifiers, { { key::defense, -1 }, { key::initiative, -1 } });
			put_at_least(state, normalized, entry, key::momentum_gain, 0, 0);
			put_clamped_float(state, normalized, entry, key::wounded_threshold_ratio, 0.0, 0.0, 1.0);
			put_clamped_float(state, normalized, entry, key::wounded_damage_multiplier, 1.0, 1.0, 2.0);
			if (state.has(entry, str(key::target_role))) {
				put_text(state, normalized, entry, key::target_role, key::empty);
			}
			if (state.has(entry, str(key::ai_target_priority_bonus))) {
				put_clamped_float(state, normalized, entry, key::ai_target_priority_bonus, 2.0, 0.0, 4.0);
			}
			if (state.has(entry, str(key::min_adjacent_allies_to_target))) {
				put_clamped_int(state, normalized, entry, key::min_adjacent_allies_to_target, 0, 0, 3);
			}
			if (state.has(entry, str(key::support_ai_target_priority_bonus))) {
				put_clamped_float(state, normalized, entry, key::support_ai_target_priority_bonus, 0.0, 0.0, 4.0);
			}
			if (state.has(entry, str(key::support_blocked_summary))) {
				put_text(state, normalized, entry, key::support_blocked_summary, key::empty);
			}
			if (state.has(entry, str(key::support_ready_summary))) {
				put_text(state, normalized, entry, key::support_ready_summary, key::empty);
			}
		} else if (ability_id == key::obituary) {
			put_identity(state, normalized, entry, ability_id, key::Obituary);
			put_text(state, normalized, entry, key::status_id, key::status_obituary_marked);
			put_text(state, normalized, entry, key::status_label, key::obituary_marked_label);
			put_at_least(state, normalized, entry, key::duration_rounds, 1, 1);
			put_at_least(state, normalized, entry, key::uses_per_battle, 1, 1);
			put_at_least(state, normalized, entry, key::braced_target_min_tier, 2, 2);
			put_clamped_float(state, normalized, entry, key::braced_ai_target_priority_bonus, 0.25, 0.0, 10.0);
			put_modifiers(state, normalized, entry, key::modifiers, { { key::cohesion, -1 }, { key::retaliation, -10 } });
			put_modifiers(state, normalized, entry, key::braced_modifiers, { { key::cohesion, -2 }, { key::retaliation, -20 } });
		} else if (ability_id == key::backstab) {
			put_identity(state, normalized, entry, ability_id, key::backstab_name);
			put_clamped_float(state, normalized, entry, key::damage_multiplier, 1.0, 1.0, 2.0);
			put_at_least(state, normalized, entry, key::momentum_gain, 0, 0);
			put_strings(state, normalized, entry, key::status_ids, { key::status_harried, key::status_staggered });
			put_clamped_float(state, normalized, entry, key::health_threshold_ratio, 0.0, 0.0, 1.0);
			put_clamped_float(state, normalized, entry, key::threshold_damage_multiplier, 1.0, 1.0, 2.0);
			if (state.has(entry, str(key::primary_melee_only))) {
				put_flag(state, normalized, entry, key::primary_melee_only, false);
			}
		} else if (ability_id == key::fogwake) {
			put_identity(state, normalized, entry, ability_id, key::fogwake_name);
			put_clamped_float(state, normalized, entry, key::isolated_damage_multiplier, 1.0, 1.0, 2.0);
			put_text(state, normalized, entry, key::status_id, key::status_fogbound);
			put_text(state, normalized, entry, key::status_label, key::fogbound_label);
			put_at_least(state, normalized, entry, key::duration_rounds, 1, 1);
			put_modifiers(state, normalized, entry, key::modifiers, { { key::defense, -1 }, { key::initiative, -1 }, { key::cohesion, -1 } });
			put_clamped_float(state, normalized, entry, key::ai_target_priority_bonus, 0.0, 0.0, 4.0);
		} else if (ability_id == key::shielding) {
			put_identity(state, normalized, entry, ability_id, key::shielding_label);
			put_at_least(state, normalized, entry, key::cohesion_hold_bonus, 0, 0);
			put_clamped_float(state, normalized, entry, key::ranged_damage_multiplier, 1.0, 0.25, 1.0);
			put_clamped_float(state, normalized, entry, key::engaged_damage_multiplier, 1.0, 1.0, 2.0);
			put_clamped_float(state, normalized, entry, key::harried_damage_multiplier, 1.0, 1.0, 2.0);
			put_clamped_int(state, normalized, entry, key::ally_ranged_melee_damage_reduction_pct, 0, 0, 50);
			put_clamped_int(state, normalized, entry, key::linebreaker_screen_bonus_pct, 0, 0, 50);
			put_clamped_float(state, normalized, entry, key::ranged_damage_return_ratio, 0.0, 0.0, 0.25);
			if (state.has(entry, str(key::payoff_status_ids))) {
				put_strings(state, normalized, entry, key::payoff_status_ids, {});
			}
		} else if (ability_id == key::volley) {
			put_identity(state, normalized, entry, ability_id, key::Volley);
			put_clamped_float(state, normalized, entry, key::damage_multiplier, 1.0, 1.0, 2.0);
			put_at_least(state, normalized, entry, key::min_distance, 1, 1);
			put_strings(state, normalized, entry, key::status_ids, {});
			put_clamped_float(state, normalized, entry, key::status_damage_multiplier, 1.0, 1.0, 2.0);
			put_clamped_float(state, normalized, entry, key::ally_defending_multiplier, 1.0, 1.0, 2.0);
			if (gd::bool_field(state, entry, key::requires_protected_lane, false)) {
				put(state, normalized, key::requires_protected_lane, bool_value(true));
				put_strings(state, normalized, entry, key::protected_lane_objective_types, {});
			}
		} else if (ability_id == key::formation_guard) {
			put_identity(state, normalized, entry, ability_id, key::formation_guard_2);
			put_clamped_float(state, normalized, entry, key::ally_ranged_damage_multiplier, 1.0, 1.0, 2.0);
			put_at_least(state, normalized, entry, key::ally_ranged_initiative_bonus, 0, 0);
			put_at_least(state, normalized, entry, key::ally_cohesion_bonus, 0, 0);
			put_at_least(state, normalized, entry, key::defending_cohesion_bonus, 0, 0);
			put_at_least(state, normalized, entry, key::defending_initiative_bonus, 0, 0);
			put_clamped_float(state, normalized, entry, key::staggered_damage_multiplier, 1.0, 1.0, 2.0);
		} else if (ability_id == key::resonance_relay) {
			put_identity(state, normalized, entry, ability_id, key::resonance_relay_2);
			put_clamped_int(state, normalized, entry, key::minimum_calibrated_stacks, 2, 2, 6);
			put_clamped_int(state, normalized, entry, key::maximum_calibrated_stacks, 3, 2, 6);
			put_clamped_float(state, normalized, entry, key::line_damage_per_calibrated_stack, 0.0, 0.0, 0.1);
			put_clamped_int(state, normalized, entry, key::line_initiative_bonus, 0, 0, 3);
			put_clamped_int(state, normalized, entry, key::late_round_initiative_bonus, 0, 0, 3);
			put_clamped_int(state, normalized, entry, key::terrain_momentum_bonus, 0, 0, 3);
			put_strings(state, normalized, entry, key::linked_unit_ids, {});
			put_clamped_int(state, normalized, entry, key::linked_initiative_bonus, 0, 0, 3);
		} else if (ability_id == key::solar_array_lane) {
			put_identity(state, normalized, entry, ability_id, key::solar_array_lanes);
			put_clamped_float(state, normalized, entry, key::incoming_melee_damage_multiplier, 1.0, 0.75, 1.0);
			put_strings(state, normalized, entry, key::linked_unit_ids, {});
		} else if (ability_id == key::bloodrush) {
			put_identity(state, normalized, entry, ability_id, key::Bloodrush);
			put_clamped_float(state, normalized, entry, key::clean_target_damage_multiplier, 1.0, 0.25, 1.0);
			put_clamped_float(state, normalized, entry, key::wounded_threshold_ratio, 0.0, 0.0, 1.0);
			put_clamped_float(state, normalized, entry, key::wounded_damage_multiplier, 1.0, 1.0, 2.0);
			put_strings(state, normalized, entry, key::status_ids, { key::status_harried, key::status_staggered });
			put_clamped_float(state, normalized, entry, key::status_damage_multiplier, 1.0, 1.0, 2.0);
			put_at_least(state, normalized, entry, key::wounded_initiative_bonus, 0, 0);
			put_at_least(state, normalized, entry, key::max_initiative_bonus, 0, 0);
			put_at_least(state, normalized, entry, key::momentum_gain, 0, 0);
			put_at_least(state, normalized, entry, key::kill_momentum_gain, 0, 0);
			put_at_least(state, normalized, entry, key::late_round_initiative_bonus, 0, 0);
			if (state.has(entry, str(key::primary_melee_only))) {
				put_flag(state, normalized, entry, key::primary_melee_only, false);
			}
			if (state.has(entry, str(key::isolated_damage_multiplier))) {
				put_clamped_float(state, normalized, entry, key::isolated_damage_multiplier, 1.0, 1.0, 1.25);
			}
			if (state.has(entry, str(key::isolated_ai_target_priority_bonus))) {
				put_clamped_float(state, normalized, entry, key::isolated_ai_target_priority_bonus, 0.0, 0.0, 5.0);
			}
		} else if (ability_id == key::overheat) {
			put_identity(state, normalized, entry, ability_id, key::Overheat);
			put_clamped_float(state, normalized, entry, key::burst_damage_multiplier, 1.0, 1.0, 2.0);
			put_clamped_float(state, normalized, entry, key::overheated_damage_multiplier, 1.0, 0.25, 1.0);
			put_text(state, normalized, entry, key::status_id, key::status_overheated);
			put_text(state, normalized, entry, key::status_label, key::Overheated);
			put_at_least(state, normalized, entry, key::duration_rounds, 2, 1);
			put_modifiers(state, normalized, entry, key::modifiers, { { key::defense, -2 }, { key::initiative, -2 } });
		} else if (ability_id == key::pressure_artillery) {
			put_identity(state, normalized, entry, ability_id, key::pressure_artillery_name);
			put_clamped_int(state, normalized, entry, key::cluster_range, 1, 1, 2);
			put_clamped_int(state, normalized, entry, key::secondary_damage_per_unit, 1, 1, 4);
			put_clamped_int(state, normalized, entry, key::max_secondary_damage, 1, 1, 30);
			put(state, normalized, key::max_secondary_targets, int_value(1));
			put_text(state, normalized, entry, key::status_id, key::status_overheated);
			put_text(state, normalized, entry, key::status_label, key::Overheated);
			put_clamped_int(state, normalized, entry, key::duration_rounds, 2, 1, 3);
			put_modifiers(state, normalized, entry, key::modifiers, { { key::initiative, -1 } });
			put_clamped_float(state, normalized, entry, key::ai_heat_score_penalty, 0.5, 0.0, 4.0);
		} else if (ability_id == key::counter_ambush_flare) {
			put_identity(state, normalized, entry, ability_id, key::counter_ambush_flare_name);
			put_strings(state, normalized, entry, key::countered_ability_ids, { key::backstab, key::fogwake });
			put_clamped_float(state, normalized, entry, key::ambush_bonus_retention, 0.0, 0.0, 1.0);
			put_flag(state, normalized, entry, key::blocks_ambush_status, true);
			put_text(state, normalized, entry, key::revealed_status_id, key::status_flare_revealed);
			put_text(state, normalized, entry, key::revealed_status_label, key::flare_revealed_label);
			put_clamped_int(state, normalized, entry, key::revealed_duration_rounds, 1, 1, 2);
			put_strings(state, normalized, entry, key::revealed_ability_ids, { key::fogwake });
			put_modifiers(state, normalized, entry, key::revealed_modifiers, { { key::defense, -1 }, { key::initiative, -1 } });
		} else if (ability_id == key::sporeglass_mend) {
			put_identity(state, normalized, entry, ability_id, key::mending_fire);
			put_clamped_int(state, normalized, entry, key::health_per_mender, 1, 1, 6);
			put_clamped_int(state, normalized, entry, key::max_health_per_attack, 1, 1, 20);
		} else if (ability_id == key::foundry_aura) {
			put_identity(state, normalized, entry, ability_id, key::foundry_aura_2);
			put_clamped_int(state, normalized, entry, key::ally_defense_bonus, 0, 0, 3);
			put_flag(state, normalized, entry, key::hardening_requires_overheated, true);
			put_clamped_float(state, normalized, entry, key::round_repair_pct, 0.0, 0.0, 0.1);
			put_clamped_float(state, normalized, entry, key::overheated_repair_bonus_pct, 0.0, 0.0, 0.1);
			put_clamped_float(state, normalized, entry, key::ai_target_priority_bonus, 0.0, 0.0, 5.0);
		} else {
			// bramble_ground, fog_screen and readiness_writ are read from the authored
			// content, and any other id is dropped.
			continue;
		}
		state.append(abilities, dict_value(normalized));
		seen.insert(ability_id);
	}
	return abilities;
}

int64_t _cohesion_base_for_unit(State &state, DictRef unit) {
	int64_t base = gd::add(5, engine_max<int64_t>(0, gd::sub(gd::int_field(state, unit, key::tier, 1), 1)));
	if (!gd::bool_field(state, unit, key::ranged, false)) {
		base = gd::add(base, 1);
	}
	for (const Value &ability : gd::field_items(state, unit, str(key::abilities))) {
		if (!gd::is_dict(ability)) {
			continue;
		}
		const Atom ability_id = gd::string_field(state, ability.ref, key::id, key::empty);
		if ((ability_id == key::brace && gd::bool_field(state, ability.ref, key::grants_base_cohesion, true)) || ability_id == key::formation_guard || (ability_id == key::shielding && gd::int_field(state, ability.ref, key::cohesion_hold_bonus, 0) > 0)) {
			base = gd::add(base, 1);
			break;
		}
	}
	if (gd::bool_field(state, unit, key::ranged, false) && gd::int_field(state, unit, key::hp, 1) <= 6) {
		base = gd::sub(base, 1);
	}
	return engine_clamp<int64_t>(base, 4, 8);
}

Atom _normalize_side_token(Atom side, bool allow_neutral) {
	if (side == key::player || side == key::enemy) {
		return side;
	}
	// "neutral" and any other token.
	return allow_neutral ? key::neutral : key::empty;
}

ArrayRef _normalize_field_objectives(State &state, const Value &existing_value, DictRef encounter, DictRef encounter_placement, DictRef scenario, const Value &context) {
	const DictRef existing_by_id = state.new_dict();
	if (gd::is_array(existing_value)) {
		for (const Value &entry : gd::items(state, existing_value)) {
			if (gd::is_dict(entry)) {
				const Atom existing_id = gd::string_field(state, entry.ref, key::id, key::empty);
				if (existing_id != key::empty) {
					state.set(existing_by_id, str(existing_id), entry);
				}
			}
		}
	}
	const ArrayRef normalized = state.new_array();
	const ArrayRef authored = _authored_field_objectives(state, encounter, encounter_placement, scenario, context);
	for (const Value &entry : gd::items(state, array_value(authored))) {
		if (!gd::is_dict(entry)) {
			continue;
		}
		const Atom objective_id = gd::string_field(state, entry.ref, key::id, key::empty);
		if (objective_id == key::empty) {
			continue;
		}
		// existing_by_id.get(objective_id, {}): the objective only reads it, and
		// reads anything but a Dictionary as {}.
		const Value existing_state = state.get(existing_by_id, str(objective_id), Value());
		state.append(normalized, dict_value(_normalize_field_objective(state, entry.ref, existing_state, context)));
	}
	return normalized;
}

ArrayRef _authored_field_objectives(State &state, DictRef encounter, DictRef encounter_placement, DictRef scenario, const Value &context) {
	(void)scenario;
	(void)context;
	// ordered_ids stays local: the objective ids in their first order.
	std::vector<Atom> ordered_ids;
	const DictRef merged = state.new_dict();
	// for source in [encounter.get(FIELD_OBJECTIVES_KEY, []), encounter_placement.get(...)]:
	// a missing key is an empty Array, which visits nothing.
	for (const DictRef holder : { encounter, encounter_placement }) {
		Value source;
		if (!state.lookup(holder, str(key::field_objectives), source) || !gd::is_array(source)) {
			continue;
		}
		for (const Value &entry : gd::items(state, source)) {
			if (!gd::is_dict(entry)) {
				continue;
			}
			const Atom objective_id = gd::string_field(state, entry.ref, key::id, key::empty);
			if (objective_id == key::empty) {
				continue;
			}
			if (!state.has(merged, str(objective_id))) {
				ordered_ids.push_back(objective_id);
				state.set(merged, str(objective_id), dict_value(gd::deep_duplicate_dict(state, entry.ref)));
			} else {
				const Value current = gd::index(state, merged, str(objective_id));
				if (gd::is_dict(current)) {
					// entry.keys(): a copy.
					const state::ValueList entry_keys = state.dict(entry.ref).keys.list();
					for (const Value &entry_key : entry_keys) {
						state.set(current.ref, str(gd::to_string(entry_key)), gd::index(state, entry.ref, entry_key));
					}
					state.set(merged, str(objective_id), current);
				}
			}
		}
	}
	const ArrayRef authored = state.new_array();
	for (const Atom objective_id : ordered_ids) {
		Value found;
		if (!state.lookup(merged, str(objective_id), found)) {
			found = dict_value(state.new_dict());
		}
		state.append(authored, found);
	}
	return authored;
}

DictRef _normalize_field_objective(State &state, DictRef entry, const Value &existing_state, const Value &context) {
	(void)context;
	const Atom objective_type = gd::string_field(state, entry, key::type, key::empty);
	const Atom starting_side = _normalize_side_token(gd::string_field(state, entry, key::starting_side, key::neutral), true);
	const int64_t capture_threshold = engine_max<int64_t>(1, gd::int_field(state, entry, key::capture_threshold, 2));
	const int64_t urgency_round = engine_max<int64_t>(1, gd::int_field(state, entry, key::urgency_round, 2));
	// var state = existing_state if existing_state is Dictionary else {}: only read.
	const bool has_saved = gd::is_dict(existing_state);
	const auto saved_get = [&](Atom field, const Value &fallback) {
		return has_saved ? state.get(existing_state.ref, str(field), fallback) : fallback;
	};
	Atom control_side = _normalize_side_token(gd::to_string(saved_get(key::control_side, str(starting_side))), true);
	if (control_side == key::empty) {
		control_side = starting_side;
	}
	Atom progress_side = _normalize_side_token(gd::to_string(saved_get(key::progress_side, str(key::empty))), false);
	if (progress_side == control_side) {
		progress_side = key::empty;
	}
	// clamp() of ints: an int (capture_threshold is at least 1).
	const int64_t progress_value = engine_clamp<int64_t>(gd::to_int(state, saved_get(key::progress_value, int_value(0))), 0, capture_threshold);
	const DictRef objective = state.new_dict();
	put(state, objective, key::id, str(gd::string_field(state, entry, key::id, key::empty)));
	put(state, objective, key::type, str(objective_type));
	// The label, summary and pressure tag fallbacks have no effects: they are
	// worked out only when the entry has no value of its own.
	const Atom label_token = gd::string_field(state, entry, key::id, objective_type);
	Value label;
	put(state, objective, key::label, str(state.lookup(entry, str(key::label), label) ? gd::to_string(label) : _titleize_token(state, label_token)));
	Value summary;
	put(state, objective, key::summary, str(state.lookup(entry, str(key::summary), summary) ? gd::to_string(summary) : _default_field_objective_summary(state, objective_type)));
	put(state, objective, key::starting_side, str(starting_side));
	put(state, objective, key::control_side, str(control_side));
	put(state, objective, key::progress_side, str(progress_side));
	put(state, objective, key::progress_value, int_value(progress_side != key::empty ? progress_value : 0));
	put(state, objective, key::capture_threshold, int_value(capture_threshold));
	put(state, objective, key::urgency_round, int_value(urgency_round));
	Value tags;
	if (!state.lookup(entry, str(key::pressure_tags), tags)) {
		tags = array_value(_default_field_objective_pressure_tags(state, objective_type));
	}
	put(state, objective, key::pressure_tags, array_value(_normalize_string_array(state, tags)));
	put(state, objective, key::last_flip_round, int_value(engine_max<int64_t>(0, gd::to_int(state, saved_get(key::last_flip_round, int_value(0))))));
	return objective;
}

Atom _default_field_objective_summary(State &state, Atom objective_type) {
	(void)state;
	if (objective_type == key::lane_battery) {
		return key::lane_batteries_sharpen_ranged_pressure_until;
	}
	if (objective_type == key::cover_line) {
		return key::a_cover_line_screens_the_firing;
	}
	if (objective_type == key::obstruction_line) {
		return key::an_obstruction_line_clogs_the_approach;
	}
	if (objective_type == key::ritual_pylon) {
		return key::a_ritual_pylon_steals_tempo_and;
	}
	if (objective_type == key::supply_post) {
		return key::a_supply_post_stabilizes_the_line;
	}
	if (objective_type == key::signal_beacon) {
		return key::a_signal_beacon_guides_the_line;
	}
	if (objective_type == key::breach_point) {
		return key::a_breach_point_decides_whether_the;
	}
	if (objective_type == key::hazard_zone) {
		return key::a_hazard_zone_punishes_the_side;
	}
	return key::battlefield_pressure_still_hangs_on_this;
}

ArrayRef _default_field_objective_pressure_tags(State &state, Atom objective_type) {
	// The match arms return Array literals: a new Array on every call.
	if (objective_type == key::lane_battery) {
		return string_array(state, { key::ranged, key::initiative });
	}
	if (objective_type == key::cover_line) {
		return string_array(state, { key::ranged, key::commander, key::cohesion });
	}
	if (objective_type == key::obstruction_line) {
		return string_array(state, { key::cohesion, key::momentum, key::urgency });
	}
	if (objective_type == key::ritual_pylon) {
		return string_array(state, { key::initiative, key::cohesion });
	}
	if (objective_type == key::supply_post) {
		return string_array(state, { key::cohesion, key::reinforcement });
	}
	if (objective_type == key::signal_beacon) {
		return string_array(state, { key::initiative, key::commander });
	}
	if (objective_type == key::breach_point) {
		return string_array(state, { key::momentum, key::cohesion });
	}
	if (objective_type == key::hazard_zone) {
		return string_array(state, { key::cohesion, key::urgency });
	}
	return state.new_array();
}

} // namespace battle_rules

namespace town_battle_rules {

void prepare(State &state, DictRef battle, ArrayRef building_ids, Atom side) {
	const DictRef defenses = state.new_dict();
	for (const Value &id : gd::items(state, array_value(building_ids))) {
		const DictRef building = gd::content_row(state, state::ContentTable::Building, gd::to_string(id));
		// .get("town_defense_effect", {}): a missing key is the empty effect, skipped.
		Value found;
		if (!state.lookup(building, str(key::town_defense_effect), found)) {
			continue;
		}
		const DictRef effect = gd::as_dict(found);
		if (!gd::is_empty(state, effect)) {
			const Atom effect_id = gd::to_string(gd::index(state, effect, str(key::id)));
			state.set(defenses, str(effect_id), dict_value(gd::deep_duplicate_dict(state, effect)));
		}
	}
	if (gd::is_empty(state, defenses)) {
		return;
	}
	const DictRef town_defenses = state.new_dict();
	put(state, town_defenses, key::side, str(side));
	put(state, town_defenses, key::effects, dict_value(defenses));
	put(state, town_defenses, key::last_healing_round, int_value(0));
	state.set(battle, str(key::town_defenses), dict_value(town_defenses));
	// defenses.get("pressure_shield", {}): a missing key is the empty shield.
	Value shield_value;
	if (!state.lookup(defenses, str(key::pressure_shield), shield_value)) {
		return;
	}
	const DictRef shield = gd::as_dict(shield_value);
	if (gd::is_empty(state, shield)) {
		return;
	}
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (gd::equal(state, variant_get(state, stack, key::side, str(key::empty)), str(side))) {
			const double total_health = gd::to_float(state.get(stack.ref, str(key::total_health), int_value(0)));
			const double health_pct = gd::to_float(state.get(shield, str(key::health_pct), int_value(15)));
			const double product = total_health * health_pct;
			const double shield_hp = product / 100.0;
			put(state, stack.ref, key::town_shield_hp, int_value(engine_max<int64_t>(0, compat::float_to_int(compat::godot_ceil(shield_hp)))));
		}
	}
}

} // namespace town_battle_rules

} // namespace aurelion::rules::port
