// EnemyTurnRules.normalize_enemy_states: the computer players' states rebuilt from their configs, then their raid
// hosts and commander rosters. The day-only functions it reaches are defined
// here under their scripts' namespaces; the shared ones are in their scripts'
// files. The paths AI matches never run are left to GDScript (state::NotPorted):
// a roster memo already open, legacy raid hosts, defender commanders, old
// saves' memories and hero task boards, configs without player records.

#include "aurelion_rules/port/ai_hero_rules.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/difficulty_rules.hpp"
#include "aurelion_rules/port/enemy_adventure_rules.hpp"
#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/enemy_turn_rules.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_string.hpp"

#include <algorithm>
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
using state::State;
using state::Value;
namespace key = state::key;
namespace player_rules = player_identity_rules;

[[noreturn]] void not_ported(const char *path) {
	throw state::NotPorted(std::string("left to GDScript: ") + path);
}

// String(d.get(key, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify_or_fallback(state, state.get(dict, str(field), str(fallback)));
}

// String(d.get(key, fallback)) with an untyped fallback.
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return gd::stringify_or_fallback(state, state.get(dict, str(field), fallback));
}

// max(a, b) and clamp(x, lo, hi) of ints: an int.
int64_t imax(int64_t a, int64_t b) {
	return compat::engine_max<int64_t>(a, b);
}
int64_t iclamp(int64_t x, int64_t lo, int64_t hi) {
	return compat::engine_clamp<int64_t>(x, lo, hi);
}

// max(0, int(d.get(key, 0))).
int64_t count_field(State &state, DictRef dict, Atom field) {
	return imax(0, gd::int_field(state, dict, field, 0));
}

// `value if value is Dictionary else {}`.
DictRef dict_or_new(State &state, const Value &value) {
	return gd::is_dict(value) ? value.ref : state.new_dict();
}

// d.get(key, {}) and d.get(key, []): a new container when the key is missing.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}
Value get_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// `d.get(key, {}) if d.get(key, {}) is Dictionary else {}`.
DictRef dict_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// x.get(key, fallback) on an untyped value: only a Dictionary has the
// two-argument get.
Value variant_get(State &state, const Value &target, Atom field, const Value &fallback) {
	if (!gd::is_dict(target)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' with two arguments in base '") + gd::type_name(target) + "'.");
	}
	return state.get(target.ref, str(field), fallback);
}

// value in [ids...] of a String.
bool one_of(Atom value, std::initializer_list<Atom> ids) {
	for (const Atom id : ids) {
		if (id == value) {
			return true;
		}
	}
	return false;
}

// " | ".join(parts).
Atom join_parts(State &state, const std::vector<std::string> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += " | ";
		}
		joined += parts[index];
	}
	return state.intern(joined);
}

// The specialty catalog's row of an id, {} when it has none
// (HeroProgressionRules._specialty_row over one catalog: a native call builds
// the catalog once, from the same content).
DictRef specialty_row(State &state, DictRef catalog, Atom specialty_id) {
	Value row;
	return state.lookup(catalog, str(specialty_id), row) ? gd::as_dict(row) : state.new_dict();
}

// EnemyTurnRules.TRACKED_RESOURCES.
constexpr Atom kTrackedResources[] = {
	key::gold,
	key::wood,
	key::ore,
	key::aetherglass,
	key::embergrain,
	key::peatwax,
	key::verdant_grafts,
	key::brass_scrip,
	key::memory_salt,
};

// EnemyTurnRules.AI_PLAYER_STATE_KEYS.
constexpr Atom kAiPlayerStateKeys[] = {
	key::ai_start_hero_granted,
	key::ai_opening_granted,
	key::ai_tavern,
	key::ai_hero_counter,
	key::ai_explored,
	key::ai_boat_wanted_day,
	key::ai_sightings,
	key::ai_weight_set,
};

// The identity keys a normalized enemy state copies from its config.
constexpr Atom kConfigIdentityKeys[] = {
	key::player_id,
	key::player_slot,
	key::team_id,
};

// EnemyTurnRules.REBUILD_PRESSURE_LAUNCH_WINDOW_DAYS and
// EnemyAdventureRules.RAID_RECENT_EXPLORATION_TARGET_LIMIT.
constexpr int64_t kRebuildPressureLaunchWindowDays = 5;
constexpr int64_t kRaidRecentExplorationTargetLimit = 12;

// EnemyAdventureRules.COMMANDER_VETERANCY_LABELS.
constexpr Atom kCommanderVeterancyLabels[] = {
	key::empty,
	key::blooded,
	key::veteran_label,
	key::war_hardened,
};

// The memory keys _normalized_commander_memory takes from an entry.
constexpr Atom kCommanderMemoryKeys[] = {
	key::focus_target_kind,
	key::focus_target_id,
	key::focus_target_label,
	key::focus_pressure_count,
	key::last_target_kind,
	key::last_target_id,
	key::last_target_label,
	key::front_label,
	key::front_x,
	key::front_y,
	key::rival_kind,
	key::rival_id,
	key::rival_label,
	key::rivalry_count,
	key::target_success_counts,
	key::target_failure_counts,
	key::last_success_target_kind,
	key::last_success_outcome,
	key::last_failure_target_kind,
	key::last_failure_outcome,
};

// AiHeroRules.MIGRATION_VERSION.
constexpr int64_t kAiHeroesMigrationVersion = 1;

// HeroProgressionRules.CHOICE_SIZE and the OFFER_*_WEIGHT draw weights.
constexpr int64_t kChoiceSize = 3;
constexpr double kOfferFocusWeight = 4.0;
constexpr double kOfferPathWeight = 2.5;
constexpr double kOfferOtherWeight = 1.0;

// HeroProgressionRules.COMMAND_GAIN_WEIGHTS.has(path).
bool is_command_path(Atom path) {
	return path == key::might || path == key::magic;
}

// s.hex_to_int() of lower-case hex digits (a SHA-256 digest's prefix).
int64_t hex_digits_to_int(const std::string &digits) {
	int64_t value = 0;
	for (const char c : digits) {
		value = value * 16 + (c >= 'a' ? c - 'a' + 10 : c - '0');
	}
	return value;
}

// A static var of EnemyAdventureRules.
Value adventure_static(State &state, Atom name) {
	return gd::static_var(state, key::enemy_adventure_rules_script, name);
}

} // namespace

// The day-only functions defined here, in their scripts' namespaces.

namespace hero_progression_rules {
DictRef ensure_hero_progression(State &state, DictRef hero_state);
ArrayRef _normalize_specialties(State &state, const Value &value);
ArrayRef _normalize_pending_choices(State &state, const Value &value, DictRef hero_state);
DictRef _reconcile_pending_choices(State &state, DictRef hero_state);
DictRef _enqueue_missing_choice_groups(State &state, DictRef hero_state);
int64_t raw_pending_choices_remaining(State &state, DictRef hero_state);
int64_t mana_max_bonus(State &state, DictRef hero_state);
DictRef _specialty_row(State &state, Atom specialty_id);
int64_t max_rank_for_specialty(State &state, Atom specialty_id);
int64_t specialty_rank(State &state, DictRef hero_state, Atom specialty_id);
Value specialties(State &state);
int64_t max_specialties_per_hero(State &state);
int64_t _distinct_specialty_count(State &state, DictRef hero_state);
bool _specialty_is_available(State &state, DictRef hero_state, Atom specialty_id);
ArrayRef available_specialty_ids(State &state, DictRef hero_state);
Atom growth_seed(State &state, DictRef hero_state);
Atom command_path(State &state, DictRef hero_state);
ArrayRef _normalize_specialty_id_list(State &state, const Value &value);
ArrayRef _offer_order(State &state, DictRef hero_state, int64_t level_number);
DictRef _build_choice_group(State &state, DictRef hero_state, int64_t level_number);
DictRef current_pending_choice(State &state, DictRef hero_state);
DictRef specialty_definition(State &state, Atom specialty_id);
DictRef choose_specialty(State &state, DictRef hero_state, Atom specialty_id);
} // namespace hero_progression_rules

namespace spell_rules {
DictRef ensure_hero_spellbook(State &state, DictRef hero_state, DictRef hero_template);
int64_t mana_max_from_hero(State &state, DictRef hero_state);
int64_t mana_max_from_command(State &state, const Value &command);
} // namespace spell_rules

namespace enemy_adventure_rules {
void normalize_raid_armies(State &state, DictRef session);
void normalize_all_commander_rosters(State &state, DictRef session);
ArrayRef normalize_commander_roster(State &state, DictRef session, Atom faction_id, const Value &roster_value);
DictRef normalize_enemy_known_world_memory(State &state, const Value &value, int64_t current_day);
ArrayRef _normalize_enemy_scouted_target_records(State &state, const Value &value, int64_t current_day);
ArrayRef _normalize_enemy_hero_sighting_records(State &state, const Value &value, int64_t current_day);
DictRef ensure_raid_army(State &state, DictRef encounter, DictRef session, DictRef occupied_commander_ids);
DictRef build_raid_commander_state(State &state, DictRef encounter, Atom roster_hero_id, Atom faction_id, DictRef session, DictRef occupied_commander_ids, const Value &commander_roster);
DictRef build_roster_commander_state(State &state, Atom roster_hero_id, Atom faction_id, DictRef existing_state, const Value &record_source);
DictRef sync_commander_army_continuity(State &state, DictRef commander_state, const Value &army_source, Atom encounter_id);
Value commander_roster_for_faction(State &state, DictRef session, Atom faction_id);
ArrayRef _normalize_commander_roster_entries(State &state, DictRef session, Atom faction_id, const Value &roster_value, const Value &selected_hero_ids);
DictRef _normalize_commander_roster_entry(State &state, DictRef session, Atom faction_id, const Value &roster_value, Atom roster_hero_id);
DictRef _active_commander_map(State &state, DictRef session, Atom faction_id, const Value &hero_ids);
DictRef _resolved_encounter_lookup(State &state, const Value &resolved_encounters);
bool _fallen_hero_settled(State &state, DictRef session, DictRef encounter, DictRef resolved_lookup, DictRef fallen_seen_day);
ArrayRef _faction_commander_ids(State &state, Atom faction_id);
void _normalize_town_defender_commander_states(State &state, DictRef session);
void _normalize_resource_defender_commander_states(State &state, DictRef session);
bool _town_has_ai_defender(State &state, DictRef town);
bool _resource_has_ai_defender(State &state, DictRef node);
DictRef _normalized_commander_record(State &state, const Value &entry_value, const Value &commander_state_value);
DictRef _normalized_commander_memory(State &state, const Value &entry_value, const Value &commander_state_value);
DictRef _normalized_commander_army_continuity(State &state, const Value &entry_value, const Value &commander_state_value, Atom encounter_id);
DictRef _normalized_commander_role_state(State &state, const Value &source, const Value &fallback_source);
DictRef _normalized_commander_target_kind_counts(State &state, const Value &value);
DictRef _apply_commander_army_metadata(State &state, DictRef commander_state, const Value &army_source);
DictRef _apply_commander_memory_metadata(State &state, DictRef commander_state, const Value &memory_source);
DictRef _apply_commander_record_metadata(State &state, DictRef commander_state, const Value &record_source);
DictRef _apply_commander_role_metadata(State &state, DictRef commander_state, const Value &role_source);
int64_t _commander_renown_from_record(State &state, DictRef record);
int64_t _commander_veterancy_rank_from_record(State &state, DictRef record);
Atom commander_veterancy_label(State &state, const Value &source);
Atom commander_record_summary(State &state, const Value &source);
Atom commander_memory_brief(State &state, const Value &source);
Atom commander_memory_summary(State &state, const Value &source);
DictRef commander_army_continuity(State &state, const Value &source);
Atom commander_army_status(State &state, const Value &source);
Atom commander_army_brief(State &state, const Value &source);
Atom commander_army_summary(State &state, const Value &source);
bool _is_army_continuity_payload(State &state, const Value &value);
Atom _army_continuity_status(State &state, int64_t current_strength, int64_t base_strength);
Atom _army_continuity_summary(State &state, Atom status, int64_t current_strength, int64_t base_strength);
int64_t _army_headcount(State &state, const Value &stacks);
int64_t _army_strength(State &state, const Value &stacks);
int64_t _unit_strength_value(State &state, Atom unit_id);
DictRef _base_enemy_army(State &state, Atom encounter_id);
DictRef _normalize_army_payload(State &state, const Value &army);
DictRef _normalize_command_payload(State &state, const Value &value);
DictRef _normalize_enemy_progression(State &state, DictRef commander_state);
Atom _normalize_commander_status(State &state, const Value &value);
ArrayRef _normalize_string_array(State &state, const Value &value);
ArrayRef _merge_unique_strings(State &state, const Value &primary, const Value &secondary);
ArrayRef _normalized_specialty_ranks(State &state, const Value &primary, const Value &secondary);
ArrayRef _normalized_specialty_focus_ids(State &state, const Value &value);
ArrayRef _hero_starting_spell_ids(State &state, DictRef hero_template);
Atom _preferred_enemy_specialty_id(State &state, DictRef commander_state, DictRef pending_choice);
void _sync_specialty_pick(State &state);
} // namespace enemy_adventure_rules

namespace enemy_turn_rules {
void _normalize_enemy_states_body(State &state, DictRef session);
ArrayRef _enemy_faction_configs_for_session(State &state, DictRef session);
ArrayRef _enemy_faction_configs_with_runtime_defaults(State &state, DictRef session, ArrayRef configs);
DictRef _enemy_faction_config_with_runtime_defaults(State &state, DictRef session, DictRef config);
ArrayRef _default_raid_encounter_ids_for_faction(State &state, Atom faction_id);
ArrayRef _default_spawn_points_for_faction(State &state, DictRef session, Atom faction_id);
DictRef _find_state(State &state, const Value &states, Atom faction_id);
DictRef _blank_resource_pool(State &state);
DictRef _normalize_resource_pool(State &state, const Value &value);
Atom _normalize_posture(State &state, const Value &value);
ArrayRef _normalize_string_array(State &state, const Value &value);
DictRef _normalize_rebuild_pressure_request(State &state, const Value &value, int64_t current_day);
} // namespace enemy_turn_rules

namespace ai_hero_rules {
void migrate_legacy_raids(State &state, DictRef session);
DictRef normalize_ai_heroes(State &state, DictRef session, Atom only_controller);
} // namespace ai_hero_rules

// EnemyTurnRules.

