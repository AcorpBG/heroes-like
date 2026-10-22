// AiHeroRules, ArtifactRules, DifficultyRules, EnemyTownServices, HeroCommandRules, OverworldLevelRules,
// OverworldTurnPlayback, PlayerIdentityRules, SpellRules, TownDevelopmentRules and VisitBuildingRules: the
// paths of the computer players' day the six seeds do not run (Phase 4, slice 4.2).

#include "aurelion_rules/port/ai_hero_rules_turn.hpp"
#include "aurelion_rules/port/artifact_rules_turn.hpp"
#include "aurelion_rules/port/difficulty_rules_turn.hpp"
#include "aurelion_rules/port/enemy_town_services_turn.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/overworld_level_rules_turn.hpp"
#include "aurelion_rules/port/overworld_turn_playback_turn.hpp"
#include "aurelion_rules/port/player_identity_rules_turn.hpp"
#include "aurelion_rules/port/spell_rules_turn.hpp"
#include "aurelion_rules/port/town_development_rules_turn.hpp"
#include "aurelion_rules/port/visit_building_rules_turn.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/content_service_ai.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/turn_hosts.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_string.hpp"

#include <initializer_list>
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
using gd::float_value;
using gd::int_value;
using gd::str;
using overworld_rules::Vector2i;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;
namespace player_rules = player_identity_rules;

// d.get(field, {}) and d.get(field, []) where the value is kept or written: a
// new container when the key is missing.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}
Value get_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

// {"arrived": true}
DictRef arrived_result(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::arrived), bool_value(true));
	return result;
}

// session.overworld.encounters[index] as a Dictionary.
DictRef encounter_at(State &state, DictRef session, int64_t index) {
	const Value encounters = gd::index(state, session_view::overworld(state, session), str(key::encounters));
	return gd::as_dict(ai::vindex(state, encounters, int_value(index)));
}

// [{"unit_id": unit_id, "count": count}]
ArrayRef single_stack(State &state, Atom unit_id, int64_t count) {
	const DictRef stack = state.new_dict();
	state.set(stack, str(key::unit_id), str(unit_id));
	state.set(stack, str(key::count), int_value(count));
	const ArrayRef stacks = state.new_array();
	state.append(stacks, dict_value(stack));
	return stacks;
}

// {"ok": ok, "hero": hero}
DictRef hero_outcome(State &state, bool ok, DictRef hero) {
	const DictRef outcome = state.new_dict();
	state.set(outcome, str(key::ok), bool_value(ok));
	state.set(outcome, str(key::hero), dict_value(hero));
	return outcome;
}

// {"ok": ok, "message": message}
DictRef message_outcome(State &state, bool ok, Atom message) {
	const DictRef outcome = state.new_dict();
	state.set(outcome, str(key::ok), bool_value(ok));
	state.set(outcome, str(key::message), str(message));
	return outcome;
}

// x.values() of an untyped value: only a Dictionary has it.
DictRef values_target(const Value &target) {
	if (!gd::is_dict(target)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'values' in base '") + gd::type_name(target) + "'.");
	}
	return target.ref;
}

// ArtifactRules.EQUIPMENT_SLOTS.
bool is_equipment_slot(Atom slot) {
	return slot == key::boots || slot == key::banner || slot == key::armor || slot == key::trinket || slot == key::trinket_2;
}

} // namespace

// AiHeroRules.

