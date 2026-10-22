// A battle's payload (Phase 2, slice 2a): BattleRules.create_battle_payload,
// the helpers that set up its sides, names, stacks, obstacles and seed, and
// TownDevelopmentRules.apply_defender_bonus.

#include "aurelion_rules/port/battle_payload.hpp"

#include "aurelion_rules/battle_hex.hpp"
#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_pcg.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/battle_rules_ai.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/phase2a_deps.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/town_development_rules_ai.hpp"

#include <cstdlib>
#include <string>

namespace aurelion::rules::port::battle_rules {

using compat::engine_clamp;
using compat::engine_max;
using gd::array_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::Kind;
namespace key = state::key;

namespace {

constexpr int64_t COHESION_MIN = 0;
constexpr int64_t COHESION_MAX = 10;
constexpr int64_t MOMENTUM_MAX = 4;
constexpr int64_t BATTLE_HEX_COLUMNS = 11;
constexpr int64_t BATTLE_HEX_ROWS = 9;
constexpr int64_t OBSTACLE_VARIANT_COUNT = 25;
constexpr int64_t OBSTACLE_MIN_COUNT = 2;
constexpr int64_t OBSTACLE_MAX_COUNT = 4;
constexpr int64_t OBSTACLE_EDGE_CLEAR_COLUMNS = 2;
constexpr int64_t ARMY_SLOT_COUNT = 7; // HeroCommandRules.ARMY_SLOT_COUNT

// session.overworld of a SessionData or a session view.
DictRef session_overworld(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::overworld));
}

// d.get(key, {}) where the Dictionary is passed on: the stored one, or a new one.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// d.get(key, []) where the Array is passed on: the stored one, or a new one.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// String(d.get(key, "")).
Atom string_of(State &state, DictRef dict, Atom field) {
	return gd::stringify(state, gd::field_or(state, dict, field, str(key::empty)));
}

// ProfileLog.env_enabled(name): OS.get_environment(name).strip_edges().to_lower()
// in ["1", "true", "yes", "on", "enabled"]. The words are ASCII, so ASCII
// lowering finds the same ones.
bool profile_env_enabled(const char *name) {
	std::string value;
#ifdef _MSC_VER
	char *buffer = nullptr;
	size_t length = 0;
	if (_dupenv_s(&buffer, &length, name) == 0 && buffer != nullptr) {
		value = buffer;
		std::free(buffer);
	}
#else
	if (const char *found = std::getenv(name)) {
		value = found;
	}
#endif
	size_t begin = 0;
	size_t end = value.size();
	while (begin < end && static_cast<unsigned char>(value[begin]) <= 32) {
		++begin;
	}
	while (end > begin && static_cast<unsigned char>(value[end - 1]) <= 32) {
		--end;
	}
	std::string word = value.substr(begin, end - begin);
	for (char &c : word) {
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
		}
	}
	return word == "1" || word == "true" || word == "yes" || word == "on" || word == "enabled";
}

// ProfileLog.general_enabled().
bool profile_general_enabled() {
	return profile_env_enabled("HEROES_PROFILE_LOG") || profile_env_enabled("HEROES_OVERWORLD_PROFILE_LOG");
}

// ProfileLog.elapsed_ms(started_usec).
double elapsed_ms(int64_t started_usec) {
	return compat::snappedf(static_cast<double>(engine_max<int64_t>(0, gd::ticks_usec() - started_usec)) / 1000.0, 0.001);
}

// ProfileLog.emit_general("battle", "payload", event, total_ms, buckets,
// metadata, session), which writes only while profiling is on: then a host
// call. A session the rules built (a Dictionary view, the AI's preview) is
// no object to GDScript, and its record carries no session metadata.
void emit_payload_profile(State &state, Atom event, double total_ms, DictRef buckets, DictRef metadata, const Value &session) {
	const Value session_object = session.kind == Kind::Opaque ? session : Value();
	gd::call_static(state, key::profile_log_script, key::emit_general,
			{ str(key::battle), str(key::payload), str(event), gd::float_value(total_ms), dict_value(buckets), dict_value(metadata), session_object });
}

// An untyped clamp() of ints: an int.
int64_t clamp_int(int64_t value, int64_t low, int64_t high) {
	return engine_clamp<int64_t>(value, low, high);
}

} // namespace

