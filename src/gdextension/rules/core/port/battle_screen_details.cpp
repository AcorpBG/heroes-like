// BattleRules, SpellRules, TownBattleRules and BattleActionPlayback for the
// battle screen (Phase 7, slice 7.9): stack and hero details, the battle
// report, the spell actions and the action playback's capture.

#include "aurelion_rules/port/battle_screen.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_footprint.hpp"
#include "aurelion_rules/port/hero_progression_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include <set>
#include <string>
#include <vector>

namespace aurelion::rules::port {

// Defined in enemy_states.cpp, declared only there.
namespace hero_progression_rules {
int64_t specialty_rank(State &state, DictRef hero_state, Atom specialty_id);
DictRef specialty_definition(State &state, Atom specialty_id);
} // namespace hero_progression_rules

namespace {

using compat::engine_clamp;
using compat::engine_max;
using compat::engine_min;
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

// BattleRules.COHESION_MAX and MOMENTUM_MAX.
constexpr int64_t kCohesionMax = 10;
constexpr int64_t kMomentumMax = 4;

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

// a + b of Strings.
Atom concat(State &state, Atom a, Atom b) {
	return state.intern(state.text(a) + state.text(b));
}

// sep.join(parts) of Strings.
Atom join_texts(State &state, Atom separator, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// sep.join(array) of an Array, which converts to a PackedStringArray.
Atom join_array(State &state, Atom separator, ArrayRef parts) {
	std::vector<Atom> texts;
	const int64_t size = state.array_size(parts);
	for (int64_t index = 0; index < size; ++index) {
		texts.push_back(string_of(state, state.at(parts, index)));
	}
	return join_texts(state, separator, texts);
}

// {"a": x, "b": y}.
DictRef pair_dict(State &state, Atom a, const Value &x, Atom b, const Value &y) {
	const DictRef dict = state.new_dict();
	state.set(dict, str(a), x);
	state.set(dict, str(b), y);
	return dict;
}

// var x: Dictionary = d.get(field, {}) if d.get(field, {}) is Dictionary else {},
// read only: the Dictionary, or false when it is missing or no Dictionary.
bool dict_field(const State &state, DictRef dict, Atom field, DictRef &out) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		out = found.ref;
		return true;
	}
	return false;
}

// var x: Dictionary = d.get(field, {}): a new Dictionary when it is missing,
// a ScriptError when it is no Dictionary.
DictRef typed_dict_field(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return gd::as_dict(found);
	}
	return state.new_dict();
}

} // namespace

