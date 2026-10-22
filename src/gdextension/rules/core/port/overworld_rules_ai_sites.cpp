// OverworldRules: a map object's interaction tiles, a resource site's response and
// delivery states, its delivery line, its town support and its family's short label.

#include "aurelion_rules/port/overworld_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/enemy_adventure_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <string>
#include <vector>

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
using overworld_rules::Vector2i;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

constexpr Atom kScript = key::overworld_rules_script;
constexpr Atom kAdventureScript = key::enemy_adventure_rules_script;

// max(0, value) of ints.
int64_t max0(int64_t value) {
	return compat::engine_max<int64_t>(0, value);
}

// max(a, b) of two ints (untyped: a, unless it is less than b).
int64_t vmax(int64_t a, int64_t b) {
	return a < b ? b : a;
}

// d.get(key, {}) / d.get(key, []) where the result is passed on: the value, or a new container.
Value dict_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

Value array_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
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

// {"gold": 0, "wood": 0, "ore": 0}.
DictRef blank_resource_cost(State &state) {
	const DictRef cost = state.new_dict();
	state.set(cost, str(key::gold), int_value(0));
	state.set(cost, str(key::wood), int_value(0));
	state.set(cost, str(key::ore), int_value(0));
	return cost;
}

// OverworldRules._rules_profile_timer, _rules_profile_set and _rules_profile_add_ms.
bool rules_profile_active(State &state) {
	return ai::static_bool(state, kScript, key::_movement_rules_profile_active);
}

int64_t rules_profile_timer(State &state) {
	return rules_profile_active(state) ? gd::ticks_usec() : 0;
}

void rules_profile_set(State &state, Atom section, Atom name, const Value &value) {
	if (!rules_profile_active(state) || section == key::empty || name == key::empty) {
		return;
	}
	const DictRef profile = ai::static_dict(state, kScript, key::_movement_rules_profile);
	Value found;
	const DictRef target = state.lookup(profile, str(section), found) && gd::is_dict(found) ? found.ref : state.new_dict();
	state.set(target, str(name), value);
	state.set(profile, str(section), dict_value(target));
}

void rules_profile_add_ms(State &state, Atom bucket, int64_t started_usec) {
	if (!rules_profile_active(state) || started_usec <= 0 || bucket == key::empty) {
		return;
	}
	const DictRef profile = ai::static_dict(state, kScript, key::_movement_rules_profile);
	const DictRef buckets = gd::as_dict(dict_or_new(state, profile, key::sub_buckets_ms));
	const double before = gd::to_float(state.get(buckets, str(bucket), gd::float_value(0.0)));
	const double elapsed = static_cast<double>(compat::engine_max<int64_t>(0, gd::sub(gd::ticks_usec(), started_usec)));
	state.set(buckets, str(bucket), gd::float_value(compat::snappedf(before + elapsed / 1000.0, 0.001)));
	state.set(profile, str(key::sub_buckets_ms), dict_value(buckets));
}

// _pathing_debug_profile[counter] = int(_pathing_debug_profile.get(counter, 0)) + 1.
void count_pathing(State &state, Atom counter) {
	const DictRef profile = ai::static_dict(state, kScript, key::_pathing_debug_profile);
	state.set(profile, str(counter), int_value(gd::add(gd::int_field(state, profile, counter, 0), 1)));
}

// {"index": ..., "town"/"encounter": ...} of the placement lookups (index -1: not found).
struct Found {
	int64_t index = -1;
	Value item;
};

// OverworldRules._find_town_by_placement (a session is never null here).
Found find_town_by_placement(State &state, DictRef session, Atom placement_id) {
	if (placement_id == key::empty) {
		return {};
	}
	const Value towns = array_or_new(state, session_view::overworld(state, session), key::towns);
	const Atom session_id = gd::stringify(state, gd::index(state, session, str(key::session_id)));
	const DictRef flags = gd::as_dict(gd::index(state, session, str(key::flags)));
	if (ai::string_or_empty(state, flags, key::active_town_placement_id) == placement_id && state.has(ai::static_dict(state, kScript, key::_active_town_visit_indexes), str(session_id))) {
		const int64_t direct_index = gd::to_int(state, state.get(ai::static_dict(state, kScript, key::_active_town_visit_indexes), str(session_id), int_value(-1)));
		if (gd::is_array(towns) && direct_index >= 0 && direct_index < state.array_size(towns.ref)) {
			const Value direct_town = state.at(towns.ref, direct_index);
			if (gd::is_dict(direct_town) && ai::string_or_empty(state, direct_town.ref, key::placement_id) == placement_id) {
				count_pathing(state, key::town_placement_lookup_direct_index_count);
				return {direct_index, direct_town};
			}
		}
	}
	const DictRef lookup_index = overworld_rules::_spatial_lookup_index(state, session);
	Value town_by_placement;
	if (state.lookup(lookup_index, str(key::town_by_placement), town_by_placement) && gd::is_dict(town_by_placement) && state.has(town_by_placement.ref, str(placement_id))) {
		const int64_t placement_index = gd::to_int(state, state.get(town_by_placement.ref, str(placement_id), int_value(-1)));
		if (gd::is_array(towns) && placement_index >= 0 && placement_index < state.array_size(towns.ref)) {
			const Value indexed_town = state.at(towns.ref, placement_index);
			if (gd::is_dict(indexed_town) && ai::string_or_empty(state, indexed_town.ref, key::placement_id) == placement_id) {
				count_pathing(state, key::town_placement_lookup_spatial_index_count);
				return {placement_index, indexed_town};
			}
		}
	}
	count_pathing(state, key::town_placement_lookup_full_scan_count);
	const int64_t count = ai::vsize(state, towns);
	for (int64_t index = 0; index < count; ++index) {
		const Value town = ai::vindex(state, towns, int_value(index));
		if (gd::is_dict(town) && ai::string_or_empty(state, town.ref, key::placement_id) == placement_id) {
			if (ai::string_or_empty(state, flags, key::active_town_placement_id) == placement_id) {
				state.set(ai::static_dict(state, kScript, key::_active_town_visit_indexes), str(session_id), int_value(index));
			}
			return {index, town};
		}
	}
	return {};
}

