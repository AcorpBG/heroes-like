// AiHeroRules: an army's fighting value with its memos, the resources a
// computer player is short of, payload values, stack merging and costs.

#include "aurelion_rules/port/ai_hero_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_damage_rules_ai.hpp"
#include "aurelion_rules/port/battle_rules_ai.hpp"
#include "aurelion_rules/port/enemy_turn_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"

#include <cmath>
#include <string>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::float_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

constexpr Atom kScript = key::ai_hero_rules_script;

// s.get_slice(splitter, slice) (String::get_slice): the whole text when the
// splitter does not occur, "" when the slice does not exist.
Atom get_slice(State &state, Atom text, Atom splitter, int64_t slice) {
	const std::string whole = state.text(text);
	const std::string separator = state.text(splitter);
	if (whole.empty() || separator.empty() || slice < 0) {
		return key::empty;
	}
	if (whole.find(separator) == std::string::npos) {
		return text;
	}
	size_t pos = 0;
	size_t prev_pos = 0;
	for (int64_t index = 0;; ++index) {
		pos = whole.find(separator, pos);
		if (pos == std::string::npos) {
			pos = whole.size();
		}
		if (index == slice) {
			return state.intern(std::string_view(whole).substr(prev_pos, pos - prev_pos));
		}
		if (pos == whole.size()) {
			break;
		}
		pos += separator.size();
		prev_pos = pos;
	}
	return key::empty;
}

// d.get(name, {}) if d.get(name, {}) is Dictionary else {}, only read: true
// with the Dictionary in out, false for the empty one.
bool dict_field(const State &state, DictRef dict, Atom name, Value &out) {
	return state.lookup(dict, str(name), out) && gd::is_dict(out);
}

// var d: Dictionary = object.get(name, {}) of an untyped object.
DictRef dict_or_new(State &state, const Value &object, Atom name) {
	if (!gd::is_dict(object)) {
		ai::vget(state, object, name);
	}
	Value found;
	if (state.lookup(object.ref, str(name), found)) {
		return gd::as_dict(found);
	}
	return state.new_dict();
}

// {"stacks": stacks, "left": left}.
DictRef stacks_and_left(State &state, ArrayRef stacks, ArrayRef left) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::stacks), array_value(stacks));
	state.set(result, str(key::left), array_value(left));
	return result;
}

} // namespace