namespace battle_rules {

DictRef stack_details(State &state, DictRef battle, Atom battle_id) {
	const DictRef stack = _get_stack_by_id(state, battle, battle_id);
	if (gd::is_empty(state, stack)) {
		return state.new_dict();
	}
	const DictRef unit = gd::content_row(state, ContentTable::Unit, text_or(state, stack, key::unit_id, key::empty));
	const Atom side = text_or(state, stack, key::side, key::empty);
	const DictRef hero = _hero_payload_for_side(state, battle, side);
	const int64_t count = _alive_count(state, stack);
	const int64_t unit_hp = engine_max<int64_t>(1, gd::int_field(state, stack, key::unit_hp, 1));
	const int64_t stack_health = engine_max<int64_t>(0, gd::int_field(state, stack, key::total_health, 0));
	const bool defending = gd::bool_field(state, stack, key::defending, false);
	const int64_t defend_bonus = defending ? gd::add(2, gd::int_field(state, hero, key::defend_defense_bonus, 0)) : 0;
	const int64_t hero_attack = gd::int_field(state, hero, key::attack, 0);
	const int64_t hero_defense = gd::int_field(state, hero, key::defense, 0);
	const bool ranged = gd::bool_field(state, stack, key::ranged, false);
	const Atom faction_id = text_or(state, stack, key::faction_id, key::empty);
	const Atom faction_name = faction_id != key::empty ? text_or(state, gd::content_row(state, ContentTable::Faction, faction_id), key::name, key::empty) : static_cast<Atom>(key::empty);
	const int64_t min_damage = gd::int_field(state, stack, key::min_damage, 1);
	const int64_t shots_left = engine_max<int64_t>(0, gd::int_field(state, stack, key::shots_remaining, 0));
	const ArrayRef abilities = state.new_array();
	for (const Value &ability : gd::field_items(state, stack, str(key::abilities))) {
		if (gd::is_dict(ability) && gd::strip_edges(state, text_or(state, ability.ref, key::name, key::empty)) != key::empty) {
			const Atom name = gd::strip_edges(state, text_or(state, ability.ref, key::name, key::empty));
			const Atom description = gd::strip_edges(state, text_or(state, ability.ref, key::description, key::empty));
			state.append(abilities, dict_value(pair_dict(state, key::name, str(name), key::description, str(description))));
		}
	}

	const DictRef details = state.new_dict();
	state.set(details, str(key::battle_id), str(battle_id));
	state.set(details, str(key::unit_id), str(text_or(state, stack, key::unit_id, key::empty)));
	const Value name_fallback = state.get(unit, str(key::name), str(key::empty));
	state.set(details, str(key::name), str(string_of(state, state.get(stack, str(key::name), name_fallback))));
	state.set(details, str(key::side), str(side));
	state.set(details, str(key::faction), str(faction_name != key::empty ? faction_name : static_cast<Atom>(key::Neutral)));
	state.set(details, str(key::tier), int_value(gd::int_field(state, stack, key::tier, 1)));
	state.set(details, str(key::ranged), bool_value(ranged));
	state.set(details, str(key::large), bool_value(battle_footprint::width(state, stack) == 2));
	state.set(details, str(key::count), int_value(count));
	state.set(details, str(key::unit_health), int_value(unit_hp));
	state.set(details, str(key::top_health), int_value(count > 0 ? gd::sub(stack_health, gd::mul(count - 1, unit_hp)) : 0));
	state.set(details, str(key::stack_health), int_value(stack_health));

	const int64_t attack_base = gd::to_int(state, state.get(unit, str(key::attack), state.get(stack, str(key::attack), int_value(0))));
	const int64_t attack_value = gd::add(_stack_attack_total(state, stack, battle), hero_attack);
	state.set(details, str(key::attack), dict_value(pair_dict(state, key::base, int_value(attack_base), key::value, int_value(attack_value))));
	const int64_t defense_base = gd::to_int(state, state.get(unit, str(key::defense), state.get(stack, str(key::defense), int_value(0))));
	const int64_t defense_value = gd::add(gd::add(_stack_defense_total(state, stack, battle), hero_defense), defend_bonus);
	state.set(details, str(key::defense), dict_value(pair_dict(state, key::base, int_value(defense_base), key::value, int_value(defense_value))));
	const int64_t max_damage = engine_max<int64_t>(min_damage, gd::int_field(state, stack, key::max_damage, 1));
	state.set(details, str(key::damage), dict_value(pair_dict(state, key::min_, int_value(min_damage), key::max, int_value(max_damage))));
	const int64_t health_base = gd::int_field(state, unit, key::hp, unit_hp);
	state.set(details, str(key::health), dict_value(pair_dict(state, key::base, int_value(health_base), key::value, int_value(unit_hp))));
	const int64_t speed_base = engine_clamp<int64_t>(gd::to_int(state, state.get(unit, str(key::speed), state.get(stack, str(key::speed), int_value(1)))), 1, 6);
	const int64_t speed_value = _stack_movement_points(state, stack, battle);
	state.set(details, str(key::speed), dict_value(pair_dict(state, key::base, int_value(speed_base), key::value, int_value(speed_value))));
	const int64_t initiative_base = gd::to_int(state, state.get(unit, str(key::initiative), state.get(stack, str(key::initiative), int_value(1))));
	const int64_t initiative_value = _stack_initiative_total(state, stack, battle);
	state.set(details, str(key::initiative), dict_value(pair_dict(state, key::base, int_value(initiative_base), key::value, int_value(initiative_value))));
	if (ranged) {
		const int64_t shots_max = engine_max<int64_t>(shots_left, gd::int_field(state, unit, key::shots, shots_left));
		state.set(details, str(key::shots), dict_value(pair_dict(state, key::left, int_value(shots_left), key::max, int_value(shots_max))));
	} else {
		state.set(details, str(key::shots), dict_value(state.new_dict()));
	}
	state.set(details, str(key::strike_backs), dict_value(stack_strike_backs(state, battle, stack)));
	const int64_t cohesion = _stack_cohesion_total(state, stack, battle);
	state.set(details, str(key::cohesion), dict_value(pair_dict(state, key::value, int_value(cohesion), key::max, int_value(kCohesionMax))));
	const int64_t momentum = _stack_momentum_total(state, stack, battle);
	state.set(details, str(key::momentum), dict_value(pair_dict(state, key::value, int_value(momentum), key::max, int_value(kMomentumMax))));
	state.set(details, str(key::abilities), array_value(abilities));
	state.set(details, str(key::effects), array_value(stack_effect_rows(state, stack, battle)));
	state.set(details, str(key::defending), bool_value(defending));
	state.set(details, str(key::defend_bonus), int_value(defend_bonus));
	state.set(details, str(key::waiting), bool_value(stack_is_waiting(state, battle, battle_id)));
	state.set(details, str(key::active), bool_value(battle_id == text_or(state, battle, key::active_stack_id, key::empty)));
	state.set(details, str(key::hero_name), str(commander_name(state, battle, side)));
	state.set(details, str(key::hero_attack), int_value(hero_attack));
	state.set(details, str(key::hero_defense), int_value(hero_defense));
	return details;
}

bool stack_is_waiting(State &state, DictRef battle, Atom battle_id) {
	const Atom active_id = text_or(state, battle, key::active_stack_id, key::empty);
	if (battle_id == key::empty || battle_id == active_id || !stack_has_waited(state, battle, battle_id)) {
		return false;
	}
	if (_alive_count(state, _get_stack_by_id(state, battle, battle_id)) <= 0) {
		return false;
	}
	Value found;
	const ArrayRef turn_order = state.lookup(battle, str(key::turn_order), found) && gd::is_array(found) ? found.ref : state.new_array();
	int64_t start = gd::array_find(state, turn_order, str(active_id));
	if (start < 0) {
		start = engine_clamp<int64_t>(gd::int_field(state, battle, key::turn_index, 0), 0, state.array_size(turn_order));
	}
	return gd::array_find(state, turn_order, str(battle_id)) >= start;
}

ArrayRef stack_effect_rows(State &state, DictRef stack, DictRef battle) {
	const ArrayRef rows = state.new_array();
	const int64_t current_round = gd::int_field(state, battle, key::round, 1);
	const ArrayRef effects = spell_rules::active_effects_for_round(state, stack, current_round);
	for (const Value &effect_value : gd::items(state, array_value(effects))) {
		const DictRef effect = gd::as_dict(effect_value);
		const Atom effect_id = text_or(state, effect, key::effect_id, key::empty);
		const bool counted = state.has(effect, str(key::turns_left));
		const int64_t left = counted
				? engine_max<int64_t>(1, gd::int_field(state, effect, key::turns_left, 1))
				: engine_max<int64_t>(1, gd::add(gd::sub(gd::int_field(state, effect, key::expires_after_round, current_round), current_round), 1));
		Atom unit = counted ? static_cast<Atom>(key::turn) : static_cast<Atom>(key::round);
		// A preparation held until it is used outlasts any battle.
		if (!counted && left > gd::int_field(state, battle, key::max_rounds, 12)) {
			unit = key::battle;
		}
		std::vector<Atom> parts;
		const Atom rules = spell_rules::status_rules_text(state, effect_id);
		if (rules != key::empty) {
			parts.push_back(rules);
		}
		const Atom modifiers = _effect_modifier_phrase(state, effect);
		if (modifiers != key::empty) {
			parts.push_back(modifiers);
		}
		const DictRef row = state.new_dict();
		state.set(row, str(key::effect_id), str(effect_id));
		state.set(row, str(key::spell_id), str(text_or(state, effect, key::spell_id, key::empty)));
		state.set(row, str(key::name), str(text_or(state, effect, key::label, key::Effect)));
		state.set(row, str(key::text), str(join_texts(state, key::semicolon_space, parts)));
		state.set(row, str(key::turns), int_value(left));
		state.set(row, str(key::unit), str(unit));
		state.set(row, str(key::after_this), bool_value(counted && gd::bool_field(state, effect, key::skip_current_turn, false)));
		state.set(row, str(key::polarity), str(effect_polarity(state, effect)));
		state.append(rows, dict_value(row));
	}
	return rows;
}

Atom _effect_modifier_phrase(State &state, DictRef effect) {
	DictRef modifiers = 0;
	if (!dict_field(state, effect, key::modifiers, modifiers)) {
		return key::empty;
	}
	std::vector<Atom> parts;
	for (const Atom field : {key::attack, key::defense, key::speed, key::initiative, key::cohesion, key::momentum}) {
		const int64_t amount = gd::int_field(state, modifiers, field, 0);
		if (amount != 0) {
			const Atom sign = amount > 0 ? static_cast<Atom>(key::plus) : static_cast<Atom>(key::empty);
			parts.push_back(gd::format(state, key::s_d_s_5, {str(sign), int_value(amount), str(field)}));
		}
	}
	const int64_t retaliation = gd::int_field(state, modifiers, key::retaliation, 0);
	if (retaliation < 0) {
		parts.push_back(gd::format(state, key::strikes_back_d_weaker, {int_value(engine_min<int64_t>(75, gd::neg(retaliation)))}));
	}
	return join_texts(state, key::comma_space, parts);
}

Atom effect_polarity(State &state, DictRef effect) {
	if (spell_rules::status_rules_text(state, text_or(state, effect, key::effect_id, key::empty)) != key::empty) {
		return key::harmful;
	}
	bool raised = false;
	DictRef modifiers = 0;
	if (dict_field(state, effect, key::modifiers, modifiers)) {
		const ArrayRef modifier_keys = gd::keys(state, modifiers);
		const int64_t size = state.array_size(modifier_keys);
		for (int64_t index = 0; index < size; ++index) {
			const int64_t amount = gd::to_int(state, gd::index(state, modifiers, state.at(modifier_keys, index)));
			if (amount < 0) {
				return key::harmful;
			}
			raised = raised || amount > 0;
		}
	}
	if (raised) {
		return key::beneficial;
	}
	Value wards;
	return state.lookup(effect, str(key::blocked_status_ids), wards) && gd::is_array(wards) && state.array_size(wards.ref) > 0
			? static_cast<Atom>(key::beneficial)
			: static_cast<Atom>(key::harmful);
}

DictRef hero_details(State &state, DictRef battle, Atom side) {
	const DictRef details = hero_presentation(state, battle, side);
	if (gd::is_empty(state, details)) {
		return state.new_dict();
	}
	const DictRef commander = _commander_state_for_side(state, battle, side);
	const DictRef payload = _hero_payload_for_side(state, battle, side);
	DictRef command = 0;
	const bool has_command = dict_field(state, commander, key::command, command);
	const Atom hero_id = text_or(state, details, key::hero_id, key::empty);
	DictRef template_payload = commander;
	if (hero_id != key::empty) {
		template_payload = state.new_dict();
		state.set(template_payload, str(key::id), str(hero_id));
	}
	state.set(details, str(key::attack), int_value(gd::int_field(state, payload, key::attack, 0)));
	state.set(details, str(key::defense), int_value(gd::int_field(state, payload, key::defense, 0)));
	state.set(details, str(key::power), int_value(spell_rules::spell_power(state, commander)));
	state.set(details, str(key::knowledge), int_value(engine_max<int64_t>(0, has_command ? gd::int_field(state, command, key::knowledge, 0) : 0)));
	const Atom faction = hero_command_rules::hero_faction_label(state, template_payload, text_or(state, details, key::faction_id, key::empty));
	state.set(details, str(key::faction), str(faction));
	const Atom role = hero_id != key::empty ? hero_command_rules::hero_role_label(state, template_payload) : text_or(state, details, key::role, key::empty);
	state.set(details, str(key::class_), str(role));

	const ArrayRef specialties = state.new_array();
	std::set<Atom> seen;
	Value specialty_ids;
	if (state.lookup(commander, str(key::specialties), specialty_ids) && gd::is_array(specialty_ids)) {
		for (const Value &specialty_value : gd::items(state, specialty_ids)) {
			const Atom specialty_id = string_of(state, specialty_value);
			if (seen.count(specialty_id) != 0) {
				continue;
			}
			seen.insert(specialty_id);
			const DictRef definition = hero_progression_rules::specialty_definition(state, specialty_id);
			if (gd::is_empty(state, definition)) {
				continue;
			}
			const int64_t rank = hero_progression_rules::specialty_rank(state, commander, specialty_id);
			const DictRef entry = state.new_dict();
			state.set(entry, str(key::id), str(specialty_id));
			state.set(entry, str(key::name), str(text_or(state, definition, key::name, specialty_id)));
			state.set(entry, str(key::rank), int_value(rank));
			state.set(entry, str(key::rank_label), str(hero_progression_rules::rank_label(state, rank)));
			state.set(entry, str(key::text), str(hero_progression_rules::rank_text(state, specialty_id, rank)));
			state.append(specialties, dict_value(entry));
		}
	}
	state.set(details, str(key::specialties), array_value(specialties));

	const ArrayRef spells = state.new_array();
	const ArrayRef known = spell_rules::known_spells(state, commander, key::battle);
	for (const Value &spell_value : gd::items(state, array_value(known))) {
		if (!gd::is_dict(spell_value)) {
			continue;
		}
		const DictRef spell = spell_value.ref;
		const Atom spell_id = text_or(state, spell, key::id, key::empty);
		const DictRef entry = state.new_dict();
		state.set(entry, str(key::id), str(spell_id));
		state.set(entry, str(key::name), str(text_or(state, spell, key::name, spell_id)));
		state.set(entry, str(key::cost), int_value(spell_rules::adjusted_spell_mana_cost(state, commander, dict_value(spell))));
		state.set(entry, str(key::icon), str(spell_rules::spell_icon_path(state, spell_id)));
		state.append(spells, dict_value(entry));
	}
	state.set(details, str(key::spells), array_value(spells));
	return details;
}

ArrayRef roster_lines(State &state, DictRef battle, Atom side) {
	const ArrayRef lines = state.new_array();
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (!gd::is_dict(stack) || text_or(state, stack.ref, key::side, key::empty) != side) {
			continue;
		}
		const Atom active_id = text_or(state, battle, key::active_stack_id, key::empty);
		const Atom selected_id = text_or(state, battle, key::selected_target_id, key::empty);
		state.append(lines, str(_stack_summary_line(state, stack.ref, battle, active_id, selected_id)));
	}
	return lines;
}