// OverworldRules._find_encounter_by_placement (a session is never null here).
Found find_encounter_by_placement(State &state, DictRef session, Atom placement_id) {
	if (placement_id == key::empty) {
		return {};
	}
	const int64_t lookup_started_usec = rules_profile_timer(state);
	const Value encounters = array_or_new(state, session_view::overworld(state, session), key::encounters);
	rules_profile_set(state, key::descriptor, key::lookup_collection_size, int_value(gd::is_array(encounters) ? state.array_size(encounters.ref) : 0));
	const DictRef lookup_index = overworld_rules::_spatial_lookup_index(state, session);
	Value by_placement;
	if (state.lookup(lookup_index, str(key::encounter_by_placement), by_placement) && gd::is_dict(by_placement) && state.has(by_placement.ref, str(placement_id))) {
		const int64_t indexed = gd::to_int(state, state.get(by_placement.ref, str(placement_id), int_value(-1)));
		if (gd::is_array(encounters) && indexed >= 0 && indexed < state.array_size(encounters.ref)) {
			const Value indexed_encounter = state.at(encounters.ref, indexed);
			if (gd::is_dict(indexed_encounter)) {
				const Value id_fallback = state.get(indexed_encounter.ref, str(key::id), str(key::empty));
				if (gd::stringify(state, state.get(indexed_encounter.ref, str(key::placement_id), id_fallback)) == placement_id) {
					rules_profile_set(state, key::descriptor, key::lookup_mode, str(key::placement_index));
					rules_profile_add_ms(state, key::descriptor_lookup_ms, lookup_started_usec);
					return {indexed, indexed_encounter};
				}
			}
		}
	}
	rules_profile_set(state, key::descriptor, key::lookup_mode, str(key::full_scan_fallback));
	const int64_t count = ai::vsize(state, encounters);
	for (int64_t index = 0; index < count; ++index) {
		const Value encounter = ai::vindex(state, encounters, int_value(index));
		if (gd::is_dict(encounter) && ai::string_or_empty(state, encounter.ref, key::placement_id) == placement_id) {
			rules_profile_add_ms(state, key::descriptor_lookup_ms, lookup_started_usec);
			return {index, encounter};
		}
	}
	rules_profile_add_ms(state, key::descriptor_lookup_ms, lookup_started_usec);
	return {};
}

// HeroCommandRules.active_hero (a session is never null here).
DictRef active_hero(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	const Atom active_hero_id = ai::string_or_empty(state, overworld, key::active_hero_id);
	for (const Value &hero : gd::field_items(state, overworld, str(key::player_heroes))) {
		if (gd::is_dict(hero) && ai::string_or_empty(state, hero.ref, key::id) == active_hero_id) {
			return hero.ref;
		}
	}
	return state.new_dict();
}

// OverworldRules._resource_site_delivery_target_label (a session is never null here).
Atom delivery_target_label(State &state, DictRef session, Atom target_kind, Atom target_id, Atom fallback_label) {
	if (target_kind == key::hero) {
		const DictRef hero = hero_command_rules::hero_by_id(state, session, target_id);
		if (!gd::is_empty(state, hero)) {
			return gd::stringify(state, state.get(hero, str(key::name), str(target_id)));
		}
	} else if (target_kind == key::town) {
		const Found town_result = find_town_by_placement(state, session, target_id);
		if (town_result.index >= 0) {
			return overworld_rules::_town_name(state, gd::as_dict(town_result.item));
		}
	} else if (target_kind == key::raid) {
		const Found encounter_result = find_encounter_by_placement(state, session, target_id);
		if (encounter_result.index >= 0) {
			const DictRef encounter = gd::as_dict(encounter_result.item);
			const Value placement_fallback = state.get(encounter, str(key::placement_id), str(target_id));
			return gd::stringify(state, state.get(encounter, str(key::target_label), placement_fallback));
		}
	}
	if (fallback_label != key::empty) {
		return fallback_label;
	}
	if (target_kind == key::hero) {
		return key::frontline_hero;
	}
	if (target_kind == key::town) {
		return key::frontline_town;
	}
	if (target_kind == key::raid) {
		return key::enemy_army_2;
	}
	return key::frontline;
}