namespace ai_hero_rules {

int64_t _nearest_hero_index(State &state, ArrayRef encounters, DictRef resolved, Atom controller, DictRef column, int64_t radius) {
	int64_t best = -1;
	int64_t best_distance = gd::add(radius, 1);
	const int64_t size = state.array_size(encounters);
	for (int64_t index = 0; index < size; ++index) {
		const Value entry = state.at(encounters, index);
		if (!is_ai_hero(state, entry) || state.has(resolved, str(gd::stringify(state, ai::vget(state, entry, key::placement_id, str(key::empty)))))) {
			continue;
		}
		if (player_rules::raid_controller_id(state, gd::as_dict(entry)) != controller || !level_rules::same_level(state, entry, dict_value(column))) {
			continue;
		}
		const int64_t dx = compat::absi(gd::sub(gd::int_field(state, entry.ref, key::x, 0), gd::int_field(state, column, key::x, 0)));
		const int64_t dy = compat::absi(gd::sub(gd::int_field(state, entry.ref, key::y, 0), gd::int_field(state, column, key::y, 0)));
		const int64_t distance = compat::engine_max<int64_t>(dx, dy);
		if (distance < best_distance) {
			best_distance = distance;
			best = index;
		}
	}
	return best;
}

DictRef _convert_legacy_host(State &state, DictRef session, DictRef entry, Atom controller) {
	const DictRef converted = gd::deep_duplicate_dict(state, entry);
	state.set(converted, str(key::legacy_encounter_id), str(gd::stringify(state, state.get(entry, str(key::encounter_id), str(key::empty)))));
	state.set(converted, str(key::encounter_id), str(key::encounter_mire_raid));
	for (const Atom field : { key::difficulty, key::commanderless_support_column, key::delivery_intercept_node_placement_id, key::arrived }) {
		state.erase(converted, str(field));
	}
	// Raid targets told the human's forecasts where a host was heading; a hero's
	// goal is its own business.
	const ArrayRef converted_keys = gd::keys(state, converted);
	for (const Value &field : gd::items(state, array_value(converted_keys))) {
		const Atom text = gd::stringify(state, field);
		for (const Atom prefix : { key::target_, key::goal_, key::regroup_, key::guarded_claim_, key::blocked_route_, key::supporting_front_, key::support_ }) {
			if (gd::begins_with(state, text, prefix)) {
				state.erase(converted, field);
				break;
			}
		}
	}
	DictRef army = 0;
	{
		Value found;
		army = state.lookup(converted, str(key::enemy_army), found) && gd::is_dict(found) ? found.ref : state.new_dict();
	}
	state.set(army, str(key::name), str(gd::format(state, key::s_s_army, { str(hero_name(state, converted)) })));
	state.set(converted, str(key::enemy_army), dict_value(army));
	const Vector2i tile = Vector2i::of(gd::int_field(state, entry, key::x, 0), gd::int_field(state, entry, key::y, 0));
	const DictRef home = _nearest_owned_town(state, session, controller, tile, level_rules::level_of(state, dict_value(entry)));
	const DictRef block = state.new_dict();
	Atom hero_id = key::empty;
	{
		Value commander;
		if (state.lookup(converted, str(key::enemy_commander_state), commander)) {
			hero_id = gd::stringify(state, ai::vget(state, commander, key::roster_hero_id, str(key::empty)));
		}
	}
	state.set(block, str(key::hero_id), str(hero_id));
	const DictRef movement = state.new_dict();
	state.set(movement, str(key::current), int_value(0));
	state.set(movement, str(key::max), int_value(_movement_max(state, converted)));
	state.set(block, str(key::movement), dict_value(movement));
	state.set(block, str(key::home_town_id), str(ai::string_or_empty(state, home, key::placement_id)));
	state.set(block, str(key::hired_day), int_value(ai::session_int(state, session, key::day)));
	state.set(block, str(key::goal), dict_value(state.new_dict()));
	state.set(block, str(key::migrated_from_raid), bool_value(true));
	state.set(converted, str(key::ai_hero), dict_value(block));
	return converted;
}

void _return_troops_to_nearest_town(State &state, DictRef session, DictRef entry, Atom controller) {
	ArrayRef stacks = 0;
	{
		// entry.get("enemy_army", {}).get("stacks", []) if ... is Dictionary else []
		Value army;
		if (!state.lookup(entry, str(key::enemy_army), army)) {
			stacks = state.new_array();
		} else if (gd::is_dict(army)) {
			stacks = gd::as_array(get_or_new_array(state, army.ref, key::stacks));
		} else {
			stacks = state.new_array();
		}
	}
	const Vector2i tile = Vector2i::of(gd::int_field(state, entry, key::x, 0), gd::int_field(state, entry, key::y, 0));
	const DictRef home = _nearest_owned_town(state, session, controller, tile, level_rules::level_of(state, dict_value(entry)));
	if (gd::is_empty(state, home) || state.array_size(stacks) == 0) {
		return;
	}
	const ArrayRef towns = gd::as_array(get_or_new_array(state, session_view::overworld(state, session), key::towns));
	const int64_t index = gd::int_field(state, home, key::index, -1);
	if (index < 0 || index >= state.array_size(towns)) {
		return;
	}
	const DictRef town = gd::as_dict(state.at(towns, index));
	const DictRef merged = _merge_stacks_into(state, get_or_new_array(state, town, key::garrison), array_value(stacks));
	const Value garrison_fallback = get_or_new_array(state, town, key::garrison);
	state.set(town, str(key::garrison), state.get(merged, str(key::stacks), garrison_fallback));
	state.set_at(towns, index, dict_value(town));
	state.set(session_view::overworld(state, session), str(key::towns), array_value(towns));
}

double _upgrade_value(State &state, DictRef town, DictRef building) {
	(void)town;
	const Atom upgraded = gd::stringify(state, state.get(building, str(key::unlock_unit_id), str(key::empty)));
	const DictRef base_building = gd::content_row(state, ContentTable::Building, gd::stringify(state, state.get(building, str(key::upgrade_from), str(key::empty))));
	const Atom base_unit = gd::stringify(state, state.get(base_building, str(key::unlock_unit_id), str(key::empty)));
	if (upgraded == key::empty || base_unit == key::empty) {
		return 0.0;
	}
	const int64_t weekly = gd::int_field(state, gd::content_row(state, ContentTable::Unit, base_unit), key::growth, 1);
	const double upgraded_power = army_power(state, array_value(single_stack(state, upgraded, weekly)), dict_value(state.new_dict()));
	const double base_power = army_power(state, array_value(single_stack(state, base_unit, weekly)), dict_value(state.new_dict()));
	const double gain = upgraded_power - base_power;
	const Atom script = key::ai_hero_rules_script;
	return compat::engine_max<double>(0.0, gain) * ai::static_float(state, script, key::TROOP_VALUE_PER_POWER) * ai::static_float(state, script, key::UPGRADE_VALUE_WEEKS) + ai::static_float(state, script, key::UPGRADE_BASE_VALUE);
}

DictRef _attack_player_hero(State &state, DictRef session, DictRef context, int64_t index, DictRef plan) {
	const ArrayRef heroes = gd::as_array(get_or_new_array(state, session_view::overworld(state, session), key::player_heroes));
	const int64_t hero_index = gd::int_field(state, plan, key::index, -1);
	if (hero_index < 0 || hero_index >= state.array_size(heroes)) {
		return arrived_result(state);
	}
	const DictRef hero = gd::as_dict(state.at(heroes, hero_index));
	const Atom hero_id = ai::string_or_empty(state, hero, key::id);
	if (!gd::bool_field(state, hero_command_rules::set_active_hero(state, session, hero_id), key::ok, false)) {
		return arrived_result(state);
	}
	const Atom controller = gd::stringify(state, gd::index(state, context, str(key::controller)));
	const DictRef battle_context = state.new_dict();
	state.set(battle_context, str(key::type), str(key::hero_intercept));
	state.set(battle_context, str(key::target_hero_id), str(hero_id));
	state.set(battle_context, str(key::trigger_faction_id), str(player_rules::faction_id(state, session, controller)));
	state.set(battle_context, str(key::trigger_player_id), str(ai::string_or_empty(state, player_rules::player(state, session, controller), key::player_id)));
	const Atom attacker = hero_name(state, encounter_at(state, session, index));
	const Atom defender = gd::stringify(state, state.get(hero, str(key::name), str(key::the_hero)));
	const Atom summary = gd::format(state, key::s_attacks_s, { str(attacker), str(defender) });
	// A host call: nothing is read after it.
	return _start_player_battle(state, session, context, index, battle_context, summary, hero);
}

} // namespace ai_hero_rules