namespace enemy_turn_rules {

void normalize_enemy_states(State &state, DictRef session) {
	if (text(state, session, key::scenario_id, key::empty) == key::empty) {
		return;
	}
	// The outermost normalization owns the roster entry memo and drops it at
	// the end. The memo only reuses entries built from the same inputs, so a
	// native normalization builds every entry and never opens it; one called
	// while a GDScript normalization holds it is left to GDScript.
	if (state.has(session_view::meta(state, session), gd::name_value(key::enemy_commander_entry_memo))) {
		not_ported("a normalization inside another");
	}
	_normalize_enemy_states_body(state, session);
}

void _normalize_enemy_states_body(State &state, DictRef session) {
	// DifficultyRules.normalize_session(session): the session's difficulty
	// normalized; its profile is discarded here.
	state.set(session, str(key::difficulty), str(difficulty_rules::normalize_difficulty(state, gd::field(state, session, key::difficulty))));

	const DictRef overworld = session_view::overworld(state, session);
	const int64_t day = gd::int_field(state, session, key::day, 0);
	const ArrayRef configs = _enemy_faction_configs_for_session(state, session);
	const Value existing_states = get_or_new_array(state, overworld, key::enemy_states);
	const ArrayRef normalized_states = state.new_array();

	for (const Value &config_value : gd::items(state, array_value(configs))) {
		if (!gd::is_dict(config_value)) {
			continue;
		}
		const DictRef config = config_value.ref;
		const Atom faction_id = player_rules::controller_id(state, config, key::empty);
		const DictRef existing_state = _find_state(state, existing_states, faction_id);
		const DictRef normalized_state = state.new_dict();
		state.set(normalized_state, str(key::faction_id), str(text(state, config, key::faction_id, key::empty)));
		state.set(normalized_state, str(key::pressure), int_value(count_field(state, existing_state, key::pressure)));
		state.set(normalized_state, str(key::raid_counter), int_value(count_field(state, existing_state, key::raid_counter)));
		state.set(normalized_state, str(key::commander_counter), int_value(count_field(state, existing_state, key::commander_counter)));
		state.set(normalized_state, str(key::siege_progress), int_value(count_field(state, existing_state, key::siege_progress)));
		state.set(normalized_state, str(key::treasury), dict_value(_normalize_resource_pool(state, get_or_new_dict(state, existing_state, key::treasury))));
		state.set(normalized_state, str(key::posture), str(_normalize_posture(state, state.get(existing_state, str(key::posture), str(key::probing)))));
		state.set(normalized_state, str(key::captured_artifact_ids), array_value(_normalize_string_array(state, get_or_new_array(state, existing_state, key::captured_artifact_ids))));
		state.set(normalized_state, str(key::commander_roster), array_value(enemy_adventure_rules::normalize_commander_roster(state, session, faction_id, get_or_new_array(state, existing_state, key::commander_roster))));
		for (const Atom identity_key : kConfigIdentityKeys) {
			Value identity;
			if (state.lookup(config, str(identity_key), identity)) {
				state.set(normalized_state, str(identity_key), identity);
			}
		}
		const DictRef rebuild_pressure_request = _normalize_rebuild_pressure_request(state, get_or_new_dict(state, existing_state, key::rebuild_pressure_request), day);
		if (!gd::is_empty(state, rebuild_pressure_request)) {
			state.set(normalized_state, str(key::rebuild_pressure_request), dict_value(rebuild_pressure_request));
		}
		const ArrayRef recent_rebuild_targets = _normalize_string_array(state, get_or_new_array(state, existing_state, key::recent_rebuild_exploration_target_ids));
		while (state.array_size(recent_rebuild_targets) > kRaidRecentExplorationTargetLimit) {
			gd::pop_front(state, recent_rebuild_targets);
		}
		if (state.array_size(recent_rebuild_targets) > 0) {
			state.set(normalized_state, str(key::recent_rebuild_exploration_target_ids), array_value(recent_rebuild_targets));
		}
		const DictRef known_world_memory = enemy_adventure_rules::normalize_enemy_known_world_memory(state, get_or_new_dict(state, existing_state, key::known_world_memory), day);
		if (!gd::is_empty(state, known_world_memory)) {
			state.set(normalized_state, str(key::known_world_memory), dict_value(known_world_memory));
		}
		if (state.has(existing_state, str(key::hero_task_state))) {
			not_ported("a hero task board");
		}
		for (const Atom state_key : kAiPlayerStateKeys) {
			Value kept;
			if (state.lookup(existing_state, str(state_key), kept)) {
				state.set(normalized_state, str(state_key), kept);
			}
		}
		state.append(normalized_states, dict_value(normalized_state));
	}

	state.set(overworld, str(key::enemy_states), array_value(normalized_states));
	enemy_adventure_rules::normalize_raid_armies(state, session);
	// Older saves carry raid hosts; they continue as heroes (or disband).
	ai_hero_rules::migrate_legacy_raids(state, session);
	enemy_adventure_rules::normalize_all_commander_rosters(state, session);
}

ArrayRef _enemy_faction_configs_for_session(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	// var players: Array = session.overworld.get("players", []).
	const ArrayRef players = gd::as_array(get_or_new_array(state, overworld, key::players));
	if (state.array_size(players) > 0) {
		return _enemy_faction_configs_with_runtime_defaults(state, session, player_rules::enemy_configs(state, players));
	}
	// The scenario's and the generated record's enemy factions, and the towns'.
	not_ported("enemy configs without player records");
}

ArrayRef _enemy_faction_configs_with_runtime_defaults(State &state, DictRef session, ArrayRef configs) {
	const ArrayRef result = state.new_array();
	for (const Value &config_value : gd::items(state, array_value(configs))) {
		if (!gd::is_dict(config_value)) {
			continue;
		}
		state.append(result, dict_value(_enemy_faction_config_with_runtime_defaults(state, session, config_value.ref)));
	}
	return result;
}

DictRef _enemy_faction_config_with_runtime_defaults(State &state, DictRef session, DictRef config) {
	const DictRef normalized = gd::deep_duplicate_dict(state, config);
	const Atom faction_id = text(state, normalized, key::faction_id, key::empty);
	if (faction_id == key::empty) {
		return normalized;
	}
	const DictRef faction = gd::content_row(state, state::ContentTable::Faction, faction_id);
	if (text(state, normalized, key::label, key::empty) == key::empty) {
		state.set(normalized, str(key::label), str(text(state, faction, key::name, faction_id)));
	}
	if (gd::int_field(state, normalized, key::pressure_per_day, 0) <= 0) {
		state.set(normalized, str(key::pressure_per_day), int_value(2));
	}
	if (gd::int_field(state, normalized, key::pressure_per_enemy_town, 0) <= 0) {
		state.set(normalized, str(key::pressure_per_enemy_town), int_value(1));
	}
	if (gd::int_field(state, normalized, key::raid_threshold, 0) <= 0) {
		state.set(normalized, str(key::raid_threshold), int_value(5));
	}
	if (gd::int_field(state, normalized, key::max_active_raids, 0) <= 0) {
		state.set(normalized, str(key::max_active_raids), int_value(2));
	}
	if (gd::int_field(state, normalized, key::raid_pillage_delay, 0) <= 0) {
		state.set(normalized, str(key::raid_pillage_delay), int_value(1));
	}
	const Value raid_pillage = get_or_new_dict(state, normalized, key::raid_pillage);
	if (!gd::is_dict(raid_pillage) || gd::is_empty(state, raid_pillage.ref)) {
		const DictRef pillage = state.new_dict();
		state.set(pillage, str(key::gold), int_value(150));
		state.set(normalized, str(key::raid_pillage), dict_value(pillage));
	}
	const Value raid_encounter_ids = get_or_new_array(state, normalized, key::raid_encounter_ids);
	if (!gd::is_array(raid_encounter_ids) || state.array_size(raid_encounter_ids.ref) == 0) {
		state.set(normalized, str(key::raid_encounter_ids), array_value(_default_raid_encounter_ids_for_faction(state, faction_id)));
	}
	const Value spawn_points = get_or_new_array(state, normalized, key::spawn_points);
	if (!gd::is_array(spawn_points) || state.array_size(spawn_points.ref) == 0) {
		state.set(normalized, str(key::spawn_points), array_value(_default_spawn_points_for_faction(state, session, player_rules::controller_id(state, normalized, key::empty))));
	}
	if (!gd::is_array(get_or_new_array(state, normalized, key::priority_target_placement_ids))) {
		state.set(normalized, str(key::priority_target_placement_ids), array_value(state.new_array()));
	}
	if (gd::int_field(state, normalized, key::priority_target_bonus, 0) <= 0) {
		state.set(normalized, str(key::priority_target_bonus), int_value(80));
	}
	if (!gd::bool_field(state, normalized, key::generated_package_town_config, false)) {
		// _config_was_runtime_defaulted: only configs without player records.
		not_ported("a config without generated_package_town_config");
	}
	return normalized;
}

ArrayRef _default_raid_encounter_ids_for_faction(State &state, Atom faction_id) {
	const ArrayRef ids = state.new_array();
	auto add = [&](std::initializer_list<Atom> encounter_ids) {
		for (const Atom encounter_id : encounter_ids) {
			state.append(ids, str(encounter_id));
		}
	};
	if (faction_id == key::faction_mireclaw) {
		add({ key::encounter_mire_raid, key::encounter_blackbranch_reavers });
	} else if (faction_id == key::faction_sunvault) {
		add({ key::encounter_aurora_battery, key::encounter_daybreak_matrix });
	} else if (faction_id == key::faction_thornwake) {
		add({ key::encounter_graftroot_wardens });
	} else if (faction_id == key::faction_brasshollow) {
		add({ key::encounter_orevein_exactors });
	} else if (faction_id == key::faction_veilmourn) {
		add({ key::encounter_bellwake_privateers });
	} else {
		add({ key::encounter_ford_reavers, key::encounter_mire_raid });
	}
	return ids;
}

ArrayRef _default_spawn_points_for_faction(State &state, DictRef session, Atom faction_id) {
	const ArrayRef points = state.new_array();
	for (const Value &entry : gd::items(state, array_value(_owned_town_entries(state, session, faction_id)))) {
		if (!gd::is_dict(entry)) {
			continue;
		}
		const DictRef town = dict_field_or_new(state, entry.ref, key::town);
		if (gd::is_empty(state, town)) {
			continue;
		}
		state.append(points, dict_value(overworld_level_rules::town_entrance(state, town)));
	}
	return points;
}

DictRef _find_state(State &state, const Value &states, Atom faction_id) {
	if (gd::is_array(states)) {
		for (const Value &found : gd::items(state, states)) {
			if (gd::is_dict(found) && player_rules::controller_id(state, found.ref, key::empty) == faction_id) {
				return found.ref;
			}
		}
	}
	return state.new_dict();
}

DictRef _blank_resource_pool(State &state) {
	const DictRef resources = state.new_dict();
	for (const Atom resource_key : kTrackedResources) {
		state.set(resources, str(resource_key), int_value(0));
	}
	return resources;
}

DictRef _normalize_resource_pool(State &state, const Value &value) {
	const DictRef normalized = _blank_resource_pool(state);
	if (gd::is_dict(value)) {
		const state::ValueList keys = state.dict(value.ref).keys.list();
		for (const Value &resource_key : keys) {
			const int64_t amount = imax(0, gd::to_int(state, gd::index(state, value.ref, resource_key)));
			state.set(normalized, str(gd::stringify_or_fallback(state, resource_key)), int_value(amount));
		}
	}
	return normalized;
}

Atom _normalize_posture(State &state, const Value &value) {
	const Atom posture = gd::stringify_or_fallback(state, value);
	if (one_of(posture, { key::probing, key::massing, key::raiding, key::fortifying, key::reorganizing, key::collapsed, key::attacking, key::expanding, key::building })) {
		return posture;
	}
	return key::probing;
}

ArrayRef _normalize_string_array(State &state, const Value &value) {
	const ArrayRef normalized = state.new_array();
	if (!gd::is_array(value)) {
		return normalized;
	}
	for (const Value &entry : gd::items(state, value)) {
		const Atom item = gd::stringify_or_fallback(state, entry);
		if (item != key::empty && !gd::array_has(state, normalized, str(item))) {
			state.append(normalized, str(item));
		}
	}
	return normalized;
}

DictRef _normalize_rebuild_pressure_request(State &state, const Value &value, int64_t current_day) {
	if (!gd::is_dict(value)) {
		return state.new_dict();
	}
	const DictRef source = value.ref;
	const int64_t requested_day = count_field(state, source, key::requested_day);
	if (requested_day <= 0) {
		return state.new_dict();
	}
	if (current_day > 0 && gd::sub(current_day, requested_day) > kRebuildPressureLaunchWindowDays) {
		return state.new_dict();
	}
	const ArrayRef recent_exploration_target_ids = _normalize_string_array(state, get_or_new_array(state, source, key::recent_exploration_target_ids));
	while (state.array_size(recent_exploration_target_ids) > kRaidRecentExplorationTargetLimit) {
		gd::pop_front(state, recent_exploration_target_ids);
	}
	const DictRef request = state.new_dict();
	state.set(request, str(key::requested_day), int_value(requested_day));
	state.set(request, str(key::origin_town_id), str(text(state, source, key::origin_town_id, key::empty)));
	state.set(request, str(key::commander_id), str(text(state, source, key::commander_id, key::empty)));
	state.set(request, str(key::reason), str(text(state, source, key::reason, key::command_rebuild)));
	state.set(request, str(key::recent_exploration_target_ids), array_value(recent_exploration_target_ids));
	return request;
}

} // namespace enemy_turn_rules

// AiHeroRules.

namespace ai_hero_rules {

void migrate_legacy_raids(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	const DictRef battle = gd::as_dict(gd::field(state, session, key::battle));
	if (gd::int_field(state, overworld, key::ai_heroes_version, 0) >= kAiHeroesMigrationVersion || !gd::is_empty(state, battle)) {
		return;
	}
	normalize_ai_heroes(state, session, key::empty);
	state.set(overworld, str(key::ai_heroes_version), int_value(kAiHeroesMigrationVersion));
}

DictRef normalize_ai_heroes(State &state, DictRef session, Atom only_controller) {
	const DictRef report = state.new_dict();
	state.set(report, str(key::converted), int_value(0));
	state.set(report, str(key::disbanded), int_value(0));
	state.set(report, str(key::joined_hero), int_value(0));
	// A battle in progress still refers to its armies as they are.
	if (!gd::is_empty(state, gd::as_dict(gd::field(state, session, key::battle)))) {
		return report;
	}
	const DictRef overworld = session_view::overworld(state, session);
	const Value encounters_value = get_or_new_array(state, overworld, key::encounters);
	const ArrayRef encounters = gd::is_array(encounters_value) ? encounters_value.ref : state.new_array();
	// _resolved_lookup(session).duplicate(): AiHeroRules._resolved_lookup and
	// _overworld_rules are inlined (Phase 3's AI targets port them).
	const DictRef resolved = gd::duplicate_dict(state, overworld_rules::resolved_encounter_lookup(state, session));
	for (int64_t index = 0; index < state.array_size(encounters); ++index) {
		const Value entry = state.at(encounters, index);
		if (!gd::is_dict(entry)) {
			continue;
		}
		const Atom controller = player_rules::raid_controller_id(state, entry.ref);
		if (controller == key::empty || (only_controller != key::empty && controller != only_controller)) {
			continue;
		}
		const Atom placement_id = text(state, entry.ref, key::placement_id, key::empty);
		if (state.has(resolved, str(placement_id)) || gd::bool_field(state, entry.ref, key::raid_retired_to_rebuild, false)) {
			continue;
		}
		if (is_ai_hero(state, entry)) {
			const DictRef block = gd::as_dict(get_or_new_dict(state, entry.ref, key::ai_hero));
			if (!gd::is_dict(get_or_new_dict(state, block, key::movement))) {
				// _movement_max: Phase 3's AI targets port it.
				not_ported("an AI hero without its movement");
			}
			continue;
		}
		// A raid host (_convert_legacy_host) or a support column (joined to the
		// nearest hero or disbanded): older saves only.
		not_ported("a legacy raid host");
	}
	return report;
}

} // namespace ai_hero_rules