// EnemyAdventureRules._normalize_army_payload.
DictRef normalize_army_payload(State &state, const Value &army) {
	if (!gd::is_dict(army)) {
		return state.new_dict();
	}
	const ArrayRef normalized_stacks = state.new_array();
	for (const Value &stack_value : gd::field_items(state, army.ref, str(key::stacks))) {
		if (!gd::is_dict(stack_value)) {
			continue;
		}
		const Atom unit_id = ai::string_or_empty(state, stack_value.ref, key::unit_id);
		const int64_t count = max0(gd::int_field(state, stack_value.ref, key::count, 0));
		if (unit_id == key::empty || count <= 0) {
			continue;
		}
		const DictRef stack = state.new_dict();
		state.set(stack, str(key::unit_id), str(unit_id));
		state.set(stack, str(key::count), int_value(count));
		state.append(normalized_stacks, dict_value(stack));
	}
	if (state.array_size(normalized_stacks) == 0) {
		return state.new_dict();
	}
	const Atom army_id = ai::string_or_empty(state, army.ref, key::id);
	const Atom army_name = gd::stringify(state, state.get(army.ref, str(key::name), str(key::raid_host)));
	const DictRef normalized = state.new_dict();
	state.set(normalized, str(key::id), str(army_id));
	state.set(normalized, str(key::name), str(army_name));
	state.set(normalized, str(key::stacks), array_value(normalized_stacks));
	return normalized;
}

// EnemyAdventureRules._base_enemy_army.
DictRef base_enemy_army(State &state, Atom encounter_id) {
	const DictRef encounter = gd::content_row(state, ContentTable::Encounter, encounter_id);
	if (gd::is_empty(state, encounter)) {
		return state.new_dict();
	}
	const DictRef group = gd::content_row(state, ContentTable::ArmyGroup, ai::string_or_empty(state, encounter, key::enemy_group_id));
	return normalize_army_payload(state, dict_value(group));
}

// EnemyAdventureRules._unit_strength_value.
int64_t unit_strength_value(State &state, Atom unit_id) {
	const Value strength = state.get(ai::static_dict(state, kAdventureScript, key::_unit_strength_memo), str(unit_id), Value());
	if (strength.kind != Kind::Nil) {
		return gd::to_int(state, strength);
	}
	const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
	int64_t sum = gd::int_field(state, unit, key::hp, 1);
	sum = gd::add(sum, gd::int_field(state, unit, key::min_damage, 1));
	sum = gd::add(sum, gd::int_field(state, unit, key::max_damage, 1));
	sum = gd::add(sum, gd::bool_field(state, unit, key::ranged, false) ? 3 : 0);
	const int64_t made = vmax(6, sum);
	state.set(ai::static_dict(state, kAdventureScript, key::_unit_strength_memo), str(unit_id), int_value(made));
	return made;
}

// EnemyAdventureRules._army_strength.
int64_t army_strength(State &state, const Value &stacks) {
	int64_t total = 0;
	if (!gd::is_array(stacks)) {
		return total;
	}
	enemy_adventure_rules::_sync_unit_strength_memo(state);
	for (const Value &stack_value : gd::items(state, stacks)) {
		if (!gd::is_dict(stack_value)) {
			continue;
		}
		const Atom unit_id = ai::string_or_empty(state, stack_value.ref, key::unit_id);
		const int64_t count = max0(gd::int_field(state, stack_value.ref, key::count, 0));
		if (unit_id == key::empty || count <= 0) {
			continue;
		}
		total = gd::add(total, gd::mul(unit_strength_value(state, unit_id), count));
	}
	return total;
}

// String(encounter.get("encounter_id", encounter.get("id", ""))).
Atom encounter_template_id(State &state, DictRef encounter) {
	const Value id_fallback = state.get(encounter, str(key::id), str(key::empty));
	return gd::stringify(state, state.get(encounter, str(key::encounter_id), id_fallback));
}

// EnemyAdventureRules.raid_strength.
int64_t raid_strength(State &state, DictRef encounter) {
	DictRef normalized_army = normalize_army_payload(state, dict_or_new(state, encounter, key::enemy_army));
	if (gd::is_empty(state, normalized_army)) {
		normalized_army = base_enemy_army(state, encounter_template_id(state, encounter));
	}
	return army_strength(state, array_or_new(state, normalized_army, key::stacks));
}