DictRef create_battle_payload(State &state, const Value &session, DictRef encounter_placement) {
	const int64_t profile_started = gd::ticks_usec();
	const bool profiling = profile_general_enabled();
	const DictRef buckets = state.new_dict();
	int64_t phase_started = gd::ticks_usec();
	overworld_rules::normalize_overworld_state(state, gd::object_view(state, session));
	if (profiling) {
		state.set(buckets, str(key::normalize_overworld), gd::float_value(elapsed_ms(phase_started)));
	}
	phase_started = gd::ticks_usec();
	encounter_placement = _resolved_encounter_placement(state, session, encounter_placement);
	const Atom encounter_id = gd::stringify(state,
			gd::field_or(state, encounter_placement, key::encounter_id, gd::field_or(state, encounter_placement, key::id, str(key::empty))));
	const DictRef encounter = gd::content_row(state, state::ContentTable::Encounter, encounter_id);
	if (gd::is_empty(state, encounter)) {
		if (profiling) {
			const DictRef metadata = state.new_dict();
			state.set(metadata, str(key::encounter_id), str(encounter_id));
			state.set(metadata, str(key::reason), str(key::missing_encounter_content));
			emit_payload_profile(state, key::create_battle_payload_failed, elapsed_ms(profile_started), buckets, metadata, session);
		}
		return state.new_dict();
	}
	if (profiling) {
		state.set(buckets, str(key::resolve_encounter), gd::float_value(elapsed_ms(phase_started)));
	}

	phase_started = gd::ticks_usec();
	const DictRef scenario = gd::content_row(state, state::ContentTable::Scenario, gd::to_string(gd::member(state, session, key::scenario_id)));
	const DictRef battle_context = _normalized_battle_context(state, session, dict_value(encounter_placement));
	const DictRef player_setup = _player_setup_for_battle(state, session, encounter_placement, battle_context);
	const DictRef enemy_army = _enemy_army_for_battle(state, session, encounter_placement, encounter, battle_context);
	const DictRef enemy_hero_state = _enemy_commander_state_for_battle(state, session, encounter_placement, encounter, battle_context);
	const Value player_commander_state = gd::field_or(state, player_setup, key::commander_state, field_or_new_dict(state, session_overworld(state, session), key::hero));
	const ArrayRef battlefield_tags = _normalized_battlefield_tags(state, encounter, dict_value(battle_context));
	if (profiling) {
		state.set(buckets, str(key::setup_payload_inputs), gd::float_value(elapsed_ms(phase_started)));
	}
	phase_started = gd::ticks_usec();
	const DictRef battle = state.new_dict();
	{
		const DictRef where = state.new_dict();
		state.set(where, str(key::x), int_value(gd::to_int(state, gd::field_or(state, encounter_placement, key::x,
				int_value(overworld_rules::hero_position(state, gd::object_view(state, session)).x)))));
		state.set(where, str(key::y), int_value(gd::to_int(state, gd::field_or(state, encounter_placement, key::y,
				int_value(overworld_rules::hero_position(state, gd::object_view(state, session)).y)))));
		state.set(where, str(key::level), int_value(overworld_level_rules::level_of(state, dict_value(encounter_placement))));
		state.set(battle, str(key::position), dict_value(overworld_level_rules::position(state, where)));
	}
	state.set(battle, str(key::encounter_id), str(encounter_id));
	state.set(battle, str(key::encounter_name), str(_battle_name(state, session, encounter, battle_context, encounter_placement)));
	state.set(battle, str(key::resolved_key), str(overworld_rules::encounter_key(state, encounter_placement)));
	state.set(battle, str(key::terrain), str(gd::stringify(state, gd::field_or(state, encounter, key::terrain, str(key::plains)))));
	state.set(battle, str(key::encounter_difficulty), str(_battle_difficulty_value(state, encounter_placement, encounter)));
	state.set(battle, str(key::battlefield_tags), array_value(battlefield_tags));
	state.set(battle, str(key::combat_seed), int_value(_new_battle_combat_seed(state, session, encounter_placement, encounter_id)));
	state.set(battle, str(key::round), int_value(1));
	state.set(battle, str(key::max_rounds), int_value(engine_max<int64_t>(1, gd::int_field(state, encounter, key::max_rounds, 12))));
	state.set(battle, str(key::context), dict_value(battle_context));
	state.set(battle, str(key::enemy_army_id), str(string_of(state, enemy_army, key::id)));
	state.set(battle, str(key::enemy_army_name), str(_battle_enemy_army_name(state, enemy_army, battle_context, session)));
	state.set(battle, str(key::enemy_army_affiliation), str(_army_affiliation(state, enemy_army)));
	state.set(battle, str(key::retreat_allowed), gd::bool_value(!_is_town_defense_context(state, dict_value(battle_context))));
	state.set(battle, str(key::surrender_allowed), gd::bool_value(!_is_town_defense_context(state, dict_value(battle_context))));
	state.set(battle, str(key::enemy_withdrawal_allowed), gd::bool_value(_enemy_withdrawal_allowed(state, session, battle_context, encounter_placement)));
	state.set(battle, str(key::player_commander_state),
			gd::is_dict(player_commander_state) ? dict_value(gd::deep_duplicate_dict(state, player_commander_state.ref)) : dict_value(state.new_dict()));
	state.set(battle, str(key::player_commander_source), field_or_new_dict(state, player_setup, key::commander_source));
	{
		const DictRef commander = gd::as_dict(player_commander_state);
		const DictRef bonuses = artifact_rules::aggregate_bonuses(state, gd::as_dict(player_commander_state));
		state.set(battle, str(key::player_hero), dict_value(_hero_payload_from_state(state, commander, bonuses, session, key::player)));
	}
	state.set(battle, str(key::enemy_hero), dict_value(enemy_hero_state));
	state.set(battle, str(key::enemy_hero_payload), dict_value(_enemy_hero_payload_from_state(state, enemy_hero_state, dict_value(state.new_dict()), session)));
	state.set(battle, str(key::stacks), array_value(state.new_array()));
	state.set(battle, str(key::turn_order), array_value(state.new_array()));
	state.set(battle, str(key::turn_index), int_value(0));
	state.set(battle, str(key::active_stack_id), str(key::empty));
	state.set(battle, str(key::selected_target_id), str(key::empty));
	state.set(battle, str(key::recent_events), array_value(state.new_array()));
	state.set(battle, str(key::battle_presentation_event_serial), int_value(0));
	state.set(battle, str(key::battle_presentation_events), array_value(state.new_array()));
	state.set(battle, str(key::battle_presentation_speed), str(key::normal));
	state.set(battle, str(key::stack_animation_states), dict_value(state.new_dict()));
	state.set(battle, str(key::animation_event_serial), int_value(0));
	state.set(battle, str(key::battle_animation_events), array_value(state.new_array()));
	state.set(battle, str(key::hex_board), dict_value(_hex_board_descriptor(state)));
	state.set(battle, str(key::occupied_hexes), dict_value(state.new_dict()));
	state.set(battle, str(key::commander_spell_cast_rounds), dict_value(state.new_dict()));
	state.set(battle, str(key::player_orders_given), int_value(0));
	state.set(battle, str(key::field_objectives),
			array_value(_normalize_field_objectives(state, array_value(state.new_array()), encounter, encounter_placement, scenario, dict_value(battle_context))));
	{
		const DictRef briefing = state.new_dict();
		state.set(briefing, str(key::signature), str(gd::format(state, key::s_s_2, { str(encounter_id), str(overworld_rules::encounter_key(state, encounter_placement)) })));
		state.set(briefing, str(key::shown), gd::bool_value(false));
		state.set(briefing, str(key::shown_round), int_value(0));
		state.set(battle, str(key::tactical_briefing), dict_value(briefing));
	}
	if (profiling) {
		state.set(buckets, str(key::assemble_payload), gd::float_value(elapsed_ms(phase_started)));
	}
	phase_started = gd::ticks_usec();

	const ArrayRef stacks = state.new_array();
	const Value player_stacks = field_or_new_array(state, player_setup, key::stacks);
	for (int64_t index = 0; index < ai::vsize(state, player_stacks); ++index) {
		const Value stack = ai::vindex(state, player_stacks, int_value(index));
		if (gd::is_dict(stack) && gd::int_field(state, stack.ref, key::count, 0) > 0) {
			const Atom unit_id = string_of(state, stack.ref, key::unit_id);
			const int64_t count = gd::int_field(state, stack.ref, key::count, 0);
			const DictRef source = gd::as_dict(field_or_new_dict(state, stack.ref, key::source));
			const int64_t slot_index = gd::int_field(state, stack.ref, key::slot_index, index);
			state.append(stacks, dict_value(_build_battle_stack(state, unit_id, count, key::player, index, source, slot_index)));
		}
	}

	const Value enemy_stacks = field_or_new_array(state, enemy_army, key::stacks);
	for (int64_t index = 0; index < ai::vsize(state, enemy_stacks); ++index) {
		const Value stack = ai::vindex(state, enemy_stacks, int_value(index));
		if (gd::is_dict(stack) && gd::int_field(state, stack.ref, key::count, 0) > 0) {
			const Atom unit_id = string_of(state, stack.ref, key::unit_id);
			const int64_t count = gd::int_field(state, stack.ref, key::count, 0);
			const DictRef source = _enemy_stack_source(state, encounter_placement, battle_context);
			const int64_t slot_index = gd::int_field(state, stack.ref, key::slot_index, index);
			state.append(stacks, dict_value(_build_battle_stack(state, unit_id, count, key::enemy, index, source, slot_index)));
		}
	}

	_apply_hero_battle_boosts(state, session, stacks, player_commander_state);
	state.set(battle, str(key::stacks), array_value(stacks));
	state.set(battle, str(key::battlefield_tags),
			array_value(_with_army_battlefield_tags(state, gd::as_array(field_or_new_array(state, battle, key::battlefield_tags)), stacks)));
	_apply_specialty_battle_starts(state, battle);
	const Atom town_context_type = string_of(state, battle_context, key::type);
	if (town_context_type == key::town_defense || town_context_type == key::town_assault) {
		const DictRef found = _find_town_by_placement(state, session, string_of(state, battle_context, key::town_placement_id));
		const DictRef defending_town = gd::as_dict(field_or_new_dict(state, found, key::town));
		town_development_rules::apply_defender_bonus(state, stacks, defending_town, town_context_type);
		town_battle_rules::prepare(state, battle, town_development_rules::active_buildings(state, defending_town),
				town_context_type == key::town_defense ? key::player : key::enemy);
	}
	_generate_battle_obstacles(state, battle);
	_ensure_battle_hex_state(state, battle);
	// The band is derived from where the armies deployed, never set up.
	_sync_distance_from_hexes(state, battle);
	_initialize_damage_rng_state(state, session, battle);
	_prepare_round(state, battle, 1);
	if (profiling) {
		state.set(buckets, str(key::stacks_and_round), gd::float_value(elapsed_ms(phase_started)));
		const DictRef metadata = state.new_dict();
		state.set(metadata, str(key::encounter_id), str(encounter_id));
		state.set(metadata, str(key::placement_id), str(string_of(state, encounter_placement, key::placement_id)));
		state.set(metadata, str(key::battle_context_type), str(string_of(state, battle_context, key::type)));
		state.set(metadata, str(key::scenario_found), gd::bool_value(!gd::is_empty(state, scenario)));
		state.set(metadata, str(key::stack_count), int_value(state.array_size(stacks)));
		emit_payload_profile(state, key::create_battle_payload, elapsed_ms(profile_started), buckets, metadata, session);
	}
	return battle;
}

