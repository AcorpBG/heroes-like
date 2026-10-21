// Layer 2: the damage stream, damage application and the event log.

#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/compat/godot_pcg.hpp"
#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/port/spell_rules.hpp"
#include "aurelion_rules/port/town_battle_rules.hpp"

#include <string>

namespace aurelion::rules::port::battle_rules {

using compat::engine_max;
using compat::engine_min;
using gd::array_value;
using gd::int_value;
using gd::str;
using state::Kind;
namespace key = state::key;

namespace {

// BattleRules consts.
constexpr int64_t RECENT_EVENT_LIMIT = 6;
constexpr int64_t DAMAGE_RNG_VERSION = 1;

int64_t int_field(const State &state, DictRef dict, Atom field, int64_t fallback) {
	return gd::to_int(state, state.get(dict, str(field), int_value(fallback)));
}

Atom string_field(const State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::to_string(state.get(dict, str(field), str(fallback)));
}

// d.get(key, []): the stored value, or a new empty Array when the key is missing.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// x.size() of an untyped value: an Array or a Dictionary has one; Nil, a
// number, a String or a bool has no size() method.
int64_t untyped_size(const State &state, const Value &value) {
	if (value.kind == Kind::Array) {
		return state.array_size(value.ref);
	}
	if (value.kind == Kind::Dict) {
		return state.dict_size(value.ref);
	}
	if (value.kind == Kind::Opaque) {
		throw state::ScriptError("size() of an opaque value is not ported");
	}
	throw state::ScriptError(std::string("Invalid call. Nonexistent function 'size' in base '") + gd::type_name(value) + "'.");
}

// x[index] of an untyped value with an int index: an Array's item (out of
// range is an error), a Dictionary's value of the int key (missing is an error).
Value untyped_at(const State &state, const Value &value, int64_t index) {
	if (value.kind == Kind::Array) {
		return state.at(value.ref, index);
	}
	if (value.kind == Kind::Dict) {
		return gd::index(state, value.ref, int_value(index));
	}
	throw state::ScriptError(std::string("Invalid access of index '") + compat::itos(index) + "' on a base object of type '" + gd::type_name(value) + "'.");
}

// x[index] = item of an untyped value with an int index.
void untyped_set_at(State &state, const Value &value, int64_t index, const Value &item) {
	if (value.kind == Kind::Array) {
		state.set_at(value.ref, index, item);
		return;
	}
	if (value.kind == Kind::Dict) {
		state.set(value.ref, int_value(index), item);
		return;
	}
	throw state::ScriptError(std::string("Invalid assignment of index '") + compat::itos(index) + "' on a base object of type '" + gd::type_name(value) + "'.");
}

// RandomNumberGenerator.new(), then .seed = seed: its .state as GDScript's int.
int64_t seeded_rng_state(int64_t seed) {
	compat::GodotPcg pcg;
	pcg.seed(static_cast<uint64_t>(seed));
	return static_cast<int64_t>(pcg.state());
}

} // namespace

int64_t _calculate_damage(State &state, DictRef attacker, DictRef defender, DictRef battle, const Value &rng, bool is_ranged, bool is_retaliation, int64_t attack_distance) {
	const int64_t from = int_field(state, attacker, key::min_damage, 1);
	const int64_t min_damage = int_field(state, attacker, key::min_damage, 1);
	const int64_t max_damage = int_field(state, attacker, key::max_damage, 1);
	// max(int, int): an int.
	const int64_t to = engine_max<int64_t>(min_damage, max_damage);
	const int64_t base_roll = gd::rng_randi_range(state, rng, from, to);
	_commit_damage_rng_roll(state, battle, rng);
	return _damage_for_roll(state, attacker, defender, battle, base_roll, is_ranged, is_retaliation, attack_distance);
}

void _apply_damage_to_stack(State &state, DictRef battle, Atom battle_id, int64_t damage) {
	const Value stacks = field_or_new_array(state, battle, key::stacks);
	bool killed = false;
	const int64_t count = untyped_size(state, stacks);
	for (int64_t index = 0; index < count; ++index) {
		const Value stack = untyped_at(state, stacks, index);
		if (gd::is_dict(stack) && string_field(state, stack.ref, key::battle_id, key::empty) == battle_id) {
			const int64_t absorbed = town_battle_rules::absorb(state, stack.ref, damage);
			const bool was_alive = int_field(state, stack.ref, key::total_health, 0) > 0;
			// max(0, int - max(0, damage - absorbed)): ints.
			const int64_t health = int_field(state, stack.ref, key::total_health, 0);
			const int64_t taken = engine_max<int64_t>(0, gd::sub(damage, absorbed));
			state.set(stack.ref, str(key::total_health), int_value(engine_max<int64_t>(0, gd::sub(health, taken))));
			if (absorbed > 0) {
				const std::string label = state.text(_stack_label(state, stack.ref));
				_record_event(state, battle, state.intern("Pressure shield absorbs " + compat::itos(absorbed) + " damage for " + label + "."));
			}
			untyped_set_at(state, stacks, index, stack);
			killed = was_alive && int_field(state, stack.ref, key::total_health, 0) <= 0;
			break;
		}
	}
	state.set(battle, str(key::stacks), stacks);
	_sync_occupied_hexes(state, battle);
	// A kill can remove the closest pair of opposing stacks.
	if (killed) {
		_sync_distance_from_hexes(state, battle);
	}
}

int64_t _restore_stack_health(State &state, DictRef battle, Atom battle_id, int64_t amount) {
	int64_t restored = 0;
	const Value stacks = field_or_new_array(state, battle, key::stacks);
	const int64_t count = untyped_size(state, stacks);
	for (int64_t index = 0; index < count; ++index) {
		const Value stack = untyped_at(state, stacks, index);
		if (!gd::is_dict(stack) || string_field(state, stack.ref, key::battle_id, key::empty) != battle_id) {
			continue;
		}
		const int64_t current_health = engine_max<int64_t>(0, int_field(state, stack.ref, key::total_health, 0));
		const int64_t max_recoverable_health = gd::add(current_health, spell_rules::battle_spell_recoverable_health(state, stack.ref));
		const int64_t updated_health = engine_min<int64_t>(max_recoverable_health, gd::add(current_health, engine_max<int64_t>(0, amount)));
		restored = engine_max<int64_t>(0, gd::sub(updated_health, current_health));
		state.set(stack.ref, str(key::total_health), int_value(updated_health));
		untyped_set_at(state, stacks, index, stack);
		break;
	}
	state.set(battle, str(key::stacks), stacks);
	_sync_occupied_hexes(state, battle);
	return restored;
}

int64_t _resolved_damage_seed(State &state, const Value &session, DictRef battle) {
	int64_t seed = int_field(state, battle, key::combat_seed, 0);
	if (seed != 0) {
		return seed;
	}
	// The Array literal's items, in GDScript's evaluation order.
	const Value session_id = gd::member(state, session, key::session_id);
	const Atom encounter_id = string_field(state, battle, key::encounter_id, key::empty);
	const Atom resolved_key = string_field(state, battle, key::resolved_key, key::empty);
	const int64_t day = gd::to_int(state, gd::member(state, session, key::day));
	const int64_t round = int_field(state, battle, key::round, 1);
	const ArrayRef parts = state.new_array();
	state::ArrayNode &node = state.array_node(parts);
	node.items.push_back(session_id);
	node.items.push_back(str(encounter_id));
	node.items.push_back(str(resolved_key));
	node.items.push_back(int_value(day));
	node.items.push_back(int_value(round));
	seed = gd::hash(state, array_value(parts));
	return seed != 0 ? seed : 1;
}

void _initialize_damage_rng_state(State &state, const Value &session, DictRef battle) {
	const int64_t seed = _resolved_damage_seed(state, session, battle);
	const int64_t rng_state = seeded_rng_state(seed);
	state.set(battle, str(key::combat_seed), int_value(seed));
	state.set(battle, str(key::damage_rng_version), int_value(DAMAGE_RNG_VERSION));
	const Atom state_text = state.intern(compat::itos(rng_state));
	state.set(battle, str(key::damage_rng_state), str(state_text));
	state.set(battle, str(key::damage_rng_roll_count), int_value(0));
	state.set(battle, str(key::damage_rng_integrity), str(_damage_rng_integrity(state, seed, state_text, 0)));
}

void _ensure_damage_rng_state(State &state, const Value &session, DictRef battle) {
	const int64_t version = int_field(state, battle, key::damage_rng_version, 0);
	const Atom state_text = gd::strip_edges(state, string_field(state, battle, key::damage_rng_state, key::empty));
	const Value roll_count_value = state.get(battle, str(key::damage_rng_roll_count), int_value(0));
	const int64_t roll_count = gd::to_int(state, roll_count_value);
	const bool has_any_rng_field = (state.has(battle, str(key::damage_rng_version))
			|| state.has(battle, str(key::damage_rng_state))
			|| state.has(battle, str(key::damage_rng_roll_count))
			|| state.has(battle, str(key::damage_rng_integrity)));
	if (version == 0 && !has_any_rng_field) {
		_initialize_damage_rng_state(state, session, battle);
		return;
	}
	if (version != DAMAGE_RNG_VERSION) {
		gd::push_warning(state, "Battle damage RNG version " + compat::itos(version) + " is unsupported; reinitializing from the authoritative combat seed.");
		_initialize_damage_rng_state(state, session, battle);
		return;
	}
	const int64_t seed = _resolved_damage_seed(state, session, battle);
	const bool canonical_state = gd::is_valid_int(state, state_text) && compat::itos(compat::to_int(state.text(state_text))) == state.text(state_text);
	const int64_t count_type = gd::type_of(roll_count_value);
	const bool canonical_count = ((count_type == state::variant_type::INT || count_type == state::variant_type::FLOAT)
			&& gd::is_equal_approx(gd::to_float(roll_count_value), static_cast<double>(roll_count))
			&& roll_count >= 0);
	const Atom expected_integrity = _damage_rng_integrity(state, seed, state_text, roll_count);
	if (!canonical_state
			|| !canonical_count
			|| string_field(state, battle, key::damage_rng_integrity, key::empty) != expected_integrity) {
		gd::push_warning(state, "Battle damage RNG state failed integrity validation; reinitializing from the authoritative combat seed.");
		_initialize_damage_rng_state(state, session, battle);
		return;
	}
	state.set(battle, str(key::combat_seed), int_value(seed));
	state.set(battle, str(key::damage_rng_version), int_value(DAMAGE_RNG_VERSION));
	state.set(battle, str(key::damage_rng_state), str(state_text));
	state.set(battle, str(key::damage_rng_roll_count), int_value(roll_count));
	state.set(battle, str(key::damage_rng_integrity), str(expected_integrity));
}

Value _damage_rng_for_battle(State &state, const Value &session) {
	_ensure_damage_rng_state(state, session, gd::as_dict(gd::member(state, session, key::battle)));
	const int64_t seed = int_field(state, gd::as_dict(gd::member(state, session, key::battle)), key::combat_seed, 1);
	// int(String(session.battle.get(DAMAGE_RNG_STATE_KEY, "0"))): the default "0" is 0.
	Value state_value;
	const bool has_state = state.lookup(gd::as_dict(gd::member(state, session, key::battle)), str(key::damage_rng_state), state_value);
	const int64_t rng_state = has_state ? compat::to_int(state.text(gd::to_string(state_value))) : 0;
	return gd::rng_new(state, seed, rng_state);
}

void _commit_damage_rng_roll(State &state, DictRef battle, const Value &rng) {
	const Atom state_text = state.intern(compat::itos(gd::rng_state(state, rng)));
	const int64_t roll_count = gd::add(int_field(state, battle, key::damage_rng_roll_count, 0), 1);
	state.set(battle, str(key::damage_rng_version), int_value(DAMAGE_RNG_VERSION));
	state.set(battle, str(key::damage_rng_state), str(state_text));
	state.set(battle, str(key::damage_rng_roll_count), int_value(roll_count));
	state.set(battle, str(key::damage_rng_integrity), str(_damage_rng_integrity(state, int_field(state, battle, key::combat_seed, 1), state_text, roll_count)));
}

Atom _damage_rng_integrity(State &state, int64_t seed, Atom state_text, int64_t roll_count) {
	const std::string text = "damage_rng_v" + compat::itos(DAMAGE_RNG_VERSION) + "|" + compat::itos(seed) + "|" + state.text(state_text) + "|" + compat::itos(roll_count);
	return state.intern(compat::sha256_text(text));
}

void _record_event(State &state, DictRef battle, Atom message) {
	if (gd::is_empty(state, battle)) {
		return;
	}
	const Atom text = gd::strip_edges(state, message);
	if (text == key::empty) {
		return;
	}
	const ArrayRef events = _normalize_recent_events(state, field_or_new_array(state, battle, key::recent_events));
	for (int64_t index = state.array_size(events) - 1; index > -1; --index) {
		if (gd::to_string(state.at(events, index)) == text) {
			gd::remove_at(state, events, index);
		}
	}
	gd::push_front(state, events, str(text));
	while (state.array_size(events) > RECENT_EVENT_LIMIT) {
		gd::pop_back(state, events);
	}
	state.set(battle, str(key::recent_events), array_value(events));
}

ArrayRef _normalize_recent_events(State &state, const Value &value) {
	const ArrayRef events = state.new_array();
	if (gd::is_array(value)) {
		// events is a new node, so walking value's items is safe while it grows.
		for (const Value &entry : gd::items(state, value)) {
			const Atom text = gd::strip_edges(state, gd::to_string(entry));
			if (text == key::empty || gd::array_has(state, events, str(text))) {
				continue;
			}
			state.append(events, str(text));
			if (state.array_size(events) >= RECENT_EVENT_LIMIT) {
				break;
			}
		}
	}
	return events;
}

} // namespace aurelion::rules::port::battle_rules