// EnemyAdventureRules._commander_name_from_source.
Atom commander_name_from_source(State &state, const Value &source) {
	if (!gd::is_dict(source)) {
		return key::empty;
	}
	Value commander_state;
	if (state.lookup(source.ref, str(key::commander_state), commander_state) && gd::is_dict(commander_state) && ai::string_or_empty(state, commander_state.ref, key::name) != key::empty) {
		return ai::string_or_empty(state, commander_state.ref, key::name);
	}
	if (ai::string_or_empty(state, source.ref, key::name) != key::empty) {
		return ai::string_or_empty(state, source.ref, key::name);
	}
	if (ai::string_or_empty(state, source.ref, key::roster_hero_id) != key::empty) {
		const DictRef hero = gd::content_row(state, ContentTable::Hero, ai::string_or_empty(state, source.ref, key::roster_hero_id));
		return ai::string_or_empty(state, hero, key::name);
	}
	return key::empty;
}

// EnemyAdventureRules._commander_veterancy_rank_from_record(_normalized_commander_record(source)):
// the record's commander_state is the default {}, so its fields read 0 and "".
int64_t commander_veterancy_rank(State &state, const Value &source) {
	const DictRef entry = gd::is_dict(source) ? source.ref : state.new_dict();
	const int64_t deployments = max0(vmax(gd::int_field(state, entry, key::deployments, 0), 0));
	const int64_t battle_wins = max0(vmax(gd::int_field(state, entry, key::battle_wins, 0), 0));
	const int64_t times_defeated = max0(vmax(gd::int_field(state, entry, key::times_defeated, 0), 0));
	const int64_t strategic_successes = max0(vmax(gd::int_field(state, entry, key::strategic_successes, 0), 0));
	(void)ai::string_or_empty(state, entry, key::last_outcome);
	const int64_t half_successes = compat::float_to_int(compat::godot_floor(static_cast<double>(strategic_successes) / 2.0));
	const int64_t renown = compat::engine_clamp<int64_t>(gd::sub(gd::add(gd::add(deployments, gd::mul(battle_wins, 2)), half_successes), times_defeated), 0, 9);
	if (battle_wins >= 3 || renown >= 8) {
		return 3;
	}
	if (battle_wins >= 2 || renown >= 5) {
		return 2;
	}
	if (battle_wins >= 1 || deployments >= 2 || renown >= 2) {
		return 1;
	}
	return 0;
}

// EnemyAdventureRules.commander_veterancy_label: COMMANDER_VETERANCY_LABELS[clamp(rank, 0, 3)].
Atom commander_veterancy_label(State &state, const Value &source) {
	switch (compat::engine_clamp<int64_t>(commander_veterancy_rank(state, source), 0, 3)) {
		case 1:
			return key::blooded;
		case 2:
			return key::veteran_label;
		case 3:
			return key::war_hardened;
		default:
			return key::empty;
	}
}

// EnemyAdventureRules.commander_display_name(source) (include_veterancy true).
Atom commander_display_name(State &state, const Value &source) {
	const Atom commander_name = commander_name_from_source(state, source);
	if (commander_name == key::empty) {
		return key::empty;
	}
	const Atom veterancy = commander_veterancy_label(state, source);
	if (veterancy != key::empty) {
		return gd::format(state, key::s_s, {str(veterancy), str(commander_name)});
	}
	return commander_name;
}

// EnemyAdventureRules.raid_commander_name.
Atom raid_commander_name(State &state, DictRef encounter) {
	if (gd::is_empty(state, encounter)) {
		return key::empty;
	}
	Value commander_state;
	if (state.lookup(encounter, str(key::enemy_commander_state), commander_state) && gd::is_dict(commander_state)) {
		const Atom commander_name = ai::string_or_empty(state, commander_state.ref, key::name);
		if (commander_name != key::empty) {
			return commander_name;
		}
	}
	const DictRef encounter_template = gd::content_row(state, ContentTable::Encounter, encounter_template_id(state, encounter));
	Value enemy_commander;
	if (!state.lookup(encounter_template, str(key::enemy_commander), enemy_commander)) {
		return key::empty;
	}
	return gd::stringify(state, ai::vget(state, enemy_commander, key::name, str(key::empty)));
}

// EnemyAdventureRules.raid_commander_display_name.
Atom raid_commander_display_name(State &state, DictRef encounter) {
	if (gd::is_empty(state, encounter)) {
		return key::empty;
	}
	Value commander_state;
	if (state.lookup(encounter, str(key::enemy_commander_state), commander_state) && gd::is_dict(commander_state) && !gd::is_empty(state, commander_state.ref)) {
		return commander_display_name(state, commander_state);
	}
	return raid_commander_name(state, encounter);
}