// Visit buildings (Wayside Chapel, Muster Banner, Fortune Ring...) leave
// cohesion and momentum on the hero; its army spends them in the next battle.
void _apply_hero_battle_boosts(State &state, const Value &session, ArrayRef stacks, const Value &commander_state) {
	if (!gd::is_dict(commander_state)) {
		return;
	}
	const Value boosts = gd::field_or(state, commander_state.ref, key::battle_boosts, Value());
	if (!gd::is_dict(boosts) || gd::is_empty(state, boosts.ref)) {
		return;
	}
	const int64_t cohesion = gd::int_field(state, boosts.ref, key::cohesion, 0);
	const int64_t momentum = gd::int_field(state, boosts.ref, key::momentum, 0);
	for (const Value &stack : gd::items(state, array_value(stacks))) {
		if (!gd::is_dict(stack) || string_of(state, stack.ref, key::side) != key::player) {
			continue;
		}
		if (cohesion != 0) {
			state.set(stack.ref, str(key::cohesion_base),
					int_value(clamp_int(gd::add(gd::int_field(state, stack.ref, key::cohesion_base, 5), cohesion), COHESION_MIN, COHESION_MAX)));
			const int64_t current = gd::to_int(state, gd::field_or(state, stack.ref, key::cohesion, gd::field_or(state, stack.ref, key::cohesion_base, int_value(5))));
			state.set(stack.ref, str(key::cohesion), int_value(clamp_int(gd::add(current, cohesion), COHESION_MIN, COHESION_MAX)));
		}
		if (momentum != 0) {
			state.set(stack.ref, str(key::momentum), int_value(clamp_int(gd::add(gd::int_field(state, stack.ref, key::momentum, 0), momentum), 0, MOMENTUM_MAX)));
		}
	}
	const DictRef overworld = session_overworld(state, session);
	const Value hero = gd::field_or(state, overworld, key::hero, Value());
	if (gd::is_dict(hero) && string_of(state, hero.ref, key::id) != key::empty
			&& string_of(state, hero.ref, key::id) == string_of(state, commander_state.ref, key::id)) {
		state.erase(hero.ref, str(key::battle_boosts));
		state.set(session_overworld(state, session), str(key::hero), hero);
		hero_command_rules::commit_active_hero(state, gd::object_view(state, session));
	}
}