// HeroProgressionRules.

namespace hero_progression_rules {

DictRef ensure_hero_progression(State &state, DictRef hero_state) {
	DictRef hero = hero_state;
	const int64_t level = imax(1, gd::int_field(state, hero, key::level, 1));
	state.set(hero, str(key::level), int_value(level));
	state.set(hero, str(key::specialties), array_value(_normalize_specialties(state, get_or_new_array(state, hero, key::specialties))));
	state.set(hero, str(key::pending_specialty_choices), array_value(_normalize_pending_choices(state, get_or_new_array(state, hero, key::pending_specialty_choices), hero)));
	hero = _reconcile_pending_choices(state, hero);
	hero = _enqueue_missing_choice_groups(state, hero);
	// Old saves with an outstanding choice get one reminder; established heroes
	// without choices do not replay their entire progression history on load.
	int64_t presented = level;
	const ArrayRef pending_choices = gd::as_array(gd::index(state, hero, str(key::pending_specialty_choices)));
	if (state.array_size(pending_choices) > 0) {
		presented = gd::sub(gd::to_int(state, variant_get(state, state.at(pending_choices, 0), key::level, int_value(level))), 1);
	}
	state.set(hero, str(key::level_up_presented), int_value(iclamp(gd::int_field(state, hero, key::level_up_presented, presented), 1, level)));
	return hero;
}

ArrayRef _normalize_specialties(State &state, const Value &value) {
	return _normalize_specialties_in(state, gd::is_array(value) ? _specialty_catalog(state) : state.new_dict(), value);
}

ArrayRef _normalize_pending_choices(State &state, const Value &value, DictRef hero_state) {
	const ArrayRef normalized = state.new_array();
	if (!gd::is_array(value)) {
		return normalized;
	}
	const DictRef catalog = _specialty_catalog(state);
	for (const Value &pending_choice : gd::items(state, value)) {
		if (!gd::is_dict(pending_choice)) {
			continue;
		}
		const int64_t level = imax(2, gd::int_field(state, pending_choice.ref, key::level, 2));
		const Value saved_options = get_or_new_array(state, pending_choice.ref, key::options);
		if (!gd::is_array(saved_options)) {
			not_ported("a pending specialty choice whose options are not an Array");
		}
		const ArrayRef options = state.new_array();
		for (const Value &specialty_id_value : gd::items(state, saved_options)) {
			const Atom specialty_id = gd::stringify_or_fallback(state, specialty_id_value);
			const DictRef row = specialty_row(state, catalog, specialty_id);
			if (gd::is_empty(state, row)) {
				continue;
			}
			if (specialty_rank(state, hero_state, specialty_id) >= imax(1, gd::int_field(state, row, key::max_rank, 1))) {
				continue;
			}
			if (gd::array_has(state, options, str(specialty_id))) {
				continue;
			}
			state.append(options, str(specialty_id));
			if (state.array_size(options) >= kChoiceSize) {
				break;
			}
		}
		if (state.array_size(options) > 0) {
			const DictRef choice = state.new_dict();
			state.set(choice, str(key::level), int_value(level));
			state.set(choice, str(key::options), array_value(options));
			state.append(normalized, dict_value(choice));
		}
	}
	return normalized;
}

DictRef _reconcile_pending_choices(State &state, DictRef hero_state) {
	const DictRef hero = hero_state;
	const ArrayRef pending_choices = state.new_array();
	for (const Value &pending_choice : gd::items(state, get_or_new_array(state, hero, key::pending_specialty_choices))) {
		if (!gd::is_dict(pending_choice)) {
			continue;
		}
		const int64_t level = imax(2, gd::int_field(state, pending_choice.ref, key::level, 2));
		const ArrayRef options = state.new_array();
		for (const Value &specialty_id_value : gd::items(state, get_or_new_array(state, pending_choice.ref, key::options))) {
			const Atom specialty_id = gd::stringify_or_fallback(state, specialty_id_value);
			if (_specialty_is_available(state, hero, specialty_id) && !gd::array_has(state, options, str(specialty_id))) {
				state.append(options, str(specialty_id));
			}
		}
		const ArrayRef offer = _offer_order(state, hero, level);
		if (state.array_size(offer) > 0) {
			// min(CHOICE_SIZE, available_specialty_ids(hero).size()): the same on
			// every pass of the loop, as the hero does not change in it.
			const int64_t wanted = std::min<int64_t>(kChoiceSize, state.array_size(available_specialty_ids(state, hero)));
			for (const Value &specialty_id : gd::items(state, array_value(offer))) {
				if (state.array_size(options) >= wanted) {
					break;
				}
				if (!gd::array_has(state, options, specialty_id)) {
					state.append(options, specialty_id);
				}
			}
		}
		if (state.array_size(options) > 0) {
			const DictRef choice = state.new_dict();
			state.set(choice, str(key::level), int_value(level));
			state.set(choice, str(key::options), array_value(options));
			state.append(pending_choices, dict_value(choice));
		}
	}
	state.set(hero, str(key::pending_specialty_choices), array_value(pending_choices));
	return hero;
}

DictRef _enqueue_missing_choice_groups(State &state, DictRef hero_state) {
	const DictRef hero = hero_state;
	const int64_t expected_choices = imax(0, gd::sub(gd::int_field(state, hero, key::level, 1), 1));
	const Value specialties = get_or_new_array(state, hero, key::specialties);
	int64_t allocated_choices = gd::add(state.array_size(gd::as_array(specialties)), raw_pending_choices_remaining(state, hero));
	int64_t next_level = gd::add(allocated_choices, 2);
	while (allocated_choices < expected_choices) {
		const DictRef choice_group = _build_choice_group(state, hero, next_level);
		if (gd::is_empty(state, choice_group)) {
			break;
		}
		Value pending_choices = get_or_new_array(state, hero, key::pending_specialty_choices);
		if (!gd::is_array(pending_choices)) {
			pending_choices = array_value(state.new_array());
		}
		state.append(pending_choices.ref, dict_value(choice_group));
		state.set(hero, str(key::pending_specialty_choices), pending_choices);
		allocated_choices = gd::add(allocated_choices, 1);
		next_level = gd::add(next_level, 1);
	}
	return hero;
}

int64_t raw_pending_choices_remaining(State &state, DictRef hero_state) {
	const Value pending_choices = get_or_new_array(state, hero_state, key::pending_specialty_choices);
	return gd::is_array(pending_choices) ? state.array_size(pending_choices.ref) : 0;
}

int64_t mana_max_bonus(State &state, DictRef hero_state) {
	return gd::int_field(state, aggregate_bonuses(state, hero_state), key::max_mana, 0);
}

DictRef _specialty_row(State &state, Atom specialty_id) {
	return specialty_row(state, _specialty_catalog(state), specialty_id);
}

int64_t max_rank_for_specialty(State &state, Atom specialty_id) {
	return imax(1, gd::int_field(state, _specialty_row(state, specialty_id), key::max_rank, 1));
}

int64_t specialty_rank(State &state, DictRef hero_state, Atom specialty_id) {
	int64_t count = 0;
	const Value specialties = get_or_new_array(state, hero_state, key::specialties);
	if (gd::is_array(specialties)) {
		for (const Value &specialty_id_value : gd::items(state, specialties)) {
			if (gd::stringify_or_fallback(state, specialty_id_value) == specialty_id) {
				++count;
			}
		}
	}
	return count;
}

Value specialties(State &state) {
	// The catalog's specialties in authored order: its "items" if an Array, else [].
	const Value items = state.get(gd::content_file(state, key::hero_specialties_path), str(key::items), array_value(state.new_array()));
	return gd::is_array(items) ? items : array_value(state.new_array());
}

int64_t max_specialties_per_hero(State &state) {
	return imax(1, gd::int_field(state, gd::content_file(state, key::hero_specialties_path), key::max_specialties_per_hero, 6));
}

int64_t _distinct_specialty_count(State &state, DictRef hero_state) {
	const DictRef seen = state.new_dict();
	for (const Value &specialty_id : gd::items(state, get_or_new_array(state, hero_state, key::specialties))) {
		state.set(seen, str(gd::stringify_or_fallback(state, specialty_id)), bool_value(true));
	}
	return state.dict_size(seen);
}

bool _specialty_is_available(State &state, DictRef hero_state, Atom specialty_id) {
	if (gd::is_empty(state, _specialty_row(state, specialty_id))) {
		return false;
	}
	const int64_t rank = specialty_rank(state, hero_state, specialty_id);
	if (rank >= max_rank_for_specialty(state, specialty_id)) {
		return false;
	}
	return rank > 0 || _distinct_specialty_count(state, hero_state) < max_specialties_per_hero(state);
}

ArrayRef available_specialty_ids(State &state, DictRef hero_state) {
	const ArrayRef available = state.new_array();
	for (const Value &specialty : gd::items(state, specialties(state))) {
		const Atom specialty_id = gd::stringify_or_fallback(state, variant_get(state, specialty, key::id, str(key::empty)));
		if (_specialty_is_available(state, hero_state, specialty_id)) {
			state.append(available, str(specialty_id));
		}
	}
	return available;
}

Atom growth_seed(State &state, DictRef hero_state) {
	const Atom stored = gd::strip_edges(state, text(state, hero_state, key::growth_seed, key::empty));
	if (stored != key::empty) {
		return stored;
	}
	for (const Atom field : { key::id, key::roster_hero_id, key::hero_id, key::name }) {
		const Atom value = gd::strip_edges(state, text(state, hero_state, field, key::empty));
		if (value != key::empty) {
			return value;
		}
	}
	return key::hero;
}

Atom command_path(State &state, DictRef hero_state) {
	Atom path = gd::strip_edges(state, text(state, hero_state, key::command_path, key::empty));
	if (!is_command_path(path)) {
		for (const Atom field : { key::id, key::roster_hero_id, key::hero_id }) {
			const Atom template_id = gd::strip_edges(state, text(state, hero_state, field, key::empty));
			if (template_id != key::empty) {
				path = text(state, gd::content_row(state, state::ContentTable::Hero, template_id), key::command_path, key::empty);
				if (is_command_path(path)) {
					break;
				}
			}
		}
	}
	if (is_command_path(path)) {
		return path;
	}
	const DictRef command = dict_field_or_new(state, hero_state, key::command);
	const int64_t magic = gd::add(gd::int_field(state, command, key::power, 0), gd::int_field(state, command, key::knowledge, 0));
	return magic > gd::add(gd::int_field(state, command, key::attack, 0), gd::int_field(state, command, key::defense, 0)) ? key::magic : key::might;
}

ArrayRef _normalize_specialty_id_list(State &state, const Value &value) {
	const ArrayRef normalized = state.new_array();
	if (!gd::is_array(value)) {
		return normalized;
	}
	for (const Value &specialty_id_value : gd::items(state, value)) {
		const Atom specialty_id = gd::stringify_or_fallback(state, specialty_id_value);
		// has_specialty(specialty_id).
		if (gd::is_empty(state, _specialty_row(state, specialty_id)) || gd::array_has(state, normalized, str(specialty_id))) {
			continue;
		}
		state.append(normalized, str(specialty_id));
	}
	return normalized;
}

ArrayRef _offer_order(State &state, DictRef hero_state, int64_t level_number) {
	// Each candidate's place is a weighted draw (Efraimidis-Spirakis keys)
	// seeded by the hero's growth seed and the level; Godot's sort_custom
	// orders the keys, largest first.
	const ArrayRef available = available_specialty_ids(state, hero_state);
	if (state.array_size(available) == 0) {
		return available;
	}
	const ArrayRef focus = _normalize_specialty_id_list(state, get_or_new_array(state, hero_state, key::specialty_focus_ids));
	const Atom path = command_path(state, hero_state);
	const std::string seed_text = state.text(growth_seed(state, hero_state));
	struct Keyed {
		Atom id;
		double key;
	};
	std::vector<Keyed> keyed;
	for (const Value &specialty_id_value : gd::items(state, array_value(available))) {
		const Atom specialty_id = gd::to_string(specialty_id_value);
		double weight = kOfferOtherWeight;
		if (gd::array_has(state, focus, str(specialty_id))) {
			weight = kOfferFocusWeight;
		} else if (text(state, _specialty_row(state, specialty_id), key::path, key::any) == path) {
			weight = kOfferPathWeight;
		}
		// ("%s|offer|%d|%s" % [seed_text, level_number, specialty_id]).sha256_text()
		const std::string digest = compat::sha256_text(seed_text + "|offer|" + compat::itos(level_number) + "|" + state.text(specialty_id));
		const double draw = (static_cast<double>(hex_digits_to_int(digest.substr(0, 8))) + 1.0) / 4294967297.0;
		keyed.push_back(Keyed{ specialty_id, gd::engine_pow(state, draw, 1.0 / weight) });
	}
	compat::sort_custom(keyed.data(), static_cast<int64_t>(keyed.size()), [](const Keyed &a, const Keyed &b) { return a.key > b.key; });
	const ArrayRef result = state.new_array();
	for (const bool want_held : { true, false }) {
		for (const Keyed &entry : keyed) {
			if ((specialty_rank(state, hero_state, entry.id) > 0) == want_held) {
				state.append(result, str(entry.id));
				break;
			}
		}
	}
	for (const Keyed &entry : keyed) {
		if (!gd::array_has(state, result, str(entry.id))) {
			state.append(result, str(entry.id));
		}
	}
	return result;
}

DictRef _build_choice_group(State &state, DictRef hero_state, int64_t level_number) {
	const ArrayRef options = _offer_order(state, hero_state, level_number);
	const int64_t size = state.array_size(options);
	if (size == 0) {
		return state.new_dict();
	}
	const DictRef group = state.new_dict();
	state.set(group, str(key::level), int_value(imax(2, level_number)));
	state.set(group, str(key::options), array_value(gd::slice(state, options, 0, std::min<int64_t>(kChoiceSize, size))));
	return group;
}

DictRef current_pending_choice(State &state, DictRef hero_state) {
	const DictRef hero = ensure_hero_progression(state, gd::deep_duplicate_dict(state, hero_state));
	const Value pending_choices = get_or_new_array(state, hero, key::pending_specialty_choices);
	if (gd::is_array(pending_choices) && state.array_size(pending_choices.ref) > 0 && gd::is_dict(state.at(pending_choices.ref, 0))) {
		return state.at(pending_choices.ref, 0).ref;
	}
	return state.new_dict();
}

DictRef specialty_definition(State &state, Atom specialty_id) {
	const DictRef row = _specialty_row(state, specialty_id);
	return gd::is_empty(state, row) ? state.new_dict() : gd::deep_duplicate_dict(state, row);
}

DictRef choose_specialty(State &state, DictRef hero_state, Atom specialty_id) {
	// The result's "hero" (every outcome has one); its message is not built, as
	// the one caller here reads only the hero.
	DictRef hero = ensure_hero_progression(state, gd::deep_duplicate_dict(state, hero_state));
	const Value pending_choices = get_or_new_array(state, hero, key::pending_specialty_choices);
	if (!gd::is_array(pending_choices) || state.array_size(pending_choices.ref) == 0) {
		return hero;
	}
	// var current_choice: Dictionary = pending_choices[0]
	const DictRef current_choice = gd::as_dict(state.at(pending_choices.ref, 0));
	const Value options = get_or_new_array(state, current_choice, key::options);
	if (!gd::is_array(options) || !gd::array_has(state, options.ref, str(specialty_id))) {
		return hero;
	}
	if (specialty_rank(state, hero, specialty_id) >= max_rank_for_specialty(state, specialty_id)) {
		return hero;
	}
	Value specialties = get_or_new_array(state, hero, key::specialties);
	if (!gd::is_array(specialties)) {
		specialties = array_value(state.new_array());
	}
	state.append(specialties.ref, str(specialty_id));
	state.set(hero, str(key::specialties), specialties);
	gd::remove_at(state, pending_choices.ref, 0);
	state.set(hero, str(key::pending_specialty_choices), pending_choices);
	return ensure_hero_progression(state, hero);
}

} // namespace hero_progression_rules