// ArtifactRules.

namespace artifact_rules {

bool has_artifact(State &state, DictRef hero_state, Atom artifact_id) {
	const DictRef location = locate_artifact(state, hero_state, artifact_id);
	return gd::stringify(state, state.get(location, str(key::location), str(key::missing))) != key::missing;
}

ArrayRef artifact_set_runtime_state(State &state, DictRef hero_state) {
	// Normalizing reads the artifacts only, so the hero needs no copy.
	// normalize_hero_artifacts({}) is normalize_hero_artifacts(null).
	const DictRef artifacts = normalize_hero_artifacts(state, gd::field(state, hero_state, key::artifacts));
	return _set_states_for_equipped(state, get_or_new_dict(state, artifacts, key::equipped));
}

DictRef remove_owned_artifact(State &state, DictRef hero_state, Atom artifact_id) {
	const DictRef hero = ensure_hero_artifacts(state, gd::deep_duplicate_dict(state, hero_state));
	const DictRef location = locate_artifact(state, hero, artifact_id);
	const Atom location_name = gd::stringify(state, state.get(location, str(key::location), str(key::missing)));
	if (location_name == key::missing) {
		const DictRef refused = hero_outcome(state, false, hero);
		state.set(refused, str(key::message), str(key::that_artifact_is_no_longer_owned));
		return refused;
	}
	const DictRef artifacts = gd::as_dict(get_or_new_dict(state, hero, key::artifacts));
	const DictRef equipped = gd::as_dict(get_or_new_dict(state, artifacts, key::equipped));
	ArrayRef inventory = 0;
	{
		Value found;
		inventory = state.lookup(artifacts, str(key::inventory), found) && gd::is_array(found) ? found.ref : state.new_array();
	}
	if (location_name == key::equipped) {
		state.set(equipped, str(gd::stringify(state, state.get(location, str(key::slot), str(key::empty)))), str(key::empty));
	} else if (!_remove_artifact_from_inventory(state, inventory, artifact_id)) {
		const DictRef refused = hero_outcome(state, false, hero);
		state.set(refused, str(key::message), str(key::that_artifact_is_no_longer_in));
		return refused;
	}
	state.set(artifacts, str(key::equipped), dict_value(equipped));
	state.set(artifacts, str(key::inventory), array_value(inventory));
	state.set(hero, str(key::artifacts), dict_value(normalize_hero_artifacts(state, dict_value(artifacts))));
	const DictRef result = hero_outcome(state, true, hero);
	state.set(result, str(key::artifact_id), str(artifact_id));
	state.set(result, str(key::previous_location), str(location_name));
	state.set(result, str(key::previous_slot), str(gd::stringify(state, state.get(location, str(key::slot), str(key::empty)))));
	state.set(result, str(key::message), str(gd::format(state, key::released_s_for_transfer, { str(artifact_name(state, artifact_id)) })));
	return result;
}

} // namespace artifact_rules