// EnemyAdventureRules.raid_display_name.
Atom raid_display_name(State &state, DictRef encounter) {
	if (gd::is_empty(state, encounter)) {
		return key::hostile_contact;
	}
	Value ai_hero;
	if (state.lookup(encounter, str(key::ai_hero), ai_hero) && gd::is_dict(ai_hero)) {
		const Atom hero_name = raid_commander_name(state, encounter);
		if (hero_name != key::empty) {
			return hero_name;
		}
	}
	const DictRef encounter_template = gd::content_row(state, ContentTable::Encounter, encounter_template_id(state, encounter));
	const Value name_fallback = state.get(encounter, str(key::placement_id), str(key::enemy_army_3));
	const Atom encounter_name = gd::stringify(state, state.get(encounter_template, str(key::name), name_fallback));
	const Atom commander_name = raid_commander_display_name(state, encounter);
	if (commander_name == key::empty || player_identity_rules::raid_controller_id(state, encounter) == key::empty) {
		return encounter_name;
	}
	return gd::format(state, key::s_s_s, {str(commander_name), str(encounter_name)});
}

// OverworldRules.encounter_display_name.
Atom encounter_display_name(State &state, DictRef encounter) {
	if (gd::is_empty(state, encounter)) {
		return key::hostile_contact;
	}
	if (ai::string_or_empty(state, encounter, key::spawned_by_faction_id) != key::empty) {
		const Atom raid_name = raid_display_name(state, encounter);
		if (raid_name != key::empty) {
			return raid_name;
		}
	}
	const DictRef encounter_def = gd::content_row(state, ContentTable::Encounter, encounter_template_id(state, encounter));
	const Value name_fallback = state.get(encounter, str(key::placement_id), str(key::hostile_contact));
	return gd::stringify(state, state.get(encounter_def, str(key::name), name_fallback));
}

// OverworldRules._resource_site_delivery_interception (a session is never null here).
DictRef delivery_interception(State &state, DictRef session, DictRef node, DictRef site) {
	const DictRef empty_state = state.new_dict();
	state.set(empty_state, str(key::active), bool_value(false));
	state.set(empty_state, str(key::arrived), bool_value(false));
	state.set(empty_state, str(key::blocks_delivery), bool_value(false));
	state.set(empty_state, str(key::goal_distance), int_value(9999));
	state.set(empty_state, str(key::strength), int_value(0));
	state.set(empty_state, str(key::encounter_key), str(key::empty));
	state.set(empty_state, str(key::encounter_name), str(key::empty));
	state.set(empty_state, str(key::summary), str(key::empty));
	if (gd::is_empty(state, node)) {
		return empty_state;
	}
	const DictRef delivery_state = overworld_rules::_resource_site_delivery_state(state, session, node, site);
	if (!gd::bool_field(state, delivery_state, key::active, false) || ai::string_or_empty(state, delivery_state, key::controller_id) != key::player) {
		return empty_state;
	}
	const DictRef overworld = session_view::overworld(state, session);
	const Value resolved_encounters = array_or_new(state, overworld, key::resolved_encounters);
	DictRef best = gd::deep_duplicate_dict(state, empty_state);
	for (const Value &encounter : gd::field_items(state, overworld, str(key::encounters))) {
		if (!gd::is_dict(encounter)) {
			continue;
		}
		if (ai::string_or_empty(state, encounter.ref, key::spawned_by_faction_id) == key::empty) {
			continue;
		}
		if (gd::is_array(resolved_encounters) && gd::array_has(state, resolved_encounters.ref, str(overworld_rules::encounter_key(state, encounter.ref)))) {
			continue;
		}
		if (!overworld_rules::_delivery_encounter_matches_node(state, session, encounter.ref, node, delivery_state)) {
			continue;
		}
		const int64_t goal_distance = max0(gd::int_field(state, encounter.ref, key::goal_distance, 9999));
		const bool arrived = gd::bool_field(state, encounter.ref, key::arrived, false) || goal_distance <= 0;
		const int64_t strength = raid_strength(state, encounter.ref);
		if (gd::bool_field(state, best, key::active, false)) {
			const bool best_arrived = gd::bool_field(state, best, key::arrived, false);
			const int64_t best_distance = gd::int_field(state, best, key::goal_distance, 9999);
			const int64_t best_strength = gd::int_field(state, best, key::strength, 0);
			if (arrived == best_arrived) {
				if (goal_distance == best_distance && strength <= best_strength) {
					continue;
				}
				if (goal_distance > best_distance) {
					continue;
				}
			} else if (!arrived) {
				continue;
			}
		}
		const Atom encounter_key = overworld_rules::encounter_key(state, encounter.ref);
		const Atom encounter_name = encounter_display_name(state, encounter.ref);
		best = state.new_dict();
		state.set(best, str(key::active), bool_value(true));
		state.set(best, str(key::arrived), bool_value(arrived));
		state.set(best, str(key::blocks_delivery), bool_value(arrived));
		state.set(best, str(key::goal_distance), int_value(goal_distance));
		state.set(best, str(key::strength), int_value(strength));
		state.set(best, str(key::encounter_key), str(encounter_key));
		state.set(best, str(key::encounter_name), str(encounter_name));
		state.set(best, str(key::summary), str(key::empty));
	}
	const Atom encounter_name = gd::stringify(state, state.get(best, str(key::encounter_name), str(key::enemy_army_3)));
	const Atom target_label = gd::stringify(state, state.get(delivery_state, str(key::target_label), str(key::the_front)));
	if (gd::bool_field(state, best, key::active, false)) {
		if (gd::bool_field(state, best, key::blocks_delivery, false)) {
			state.set(best, str(key::summary), str(gd::format(state, key::s_is_contesting_s, {str(encounter_name), str(target_label)})));
		} else {
			const int64_t distance = gd::int_field(state, best, key::goal_distance, 0);
			const Atom plural = gd::int_field(state, best, key::goal_distance, 0) == 1 ? key::empty : key::s;
			state.set(best, str(key::summary), str(gd::format(state, key::s_closes_on_s_in_d, {str(encounter_name), str(target_label), int_value(distance), str(plural)})));
		}
	}
	return best;
}

} // namespace