// SpellRules.

namespace spell_rules {

DictRef ensure_hero_spellbook(State &state, DictRef hero_state, DictRef hero_template) {
	const int64_t max_mana = mana_max_from_hero(state, hero_state);
	const ArrayRef default_known_spells = !gd::is_empty(state, hero_template) ? _normalize_spell_ids(state, get_or_new_array(state, hero_template, key::starting_spell_ids)) : state.new_array();
	const DictRef spellbook = dict_or_new(state, get_or_new_dict(state, hero_state, key::spellbook));

	// The template's list is normalized already; only a stored list needs it.
	Value stored_spell_ids;
	ArrayRef known_spell_ids = state.lookup(spellbook, str(key::known_spell_ids), stored_spell_ids) ? _normalize_spell_ids(state, stored_spell_ids) : default_known_spells;
	if (state.array_size(known_spell_ids) == 0 && state.array_size(default_known_spells) > 0) {
		known_spell_ids = default_known_spells;
	}

	// var mana: Dictionary = spellbook.get("mana", {}).
	const DictRef mana = gd::as_dict(get_or_new_dict(state, spellbook, key::mana));
	int64_t current_mana = max_mana;
	if (!gd::is_empty(state, mana)) {
		current_mana = iclamp(gd::int_field(state, mana, key::current, max_mana), 0, max_mana);
	}

	const DictRef mana_state = state.new_dict();
	state.set(mana_state, str(key::current), int_value(current_mana));
	state.set(mana_state, str(key::max), int_value(max_mana));
	const DictRef new_spellbook = state.new_dict();
	state.set(new_spellbook, str(key::known_spell_ids), array_value(known_spell_ids));
	state.set(new_spellbook, str(key::mana), dict_value(mana_state));
	state.set(hero_state, str(key::spellbook), dict_value(new_spellbook));
	return hero_state;
}

int64_t mana_max_from_hero(State &state, DictRef hero_state) {
	const Value week_bonuses = get_or_new_dict(state, hero_state, key::week_bonuses);
	const int64_t week_mana = gd::is_dict(week_bonuses) ? gd::int_field(state, week_bonuses.ref, key::mana, 0) : 0;
	const int64_t command_mana = mana_max_from_command(state, get_or_new_dict(state, hero_state, key::command));
	return gd::add(gd::add(command_mana, hero_progression_rules::mana_max_bonus(state, hero_state)), week_mana);
}

int64_t mana_max_from_command(State &state, const Value &command) {
	if (!gd::is_dict(command)) {
		return 8;
	}
	return imax(8, gd::add(8, gd::mul(imax(0, gd::int_field(state, command.ref, key::knowledge, 0)), 4)));
}

} // namespace spell_rules

// EnemyAdventureRules.