ArrayRef _starting_enemy_stacks(State &state, DictRef battle) {
	const ArrayRef stacks = state.new_array();
	for (const Value &stack_value : gd::field_items(state, battle, str(key::stacks))) {
		if (gd::is_dict(stack_value) && text_or(state, stack_value.ref, key::side, key::empty) == key::enemy && gd::int_field(state, stack_value.ref, key::base_count, 0) > 0) {
			const Atom unit_id = text_or(state, stack_value.ref, key::unit_id, key::empty);
			const int64_t count = gd::int_field(state, stack_value.ref, key::base_count, 0);
			state.append(stacks, dict_value(pair_dict(state, key::unit_id, str(unit_id), key::count, int_value(count))));
		}
	}
	return stacks;
}

DictRef pending_battle_report(State &state, DictRef session) {
	if (!gd::is_empty(state, gd::as_dict(gd::index(state, session, str(key::battle))))) {
		return state.new_dict();
	}
	const DictRef flags = gd::as_dict(gd::index(state, session, str(key::flags)));
	Value value;
	if (!state.lookup(flags, str(key::last_battle_aftermath), value)) {
		return state.new_dict();
	}
	if (!gd::is_dict(value)) {
		return state.new_dict();
	}
	const DictRef report = value.ref;
	Value casualties;
	if (
			!gd::bool_field(state, report, key::pending, false) ||
			gd::int_field(state, report, key::report_version, 0) != 1 ||
			text_or(state, report, key::report_id, key::empty) == key::empty ||
			(state.lookup(report, str(key::casualties), casualties) && !gd::is_dict(casualties))) {
		return state.new_dict();
	}
	return gd::as_dict(gd::engine_duplicate(state, dict_value(report), true));
}

