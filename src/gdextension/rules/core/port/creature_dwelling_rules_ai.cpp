// CreatureDwellingRules: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/creature_dwelling_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/content_service_ai.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/compat/godot_string.hpp"

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;

} // namespace

namespace creature_dwelling_rules {

bool is_dwelling(State &state, DictRef site) {
	return ai::string_or_empty(state, site, key::family) == key::neutral_dwelling;
}

bool is_refugee_camp(State &state, DictRef site) {
	return is_dwelling(state, site) && ai::string_or_empty(state, site, key::dwelling_kind) == key::refugee_camp;
}

int64_t week_index(State &state, int64_t day) {
	(void)state;
	const int64_t first = day > 1 ? day : 1;
	return compat::float_to_int(compat::godot_floor(static_cast<double>(gd::sub(first, 1)) / 7.0));
}

int64_t unit_tier(State &state, Atom unit_id) {
	return gd::int_field(state, gd::content_row(state, ContentTable::Unit, unit_id), key::tier, 1);
}

ArrayRef creatures(State &state, DictRef node, DictRef site, int64_t day) {
	if (is_refugee_camp(state, site)) {
		const Atom unit_id = refugee_unit(state, node, day);
		const ArrayRef offered = state.new_array();
		if (unit_id != key::empty) {
			state.append(offered, str(unit_id));
		}
		return offered;
	}
	const ArrayRef result = state.new_array();
	Value recruits;
	if (state.lookup(site, str(key::weekly_recruits), recruits) && gd::is_dict(recruits)) {
		for (const Value &unit_id : gd::items(state, recruits)) {
			state.append(result, str(gd::stringify(state, unit_id)));
		}
	}
	return result;
}

DictRef weekly_growth(State &state, DictRef node, DictRef site, int64_t day) {
	const DictRef growth = state.new_dict();
	Value authored;
	const bool has_authored = state.lookup(site, str(key::weekly_recruits), authored);
	for (const Value &unit_id : gd::items(state, array_value(creatures(state, node, site, day)))) {
		int64_t amount = gd::int_field(state, gd::content_row(state, ContentTable::Unit, gd::to_string(unit_id)), key::growth, 1);
		if (!is_refugee_camp(state, site) && has_authored && gd::is_dict(authored) && state.has(authored.ref, unit_id)) {
			amount = gd::to_int(state, gd::index(state, authored.ref, unit_id));
		}
		state.set(growth, unit_id, int_value(amount > 1 ? amount : 1));
	}
	return growth;
}

DictRef population(State &state, DictRef node, DictRef site, int64_t day) {
	Value stored;
	const bool has_stored = state.lookup(node, str(key::dwelling_population), stored);
	if (gd::int_field(state, node, key::dwelling_week, -1) == week_index(state, day) && (!has_stored || gd::is_dict(stored))) {
		return has_stored ? gd::deep_duplicate_dict(state, stored.ref) : state.new_dict();
	}
	return weekly_growth(state, node, site, day);
}

DictRef unit_cost(State &state, Atom unit_id) {
	const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
	if (gd::int_field(state, unit, key::tier, 1) <= 1) {
		return state.new_dict();
	}
	return ai::duplicate_field(state, unit, key::cost);
}

Atom refugee_unit(State &state, DictRef node, int64_t day) {
	const ArrayRef pool = _refugee_candidates(state);
	if (state.array_size(pool) == 0) {
		return key::empty;
	}
	const Atom roll_key = gd::format(state, key::s_refugee_d, {str(ai::string_or_empty(state, node, key::placement_id)), int_value(week_index(state, day))});
	return gd::stringify(state, state.at(pool, _stable_roll(state, roll_key, state.array_size(pool))));
}

ArrayRef _refugee_candidates(State &state) {
	const ArrayRef pool = ai::static_array(state, key::creature_dwelling_rules_script, key::_refugee_pool);
	if (state.array_size(pool) != 0) {
		return pool;
	}
	const DictRef town_units = state.new_dict();
	for (const Value &building : gd::field_items(state, gd::content_file(state, key::buildings_path), str(key::items))) {
		if (gd::is_dict(building) && !gd::bool_field(state, building.ref, key::retired_from_town_tree, false)) {
			state.set(town_units, str(ai::string_or_empty(state, building.ref, key::unlock_unit_id)), bool_value(true));
		}
	}
	for (const Value &unit : gd::field_items(state, gd::content_file(state, key::units_path), str(key::items))) {
		if (!gd::is_dict(unit)) {
			continue;
		}
		const Atom unit_id = ai::string_or_empty(state, unit.ref, key::id);
		const bool neutral = ai::string_or_empty(state, unit.ref, key::faction_id) == key::empty;
		if (unit_id == key::empty || base_unit_id(state, unit_id) != unit_id) {
			continue;
		}
		if (neutral || state.has(town_units, str(unit_id))) {
			state.append(pool, str(unit_id));
		}
	}
	// Array.sort() of Strings only.
	gd::sort_custom(state, pool, [&state](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
	return pool;
}

Atom base_unit_id(State &state, Atom unit_id) {
	const DictRef base_by_upgrade = ai::static_dict(state, key::creature_dwelling_rules_script, key::_base_by_upgrade);
	if (gd::is_empty(state, base_by_upgrade)) {
		for (const Value &unit : gd::field_items(state, gd::content_file(state, key::units_path), str(key::items))) {
			if (gd::is_dict(unit) && ai::string_or_empty(state, unit.ref, key::upgrade_to) != key::empty) {
				state.set(base_by_upgrade, str(ai::string_or_empty(state, unit.ref, key::upgrade_to)), str(ai::string_or_empty(state, unit.ref, key::id)));
			}
		}
		state.set(base_by_upgrade, str(key::k__loaded__), str(key::empty));
	}
	return gd::stringify(state, state.get(base_by_upgrade, str(unit_id), str(unit_id)));
}

Atom guard_unit(State &state, DictRef node, DictRef site, int64_t day) {
	if (is_refugee_camp(state, site)) {
		return key::empty;
	}
	Atom best = key::empty;
	for (const Value &unit_id : gd::items(state, array_value(creatures(state, node, site, day)))) {
		const int64_t tier = unit_tier(state, gd::to_string(unit_id));
		if (tier >= 5 && (best == key::empty || tier > unit_tier(state, best))) {
			best = gd::to_string(unit_id);
		}
	}
	return best;
}

bool is_guarded(State &state, DictRef node, DictRef site, int64_t day) {
	return guard_unit(state, node, site, day) != key::empty;
}

bool guard_beaten(State &state, DictRef node, Atom side) {
	Value beaten;
	if (!state.lookup(node, str(key::dwelling_guard_beaten), beaten)) {
		return false;
	}
	return gd::is_dict(beaten) && state.has(beaten.ref, str(side));
}

bool guard_blocks(State &state, DictRef node, DictRef site, Atom side, int64_t day) {
	return is_guarded(state, node, site, day) && !guard_beaten(state, node, side) && state.array_size(guard_stacks(state, node, site, side, day)) != 0;
}

ArrayRef full_guard(State &state, DictRef node, DictRef site, int64_t day) {
	const Atom unit_id = guard_unit(state, node, site, day);
	if (unit_id == key::empty) {
		return state.new_array();
	}
	const int64_t growth = gd::int_field(state, weekly_growth(state, node, site, day), unit_id, 1);
	const DictRef stack = state.new_dict();
	state.set(stack, str(key::unit_id), str(unit_id));
	state.set(stack, str(key::count), int_value(gd::mul(3, growth > 1 ? growth : 1)));
	const ArrayRef result = state.new_array();
	state.append(result, dict_value(stack));
	return result;
}

ArrayRef guard_stacks(State &state, DictRef node, DictRef site, Atom side, int64_t day) {
	if (!is_guarded(state, node, site, day) || guard_beaten(state, node, side)) {
		return state.new_array();
	}
	Value survivors;
	if (state.lookup(node, str(key::dwelling_guard_survivors), survivors) && gd::is_dict(survivors) && state.has(survivors.ref, str(side))) {
		const Value record = gd::index(state, survivors.ref, str(side));
		if (gd::is_dict(record) && gd::int_field(state, record.ref, key::week, -1) == week_index(state, day)) {
			Value stacks;
			if (!state.lookup(record.ref, str(key::stacks), stacks)) {
				return state.new_array();
			}
			if (gd::is_array(stacks)) {
				return gd::deep_duplicate_array(state, stacks.ref);
			}
		}
	}
	return full_guard(state, node, site, day);
}

int64_t week_value(State &state, DictRef node, DictRef site, int64_t day, bool available_only) {
	if (!ai::static_bool(state, key::creature_dwelling_rules_script, key::_ai_weights_ready)) {
		apply_ai_weights(state, content_service::default_ai_hero_weights(state));
	}
	int64_t value = 0;
	const DictRef counts = available_only ? population(state, node, site, day) : weekly_growth(state, node, site, day);
	for (const Value &unit_id : gd::items(state, dict_value(counts))) {
		const DictRef unit = gd::content_row(state, ContentTable::Unit, gd::stringify(state, unit_id));
		int64_t price = 0;
		Value cost;
		if (state.lookup(unit, str(key::cost), cost) && gd::is_dict(cost)) {
			price = gd::int_field(state, cost.ref, key::gold, 0);
		}
		const int64_t count = gd::to_int(state, gd::index(state, counts, unit_id));
		const int64_t least = ai::static_int(state, key::creature_dwelling_rules_script, key::AI_CREATURE_MIN_VALUE);
		value = gd::add(value, gd::mul(count, least < price ? price : least));
	}
	return value;
}

int64_t _stable_roll(State &state, Atom text_key, int64_t size) {
	if (size <= 0) {
		return 0;
	}
	const int64_t mask = int64_t{0xffffffff};
	int64_t hash_value = int64_t{2166136261};
	for (const char byte : state.text(text_key)) {
		hash_value = gd::mul(hash_value ^ static_cast<int64_t>(static_cast<unsigned char>(byte)), int64_t{16777619}) & mask;
	}
	hash_value ^= hash_value >> 16;
	hash_value = gd::mul(hash_value, int64_t{0x85ebca6b}) & mask;
	hash_value ^= hash_value >> 13;
	hash_value = gd::mul(hash_value, int64_t{0xc2b2ae35}) & mask;
	hash_value ^= hash_value >> 16;
	return compat::int_mod(hash_value, size);
}

void apply_ai_weights(State &state, DictRef weights) {
	ai::assign_int(state, key::creature_dwelling_rules_script, key::AI_CREATURE_MIN_VALUE, weights, key::dwelling_creature_min_value);
	gd::set_static_var(state, key::creature_dwelling_rules_script, key::_ai_weights_ready, bool_value(true));
}

} // namespace creature_dwelling_rules

} // namespace aurelion::rules::port