namespace enemy_adventure_rules {

ArrayRef normalize_commander_roster(State &state, DictRef session, Atom faction_id, const Value &roster_value) {
	return _normalize_commander_roster_entries(state, session, faction_id, roster_value, Value());
}

DictRef normalize_enemy_known_world_memory(State &state, const Value &value, int64_t current_day) {
	if (!gd::is_dict(value)) {
		return state.new_dict();
	}
	const DictRef source = value.ref;
	const ArrayRef scouted_targets = _normalize_enemy_scouted_target_records(state, get_or_new_array(state, source, key::scouted_targets), current_day);
	const ArrayRef hero_sightings = _normalize_enemy_hero_sighting_records(state, get_or_new_array(state, source, key::player_hero_sightings), current_day);
	// Both lists are empty here (the records are left to GDScript), so the
	// memory has neither and is {}.
	(void)scouted_targets;
	(void)hero_sightings;
	return state.new_dict();
}

ArrayRef _normalize_enemy_scouted_target_records(State &state, const Value &value, int64_t) {
	// known_world_memory comes only from older saves.
	if (gd::is_array(value) && state.array_size(value.ref) > 0) {
		not_ported("an old save's scouted targets");
	}
	return state.new_array();
}

ArrayRef _normalize_enemy_hero_sighting_records(State &state, const Value &value, int64_t) {
	if (gd::is_array(value) && state.array_size(value.ref) > 0) {
		not_ported("an old save's hero sightings");
	}
	return state.new_array();
}

void normalize_raid_armies(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	const DictRef meta = session_view::meta(state, session);
	const Value encounters = get_or_new_array(state, overworld, key::encounters);
	const ArrayRef normalized = state.new_array();
	bool changed = false;
	const DictRef occupied_commander_ids = state.new_dict();
	const DictRef resolved_lookup = _resolved_encounter_lookup(state, get_or_new_array(state, overworld, key::resolved_encounters));
	// var fallen_seen_day: Dictionary = session.get_meta(FALLEN_HERO_SEEN_DAY_META, {}),
	// then set_meta.
	Value fallen_value;
	const DictRef fallen_seen_day = state.lookup(meta, gd::name_value(key::enemy_fallen_hero_seen_day), fallen_value) ? gd::as_dict(fallen_value) : state.new_dict();
	state.set(meta, gd::name_value(key::enemy_fallen_hero_seen_day), dict_value(fallen_seen_day));
	for (const Value &encounter_value : gd::items(state, encounters)) {
		if (!gd::is_dict(encounter_value)) {
			continue;
		}
		const Value existing_commander = get_or_new_dict(state, encounter_value.ref, key::enemy_commander_state);
		if (!gd::is_dict(existing_commander)) {
			continue;
		}
		const Atom roster_hero_id = text(state, existing_commander.ref, key::roster_hero_id, key::empty);
		if (roster_hero_id != key::empty) {
			state.set(occupied_commander_ids, str(roster_hero_id), bool_value(true));
		}
	}
	for (const Value &encounter_value : gd::items(state, encounters)) {
		if (!gd::is_dict(encounter_value)) {
			state.append(normalized, encounter_value);
			continue;
		}
		DictRef encounter = encounter_value.ref;
		if (player_rules::raid_controller_id(state, encounter) != key::empty) {
			if (_fallen_hero_settled(state, session, encounter, resolved_lookup, fallen_seen_day)) {
				state.append(normalized, dict_value(encounter));
				continue;
			}
			const Value previous_army = get_or_new_dict(state, encounter, key::enemy_army);
			const Value previous_commander = get_or_new_dict(state, encounter, key::enemy_commander_state);
			encounter = ensure_raid_army(state, encounter, session, occupied_commander_ids);
			const Atom roster_hero_id = gd::stringify_or_fallback(state, variant_get(state, get_or_new_dict(state, encounter, key::enemy_commander_state), key::roster_hero_id, str(key::empty)));
			if (roster_hero_id != key::empty) {
				state.set(occupied_commander_ids, str(roster_hero_id), bool_value(true));
			}
			if (!gd::equal(state, get_or_new_dict(state, encounter, key::enemy_army), previous_army) || !gd::equal(state, get_or_new_dict(state, encounter, key::enemy_commander_state), previous_commander)) {
				changed = true;
			}
		}
		state.append(normalized, dict_value(encounter));
	}
	if (changed) {
		state.set(overworld, str(key::encounters), array_value(normalized));
	}
}

bool _fallen_hero_settled(State &state, DictRef session, DictRef encounter, DictRef resolved_lookup, DictRef fallen_seen_day) {
	const Atom placement_id = text(state, encounter, key::placement_id, key::empty);
	if (!state.has(resolved_lookup, str(placement_id))) {
		return false;
	}
	const Value commander_state = get_or_new_dict(state, encounter, key::enemy_commander_state);
	if (!gd::is_dict(commander_state) || text(state, commander_state.ref, key::roster_hero_id, key::empty) == key::empty) {
		return false;
	}
	const int64_t day = gd::int_field(state, session, key::day, 0);
	if (!state.has(fallen_seen_day, str(placement_id))) {
		state.set(fallen_seen_day, str(placement_id), int_value(day));
	}
	return gd::to_int(state, gd::index(state, fallen_seen_day, str(placement_id))) < day;
}

DictRef ensure_raid_army(State &state, DictRef encounter, DictRef session, DictRef occupied_commander_ids) {
	if (gd::is_empty(state, encounter)) {
		return encounter;
	}
	const Atom encounter_id = text_or(state, encounter, key::encounter_id, state.get(encounter, str(key::id), str(key::empty)));
	DictRef commander_state = state.new_dict();
	if (player_rules::raid_controller_id(state, encounter) != key::empty && !gd::bool_field(state, encounter, key::commanderless_support_column, false)) {
		const Value roster = commander_roster_for_faction(state, session, player_rules::raid_controller_id(state, encounter));
		commander_state = build_raid_commander_state(state, encounter, key::empty, key::empty, session, occupied_commander_ids, roster);
	}
	DictRef normalized_army = _normalize_army_payload(state, get_or_new_dict(state, encounter, key::enemy_army));
	if (gd::is_empty(state, normalized_army)) {
		const DictRef continuity_source = state.new_dict();
		state.set(continuity_source, str(key::stacks), get_or_new_array(state, commander_army_continuity(state, dict_value(commander_state)), key::stacks));
		const DictRef continuity_army = _normalize_army_payload(state, dict_value(continuity_source));
		if (!gd::is_empty(state, continuity_army)) {
			const Value army = get_or_new_dict(state, encounter, key::enemy_army);
			const Atom army_id = gd::stringify_or_fallback(state, variant_get(state, army, key::id, str(encounter_id)));
			const Atom army_name = gd::stringify_or_fallback(state, variant_get(state, get_or_new_dict(state, encounter, key::enemy_army), key::name, str(key::raid_host)));
			normalized_army = state.new_dict();
			state.set(normalized_army, str(key::id), str(army_id));
			state.set(normalized_army, str(key::name), str(army_name));
			state.set(normalized_army, str(key::stacks), gd::duplicate_value(state, get_or_new_array(state, continuity_army, key::stacks), true));
		} else {
			normalized_army = _base_enemy_army(state, encounter_id);
		}
	}
	if (!gd::is_empty(state, normalized_army)) {
		state.set(normalized_army, str(key::id), str(text(state, normalized_army, key::id, encounter_id)));
		state.set(normalized_army, str(key::name), str(text(state, normalized_army, key::name, key::raid_host)));
		state.set(encounter, str(key::enemy_army), dict_value(normalized_army));
	}
	if (!gd::is_empty(state, commander_state)) {
		state.set(encounter, str(key::enemy_commander_state), dict_value(sync_commander_army_continuity(state, commander_state, dict_value(normalized_army), encounter_id)));
	}
	return encounter;
}

DictRef build_raid_commander_state(State &state, DictRef encounter, Atom roster_hero_id, Atom faction_id, DictRef session, DictRef, const Value &commander_roster) {
	if (gd::is_empty(state, encounter)) {
		return state.new_dict();
	}
	const DictRef existing_state = dict_field_or_new(state, encounter, key::enemy_commander_state);
	Atom resolved_faction_id = player_rules::raid_controller_id(state, encounter);
	if (resolved_faction_id == key::empty) {
		resolved_faction_id = player_rules::controller_id(state, existing_state, faction_id);
	}
	if (resolved_faction_id == key::empty) {
		resolved_faction_id = text(state, encounter, key::spawned_by_faction_id, faction_id);
	}
	const Atom resolved_roster_hero_id = text(state, existing_state, key::roster_hero_id, roster_hero_id);
	if (resolved_roster_hero_id == key::empty && resolved_faction_id != key::empty) {
		// select_raid_commander_roster_hero_id: raids now come with their hero.
		not_ported("a raid without its commander");
	}
	if (resolved_roster_hero_id == key::empty && resolved_faction_id != key::empty && gd::is_empty(state, existing_state)) {
		return state.new_dict();
	}
	const DictRef hero_template = gd::content_row(state, state::ContentTable::Hero, resolved_roster_hero_id);
	const Atom template_id = text_or(state, encounter, key::encounter_id, state.get(encounter, str(key::id), str(key::empty)));
	const DictRef encounter_template = gd::content_row(state, state::ContentTable::Encounter, template_id);
	const DictRef encounter_commander = dict_or_new(state, get_or_new_dict(state, encounter_template, key::enemy_commander));
	const Value roster = gd::is_array(commander_roster) ? commander_roster : commander_roster_for_faction(state, session, resolved_faction_id);
	const DictRef roster_entry = _normalize_commander_roster_entry(state, session, resolved_faction_id, roster, resolved_roster_hero_id);
	const DictRef roster_commander_state = dict_or_new(state, get_or_new_dict(state, roster_entry, key::commander_state));
	const DictRef commander_seed = build_roster_commander_state(state, resolved_roster_hero_id, resolved_faction_id, !gd::is_empty(state, roster_commander_state) ? roster_commander_state : existing_state, dict_value(roster_entry));
	const Value hero_command = get_or_new_dict(state, hero_template, key::command);
	const Value seed_command = state.get(commander_seed, str(key::command), hero_command);
	const Value command_source = state.get(encounter_commander, str(key::command), seed_command);
	const DictRef commander_state = gd::deep_duplicate_dict(state, !gd::is_empty(state, existing_state) ? existing_state : commander_seed);

	// commander_state["id"]: its own, the seed's, or "raid_commander:<placement>".
	const Atom placement = text_or(state, encounter, key::placement_id, state.get(encounter, str(key::encounter_id), str(key::raid)));
	const Atom fallback_id = state.intern("raid_commander:" + state.text(placement));
	const Value seed_id = state.get(commander_seed, str(key::id), str(fallback_id));
	state.set(commander_state, str(key::id), str(text_or(state, commander_state, key::id, seed_id)));
	state.set(commander_state, str(key::roster_hero_id), str(resolved_roster_hero_id));
	state.set(commander_state, str(key::faction_id), str(player_rules::faction_id(state, session, resolved_faction_id)));
	if (!gd::is_empty(state, player_rules::player(state, session, resolved_faction_id))) {
		state.set(commander_state, str(key::player_id), str(resolved_faction_id));
	}
	{
		const Value commander_name = state.get(encounter_commander, str(key::name), str(key::enemy_commander_title));
		const Value hero_name = state.get(hero_template, str(key::name), commander_name);
		const Value seed_name = state.get(commander_seed, str(key::name), hero_name);
		state.set(commander_state, str(key::name), str(text_or(state, commander_state, key::name, seed_name)));
	}
	{
		const Value hero_archetype = state.get(hero_template, str(key::archetype), str(key::empty));
		const Value seed_archetype = state.get(commander_seed, str(key::archetype), hero_archetype);
		state.set(commander_state, str(key::archetype), str(text_or(state, commander_state, key::archetype, seed_archetype)));
	}
	{
		const Value hero_summary = state.get(hero_template, str(key::identity_summary), str(key::empty));
		const Value seed_summary = state.get(commander_seed, str(key::identity_summary), hero_summary);
		state.set(commander_state, str(key::identity_summary), str(text_or(state, commander_state, key::identity_summary, seed_summary)));
	}
	state.set(commander_state, str(key::command), dict_value(_normalize_command_payload(state, state.get(commander_state, str(key::command), command_source))));
	{
		const Value hero_traits = get_or_new_array(state, hero_template, key::battle_traits);
		const Value seed_traits = state.get(commander_seed, str(key::battle_traits), hero_traits);
		const Value encounter_traits = get_or_new_array(state, encounter_commander, key::battle_traits);
		const Value own_traits = state.get(commander_state, str(key::battle_traits), encounter_traits);
		state.set(commander_state, str(key::battle_traits), array_value(_merge_unique_strings(state, seed_traits, own_traits)));
	}
	Value resolved_specialties = get_or_new_array(state, commander_state, key::specialties);
	if (!gd::is_array(resolved_specialties) || state.array_size(resolved_specialties.ref) == 0) {
		const Value hero_specialties = get_or_new_array(state, hero_template, key::starting_specialties);
		resolved_specialties = state.get(commander_seed, str(key::specialties), hero_specialties);
	}
	state.set(commander_state, str(key::specialties), array_value(_normalized_specialty_ranks(state, resolved_specialties, array_value(state.new_array()))));
	{
		const Value own_focus = get_or_new_array(state, commander_state, key::specialty_focus_ids);
		const Value hero_focus = get_or_new_array(state, hero_template, key::specialty_focus_ids);
		const Value seed_focus = state.get(commander_seed, str(key::specialty_focus_ids), hero_focus);
		state.set(commander_state, str(key::specialty_focus_ids), array_value(_normalized_specialty_focus_ids(state, array_value(_merge_unique_strings(state, own_focus, seed_focus)))));
	}
	{
		const Value seed_level = state.get(commander_seed, str(key::level), int_value(1));
		state.set(commander_state, str(key::level), int_value(imax(1, gd::to_int(state, state.get(commander_state, str(key::level), seed_level)))));
		const Value seed_experience = state.get(commander_seed, str(key::experience), int_value(0));
		state.set(commander_state, str(key::experience), int_value(imax(0, gd::to_int(state, state.get(commander_state, str(key::experience), seed_experience)))));
		const Value seed_next = state.get(commander_seed, str(key::next_level_experience), int_value(250));
		state.set(commander_state, str(key::next_level_experience), int_value(imax(250, gd::to_int(state, state.get(commander_state, str(key::next_level_experience), seed_next)))));
		const Value seed_choices = get_or_new_array(state, commander_seed, key::pending_specialty_choices);
		state.set(commander_state, str(key::pending_specialty_choices), state.get(commander_state, str(key::pending_specialty_choices), seed_choices));
		const Value seed_outcome = state.get(commander_seed, str(key::last_outcome), str(key::empty));
		state.set(commander_state, str(key::last_outcome), str(text_or(state, commander_state, key::last_outcome, seed_outcome)));
		const Value seed_artifacts = get_or_new_dict(state, commander_seed, key::artifacts);
		state.set(commander_state, str(key::artifacts), dict_value(artifact_rules::normalize_hero_artifacts(state, state.get(commander_state, str(key::artifacts), seed_artifacts))));
	}
	const DictRef progressed = _normalize_enemy_progression(state, commander_state);
	const DictRef commander_spellbook = dict_field_or_new(state, progressed, key::spellbook);

	// The nested calls in GDScript's order: the spellbook first, then the
	// roster entry's memory, record and army, each read after it.
	const DictRef spell_template = state.new_dict();
	state.set(spell_template, str(key::command), get_or_new_dict(state, progressed, key::command));
	{
		const ArrayRef starting = _merge_unique_strings(state, array_value(_hero_starting_spell_ids(state, hero_template)), get_or_new_array(state, encounter_commander, key::starting_spell_ids));
		state.set(spell_template, str(key::starting_spell_ids), array_value(_merge_unique_strings(state, get_or_new_array(state, commander_spellbook, key::known_spell_ids), array_value(starting))));
	}
	const DictRef with_spellbook = spell_rules::ensure_hero_spellbook(state, progressed, spell_template);
	const DictRef memory = _normalized_commander_memory(state, dict_value(roster_entry), dict_value(with_spellbook));
	const DictRef with_memory = _apply_commander_memory_metadata(state, with_spellbook, dict_value(memory));
	const DictRef record = _normalized_commander_record(state, dict_value(roster_entry), dict_value(with_spellbook));
	const DictRef with_record = _apply_commander_record_metadata(state, with_memory, dict_value(record));
	const Atom continuity_encounter_id = text_or(state, encounter, key::encounter_id, state.get(encounter, str(key::id), str(key::empty)));
	const DictRef continuity = _normalized_commander_army_continuity(state, dict_value(roster_entry), dict_value(with_spellbook), continuity_encounter_id);
	return _apply_commander_army_metadata(state, with_record, dict_value(continuity));
}

DictRef build_roster_commander_state(State &state, Atom roster_hero_id, Atom faction_id, DictRef existing_state, const Value &record_source) {
	const DictRef hero_template = gd::content_row(state, state::ContentTable::Hero, roster_hero_id);
	const Value record_value = gd::is_dict(record_source) ? state.get(record_source.ref, str(key::record), record_source) : record_source;
	const DictRef record = _normalized_commander_record(state, record_value, dict_value(existing_state));
	const DictRef target_memory = _normalized_commander_memory(state, record_source, dict_value(existing_state));
	const DictRef army_continuity = _normalized_commander_army_continuity(state, record_source, dict_value(existing_state), key::empty);
	const DictRef existing_spellbook = dict_or_new(state, get_or_new_dict(state, existing_state, key::spellbook));
	const Value command_source = state.get(existing_state, str(key::command), get_or_new_dict(state, hero_template, key::command));
	const ArrayRef battle_traits_source = _merge_unique_strings(state, get_or_new_array(state, existing_state, key::battle_traits), get_or_new_array(state, hero_template, key::battle_traits));
	const Value existing_specialties = get_or_new_array(state, existing_state, key::specialties);
	const bool own_specialties = gd::is_array(existing_specialties) && state.array_size(existing_specialties.ref) > 0;
	const ArrayRef specialties_source = _normalized_specialty_ranks(state, own_specialties ? existing_specialties : get_or_new_array(state, hero_template, key::starting_specialties), array_value(state.new_array()));
	const ArrayRef specialty_focus_source = _normalized_specialty_focus_ids(state, array_value(_merge_unique_strings(state, get_or_new_array(state, existing_state, key::specialty_focus_ids), get_or_new_array(state, hero_template, key::specialty_focus_ids))));
	const ArrayRef spell_ids_source = _merge_unique_strings(state, get_or_new_array(state, existing_spellbook, key::known_spell_ids), array_value(_hero_starting_spell_ids(state, hero_template)));
	const Value record_artifacts = gd::is_dict(record_source) ? get_or_new_dict(state, record_source.ref, key::artifacts) : dict_value(state.new_dict());
	const Value artifacts_source = state.get(existing_state, str(key::artifacts), record_artifacts);

	DictRef commander_state = state.new_dict();
	const Atom default_id = state.intern("enemy_commander:" + state.text(faction_id) + ":" + state.text(roster_hero_id));
	state.set(commander_state, str(key::id), str(text(state, existing_state, key::id, default_id)));
	state.set(commander_state, str(key::roster_hero_id), str(roster_hero_id));
	state.set(commander_state, str(key::faction_id), str(text_or(state, hero_template, key::faction_id, state.get(existing_state, str(key::faction_id), str(faction_id)))));
	state.set(commander_state, str(key::name), str(text_or(state, existing_state, key::name, state.get(hero_template, str(key::name), str(key::enemy_commander_title)))));
	state.set(commander_state, str(key::archetype), str(text_or(state, existing_state, key::archetype, state.get(hero_template, str(key::archetype), str(key::empty)))));
	state.set(commander_state, str(key::identity_summary), str(text_or(state, existing_state, key::identity_summary, state.get(hero_template, str(key::identity_summary), str(key::empty)))));
	state.set(commander_state, str(key::command), dict_value(_normalize_command_payload(state, command_source)));
	state.set(commander_state, str(key::battle_traits), array_value(battle_traits_source));
	state.set(commander_state, str(key::specialties), array_value(specialties_source));
	state.set(commander_state, str(key::specialty_focus_ids), array_value(specialty_focus_source));
	state.set(commander_state, str(key::level), int_value(imax(1, gd::int_field(state, existing_state, key::level, 1))));
	state.set(commander_state, str(key::experience), int_value(imax(0, gd::int_field(state, existing_state, key::experience, 0))));
	state.set(commander_state, str(key::next_level_experience), int_value(imax(250, gd::int_field(state, existing_state, key::next_level_experience, 250))));
	state.set(commander_state, str(key::pending_specialty_choices), get_or_new_array(state, existing_state, key::pending_specialty_choices));
	state.set(commander_state, str(key::last_outcome), str(text_or(state, existing_state, key::last_outcome, state.get(record, str(key::last_outcome), str(key::empty)))));
	state.set(commander_state, str(key::artifacts), dict_value(artifact_rules::normalize_hero_artifacts(state, artifacts_source)));
	state.set(commander_state, str(key::town_training_claims), array_value(_normalize_string_array(state, get_or_new_array(state, existing_state, key::town_training_claims))));
	state.set(commander_state, str(key::last_town_trade_day), int_value(gd::int_field(state, existing_state, key::last_town_trade_day, -1)));
	const Value service_claims = get_or_new_dict(state, existing_state, key::town_service_claims);
	state.set(commander_state, str(key::town_service_claims), dict_value(gd::is_dict(service_claims) ? gd::deep_duplicate_dict(state, service_claims.ref) : state.new_dict()));
	if (text(state, existing_state, key::player_id, key::empty) != key::empty) {
		state.set(commander_state, str(key::player_id), str(gd::stringify_or_fallback(state, gd::index(state, existing_state, str(key::player_id)))));
	}
	// Level-up rolls (HeroProgressionRules.command_gain_stat) keep their path and seed.
	for (const Atom kept_key : { key::command_path, key::growth_seed }) {
		const Atom kept = text(state, existing_state, kept_key, key::empty);
		if (kept != key::empty) {
			state.set(commander_state, str(kept_key), str(kept));
		}
	}
	commander_state = _normalize_enemy_progression(state, commander_state);
	const DictRef spell_template = state.new_dict();
	state.set(spell_template, str(key::command), get_or_new_dict(state, commander_state, key::command));
	state.set(spell_template, str(key::starting_spell_ids), array_value(spell_ids_source));
	spell_rules::ensure_hero_spellbook(state, commander_state, spell_template);
	// Full mana, as refresh_daily_mana would give; commander_state is a fresh copy.
	const DictRef spellbook = gd::as_dict(gd::index(state, commander_state, str(key::spellbook)));
	const DictRef mana = gd::as_dict(gd::index(state, spellbook, str(key::mana)));
	state.set(mana, str(key::current), int_value(gd::int_field(state, mana, key::max, 0)));
	const DictRef with_memory = _apply_commander_memory_metadata(state, commander_state, dict_value(target_memory));
	const DictRef with_record = _apply_commander_record_metadata(state, with_memory, dict_value(record));
	const DictRef with_metadata = _apply_commander_army_metadata(state, with_record, dict_value(army_continuity));
	return _apply_commander_role_metadata(state, with_metadata, record_source);
}

DictRef sync_commander_army_continuity(State &state, DictRef commander_state, const Value &army_source, Atom encounter_id) {
	if (gd::is_empty(state, commander_state)) {
		return state.new_dict();
	}
	const DictRef updated = gd::deep_duplicate_dict(state, commander_state);
	const DictRef continuity = _normalized_commander_army_continuity(state, dict_value(updated), dict_value(updated), encounter_id);
	Value army_payload = army_source;
	if (!gd::is_dict(army_source)) {
		const DictRef wrapped = state.new_dict();
		state.set(wrapped, str(key::stacks), army_source);
		army_payload = dict_value(wrapped);
	}
	const bool explicit_stacks = state.has(army_payload.ref, str(key::stacks)) && gd::is_array(get_or_new_array(state, army_payload.ref, key::stacks));
	const DictRef normalized_army = _normalize_army_payload(state, army_payload);
	ArrayRef stacks = state.new_array();
	if (state.has(normalized_army, str(key::stacks))) {
		stacks = gd::as_array(get_or_new_array(state, normalized_army, key::stacks));
	} else if (explicit_stacks) {
		stacks = state.new_array();
	} else {
		stacks = gd::as_array(get_or_new_array(state, continuity, key::stacks));
	}
	const Atom resolved_encounter_id = encounter_id != key::empty ? encounter_id : text(state, continuity, key::encounter_id, key::empty);
	const int64_t base_army_strength = _army_strength(state, get_or_new_array(state, _base_enemy_army(state, resolved_encounter_id), key::stacks));
	int64_t base_strength = imax(gd::int_field(state, continuity, key::base_strength, 0), base_army_strength);
	if (base_strength <= 0) {
		base_strength = _army_strength(state, array_value(stacks));
	}
	if (base_strength <= 0 && state.array_size(stacks) == 0) {
		return _apply_commander_army_metadata(state, updated, dict_value(state.new_dict()));
	}
	const int64_t current_strength = _army_strength(state, array_value(stacks));
	const Atom status = _army_continuity_status(state, current_strength, base_strength);
	const DictRef army_continuity = state.new_dict();
	state.set(army_continuity, str(key::encounter_id), str(resolved_encounter_id));
	state.set(army_continuity, str(key::stacks), array_value(gd::deep_duplicate_array(state, stacks)));
	state.set(army_continuity, str(key::base_strength), int_value(base_strength));
	state.set(army_continuity, str(key::current_strength), int_value(current_strength));
	state.set(army_continuity, str(key::rebuild_need), int_value(imax(0, gd::sub(base_strength, current_strength))));
	int64_t strength_percent = 100;
	if (base_strength > 0) {
		strength_percent = iclamp(compat::float_to_int(compat::godot_round((static_cast<double>(current_strength) * 100.0) / static_cast<double>(base_strength))), 0, 100);
	}
	state.set(army_continuity, str(key::strength_percent), int_value(strength_percent));
	state.set(army_continuity, str(key::status), str(status));
	state.set(army_continuity, str(key::headcount), int_value(_army_headcount(state, array_value(stacks))));
	state.set(army_continuity, str(key::company_count), int_value(state.array_size(stacks)));
	state.set(updated, str(key::army_continuity), dict_value(army_continuity));
	return _apply_commander_army_metadata(state, updated, dict_value(updated));
}

Value commander_roster_for_faction(State &state, DictRef session, Atom faction_id) {
	if (faction_id == key::empty) {
		return array_value(state.new_array());
	}
	const DictRef overworld = session_view::overworld(state, session);
	for (const Value &enemy_state : gd::field_items(state, overworld, str(key::enemy_states))) {
		if (!gd::is_dict(enemy_state)) {
			continue;
		}
		if (player_rules::controller_id(state, enemy_state.ref, key::empty) != faction_id) {
			continue;
		}
		const Value roster = get_or_new_array(state, enemy_state.ref, key::commander_roster);
		return gd::is_array(roster) ? roster : array_value(state.new_array());
	}
	return array_value(state.new_array());
}

ArrayRef _normalize_commander_roster_entries(State &state, DictRef session, Atom faction_id, const Value &roster_value, const Value &selected_hero_ids) {
	const DictRef existing_map = state.new_dict();
	if (gd::is_array(roster_value)) {
		for (const Value &entry_value : gd::items(state, roster_value)) {
			if (!gd::is_dict(entry_value)) {
				continue;
			}
			const Atom roster_hero_id = text(state, entry_value.ref, key::roster_hero_id, key::empty);
			if (roster_hero_id == key::empty) {
				continue;
			}
			state.set(existing_map, str(roster_hero_id), entry_value);
		}
	}
	const DictRef active_map = _active_commander_map(state, session, faction_id, selected_hero_ids);
	const ArrayRef normalized = state.new_array();
	const int64_t session_day = gd::int_field(state, session, key::day, 0);
	const Value hero_ids = gd::is_array(selected_hero_ids) ? selected_hero_ids : array_value(_faction_commander_ids(state, player_rules::faction_id(state, session, faction_id)));
	// Without the roster entry memo (COMMANDER_ENTRY_MEMO_META): an entry is a
	// function of the inputs that key it, so every entry is built.
	for (const Value &roster_hero_id_value : gd::items(state, hero_ids)) {
		const Atom roster_hero_id = gd::to_string(roster_hero_id_value);
		const DictRef existing = dict_or_new(state, state.get(existing_map, roster_hero_id_value, dict_value(state.new_dict())));
		// var active_entry: Dictionary = active_map.get(roster_hero_id, {}).
		const DictRef active_entry = gd::as_dict(state.get(active_map, roster_hero_id_value, dict_value(state.new_dict())));
		const DictRef active_commander_state = dict_or_new(state, get_or_new_dict(state, active_entry, key::commander_state));
		const Value seed_source = !gd::is_empty(state, active_commander_state) ? dict_value(active_commander_state) : get_or_new_dict(state, existing, key::commander_state);
		const DictRef commander_seed = gd::deep_duplicate_dict(state, gd::as_dict(seed_source));
		gd::merge(state, commander_seed, player_rules::identity_fields(state, session, faction_id), true);
		const DictRef record = _normalized_commander_record(state, dict_value(existing), dict_value(commander_seed));
		const DictRef target_memory = _normalized_commander_memory(state, dict_value(existing), dict_value(commander_seed));
		const DictRef army_continuity = _normalized_commander_army_continuity(state, dict_value(existing), dict_value(commander_seed), key::empty);
		const DictRef record_source = state.new_dict();
		state.set(record_source, str(key::record), dict_value(record));
		state.set(record_source, str(key::target_memory), dict_value(target_memory));
		state.set(record_source, str(key::army_continuity), dict_value(army_continuity));
		state.set(record_source, str(key::commander_role_state), dict_value(_normalized_commander_role_state(state, dict_value(existing), dict_value(commander_seed))));
		const DictRef commander_state = build_roster_commander_state(state, roster_hero_id, faction_id, commander_seed, dict_value(record_source));
		const DictRef role_state = _normalized_commander_role_state(state, dict_value(existing), dict_value(commander_state));
		const DictRef entry = state.new_dict();
		state.set(entry, str(key::roster_hero_id), roster_hero_id_value);
		state.set(entry, str(key::status), str(key::available));
		state.set(entry, str(key::active_placement_id), str(key::empty));
		state.set(entry, str(key::recovery_day), int_value(0));
		state.set(entry, str(key::last_outcome), str(text_or(state, existing, key::last_outcome, state.get(commander_state, str(key::last_outcome), str(key::empty)))));
		state.set(entry, str(key::deployments), int_value(count_field(state, record, key::deployments)));
		state.set(entry, str(key::battle_wins), int_value(count_field(state, record, key::battle_wins)));
		state.set(entry, str(key::times_defeated), int_value(count_field(state, record, key::times_defeated)));
		state.set(entry, str(key::strategic_successes), int_value(count_field(state, record, key::strategic_successes)));
		state.set(entry, str(key::renown), int_value(count_field(state, record, key::renown)));
		state.set(entry, str(key::target_memory), dict_value(target_memory));
		state.set(entry, str(key::commander_role_state), dict_value(role_state));
		state.set(entry, str(key::army_continuity), dict_value(commander_army_continuity(state, dict_value(commander_state))));
		state.set(entry, str(key::commander_state), dict_value(commander_state));
		if (state.has(active_map, roster_hero_id_value)) {
			state.set(entry, str(key::status), str(key::active));
			state.set(entry, str(key::active_placement_id), str(text(state, active_entry, key::placement_id, key::empty)));
		} else {
			const Atom existing_status = _normalize_commander_status(state, state.get(existing, str(key::status), str(key::available)));
			const int64_t recovery_day = count_field(state, existing, key::recovery_day);
			if (existing_status == key::recovering && recovery_day > session_day) {
				state.set(entry, str(key::status), str(key::recovering));
				state.set(entry, str(key::recovery_day), int_value(recovery_day));
			}
		}
		state.append(normalized, dict_value(entry));
	}
	return normalized;
}

DictRef _normalize_commander_roster_entry(State &state, DictRef session, Atom faction_id, const Value &roster_value, Atom roster_hero_id) {
	// Raid construction consumes one entry. Keep its exact catalog membership
	// and normalization without rebuilding every unrelated faction commander.
	if (roster_hero_id == key::empty || !gd::array_has(state, _faction_commander_ids(state, player_rules::faction_id(state, session, faction_id)), str(roster_hero_id))) {
		return state.new_dict();
	}
	const ArrayRef selected = state.new_array();
	state.append(selected, str(roster_hero_id));
	const ArrayRef entries = _normalize_commander_roster_entries(state, session, faction_id, roster_value, array_value(selected));
	return gd::as_dict(state.at(entries, 0));
}

DictRef _active_commander_map(State &state, DictRef session, Atom faction_id, const Value &hero_ids) {
	const DictRef active = state.new_dict();
	const DictRef overworld = session_view::overworld(state, session);
	const DictRef resolved_lookup = _resolved_encounter_lookup(state, get_or_new_array(state, overworld, key::resolved_encounters));
	const bool limited = gd::is_array(hero_ids);
	for (const Value &encounter : gd::field_items(state, overworld, str(key::encounters))) {
		if (!gd::is_dict(encounter)) {
			continue;
		}
		if (faction_id != key::empty && player_rules::raid_controller_id(state, encounter.ref) != faction_id) {
			continue;
		}
		if (enemy_adventure_rules::_placement_resolved(state, text(state, encounter.ref, key::placement_id, key::empty), dict_value(resolved_lookup))) {
			continue;
		}
		const Value commander_state = get_or_new_dict(state, encounter.ref, key::enemy_commander_state);
		if (!gd::is_dict(commander_state) || gd::is_empty(state, commander_state.ref)) {
			continue;
		}
		const Atom roster_hero_id = text(state, commander_state.ref, key::roster_hero_id, key::empty);
		if (roster_hero_id == key::empty || (limited && !gd::array_has(state, hero_ids.ref, str(roster_hero_id)))) {
			continue;
		}
		const DictRef active_entry = state.new_dict();
		state.set(active_entry, str(key::placement_id), str(text(state, encounter.ref, key::placement_id, key::empty)));
		state.set(active_entry, str(key::commander_state), dict_value(gd::deep_duplicate_dict(state, commander_state.ref)));
		state.set(active, str(roster_hero_id), dict_value(active_entry));
	}
	// Only a site or town holding a defender's state can add one.
	for (const Value &town : gd::field_items(state, overworld, str(key::towns))) {
		if (gd::is_dict(town) && state.has(town.ref, str(key::ai_defender_commander_state))) {
			// _active_town_defender_entry.
			not_ported("a town's defender commander");
		}
	}
	for (const Value &node : gd::field_items(state, overworld, str(key::resource_nodes))) {
		if (gd::is_dict(node) && state.has(node.ref, str(key::ai_defender_commander_state))) {
			// _active_resource_defender_entry.
			not_ported("a site's defender commander");
		}
	}
	return active;
}

DictRef _resolved_encounter_lookup(State &state, const Value &resolved_encounters) {
	const DictRef lookup = state.new_dict();
	if (gd::is_array(resolved_encounters)) {
		for (const Value &value : gd::items(state, resolved_encounters)) {
			state.set(lookup, str(gd::stringify_or_fallback(state, value)), bool_value(true));
		}
	}
	return lookup;
}

ArrayRef _faction_commander_ids(State &state, Atom faction_id) {
	const ArrayRef hero_ids = state.new_array();
	if (faction_id == key::empty) {
		return hero_ids;
	}
	const DictRef faction = gd::content_row(state, state::ContentTable::Faction, faction_id);
	for (const Value &hero_id_value : gd::field_items(state, faction, str(key::hero_ids))) {
		const Atom hero_id = gd::stringify_or_fallback(state, hero_id_value);
		if (hero_id != key::empty && !gd::array_has(state, hero_ids, str(hero_id))) {
			state.append(hero_ids, str(hero_id));
		}
	}
	return hero_ids;
}

void normalize_all_commander_rosters(State &state, DictRef session) {
	_normalize_town_defender_commander_states(state, session);
	_normalize_resource_defender_commander_states(state, session);
	const DictRef overworld = session_view::overworld(state, session);
	const Value states = get_or_new_array(state, overworld, key::enemy_states);
	if (!gd::is_array(states)) {
		return;
	}
	bool changed = false;
	for (int64_t index = 0; index < state.array_size(states.ref); ++index) {
		const Value enemy_state = state.at(states.ref, index);
		if (!gd::is_dict(enemy_state)) {
			continue;
		}
		const Atom faction_id = player_rules::controller_id(state, enemy_state.ref, key::empty);
		if (faction_id == key::empty) {
			continue;
		}
		const ArrayRef normalized_roster = normalize_commander_roster(state, session, faction_id, get_or_new_array(state, enemy_state.ref, key::commander_roster));
		if (!gd::equal(state, get_or_new_array(state, enemy_state.ref, key::commander_roster), array_value(normalized_roster))) {
			state.set(enemy_state.ref, str(key::commander_roster), array_value(normalized_roster));
			state.set_at(states.ref, index, enemy_state);
			changed = true;
		}
	}
	if (changed) {
		state.set(overworld, str(key::enemy_states), states);
	}
}

void _normalize_town_defender_commander_states(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	for (const Value &town : gd::field_items(state, overworld, str(key::towns))) {
		if (gd::is_dict(town) && _town_has_ai_defender(state, town.ref)) {
			// _active_town_defender_entry and _clear_town_defender_metadata.
			not_ported("a town's defender commander");
		}
	}
}

void _normalize_resource_defender_commander_states(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	for (const Value &node : gd::field_items(state, overworld, str(key::resource_nodes))) {
		if (gd::is_dict(node) && _resource_has_ai_defender(state, node.ref)) {
			// _active_resource_defender_entry and _clear_resource_defender_metadata.
			not_ported("a site's defender commander");
		}
	}
}

bool _town_has_ai_defender(State &state, DictRef town) {
	return state.has(town, str(key::ai_defender_commander_state))
			|| text(state, town, key::ai_defender_roster_hero_id, key::empty) != key::empty
			|| text(state, town, key::ai_defended_by_faction_id, key::empty) != key::empty;
}

bool _resource_has_ai_defender(State &state, DictRef node) {
	return state.has(node, str(key::ai_defender_commander_state))
			|| text(state, node, key::ai_defender_roster_hero_id, key::empty) != key::empty
			|| text(state, node, key::ai_defended_by_faction_id, key::empty) != key::empty;
}

DictRef _normalized_commander_record(State &state, const Value &entry_value, const Value &commander_state_value) {
	const DictRef entry = dict_or_new(state, entry_value);
	const DictRef commander_state = dict_or_new(state, commander_state_value);
	const int64_t deployments = imax(0, imax(gd::int_field(state, entry, key::deployments, 0), gd::int_field(state, commander_state, key::deployments, 0)));
	const int64_t battle_wins = imax(0, imax(gd::int_field(state, entry, key::battle_wins, 0), gd::int_field(state, commander_state, key::battle_wins, 0)));
	const int64_t times_defeated = imax(0, imax(gd::int_field(state, entry, key::times_defeated, 0), gd::int_field(state, commander_state, key::times_defeated, 0)));
	const int64_t strategic_successes = imax(0, imax(gd::int_field(state, entry, key::strategic_successes, 0), gd::int_field(state, commander_state, key::strategic_successes, 0)));
	Atom last_outcome = text(state, commander_state, key::last_outcome, key::empty);
	if (last_outcome == key::empty) {
		last_outcome = text(state, entry, key::last_outcome, key::empty);
	}
	const DictRef record = state.new_dict();
	state.set(record, str(key::deployments), int_value(deployments));
	state.set(record, str(key::battle_wins), int_value(battle_wins));
	state.set(record, str(key::times_defeated), int_value(times_defeated));
	state.set(record, str(key::strategic_successes), int_value(strategic_successes));
	state.set(record, str(key::last_outcome), str(last_outcome));
	state.set(record, str(key::renown), int_value(_commander_renown_from_record(state, record)));
	return record;
}

DictRef _normalized_commander_memory(State &state, const Value &entry_value, const Value &commander_state_value) {
	const DictRef entry = dict_or_new(state, entry_value);
	const DictRef commander_state = dict_or_new(state, commander_state_value);
	const DictRef entry_commander_state = dict_or_new(state, get_or_new_dict(state, entry, key::commander_state));
	const DictRef raw_memory = state.new_dict();
	for (const Atom memory_key : kCommanderMemoryKeys) {
		Value value;
		if (state.lookup(entry, str(memory_key), value)) {
			state.set(raw_memory, str(memory_key), value);
		}
	}
	const Value sources[] = {
		get_or_new_dict(state, entry, key::target_memory),
		get_or_new_dict(state, entry_commander_state, key::target_memory),
		get_or_new_dict(state, commander_state, key::target_memory),
	};
	for (const Value &source : sources) {
		if (!gd::is_dict(source)) {
			continue;
		}
		const state::ValueList source_keys = state.dict(source.ref).keys.list();
		for (const Value &source_key : source_keys) {
			state.set(raw_memory, str(gd::stringify_or_fallback(state, source_key)), gd::index(state, source.ref, source_key));
		}
	}
	const DictRef memory = state.new_dict();
	auto copy_text = [&](Atom field) {
		state.set(memory, str(field), str(text(state, raw_memory, field, key::empty)));
	};
	auto copy_count = [&](Atom field) {
		state.set(memory, str(field), int_value(count_field(state, raw_memory, field)));
	};
	copy_text(key::focus_target_kind);
	copy_text(key::focus_target_id);
	copy_text(key::focus_target_label);
	copy_count(key::focus_pressure_count);
	copy_text(key::last_target_kind);
	copy_text(key::last_target_id);
	copy_text(key::last_target_label);
	copy_text(key::front_label);
	state.set(memory, str(key::front_x), int_value(gd::int_field(state, raw_memory, key::front_x, 0)));
	state.set(memory, str(key::front_y), int_value(gd::int_field(state, raw_memory, key::front_y, 0)));
	copy_text(key::rival_kind);
	copy_text(key::rival_id);
	copy_text(key::rival_label);
	copy_count(key::rivalry_count);
	const DictRef success_counts = _normalized_commander_target_kind_counts(state, get_or_new_dict(state, raw_memory, key::target_success_counts));
	state.set(memory, str(key::target_success_counts), dict_value(success_counts));
	const DictRef failure_counts = _normalized_commander_target_kind_counts(state, get_or_new_dict(state, raw_memory, key::target_failure_counts));
	state.set(memory, str(key::target_failure_counts), dict_value(failure_counts));
	copy_text(key::last_success_target_kind);
	copy_text(key::last_success_outcome);
	copy_text(key::last_failure_target_kind);
	copy_text(key::last_failure_outcome);
	if (
			text(state, memory, key::focus_target_id, key::empty) == key::empty
			&& text(state, memory, key::last_target_id, key::empty) == key::empty
			&& text(state, memory, key::rival_id, key::empty) == key::empty
			&& text(state, memory, key::front_label, key::empty) == key::empty
			&& gd::int_field(state, memory, key::focus_pressure_count, 0) <= 0
			&& gd::int_field(state, memory, key::rivalry_count, 0) <= 0
			&& gd::is_empty(state, success_counts)
			&& gd::is_empty(state, failure_counts)
			&& text(state, memory, key::last_success_target_kind, key::empty) == key::empty
			&& text(state, memory, key::last_failure_target_kind, key::empty) == key::empty) {
		return state.new_dict();
	}
	return memory;
}

DictRef _normalized_commander_army_continuity(State &state, const Value &entry_value, const Value &commander_state_value, Atom encounter_id) {
	const DictRef entry = dict_or_new(state, entry_value);
	const DictRef commander_state = dict_or_new(state, commander_state_value);
	const DictRef entry_commander_state = dict_or_new(state, get_or_new_dict(state, entry, key::commander_state));
	const DictRef raw_continuity = state.new_dict();
	std::vector<Value> continuity_sources;
	if (_is_army_continuity_payload(state, dict_value(entry))) {
		continuity_sources.push_back(dict_value(entry));
	}
	continuity_sources.push_back(get_or_new_dict(state, entry, key::army_continuity));
	continuity_sources.push_back(get_or_new_dict(state, entry_commander_state, key::army_continuity));
	continuity_sources.push_back(get_or_new_dict(state, commander_state, key::army_continuity));
	for (const Value &source : continuity_sources) {
		if (!gd::is_dict(source)) {
			continue;
		}
		const state::ValueList source_keys = state.dict(source.ref).keys.list();
		for (const Value &source_key : source_keys) {
			state.set(raw_continuity, str(gd::stringify_or_fallback(state, source_key)), gd::index(state, source.ref, source_key));
		}
	}
	const Atom resolved_encounter_id = text(state, raw_continuity, key::encounter_id, encounter_id);
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::stacks), get_or_new_array(state, raw_continuity, key::stacks));
	const DictRef normalized_payload = _normalize_army_payload(state, dict_value(payload));
	// var stacks: Array = normalized_payload.get("stacks", []).
	const ArrayRef stacks = gd::as_array(get_or_new_array(state, normalized_payload, key::stacks));
	int64_t base_strength = count_field(state, raw_continuity, key::base_strength);
	if (base_strength <= 0 && resolved_encounter_id != key::empty) {
		base_strength = _army_strength(state, get_or_new_array(state, _base_enemy_army(state, resolved_encounter_id), key::stacks));
	}
	if (base_strength <= 0 && state.array_size(stacks) == 0) {
		return state.new_dict();
	}
	if (base_strength <= 0) {
		base_strength = _army_strength(state, array_value(stacks));
	}
	const int64_t current_strength = _army_strength(state, array_value(stacks));
	Atom status = text(state, raw_continuity, key::status, key::empty);
	if (status == key::empty) {
		status = _army_continuity_status(state, current_strength, base_strength);
	}
	int64_t strength_percent = 100;
	if (base_strength > 0) {
		strength_percent = compat::float_to_int(compat::godot_round((static_cast<double>(current_strength) * 100.0) / static_cast<double>(base_strength)));
	}
	const DictRef continuity = state.new_dict();
	state.set(continuity, str(key::encounter_id), str(resolved_encounter_id));
	state.set(continuity, str(key::stacks), array_value(gd::deep_duplicate_array(state, stacks)));
	state.set(continuity, str(key::base_strength), int_value(base_strength));
	state.set(continuity, str(key::current_strength), int_value(current_strength));
	state.set(continuity, str(key::rebuild_need), int_value(imax(0, gd::sub(base_strength, current_strength))));
	state.set(continuity, str(key::strength_percent), int_value(iclamp(strength_percent, 0, 100)));
	state.set(continuity, str(key::status), str(status));
	state.set(continuity, str(key::headcount), int_value(_army_headcount(state, array_value(stacks))));
	state.set(continuity, str(key::company_count), int_value(state.array_size(stacks)));
	state.set(continuity, str(key::summary), str(_army_continuity_summary(state, status, current_strength, base_strength)));
	return continuity;
}