bool is_hero_actor_id(State &state, Atom actor_id) {
	return gd::begins_with(state, actor_id, key::hero_actor_prefix);
}

Atom hero_actor_side(State &state, Atom actor_id) {
	return is_hero_actor_id(state, actor_id) ? gd::trim_prefix(state, actor_id, key::hero_actor_prefix) : static_cast<Atom>(key::empty);
}

Atom battle_actor_label(State &state, DictRef battle, Atom actor_id) {
	if (is_hero_actor_id(state, actor_id)) {
		return text_or(state, _hero_caster(state, battle, hero_actor_side(state, actor_id)), key::name, key::empty);
	}
	return _stack_label(state, _get_stack_by_id(state, battle, actor_id));
}

Atom battle_actor_side(State &state, DictRef battle, Atom actor_id) {
	if (is_hero_actor_id(state, actor_id)) {
		return hero_actor_side(state, actor_id);
	}
	return text_or(state, _get_stack_by_id(state, battle, actor_id), key::side, key::empty);
}

DictRef default_deployment_hex(State &state, Atom side, int64_t index, int64_t stack_count, DictRef stack) {
	return _default_stack_hex(state, side, index, stack_count, stack);
}

ArrayRef battle_obstacles(State &state, DictRef battle) {
	Value obstacles;
	if (state.lookup(battle, str(key::obstacles), obstacles) && gd::is_array(obstacles)) {
		return gd::as_array(gd::engine_duplicate(state, obstacles, true));
	}
	return state.new_array();
}