// DifficultyRules.

namespace difficulty_rules {

int64_t adjust_enemy_pressure_gain(State &state, DictRef session, int64_t base_gain) {
	const DictRef profile = profile_for_session(state, dict_value(session));
	return compat::engine_max<int64_t>(0, gd::add(base_gain, gd::int_field(state, profile, key::enemy_pressure_bonus, 0)));
}

int64_t adjust_raid_threshold(State &state, DictRef session, int64_t base_threshold) {
	const DictRef profile = profile_for_session(state, dict_value(session));
	return compat::engine_max<int64_t>(1, gd::add(base_threshold, gd::int_field(state, profile, key::raid_threshold_offset, 0)));
}

} // namespace difficulty_rules

// EnemyTownServices.

namespace enemy_town_services {

double loadout_value(State &state, DictRef hero) {
	const Atom script = key::enemy_town_services_script;
	if (!ai::static_bool(state, script, key::_ai_weights_ready)) {
		apply_ai_weights(state, content_service::default_ai_hero_weights(state));
	}
	// Compare actual equipped effects, including set thresholds and penalties.
	const DictRef bonuses = artifact_rules::aggregate_bonuses(state, gd::deep_duplicate_dict(state, hero));
	double score = 0.0;
	const DictRef loadout_values = ai::static_dict(state, script, key::LOADOUT_VALUES);
	for (const Value &value_key : gd::items(state, dict_value(loadout_values))) {
		score += gd::to_float(state.get(bonuses, value_key, int_value(0))) * gd::to_float(gd::index(state, loadout_values, value_key));
	}
	for (const Value &income_key : gd::field_items(state, bonuses, str(key::daily_income))) {
		const Value amount = ai::vindex(state, gd::index(state, bonuses, str(key::daily_income)), income_key);
		const double weight = gd::equal(state, income_key, str(key::gold)) ? ai::static_float(state, script, key::LOADOUT_GOLD_INCOME_VALUE) : ai::static_float(state, script, key::LOADOUT_INCOME_VALUE);
		score += gd::to_float(amount) * weight;
	}
	{
		// bonuses.get("battle_school_resistance_pct", {}).values(): none when missing.
		Value resistance;
		if (state.lookup(bonuses, str(key::battle_school_resistance_pct), resistance)) {
			const ArrayRef values = gd::values(state, values_target(resistance));
			for (const Value &value : gd::items(state, array_value(values))) {
				score += gd::to_float(value) * ai::static_float(state, script, key::LOADOUT_SCHOOL_RESISTANCE_VALUE);
			}
		}
	}
	for (const Value &modifier : gd::field_items(state, bonuses, str(key::spell_modifiers))) {
		const double effect = gd::to_float(ai::vget(state, modifier, key::effect_amount_delta, int_value(0))) * ai::static_float(state, script, key::LOADOUT_SPELL_EFFECT_VALUE);
		const double mana = gd::to_float(ai::vget(state, modifier, key::mana_cost_delta, int_value(0))) * ai::static_float(state, script, key::LOADOUT_MANA_COST_VALUE);
		score += effect - mana;
	}
	return score;
}

DictRef best_equipment(State &state, DictRef hero, Atom artifact_id) {
	DictRef best = state.new_dict();
	state.set(best, str(key::hero), dict_value(hero));
	state.set(best, str(key::gain), float_value(0.0));
	const double before = loadout_value(state, hero);
	const Atom slot_type = artifact_rules::artifact_slot(state, artifact_id);
	const std::vector<Atom> slots = slot_type == key::trinket ? std::vector<Atom>{ key::trinket, key::trinket_2 } : std::vector<Atom>{ slot_type };
	for (const Atom slot : slots) {
		if (!is_equipment_slot(slot)) {
			continue;
		}
		const DictRef candidate = artifact_rules::ensure_hero_artifacts(state, gd::deep_duplicate_dict(state, hero));
		// Explicitly compare both trinket slots; default equip only replaces the first.
		const Value artifacts = gd::index(state, candidate, str(key::artifacts));
		const Value equipped = ai::vmember(state, artifacts, key::equipped);
		const Atom displaced = gd::stringify(state, ai::vget(state, equipped, str(slot), str(key::empty)));
		const ArrayRef inventory = gd::as_array(ai::vmember(state, artifacts, key::inventory));
		ai::array_erase(state, inventory, str(artifact_id));
		if (displaced != key::empty) {
			state.append(inventory, str(displaced));
		}
		state.set(gd::as_dict(equipped), str(slot), str(artifact_id));
		// candidate.artifacts = ...: a named set, onto the key ensure_hero_artifacts stored.
		state.set(candidate, gd::name_value(key::artifacts), dict_value(artifact_rules::normalize_hero_artifacts(state, gd::index(state, candidate, str(key::artifacts)))));
		const double gain = loadout_value(state, candidate) - before;
		if (gain > gd::to_float(gd::index(state, best, str(key::gain))) + 0.001) {
			best = state.new_dict();
			state.set(best, str(key::hero), dict_value(candidate));
			state.set(best, str(key::gain), float_value(gain));
		}
	}
	return best;
}

} // namespace enemy_town_services