DictRef _normalized_commander_role_state(State &state, const Value &source, const Value &fallback_source) {
	const DictRef source_dict = dict_or_new(state, source);
	const DictRef fallback_dict = dict_or_new(state, fallback_source);
	Value role_value = get_or_new_dict(state, source_dict, key::commander_role_state);
	if (!gd::is_dict(role_value)) {
		const Value nested = get_or_new_dict(state, source_dict, key::commander_state);
		if (gd::is_dict(nested)) {
			role_value = get_or_new_dict(state, nested.ref, key::commander_role_state);
		}
	}
	if (!gd::is_dict(role_value)) {
		role_value = get_or_new_dict(state, fallback_dict, key::commander_role_state);
	}
	if (!gd::is_dict(role_value)) {
		const Value nested = get_or_new_dict(state, fallback_dict, key::commander_state);
		if (gd::is_dict(nested)) {
			role_value = get_or_new_dict(state, nested.ref, key::commander_role_state);
		}
	}
	if (!gd::is_dict(role_value)) {
		return state.new_dict();
	}
	const DictRef role_payload = role_value.ref;
	Atom role = text(state, role_payload, key::role, key::empty);
	if (!one_of(role, { key::raider, key::defender, key::retaker, key::stabilizer, key::scout, key::recovering, key::reserve })) {
		role = key::empty;
	}
	const Atom target_kind = text(state, role_payload, key::target_kind, key::empty);
	const Atom target_id = text(state, role_payload, key::target_id, key::empty);
	if (role == key::empty && target_kind == key::empty && target_id == key::empty) {
		return state.new_dict();
	}
	const DictRef role_state = state.new_dict();
	state.set(role_state, str(key::role), str(role != key::empty ? role : key::reserve));
	state.set(role_state, str(key::role_status), str(text(state, role_payload, key::role_status, key::empty)));
	state.set(role_state, str(key::task_class), str(text(state, role_payload, key::task_class, key::empty)));
	state.set(role_state, str(key::target_kind), str(target_kind));
	state.set(role_state, str(key::target_id), str(target_id));
	state.set(role_state, str(key::target_label), str(text(state, role_payload, key::target_label, target_id)));
	state.set(role_state, str(key::front_id), str(text(state, role_payload, key::front_id, key::empty)));
	state.set(role_state, str(key::origin_id), str(text(state, role_payload, key::origin_id, key::empty)));
	state.set(role_state, str(key::assigned_day), int_value(count_field(state, role_payload, key::assigned_day)));
	state.set(role_state, str(key::expires_day), int_value(count_field(state, role_payload, key::expires_day)));
	state.set(role_state, str(key::last_validation), str(text(state, role_payload, key::last_validation, key::valid)));
	state.set(role_state, str(key::reason_codes), array_value(_normalize_string_array(state, get_or_new_array(state, role_payload, key::reason_codes))));
	state.set(role_state, str(key::source_policy), str(text(state, role_payload, key::source_policy, key::live)));
	return role_state;
}