// Commander specialties at the start of a battle: Banner of Resolve adds
// cohesion, Fortune's Favour momentum and Hardened Ranks creature health to
// that commander's stacks.
void _apply_specialty_battle_starts(State &state, DictRef battle) {
	const ArrayRef stacks = gd::as_array(field_or_new_array(state, battle, key::stacks));
	for (const Atom side : { key::player, key::enemy }) {
		const DictRef hero = _hero_payload_for_side(state, battle, side);
		const int64_t cohesion = gd::int_field(state, hero, key::battle_cohesion, 0);
		const int64_t momentum = gd::int_field(state, hero, key::battle_momentum, 0);
		const int64_t health_pct = gd::int_field(state, hero, key::creature_health_pct, 0);
		if (cohesion == 0 && momentum == 0 && health_pct == 0) {
			continue;
		}
		for (int64_t index = 0; index < state.array_size(stacks); ++index) {
			const Value stack = state.at(stacks, index);
			if (!gd::is_dict(stack) || string_of(state, stack.ref, key::side) != side) {
				continue;
			}
			if (cohesion != 0) {
				state.set(stack.ref, str(key::cohesion_base),
						int_value(clamp_int(gd::add(gd::int_field(state, stack.ref, key::cohesion_base, 5), cohesion), COHESION_MIN, COHESION_MAX)));
				const int64_t current = gd::to_int(state, gd::field_or(state, stack.ref, key::cohesion, gd::field_or(state, stack.ref, key::cohesion_base, int_value(5))));
				state.set(stack.ref, str(key::cohesion), int_value(clamp_int(gd::add(current, cohesion), COHESION_MIN, COHESION_MAX)));
			}
			if (momentum != 0) {
				state.set(stack.ref, str(key::momentum), int_value(clamp_int(gd::add(gd::int_field(state, stack.ref, key::momentum, 0), momentum), 0, MOMENTUM_MAX)));
			}
			if (health_pct > 0) {
				int64_t unit_hp = engine_max<int64_t>(1, gd::int_field(state, stack.ref, key::unit_hp, 1));
				unit_hp = gd::add(unit_hp, engine_max<int64_t>(1, compat::int_div(gd::mul(unit_hp, health_pct), 100)));
				state.set(stack.ref, str(key::unit_hp), int_value(unit_hp));
				state.set(stack.ref, str(key::total_health), int_value(gd::mul(gd::int_field(state, stack.ref, key::base_count, 0), unit_hp)));
			}
			state.set_at(stacks, index, stack);
		}
	}
	state.set(battle, str(key::stacks), array_value(stacks));
}