// HeroCommandRules.

namespace hero_command_rules {

DictRef set_active_hero(State &state, DictRef session, Atom hero_id) {
	normalize_session(state, session, key::empty, state.new_dict(), state.new_dict());
	if (hero_id == key::empty) {
		return message_outcome(state, false, key::no_hero_was_selected);
	}
	commit_active_hero(state, session);
	const DictRef hero = hero_by_id(state, session, hero_id);
	if (gd::is_empty(state, hero)) {
		return message_outcome(state, false, key::that_hero_is_not_under_command);
	}
	const DictRef overworld = session_view::overworld(state, session);
	if (gd::stringify(state, state.get(overworld, str(key::active_hero_id), str(key::empty))) == hero_id) {
		const Atom name = gd::stringify(state, state.get(hero, str(key::name), str(key::the_hero_text)));
		return message_outcome(state, true, gd::format(state, key::s_is_already_in_command, { str(name) }));
	}
	state.set(session_view::overworld(state, session), str(key::active_hero_id), str(hero_id));
	_sync_active_hero_mirror(state, session);
	const Atom name = gd::stringify(state, state.get(hero, str(key::name), str(key::the_hero_text)));
	return message_outcome(state, true, gd::format(state, key::s_takes_command, { str(name) }));
}

ArrayRef merge_stacks_into_army(State &state, ArrayRef army, ArrayRef incoming) {
	const ArrayRef merged = _slotted_stacks(state, array_value(army));
	for (const Value &stack_value : gd::items(state, array_value(incoming))) {
		if (!gd::is_dict(stack_value)) {
			continue;
		}
		const Atom unit_id = ai::string_or_empty(state, stack_value.ref, key::unit_id);
		const int64_t count = gd::int_field(state, stack_value.ref, key::count, 0);
		if (unit_id == key::empty || count <= 0) {
			continue;
		}
		bool joined = false;
		const int64_t size = state.array_size(merged);
		for (int64_t index = 0; index < size; ++index) {
			if (gd::stringify(state, ai::vget(state, state.at(merged, index), key::unit_id, str(key::empty))) == unit_id) {
				const int64_t total = gd::add(gd::to_int(state, ai::vget(state, state.at(merged, index), key::count, int_value(0))), count);
				state.set(gd::as_dict(state.at(merged, index)), str(key::count), int_value(total));
				joined = true;
				break;
			}
		}
		if (joined) {
			continue;
		}
		const DictRef claimed = state.new_dict();
		for (const Value &stack : gd::items(state, array_value(merged))) {
			state.set(claimed, int_value(gd::to_int(state, ai::vget(state, stack, key::slot_index, int_value(-1)))), bool_value(true));
		}
		const int64_t slot = _first_open_army_slot(state, claimed);
		if (slot < 0) {
			return state.new_array();
		}
		const DictRef placed = gd::deep_duplicate_dict(state, stack_value.ref);
		state.set(placed, str(key::slot_index), int_value(slot));
		state.append(merged, dict_value(placed));
	}
	gd::sort_custom(state, merged, [&state](const Value &left, const Value &right) {
		return _stack_slot_less(state, gd::as_dict(left), gd::as_dict(right));
	});
	return merged;
}

ArrayRef _holder_stacks(State &state, DictRef session, DictRef town, Atom holder_id) {
	if (holder_id == key::garrison) {
		// A missing garrison is [], whose duplicate is a new [].
		const Value garrison = gd::field(state, town, key::garrison);
		return gd::is_array(garrison) ? gd::deep_duplicate_array(state, garrison.ref) : state.new_array();
	}
	const DictRef hero = hero_by_id(state, session, holder_id);
	if (gd::is_empty(state, hero)) {
		return state.new_array();
	}
	Value army;
	if (!state.lookup(hero, str(key::army), army)) {
		return state.new_array();
	}
	// hero.get("army", {}).get("stacks", []): a missing list is [], whose duplicate is a new [].
	const Value stacks = ai::vget(state, army, key::stacks);
	return gd::is_array(stacks) ? gd::deep_duplicate_array(state, stacks.ref) : state.new_array();
}

} // namespace hero_command_rules