DictRef battle_obstacle_cells(State &state, DictRef battle) {
	return _obstacle_cell_map(state, battle);
}

Atom _damage_preview_text(State &state, DictRef preview) {
	if (gd::is_empty(state, preview)) {
		return key::no_clean_damage;
	}
	const int64_t min_damage = gd::int_field(state, preview, key::min_damage, 0);
	const int64_t max_damage = gd::int_field(state, preview, key::max_damage, min_damage);
	const int64_t min_units = gd::int_field(state, preview, key::min_units, 0);
	const int64_t max_units = gd::int_field(state, preview, key::max_units, min_units);
	const Atom damage_text = min_damage == max_damage
			? gd::format(state, key::d_damage, {int_value(min_damage)})
			: gd::format(state, key::d_d_damage, {int_value(min_damage), int_value(max_damage)});
	if (max_units <= 0) {
		return damage_text;
	}
	const Atom unit_text = min_units == max_units
			? gd::format(state, key::d_unit, {int_value(min_units)})
			: gd::format(state, key::d_d_units, {int_value(min_units), int_value(max_units)});
	return gd::format(state, key::phrase_with_steps_text, {str(damage_text), str(unit_text)});
}

DictRef _retaliation_range_preview(State &state, DictRef attacker, DictRef defender, DictRef battle, int64_t attack_distance, DictRef attack_preview) {
	if (gd::is_empty(state, attack_preview)) {
		return state.new_dict();
	}
	const DictRef low_state = gd::as_dict(gd::engine_duplicate(state, dict_value(defender), true));
	state.set(low_state, str(key::total_health), int_value(engine_max<int64_t>(0, gd::sub(gd::int_field(state, defender, key::total_health, 0), gd::int_field(state, attack_preview, key::max_damage, 0)))));
	const DictRef high_state = gd::as_dict(gd::engine_duplicate(state, dict_value(defender), true));
	state.set(high_state, str(key::total_health), int_value(engine_max<int64_t>(0, gd::sub(gd::int_field(state, defender, key::total_health, 0), gd::int_field(state, attack_preview, key::min_damage, 0)))));
	const DictRef low_preview = _damage_range_preview(state, low_state, attacker, battle, false, true, attack_distance);
	const DictRef high_preview = _damage_range_preview(state, high_state, attacker, battle, false, true, attack_distance);
	if (gd::is_empty(state, low_preview) && gd::is_empty(state, high_preview)) {
		return state.new_dict();
	}
	const int64_t min_damage = gd::to_int(state, state.get(low_preview, str(key::min_damage), state.get(high_preview, str(key::min_damage), int_value(0))));
	const int64_t max_damage = gd::to_int(state, state.get(high_preview, str(key::max_damage), state.get(low_preview, str(key::max_damage), int_value(min_damage))));
	const DictRef losses = _unit_loss_range(state, attacker, min_damage, max_damage);
	const DictRef preview = state.new_dict();
	state.set(preview, str(key::min_damage), int_value(min_damage));
	state.set(preview, str(key::max_damage), int_value(max_damage));
	state.set(preview, str(key::min_units), int_value(gd::int_field(state, losses, key::min_units, 0)));
	state.set(preview, str(key::max_units), int_value(gd::int_field(state, losses, key::max_units, 0)));
	return preview;
}