DictRef _resolved_encounter_placement(State &state, const Value &session, DictRef encounter_placement) {
	if (session.kind == Kind::Nil) {
		return encounter_placement;
	}
	const Atom resolved_key = overworld_rules::encounter_key(state, encounter_placement);
	for (const Value &placement_value : gd::field_items(state, session_overworld(state, session), str(key::encounters))) {
		if (!gd::is_dict(placement_value)) {
			continue;
		}
		if (overworld_rules::encounter_key(state, placement_value.ref) == resolved_key) {
			return placement_value.ref;
		}
	}
	return encounter_placement;
}

bool _enemy_withdrawal_allowed(State &state, const Value &session, DictRef battle_context, DictRef encounter_placement) {
	if (_is_town_defense_context(state, dict_value(battle_context)) || _is_town_assault_context(state, dict_value(battle_context))) {
		return false;
	}
	if (_is_resource_assault_context(state, dict_value(battle_context))) {
		return _enemy_state_exists(state, session, _battle_context_controller_id(state, session, battle_context, dict_value(state.new_dict())));
	}
	return _enemy_state_exists(state, session, player_identity_rules::raid_controller_id(state, encounter_placement));
}

Atom _battle_name(State &state, const Value &session, DictRef encounter, DictRef battle_context, DictRef encounter_placement) {
	const Atom opposing_commander_name = _encounter_enemy_commander_name(state, encounter_placement, encounter);
	// String(encounter.get("name", encounter.get("id", fallback))).
	const auto encounter_name = [&](Atom fallback) {
		return gd::stringify(state, gd::field_or(state, encounter, key::name, gd::field_or(state, encounter, key::id, str(fallback))));
	};
	if (_is_town_assault_context(state, dict_value(battle_context))) {
		const Atom town_name = _town_name_from_placement_id(state, session, string_of(state, battle_context, key::town_placement_id));
		if (town_name != key::empty) {
			return gd::format(state, key::assault_on_s, { str(town_name) });
		}
	}
	if (_is_town_defense_context(state, dict_value(battle_context))) {
		const Atom town_name = _town_name_from_placement_id(state, session, string_of(state, battle_context, key::town_placement_id));
		if (town_name != key::empty) {
			if (opposing_commander_name != key::empty) {
				return gd::format(state, key::s_assaults_s, { str(opposing_commander_name), str(town_name) });
			}
			return gd::format(state, key::s_at_s, { str(encounter_name(key::enemy_army_3)), str(town_name) });
		}
	}
	if (_is_resource_assault_context(state, dict_value(battle_context))) {
		const Atom site_name = string_of(state, battle_context, key::resource_site_name);
		if (site_name != key::empty) {
			if (opposing_commander_name != key::empty) {
				return gd::format(state, key::s_defends_s, { str(opposing_commander_name), str(site_name) });
			}
			return gd::format(state, key::fight_for_s, { str(site_name) });
		}
	}
	if (string_of(state, battle_context, key::type) == key::hero_intercept) {
		const DictRef target = hero_command_rules::hero_by_id(state, gd::object_view(state, session), string_of(state, battle_context, key::target_hero_id));
		const Atom hero_name = string_of(state, target, key::name);
		if (hero_name != key::empty) {
			if (opposing_commander_name != key::empty) {
				return gd::format(state, key::s_intercepts_s, { str(opposing_commander_name), str(hero_name) });
			}
			return gd::format(state, key::s_intercepts_s, { str(encounter_name(key::enemy_army_3)), str(hero_name) });
		}
	}
	if (opposing_commander_name != key::empty && gd::is_dict(gd::field_or(state, encounter_placement, key::ai_hero, Value()))) {
		return gd::format(state, key::battle_with_s, { str(opposing_commander_name) });
	}
	if (opposing_commander_name != key::empty
			&& gd::stringify(state, gd::field_or(state, encounter, key::spawned_by_faction_id,
						   gd::field_or(state, encounter_placement, key::spawned_by_faction_id, str(key::empty))))
					!= key::empty) {
		return gd::format(state, key::s_s_s, { str(opposing_commander_name), str(encounter_name(key::Battle)) });
	}
	return encounter_name(key::Battle);
}

DictRef _enemy_stack_source(State &state, DictRef encounter_placement, DictRef battle_context) {
	const DictRef source = state.new_dict();
	if (_is_town_assault_context(state, dict_value(battle_context))) {
		state.set(source, str(key::source_type), str(key::town_garrison));
		state.set(source, str(key::town_placement_id), str(string_of(state, battle_context, key::town_placement_id)));
		return source;
	}
	if (_is_resource_assault_context(state, dict_value(battle_context))) {
		state.set(source, str(key::source_type), str(key::resource_defender));
		state.set(source, str(key::resource_placement_id), str(string_of(state, battle_context, key::resource_placement_id)));
		return source;
	}
	state.set(source, str(key::source_type), str(key::encounter_army));
	state.set(source, str(key::encounter_key), str(overworld_rules::encounter_key(state, encounter_placement)));
	return source;
}

