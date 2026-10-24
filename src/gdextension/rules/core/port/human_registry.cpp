#include "aurelion_rules/port/registry.hpp"

#include "aurelion_rules/port/generated_reward_rules.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/native_random_map_package_session_bridge.hpp"
#include "aurelion_rules/port/overworld_rules_context.hpp"
#include "aurelion_rules/port/overworld_rules_human.hpp"
#include "aurelion_rules/port/overworld_rules_move.hpp"
#include "aurelion_rules/port/random_map_generator_rules.hpp"
#include "aurelion_rules/port/save_service.hpp"
#include "aurelion_rules/port/scenario_outcome.hpp"
#include "aurelion_rules/port/scenario_select_rules_setup.hpp"
#include "aurelion_rules/port/session_state_store.hpp"

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
namespace save = save_service;
namespace native_transit = native_transit_rules;
namespace dwellings = creature_dwelling_rules;
namespace visit_buildings = visit_building_rules;
namespace scenario = scenario_rules;
namespace artifacts = artifact_rules;
namespace spells = spell_rules;
namespace towns = town_rules;
namespace building_panel = town_building_panel;
namespace construction_board = town_construction_board;
namespace town_development = town_development_rules;
namespace scenario_script = scenario_script_rules;
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

// The same for a session that is not the first parameter.
void no_null(const Value *args, int index) {
	if (nil(args, index)) {
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
	// 7.12, saves: the SaveService methods the game, the tools and the tests call.
	NATIVE(SaveService, save_file_identity, 1, true,
			return gd::dict_value(save::save_file_identity(s, S(a, 0)))),
	NATIVE(SaveService, inspect_save_file, 1, true,
			return gd::dict_value(save::inspect_save_file(s, S(a, 0)))),
	NATIVE(SaveService, list_save_files, 0, true,
			return gd::array_value(save::list_save_files(s))),
	NATIVE(SaveService, build_file_save_action, 1, true,
			return gd::dict_value(save::build_file_save_action(s, S(a, 0)))),
	NATIVE(SaveService, save_runtime_file_session, 4, true,
			return gd::dict_value(save::save_runtime_file_session(s, a[0], S(a, 1), B(a, 2), S(a, 3)))),
	NATIVE(SaveService, validation_begin_summary_inspection_trace, 0, true,
			save::validation_begin_summary_inspection_trace(s); return Value()),
	NATIVE(SaveService, validation_summary_inspection_trace_snapshot, 0, true,
			return gd::dict_value(save::validation_summary_inspection_trace_snapshot(s))),
	NATIVE(SaveService, validation_end_summary_inspection_trace, 0, true,
			return gd::dict_value(save::validation_end_summary_inspection_trace(s))),
	NATIVE(SaveService, validation_last_runtime_save_profile, 0, true,
			return gd::dict_value(save::validation_last_runtime_save_profile(s))),
	NATIVE(SaveService, validation_summary_cache_snapshot, 0, true,
			return gd::dict_value(save::validation_summary_cache_snapshot(s))),
	NATIVE(SaveService, validation_clear_summary_cache, 0, true,
			save::validation_clear_summary_cache(s); return Value()),
	NATIVE(SaveService, validation_transaction_artifact_paths, 1, true,
			return gd::dict_value(save::validation_transaction_artifact_paths(s, S(a, 0)))),
	NATIVE(SaveService, validation_clear_general_profile_log, 0, true,
			return gd::dict_value(save::validation_clear_general_profile_log(s))),
	NATIVE(SaveService, validation_general_profile_log_snapshot, 0, true,
			return gd::dict_value(save::validation_general_profile_log_snapshot(s))),
	NATIVE(SaveService, validation_general_profile_log_last_records, 1, true,
			return gd::array_value(save::validation_general_profile_log_last_records(s, I(a, 0)))),
	NATIVE(SaveService, save_session, 2, true,
			return gd::str(save::save_session(s, D(a, 0), I(a, 1)))),
	NATIVE(SaveService, save_runtime_manual_session, 2, true,
			return gd::dict_value(save::save_runtime_manual_session(s, a[0], I(a, 1)))),
	NATIVE(SaveService, save_runtime_autosave_session, 3, true,
			return gd::dict_value(save::save_runtime_autosave_session(s, a[0], B(a, 1), B(a, 2)))),
	NATIVE(SaveService, save_manual_session, 2, true,
			return gd::str(save::save_manual_session(s, D(a, 0), I(a, 1)))),
	NATIVE(SaveService, save_autosave_session, 1, true,
			return gd::str(save::save_autosave_session(s, D(a, 0)))),
	NATIVE(SaveService, load_session, 1, true,
			return gd::dict_value(save::load_session(s, I(a, 0)))),
	NATIVE(SaveService, load_autosave, 0, true,
			return gd::dict_value(save::load_autosave(s))),
	NATIVE(SaveService, restore_manual_session, 1, true,
			return save::restore_manual_session(s, I(a, 0))),
	NATIVE(SaveService, restore_autosave_session, 0, true,
			return save::restore_autosave_session(s)),
	NATIVE(SaveService, restore_session_from_summary, 1, true,
			return save::restore_session_from_summary(s, D(a, 0))),
	NATIVE(SaveService, refresh_summary, 1, true,
			return gd::dict_value(save::refresh_summary(s, D(a, 0)))),
	NATIVE(SaveService, build_delete_action, 1, true,
			return gd::dict_value(save::build_delete_action(s, D(a, 0)))),
	NATIVE(SaveService, build_manual_slot_name_action, 1, true,
			return gd::dict_value(save::build_manual_slot_name_action(s, D(a, 0)))),
	NATIVE(SaveService, set_manual_slot_name_from_summary, 2, true,
			return gd::dict_value(save::set_manual_slot_name_from_summary(s, D(a, 0), S(a, 1)))),
	NATIVE(SaveService, build_manual_save_action, 2, true,
			return gd::dict_value(save::build_manual_save_action(s, a[0], I(a, 1)))),
	NATIVE(SaveService, delete_session_from_summary, 1, true,
			return gd::dict_value(save::delete_session_from_summary(s, D(a, 0)))),
	NATIVE(SaveService, save_progression, 1, true,
			return gd::str(save::save_progression(s, D(a, 0)))),
	NATIVE(SaveService, load_progression, 0, true,
			return gd::dict_value(save::load_progression(s))),
	NATIVE(SaveService, has_progression, 0, true,
			return gd::bool_value(save::has_progression(s))),
	NATIVE(SaveService, inspect_progression_storage, 0, true,
			return gd::dict_value(save::inspect_progression_storage(s))),
	NATIVE(SaveService, get_manual_slot_ids, 0, true,
			return gd::array_value(save::get_manual_slot_ids(s))),
	NATIVE(SaveService, get_selected_manual_slot, 0, true,
			return gd::int_value(save::get_selected_manual_slot(s))),
	NATIVE(SaveService, set_selected_manual_slot, 1, true,
			save::set_selected_manual_slot(s, I(a, 0)); return Value()),
	NATIVE(SaveService, inspect_manual_slot, 1, true,
			return gd::dict_value(save::inspect_manual_slot(s, I(a, 0)))),
	NATIVE(SaveService, inspect_autosave, 0, true,
			return gd::dict_value(save::inspect_autosave(s))),
	NATIVE(SaveService, list_session_summaries, 0, true,
			return gd::array_value(save::list_session_summaries(s))),
	NATIVE(SaveService, latest_loadable_summary, 0, true,
			return gd::dict_value(save::latest_loadable_summary(s))),
	NATIVE(SaveService, summary_recency_timestamp, 1, true,
			return gd::float_value(save::summary_recency_timestamp(s, D(a, 0)))),
	NATIVE(SaveService, in_session_save_bar_status, 2, true,
			return gd::dict_value(save::in_session_save_bar_status(s, a[0], I(a, 1)))),
	NATIVE(SaveService, build_current_session_save_context, 1, true,
			return gd::dict_value(save::build_current_session_save_context(s, a[0]))),
	NATIVE(SaveService, build_in_session_save_surface, 5, true,
			return gd::dict_value(save::build_in_session_save_surface(s, a[0], I(a, 1), D(a, 2), B(a, 3), B(a, 4)))),
	NATIVE(SaveService, resume_target_for_session, 1, true,
			return gd::str(save::resume_target_for_session(s, a[0]))),
	NATIVE(SaveService, can_load_summary, 1, true,
			return gd::bool_value(save::can_load_summary(s, D(a, 0)))),
	NATIVE(SaveService, load_action_label, 1, true,
			return gd::str(save::load_action_label(s, D(a, 0)))),
	NATIVE(SaveService, continue_action_label, 1, true,
			return gd::str(save::continue_action_label(s, D(a, 0)))),
	NATIVE(SaveService, load_action_tooltip, 1, true,
			return gd::str(save::load_action_tooltip(s, D(a, 0)))),
	NATIVE(SaveService, describe_summary_resume_recap, 1, true,
			return gd::str(save::describe_summary_resume_recap(s, D(a, 0)))),
	NATIVE(SaveService, describe_summary_play_check, 1, true,
			return gd::str(save::describe_summary_play_check(s, D(a, 0)))),
	NATIVE(SaveService, describe_summary_resume_handoff, 1, true,
			return gd::str(save::describe_summary_resume_handoff(s, D(a, 0)))),
	NATIVE(SaveService, describe_resume_brief, 1, true,
			return gd::str(save::describe_resume_brief(s, D(a, 0)))),
	NATIVE(SaveService, describe_slot_browser_row, 1, true,
			return gd::str(save::describe_slot_browser_row(s, D(a, 0)))),
	NATIVE(SaveService, describe_load_preview, 1, true,
			return gd::str(save::describe_load_preview(s, D(a, 0)))),
	NATIVE(SaveService, describe_slot_continuity_cue, 1, true,
			return gd::str(save::describe_slot_continuity_cue(s, D(a, 0)))),
	NATIVE(SaveService, describe_slot_details, 1, true,
			return gd::str(save::describe_slot_details(s, D(a, 0)))),
	NATIVE(SaveService, format_modified_timestamp, 1, true,
			return gd::str(save::format_modified_timestamp(s, I(a, 0)))),
	NATIVE(SaveService, _autosave_path, 0, true,
			return gd::str(save::_autosave_path(s))),
	NATIVE(SaveService, _inspect_slot, 3, true,
			return gd::dict_value(save::_inspect_slot(s, S(a, 0), S(a, 1), S(a, 2)))),
	NATIVE(SaveService, _normalize_restore_result, 2, true,
			return gd::dict_value(save::_normalize_restore_result(s, D(a, 0), S(a, 1)))),
	NATIVE(SaveService, _ensure_generated_random_map_scenario_registered, 1, true,
			return gd::dict_value(save::_ensure_generated_random_map_scenario_registered(s, D(a, 0)))),
	// 7.12, the save payload normalized (SessionState.normalize_payload, the tests).
	NATIVE(SessionStateStore, normalize_payload, 1, true,
			return gd::dict_value(session_state_store::normalize_payload(s, a[0]))),
	// 7.2, the move and its arrival: what the overworld screen and the
	// GDScript outside this slice call (the panels, the context actions, the
	// battle end's site visit).
	NATIVE(CreatureDwellingRules, summary, 3, false,
			return gd::str(dwellings::summary(s, D(a, 0), D(a, 1), I(a, 2)))),
	NATIVE(HeroCommandRules, field_rendezvous_heroes, 1, true,
			if (nil(a, 0)) return gd::array_value(s.new_array());
			return gd::array_value(hero_command::field_rendezvous_heroes(s, D(a, 0)))),
	NATIVE(OverworldRules, normalize_overworld_state_for_runtime, 1, true,
			if (nil(a, 0)) return Value();
			overworld::normalize_overworld_state_for_runtime(s, D(a, 0)); return Value()),
	NATIVE(OverworldRules, _store_level_fog, 3, true,
			no_null(a, 0);
			overworld::_store_level_fog(s, D(a, 0), D(a, 1), I(a, 2)); return Value()),
	NATIVE(OverworldRules, try_move, 3, true,
			no_null(a, 0);
			return gd::dict_value(overworld::try_move(s, D(a, 0), I(a, 1), I(a, 2)))),
	NATIVE(OverworldRules, native_portal_display_name, 1, false,
			return gd::str(overworld::native_portal_display_name(s, D(a, 0)))),
	NATIVE(OverworldRules, try_move_along_route, 4, true,
			no_null(a, 0);
			return gd::dict_value(overworld::try_move_along_route(s, D(a, 0), a[1], I(a, 2), B(a, 3)))),
	NATIVE(OverworldRules, execute_prevalidated_route, 5, true,
			no_null(a, 0);
			return gd::dict_value(overworld::execute_prevalidated_route(s, D(a, 0), a[1], D(a, 2), I(a, 3), D(a, 4)))),
	NATIVE(OverworldRules, collect_active_resource, 1, true,
			no_null(a, 0);
			return gd::dict_value(overworld::collect_active_resource(s, D(a, 0)))),
	NATIVE(OverworldRules, _resource_reward_choice_context, 2, true,
			no_null(a, 0);
			return gd::dict_value(overworld::_resource_reward_choice_context(s, D(a, 0), D(a, 1)))),
	NATIVE(OverworldRules, _resource_site_artifact_summary, 1, false,
			return gd::str(overworld::_resource_site_artifact_summary(s, D(a, 0)))),
	NATIVE(OverworldRules, _spell_list_text, 1, false,
			return gd::str(overworld::_spell_list_text(s, A(a, 0)))),
	NATIVE(OverworldRules, _resource_site_reward_summary, 1, false,
			return gd::str(overworld::_resource_site_reward_summary(s, D(a, 0)))),
	NATIVE(OverworldRules, _collect_resource_node_result, 5, true,
			no_null(a, 0);
			return gd::dict_value(overworld::_collect_resource_node_result(s, D(a, 0), D(a, 1), B(a, 2), I(a, 3), S(a, 4)))),
	NATIVE(OverworldRules, collect_active_artifact, 1, true,
			no_null(a, 0);
			return gd::dict_value(overworld::collect_active_artifact(s, D(a, 0)))),
	NATIVE(OverworldRules, clear_active_town_visit, 1, true,
			if (nil(a, 0)) return Value();
			overworld::clear_active_town_visit(s, D(a, 0)); return Value()),
	NATIVE(OverworldRules, capture_active_town, 1, true,
			no_null(a, 0);
			return gd::dict_value(overworld::capture_active_town(s, D(a, 0)))),
	NATIVE(OverworldRules, describe_encounter_compact_readability, 2, true,
			no_null(a, 0);
			return gd::str(overworld::describe_encounter_compact_readability(s, D(a, 0), D(a, 1)))),
	NATIVE(OverworldRules, describe_encounter_battle_cue, 2, true,
			no_null(a, 0);
			return gd::str(overworld::describe_encounter_battle_cue(s, D(a, 0), D(a, 1)))),
	NATIVE(OverworldRules, describe_encounter_consequence_surface, 3, true,
			no_null(a, 0);
			return gd::str(overworld::describe_encounter_consequence_surface(s, D(a, 0), D(a, 1), B(a, 2)))),
	NATIVE(OverworldRules, _field_rendezvous_hero_at_tile, 2, true,
			if (nil(a, 0)) return gd::dict_value(s.new_dict());
			return gd::dict_value(overworld::_field_rendezvous_hero_at_tile(s, D(a, 0), V(a, 1)))),
	NATIVE(OverworldRules, get_active_encounter, 1, true,
			no_null(a, 0);
			return gd::dict_value(overworld::get_active_encounter(s, D(a, 0)))),
	NATIVE(OverworldRules, _scenario_objective_player_label, 2, true,
			no_null(a, 0);
			return gd::str(overworld::_scenario_objective_player_label(s, D(a, 0), D(a, 1)))),
	NATIVE(OverworldRules, _resource_site_income_cadence_label, 1, false,
			return gd::str(overworld::_resource_site_income_cadence_label(s, D(a, 0)))),
	NATIVE(OverworldRules, relieve_town_recovery_pressure, 4, true,
			if (nil(a, 0)) return gd::str(state::key::empty);
			return gd::str(overworld::relieve_town_recovery_pressure(s, D(a, 0), S(a, 1), I(a, 2), S(a, 3)))),
	NATIVE(OverworldRules, _find_resource_node_at, 1, true,
			no_null(a, 0);
			return gd::dict_value(overworld::_find_resource_node_at(s, D(a, 0)))),
	NATIVE(OverworldRules, _find_context_resource_node, 1, true,
			no_null(a, 0);
			return gd::dict_value(overworld::_find_context_resource_node(s, D(a, 0)))),
	NATIVE(OverworldRules, _find_active_artifact_node, 1, true,
			no_null(a, 0);
			return gd::dict_value(overworld::_find_active_artifact_node(s, D(a, 0)))),
	NATIVE(OverworldRules, _resource_site_visit_cost, 1, false,
			return gd::dict_value(overworld::_resource_site_visit_cost(s, D(a, 0)))),
	NATIVE(OverworldRules, _resource_site_repeat_ready, 3, true,
			if (nil(a, 0)) return gd::bool_value(false);
			return gd::bool_value(overworld::_resource_site_repeat_ready(s, D(a, 0), D(a, 1), D(a, 2)))),
	NATIVE(OverworldRules, _resource_site_next_visit_day, 2, false,
			return gd::int_value(overworld::_resource_site_next_visit_day(s, D(a, 0), D(a, 1)))),
	NATIVE(OverworldRules, _resource_node_claimable_by_player, 3, true,
			return gd::bool_value(overworld::_resource_node_claimable_by_player(s, D(a, 0), D(a, 1), a[2]))),
	NATIVE(OverworldRules, _resource_node_has_live_ai_defender, 3, true,
			if (nil(a, 0)) return gd::bool_value(false);
			return gd::bool_value(overworld::_resource_node_has_live_ai_defender(s, D(a, 0), D(a, 1), D(a, 2)))),
	NATIVE(OverworldRules, _resource_site_claim_rewards, 1, false,
			return gd::dict_value(overworld::_resource_site_claim_rewards(s, D(a, 0)))),
	NATIVE(OverworldRules, _resource_site_claim_recruits, 1, false,
			return gd::dict_value(overworld::_resource_site_claim_recruits(s, D(a, 0)))),
	NATIVE(OverworldRules, resource_site_is_recruit_source, 1, false,
			return gd::bool_value(overworld::resource_site_is_recruit_source(s, D(a, 0)))),
	NATIVE(OverworldRules, _resource_site_yield_line, 3, true,
			return gd::str(overworld::_resource_site_yield_line(s, a[0], D(a, 1), D(a, 2)))),
	NATIVE(OverworldRules, _resource_site_guard_encounter, 4, true,
			if (nil(a, 0)) return gd::dict_value(s.new_dict());
			return gd::dict_value(overworld::_resource_site_guard_encounter(s, D(a, 0), D(a, 1), D(a, 2), a[3]))),
	NATIVE(OverworldRules, _resource_site_guard_blocks_node, 2, false,
			return gd::bool_value(overworld::_resource_site_guard_blocks_node(s, D(a, 0), D(a, 1)))),
	NATIVE(OverworldRules, _encounter_guard_link, 1, false,
			return gd::dict_value(overworld::_encounter_guard_link(s, D(a, 0)))),
	NATIVE(OverworldRules, _encounter_guard_summary, 2, true,
			return gd::str(overworld::_encounter_guard_summary(s, D(a, 0), a[1]))),
	NATIVE(OverworldRules, _encounter_readiness_surface, 3, true,
			if (nil(a, 0)) return gd::str(state::key::empty);
			return gd::str(overworld::_encounter_readiness_surface(s, D(a, 0), D(a, 1), B(a, 2)))),
	NATIVE(OverworldRules, _encounter_risk_label, 1, false,
			return gd::str(overworld::_encounter_risk_label(s, D(a, 0)))),
	NATIVE(OverworldRules, _encounter_difficulty_label, 1, false,
			return gd::str(overworld::_encounter_difficulty_label(s, D(a, 0)))),
	NATIVE(OverworldRules, _encounter_army_surface, 2, false,
			return gd::str(overworld::_encounter_army_surface(s, D(a, 0), B(a, 1)))),
	NATIVE(OverworldRules, _encounter_army_payload, 1, false,
			return gd::dict_value(overworld::_encounter_army_payload(s, D(a, 0)))),
	NATIVE(OverworldRules, _encounter_reward_surface, 1, false,
			return gd::str(overworld::_encounter_reward_surface(s, D(a, 0)))),
	NATIVE(OverworldRules, _encounter_guard_target_label, 2, true,
			return gd::str(overworld::_encounter_guard_target_label(s, a[0], D(a, 1)))),
	NATIVE(OverworldRules, _non_empty_strings, 1, false,
			return gd::array_value(overworld::_non_empty_strings(s, A(a, 0)))),
	NATIVE(OverworldRules, _humanize_id, 1, false,
			return gd::str(overworld::_humanize_id(s, S(a, 0)))),
	NATIVE(OverworldRules, _describe_recruit_count, 1, false,
			return gd::str(overworld::_describe_recruit_count(s, D(a, 0)))),
	NATIVE(OverworldRules, _resource_site_spell_names, 1, false,
			return gd::array_value(overworld::_resource_site_spell_names(s, D(a, 0)))),
	NATIVE(OverworldRules, _can_afford, 2, true,
			no_null(a, 0);
			return gd::bool_value(overworld::_can_afford(s, D(a, 0), a[1]))),
	NATIVE(OverworldRules, _sync_spellbook_to_hero, 2, true,
			no_null(a, 0);
			overworld::_sync_spellbook_to_hero(s, D(a, 0), I(a, 1)); return Value()),
	NATIVE(OverworldRules, _town_requires_assault, 1, false,
			return gd::bool_value(overworld::_town_requires_assault(s, D(a, 0)))),
	NATIVE(OverworldRules, _attach_post_action_recap, 4, true,
			no_null(a, 1);
			return gd::dict_value(overworld::_attach_post_action_recap(s, D(a, 0), D(a, 1), S(a, 2), D(a, 3)))),
	NATIVE(OverworldRules, _normalize_post_action_recap, 1, false,
			return gd::dict_value(overworld::_normalize_post_action_recap(s, a[0]))),
	NATIVE(OverworldRules, _army_totals, 1, false,
			return gd::dict_value(overworld::_army_totals(s, D(a, 0)))),
	NATIVE(VisitBuildingRules, cadence_label, 1, false,
			return gd::str(visit_buildings::cadence_label(s, D(a, 0)))),
	NATIVE(VisitBuildingRules, summary, 1, false,
			return gd::str(visit_buildings::summary(s, D(a, 0)))),
	NATIVE(ScenarioRules, _objective_label, 2, true,
			no_null(a, 0);
			return gd::str(scenario::_objective_label(s, D(a, 0), D(a, 1)))),
	// 7.2's functions that tests call to set up or check a move.
	NATIVE(OverworldRules, travel_native_passage, 3, true,
			no_null(a, 0);
			return gd::dict_value(overworld::travel_native_passage(s, D(a, 0), D(a, 1), I(a, 2)))),
	NATIVE(OverworldRules, _set_active_hero_position, 3, true,
			no_null(a, 0);
			overworld::_set_active_hero_position(s, D(a, 0), V(a, 1), I(a, 2)); return Value()),
	NATIVE(OverworldRules, _resolve_post_move_interaction, 1, true,
			no_null(a, 0);
			return gd::dict_value(overworld::_resolve_post_move_interaction(s, D(a, 0)))),
	NATIVE(OverworldRules, _refresh_blocked_tile_index_for_interaction, 2, true,
			if (nil(a, 0)) return Value();
			overworld::_refresh_blocked_tile_index_for_interaction(s, D(a, 0), D(a, 1)); return Value()),
	NATIVE(OverworldRules, _route_lock_prompt, 3, true,
			no_null(a, 0);
			return gd::dict_value(overworld::_route_lock_prompt(s, D(a, 0), D(a, 1), D(a, 2)))),
	NATIVE(OverworldRules, _collect_artifact_node_result, 3, true,
			no_null(a, 0);
			return gd::dict_value(overworld::_collect_artifact_node_result(s, D(a, 0), D(a, 1), B(a, 2)))),
	NATIVE(ScenarioRules, evaluate_session_for_event, 2, true,
			no_null(a, 0);
			return gd::dict_value(scenario::evaluate_session_for_event(s, D(a, 0), D(a, 1)))),
	// ScenarioScriptRules' award_experience effect.
	NATIVE(OverworldRules, _award_experience, 2, true,
			no_null(a, 0);
			return gd::array_value(overworld::_award_experience(s, D(a, 0), I(a, 1)))),
	// ScenarioRules.objective_artifact_ids (the towns' artifact trade).
	NATIVE(ScenarioRules, _scenario_objective_dependency, 3, false,
			return gd::dict_value(scenario::_scenario_objective_dependency(s, D(a, 0), D(a, 1), D(a, 2)))),
	// 7.3, context and site actions: what the overworld and town screens, the
	// map editor, the other rules scripts and the tests call.
	NATIVE(ArtifactRules, describe_single_artifact_impact, 1, false,
			return gd::str(artifacts::describe_single_artifact_impact(s, S(a, 0)))),
	NATIVE(ArtifactRules, describe_artifact_short, 1, false,
			return gd::str(artifacts::describe_artifact_short(s, S(a, 0)))),
	NATIVE(ArtifactRules, artifact_collection_state, 4, true,
			return gd::str(artifacts::artifact_collection_state(s, D(a, 0), S(a, 1), B(a, 2), S(a, 3)))),
	NATIVE(ArtifactRules, _bonus_impact_sections, 2, false,
			return gd::array_value(artifacts::_bonus_impact_sections(s, D(a, 0), B(a, 1)))),
	NATIVE(HeroCommandRules, spend_active_hero_movement, 3, true,
			no_null(a, 0);
			return gd::dict_value(hero_command::spend_active_hero_movement(s, D(a, 0), I(a, 1), S(a, 2)))),
	NATIVE(HeroCommandRules, town_recruitment_destination, 2, true,
			no_null(a, 0);
			return gd::dict_value(hero_command::town_recruitment_destination(s, D(a, 0), D(a, 1)))),
	NATIVE(HeroCommandRules, army_slot_snapshot, 3, true,
			if (nil(a, 0)) return gd::dict_value(s.new_dict());
			return gd::dict_value(hero_command::army_slot_snapshot(s, D(a, 0), D(a, 1), S(a, 2)))),
	NATIVE(HeroCommandRules, _stationed_holder_ids, 2, true,
			no_null(a, 0);
			return gd::array_value(hero_command::_stationed_holder_ids(s, D(a, 0), D(a, 1)))),
	NATIVE(HeroCommandRules, _army_slot_holder_is_available, 3, true,
			if (nil(a, 0)) return gd::bool_value(false);
			return gd::bool_value(hero_command::_army_slot_holder_is_available(s, D(a, 0), D(a, 1), S(a, 2)))),
	NATIVE(HeroCommandRules, _holder_label, 3, true,
			no_null(a, 0);
			return gd::str(hero_command::_holder_label(s, D(a, 0), D(a, 1), S(a, 2)))),
	NATIVE(HeroProgressionRules, level_up_summary, 1, true,
			return gd::dict_value(hero_progression::level_up_summary(s, D(a, 0)))),
	NATIVE(HeroProgressionRules, get_choice_actions, 1, true,
			return gd::array_value(hero_progression::get_choice_actions(s, D(a, 0)))),
	NATIVE(HeroProgressionRules, rank_text, 2, false,
			return gd::str(hero_progression::rank_text(s, S(a, 0), I(a, 1)))),
	NATIVE(OverworldRules, describe_native_portal, 2, true,
			no_null(a, 0);
			return gd::str(overworld::describe_native_portal(s, D(a, 0), D(a, 1)))),
	NATIVE(OverworldRules, choose_resource_reward, 3, true,
			no_null(a, 0);
			return gd::dict_value(overworld::choose_resource_reward(s, D(a, 0), S(a, 1), D(a, 2)))),
	NATIVE(OverworldRules, hire_from_dwelling, 3, true,
			no_null(a, 0);
			return gd::dict_value(overworld::hire_from_dwelling(s, D(a, 0), D(a, 1), D(a, 2)))),
	NATIVE(OverworldRules, perform_context_action, 2, true,
			if (nil(a, 0)) return gd::dict_value(s.new_dict());
			return gd::dict_value(overworld::perform_context_action(s, D(a, 0), S(a, 1)))),
	NATIVE(OverworldRules, build_in_active_town, 2, true,
			no_null(a, 0);
			return gd::dict_value(overworld::build_in_active_town(s, D(a, 0), S(a, 1)))),
	NATIVE(OverworldRules, recruit_in_active_town, 4, true,
			no_null(a, 0);
			return gd::dict_value(overworld::recruit_in_active_town(s, D(a, 0), S(a, 1), I(a, 2), B(a, 3)))),
	NATIVE(OverworldRules, get_active_context, 1, true,
			no_null(a, 0);
			return gd::dict_value(overworld::get_active_context(s, D(a, 0)))),
	NATIVE(OverworldRules, town_built_today, 2, false,
			return gd::bool_value(overworld::town_built_today(s, D(a, 0), I(a, 1)))),
	NATIVE(OverworldRules, town_cost_readiness, 4, true,
			return gd::dict_value(overworld::town_cost_readiness(s, D(a, 0), D(a, 1), a[2], I(a, 3)))),
	NATIVE(OverworldRules, town_recruit_cost, 3, true,
			no_null(a, 0);
			return gd::dict_value(overworld::town_recruit_cost(s, D(a, 0), D(a, 1), S(a, 2)))),
	NATIVE(OverworldRules, get_context_actions, 1, true,
			no_null(a, 0);
			return gd::array_value(overworld::get_context_actions(s, D(a, 0)))),
	NATIVE(OverworldRules, get_level_up_prompt, 1, true,
			if (nil(a, 0)) return gd::dict_value(s.new_dict());
			return gd::dict_value(overworld::get_level_up_prompt(s, D(a, 0)))),
	NATIVE(OverworldRules, resolve_level_up, 3, true,
			no_null(a, 0);
			return gd::dict_value(overworld::resolve_level_up(s, D(a, 0), D(a, 1), S(a, 2)))),
	NATIVE(OverworldRules, get_specialty_actions, 1, true,
			no_null(a, 0);
			return gd::array_value(overworld::get_specialty_actions(s, D(a, 0)))),
	NATIVE(OverworldRules, choose_specialty, 3, true,
			no_null(a, 0);
			return gd::dict_value(overworld::choose_specialty(s, D(a, 0), S(a, 1), S(a, 2)))),
	NATIVE(OverworldRules, describe_recruit_source_inspection, 3, true,
			return gd::str(overworld::describe_recruit_source_inspection(s, a[0], D(a, 1), D(a, 2)))),
	NATIVE(OverworldRules, describe_resource_site_surface, 3, true,
			no_null(a, 0);
			return gd::str(overworld::describe_resource_site_surface(s, D(a, 0), D(a, 1), D(a, 2)))),
	NATIVE(OverworldRules, describe_resource_site_control_inspection, 3, true,
			return gd::str(overworld::describe_resource_site_control_inspection(s, a[0], D(a, 1), D(a, 2)))),
	NATIVE(OverworldRules, describe_resource_site_interaction_surface, 2, false,
			return gd::str(overworld::describe_resource_site_interaction_surface(s, D(a, 0), D(a, 1)))),
	NATIVE(OverworldRules, _recruit_source_roster_line, 4, false,
			return gd::str(overworld::_recruit_source_roster_line(s, S(a, 0), a[1], I(a, 2), B(a, 3)))),
	NATIVE(OverworldRules, _resource_site_action_label, 2, false,
			return gd::str(overworld::_resource_site_action_label(s, D(a, 0), D(a, 1)))),
	NATIVE(OverworldRules, _resource_site_role_label, 2, false,
			return gd::str(overworld::_resource_site_role_label(s, D(a, 0), D(a, 1)))),
	NATIVE(OverworldRules, _resource_site_control_brief, 2, false,
			return gd::str(overworld::_resource_site_control_brief(s, D(a, 0), D(a, 1)))),
	NATIVE(OverworldRules, _resource_site_guard_or_contest_line, 3, true,
			return gd::str(overworld::_resource_site_guard_or_contest_line(s, a[0], D(a, 1), D(a, 2)))),
	NATIVE(OverworldRules, _interaction_cadence_label, 1, false,
			return gd::str(overworld::_interaction_cadence_label(s, S(a, 0)))),
	NATIVE(OverworldRules, _resource_site_response_effect_summary, 1, false,
			return gd::str(overworld::_resource_site_response_effect_summary(s, D(a, 0)))),
	NATIVE(OverworldRules, _player_reserve_delivery_plan, 3, true,
			if (nil(a, 0)) return gd::dict_value(s.new_dict());
			return gd::dict_value(overworld::_player_reserve_delivery_plan(s, D(a, 0), D(a, 1), D(a, 2)))),
	NATIVE(OverworldRules, _consume_recruit_payload, 2, true,
			return gd::dict_value(overworld::_consume_recruit_payload(s, a[0], a[1]))),
	NATIVE(OverworldRules, _resource_site_context_summary, 3, true,
			no_null(a, 0);
			return gd::str(overworld::_resource_site_context_summary(s, D(a, 0), D(a, 1), D(a, 2)))),
	NATIVE(OverworldRules, site_recruit_overflow_prompt, 1, true,
			if (nil(a, 0)) return gd::dict_value(s.new_dict());
			return gd::dict_value(overworld::site_recruit_overflow_prompt(s, D(a, 0)))),
	NATIVE(OverworldRules, take_site_recruits_by_dismissing, 3, true,
			no_null(a, 0);
			return gd::dict_value(overworld::take_site_recruits_by_dismissing(s, D(a, 0), I(a, 1), D(a, 2)))),
	NATIVE(OverworldRules, leave_site_recruits, 2, true,
			no_null(a, 0);
			return gd::dict_value(overworld::leave_site_recruits(s, D(a, 0), D(a, 1)))),
	NATIVE(OverworldRules, _issue_resource_site_response, 3, true,
			no_null(a, 0);
			return gd::dict_value(overworld::_issue_resource_site_response(s, D(a, 0), S(a, 1), S(a, 2)))),
	NATIVE(OverworldRules, _army_unit_count, 2, false,
			return gd::int_value(overworld::_army_unit_count(s, a[0], S(a, 1)))),
	NATIVE(OverworldRules, _market_buy_resources, 1, true,
			return gd::array_value(overworld::_market_buy_resources(s, D(a, 0)))),
	NATIVE(OverworldRules, _town_market_cost_coverage, 4, true,
			return gd::dict_value(overworld::_town_market_cost_coverage(s, D(a, 0), D(a, 1), a[2], I(a, 3)))),
	NATIVE(OverworldRules, _apply_market_cost_coverage, 4, true,
			return gd::array_value(overworld::_apply_market_cost_coverage(s, D(a, 0), D(a, 1), a[2], I(a, 3)))),
	NATIVE(OverworldRules, _building_growth_payload, 1, false,
			return gd::dict_value(overworld::_building_growth_payload(s, S(a, 0)))),
	NATIVE(OverworldRules, _max_affordable_count, 2, true,
			no_null(a, 0);
			return gd::int_value(overworld::_max_affordable_count(s, D(a, 0), a[1]))),
	NATIVE(OverworldRules, _apply_resource_transaction_to_pool, 3, true,
			overworld::_apply_resource_transaction_to_pool(s, D(a, 0), a[1], a[2]); return Value()),
	NATIVE(OverworldRules, resource_icon_path, 1, false,
			return gd::str(overworld::resource_icon_path(s, S(a, 0)))),
	NATIVE(OverworldRules, _describe_recruit_projection, 2, false,
			return gd::str(overworld::_describe_recruit_projection(s, a[0], a[1]))),
	NATIVE(OverworldRules, _describe_signed_int, 1, false,
			return gd::str(overworld::_describe_signed_int(s, I(a, 0)))),
	NATIVE(OverworldRules, _context_action_briefing, 3, true,
			no_null(a, 0);
			return gd::str(overworld::_context_action_briefing(s, D(a, 0), a[1], D(a, 2)))),
	NATIVE(OverworldRules, _encounter_pressure_summary, 3, true,
			no_null(a, 0);
			return gd::str(overworld::_encounter_pressure_summary(s, D(a, 0), D(a, 1), B(a, 2)))),
	NATIVE(OverworldRules, _resource_site_opening_value, 1, false,
			return gd::str(overworld::_resource_site_opening_value(s, D(a, 0)))),
	// 7.4 to 7.7, overworld spells, heroes, town actions and the outcome screen:
	// what the overworld, town and outcome screens, the other rules scripts and the
	// tests call.
	NATIVE(OverworldRules, cast_overworld_spell, 2, true,
			no_null(a, 0);
			return gd::dict_value(overworld::cast_overworld_spell(s, D(a, 0), S(a, 1)))),
	NATIVE(OverworldRules, get_spell_actions, 1, true,
			no_null(a, 0);
			return gd::array_value(overworld::get_spell_actions(s, D(a, 0)))),
	NATIVE(SpellRules, cast_overworld_spell_on_day, 2, true,
			return gd::bool_value(spells::cast_overworld_spell_on_day(s, D(a, 0), I(a, 1)))),
	NATIVE(SpellRules, spell_category_label, 1, true,
			return gd::str(spells::spell_category_label(s, D(a, 0)))),
	NATIVE(SpellRules, adventure_spell_consequence_preview, 3, true,
			return gd::dict_value(spells::adventure_spell_consequence_preview(s, D(a, 0), D(a, 1), a[2]))),
	NATIVE(SpellRules, _best_use_line, 4, true,
			return gd::str(spells::_best_use_line(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3)))),
	NATIVE(SpellRules, get_overworld_actions, 3, true,
			return gd::array_value(spells::get_overworld_actions(s, D(a, 0), D(a, 1), I(a, 2)))),
	NATIVE(SpellRules, validate_overworld_spell, 4, true,
			return gd::dict_value(spells::validate_overworld_spell(s, D(a, 0), D(a, 1), a[2], I(a, 3)))),
	NATIVE(SpellRules, effect_summary, 2, true,
			return gd::str(spells::effect_summary(s, D(a, 0), D(a, 1)))),
	NATIVE(SpellRules, battle_spell_timing_summary, 5, true,
			return gd::str(spells::battle_spell_timing_summary(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), D(a, 4)))),
	NATIVE(SpellRules, _overworld_spell_effect_summary, 3, true,
			return gd::str(spells::_overworld_spell_effect_summary(s, D(a, 0), D(a, 1), D(a, 2)))),
	NATIVE(SpellRules, _overworld_target_requirement, 1, true,
			return gd::str(spells::_overworld_target_requirement(s, D(a, 0)))),
	NATIVE(SpellRules, _target_mode_label, 1, false,
			return gd::str(spells::_target_mode_label(s, S(a, 0)))),
	NATIVE(ArtifactRules, equipment_slot_accepts, 2, false,
			return gd::bool_value(artifacts::equipment_slot_accepts(s, S(a, 0), S(a, 1)))),
	NATIVE(ArtifactRules, unequip_artifact, 2, true,
			return gd::dict_value(artifacts::unequip_artifact(s, D(a, 0), S(a, 1)))),
	NATIVE(ArtifactRules, get_management_actions, 1, true,
			return gd::array_value(artifacts::get_management_actions(s, D(a, 0)))),
	NATIVE(ArtifactRules, artifact_id_for_management_action, 2, true,
			return gd::str(artifacts::artifact_id_for_management_action(s, D(a, 0), S(a, 1)))),
	NATIVE(ArtifactRules, artifact_set_context, 1, false,
			return gd::str(artifacts::artifact_set_context(s, S(a, 0)))),
	NATIVE(ArtifactRules, artifact_decision_summary, 2, true,
			return gd::str(artifacts::artifact_decision_summary(s, D(a, 0), S(a, 1)))),
	NATIVE(HeroCommandRules, hero_inspection_snapshot, 2, true,
			no_null(a, 0);
			return gd::dict_value(hero_command::hero_inspection_snapshot(s, D(a, 0), S(a, 1)))),
	NATIVE(HeroCommandRules, hero_template, 1, true,
			return gd::dict_value(hero_command::hero_template(s, D(a, 0)))),
	NATIVE(HeroCommandRules, hero_faction_label, 2, true,
			return gd::str(hero_command::hero_faction_label(s, D(a, 0), S(a, 1)))),
	NATIVE(HeroCommandRules, hero_role_label, 1, true,
			return gd::str(hero_command::hero_role_label(s, D(a, 0)))),
	NATIVE(HeroCommandRules, hero_identity_context_line, 2, true,
			return gd::str(hero_command::hero_identity_context_line(s, D(a, 0), S(a, 1)))),
	NATIVE(HeroCommandRules, hero_progress_context_line, 1, true,
			return gd::str(hero_command::hero_progress_context_line(s, D(a, 0)))),
	NATIVE(HeroCommandRules, hero_readiness_context_line, 2, true,
			return gd::str(hero_command::hero_readiness_context_line(s, D(a, 0), B(a, 1)))),
	NATIVE(HeroCommandRules, manage_army_slots, 7, true,
			no_null(a, 0);
			return gd::dict_value(hero_command::manage_army_slots(s, D(a, 0), D(a, 1), S(a, 2), I(a, 3), S(a, 4), I(a, 5), S(a, 6)))),
	NATIVE(HeroCommandRules, field_slot_action_id, 5, false,
			return gd::str(hero_command::field_slot_action_id(s, S(a, 0), I(a, 1), S(a, 2), I(a, 3), S(a, 4)))),
	NATIVE(HeroCommandRules, field_troops_all_action_id, 2, false,
			return gd::str(hero_command::field_troops_all_action_id(s, S(a, 0), S(a, 1)))),
	NATIVE(HeroCommandRules, field_artifact_place_action_id, 4, false,
			return gd::str(hero_command::field_artifact_place_action_id(s, S(a, 0), S(a, 1), S(a, 2), S(a, 3)))),
	NATIVE(HeroCommandRules, field_artifacts_all_action_id, 2, false,
			return gd::str(hero_command::field_artifacts_all_action_id(s, S(a, 0), S(a, 1)))),
	NATIVE(HeroCommandRules, field_spell_share_action_id, 3, false,
			return gd::str(hero_command::field_spell_share_action_id(s, S(a, 0), S(a, 1), S(a, 2)))),
	NATIVE(HeroCommandRules, field_exchange_state, 2, true,
			no_null(a, 0);
			return gd::dict_value(hero_command::field_exchange_state(s, D(a, 0), S(a, 1)))),
	NATIVE(HeroCommandRules, _hero_roster_line, 2, true,
			return gd::str(hero_command::_hero_roster_line(s, D(a, 0), S(a, 1)))),
	NATIVE(HeroCommandRules, _transfer_empties_hero_army, 5, true,
			return gd::bool_value(hero_command::_transfer_empties_hero_army(s, S(a, 0), a[1], I(a, 2), I(a, 3), B(a, 4)))),
	NATIVE(HeroCommandRules, _resolve_transfer_amount, 2, false,
			return gd::int_value(hero_command::_resolve_transfer_amount(s, S(a, 0), I(a, 1)))),
	NATIVE(OverworldRules, perform_artifact_action, 2, true,
			no_null(a, 0);
			return gd::dict_value(overworld::perform_artifact_action(s, D(a, 0), S(a, 1)))),
	NATIVE(OverworldRules, perform_rendezvous_action, 2, true,
			no_null(a, 0);
			return gd::dict_value(overworld::perform_rendezvous_action(s, D(a, 0), S(a, 1)))),
	NATIVE(OverworldRules, get_artifact_actions, 1, true,
			no_null(a, 0);
			return gd::array_value(overworld::get_artifact_actions(s, D(a, 0)))),
	NATIVE(OverworldRules, get_hero_actions, 1, true,
			no_null(a, 0);
			return gd::array_value(overworld::get_hero_actions(s, D(a, 0)))),
	NATIVE(OverworldRules, switch_active_hero, 2, true,
			no_null(a, 0);
			return gd::dict_value(overworld::switch_active_hero(s, D(a, 0), S(a, 1)))),
	NATIVE(TownRules, get_active_town, 1, true,
			no_null(a, 0);
			return gd::dict_value(towns::get_active_town(s, D(a, 0)))),
	NATIVE(TownRules, get_hero_actions, 1, true,
			no_null(a, 0);
			return gd::array_value(towns::get_hero_actions(s, D(a, 0)))),
	NATIVE(TownRules, get_tavern_actions, 1, true,
			no_null(a, 0);
			return gd::array_value(towns::get_tavern_actions(s, D(a, 0)))),
	NATIVE(TownRules, get_transfer_actions, 1, true,
			no_null(a, 0);
			return gd::array_value(towns::get_transfer_actions(s, D(a, 0)))),
	NATIVE(TownRules, get_artifact_actions, 1, true,
			no_null(a, 0);
			return gd::array_value(towns::get_artifact_actions(s, D(a, 0)))),
	NATIVE(TownRules, switch_active_hero_at_town, 2, true,
			no_null(a, 0);
			return gd::dict_value(towns::switch_active_hero_at_town(s, D(a, 0), S(a, 1)))),
	NATIVE(TownRules, hire_hero_at_active_town, 2, true,
			no_null(a, 0);
			return gd::dict_value(towns::hire_hero_at_active_town(s, D(a, 0), S(a, 1)))),
	NATIVE(TownRules, transfer_in_active_town, 2, true,
			no_null(a, 0);
			return gd::dict_value(towns::transfer_in_active_town(s, D(a, 0), S(a, 1)))),
	NATIVE(TownRules, manage_army_slots_in_active_town, 6, true,
			no_null(a, 0);
			return gd::dict_value(towns::manage_army_slots_in_active_town(s, D(a, 0), S(a, 1), I(a, 2), S(a, 3), I(a, 4), S(a, 5)))),
	NATIVE(TownRules, set_garrison_hero_in_active_town, 2, true,
			no_null(a, 0);
			return gd::dict_value(towns::set_garrison_hero_in_active_town(s, D(a, 0), S(a, 1)))),
	NATIVE(TownRules, manage_artifact_at_active_town, 2, true,
			no_null(a, 0);
			return gd::dict_value(towns::manage_artifact_at_active_town(s, D(a, 0), S(a, 1)))),
	NATIVE(TownRules, _describe_resources, 2, true,
			return gd::str(towns::_describe_resources(s, a[0], S(a, 1)))),
	NATIVE(TownRules, _resource_keys_for_payload, 1, true,
			return gd::array_value(towns::_resource_keys_for_payload(s, a[0]))),
	NATIVE(HeroCommandRules, player_hero_count, 1, true,
			if (nil(a, 0)) return gd::int_value(0);
			return gd::int_value(hero_command::player_hero_count(s, D(a, 0)))),
	NATIVE(HeroCommandRules, recruitable_hero_ids, 1, true,
			if (nil(a, 0)) return gd::array_value(s.new_array());
			return gd::array_value(hero_command::recruitable_hero_ids(s, D(a, 0)))),
	NATIVE(SpellRules, spell_icon_path, 1, false,
			return gd::str(spells::spell_icon_path(s, S(a, 0)))),
	NATIVE(SpellRules, describe_spell_inspection_line, 3, true,
			return gd::str(spells::describe_spell_inspection_line(s, D(a, 0), D(a, 1), D(a, 2)))),
	NATIVE(SpellRules, _mana_readiness_label, 2, true,
			return gd::str(spells::_mana_readiness_label(s, D(a, 0), I(a, 1)))),
	NATIVE(SpellRules, _spell_effect_summary, 2, true,
			return gd::str(spells::_spell_effect_summary(s, D(a, 0), D(a, 1)))),
	NATIVE(TownBuildingPanel, build, 3, true,
			return gd::dict_value(building_panel::build(s, a[0], S(a, 1), D(a, 2)))),
	NATIVE(TownBuildingPanel, recruit_card, 1, true,
			return gd::dict_value(building_panel::recruit_card(s, D(a, 0)))),
	NATIVE(TownBuildingPanel, _action_entry, 1, true,
			return gd::dict_value(building_panel::_action_entry(s, D(a, 0)))),
	NATIVE(TownConstructionBoard, build, 4, true,
			return gd::dict_value(construction_board::build(s, D(a, 0), I(a, 1), D(a, 2), D(a, 3)))),
	NATIVE(TownConstructionBoard, slot_for_building, 2, true,
			return gd::dict_value(construction_board::slot_for_building(s, D(a, 0), S(a, 1)))),
	NATIVE(TownConstructionBoard, format_amount, 1, false,
			return gd::str(construction_board::format_amount(s, I(a, 0)))),
	NATIVE(TownConstructionBoard, resource_name, 1, false,
			return gd::str(construction_board::resource_name(s, S(a, 0)))),
	NATIVE(TownConstructionBoard, roman, 1, false,
			return gd::str(construction_board::roman(s, I(a, 0)))),
	NATIVE(TownRules, building_icon_path, 2, false,
			return gd::str(towns::building_icon_path(s, S(a, 0), S(a, 1)))),
	NATIVE(TownRules, begin_read_scope, 1, true,
			if (nil(a, 0)) return Value();
			towns::begin_read_scope(s, D(a, 0)); return Value()),
	NATIVE(TownRules, end_read_scope, 1, true,
			if (nil(a, 0)) return Value();
			towns::end_read_scope(s, D(a, 0)); return Value()),
	NATIVE(TownRules, can_visit_active_town, 1, true,
			no_null(a, 0);
			return gd::bool_value(towns::can_visit_active_town(s, D(a, 0)))),
	NATIVE(TownRules, get_build_actions, 1, true,
			no_null(a, 0);
			return gd::array_value(towns::get_build_actions(s, D(a, 0)))),
	NATIVE(TownRules, get_recruit_actions, 1, true,
			no_null(a, 0);
			return gd::array_value(towns::get_recruit_actions(s, D(a, 0)))),
	NATIVE(TownRules, get_build_catalog, 1, true,
			no_null(a, 0);
			return gd::array_value(towns::get_build_catalog(s, D(a, 0)))),
	NATIVE(TownRules, get_muster_catalog, 1, true,
			no_null(a, 0);
			return gd::array_value(towns::get_muster_catalog(s, D(a, 0)))),
	NATIVE(TownRules, get_market_actions, 1, true,
			no_null(a, 0);
			return gd::array_value(towns::get_market_actions(s, D(a, 0)))),
	NATIVE(TownRules, get_response_actions, 1, true,
			no_null(a, 0);
			return gd::array_value(towns::get_response_actions(s, D(a, 0)))),
	NATIVE(TownRules, get_spell_learning_actions, 1, true,
			no_null(a, 0);
			return gd::array_value(towns::get_spell_learning_actions(s, D(a, 0)))),
	NATIVE(TownRules, get_specialty_actions, 1, true,
			no_null(a, 0);
			return gd::array_value(towns::get_specialty_actions(s, D(a, 0)))),
	NATIVE(TownRules, build_active_town, 2, true,
			no_null(a, 0);
			return gd::dict_value(towns::build_active_town(s, D(a, 0), S(a, 1)))),
	NATIVE(TownRules, recruit_active_town, 4, true,
			no_null(a, 0);
			return gd::dict_value(towns::recruit_active_town(s, D(a, 0), S(a, 1), I(a, 2), B(a, 3)))),
	NATIVE(TownRules, perform_market_action, 2, true,
			no_null(a, 0);
			return gd::dict_value(towns::perform_market_action(s, D(a, 0), S(a, 1)))),
	NATIVE(TownRules, market_action_label, 1, false,
			return gd::str(towns::market_action_label(s, S(a, 0)))),
	NATIVE(TownRules, perform_response_action, 2, true,
			no_null(a, 0);
			return gd::dict_value(towns::perform_response_action(s, D(a, 0), S(a, 1)))),
	NATIVE(TownRules, learn_spell_at_active_town, 2, true,
			no_null(a, 0);
			return gd::dict_value(towns::learn_spell_at_active_town(s, D(a, 0), S(a, 1)))),
	NATIVE(TownRules, choose_specialty_at_active_town, 2, true,
			no_null(a, 0);
			return gd::dict_value(towns::choose_specialty_at_active_town(s, D(a, 0), S(a, 1)))),
	NATIVE(TownRules, _recruit_choice_impact_line, 3, false,
			return gd::str(towns::_recruit_choice_impact_line(s, S(a, 0), I(a, 1), I(a, 2)))),
	NATIVE(TownRules, _action_recommendation_line, 6, false,
			return gd::str(towns::_action_recommendation_line(s, S(a, 0), S(a, 1), B(a, 2), B(a, 3), S(a, 4), S(a, 5)))),
	NATIVE(TownRules, _unit_tier_label, 1, false,
			return gd::str(towns::_unit_tier_label(s, I(a, 0)))),
	NATIVE(TownRules, _signed_int, 1, false,
			return gd::str(towns::_signed_int(s, I(a, 0)))),
	NATIVE(TownRules, _market_coverage_line, 1, true,
			return gd::str(towns::_market_coverage_line(s, D(a, 0)))),
	NATIVE(TownRules, _cost_shortfall_line, 1, true,
			return gd::str(towns::_cost_shortfall_line(s, D(a, 0)))),
	NATIVE(TownRules, _cost_readiness_line, 3, true,
			return gd::str(towns::_cost_readiness_line(s, D(a, 0), a[1], D(a, 2)))),
	NATIVE(TownRules, _stores_after_cost_line, 2, true,
			return gd::str(towns::_stores_after_cost_line(s, D(a, 0), a[1]))),
	NATIVE(TownRules, _recruit_affordability_label, 3, false,
			return gd::str(towns::_recruit_affordability_label(s, I(a, 0), I(a, 1), S(a, 2)))),
	NATIVE(TownRules, _disabled_reason_line, 4, false,
			return gd::str(towns::_disabled_reason_line(s, B(a, 0), B(a, 1), S(a, 2), S(a, 3)))),
	NATIVE(TownRules, _max_market_affordable_count, 5, true,
			no_null(a, 0);
			return gd::int_value(towns::_max_market_affordable_count(s, D(a, 0), D(a, 1), D(a, 2), a[3], I(a, 4)))),
	NATIVE(TownRules, _multiply_resource_cost, 2, true,
			return gd::dict_value(towns::_multiply_resource_cost(s, a[0], I(a, 1)))),
	NATIVE(TownRules, _building_line, 3, true,
			return gd::str(towns::_building_line(s, S(a, 0), S(a, 1), D(a, 2)))),
	NATIVE(TownRules, _town_name, 1, true,
			return gd::str(towns::_town_name(s, D(a, 0)))),
	NATIVE(TownRules, _town_pressure_label, 1, true,
			return gd::str(towns::_town_pressure_label(s, D(a, 0)))),
	NATIVE(TownRules, _describe_vulnerability_penalties, 1, true,
			return gd::str(towns::_describe_vulnerability_penalties(s, D(a, 0)))),
	NATIVE(TownRules, _max_affordable_count, 2, true,
			no_null(a, 0);
			return gd::int_value(towns::_max_affordable_count(s, D(a, 0), a[1]))),
	NATIVE(TownRules, _town_unit_ids, 1, true,
			return gd::array_value(towns::_town_unit_ids(s, D(a, 0)))),
	NATIVE(TownRules, _unit_is_unlocked_in_town, 2, true,
			return gd::bool_value(towns::_unit_is_unlocked_in_town(s, D(a, 0), S(a, 1)))),
	NATIVE(TownRules, _unlock_building_for_unit, 2, true,
			return gd::str(towns::_unlock_building_for_unit(s, D(a, 0), S(a, 1)))),
	NATIVE(HeroCommandRules, hero_profile_summary, 2, true,
			return gd::str(hero_command::hero_profile_summary(s, D(a, 0), B(a, 1)))),
	NATIVE(HeroCommandRules, town_visiting_hero, 2, true,
			no_null(a, 0);
			return gd::dict_value(hero_command::town_visiting_hero(s, D(a, 0), D(a, 1)))),
	NATIVE(HeroCommandRules, get_tavern_actions, 2, true,
			if (nil(a, 0)) return gd::array_value(s.new_array());
			return gd::array_value(hero_command::get_tavern_actions(s, D(a, 0), D(a, 1)))),
	NATIVE(HeroCommandRules, _army_summary, 1, true,
			return gd::str(hero_command::_army_summary(s, a[0]))),
	NATIVE(HeroCommandRules, _transfer_amount_tokens, 1, false,
			return gd::array_value(hero_command::_transfer_amount_tokens(s, I(a, 0)))),
	NATIVE(HeroCommandRules, _transfer_amount_label, 2, false,
			return gd::str(hero_command::_transfer_amount_label(s, S(a, 0), I(a, 1)))),
	NATIVE(HeroCommandRules, _stack_summary_from_array, 1, true,
			return gd::str(hero_command::_stack_summary_from_array(s, a[0]))),
	NATIVE(HeroProgressionRules, summarize_specialty_ids, 2, true,
			return gd::str(hero_progression::summarize_specialty_ids(s, a[0], B(a, 1)))),
	NATIVE(OverworldRules, town_reinforcement_quality, 2, true,
			return gd::int_value(overworld::town_reinforcement_quality(s, D(a, 0), a[1]))),
	NATIVE(OverworldRules, town_battle_readiness, 2, true,
			return gd::int_value(overworld::town_battle_readiness(s, D(a, 0), a[1]))),
	NATIVE(OverworldRules, town_pressure_output, 2, true,
			return gd::int_value(overworld::town_pressure_output(s, D(a, 0), a[1]))),
	NATIVE(OverworldRules, town_logistics_state, 2, true,
			no_null(a, 0);
			return gd::dict_value(overworld::town_logistics_state(s, D(a, 0), D(a, 1)))),
	NATIVE(OverworldRules, describe_unit_recruit_brief, 2, false,
			return gd::str(overworld::describe_unit_recruit_brief(s, S(a, 0), I(a, 1)))),
	NATIVE(OverworldRules, unit_stack_strength_value, 2, false,
			return gd::int_value(overworld::unit_stack_strength_value(s, S(a, 0), I(a, 1)))),
	NATIVE(OverworldRules, _town_market_actions, 2, true,
			if (nil(a, 0)) return gd::array_value(s.new_array());
			return gd::array_value(overworld::_town_market_actions(s, D(a, 0), D(a, 1)))),
	NATIVE(OverworldRules, _town_response_actions, 2, true,
			if (nil(a, 0)) return gd::array_value(s.new_array());
			return gd::array_value(overworld::_town_response_actions(s, D(a, 0), D(a, 1)))),
	NATIVE(ScenarioRules, describe_session_progress_recap, 2, true,
			if (nil(a, 0)) return gd::str(B(a, 1) ? state::key::progress_recap_no_active_scenario_progress : state::key::empty);
			return gd::str(scenario::describe_session_progress_recap(s, D(a, 0), B(a, 1)))),
	NATIVE(ScenarioRules, describe_session_progress_recap_from_normalized_session, 3, true,
			if (nil(a, 0)) return gd::str(B(a, 1) ? state::key::progress_recap_no_active_scenario_progress : state::key::empty);
			return gd::str(scenario::describe_session_progress_recap_from_normalized_session(s, D(a, 0), B(a, 1), D(a, 2)))),
	NATIVE(ScenarioRules, build_outcome_model, 1, true,
			no_null(a, 0);
			return gd::dict_value(scenario::build_outcome_model(s, D(a, 0)))),
	NATIVE(ScenarioRules, perform_outcome_action, 2, true,
			no_null(a, 0);
			return gd::dict_value(scenario::perform_outcome_action(s, D(a, 0), S(a, 1)))),
	NATIVE(ScenarioRules, _progress_recap_status_line, 2, true,
			no_null(a, 0);
			return gd::str(scenario::_progress_recap_status_line(s, D(a, 0), D(a, 1)))),
	NATIVE(ScenarioRules, _progress_recap_next_step_line, 3, true,
			no_null(a, 0);
			return gd::str(scenario::_progress_recap_next_step_line(s, D(a, 0), D(a, 1), D(a, 2)))),
	NATIVE(OverworldRules, describe_resources, 1, true,
			no_null(a, 0);
			return gd::str(overworld::describe_resources(s, D(a, 0)))),
	NATIVE(OverworldRules, describe_resource_stockpile, 2, true,
			return gd::str(overworld::describe_resource_stockpile(s, a[0], B(a, 1)))),
	NATIVE(OverworldRules, describe_hero, 1, true,
			no_null(a, 0);
			return gd::str(overworld::describe_hero(s, D(a, 0)))),
	NATIVE(OverworldRules, describe_army, 1, true,
			if (nil(a, 0)) return gd::str(state::key::marching_army_0_troops_in_0);
			return gd::str(overworld::describe_army(s, D(a, 0)))),
	NATIVE(OverworldRules, describe_stack_inspection_line, 2, true,
			return gd::str(overworld::describe_stack_inspection_line(s, D(a, 0), D(a, 1)))),
	NATIVE(OverworldRules, _resource_display_name, 1, false,
			return gd::str(overworld::_resource_display_name(s, S(a, 0)))),
	NATIVE(ScenarioScriptRules, describe_recent_events, 2, true,
			if (nil(a, 0)) return gd::str(state::key::empty);
			return gd::str(scenario_script::describe_recent_events(s, D(a, 0), I(a, 1)))),
	// Merge 3: the public functions of 7.4 to 7.7 that only tests call.
	NATIVE(OverworldRules, perform_rendezvous_transfer_action, 2, true,
			no_null(a, 0);
			return gd::dict_value(overworld::perform_rendezvous_transfer_action(s, D(a, 0), S(a, 1)))),
	NATIVE(OverworldRules, describe_town_build_projection, 3, true,
			no_null(a, 0);
			return gd::str(overworld::describe_town_build_projection(s, D(a, 0), D(a, 1), S(a, 2)))),
	NATIVE(HeroCommandRules, transfer_field_stack, 5, true,
			no_null(a, 0);
			return gd::dict_value(hero_command::transfer_field_stack(s, D(a, 0), S(a, 1), S(a, 2), S(a, 3), S(a, 4)))),
	NATIVE(HeroCommandRules, transfer_field_artifact, 4, true,
			no_null(a, 0);
			return gd::dict_value(hero_command::transfer_field_artifact(s, D(a, 0), S(a, 1), S(a, 2), S(a, 3)))),
	NATIVE(HeroCommandRules, teach_field_spell, 4, true,
			no_null(a, 0);
			return gd::dict_value(hero_command::teach_field_spell(s, D(a, 0), S(a, 1), S(a, 2), S(a, 3)))),
	NATIVE(HeroCommandRules, set_town_garrison_hero, 3, true,
			no_null(a, 0);
			return gd::dict_value(hero_command::set_town_garrison_hero(s, D(a, 0), D(a, 1), S(a, 2)))),
	NATIVE(HeroCommandRules, tavern_offer_ids, 1, true,
			if (nil(a, 0)) return gd::array_value(s.new_array());
			return gd::array_value(hero_command::tavern_offer_ids(s, D(a, 0)))),
	NATIVE(TownRules, building_id_for_action, 1, false,
			return gd::str(towns::building_id_for_action(s, S(a, 0)))),
	NATIVE(TownRules, building_category_icon_path, 1, false,
			return gd::str(towns::building_category_icon_path(s, S(a, 0)))),
	NATIVE(TownConstructionBoard, town_building_ids, 1, false,
			return gd::array_value(construction_board::town_building_ids(s, D(a, 0)))),
	NATIVE(SpellRules, spell_school_icon_path, 1, false,
			return gd::str(spells::spell_school_icon_path(s, S(a, 0)))),
	NATIVE(SpellRules, adventure_spell_target_contract, 3, false,
			return gd::dict_value(spells::adventure_spell_target_contract(s, D(a, 0), D(a, 1), a[2]))),
	NATIVE(SpellRules, cast_overworld_spell, 4, false,
			return gd::dict_value(spells::cast_overworld_spell(s, D(a, 0), D(a, 1), S(a, 2), I(a, 3)))),
	// Merge 3: the functions of 7.3 to 7.7 that the Python regressions' GDScript calls.
	NATIVE(ScenarioRules, _objective_progress_counts, 1, true,
			no_null(a, 0);
			return gd::dict_value(scenario::_objective_progress_counts(s, D(a, 0)))),
	NATIVE(OverworldRules, _resource_site_control_label, 2, true,
			return gd::str(overworld::_resource_site_control_label(s, D(a, 0), D(a, 1)))),
	NATIVE(OverworldRules, can_afford_cost_with_town_market, 4, true,
			return gd::bool_value(overworld::can_afford_cost_with_town_market(s, D(a, 0), D(a, 1), a[2], I(a, 3)))),
	NATIVE(OverworldRules, get_town_market_actions, 2, true,
			no_null(a, 0);
			return gd::array_value(overworld::get_town_market_actions(s, D(a, 0), D(a, 1)))),
	NATIVE(OverworldRules, get_town_recruit_options, 1, true,
			return gd::array_value(overworld::get_town_recruit_options(s, D(a, 0)))),
	NATIVE(TownRules, _town_artifact_service_actions, 2, true,
			no_null(a, 0);
			return gd::array_value(towns::_town_artifact_service_actions(s, D(a, 0), D(a, 1)))),
	NATIVE(HeroCommandRules, get_town_transfer_actions, 2, true,
			no_null(a, 0);
			return gd::array_value(hero_command::get_town_transfer_actions(s, D(a, 0), D(a, 1)))),
	NATIVE(HeroCommandRules, transfer_town_stack, 6, true,
			no_null(a, 0);
			return gd::dict_value(hero_command::transfer_town_stack(s, D(a, 0), D(a, 1), S(a, 2), S(a, 3), S(a, 4), S(a, 5)))),
	NATIVE(TownDevelopmentRules, objective_artifact_ids, 1, true,
			return gd::array_value(town_development::objective_artifact_ids(s, a[0]))),
	NATIVE(TownDevelopmentRules, visiting_active_hero, 2, true,
			return gd::bool_value(town_development::visiting_active_hero(s, a[0], D(a, 1)))),
	NATIVE(TownDevelopmentRules, service_actions, 2, true,
			return gd::array_value(town_development::service_actions(s, a[0], D(a, 1)))),
	NATIVE(TownDevelopmentRules, perform_service, 3, true,
			return gd::dict_value(town_development::perform_service(s, a[0], D(a, 1), S(a, 2)))),
};