Atom _wait_action_summary(State &state, DictRef battle, DictRef stack) {
	const Atom battle_id = text_or(state, stack, key::battle_id, key::empty);
	if (stack_has_waited(state, battle, battle_id)) {
		return gd::format(state, key::already_waited_text, {str(_stack_label(state, stack))});
	}
	const int64_t ahead = _stacks_ahead_after_wait(state, battle, battle_id);
	if (ahead <= 0) {
		return key::no_other_stack_is_left_to;
	}
	const Atom plural = ahead == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::s);
	return gd::format(state, key::act_later_this_round_after_d, {int_value(ahead), str(plural)});
}

} // namespace battle_rules

namespace spell_rules {

ArrayRef get_battle_actions(State &state, DictRef hero_state, DictRef battle, DictRef active_stack, DictRef target_stack) {
	const ArrayRef actions = state.new_array();
	const ArrayRef known = known_spells(state, hero_state, key::battle);
	for (const Value &spell : gd::items(state, array_value(known))) {
		const DictRef validation = validate_battle_spell(state, hero_state, battle, active_stack, target_stack, spell, key::player);
		const int64_t mana_cost = adjusted_spell_mana_cost(state, hero_state, spell);
		Atom summary = _battle_spell_action_summary(state, hero_state, battle, active_stack, target_stack, gd::as_dict(spell));
		const Atom validation_message = text_or(state, validation, key::message, key::empty);
		if (validation_message != key::empty) {
			summary = gd::format(state, key::s_blocked_s_3, {str(summary), str(validation_message)});
		}
		const Atom category = spell_category_label(state, gd::as_dict(spell));
		const Atom target_mode = _target_mode_label(state, string_of(state, ai::vget(state, spell, key::target_mode, str(key::self))));
		const Atom ready = gd::bool_field(state, validation, key::ok, false) ? static_cast<Atom>(key::ready_2) : static_cast<Atom>(key::empty);
		summary = gd::format(state, key::s_cost_d_mana_target_s, {str(category), int_value(mana_cost), str(target_mode), str(ready), str(gd::strip_edges(state, summary))});

		const DictRef action = state.new_dict();
		state.set(action, str(key::id), str(gd::format(state, key::cast_spell_s, {str(string_of(state, ai::vget(state, spell, key::id, str(key::empty))))})));
		state.set(action, str(key::label), str(gd::format(state, key::cast_s_d, {str(string_of(state, ai::vget(state, spell, key::name, str(key::spell_word)))), int_value(mana_cost)})));
		state.set(action, str(key::disabled), bool_value(!gd::bool_field(state, validation, key::ok, false)));
		state.set(action, str(key::summary), str(gd::strip_edges(state, summary)));
		state.set(action, str(key::cost), int_value(mana_cost));
		state.set(action, str(key::category), str(spell_category_label(state, gd::as_dict(spell))));
		state.set(action, str(key::effect), str(_battle_spell_effect_summary(state, hero_state, gd::as_dict(spell), battle, active_stack, target_stack)));
		const Atom readiness = gd::bool_field(state, validation, key::ok, false)
				? static_cast<Atom>(key::Ready)
				: gd::format(state, key::blocked_s, {str(validation_message)});
		state.set(action, str(key::readiness), str(readiness));
		state.set(action, str(key::target), str(_target_mode_label(state, string_of(state, ai::vget(state, spell, key::target_mode, str(key::self))))));
		state.set(action, str(key::best_use), str(_best_use_line(state, gd::as_dict(spell), battle, active_stack, target_stack)));
		state.append(actions, dict_value(action));
	}
	return actions;
}

Atom _battle_spell_action_summary(State &state, DictRef hero_state, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell) {
	const Atom timing_hint = battle_spell_timing_summary(state, hero_state, battle, active_stack, target_stack, spell);
	Value effect_value;
	const bool has_effect = state.lookup(spell, str(key::effect), effect_value);
	// spell.get("effect", {}).get("type", ""): a missing effect is {}, whose type is "".
	const Atom effect_type = has_effect ? string_of(state, ai::vget(state, effect_value, key::type, str(key::empty))) : static_cast<Atom>(key::empty);
	const DictRef effect = has_effect ? effect_value.ref : 0;
	// summary += " Timing: %s" % timing_hint
	const auto with_timing = [&](Atom summary) {
		return timing_hint != key::empty ? concat(state, summary, gd::format(state, key::timing_s, {str(timing_hint)})) : summary;
	};
	const auto grant_for = [&](Atom summary) {
		const DictRef modifiers = battle_spell_modifiers(state, spell);
		if (!gd::is_empty(state, modifiers)) {
			const Atom modifier_text = _modifier_summary(state, modifiers);
			const Atom turns = _turns_label(state, spell_duration_rounds(state, hero_state, gd::field_or(state, effect, key::duration_rounds, int_value(1)), spell, key::buff));
			summary = concat(state, summary, gd::format(state, key::grant_s_for_s, {str(modifier_text), str(turns)}));
		}
		return summary;
	};

	if (effect_type == key::damage_enemy) {
		const DictRef damage_projection = battle_spell_damage_projection(state, hero_state, battle, target_stack, spell);
		const int64_t final_damage = gd::int_field(state, damage_projection, key::final_damage, 0);
		Atom summary = gd::format(state, key::projected_d_damage_to_s, {int_value(final_damage), str(text_or(state, target_stack, key::name, key::the_selected_enemy))});
		if (gd::int_field(state, damage_projection, key::resistance_pct, 0) > 0) {
			const int64_t raw_damage = gd::int_field(state, damage_projection, key::raw_damage, 0);
			const int64_t resistance_pct = gd::int_field(state, damage_projection, key::resistance_pct, 0);
			summary = concat(state, summary, gd::format(state, key::resistance_reduces_raw_d_by_d, {int_value(raw_damage), int_value(resistance_pct)}));
		}
		const DictRef status_effect = typed_dict_field(state, effect, key::status_effect);
		if (!gd::is_empty(state, status_effect)) {
			const DictRef status_payload = _status_effect_from_spell_effect(state, spell, battle, hero_state);
			const int64_t control_pct = control_resistance_pct(state, battle, target_stack, spell);
			const Atom label = text_or(state, status_effect, key::label, key::a_battle_effect);
			const Atom terms = _status_terms(state, status_effect);
			const Atom turns = _turns_label(state, spell_duration_rounds(state, hero_state, gd::field_or(state, status_effect, key::duration_rounds, int_value(1)), spell, key::debuff));
			summary = concat(state, summary, gd::format(state, key::leaves_it_s_s_for_s, {str(label), str(terms), str(turns)}));
			if (target_is_immune_to_status(state, target_stack, battle, text_or(state, status_payload, key::effect_id, key::empty))) {
				summary = concat(state, summary, key::target_is_immune_to_that_rider);
			} else if (control_pct > 0) {
				summary = concat(state, summary, gd::format(state, key::rider_success_chance_d, {int_value(engine_max<int64_t>(0, gd::sub(100, control_pct)))}));
			}
		}
		return with_timing(summary);
	}
	if (effect_type == key::control_enemy) {
		const DictRef control_effect = typed_dict_field(state, effect, key::status_effect);
		const Atom target_name = text_or(state, target_stack, key::name, key::the_selected_enemy);
		const Atom label = text_or(state, control_effect, key::label, key::control);
		const Atom terms = _status_terms(state, control_effect);
		const Atom turns = _turns_label(state, spell_duration_rounds(state, hero_state, gd::field_or(state, control_effect, key::duration_rounds, int_value(1)), spell, key::debuff));
		Atom summary = gd::format(state, key::leave_s_s_s_for_s, {str(target_name), str(label), str(terms), str(turns)});
		const DictRef control_payload = _status_effect_from_spell_effect(state, spell, battle, hero_state);
		const int64_t control_pct = control_resistance_pct(state, battle, target_stack, spell);
		if (target_is_immune_to_status(state, target_stack, battle, text_or(state, control_payload, key::effect_id, key::empty))) {
			summary = concat(state, summary, key::target_is_immune);
		} else if (control_pct > 0) {
			summary = concat(state, summary, gd::format(state, key::success_chance_d, {int_value(engine_max<int64_t>(0, gd::sub(100, control_pct)))}));
		}
		return with_timing(summary);
	}
	if (effect_type == key::recover_ally) {
		const int64_t amount = _battle_spell_recovery_amount(state, hero_state, spell);
		const Atom recovery_summary = gd::format(state, key::restore_up_to_d_health_to, {int_value(amount), str(text_or(state, active_stack, key::name, key::the_active_stack_text))});
		return with_timing(grant_for(recovery_summary));
	}
	if (effect_type == key::cleanse_ally) {
		const Atom cleansed = join_array(state, key::comma_space, _cleanse_labels(state, effect));
		const Atom cleanse_summary = gd::format(state, key::cleanse_s_from_s, {str(cleansed), str(text_or(state, active_stack, key::name, key::the_active_stack_text))});
		return with_timing(grant_for(cleanse_summary));
	}
	if (effect_type == key::defense_buff || effect_type == key::initiative_buff || effect_type == key::attack_buff) {
		const Atom modifier_text = _modifier_summary(state, battle_spell_modifiers(state, spell));
		const Atom target_name = text_or(state, active_stack, key::name, key::the_active_stack_text);
		const Atom turns = _turns_label(state, spell_duration_rounds(state, hero_state, gd::field_or(state, effect, key::duration_rounds, int_value(1)), spell, key::buff));
		return with_timing(gd::format(state, key::grant_s_to_s_for_s, {str(modifier_text), str(target_name), str(turns)}));
	}
	return key::no_authored_battle_summary_is_available;
}

} // namespace spell_rules