DictRef _enemy_army_for_battle(State &state, const Value &session, DictRef encounter_placement, DictRef encounter, DictRef battle_context) {
	if (_is_town_assault_context(state, dict_value(battle_context))) {
		const DictRef found = _find_town_by_placement(state, session, string_of(state, battle_context, key::town_placement_id));
		const Value town = field_or_new_dict(state, found, key::town);
		const DictRef army = state.new_dict();
		state.set(army, str(key::id), str(gd::format(state, key::town_garrison_s_2, { str(string_of(state, battle_context, key::town_placement_id)) })));
		state.set(army, str(key::name), str(gd::format(state, key::s_garrison, { str(_town_name(state, gd::as_dict(town))) })));
		const Value garrison = ai::vget(state, town, key::garrison, Value());
		state.set(army, str(key::stacks),
				gd::is_array(garrison) ? array_value(gd::deep_duplicate_array(state, garrison.ref)) : array_value(state.new_array()));
		return army;
	}
	if (_is_resource_assault_context(state, dict_value(battle_context))) {
		const DictRef found = overworld_rules::_find_resource_node_by_placement(state, gd::object_view(state, session), string_of(state, battle_context, key::resource_placement_id));
		const DictRef node = gd::as_dict(field_or_new_dict(state, found, key::node));
		// node.get("ai_defender_army", {}): a missing key is an empty Dictionary too.
		Value defender_army;
		if (!state.lookup(node, str(key::ai_defender_army), defender_army)) {
			return state.new_dict();
		}
		if (gd::is_dict(defender_army)) {
			return gd::deep_duplicate_dict(state, defender_army.ref);
		}
	}
	return _enemy_army_for_encounter(state, encounter_placement, encounter);
}

Atom _army_affiliation(State &state, DictRef army) {
	const Atom affiliation = string_of(state, army, key::affiliation);
	if (affiliation != key::empty) {
		return affiliation;
	}
	return string_of(state, army, key::faction_id) != key::empty ? key::faction : key::neutral;
}

DictRef _player_setup_for_battle(State &state, const Value &session, DictRef encounter_placement, DictRef battle_context) {
	(void)encounter_placement;
	if (!_is_town_defense_context(state, dict_value(battle_context))) {
		const Value active_hero = field_or_new_dict(state, session_overworld(state, session), key::hero);
		const DictRef setup = state.new_dict();
		state.set(setup, str(key::commander_state), active_hero);
		const DictRef commander_source = state.new_dict();
		state.set(commander_source, str(key::type), str(key::active_hero));
		state.set(commander_source, str(key::hero_id), str(gd::stringify(state, ai::vget(state, active_hero, key::id, str(key::empty)))));
		state.set(setup, str(key::commander_source), dict_value(commander_source));
		const Value army = field_or_new_dict(state, session_overworld(state, session), key::army);
		const DictRef source = state.new_dict();
		state.set(source, str(key::source_type), str(key::hero_army));
		state.set(source, str(key::hero_id), str(gd::stringify(state, ai::vget(state, active_hero, key::id, str(key::empty)))));
		state.set(setup, str(key::stacks), array_value(_army_stack_descriptors(state, army, source)));
		return setup;
	}

	const DictRef found = _find_town_by_placement(state, session, string_of(state, battle_context, key::town_placement_id));
	const Value town = field_or_new_dict(state, found, key::town);
	const DictRef defense_force = hero_command_rules::town_defense_force(state, gd::object_view(state, session), gd::as_dict(town),
			string_of(state, battle_context, key::defending_hero_id));
	const DictRef defending_hero = gd::as_dict(gd::index(state, defense_force, str(key::hero)));
	const DictRef commander_state = !gd::is_empty(state, defending_hero) ? defending_hero : _town_captain_state(state, gd::as_dict(town));
	const DictRef commander_source = state.new_dict();
	state.set(commander_source, str(key::type), str(!gd::is_empty(state, defending_hero) ? key::town_hero : key::town_captain_2));
	state.set(commander_source, str(key::hero_id), str(string_of(state, defending_hero, key::id)));
	state.set(commander_source, str(key::town_placement_id), str(gd::stringify(state, ai::vget(state, town, key::placement_id, str(key::empty)))));
	const ArrayRef player_stacks = gd::as_array(gd::index(state, defense_force, str(key::stacks)));
	const DictRef setup = state.new_dict();
	state.set(setup, str(key::commander_state), dict_value(commander_state));
	state.set(setup, str(key::commander_source), dict_value(commander_source));
	state.set(setup, str(key::stacks), array_value(player_stacks));
	return setup;
}