// The host calls of a merged slice's functions (gd::call_static), as HOST
// entries are but read by no tool: no shadow run reaches them, so they have
// no shadow wrapper. A pure one (Host::pure) is written back to, undoably,
// and read nothing again after.
#define NATIVE_HOST(script, fn, arity) { #script "." #fn, arity, true }
// One that may change what the native call holds (a session's containers, a
// static var the ports read): written back first and read again after.
#define NATIVE_HOST_WRITING(script, fn, arity) { #script "." #fn, arity, false }

constexpr Host kHosts[] = {
	// 7.11: a new game's SessionData (session_state_store::new_session_data).
	NATIVE_HOST(SessionStateStore, new_session_data, 7),
	// 7.12, saves. The profile log stays GDScript (diagnostics the screens and
	// the router write too), and so does the campaign runtime (D-f).
	NATIVE_HOST(ProfileLog, session_metadata, 1),
	NATIVE_HOST(ProfileLog, emit_general, 7),
	NATIVE_HOST(ProfileLog, clear_general_log, 0),
	NATIVE_HOST(ProfileLog, general_log_snapshot, 0),
	NATIVE_HOST(ProfileLog, last_general_records, 1),
	NATIVE_HOST(CampaignRules, get_campaign_id_for_scenario, 1),
	// The screens' texts a summary quotes and the read scopes they run in,
	// GDScript until their slices port them. They normalize the session.
	NATIVE_HOST_WRITING(OverworldRules, begin_normalized_read_scope, 1),
	NATIVE_HOST_WRITING(OverworldRules, end_normalized_read_scope, 1),
	NATIVE_HOST_WRITING(OverworldRules, is_runtime_session_normalized, 1),
	NATIVE_HOST_WRITING(OverworldRules, describe_command_risk, 1),
	NATIVE_HOST_WRITING(OverworldRules, describe_command_risk_summary_from_normalized_session, 1),
	NATIVE_HOST_WRITING(OverworldRules, describe_frontier_threats, 1),
	NATIVE_HOST_WRITING(OverworldRules, describe_management_watch, 1),
	NATIVE_HOST_WRITING(TownRules, describe_defense, 1),
	NATIVE_HOST_WRITING(TownRules, describe_defense_headline, 1),
	NATIVE_HOST_WRITING(BattleRules, describe_risk_readiness_board, 1),
};

#undef NATIVE_HOST_WRITING
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
