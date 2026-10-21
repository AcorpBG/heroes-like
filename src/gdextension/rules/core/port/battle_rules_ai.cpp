// BattleRules: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/battle_rules_ai.hpp"

#include "aurelion_rules/port/ai_hero_rules_ai.hpp"
#include "aurelion_rules/port/ai_port.hpp"

namespace aurelion::rules::port {

namespace {

using gd::Atom;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::State;
namespace key = state::key;

} // namespace

namespace battle_rules {

DictRef _enemy_army_for_encounter(State &state, DictRef encounter_placement, DictRef encounter) {
	DictRef enemy_army = gd::content_row(state, ContentTable::ArmyGroup, ai::string_or_empty(state, encounter, key::enemy_group_id));
	Value placement_army;
	if (state.lookup(encounter_placement, str(key::enemy_army), placement_army) && gd::is_dict(placement_army)) {
		Value stacks;
		if (state.lookup(placement_army.ref, str(key::stacks), stacks) && gd::is_array(stacks) && state.array_size(stacks.ref) != 0) {
			enemy_army = placement_army.ref;
		}
	}
	return enemy_army;
}

DictRef battle_rewards_for_strength(State &state, DictRef encounter, const Value &beaten_stacks, const Value &commander) {
	Value listed;
	const bool has_listed = state.lookup(encounter, str(key::rewards), listed) && gd::is_dict(listed);
	const double strength = ai_hero_rules::army_power(state, beaten_stacks, commander);
	const DictRef rewards = state.new_dict();
	if (strength <= 0.0) {
		return rewards;
	}
	const double scale = compat::engine_clamp(strength / 300.0, 0.25, 4.0);
	if (has_listed) {
		const ArrayRef keys = gd::keys(state, listed.ref);
		for (int64_t index = 0; index < state.array_size(keys); ++index) {
			const Value reward_key = state.at(keys, index);
			const Atom name = gd::stringify(state, reward_key);
			if (name == key::experience) {
				continue;
			}
			const Value listed_amount = gd::index(state, listed.ref, reward_key);
			if (!(gd::is_int(listed_amount) || gd::is_float(listed_amount))) {
				continue;
			}
			const double amount = gd::to_float(listed_amount) * 0.5 * scale;
			const int64_t paid = name == key::gold ? gd::mul(compat::float_to_int(compat::godot_round(amount / 10.0)), 10) : compat::float_to_int(compat::godot_round(amount));
			if (paid > 0) {
				state.set(rewards, str(name), int_value(paid));
			}
		}
	}
	const int64_t experience = compat::float_to_int(compat::godot_round(strength * 0.5));
	if (experience > 0) {
		state.set(rewards, str(key::experience), int_value(experience));
	}
	return rewards;
}

} // namespace battle_rules

} // namespace aurelion::rules::port