// OverworldLevelRules.

namespace overworld_level_rules {

int64_t view_level(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return 0;
	}
	const DictRef view = gd::as_dict(session);
	const DictRef overworld = session_view::overworld(state, view);
	const int64_t fallback = hero_level(state, view);
	const int64_t level = gd::to_int(state, state.get(overworld, str(key::view_level), int_value(fallback)));
	return compat::engine_clamp<int64_t>(level, 0, gd::sub(level_count(state, view), 1));
}

} // namespace overworld_level_rules

// OverworldTurnPlayback.

namespace overworld_turn_playback {

bool visible(State &state, const Value &session, DictRef point) {
	if (level_rules::level_of(state, dict_value(point)) != level_rules::view_level(state, session)) {
		return false;
	}
	const int64_t x = gd::int_field(state, point, key::x, -1);
	const int64_t y = gd::int_field(state, point, key::y, -1);
	const int64_t level = level_rules::level_of(state, dict_value(point));
	// OverworldRules.is_tile_visible(null, ...) is false.
	if (session.kind == Kind::Nil) {
		return false;
	}
	return overworld_rules::is_tile_visible(state, gd::as_dict(session), x, y, level);
}

DictRef _visual_actor(State &state, DictRef actor, DictRef point) {
	// An allowlist prevents hidden targets, task scores or planned routes from
	// entering the presentation record, even as AI state gains new fields.
	const DictRef visual = state.new_dict();
	for (const Atom field : { key::placement_id, key::encounter_id, key::name, key::spawned_by_faction_id, key::spawned_by_player_id }) {
		if (state.has(actor, str(field))) {
			state.set(visual, str(field), gd::index(state, actor, str(field)));
		}
	}
	Value roster_hero_id = str(key::empty);
	Value faction_id = str(key::empty);
	{
		Value found;
		if (state.lookup(actor, str(key::enemy_commander_state), found)) {
			const DictRef commander = gd::as_dict(found);
			roster_hero_id = state.get(commander, str(key::roster_hero_id), str(key::empty));
			faction_id = state.get(commander, str(key::faction_id), str(key::empty));
		}
	}
	const DictRef commander_state = state.new_dict();
	state.set(commander_state, str(key::roster_hero_id), roster_hero_id);
	state.set(commander_state, str(key::faction_id), faction_id);
	state.set(visual, str(key::enemy_commander_state), dict_value(commander_state));
	// visual.x = ...: named sets of new keys, which Dictionary::set keeps as StringNames.
	state.set(visual, gd::name_value(key::x), gd::index(state, point, str(key::x)));
	state.set(visual, gd::name_value(key::y), gd::index(state, point, str(key::y)));
	state.set(visual, gd::name_value(key::level), int_value(level_rules::level_of(state, dict_value(point))));
	return visual;
}

Atom _actor_name(State &state, DictRef actor) {
	Atom hero_id = key::empty;
	{
		Value found;
		if (state.lookup(actor, str(key::enemy_commander_state), found)) {
			hero_id = gd::stringify(state, state.get(gd::as_dict(found), str(key::roster_hero_id), str(key::empty)));
		}
	}
	const DictRef hero = gd::content_row(state, ContentTable::Hero, hero_id);
	return gd::stringify(state, state.get(hero, str(key::name), state.get(actor, str(key::name), str(key::enemy_hero_2))));
}

} // namespace overworld_turn_playback

