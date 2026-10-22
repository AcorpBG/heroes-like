// HeroProgressionRules ports shared by the computer players' day (Phase 4) and the
// ends of a battle (Phase 5): experience, levels and their pending choices.

#include "aurelion_rules/port/hero_progression_rules.hpp"

#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/port/enemy_states.hpp"

#include <string>
#include <vector>

namespace aurelion::rules::port {

// Defined in Phase 5's files without a header.
namespace hero_progression_rules {
Atom growth_seed(State &state, DictRef hero_state);
Atom command_path(State &state, DictRef hero_state);
DictRef _build_choice_group(State &state, DictRef hero_state, int64_t level_number);
DictRef current_pending_choice(State &state, DictRef hero_state);
DictRef specialty_definition(State &state, Atom specialty_id);
} // namespace hero_progression_rules

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::State;
using state::Value;
namespace key = state::key;

// s.hex_to_int() of lower-case hex digits (a SHA-256 digest's prefix).
int64_t hex_digits_to_int(const std::string &digits) {
	int64_t value = 0;
	for (const char c : digits) {
		value = value * 16 + (c >= 'a' ? c - 'a' + 10 : c - '0');
	}
	return value;
}

// sep.join(parts) of Strings.
Atom join_texts(State &state, const std::vector<std::string> &parts, const char *separator) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += separator;
		}
		joined += parts[index];
	}
	return state.intern(joined);
}

} // namespace

namespace hero_progression_rules {

DictRef add_experience(State &state, DictRef hero_state, int64_t amount) {
	return _add_experience(state, hero_state, experience_with_bonus(state, hero_state, amount));
}

int64_t experience_with_bonus(State &state, DictRef hero_state, int64_t amount) {
	if (amount <= 0) {
		return amount;
	}
	const int64_t bonus_pct = gd::int_field(state, aggregate_bonuses(state, hero_state), key::experience_bonus_pct, 0);
	return gd::add(amount, compat::int_div(gd::mul(amount, bonus_pct), 100));
}

DictRef _add_experience(State &state, DictRef hero_state, int64_t amount) {
	DictRef hero = ensure_hero_progression(state, gd::deep_duplicate_dict(state, hero_state));
	const ArrayRef messages = state.new_array();
	if (amount > 0) {
		state.set(hero, str(key::experience), int_value(gd::add(gd::int_field(state, hero, key::experience, 0), amount)));
		if (gd::int_field(state, hero, key::experience, 0) >= gd::int_field(state, hero, key::next_level_experience, 250)) {
			// Pin what the rolls come from, so later reads (the level-up popup)
			// and later levels roll from the same path and seed.
			state.set(hero, str(key::command_path), str(command_path(state, hero)));
			state.set(hero, str(key::growth_seed), str(growth_seed(state, hero)));
		}
		while (gd::int_field(state, hero, key::experience, 0) >= gd::int_field(state, hero, key::next_level_experience, 250)) {
			state.set(hero, str(key::level), int_value(gd::add(gd::int_field(state, hero, key::level, 1), 1)));
			// hero.get("command", {}): _apply_command_gain reads a missing one as {}.
			const Value command = gd::field(state, hero, key::command);
			const Atom stat = command_gain_stat(state, hero, gd::int_field(state, hero, key::level, 1));
			state.set(hero, str(key::command), dict_value(_apply_command_gain(state, command, stat)));
			const int64_t next_level_experience = gd::add(gd::add(gd::int_field(state, hero, key::next_level_experience, 250), 250), gd::mul(gd::int_field(state, hero, key::level, 1), 100));
			state.set(hero, str(key::next_level_experience), int_value(next_level_experience));
			hero = _enqueue_choice_group(state, hero, gd::int_field(state, hero, key::level, 1));
			const Atom name = gd::stringify(state, gd::field_or(state, hero, key::name, str(key::Hero)));
			state.append(messages, str(gd::format(state, key::s_reached_level_d, { str(name), int_value(gd::int_field(state, hero, key::level, 1)) })));
			const DictRef pending_choice = current_pending_choice(state, hero);
			if (!gd::is_empty(state, pending_choice)) {
				state.append(messages, str(gd::format(state, key::specialty_choice_ready_s, { str(pending_choice_summary(state, pending_choice)) })));
			}
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::hero), dict_value(hero));
	state.set(result, str(key::messages), array_value(messages));
	return result;
}

Atom pending_choice_summary(State &state, DictRef pending_choice) {
	std::vector<std::string> names;
	for (const Value &specialty_id_value : gd::field_items(state, pending_choice, str(key::options))) {
		const DictRef specialty = specialty_definition(state, gd::stringify(state, specialty_id_value));
		if (gd::is_empty(state, specialty)) {
			continue;
		}
		const Value fallback = state.get(specialty, str(key::name), specialty_id_value);
		names.push_back(state.text(gd::stringify(state, state.get(specialty, str(key::short_name), fallback))));
	}
	return join_texts(state, names, ", ");
}

DictRef _enqueue_choice_group(State &state, DictRef hero_state, int64_t level_number) {
	const DictRef hero = hero_state;
	const DictRef choice_group = _build_choice_group(state, hero, level_number);
	if (gd::is_empty(state, choice_group)) {
		return hero;
	}
	Value pending_choices;
	if (!state.lookup(hero, str(key::pending_specialty_choices), pending_choices) || !gd::is_array(pending_choices)) {
		pending_choices = array_value(state.new_array());
	}
	state.append(pending_choices.ref, dict_value(choice_group));
	state.set(hero, str(key::pending_specialty_choices), pending_choices);
	return hero;
}

Atom command_gain_stat(State &state, DictRef hero_state, int64_t level_number) {
	// COMMAND_GAIN_WEIGHTS[command_path(hero_state)] over COMMAND_STATS (attack, defense, power, knowledge).
	const Atom path = command_path(state, hero_state);
	static constexpr int64_t kMightWeights[4] = { 40, 40, 10, 10 };
	static constexpr int64_t kMagicWeights[4] = { 10, 10, 40, 40 };
	if (path != key::might && path != key::magic) {
		throw state::ScriptError("Invalid access to property or key '" + state.text(path) + "' on a base object of type 'Dictionary'.");
	}
	const int64_t *weights = path == key::magic ? kMagicWeights : kMightWeights;
	static constexpr Atom kStats[4] = { key::attack, key::defense, key::power, key::knowledge };
	int64_t total = 0;
	for (int index = 0; index < 4; ++index) {
		total += weights[index];
	}
	const Atom seed_text = gd::format(state, key::s_level_d, { str(growth_seed(state, hero_state)), int_value(level_number) });
	const std::string digest = compat::sha256_text(state.text(seed_text));
	int64_t roll = compat::posmod(hex_digits_to_int(digest.substr(0, 8)), total);
	for (int index = 0; index < 4; ++index) {
		roll -= weights[index];
		if (roll < 0) {
			return kStats[index];
		}
	}
	return kStats[0];
}

DictRef _apply_command_gain(State &state, const Value &command_state, Atom stat) {
	// (command_state if command_state is Dictionary else {}).get(stat, 0)
	const bool known = gd::is_dict(command_state);
	const DictRef command = state.new_dict();
	for (const Atom name : { key::attack, key::defense, key::power, key::knowledge }) {
		const int64_t value = known ? gd::int_field(state, command_state.ref, name, 0) : 0;
		state.set(command, str(name), int_value(compat::engine_max<int64_t>(0, value)));
	}
	state.set(command, str(stat), int_value(gd::add(gd::int_field(state, command, stat, 0), 1)));
	return command;
}

} // namespace hero_progression_rules

} // namespace aurelion::rules::port
