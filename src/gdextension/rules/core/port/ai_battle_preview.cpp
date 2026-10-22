// The AI's battle preview (Phase 2, slice 2a): AiHeroRules._simulate_battle
// and _battle_hero.

#include "aurelion_rules/port/ai_battle_preview.hpp"

#include "aurelion_rules/port/ai_hero_rules_ai.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_auto_resolve_rules.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/battle_payload.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/session_state_store.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

namespace aurelion::rules::port::ai_hero_rules {

using gd::ArrayRef;
using gd::array_value;
using gd::Atom;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::Value;
namespace key = state::key;

namespace {

constexpr int64_t DEFAULT_STEP_LIMIT = 240; // BattleAutoResolveRules.DEFAULT_STEP_LIMIT
constexpr int64_t SAVE_VERSION = 9; // SessionStateStore.SAVE_VERSION

// d.get(key, {}) where the Dictionary is passed on: the stored one, or a new one.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// String(d.get(key, "")).
Atom string_of(State &state, DictRef dict, Atom field) {
	return gd::stringify(state, gd::field_or(state, dict, field, str(key::empty)));
}

// x.duplicate(true) of an untyped Array or Dictionary.
Value deep_duplicate(State &state, const Value &value) {
	if (gd::is_dict(value)) {
		return dict_value(gd::deep_duplicate_dict(state, value.ref));
	}
	if (gd::is_array(value)) {
		return array_value(gd::deep_duplicate_array(state, value.ref));
	}
	throw state::ScriptError(std::string("Invalid call. Nonexistent function 'duplicate' in base '") + gd::type_name(value) + "'.");
}

// SessionStateStore.new_session_data(session_id, "", hero_id, day,
// overworld_state, "normal", "skirmish") as its view: the SessionData's
// fields in their order, then its metadata (none) under "meta". The
// overworld is a deep copy of overworld_state, as SessionData._init makes it.
DictRef new_scratch_session(State &state, Atom session_id, Atom hero_id, int64_t day, DictRef overworld_state) {
	const DictRef session = state.new_dict();
	state.set(session, str(key::save_version), int_value(SAVE_VERSION));
	state.set(session, str(key::session_id), str(session_id));
	state.set(session, str(key::scenario_id), str(key::empty));
	state.set(session, str(key::hero_id), str(hero_id));
	state.set(session, str(key::day), int_value(day));
	state.set(session, str(key::difficulty), str(key::normal)); // AI_DIFFICULTY
	state.set(session, str(key::launch_mode), str(session_state_store::normalize_launch_mode(state, str(key::skirmish))));
	state.set(session, str(key::game_state), str(key::overworld));
	state.set(session, str(key::scenario_status), str(key::in_progress));
	state.set(session, str(key::scenario_summary), str(key::empty));
	state.set(session, str(key::overworld), dict_value(gd::deep_duplicate_dict(state, overworld_state)));
	state.set(session, str(key::battle), dict_value(state.new_dict()));
	state.set(session, str(key::flags), dict_value(state.new_dict()));
	state.set(session, str(key::meta), dict_value(state.new_dict()));
	return session;
}

DictRef point_zero(State &state) {
	const DictRef point = state.new_dict();
	state.set(point, str(key::x), int_value(0));
	state.set(point, str(key::y), int_value(0));
	return point;
}

} // namespace

DictRef _simulate_battle(State &state, DictRef session, DictRef context, DictRef entry, DictRef defender, int64_t battle_number, int64_t stop_below_creatures) {
	(void)context;
	const int64_t day = gd::to_int(state, gd::index(state, session, str(key::day)));
	return _simulate_battle_on_day(state, day, entry, defender, battle_number, stop_below_creatures);
}

// One auto-resolved battle on a scratch session: the hero attacks `defender`.
// Pure: the live session is not touched. stop_below_creatures > 0 ends the
// battle unresolved (not won) once the hero has fewer creatures standing.
DictRef _simulate_battle_on_day(State &state, int64_t day, DictRef entry, DictRef defender, int64_t battle_number, int64_t stop_below_creatures) {
	const DictRef hero = _battle_hero(state, entry);
	const DictRef defender_copy = gd::deep_duplicate_dict(state, defender);
	state.set(defender_copy, str(key::x), int_value(0));
	state.set(defender_copy, str(key::y), int_value(0));
	state.set(defender_copy, str(key::level), int_value(0));
	state.erase(defender_copy, str(key::battle_context));
	Value defender_army;
	if (state.lookup(defender_copy, str(key::enemy_army), defender_army) && gd::is_dict(defender_army)) {
		Value stacks;
		const bool has_stacks = state.lookup(defender_army.ref, str(key::stacks), stacks);
		if (!has_stacks || state.array_size(gd::as_array(stacks)) == 0) {
			state.erase(defender_copy, str(key::enemy_army));
		}
	} else if (player_identity_rules::raid_controller_id(state, defender) == key::empty) {
		state.set(defender_copy, str(key::enemy_army), dict_value(_neutral_army(state, defender)));
	}
	const Atom hero_id = string_of(state, hero, key::id);
	const DictRef overworld_state = state.new_dict();
	{
		const ArrayRef map_row = state.new_array();
		state.append(map_row, str(key::grass));
		const ArrayRef map = state.new_array();
		state.append(map, array_value(map_row));
		state.set(overworld_state, str(key::map), array_value(map));
		const DictRef map_size = state.new_dict();
		state.set(map_size, str(key::x), int_value(1));
		state.set(map_size, str(key::y), int_value(1));
		state.set(overworld_state, str(key::map_size), dict_value(map_size));
		const ArrayRef player_heroes = state.new_array();
		state.append(player_heroes, dict_value(hero));
		state.set(overworld_state, str(key::player_heroes), array_value(player_heroes));
		state.set(overworld_state, str(key::active_hero_id), str(hero_id));
		state.set(overworld_state, str(key::hero), dict_value(hero));
		state.set(overworld_state, str(key::army), field_or_new_dict(state, hero, key::army));
		state.set(overworld_state, str(key::hero_position), dict_value(point_zero(state)));
		state.set(overworld_state, str(key::movement), field_or_new_dict(state, hero, key::movement));
		const ArrayRef encounters = state.new_array();
		state.append(encounters, dict_value(defender_copy));
		state.set(overworld_state, str(key::encounters), array_value(encounters));
		state.set(overworld_state, str(key::resolved_encounters), array_value(state.new_array()));
		state.set(overworld_state, str(key::towns), array_value(state.new_array()));
		state.set(overworld_state, str(key::resource_nodes), array_value(state.new_array()));
		state.set(overworld_state, str(key::artifact_nodes), array_value(state.new_array()));
		state.set(overworld_state, str(key::resources), dict_value(state.new_dict()));
		state.set(overworld_state, str(key::enemy_states), array_value(state.new_array()));
	}
	const Atom session_id = gd::format(state, key::ai_battle_s_d, { str(string_of(state, entry, key::placement_id)), int_value(battle_number) });
	const DictRef scratch = new_scratch_session(state, session_id, hero_id, day, overworld_state);
	const Value scratch_value = dict_value(scratch);
	const DictRef payload = battle_rules::create_battle_payload(state, scratch_value, defender_copy);
	if (gd::is_empty(state, payload)) {
		const DictRef failed = state.new_dict();
		state.set(failed, str(key::ok), gd::bool_value(false));
		state.set(failed, str(key::won), gd::bool_value(false));
		return failed;
	}
	gd::set_member(state, scratch_value, key::battle, dict_value(payload));
	gd::set_member(state, scratch_value, key::game_state, str(key::battle));
	const DictRef resolution = battle_auto_resolve_rules::resolve_active_battle(state, scratch_value, DEFAULT_STEP_LIMIT, stop_below_creatures);
	const Atom final_state = string_of(state, resolution, key::state);
	const bool won = final_state == key::victory;
	const auto scratch_overworld = [&]() { return gd::as_dict(gd::member(state, scratch_value, key::overworld)); };
	const auto scratch_battle = [&]() { return gd::as_dict(gd::member(state, scratch_value, key::battle)); };
	DictRef hero_after = state.new_dict();
	for (const Value &value : gd::field_items(state, scratch_overworld(), str(key::player_heroes))) {
		if (gd::is_dict(value) && string_of(state, value.ref, key::id) == hero_id) {
			hero_after = value.ref;
		}
	}
	ArrayRef hero_survivors;
	if (!gd::is_empty(state, hero_after)) {
		const Value army = field_or_new_dict(state, hero_after, key::army);
		hero_survivors = gd::as_array(ai::vget(state, army, key::stacks, array_value(state.new_array())));
	} else {
		hero_survivors = state.new_array();
	}
	if (!won && !gd::is_empty(state, scratch_battle())) {
		// The fight ran out of orders without an outcome: both sides keep what
		// is still standing, as after a drawn battle.
		hero_survivors = battle_rules::_battle_survivor_stacks(state, scratch_value, key::player, state.new_dict());
	}
	ArrayRef enemy_survivors = state.new_array();
	DictRef scratch_defender = defender_copy;
	{
		Value encounters;
		if (state.lookup(scratch_overworld(), str(key::encounters), encounters) && !ai::vempty(state, encounters)) {
			scratch_defender = gd::as_dict(ai::vindex(state, encounters, int_value(0)));
		}
	}
	if (!won) {
		if (!gd::is_empty(state, scratch_battle())) {
			enemy_survivors = battle_rules::_battle_survivor_stacks(state, scratch_value, key::enemy, state.new_dict());
		} else {
			const Value army = field_or_new_dict(state, scratch_defender, key::enemy_army);
			const Value fallback = ai::vget(state, field_or_new_dict(state, defender_copy, key::enemy_army), key::stacks, array_value(state.new_array()));
			enemy_survivors = gd::as_array(ai::vget(state, army, key::stacks, fallback));
		}
	}
	const DictRef gained = state.new_dict();
	for (const Atom resource : { key::gold, key::wood, key::ore, key::aetherglass, key::embergrain, key::peatwax, key::verdant_grafts, key::brass_scrip,
				 key::memory_salt }) {
		Value resources;
		int64_t amount = 0;
		if (state.lookup(scratch_overworld(), str(key::resources), resources)) {
			amount = gd::to_int(state, ai::vget(state, resources, resource, int_value(0)));
		}
		if (amount > 0) {
			state.set(gained, str(resource), int_value(amount));
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), gd::bool_value(true));
	state.set(result, str(key::won), gd::bool_value(won));
	state.set(result, str(key::state), str(final_state));
	state.set(result, str(key::hero_after), dict_value(hero_after));
	state.set(result, str(key::hero_survivors), array_value(hero_survivors));
	state.set(result, str(key::lost), gd::bool_value(gd::is_empty(state, hero_after) || army_power(state, array_value(hero_survivors), dict_value(state.new_dict())) <= 0.0));
	state.set(result, str(key::enemy_survivors), array_value(enemy_survivors));
	state.set(result, str(key::resources_gained), dict_value(gained));
	const DictRef summary = state.new_dict();
	state.set(summary, str(key::state), str(final_state));
	state.set(summary, str(key::stop_reason), str(string_of(state, resolution, key::stop_reason)));
	state.set(summary, str(key::steps), int_value(gd::int_field(state, resolution, key::steps, 0)));
	state.set(summary, str(key::player_orders), int_value(gd::int_field(state, resolution, key::player_orders, 0)));
	state.set(summary, str(key::enemy_turns), int_value(gd::int_field(state, resolution, key::enemy_ready_ticks, 0)));
	state.set(summary, str(key::action_counts), field_or_new_dict(state, resolution, key::action_counts));
	state.set(summary, str(key::message),
			str(gd::stringify(state, ai::vget(state, field_or_new_dict(state, resolution, key::terminal_result), key::message, str(key::empty)))));
	state.set(result, str(key::resolution), dict_value(summary));
	return result;
}

DictRef _battle_hero(State &state, DictRef entry) {
	Value commander_value;
	if (!state.lookup(entry, str(key::enemy_commander_state), commander_value)) {
		commander_value = dict_value(state.new_dict());
	}
	const DictRef commander = gd::as_dict(deep_duplicate(state, commander_value));
	const Atom hero_id = gd::stringify(state, gd::field_or(state, commander, key::roster_hero_id, gd::field_or(state, commander, key::id, str(key::ai_hero))));
	const DictRef hero = commander;
	state.set(hero, str(key::id), str(hero_id));
	{
		const DictRef army = state.new_dict();
		state.set(army, str(key::id), str(gd::format(state, key::s_army, { str(hero_id) })));
		state.set(army, str(key::name), str(key::field_army));
		const Value stacks = ai::vget(state, field_or_new_dict(state, entry, key::enemy_army), key::stacks, array_value(state.new_array()));
		state.set(army, str(key::stacks), deep_duplicate(state, stacks));
		state.set(hero, str(key::army), dict_value(army));
	}
	state.set(hero, str(key::position), dict_value(point_zero(state)));
	{
		const DictRef no_movement = state.new_dict();
		state.set(no_movement, str(key::current), int_value(0));
		state.set(no_movement, str(key::max), int_value(0));
		const Value movement = ai::vget(state, field_or_new_dict(state, entry, key::ai_hero), key::movement, dict_value(no_movement));
		state.set(hero, str(key::movement), deep_duplicate(state, movement));
	}
	state.set(hero, str(key::is_primary), gd::bool_value(true));
	if (!state.has(hero, str(key::base_movement))) {
		const DictRef row = gd::content_row(state, state::ContentTable::Hero, hero_id);
		state.set(hero, str(key::base_movement), int_value(gd::int_field(state, row, key::base_movement, 10)));
	}
	return hero_progression_rules::ensure_hero_progression(state, spell_rules::ensure_hero_spellbook(state, hero, state.new_dict()));
}

} // namespace aurelion::rules::port::ai_hero_rules