DictRef _normalized_commander_target_kind_counts(State &state, const Value &value) {
	const DictRef counts = state.new_dict();
	if (!gd::is_dict(value)) {
		return counts;
	}
	const state::ValueList value_keys = state.dict(value.ref).keys.list();
	for (const Value &key_value : value_keys) {
		const Atom kind = gd::stringify_or_fallback(state, key_value);
		if (!one_of(kind, { key::resource, key::town, key::artifact, key::encounter, key::hero })) {
			continue;
		}
		const int64_t count = iclamp(gd::to_int(state, gd::index(state, value.ref, key_value)), 0, 9);
		if (count > 0) {
			state.set(counts, str(kind), int_value(count));
		}
	}
	return counts;
}

DictRef _apply_commander_army_metadata(State &state, DictRef commander_state, const Value &army_source) {
	if (gd::is_empty(state, commander_state)) {
		return state.new_dict();
	}
	const DictRef commander = gd::deep_duplicate_dict(state, commander_state);
	const DictRef continuity = _normalized_commander_army_continuity(state, army_source, dict_value(commander), key::empty);
	state.set(commander, str(key::army_continuity), dict_value(continuity));
	state.set(commander, str(key::army_status), str(text(state, continuity, key::status, key::empty)));
	state.set(commander, str(key::army_brief), str(commander_army_brief(state, dict_value(continuity))));
	state.set(commander, str(key::army_summary), str(commander_army_summary(state, dict_value(continuity))));
	state.set(commander, str(key::army_base_strength), int_value(count_field(state, continuity, key::base_strength)));
	state.set(commander, str(key::army_current_strength), int_value(count_field(state, continuity, key::current_strength)));
	state.set(commander, str(key::army_rebuild_need), int_value(count_field(state, continuity, key::rebuild_need)));
	return commander;
}

DictRef _apply_commander_memory_metadata(State &state, DictRef commander_state, const Value &memory_source) {
	if (gd::is_empty(state, commander_state)) {
		return state.new_dict();
	}
	const DictRef commander = gd::deep_duplicate_dict(state, commander_state);
	DictRef memory = _normalized_commander_memory(state, memory_source, dict_value(state.new_dict()));
	if (gd::is_empty(state, memory)) {
		memory = _normalized_commander_memory(state, dict_value(commander), dict_value(state.new_dict()));
	}
	state.set(commander, str(key::target_memory), dict_value(memory));
	state.set(commander, str(key::memory_brief), str(commander_memory_brief(state, dict_value(memory))));
	state.set(commander, str(key::memory_summary), str(commander_memory_summary(state, dict_value(memory))));
	return commander;
}

DictRef _apply_commander_record_metadata(State &state, DictRef commander_state, const Value &record_source) {
	const DictRef commander = gd::deep_duplicate_dict(state, commander_state);
	const DictRef record = _normalized_commander_record(state, record_source, dict_value(commander));
	state.set(commander, str(key::deployments), int_value(count_field(state, record, key::deployments)));
	state.set(commander, str(key::battle_wins), int_value(count_field(state, record, key::battle_wins)));
	state.set(commander, str(key::times_defeated), int_value(count_field(state, record, key::times_defeated)));
	state.set(commander, str(key::strategic_successes), int_value(count_field(state, record, key::strategic_successes)));
	state.set(commander, str(key::renown), int_value(count_field(state, record, key::renown)));
	state.set(commander, str(key::veterancy_rank), int_value(_commander_veterancy_rank_from_record(state, record)));
	state.set(commander, str(key::veterancy_label), str(commander_veterancy_label(state, dict_value(record))));
	state.set(commander, str(key::record_summary), str(commander_record_summary(state, dict_value(record))));
	state.set(commander, str(key::last_outcome), str(text_or(state, record, key::last_outcome, state.get(commander, str(key::last_outcome), str(key::empty)))));
	return commander;
}

DictRef _apply_commander_role_metadata(State &state, DictRef commander_state, const Value &role_source) {
	if (gd::is_empty(state, commander_state)) {
		return state.new_dict();
	}
	const DictRef commander = gd::deep_duplicate_dict(state, commander_state);
	const DictRef role_state = _normalized_commander_role_state(state, role_source, dict_value(commander));
	if (gd::is_empty(state, role_state)) {
		state.erase(commander, str(key::commander_role_state));
	} else {
		state.set(commander, str(key::commander_role_state), dict_value(role_state));
	}
	return commander;
}

int64_t _commander_renown_from_record(State &state, DictRef record) {
	const int64_t deployments = count_field(state, record, key::deployments);
	const int64_t battle_wins = count_field(state, record, key::battle_wins);
	const int64_t times_defeated = count_field(state, record, key::times_defeated);
	const int64_t strategic_successes = count_field(state, record, key::strategic_successes);
	const int64_t half_successes = compat::float_to_int(compat::godot_floor(static_cast<double>(strategic_successes) / 2.0));
	return iclamp(gd::sub(gd::add(gd::add(deployments, gd::mul(battle_wins, 2)), half_successes), times_defeated), 0, 9);
}