namespace overworld_rules {

ArrayRef _map_object_world_interaction_tiles(State &state, DictRef map_object, DictRef placement) {
	const ArrayRef tiles = state.new_array();
	const Vector2i origin = _map_object_footprint_origin(state, map_object, placement);
	Value approach;
	Value offsets;
	if (state.lookup(map_object, str(key::approach), approach) && gd::is_dict(approach) && state.lookup(approach.ref, str(key::visit_offsets), offsets) && gd::is_array(offsets) && state.array_size(offsets.ref) > 0) {
		for (const Value &offset_value : gd::items(state, offsets)) {
			if (!gd::is_dict(offset_value)) {
				continue;
			}
			const int64_t x = gd::int_field(state, offset_value.ref, key::x, 0);
			const int64_t y = gd::int_field(state, offset_value.ref, key::y, 0);
			const Vector2i tile = origin + Vector2i::of(x, y);
			state.append(tiles, Value::of_vector2i(tile.x, tile.y));
		}
		return tiles;
	}
	const int64_t x = gd::int_field(state, placement, key::x, 0);
	const int64_t y = gd::int_field(state, placement, key::y, 0);
	const Vector2i tile = Vector2i::of(x, y);
	const ArrayRef single = state.new_array();
	state.append(single, Value::of_vector2i(tile.x, tile.y));
	return single;
}

DictRef _resource_site_response_state(State &state, DictRef session, DictRef node, DictRef site) {
	const DictRef profile = _resource_site_response_profile(state, site);
	bool active = false;
	int64_t remaining_days = 0;
	const Atom commander_id = ai::string_or_empty(state, node, key::response_commander_id);
	Atom commander_name = key::empty;
	int64_t security_rating = max0(gd::int_field(state, node, key::response_security_rating, 0));
	if (ai::string_or_empty(state, node, key::collected_by_faction_id) == key::player) {
		const int64_t response_until_day = max0(gd::int_field(state, node, key::response_until_day, 0));
		active = response_until_day >= ai::session_int(state, session, key::day) && gd::int_field(state, profile, key::watch_days, 0) > 0;
		if (active) {
			remaining_days = vmax(1, gd::add(gd::sub(response_until_day, ai::session_int(state, session, key::day)), 1));
		}
		if (commander_id != key::empty) {
			commander_name = ai::string_or_empty(state, hero_command_rules::hero_by_id(state, session, commander_id), key::name);
		}
		if (security_rating <= 0) {
			const DictRef preview_hero = active_hero(state, session);
			security_rating = _route_security_rating_for_hero(state, preview_hero);
			if (commander_name == key::empty) {
				commander_name = ai::string_or_empty(state, preview_hero, key::name);
			}
		}
	}
	if (active && security_rating <= 0) {
		security_rating = 1;
	}
	const int64_t pressure_guard_bonus = gd::add(max0(gd::int_field(state, profile, key::pressure_guard_bonus, 0)), max0(gd::sub(security_rating, 1)));
	int64_t growth_bonus_percent = max0(gd::int_field(state, profile, key::growth_bonus_percent, 0));
	if (growth_bonus_percent > 0) {
		growth_bonus_percent = gd::add(growth_bonus_percent, gd::mul(max0(gd::sub(security_rating, 1)), 3));
	}
	const int64_t break_pressure = gd::add(max0(gd::int_field(state, profile, key::break_pressure, 0)), max0(gd::sub(security_rating, 1)));
	const DictRef result = state.new_dict();
	state.set(result, str(key::active), bool_value(active));
	state.set(result, str(key::remaining_days), int_value(remaining_days));
	state.set(result, str(key::origin), str(ai::string_or_empty(state, node, key::response_origin)));
	state.set(result, str(key::source_town_id), str(ai::string_or_empty(state, node, key::response_source_town_id)));
	state.set(result, str(key::commander_id), str(commander_id));
	state.set(result, str(key::commander_name), str(commander_name));
	state.set(result, str(key::security_rating), int_value(security_rating));
	state.set(result, str(key::action_label), str(ai::string_or_empty(state, profile, key::action_label)));
	state.set(result, str(key::summary), str(ai::string_or_empty(state, profile, key::summary)));
	state.set(result, str(key::movement_cost), int_value(gd::int_field(state, profile, key::movement_cost, 0)));
	Value resource_cost;
	if (!state.lookup(profile, str(key::resource_cost), resource_cost)) {
		resource_cost = dict_value(blank_resource_cost(state));
	}
	state.set(result, str(key::resource_cost), resource_cost);
	state.set(result, str(key::watch_days), int_value(gd::int_field(state, profile, key::watch_days, 0)));
	state.set(result, str(key::quality_bonus), int_value(gd::int_field(state, profile, key::quality_bonus, 0)));
	state.set(result, str(key::readiness_bonus), int_value(gd::int_field(state, profile, key::readiness_bonus, 0)));
	state.set(result, str(key::pressure_bonus), int_value(gd::int_field(state, profile, key::pressure_bonus, 0)));
	state.set(result, str(key::recovery_relief), int_value(gd::int_field(state, profile, key::recovery_relief, 0)));
	state.set(result, str(key::pressure_guard_bonus), int_value(pressure_guard_bonus));
	state.set(result, str(key::growth_bonus_percent), int_value(growth_bonus_percent));
	state.set(result, str(key::break_pressure), int_value(break_pressure));
	return result;
}

DictRef _resource_site_delivery_state(State &state, DictRef session, DictRef node, DictRef _site) {
	(void)_site;
	const DictRef manifest = _normalize_recruit_payload(state, dict_or_new(state, node, key::delivery_manifest));
	const Atom controller_id = ai::string_or_empty(state, node, key::delivery_controller_id);
	const int64_t arrival_day = max0(gd::int_field(state, node, key::delivery_arrival_day, 0));
	const Atom target_kind = ai::string_or_empty(state, node, key::delivery_target_kind);
	const Atom target_id = ai::string_or_empty(state, node, key::delivery_target_id);
	const Atom fallback_label = ai::string_or_empty(state, node, key::delivery_target_label);
	const Atom target_label = delivery_target_label(state, session, target_kind, target_id, fallback_label);
	const Atom source_town_id = ai::string_or_empty(state, node, key::delivery_origin_town_id);
	Atom source_town_label = key::empty;
	if (source_town_id != key::empty) {
		const Found source_town_result = find_town_by_placement(state, session, source_town_id);
		if (source_town_result.index >= 0) {
			source_town_label = _town_name(state, gd::as_dict(source_town_result.item));
		}
	}
	bool active = false;
	int64_t days_remaining = 0;
	if (controller_id != key::empty && !gd::is_empty(state, manifest) && arrival_day > 0) {
		active = player_identity_rules::resource_controller_id(state, node) == controller_id;
		if (active) {
			days_remaining = max0(gd::sub(arrival_day, ai::session_int(state, session, key::day)));
			if (days_remaining > 0) {
				days_remaining = vmax(1, days_remaining);
			}
		}
	}
	const Atom recruit_summary = _describe_recruit_delta(state, dict_value(manifest));
	const int64_t manifest_value = _weighted_recruit_value(state, dict_value(manifest));
	const DictRef result = state.new_dict();
	state.set(result, str(key::active), bool_value(active));
	state.set(result, str(key::controller_id), str(controller_id));
	state.set(result, str(key::origin_town_id), str(source_town_id));
	state.set(result, str(key::origin_town_label), str(source_town_label));
	state.set(result, str(key::target_kind), str(target_kind));
	state.set(result, str(key::target_id), str(target_id));
	state.set(result, str(key::target_label), str(target_label));
	state.set(result, str(key::arrival_day), int_value(arrival_day));
	state.set(result, str(key::days_remaining), int_value(days_remaining));
	state.set(result, str(key::manifest), dict_value(manifest));
	state.set(result, str(key::recruit_summary), str(recruit_summary));
	state.set(result, str(key::manifest_value), int_value(manifest_value));
	return result;
}

Atom _resource_site_delivery_line(State &state, DictRef session, DictRef node, DictRef site) {
	const DictRef delivery_state = _resource_site_delivery_state(state, session, node, site);
	if (!gd::bool_field(state, delivery_state, key::active, false)) {
		return key::empty;
	}
	std::vector<Atom> parts;
	const Atom site_name = gd::stringify(state, state.get(site, str(key::name), str(key::frontier_route)));
	parts.push_back(gd::format(state, key::s_convoy, {str(site_name)}));
	const Atom target_label = gd::stringify(state, state.get(delivery_state, str(key::target_label), str(key::the_front)));
	parts.push_back(gd::format(state, key::to_s, {str(target_label)}));
	const Atom recruit_summary = ai::string_or_empty(state, delivery_state, key::recruit_summary);
	if (recruit_summary != key::empty) {
		parts.push_back(recruit_summary);
	}
	const int64_t days_remaining = gd::int_field(state, delivery_state, key::days_remaining, 0);
	if (days_remaining > 0) {
		parts.push_back(gd::format(state, key::d_day_s_out, {int_value(days_remaining), str(days_remaining == 1 ? key::empty : key::s)}));
	} else {
		const DictRef interception_state = delivery_interception(state, session, node, site);
		if (gd::bool_field(state, interception_state, key::blocks_delivery, false)) {
			parts.push_back(key::holding_under_interception);
		}
	}
	const DictRef interception = delivery_interception(state, session, node, site);
	if (gd::bool_field(state, interception, key::active, false)) {
		if (gd::bool_field(state, interception, key::blocks_delivery, false)) {
			const Atom encounter_name = gd::stringify(state, state.get(interception, str(key::encounter_name), str(key::enemy_army_3)));
			parts.push_back(gd::format(state, key::s_blocks_the_route, {str(encounter_name)}));
		} else {
			const Atom encounter_name = gd::stringify(state, state.get(interception, str(key::encounter_name), str(key::enemy_army_3)));
			const int64_t goal_distance = gd::int_field(state, interception, key::goal_distance, 0);
			const Atom plural = gd::int_field(state, interception, key::goal_distance, 0) == 1 ? key::empty : key::s;
			parts.push_back(gd::format(state, key::s_d_tile_s_out, {str(encounter_name), int_value(goal_distance), str(plural)}));
		}
	}
	return join_atoms(state, key::space_bar_space, parts);
}

DictRef _resource_site_town_support(State &state, DictRef site) {
	static constexpr Atom kFields[] = {
		key::quality_bonus,
		key::readiness_bonus,
		key::pressure_bonus,
		key::growth_bonus_percent,
		key::recovery_relief,
		key::disruption_pressure,
	};
	const DictRef support = state.new_dict();
	for (const Atom field : kFields) {
		state.set(support, str(field), int_value(0));
	}
	Value authored_support;
	if (state.lookup(site, str(key::town_support), authored_support) && gd::is_dict(authored_support) && !gd::is_empty(state, authored_support.ref)) {
		for (const Atom field : kFields) {
			const Value current = gd::index(state, support, str(field));
			state.set(support, str(field), int_value(max0(gd::to_int(state, state.get(authored_support.ref, str(field), current)))));
		}
		return support;
	}
	const Atom family = ai::string_or_empty(state, site, key::family);
	if (family == key::mine) {
		state.set(support, str(key::growth_bonus_percent), int_value(3));
		state.set(support, str(key::recovery_relief), int_value(1));
		state.set(support, str(key::disruption_pressure), int_value(1));
	} else if (family == key::neutral_dwelling) {
		// Dwellings grow towns by +1 per creature instead (_add_dwelling_town_growth).
	} else if (family == key::faction_outpost) {
		state.set(support, str(key::readiness_bonus), int_value(vmax(2, gd::mul(max0(gd::int_field(state, site, key::vision_radius, 0)), 2))));
		state.set(support, str(key::pressure_bonus), int_value(max0(gd::int_field(state, site, key::pressure_bonus, 0))));
		state.set(support, str(key::recovery_relief), int_value(1));
		state.set(support, str(key::disruption_pressure), int_value(1));
	} else if (family == key::frontier_shrine) {
		state.set(support, str(key::quality_bonus), int_value(2));
		state.set(support, str(key::pressure_bonus), int_value(1));
		state.set(support, str(key::growth_bonus_percent), int_value(6));
		state.set(support, str(key::recovery_relief), int_value(1));
		state.set(support, str(key::disruption_pressure), int_value(1));
	} else if (family == key::scouting_structure) {
		state.set(support, str(key::readiness_bonus), int_value(vmax(1, max0(gd::int_field(state, site, key::vision_radius, 0)))));
		state.set(support, str(key::pressure_bonus), int_value(1));
		state.set(support, str(key::disruption_pressure), int_value(1));
	} else if (family == key::transit_object) {
		state.set(support, str(key::readiness_bonus), int_value(1));
		state.set(support, str(key::recovery_relief), int_value(1));
		state.set(support, str(key::disruption_pressure), int_value(1));
	} else if (family == key::repeatable_service) {
		state.set(support, str(key::recovery_relief), int_value(1));
	}
	return support;
}

Atom _resource_site_family_short_label(State &state, Atom family_id) {
	(void)state;
	if (family_id == key::neutral_dwelling) {
		return key::dwelling;
	}
	if (family_id == key::faction_outpost) {
		return key::outpost;
	}
	if (family_id == key::frontier_shrine) {
		return key::shrine;
	}
	return family_id;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