namespace ai_hero_rules {

void _note_alternative(State &state, DictRef context, DictRef candidate, double score, int64_t distance) {
	const ArrayRef alternatives = gd::as_array(gd::index(state, context, str(key::decision_alternatives)));
	const ArrayRef alternative = state.new_array();
	state.append(alternative, float_value(compat::snappedf(score, 1.0)));
	state.append(alternative, str(ai::string_or_empty(state, candidate, key::kind)));
	state.append(alternative, str(get_slice(state, ai::string_or_empty(state, candidate, key::id), key::_object_, 1)));
	state.append(alternative, float_value(compat::snappedf(gd::float_field(state, candidate, key::value, 0.0), 1.0)));
	state.append(alternative, int_value(distance));
	state.append(alternatives, array_value(alternative));
	gd::sort_custom(state, alternatives, [&](const Value &a, const Value &b) {
		const ArrayRef left = gd::as_array(a);
		const ArrayRef right = gd::as_array(b);
		return gd::to_float(state.at(left, 0)) > gd::to_float(state.at(right, 0));
	});
	if (state.array_size(alternatives) > 3 + 1) {
		ai::array_resize(state, alternatives, 3 + 1);
	}
	state.set(context, str(key::decision_alternatives), array_value(alternatives));
}

DictRef _neutral_army(State &state, DictRef encounter) {
	const Value fallback = state.get(encounter, str(key::id), str(key::empty));
	const Atom encounter_id = gd::stringify(state, state.get(encounter, str(key::encounter_id), fallback));
	const DictRef encounter_template = gd::content_row(state, ContentTable::Encounter, encounter_id);
	return battle_rules::_enemy_army_for_encounter(state, encounter, encounter_template);
}

double army_power(State &state, const Value &stacks, const Value &commander) {
	double total = 0.0;
	double damage_per_round = 0.0;
	if (!gd::is_array(stacks)) {
		return total;
	}
	_sync_power_memos(state);
	const DictRef memo = ai::static_dict(state, kScript, key::_unit_power_memo);
	for (int64_t index = 0; index < state.array_size(stacks.ref); ++index) {
		const Value stack = state.at(stacks.ref, index);
		if (!gd::is_dict(stack)) {
			continue;
		}
		const int64_t count = gd::int_field(state, stack.ref, key::count, 0);
		if (count <= 0) {
			continue;
		}
		const Atom unit_id = ai::string_or_empty(state, stack.ref, key::unit_id);
		Value figures = state.get(memo, str(unit_id), Value());
		if (figures.kind == Kind::Nil) {
			figures = array_value(_unit_power_figures(state, unit_id));
			state.set(memo, str(unit_id), figures);
		}
		if (ai::vempty(state, figures)) {
			continue;
		}
		total += gd::to_float(ai::vindex(state, figures, int_value(0))) * static_cast<double>(count);
		damage_per_round += gd::to_float(ai::vindex(state, figures, int_value(1))) * static_cast<double>(count);
	}
	if (gd::is_dict(commander) && !gd::is_empty(state, commander.ref)) {
		// The hero's attack raises the army's damage and its defense cuts the
		// damage it takes; its spells add to the army's damage per round.
		Value command;
		const bool has_command = dict_field(state, commander.ref, key::command, command);
		const int64_t attack = has_command ? gd::int_field(state, command.ref, key::attack, 0) : 0;
		const double damage_dealt = battle_damage_rules::attack_defense_multiplier(state, compat::engine_max<int64_t>(0, attack), 0);
		const int64_t defense = has_command ? gd::int_field(state, command.ref, key::defense, 0) : 0;
		const double damage_taken = battle_damage_rules::attack_defense_multiplier(state, 0, compat::engine_max<int64_t>(0, defense));
		total *= gd::engine_pow(state, damage_dealt / compat::engine_max(0.01, damage_taken), ai::static_float(state, kScript, key::HERO_COMMAND_POWER));
		const double spell_damage = _spell_damage_per_round(state, commander.ref);
		if (spell_damage > 0.0 && damage_per_round > 0.0) {
			total *= gd::engine_pow(state, 1.0 + spell_damage / damage_per_round, ai::static_float(state, kScript, key::HERO_SPELL_POWER));
		}
	}
	return total;
}

double _spell_damage_per_round(State &state, DictRef commander) {
	Value spellbook;
	if (!dict_field(state, commander, key::spellbook, spellbook)) {
		return 0.0;
	}
	Value known;
	if (!state.lookup(spellbook.ref, str(key::known_spell_ids), known) || !gd::is_array(known) || state.array_size(known.ref) == 0) {
		return 0.0;
	}
	Value mana_state;
	int64_t mana = 0;
	if (dict_field(state, spellbook.ref, key::mana, mana_state)) {
		const Value mana_max = state.get(mana_state.ref, str(key::max), int_value(0));
		mana = gd::to_int(state, state.get(mana_state.ref, str(key::current), mana_max));
	}
	Value command;
	const int64_t power = compat::engine_max<int64_t>(0, dict_field(state, commander, key::command, command) ? gd::int_field(state, command.ref, key::power, 0) : 0);
	const DictRef memo = ai::static_dict(state, kScript, key::_damage_spell_memo);
	double best = 0.0;
	for (int64_t index = 0; index < state.array_size(known.ref); ++index) {
		const Atom spell_id = gd::stringify(state, state.at(known.ref, index));
		Value figures = state.get(memo, str(spell_id), Value());
		if (figures.kind == Kind::Nil) {
			figures = array_value(_damage_spell_figures(state, spell_id));
			state.set(memo, str(spell_id), figures);
		}
		if (ai::vempty(state, figures)) {
			continue;
		}
		const int64_t mana_cost = gd::to_int(state, ai::vindex(state, figures, int_value(0)));
		if (mana_cost == 0) {
			throw state::ScriptError("Division by zero error in operator '/'.");
		}
		const int64_t casts = compat::engine_min<int64_t>(ai::static_int(state, kScript, key::BATTLE_ROUNDS_ESTIMATE), compat::int_div(mana, mana_cost));
		const int64_t base_damage = gd::to_int(state, ai::vindex(state, figures, int_value(1)));
		const int64_t power_scale = gd::to_int(state, ai::vindex(state, figures, int_value(2)));
		const double per_cast = static_cast<double>(gd::add(base_damage, gd::mul(power, power_scale)));
		best = compat::engine_max(best, per_cast * static_cast<double>(casts));
	}
	return best / static_cast<double>(ai::static_int(state, kScript, key::BATTLE_ROUNDS_ESTIMATE));
}

ArrayRef _unit_power_figures(State &state, Atom unit_id) {
	const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
	if (gd::is_empty(state, unit)) {
		return state.new_array();
	}
	const double min_damage = gd::float_field(state, unit, key::min_damage, 1.0);
	const double max_damage = gd::float_field(state, unit, key::max_damage, 1.0);
	const double damage = (min_damage + max_damage) * 0.5;
	const double health = gd::float_field(state, unit, key::hp, 1.0);
	double per = ai::static_float(state, kScript, key::POWER_SCALE) * gd::engine_pow(state, compat::engine_max(1.0, health), ai::static_float(state, kScript, key::POWER_HEALTH));
	per = per * gd::engine_pow(state, compat::engine_max(0.5, damage), ai::static_float(state, kScript, key::POWER_DAMAGE));
	const double defense = static_cast<double>(gd::int_field(state, unit, key::defense, 0));
	const double speed = static_cast<double>(gd::int_field(state, unit, key::speed, 0));
	const double initiative = static_cast<double>(gd::int_field(state, unit, key::initiative, 0));
	const double by_defense = ai::static_float(state, kScript, key::POWER_PER_DEFENSE) * defense;
	const double by_speed = ai::static_float(state, kScript, key::POWER_PER_SPEED) * speed;
	const double by_initiative = ai::static_float(state, kScript, key::POWER_PER_INITIATIVE) * initiative;
	per *= gd::engine_exp(state, by_defense + by_speed + by_initiative);
	if (gd::bool_field(state, unit, key::ranged, false)) {
		per *= ai::static_float(state, kScript, key::RANGED_POWER);
	}
	const ArrayRef figures = state.new_array();
	state.append(figures, float_value(per));
	state.append(figures, float_value(damage));
	return figures;
}

ArrayRef _damage_spell_figures(State &state, Atom spell_id) {
	const DictRef spell = gd::content_row(state, ContentTable::Spell, spell_id);
	Value effect;
	const bool has_effect = dict_field(state, spell, key::effect, effect);
	if (ai::string_or_empty(state, spell, key::context) != key::battle || (has_effect ? ai::string_or_empty(state, effect.ref, key::type) : key::empty) != key::damage_enemy) {
		return state.new_array();
	}
	const ArrayRef figures = state.new_array();
	state.append(figures, int_value(compat::engine_max<int64_t>(1, gd::int_field(state, spell, key::mana_cost, 1))));
	state.append(figures, int_value(gd::int_field(state, effect.ref, key::base_damage, 0)));
	state.append(figures, int_value(gd::int_field(state, effect.ref, key::power_scale, 0)));
	return figures;
}

void _sync_power_memos(State &state) {
	const ArrayRef sources = state.new_array();
	state.append(sources, int_value(gd::content_revision(state)));
	state.append(sources, dict_value(gd::content_file(state, key::units_path)));
	state.append(sources, dict_value(gd::content_file(state, key::spells_path)));
	const ArrayRef kept = ai::static_array(state, kScript, key::_power_memo_sources);
	if (state.array_size(kept) != state.array_size(sources) || !gd::equal(state, state.at(kept, 0), state.at(sources, 0)) || !gd::is_same(state, state.at(kept, 1), state.at(sources, 1)) || !gd::is_same(state, state.at(kept, 2), state.at(sources, 2))) {
		gd::set_static_var(state, kScript, key::_unit_power_memo, dict_value(state.new_dict()));
		gd::set_static_var(state, kScript, key::_damage_spell_memo, dict_value(state.new_dict()));
		gd::set_static_var(state, kScript, key::_power_memo_sources, array_value(sources));
		_apply_power_terms(state);
	}
}

double hero_power(State &state, DictRef entry) {
	Value army;
	Value stacks;
	const bool has_army = state.lookup(entry, str(key::enemy_army), army);
	if (!(has_army && gd::is_dict(army) && state.lookup(army.ref, str(key::stacks), stacks))) {
		stacks = array_value(state.new_array());
	}
	Value commander;
	if (!state.lookup(entry, str(key::enemy_commander_state), commander)) {
		commander = dict_value(state.new_dict());
	}
	return army_power(state, stacks, commander);
}

DictRef _resource_needs(State &state, DictRef session, DictRef context) {
	if (state.has(context, str(key::needs))) {
		return gd::as_dict(gd::index(state, context, str(key::needs)));
	}
	const DictRef needs = state.new_dict();
	const DictRef treasury = gd::as_dict(ai::vmember(state, gd::index(state, context, str(key::state)), key::treasury));
	const Atom controller = gd::stringify(state, gd::index(state, context, str(key::controller)));
	const ArrayRef entries = enemy_turn_rules::_owned_town_entries(state, session, controller);
	for (int64_t entry_index = 0; entry_index < state.array_size(entries); ++entry_index) {
		const DictRef town = dict_or_new(state, state.at(entries, entry_index), key::town);
		const ArrayRef options = overworld_rules::get_town_build_options(state, town, ai::session_int(state, session, key::day));
		for (int64_t option_index = 0; option_index < state.array_size(options); ++option_index) {
			const Atom building_id = gd::stringify(state, state.at(options, option_index));
			const DictRef status = overworld_rules::get_town_build_status(state, town, building_id);
			if (!gd::bool_field(state, status, key::buildable, false)) {
				continue;
			}
			Value building;
			if (!state.lookup(status, str(key::building), building)) {
				continue;
			}
			if (!gd::is_dict(building)) {
				ai::vget(state, building, key::cost);
			}
			Value cost;
			if (!state.lookup(building.ref, str(key::cost), cost)) {
				continue;
			}
			if (!gd::is_dict(cost)) {
				throw state::ScriptError(std::string("Invalid call. Nonexistent function 'keys' in base '") + gd::type_name(cost) + "'.");
			}
			for (const Value &cost_key : gd::items(state, cost)) {
				if (gd::to_int(state, gd::index(state, cost.ref, cost_key)) > gd::to_int(state, state.get(treasury, cost_key, int_value(0)))) {
					state.set(needs, str(gd::stringify(state, cost_key)), bool_value(true));
				}
			}
		}
	}
	state.set(context, str(key::needs), dict_value(needs));
	return needs;
}

double _payload_value(State &state, const Value &payload, DictRef needs) {
	double value = 0.0;
	if (!gd::is_dict(payload)) {
		return value;
	}
	const DictRef resource_values = ai::static_dict(state, kScript, key::RESOURCE_VALUES);
	for (const Value &resource : gd::items(state, payload)) {
		const Value held = gd::index(state, payload.ref, resource);
		const double amount = (gd::is_int(held) || gd::is_float(held)) ? gd::to_float(held) : 0.0;
		const Atom name = gd::stringify(state, resource);
		double unit = gd::to_float(state.get(resource_values, str(name), float_value(0.0)));
		if (state.has(needs, str(name)) && name != key::experience) {
			unit *= ai::static_float(state, kScript, key::SHORT_RESOURCE_MULTIPLIER);
		}
		value += amount * unit;
	}
	return value;
}

DictRef _merge_stacks_into(State &state, const Value &destination, const Value &additions) {
	ArrayRef stacks = gd::is_array(destination) ? gd::deep_duplicate_array(state, destination.ref) : state.new_array();
	const ArrayRef left = state.new_array();
	if (!gd::is_array(additions)) {
		return stacks_and_left(state, stacks, left);
	}
	for (int64_t index = 0; index < state.array_size(additions.ref); ++index) {
		const Value stack = state.at(additions.ref, index);
		if (!gd::is_dict(stack)) {
			continue;
		}
		const int64_t count = gd::int_field(state, stack.ref, key::count, 0);
		if (count <= 0) {
			continue;
		}
		const DictRef addition = state.new_dict();
		state.set(addition, str(ai::string_or_empty(state, stack.ref, key::unit_id)), int_value(count));
		const DictRef plan = hero_command_rules::army_addition_plan(state, array_value(stacks), addition);
		if (gd::bool_field(state, plan, key::ok, false)) {
			stacks = gd::as_array(state.get(plan, str(key::stacks), array_value(stacks)));
		} else {
			state.append(left, dict_value(gd::deep_duplicate_dict(state, stack.ref)));
		}
	}
	return stacks_and_left(state, stacks, left);
}

bool _can_afford(State &state, DictRef pool, DictRef cost) {
	for (const Value &resource : gd::items(state, dict_value(cost))) {
		if (gd::to_int(state, state.get(pool, resource, int_value(0))) < gd::to_int(state, gd::index(state, cost, resource))) {
			return false;
		}
	}
	return true;
}

void _apply_power_terms(State &state) {
	const Atom script = key::ai_hero_rules_script;
	const DictRef terms = gd::as_dict(gd::index(state, gd::content_file(state, key::ai_hero_weights_path), str(key::army_power)));
	ai::assign_float(state, script, key::POWER_SCALE, terms, key::power_scale);
	ai::assign_float(state, script, key::POWER_HEALTH, terms, key::power_health);
	ai::assign_float(state, script, key::POWER_DAMAGE, terms, key::power_damage);
	ai::assign_float(state, script, key::POWER_PER_DEFENSE, terms, key::power_per_defense);
	ai::assign_float(state, script, key::POWER_PER_SPEED, terms, key::power_per_speed);
	ai::assign_float(state, script, key::POWER_PER_INITIATIVE, terms, key::power_per_initiative);
	ai::assign_float(state, script, key::RANGED_POWER, terms, key::ranged_power);
	ai::assign_float(state, script, key::HERO_COMMAND_POWER, terms, key::hero_command_power);
	ai::assign_float(state, script, key::HERO_SPELL_POWER, terms, key::hero_spell_power);
	ai::assign_int(state, script, key::BATTLE_ROUNDS_ESTIMATE, terms, key::battle_rounds_estimate);
}

} // namespace ai_hero_rules

} // namespace aurelion::rules::port