int64_t _commander_veterancy_rank_from_record(State &state, DictRef record) {
	const int64_t deployments = count_field(state, record, key::deployments);
	const int64_t battle_wins = count_field(state, record, key::battle_wins);
	const int64_t renown = imax(0, gd::int_field(state, record, key::renown, _commander_renown_from_record(state, record)));
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

Atom commander_veterancy_label(State &state, const Value &source) {
	const int64_t rank = _commander_veterancy_rank_from_record(state, _normalized_commander_record(state, source, dict_value(state.new_dict())));
	return kCommanderVeterancyLabels[iclamp(rank, 0, 3)];
}

Atom commander_record_summary(State &state, const Value &source) {
	const DictRef record = _normalized_commander_record(state, source, dict_value(state.new_dict()));
	const int64_t deployments = count_field(state, record, key::deployments);
	const int64_t wins = count_field(state, record, key::battle_wins);
	const int64_t defeats = count_field(state, record, key::times_defeated);
	const int64_t strategic_successes = count_field(state, record, key::strategic_successes);
	if (deployments <= 0 && wins <= 0 && defeats <= 0 && strategic_successes <= 0) {
		return key::empty;
	}
	std::vector<std::string> parts;
	const Atom veterancy = commander_veterancy_label(state, dict_value(record));
	if (veterancy != key::empty) {
		parts.push_back(state.text(veterancy));
	}
	auto counted = [](int64_t amount, const char *noun) {
		return compat::itos(amount) + " " + noun + (amount == 1 ? "" : "s");
	};
	parts.push_back(counted(deployments, "raid"));
	if (wins > 0) {
		parts.push_back(counted(wins, "win"));
	}
	if (strategic_successes > 0) {
		parts.push_back(counted(strategic_successes, "objective"));
	}
	if (defeats > 0) {
		parts.push_back(counted(defeats, "defeat"));
	} else if (wins > 0) {
		parts.push_back("undefeated");
	}
	return join_parts(state, parts);
}

Atom commander_memory_brief(State &state, const Value &source) {
	const DictRef memory = _normalized_commander_memory(state, source, dict_value(state.new_dict()));
	if (gd::is_empty(state, memory)) {
		return key::empty;
	}
	const Atom rival_label = text(state, memory, key::rival_label, key::empty);
	const int64_t rivalry_count = count_field(state, memory, key::rivalry_count);
	if (rival_label != key::empty && rivalry_count >= 2) {
		return state.intern("holds a grudge against " + state.text(rival_label));
	}
	const Atom focus_label = text(state, memory, key::focus_target_label, key::empty);
	const int64_t focus_count = count_field(state, memory, key::focus_pressure_count);
	if (focus_label != key::empty && focus_count >= 2) {
		return state.intern("returns to " + state.text(focus_label));
	}
	return key::empty;
}

Atom commander_memory_summary(State &state, const Value &source) {
	const DictRef memory = _normalized_commander_memory(state, source, dict_value(state.new_dict()));
	if (gd::is_empty(state, memory)) {
		return key::empty;
	}
	std::vector<std::string> parts;
	const Atom focus_label = text(state, memory, key::focus_target_label, key::empty);
	const int64_t focus_count = count_field(state, memory, key::focus_pressure_count);
	if (focus_label != key::empty) {
		std::string focus_summary = "Target " + state.text(focus_label);
		if (focus_count > 1) {
			focus_summary += " (" + compat::itos(focus_count) + " raids)";
		}
		parts.push_back(focus_summary);
	}
	const Atom rival_label = text(state, memory, key::rival_label, key::empty);
	const int64_t rivalry_count = count_field(state, memory, key::rivalry_count);
	if (rival_label != key::empty) {
		std::string rival_summary = "Rival " + state.text(rival_label);
		if (rivalry_count > 1) {
			rival_summary += " x" + compat::itos(rivalry_count);
		}
		parts.push_back(rival_summary);
	}
	return join_parts(state, parts);
}

DictRef commander_army_continuity(State &state, const Value &source) {
	return _normalized_commander_army_continuity(state, source, dict_value(state.new_dict()), key::empty);
}

Atom commander_army_status(State &state, const Value &source) {
	return text(state, _normalized_commander_army_continuity(state, source, dict_value(state.new_dict()), key::empty), key::status, key::empty);
}

Atom commander_army_brief(State &state, const Value &source) {
	const Atom status = commander_army_status(state, source);
	if (status == key::shattered) {
		return key::shattered_host;
	}
	if (status == key::rebuilding) {
		return key::rebuilding_host;
	}
	if (status == key::scarred) {
		return key::scarred_host;
	}
	return key::empty;
}

Atom commander_army_summary(State &state, const Value &source) {
	return text(state, _normalized_commander_army_continuity(state, source, dict_value(state.new_dict()), key::empty), key::summary, key::empty);
}

bool _is_army_continuity_payload(State &state, const Value &value) {
	if (!gd::is_dict(value)) {
		return false;
	}
	const DictRef payload = value.ref;
	return state.has(payload, str(key::base_strength))
			|| state.has(payload, str(key::current_strength))
			|| state.has(payload, str(key::rebuild_need))
			|| state.has(payload, str(key::strength_percent))
			|| state.has(payload, str(key::stacks));
}

Atom _army_continuity_status(State &, int64_t current_strength, int64_t base_strength) {
	if (base_strength <= 0) {
		return key::empty;
	}
	if (current_strength <= 0) {
		return key::shattered;
	}
	if (current_strength >= base_strength) {
		return key::ready;
	}
	if ((static_cast<double>(current_strength) / static_cast<double>(base_strength)) >= 0.7) {
		return key::scarred;
	}
	return key::rebuilding;
}

Atom _army_continuity_summary(State &state, Atom status, int64_t current_strength, int64_t base_strength) {
	if (base_strength <= 0) {
		return key::empty;
	}
	const char *prefix = "Battle-ready host";
	if (status == key::shattered) {
		prefix = "Shattered host";
	} else if (status == key::rebuilding) {
		prefix = "Rebuilding host";
	} else if (status == key::scarred) {
		prefix = "Scarred host";
	}
	return state.intern(std::string(prefix) + " " + compat::itos(imax(0, current_strength)) + "/" + compat::itos(imax(0, base_strength)));
}

int64_t _army_headcount(State &state, const Value &stacks) {
	int64_t count = 0;
	if (!gd::is_array(stacks)) {
		return count;
	}
	for (const Value &stack_value : gd::items(state, stacks)) {
		if (!gd::is_dict(stack_value)) {
			continue;
		}
		count = gd::add(count, count_field(state, stack_value.ref, key::count));
	}
	return count;
}

int64_t _army_strength(State &state, const Value &stacks) {
	int64_t total = 0;
	if (!gd::is_array(stacks)) {
		return total;
	}
	// Without the unit strength memo (_sync_unit_strength_memo): each value is
	// computed from the unit's row.
	for (const Value &stack_value : gd::items(state, stacks)) {
		if (!gd::is_dict(stack_value)) {
			continue;
		}
		const Atom unit_id = text(state, stack_value.ref, key::unit_id, key::empty);
		const int64_t count = count_field(state, stack_value.ref, key::count);
		if (unit_id == key::empty || count <= 0) {
			continue;
		}
		total = gd::add(total, gd::mul(_unit_strength_value(state, unit_id), count));
	}
	return total;
}

int64_t _unit_strength_value(State &state, Atom unit_id) {
	const DictRef unit = gd::content_row(state, state::ContentTable::Unit, unit_id);
	const int64_t ranged_bonus = gd::bool_field(state, unit, key::ranged, false) ? 3 : 0;
	const int64_t sum = gd::add(gd::add(gd::add(gd::int_field(state, unit, key::hp, 1), gd::int_field(state, unit, key::min_damage, 1)), gd::int_field(state, unit, key::max_damage, 1)), ranged_bonus);
	return imax(6, sum);
}

DictRef _base_enemy_army(State &state, Atom encounter_id) {
	const DictRef encounter = gd::content_row(state, state::ContentTable::Encounter, encounter_id);
	if (gd::is_empty(state, encounter)) {
		return state.new_dict();
	}
	const DictRef group = gd::content_row(state, state::ContentTable::ArmyGroup, text(state, encounter, key::enemy_group_id, key::empty));
	return _normalize_army_payload(state, dict_value(group));
}

DictRef _normalize_army_payload(State &state, const Value &army) {
	if (!gd::is_dict(army)) {
		return state.new_dict();
	}
	const ArrayRef normalized_stacks = state.new_array();
	for (const Value &stack_value : gd::field_items(state, army.ref, str(key::stacks))) {
		if (!gd::is_dict(stack_value)) {
			continue;
		}
		const Atom unit_id = text(state, stack_value.ref, key::unit_id, key::empty);
		const int64_t count = count_field(state, stack_value.ref, key::count);
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
	const DictRef normalized = state.new_dict();
	state.set(normalized, str(key::id), str(text(state, army.ref, key::id, key::empty)));
	state.set(normalized, str(key::name), str(text(state, army.ref, key::name, key::raid_host)));
	state.set(normalized, str(key::stacks), array_value(normalized_stacks));
	return normalized;
}

DictRef _normalize_command_payload(State &state, const Value &value) {
	const DictRef command = state.new_dict();
	const bool known = gd::is_dict(value);
	for (const Atom stat : { key::attack, key::defense, key::power, key::knowledge }) {
		state.set(command, str(stat), int_value(known ? count_field(state, value.ref, stat) : 0));
	}
	return command;
}

DictRef _normalize_enemy_progression(State &state, DictRef commander_state) {
	DictRef commander = hero_progression_rules::ensure_hero_progression(state, gd::deep_duplicate_dict(state, commander_state));
	int64_t guard = 0;
	// commander stays progression-ensured: the ensure above, then choose_specialty's result.
	while (hero_progression_rules::raw_pending_choices_remaining(state, commander) > 0 && guard < 8) {
		const DictRef pending_choice = hero_progression_rules::current_pending_choice(state, commander);
		if (gd::is_empty(state, pending_choice)) {
			break;
		}
		const Atom chosen_specialty = _preferred_enemy_specialty_id(state, commander, pending_choice);
		if (chosen_specialty == key::empty) {
			break;
		}
		commander = hero_progression_rules::choose_specialty(state, commander, chosen_specialty);
		++guard;
	}
	return guard > 0 ? hero_progression_rules::ensure_hero_progression(state, commander) : commander;
}

Atom _preferred_enemy_specialty_id(State &state, DictRef commander_state, DictRef pending_choice) {
	// A computer commander's pick: its focus specialties first, then those of
	// its command path, battle and magic ones over adventure ones, and ranking
	// up what it holds over starting something new.
	const Value options = get_or_new_array(state, pending_choice, key::options);
	if (!gd::is_array(options) || state.array_size(options.ref) == 0) {
		return key::empty;
	}
	_sync_specialty_pick(state);
	const Value focus_value = get_or_new_array(state, commander_state, key::specialty_focus_ids);
	const ArrayRef focus = gd::is_array(focus_value) ? focus_value.ref : state.new_array();
	const Atom path = hero_progression_rules::command_path(state, commander_state);
	Atom best = gd::stringify_or_fallback(state, state.at(options.ref, 0));
	double best_score = -1.0;
	for (const Value &option : gd::items(state, options)) {
		const Atom specialty_id = gd::stringify_or_fallback(state, option);
		const DictRef specialty = hero_progression_rules::specialty_definition(state, specialty_id);
		double score = 0.0;
		if (gd::array_has(state, focus, str(specialty_id))) {
			score += gd::to_float(adventure_static(state, key::SPECIALTY_FOCUS_SCORE));
		}
		if (text(state, specialty, key::path, key::any) == path) {
			score += gd::to_float(adventure_static(state, key::SPECIALTY_PATH_SCORE));
		}
		if (text(state, specialty, key::group, key::empty) != key::adventure) {
			score += gd::to_float(adventure_static(state, key::SPECIALTY_NOT_ADVENTURE_SCORE));
		}
		if (hero_progression_rules::specialty_rank(state, commander_state, specialty_id) > 0) {
			score += gd::to_float(adventure_static(state, key::SPECIALTY_RANK_UP_SCORE));
		}
		if (score > best_score) {
			best_score = score;
			best = specialty_id;
		}
	}
	return best;
}

void _sync_specialty_pick(State &state) {
	// The pick weights (content/ai_hero_weights.json, "specialty_pick") in the
	// script's static vars, read again when the content revision changes.
	const int64_t revision = gd::content_revision(state);
	if (gd::equal(state, int_value(revision), adventure_static(state, key::_specialty_pick_revision))) {
		return;
	}
	const DictRef pick = gd::as_dict(gd::index(state, gd::content_file(state, key::ai_hero_weights_path), str(key::specialty_pick)));
	const Atom script = key::enemy_adventure_rules_script;
	// SPECIALTY_*_SCORE = float(pick[field]), String weights left to GDScript.
	const auto assign = [&](Atom name, Atom field) {
		const Value weight = gd::index(state, pick, str(field));
		if (weight.is_string_like()) {
			not_ported("a specialty pick weight as a String");
		}
		gd::set_static_var(state, script, name, gd::float_value(gd::to_float(weight)));
	};
	assign(key::SPECIALTY_FOCUS_SCORE, key::focus);
	assign(key::SPECIALTY_PATH_SCORE, key::path);
	assign(key::SPECIALTY_NOT_ADVENTURE_SCORE, key::not_adventure);
	assign(key::SPECIALTY_RANK_UP_SCORE, key::rank_up);
	gd::set_static_var(state, script, key::_specialty_pick_revision, int_value(revision));
}

Atom _normalize_commander_status(State &state, const Value &value) {
	const Atom status = gd::stringify_or_fallback(state, value);
	if (one_of(status, { key::available, key::active, key::recovering })) {
		return status;
	}
	return key::available;
}

ArrayRef _normalize_string_array(State &state, const Value &value) {
	const ArrayRef output = state.new_array();
	if (!gd::is_array(value)) {
		return output;
	}
	for (const Value &item : gd::items(state, value)) {
		const Atom entry = gd::stringify_or_fallback(state, item);
		if (entry != key::empty && !gd::array_has(state, output, str(entry))) {
			state.append(output, str(entry));
		}
	}
	return output;
}

ArrayRef _merge_unique_strings(State &state, const Value &primary, const Value &secondary) {
	const ArrayRef merged = state.new_array();
	for (const Value *source : { &primary, &secondary }) {
		if (!gd::is_array(*source)) {
			continue;
		}
		for (const Value &entry : gd::items(state, *source)) {
			const Atom entry_text = gd::stringify_or_fallback(state, entry);
			if (entry_text != key::empty && !gd::array_has(state, merged, str(entry_text))) {
				state.append(merged, str(entry_text));
			}
		}
	}
	return merged;
}

ArrayRef _normalized_specialty_ranks(State &state, const Value &primary, const Value &secondary) {
	// Each known specialty up to its max rank, secondary first.
	const ArrayRef normalized = state.new_array();
	const DictRef catalog = hero_progression_rules::_specialty_catalog(state);
	for (const Value *source : { &secondary, &primary }) {
		if (!gd::is_array(*source)) {
			continue;
		}
		for (const Value &specialty_value : gd::items(state, *source)) {
			const Atom specialty_id = gd::stringify_or_fallback(state, specialty_value);
			const DictRef row = specialty_row(state, catalog, specialty_id);
			// HeroProgressionRules.has_specialty and max_rank_for_specialty.
			if (gd::is_empty(state, row)) {
				continue;
			}
			if (hero_progression_rules::_rank_in_array(state, normalized, specialty_id) < imax(1, gd::int_field(state, row, key::max_rank, 1))) {
				state.append(normalized, str(specialty_id));
			}
		}
	}
	return normalized;
}

ArrayRef _normalized_specialty_focus_ids(State &state, const Value &value) {
	const ArrayRef normalized = state.new_array();
	if (!gd::is_array(value)) {
		return normalized;
	}
	const DictRef catalog = hero_progression_rules::_specialty_catalog(state);
	for (const Value &specialty_value : gd::items(state, value)) {
		const Atom specialty_id = gd::stringify_or_fallback(state, specialty_value);
		if (specialty_id == key::empty || gd::array_has(state, normalized, str(specialty_id))) {
			continue;
		}
		// HeroProgressionRules.has_specialty.
		if (gd::is_empty(state, specialty_row(state, catalog, specialty_id))) {
			continue;
		}
		state.append(normalized, str(specialty_id));
	}
	return normalized;
}

ArrayRef _hero_starting_spell_ids(State &state, DictRef hero_template) {
	const ArrayRef spell_ids = state.new_array();
	for (const Value &spell_id_value : gd::field_items(state, hero_template, str(key::starting_spell_ids))) {
		const Atom spell_id = gd::stringify_or_fallback(state, spell_id_value);
		if (spell_id == key::empty) {
			continue;
		}
		if (gd::is_empty(state, gd::content_row(state, state::ContentTable::Spell, spell_id))) {
			continue;
		}
		if (!gd::array_has(state, spell_ids, str(spell_id))) {
			state.append(spell_ids, str(spell_id));
		}
	}
	return spell_ids;
}

} // namespace enemy_adventure_rules

} // namespace aurelion::rules::port