// PlayerIdentityRules.

namespace player_identity_rules {

DictRef config_for_controller(State &state, const Value &session, Atom controller) {
	DictRef result = 0;
	if (session.kind == Kind::Nil) {
		// identity_fields(null, controller): player(null, ...) is {}.
		result = state.new_dict();
		state.set(result, str(key::faction_id), str(controller));
	} else {
		result = identity_fields(state, gd::as_dict(session), controller);
	}
	const Value faction = gd::index(state, result, str(key::faction_id));
	const DictRef row = gd::content_row(state, ContentTable::Faction, gd::stringify(state, faction));
	state.set(result, str(key::label), str(gd::stringify(state, state.get(row, str(key::name), gd::index(state, result, str(key::faction_id))))));
	return result;
}

} // namespace player_identity_rules

// SpellRules.

namespace spell_rules {

DictRef mana_state(State &state, DictRef hero_state) {
	const DictRef hero = ensure_hero_spellbook(state, gd::deep_duplicate_dict(state, hero_state), state.new_dict());
	const Value spellbook = get_or_new_dict(state, hero, key::spellbook);
	if (!gd::is_dict(spellbook)) {
		return gd::as_dict(ai::vget(state, spellbook, key::mana));
	}
	return gd::as_dict(get_or_new_dict(state, spellbook.ref, key::mana));
}

} // namespace spell_rules

// TownDevelopmentRules.