ArrayRef _army_stack_descriptors(State &state, const Value &army, DictRef source) {
	const ArrayRef descriptors = state.new_array();
	if (!gd::is_dict(army)) {
		return descriptors;
	}
	for (const Value &stack_value : gd::field_items(state, army.ref, str(key::stacks))) {
		if (!gd::is_dict(stack_value)) {
			continue;
		}
		const Atom unit_id = string_of(state, stack_value.ref, key::unit_id);
		const int64_t count = engine_max<int64_t>(0, gd::int_field(state, stack_value.ref, key::count, 0));
		if (unit_id == key::empty || count <= 0) {
			continue;
		}
		const DictRef descriptor = state.new_dict();
		state.set(descriptor, str(key::unit_id), str(unit_id));
		state.set(descriptor, str(key::count), int_value(count));
		state.set(descriptor, str(key::source), dict_value(gd::deep_duplicate_dict(state, source)));
		const int64_t slot_index = gd::int_field(state, stack_value.ref, key::slot_index, -1);
		if (slot_index >= 0 && slot_index < ARMY_SLOT_COUNT) {
			state.set(descriptor, str(key::slot_index), int_value(slot_index));
		}
		state.append(descriptors, dict_value(descriptor));
	}
	return descriptors;
}

Atom _battle_difficulty_value(State &state, DictRef encounter_placement, DictRef encounter) {
	Atom difficulty = gd::strip_edges(state, string_of(state, encounter_placement, key::difficulty));
	if (difficulty == key::empty) {
		// encounter_placement.get("encounter_ref", {}): a missing key reads as "".
		const Value encounter_ref = gd::field_or(state, encounter_placement, key::encounter_ref, Value());
		if (gd::is_dict(encounter_ref)) {
			difficulty = gd::strip_edges(state, string_of(state, encounter_ref.ref, key::difficulty));
		}
	}
	if (difficulty == key::empty) {
		difficulty = gd::strip_edges(state, string_of(state, encounter, key::difficulty));
	}
	return difficulty;
}

Atom _battle_enemy_army_name(State &state, DictRef enemy_army, DictRef battle_context, const Value &session) {
	const Atom army_name = gd::strip_edges(state, string_of(state, enemy_army, key::name));
	if (army_name != key::empty) {
		return army_name;
	}
	if (_is_town_assault_context(state, dict_value(battle_context)) || _is_town_defense_context(state, dict_value(battle_context))) {
		const Atom town_name = _town_name_from_placement_id(state, session, string_of(state, battle_context, key::town_placement_id));
		if (town_name != key::empty) {
			return gd::format(state, key::s_garrison, { str(town_name) });
		}
	}
	return key::enemy_force;
}

void _generate_battle_obstacles(State &state, DictRef battle) {
	const ArrayRef obstacles = state.new_array();
	const Value context = gd::field_or(state, battle, key::context, Value());
	if (gd::is_dict(context)) {
		const Atom type = string_of(state, context.ref, key::type);
		if (type == key::town_defense || type == key::town_assault) {
			state.set(battle, str(key::obstacles), array_value(obstacles));
			return;
		}
	}
	compat::GodotPcg rng;
	const Atom seed_text = gd::format(state, key::s_s_obstacles_v1,
			{ str(gd::stringify(state, gd::field_or(state, battle, key::combat_seed, str(key::empty)))), str(string_of(state, battle, key::terrain)) });
	rng.seed(static_cast<uint64_t>(gd::hash(state, str(seed_text))));
	const int64_t target_count = rng.randi_range(OBSTACLE_MIN_COUNT, OBSTACLE_MAX_COUNT);
	DictRef blocked = state.new_dict();
	int64_t attempts = 0;
	while (state.array_size(obstacles) < target_count && attempts < 64) {
		attempts += 1;
		const int64_t size = rng.randf() < 0.4 ? 2 : 1;
		const int64_t q = rng.randi_range(OBSTACLE_EDGE_CLEAR_COLUMNS, BATTLE_HEX_COLUMNS - 1 - OBSTACLE_EDGE_CLEAR_COLUMNS - (size - 1));
		const int64_t r = rng.randi_range(0, BATTLE_HEX_ROWS - 1);
		// OBSTACLE_KINDS = ["rock", "deadwood"]
		const Atom kind = rng.randi_range(0, 1) == 0 ? key::rock : key::deadwood;
		const int64_t variant = rng.randi_range(0, OBSTACLE_VARIANT_COUNT - 1);
		const ArrayRef cells = state.new_array();
		state.append(cells, dict_value(_hex_cell(state, q, r)));
		if (size == 2) {
			state.append(cells, dict_value(_hex_cell(state, q + 1, r)));
		}
		if (!_obstacle_cells_clear(state, cells, blocked)) {
			continue;
		}
		const DictRef trial = gd::duplicate_dict(state, blocked);
		for (const Value &cell : gd::items(state, array_value(cells))) {
			state.set(trial, str(_hex_key(state, gd::as_dict(cell))), str(key::obstacle_prefix));
		}
		if (!_obstacle_field_stays_open(state, trial)) {
			continue;
		}
		blocked = trial;
		const DictRef obstacle = state.new_dict();
		state.set(obstacle, str(key::id), str(gd::format(state, key::o_d, { int_value(gd::add(state.array_size(obstacles), 1)) })));
		state.set(obstacle, str(key::kind), str(kind));
		state.set(obstacle, str(key::size), int_value(size));
		state.set(obstacle, str(key::variant), int_value(variant));
		state.set(obstacle, str(key::cells), array_value(cells));
		state.append(obstacles, dict_value(obstacle));
	}
	state.set(battle, str(key::obstacles), array_value(obstacles));
}

