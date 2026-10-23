#include "aurelion_rules/port/registry.hpp"

#include "aurelion_rules/port/generated_reward_rules.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/native_random_map_package_session_bridge.hpp"
#include "aurelion_rules/port/overworld_rules_human.hpp"
#include "aurelion_rules/port/random_map_generator_rules.hpp"
#include "aurelion_rules/port/scenario_select_rules_setup.hpp"

namespace aurelion::rules::port {

namespace {

using state::State;
using state::Value;
namespace overworld = overworld_rules;
namespace water = water_travel_rules;
namespace ssr = scenario_select_rules;
namespace bridge = native_random_map_package_session_bridge;
namespace rewards = generated_reward_rules;
namespace hero_command = hero_command_rules;
namespace hero_progression = hero_progression_rules;
namespace rmg = random_map_generator_rules;
using overworld::Vector2i;

// The parameters as GDScript's types left them. A session is its view, a
// Dictionary (DayEngine.gd), or Nil.
gd::DictRef D(const Value *args, int index) {
	return gd::as_dict(args[index]);
}
gd::ArrayRef A(const Value *args, int index) {
	return gd::as_array(args[index]);
}
gd::Atom S(const Value *args, int index) {
	return gd::to_string(args[index]);
}
int64_t I(const Value *args, int index) {
	return args[index].i;
}
bool B(const Value *args, int index) {
	return gd::to_bool(args[index]);
}
Vector2i V(const Value *args, int index) {
	return {args[index].vx(), args[index].vy()};
}
bool nil(const Value *args, int index) {
	return args[index].kind == state::Kind::Nil;
}

// GDScript stops with a runtime error on a null session here; no screen passes one.
void no_null_session(const Value *args) {
	if (nil(args, 0)) {
		throw state::NotPorted("a null session");
	}
}

#define PORT(script, fn, arity, mutates, body) \
	{ #script "." #fn, arity, mutates, [](State &s, const Value *a) -> Value { (void)s; (void)a; body; } }
// A merged slice's function (owner decision D-d): GDScript keeps only a thin
// wrapper over it, which tools/native_battle_switch.py writes in place of the
// switch and the GDScript body.
#define NATIVE(script, fn, arity, mutates, body) PORT(script, fn, arity, mutates, body)

// The human seat's functions ported so far (Phase 7). The ones that write
// fill the caches in the session's metadata (the blocked-tile and spatial
// lookup indexes) and the scripts' static vars (terrain passability, the
// normalized read scope's cache, the pathing debug profile).
const Function kFunctions[] = {
	// 7.1, the routes (merge 1a).
	NATIVE(OverworldRules, tile_is_blocked, 4, true,
			no_null_session(a);
			return gd::bool_value(overworld::tile_is_blocked(s, D(a, 0), I(a, 1), I(a, 2), I(a, 3)))),
	NATIVE(OverworldRules, tile_has_route_interaction, 5, true,
			if (nil(a, 0)) return gd::bool_value(false);
			return gd::bool_value(overworld::tile_has_route_interaction(s, D(a, 0), I(a, 1), I(a, 2), I(a, 3), B(a, 4)))),
	NATIVE(OverworldRules, tile_is_actionable_route_destination, 4, true,
			if (nil(a, 0)) return gd::bool_value(false);
			return gd::bool_value(overworld::tile_is_actionable_route_destination(s, D(a, 0), I(a, 1), I(a, 2), I(a, 3)))),
	NATIVE(OverworldRules, hero_route_tile_blocked, 4, true,
			no_null_session(a);
			return gd::bool_value(overworld::hero_route_tile_blocked(s, D(a, 0), I(a, 1), I(a, 2), I(a, 3)))),
	NATIVE(OverworldRules, hero_route_destination, 4, true,
			no_null_session(a);
			return gd::bool_value(overworld::hero_route_destination(s, D(a, 0), I(a, 1), I(a, 2), I(a, 3)))),
	// The route search, one call per route the screens show.
	NATIVE(OverworldRules, hero_route_path, 5, true,
			if (nil(a, 0)) return gd::array_value(s.new_array());
			return gd::array_value(overworld::hero_route_path(s, D(a, 0), V(a, 1), V(a, 2), I(a, 3), B(a, 4)))),
	NATIVE(OverworldRules, hero_route_path_lengths, 3, true,
			if (nil(a, 0)) return gd::dict_value(s.new_dict());
			return gd::dict_value(overworld::hero_route_path_lengths(s, D(a, 0), V(a, 1), a[2]))),
	NATIVE(OverworldRules, resource_node_interaction_at_tile, 4, true,
			if (nil(a, 0)) return gd::dict_value(s.new_dict());
			return gd::dict_value(overworld::resource_node_interaction_at_tile(s, D(a, 0), I(a, 1), I(a, 2), I(a, 3)))),
	NATIVE(OverworldRules, tile_step_cuts_blocked_corner, 4, true,
			no_null_session(a);
			return gd::bool_value(overworld::tile_step_cuts_blocked_corner(s, D(a, 0), V(a, 1), V(a, 2), I(a, 3)))),
	NATIVE(OverworldRules, active_linked_transit_edges, 2, true,
			if (nil(a, 0)) return gd::array_value(s.new_array());
			return gd::array_value(overworld::active_linked_transit_edges(s, D(a, 0), I(a, 1)))),
	NATIVE(OverworldRules, linked_transit_neighbors_from_edges, 2, false,
			return gd::array_value(overworld::linked_transit_neighbors_from_edges(s, a[0], V(a, 1)))),
	NATIVE(OverworldRules, active_linked_transit_signature, 1, true,
			if (nil(a, 0)) return s.string("linked_transit:");
			return gd::str(overworld::active_linked_transit_signature(s, D(a, 0)))),
	NATIVE(OverworldRules, route_movement_preview, 3, false,
			return gd::dict_value(overworld::route_movement_preview(s, a[0], a[1], I(a, 2)))),
	NATIVE(OverworldRules, guard_engagement_encounter_at_tile, 4, true,
			no_null_session(a);
			return gd::dict_value(overworld::guard_engagement_encounter_at_tile(s, D(a, 0), I(a, 1), I(a, 2), I(a, 3)))),
	NATIVE(OverworldRules, guard_engagement_approach_route, 2, true,
			if (nil(a, 0)) return gd::array_value(s.new_array());
			return gd::array_value(overworld::guard_engagement_approach_route(s, D(a, 0), D(a, 1)))),
	NATIVE(OverworldRules, blocking_object_feedback_surface_at_tile, 3, false,
			if (nil(a, 0)) return gd::dict_value(s.new_dict());
			return gd::dict_value(overworld::blocking_object_feedback_surface_at_tile(s, D(a, 0), I(a, 1), I(a, 2)))),
	NATIVE(WaterTravelRules, is_sailing, 1, false,
			return gd::bool_value(water::is_sailing(s, a[0]))),
	// 7.11, game setup (merge 1b): a new game from a generated map or the maps
	// folder. A session it makes is a SessionData object, which the setup
	// fills through its view; a session it gets is a view or Nil.
	// 7.11, difficulty and labels.
	NATIVE(ScenarioSelectRules, build_difficulty_options, 1, true,
			return gd::array_value(ssr::build_difficulty_options(s, S(a, 0)))),
	NATIVE(ScenarioSelectRules, difficulty_label, 1, true,
			return gd::str(ssr::difficulty_label(s, S(a, 0)))),
	NATIVE(ScenarioSelectRules, difficulty_summary, 1, true,
			return gd::str(ssr::difficulty_summary(s, S(a, 0)))),
	NATIVE(ScenarioSelectRules, launch_mode_label, 1, true,
			return gd::str(ssr::launch_mode_label(s, S(a, 0)))),
	NATIVE(ScenarioSelectRules, build_current_session_summary, 1, true,
			return gd::str(ssr::build_current_session_summary(s, a[0]))),
	NATIVE(ScenarioSelectRules, generated_skirmish_display_name, 1, true,
			return gd::str(ssr::generated_skirmish_display_name(s, a[0]))),
	NATIVE(ScenarioSelectRules, _skirmish_difficulty_consequence, 2, true,
			return gd::str(ssr::_skirmish_difficulty_consequence(s, S(a, 0), S(a, 1)))),
	NATIVE(ScenarioSelectRules, describe_skirmish_difficulty_check, 2, true,
			return gd::str(ssr::describe_skirmish_difficulty_check(s, S(a, 0), S(a, 1)))),
	NATIVE(ScenarioSelectRules, _first_substantive_line, 1, true,
			return gd::str(ssr::_first_substantive_line(s, S(a, 0)))),
	NATIVE(ScenarioSelectRules, _compact_sentence, 2, true,
			return gd::str(ssr::_compact_sentence(s, S(a, 0), I(a, 1)))),
	// 7.11, the player's random map config.
	NATIVE(ScenarioSelectRules, random_map_faction_options, 0, true,
			return gd::array_value(ssr::random_map_faction_options(s))),
	NATIVE(ScenarioSelectRules, random_map_hero_options_for_faction, 1, true,
			return gd::array_value(ssr::random_map_hero_options_for_faction(s, S(a, 0)))),
	NATIVE(ScenarioSelectRules, random_map_default_hero_id_for_faction, 1, true,
			return gd::str(ssr::random_map_default_hero_id_for_faction(s, S(a, 0)))),
	NATIVE(ScenarioSelectRules, random_map_seed_requests_auto, 1, true,
			return gd::bool_value(ssr::random_map_seed_requests_auto(s, S(a, 0)))),
	NATIVE(ScenarioSelectRules, random_map_fresh_auto_seed, 0, true,
			return gd::str(ssr::random_map_fresh_auto_seed(s))),
	NATIVE(ScenarioSelectRules, random_map_size_class_default, 1, true,
			return gd::dict_value(ssr::random_map_size_class_default(s, S(a, 0)))),
	NATIVE(ScenarioSelectRules, build_random_map_player_config, 12, true,
			return gd::dict_value(ssr::build_random_map_player_config(s, S(a, 0), S(a, 1), S(a, 2), I(a, 3), S(a, 4), B(a, 5), S(a, 6), S(a, 7), S(a, 8), S(a, 9), S(a, 10), A(a, 11)))),
	NATIVE(ScenarioSelectRules, random_map_size_class_label, 1, true,
			return gd::str(ssr::random_map_size_class_label(s, S(a, 0)))),
	NATIVE(ScenarioSelectRules, random_map_monster_strength_id, 1, true,
			return gd::str(ssr::random_map_monster_strength_id(s, S(a, 0)))),
	NATIVE(ScenarioSelectRules, random_map_monster_strength_label, 1, true,
			return gd::str(ssr::random_map_monster_strength_label(s, S(a, 0)))),
	NATIVE(ScenarioSelectRules, random_map_player_setup_options, 0, true,
			return gd::dict_value(ssr::random_map_player_setup_options(s))),
	NATIVE(ScenarioSelectRules, random_map_player_count_options_for_template, 1, true,
			return gd::array_value(ssr::random_map_player_count_options_for_template(s, S(a, 0)))),
	NATIVE(ScenarioSelectRules, random_map_profile_options_for_template, 1, true,
			return gd::array_value(ssr::random_map_profile_options_for_template(s, S(a, 0)))),
	NATIVE(ScenarioSelectRules, _random_map_public_h3maped_launch_config, 1, true,
			return gd::dict_value(ssr::_random_map_public_h3maped_launch_config(s, D(a, 0)))),
	// 7.11, generating the map and starting the game.
	NATIVE(ScenarioSelectRules, generated_map_package_directory_policy, 0, true,
			return gd::dict_value(ssr::generated_map_package_directory_policy(s))),
	NATIVE(ScenarioSelectRules, build_random_map_skirmish_setup_with_retry, 3, true,
			return gd::dict_value(ssr::build_random_map_skirmish_setup_with_retry(s, D(a, 0), S(a, 1), D(a, 2)))),
	NATIVE(ScenarioSelectRules, build_random_map_skirmish_setup, 2, true,
			return gd::dict_value(ssr::build_random_map_skirmish_setup(s, D(a, 0), S(a, 1)))),
	NATIVE(ScenarioSelectRules, start_random_map_skirmish_session, 2, true,
			return ssr::start_random_map_skirmish_session(s, D(a, 0), S(a, 1))),
	NATIVE(ScenarioSelectRules, start_random_map_skirmish_session_from_setup, 1, true,
			return ssr::start_random_map_skirmish_session_from_setup(s, D(a, 0))),
	NATIVE(ScenarioSelectRules, restart_generated_skirmish_session, 1, true,
			return gd::dict_value(ssr::restart_generated_skirmish_session(s, a[0]))),
	NATIVE(ScenarioSelectRules, _generated_map_package_dir, 0, true,
			return gd::str(ssr::_generated_map_package_dir(s))),
	// 7.11, the maps folder.
	NATIVE(ScenarioSelectRules, maps_folder_package_id_is_valid, 1, true,
			return gd::bool_value(ssr::maps_folder_package_id_is_valid(s, S(a, 0)))),
	NATIVE(ScenarioSelectRules, maps_folder_package_id_for_stem, 1, true,
			return gd::str(ssr::maps_folder_package_id_for_stem(s, S(a, 0)))),
	NATIVE(ScenarioSelectRules, maps_folder_package_stem_from_id, 1, true,
			return gd::str(ssr::maps_folder_package_stem_from_id(s, S(a, 0)))),
	NATIVE(ScenarioSelectRules, safe_maps_folder_package_stem, 1, true,
			return gd::str(ssr::safe_maps_folder_package_stem(s, S(a, 0)))),
	NATIVE(ScenarioSelectRules, build_maps_folder_package_browser_entries, 1, true,
			return gd::array_value(ssr::build_maps_folder_package_browser_entries(s, D(a, 0)))),
	NATIVE(ScenarioSelectRules, maps_folder_package_index, 1, true,
			return gd::dict_value(ssr::maps_folder_package_index(s, D(a, 0)))),
	NATIVE(ScenarioSelectRules, maps_folder_package_entry, 2, true,
			return gd::dict_value(ssr::maps_folder_package_entry(s, S(a, 0), D(a, 1)))),
	NATIVE(ScenarioSelectRules, build_maps_folder_package_skirmish_setup, 3, true,
			return gd::dict_value(ssr::build_maps_folder_package_skirmish_setup(s, S(a, 0), S(a, 1), D(a, 2)))),
	NATIVE(ScenarioSelectRules, build_maps_folder_package_skirmish_setup_from_entry, 2, true,
			return gd::dict_value(ssr::build_maps_folder_package_skirmish_setup_from_entry(s, D(a, 0), S(a, 1)))),
	NATIVE(ScenarioSelectRules, load_maps_folder_package_session_from_entry, 3, true,
			return ssr::load_maps_folder_package_session_from_entry(s, D(a, 0), S(a, 1), D(a, 2))),
	NATIVE(ScenarioSelectRules, start_maps_folder_package_skirmish_session, 2, true,
			return ssr::start_maps_folder_package_skirmish_session(s, S(a, 0), S(a, 1))),
	NATIVE(ScenarioSelectRules, start_maps_folder_package_skirmish_session_from_entry, 2, true,
			return ssr::start_maps_folder_package_skirmish_session_from_entry(s, D(a, 0), S(a, 1))),
	// 7.11, the session from the map's documents.
	NATIVE(NativeRandomMapPackageSessionBridge, build_session_from_adoption, 3, true,
			return bridge::build_session_from_adoption(s, D(a, 0), S(a, 1), D(a, 2))),
	NATIVE(NativeRandomMapPackageSessionBridge, boats_from_objects, 1, true,
			return gd::array_value(bridge::boats_from_objects(s, A(a, 0)))),
	// 7.11, the map objects' meanings.
	NATIVE(GeneratedRewardRules, resolve, 3, true,
			return gd::dict_value(rewards::resolve(s, D(a, 0), A(a, 1), A(a, 2)))),
	NATIVE(GeneratedRewardRules, is_skipped, 1, true,
			return gd::bool_value(rewards::is_skipped(s, D(a, 0)))),
	NATIVE(GeneratedRewardRules, boat_tile, 1, true,
			return gd::dict_value(rewards::boat_tile(s, D(a, 0)))),
	NATIVE(GeneratedRewardRules, bank_key, 2, true,
			return gd::str(rewards::bank_key(s, I(a, 0), I(a, 1)))),
	NATIVE(GeneratedRewardRules, bank_level_roll, 2, true,
			return gd::int_value(rewards::bank_level_roll(s, S(a, 0), S(a, 1)))),
	NATIVE(GeneratedRewardRules, native_guard_stacks, 3, true,
			return gd::array_value(rewards::native_guard_stacks(s, S(a, 0), S(a, 1), I(a, 2)))),
	NATIVE(GeneratedRewardRules, bank_guard_stacks, 1, true,
			return gd::array_value(rewards::bank_guard_stacks(s, D(a, 0)))),
	NATIVE(GeneratedRewardRules, experience_for_h3m, 1, true,
			return gd::int_value(rewards::experience_for_h3m(s, I(a, 0)))),
	// 7.11, the start heroes.
	NATIVE(HeroCommandRules, army_has_troops, 1, true,
			return gd::bool_value(hero_command::army_has_troops(s, a[0]))),
	NATIVE(HeroCommandRules, seed_start_heroes_from_session, 1, true,
			hero_command::seed_start_heroes_from_session(s, a[0]); return Value()),
	// 7.11, a hero's summary.
	NATIVE(HeroProgressionRules, brief_summary, 1, true,
			return gd::str(hero_progression::brief_summary(s, D(a, 0)))),
	// 7.11, the config normalized.
	NATIVE(RandomMapGeneratorRules, normalize_config, 1, true,
			return gd::dict_value(rmg::normalize_config(s, D(a, 0)))),
};

// The host calls of a merged slice's functions (gd::call_static), as HOST
// entries are but read by no tool: no shadow run reaches them, so they have
// no shadow wrapper. A pure one (Host::pure) is written back to, undoably,
// and read nothing again after.
#define NATIVE_HOST(script, fn, arity) { #script "." #fn, arity, true }

constexpr Host kHosts[] = {
	// 7.11: a new game's SessionData (session_state_store::new_session_data).
	NATIVE_HOST(SessionStateStore, new_session_data, 7),
};

#undef NATIVE_HOST

#undef NATIVE
#undef PORT

} // namespace

// The human seat's table, listed in registry_tables.cpp. A path its port
// leaves out is a native failure: there is no GDScript to fall back to after
// the slice merges (owner decision D-d).
Table human_table() {
	Table table{"HEROES_NATIVE_HUMAN_LOG", kFunctions, sizeof(kFunctions) / sizeof(kFunctions[0])};
	table.hosts = kHosts;
	table.host_count = sizeof(kHosts) / sizeof(kHosts[0]);
	return table;
}

} // namespace aurelion::rules::port