namespace town_battle_rules {

Atom summary(State &state, DictRef battle, DictRef stack) {
	std::vector<Atom> parts;
	if (defends(state, battle, stack)) {
		for (const Atom id : {key::beacon_volley, key::prism_ward, key::root_ward, key::bellwake_fog}) {
			const DictRef active = effect(state, battle, id);
			if (!gd::is_empty(state, active)) {
				parts.push_back(text_or(state, active, key::description, id));
			}
		}
		if (gd::int_field(state, stack, key::town_shield_hp, 0) > 0) {
			const int64_t shield = gd::to_int(state, gd::index(state, stack, str(key::town_shield_hp)));
			parts.push_back(gd::format(state, key::pressure_shield_d_damage_absorption_remaining, {int_value(shield)}));
		}
	} else if (movement_penalty(state, battle, stack) > 0) {
		parts.push_back(text_or(state, effect(state, battle, key::chainboom), key::description, key::chainboom_slows_ground_movement));
	}
	return join_texts(state, key::semicolon_space, parts);
}

} // namespace town_battle_rules

namespace battle_action_playback {

void begin(State &state, DictRef battle) {
	state.set(battle, str(key::_live_action_playback_capture), array_value(state.new_array()));
}

DictRef finish(State &state, DictRef battle, DictRef result) {
	Value found;
	const ArrayRef frames = state.lookup(battle, str(key::_live_action_playback_capture), found)
			? ai::typed_array(found, "BattleActionPlayback.finish")
			: state.new_array();
	state.erase(battle, str(key::_live_action_playback_capture));
	if (gd::bool_field(state, result, key::ok, false)) {
		state.set(result, str(key::playback_frames), array_value(frames));
	}
	return result;
}

} // namespace battle_action_playback

} // namespace aurelion::rules::port