namespace town_development_rules {

bool satisfies(State &state, ArrayRef built, Atom required) {
	return state.has(_satisfied_ids(state, built), str(required));
}

int64_t price(State &state, DictRef artifact) {
	const Atom tier = gd::stringify(state, state.get(artifact, str(key::rarity), str(key::common)));
	// {"common": 1500, "uncommon": 2500, "rare": 4000, "epic": 6500, "legendary": 10000}.get(tier, 2500)
	if (tier == key::common) {
		return 1500;
	}
	if (tier == key::uncommon) {
		return 2500;
	}
	if (tier == key::rare) {
		return 4000;
	}
	if (tier == key::epic) {
		return 6500;
	}
	if (tier == key::legendary) {
		return 10000;
	}
	return 2500;
}

ArrayRef offers(State &state, DictRef town, int64_t day, ArrayRef excluded_ids) {
	const ArrayRef eligible = state.new_array();
	for (const Value &artifact : gd::field_items(state, gd::content_file(state, key::artifacts_path), str(key::items))) {
		// Authored quest/relic rewards stay outside the merchant inventory.
		const Atom rarity = gd::stringify(state, ai::vget(state, artifact, key::rarity, str(key::common)));
		if ((rarity == key::common || rarity == key::uncommon || rarity == key::rare) && !gd::to_bool(ai::vget(state, artifact, key::quest_item, bool_value(false)))) {
			state.append(eligible, str(gd::stringify(state, ai::vmember(state, artifact, key::id))));
		}
	}
	// eligible.sort() of Strings: by code point, which is UTF-8 byte order.
	gd::sort_custom(state, eligible, [&state](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
	const ArrayRef result = state.new_array();
	const int64_t size = state.array_size(eligible);
	if (size == 0) {
		return result;
	}
	const int64_t week = compat::engine_max<int64_t>(0, compat::int_div(gd::sub(day, 1), 7));
	const Atom placement_id = gd::stringify(state, state.get(town, str(key::placement_id), str(key::empty)));
	const int64_t placement_hash = static_cast<int64_t>(compat::string_hash(state.text(placement_id)));
	const int64_t start = compat::posmod(gd::add(placement_hash, gd::mul(week, 3)), size);
	// Scenario objective artifacts are skipped in place, so the rest of the
	// weekly rotation stays the same.
	for (int64_t i = 0; i < size; ++i) {
		if (state.array_size(result) >= 3) {
			break;
		}
		const Atom id = gd::to_string(state.at(eligible, compat::int_mod(gd::add(start, i), size)));
		if (!gd::array_has(state, excluded_ids, str(id))) {
			state.append(result, str(id));
		}
	}
	return result;
}

DictRef trade_artifact(State &state, DictRef hero, DictRef town, int64_t day, Atom artifact_id, bool buying, DictRef resources, ArrayRef excluded_ids) {
	bool exchange = false;
	for (const Value &id : gd::items(state, array_value(active_buildings(state, town)))) {
		const DictRef building = gd::content_row(state, ContentTable::Building, gd::stringify(state, id));
		if (gd::truthy(state, state.get(building, str(key::artifact_exchange), bool_value(false)))) {
			exchange = true;
		}
	}
	const DictRef artifact = gd::content_row(state, ContentTable::Artifact, artifact_id);
	if (!exchange || gd::is_empty(state, artifact) || gd::bool_field(state, artifact, key::quest_item, false) || gd::array_has(state, excluded_ids, str(artifact_id))) {
		return hero_outcome(state, false, hero);
	}
	const Atom week = gd::stringify(state, int_value(compat::engine_max<int64_t>(0, compat::int_div(gd::sub(day, 1), 7))));
	const DictRef purchases = gd::as_dict(gd::duplicate_value(state, get_or_new_dict(state, town, key::artifact_shop_purchases), true));
	ArrayRef purchased = 0;
	{
		Value found;
		purchased = state.lookup(purchases, str(week), found) ? gd::as_array(found) : state.new_array();
	}
	DictRef result = 0;
	if (buying) {
		if (!gd::array_has(state, offers(state, town, day, excluded_ids), str(artifact_id)) || gd::array_has(state, purchased, str(artifact_id)) || artifact_rules::has_artifact(state, hero, artifact_id)) {
			return hero_outcome(state, false, hero);
		}
		const DictRef cost = state.new_dict();
		state.set(cost, str(key::gold), int_value(price(state, artifact)));
		if (!can_pay(state, resources, cost)) {
			return hero_outcome(state, false, hero);
		}
		result = artifact_rules::claim_artifact(state, hero, artifact_id, key::Purchased, false);
	} else {
		// normalize_hero_artifacts({}) is normalize_hero_artifacts(null).
		const DictRef normalized = artifact_rules::normalize_hero_artifacts(state, gd::field(state, hero, key::artifacts));
		if (!gd::in(state, str(artifact_id), gd::index(state, normalized, str(key::inventory)))) {
			return hero_outcome(state, false, hero);
		}
		result = artifact_rules::remove_owned_artifact(state, hero, artifact_id);
	}
	if (!gd::bool_field(state, result, key::ok, false)) {
		return result;
	}
	const int64_t gold = gd::int_field(state, resources, key::gold, 0);
	const int64_t delta = buying ? gd::neg(price(state, artifact)) : compat::int_div(price(state, artifact), 2);
	state.set(resources, str(key::gold), int_value(gd::add(gold, delta)));
	if (buying) {
		state.append(purchased, str(artifact_id));
		state.set(purchases, str(week), array_value(purchased));
		state.set(town, str(key::artifact_shop_purchases), dict_value(purchases));
	}
	return result;
}

} // namespace town_development_rules

// VisitBuildingRules.

namespace visit_building_rules {

Atom _resource_text(State &state, DictRef resources) {
	std::string joined;
	bool first = true;
	for (const Value &resource : gd::items(state, array_value(gd::keys(state, resources)))) {
		const Atom amount = _thousands(state, gd::to_int(state, gd::index(state, resources, resource)));
		const Atom name = gd::replace(state, gd::stringify(state, resource), key::_, key::space);
		const Atom part = gd::format(state, key::s_s, { str(amount), str(name) });
		if (!first) {
			joined += state.text(key::comma_space);
		}
		joined += state.text(part);
		first = false;
	}
	return state.intern(joined);
}

} // namespace visit_building_rules

} // namespace aurelion::rules::port