bool _obstacle_cells_clear(State &state, ArrayRef cells, DictRef blocked) {
	for (const Value &cell : gd::items(state, array_value(cells))) {
		if (state.has(blocked, str(_hex_key(state, gd::as_dict(cell))))) {
			return false;
		}
		for (const Value &neighbor : gd::items(state, array_value(_hex_neighbors(state, gd::as_dict(cell))))) {
			if (state.has(blocked, str(_hex_key(state, gd::as_dict(neighbor))))) {
				return false;
			}
		}
	}
	return true;
}

// A two-hex body of either side can still walk from its own edge to the other.
bool _obstacle_field_stays_open(State &state, DictRef blocked) {
	uint8_t open[BATTLE_HEX_COLUMNS * BATTLE_HEX_ROWS];
	_hex_open_mask(state, state.new_dict(), blocked, open);
	return battle_hex::field_stays_open(open);
}

// The ground's tags plus those the armies bring (factions.json
// "brings_battlefield_tags"): a Veilmourn fleet fights in its own fog bank.
ArrayRef _with_army_battlefield_tags(State &state, ArrayRef tags, ArrayRef stacks) {
	const ArrayRef result = gd::duplicate_array(state, tags);
	for (const Value &stack : gd::items(state, array_value(stacks))) {
		if (!gd::is_dict(stack)) {
			continue;
		}
		for (const Value &tag_value : gd::items(state, array_value(battle_ai_rules::faction_brought_tags(state, stack.ref)))) {
			const Atom tag = gd::stringify(state, tag_value);
			if (!gd::array_has(state, result, str(tag))) {
				state.append(result, str(tag));
			}
		}
	}
	return result;
}

ArrayRef _normalized_battlefield_tags(State &state, DictRef encounter, const Value &context) {
	const ArrayRef normalized = state.new_array();
	for (const Value &tag_value : gd::field_items(state, encounter, str(key::battlefield_tags))) {
		const Atom tag_id = gd::stringify(state, tag_value);
		if (tag_id != key::empty && !gd::array_has(state, normalized, str(tag_id))) {
			state.append(normalized, str(tag_id));
		}
	}
	if (_is_town_defense_context(state, context) || _is_town_assault_context(state, context)) {
		for (const Atom tag_id : { key::fortified_line, key::chokepoint }) {
			if (!gd::array_has(state, normalized, str(tag_id))) {
				state.append(normalized, str(tag_id));
			}
		}
		// context.get("battlefront_tags", []): a town context is a Dictionary.
		for (const Value &tag_value : gd::field_items(state, gd::as_dict(context), str(key::battlefront_tags))) {
			const Atom context_tag = gd::stringify(state, tag_value);
			if (context_tag != key::empty && !gd::array_has(state, normalized, str(context_tag))) {
				state.append(normalized, str(context_tag));
			}
		}
	}
	return normalized;
}

int64_t _new_battle_combat_seed(State &state, const Value &session, DictRef encounter_placement, Atom encounter_id) {
	const int64_t authored = gd::int_field(state, encounter_placement, key::combat_seed, 0);
	if (authored != 0) {
		return authored;
	}
	const int64_t serial = gd::add(gd::int_field(state, session_overworld(state, session), key::battle_seed_serial, 0), 1);
	state.set(session_overworld(state, session), str(key::battle_seed_serial), int_value(serial));
	// An Array hash mixes every part; a String hash of text that differs only in
	// the serial would give neighbouring battles neighbouring seeds.
	const ArrayRef parts = state.new_array();
	state.append(parts, gd::member(state, session, key::session_id));
	state.append(parts, str(encounter_id));
	state.append(parts, str(overworld_rules::encounter_key(state, encounter_placement)));
	state.append(parts, int_value(gd::to_int(state, gd::member(state, session, key::day))));
	state.append(parts, int_value(serial));
	const int64_t seed = gd::hash(state, array_value(parts));
	return seed != 0 ? seed : 1;
}

} // namespace aurelion::rules::port::battle_rules

namespace aurelion::rules::port::town_development_rules {

namespace key = state::key;

void apply_defender_bonus(State &state, ArrayRef stacks, DictRef town, Atom context_type) {
	if (context_type != key::town_defense && context_type != key::town_assault) {
		return;
	}
	int64_t bonus = 0;
	for (const Value &id : gd::items(state, gd::array_value(active_buildings(state, town)))) {
		const DictRef building = gd::content_row(state, state::ContentTable::Building, gd::stringify(state, id));
		bonus = gd::add(bonus, gd::int_field(state, building, key::defender_defense_bonus, 0));
	}
	const Atom side = context_type == key::town_defense ? key::player : key::enemy;
	for (const Value &stack : gd::items(state, gd::array_value(stacks))) {
		if (gd::equal(state, ai::vget(state, stack, key::side, gd::str(key::empty)), gd::str(side))) {
			state.set(gd::as_dict(stack), gd::str(key::defense), gd::int_value(gd::add(gd::int_field(state, gd::as_dict(stack), key::defense, 0), bonus)));
		}
	}
}

} // namespace aurelion::rules::port::town_development_rules
