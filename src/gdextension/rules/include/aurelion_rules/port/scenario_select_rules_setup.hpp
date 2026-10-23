#pragma once

// scripts/core/ScenarioSelectRules.gd: game setup for generated maps and the
// maps folder (docs/native-rules-engine-transition.md, Phase 7, 7.11), ported
// function by function under the GDScript names. A session parameter is a
// SessionData object (an opaque Value), its view (a Dict) or null:
// gd::object_view gives the view of either. A function that returns a session
// returns the object. The authored-scenario setup stays GDScript.

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/scenario_select_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <cstdint>
#include <utility>
#include <vector>

namespace aurelion::rules::port::scenario_select_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// Difficulty, labels, seeds, the player's random-map config and its seats
// (scenario_select_options.cpp).
ArrayRef build_difficulty_options(State &state, Atom selected_id = state::key::empty);
Atom difficulty_label(State &state, Atom difficulty_id);
Atom difficulty_summary(State &state, Atom difficulty_id);
Atom launch_mode_label(State &state, Atom launch_mode);
Atom build_current_session_summary(State &state, const Value &session);
ArrayRef random_map_faction_options(State &state);
ArrayRef random_map_hero_options_for_faction(State &state, Atom faction_id);
Atom random_map_default_hero_id_for_faction(State &state, Atom faction_id);
bool random_map_seed_requests_auto(State &state, Atom seed);
Atom random_map_fresh_auto_seed(State &state);
DictRef random_map_h3maped_seed_record(State &state, Atom seed);
bool _random_map_seed_is_unsigned_integer(State &state, Atom seed);
int64_t _stable_hash_u31(State &state, Atom value);
DictRef random_map_size_class_default(State &state, Atom size_class_id);
DictRef build_random_map_player_config(State &state, Atom seed, Atom template_id, Atom profile_id, int64_t player_count, Atom water_mode, bool underground_enabled, Atom size_class_id, Atom template_selection_mode, Atom player_faction_id, Atom player_hero_id, Atom monster_strength, ArrayRef seat_faction_ids);
ArrayRef random_map_seat_factions(State &state, Atom normalized_seed, int64_t player_count, ArrayRef request);
Atom _valid_random_map_player_faction_id(State &state, Atom faction_id);
Atom _valid_random_map_player_hero_id(State &state, Atom hero_id, Atom faction_id);
ArrayRef _random_map_faction_seed_order(State &state, Atom player_faction_id);
Atom generated_skirmish_display_name(State &state, const Value &session);
Atom _title_from_package_stem(State &state, Atom package_stem);
Atom _title_from_kebab(State &state, Atom value);
Atom random_map_size_class_label(State &state, Atom size_class_id);
Atom random_map_monster_strength_id(State &state, Atom value);
Atom random_map_monster_strength_label(State &state, Atom value);
Atom _skirmish_difficulty_consequence(State &state, Atom difficulty_id, Atom recommended_difficulty);
Atom describe_skirmish_difficulty_check(State &state, Atom difficulty_id, Atom recommended_difficulty);
Atom _first_substantive_line(State &state, Atom text);
Atom _compact_sentence(State &state, Atom text, int64_t max_chars);

// The random-map setup options: sizes, water, levels, the template catalog,
// templates, profiles and player counts (scenario_select_catalog.cpp).
DictRef random_map_player_setup_options(State &state);
ArrayRef _random_map_public_size_options(State &state);
ArrayRef _random_map_public_water_options(State &state);
ArrayRef _random_map_public_level_options(State &state);
ArrayRef _random_map_public_h3maped_size_ids(State &state);
Atom _random_map_public_h3maped_scope_label_for_size(State &state, Atom size_class_id);
DictRef _random_map_public_h3maped_scope_for(State &state, Atom size_class_id, Atom water_mode, int64_t level_count);
ArrayRef random_map_player_count_options_for_template(State &state, Atom template_id);
ArrayRef random_map_profile_options_for_template(State &state, Atom template_id);
DictRef _random_map_template_option(State &state, Atom template_id);
ArrayRef _random_map_player_facing_template_options_with_player_counts(State &state);
ArrayRef _random_map_player_facing_profile_options(State &state);
DictRef _random_map_size_default_template_ids(State &state);
DictRef _random_map_size_default_profile_ids(State &state);
ArrayRef _random_map_all_player_count_options(State &state, ArrayRef template_options);
DictRef _random_map_player_count_options_by_template(State &state, ArrayRef template_options);
DictRef _random_map_profile_options_by_template(State &state, ArrayRef profile_options);
ArrayRef _random_map_template_player_count_options(State &state, Atom template_id, DictRef fallback_option);
int64_t _random_map_normalize_player_count_for_template(State &state, Atom template_id, int64_t player_count, int64_t fallback_count = 3);
DictRef _random_map_catalog_template(State &state, Atom template_id);
DictRef _random_map_catalog(State &state);
ArrayRef _random_map_template_options(State &state);
ArrayRef _random_map_profile_options(State &state);
// `template` is the GDScript parameter's name.
ArrayRef _player_counts_from_catalog_template(State &state, DictRef template_, int64_t fallback_count);
bool _random_map_template_active_graph_connected(State &state, DictRef template_, int64_t player_count);
bool _template_player_filter_allows(State &state, DictRef record, int64_t player_count);
ArrayRef _water_modes_from_catalog_template(State &state, DictRef template_);
bool _template_supports_underground(State &state, DictRef template_);
int64_t _random_map_template_total_start_capacity(State &state, DictRef template_);
ArrayRef _sorted_int_keys(State &state, DictRef values);
ArrayRef _sorted_string_keys(State &state, DictRef values);
DictRef _random_map_size_option(State &state, Atom size_class_id);
DictRef _random_map_profile_option(State &state, Atom profile_id);
DictRef _random_map_public_h3maped_launch_config(State &state, DictRef input_config);

// Generating the map, writing its packages and starting or restarting the
// session (scenario_select_setup.cpp).
DictRef generated_map_package_directory_policy(State &state);
DictRef build_random_map_skirmish_setup_with_retry(State &state, DictRef input_config, Atom difficulty_id, DictRef retry_policy);
DictRef build_random_map_skirmish_setup(State &state, DictRef input_config, Atom difficulty_id = state::key::normal);
DictRef _build_random_map_skirmish_setup_single_attempt(State &state, DictRef input_config, Atom difficulty_id = state::key::normal);
Value start_random_map_skirmish_session(State &state, DictRef input_config, Atom difficulty_id = state::key::normal);
Value start_random_map_skirmish_session_with_retry(State &state, DictRef input_config, Atom difficulty_id, DictRef retry_policy);
Value start_random_map_skirmish_session_from_setup(State &state, DictRef setup);
DictRef restart_generated_skirmish_session(State &state, const Value &source);
Value _start_random_map_skirmish_session_from_setup(State &state, DictRef setup);
Value _finish_random_map_skirmish_startup(State &state, const Value &session, DictRef setup, bool package_backed);
DictRef _random_map_retry_status(State &state, DictRef generated, DictRef report);
DictRef _random_map_not_implemented_launch_report(State &state, DictRef generated, DictRef report);
// ClassDB.instantiate("MapPackageService"), or null.
Value _native_map_package_service(State &state);
bool _is_legacy_compact_rmg_config(State &state, DictRef normalized);
DictRef _random_map_legacy_compact_launch_report(State &state, DictRef generated, DictRef report);
bool _use_project_maps_dir(State &state);
Atom _generated_map_package_dir(State &state);
DictRef _native_package_setup_failure(State &state, Atom code, Atom message, Atom difficulty_id, DictRef report);
DictRef _persist_and_load_generated_packages(State &state, const Value &service, DictRef adoption, DictRef generated);
DictRef _public_package_load_result(State &state, DictRef load_result);
DictRef _public_package_write_result(State &state, DictRef write_result);
Atom _safe_package_stem(State &state, Atom value);
DictRef _generated_map_package_identity(State &state, DictRef generated, DictRef adoption);
Atom _generated_map_package_size_token(State &state, Atom size_class_id);
Atom _generated_map_package_creative_name(State &state, DictRef normalized, DictRef generated);
int64_t _stable_name_index(State &state, Atom value, int64_t modulo);
Atom _generated_map_package_short_hash(State &state, DictRef normalized);
Atom _stable_hash_hex8(State &state, Atom value);
Atom _hex8(State &state, int64_t value);
Atom _native_random_map_profile_id(State &state, DictRef normalized);
Atom _safe_package_token(State &state, const Value &value, Atom fallback = state::key::generated);
DictRef _native_random_map_generated_identity(State &state, DictRef generated, DictRef adoption, DictRef persisted);
DictRef _native_random_map_provenance(State &state, DictRef input_config, DictRef generated, DictRef adoption, DictRef persisted, DictRef retry_status);
Atom _native_random_map_setup_summary(State &state, DictRef generated, DictRef adoption, DictRef persisted, DictRef report, DictRef retry_status, Atom difficulty_id);
DictRef _random_map_retry_policy(State &state, DictRef retry_policy);
DictRef _random_map_retry_attempt_config(State &state, DictRef input_config, int64_t attempt_index, DictRef retry_policy);
DictRef _random_map_setup_attempt_record(State &state, DictRef setup, DictRef input_config, int64_t attempt_number, int64_t max_attempts);
DictRef _random_map_attempt_native_normalized_config(State &state, DictRef setup, DictRef input_config);
DictRef _random_map_retry_status_from_attempts(State &state, ArrayRef attempts, bool ok, DictRef retry_policy);
Atom _random_map_failure_handoff(State &state, DictRef report, DictRef retry_status);
Atom _random_map_failure_setup_summary(State &state, DictRef report, DictRef retry_status, ArrayRef attempts);
Atom _stringify_report_value(State &state, const Value &value);
DictRef _random_map_replay_metadata(State &state, DictRef provenance, DictRef identity, DictRef retry_status);

// The maps folder: its index, its entries and starting a session from one
// (scenario_select_maps_folder.cpp).
bool maps_folder_package_id_is_valid(State &state, Atom package_id);
Atom maps_folder_package_id_for_stem(State &state, Atom package_stem);
Atom maps_folder_package_stem_from_id(State &state, Atom package_id);
Atom safe_maps_folder_package_stem(State &state, Atom value);
ArrayRef build_maps_folder_package_browser_entries(State &state, DictRef options);
DictRef maps_folder_package_index(State &state, DictRef options);
DictRef maps_folder_package_entry(State &state, Atom package_id, DictRef options);
DictRef build_maps_folder_package_skirmish_setup(State &state, Atom package_id, Atom difficulty_id, DictRef options);
DictRef build_maps_folder_package_skirmish_setup_from_entry(State &state, DictRef entry, Atom difficulty_id = state::key::normal);
Value load_maps_folder_package_session(State &state, Atom package_id, Atom difficulty_id, DictRef options);
Value load_maps_folder_package_session_from_entry(State &state, DictRef entry, Atom difficulty_id, DictRef options);
Value start_maps_folder_package_skirmish_session(State &state, Atom package_id, Atom difficulty_id = state::key::normal);
Value start_maps_folder_package_skirmish_session_from_entry(State &state, DictRef entry, Atom difficulty_id = state::key::normal);
// _maps_folder_package_stems(dir: DirAccess): the opened folder's entries as
// gd::dir_entries lists them (name, current_is_dir()), in get_next() order.
DictRef _maps_folder_package_stems(State &state, const std::vector<std::pair<Atom, bool>> &entries);
DictRef _maps_folder_package_record(State &state, const Value &service, Atom package_dir, Atom package_stem, DictRef options);
DictRef _maps_folder_package_entry_payload(State &state, Atom package_stem, Atom map_path, Atom scenario_path, DictRef map_manifest, DictRef scenario_manifest, DictRef metadata, DictRef map_ref, DictRef scenario_ref, int64_t player_count, DictRef launch_validation, bool launchable);
DictRef _maps_folder_package_launch_validation(State &state, DictRef metadata, DictRef map_ref, int64_t player_count);
Value _load_maps_folder_package_session_from_entry(State &state, DictRef entry, Atom difficulty_id, DictRef options);
bool _maps_folder_package_entry_is_current(State &state, DictRef entry);
DictRef _maps_folder_package_file_identity(State &state, Atom path);
// `keys` is the GDScript parameter's name.
bool _maps_folder_package_ref_matches(State &state, DictRef expected, DictRef actual, ArrayRef key_list);
Atom _maps_folder_display_name(State &state, Atom package_stem, DictRef metadata, DictRef selection);
Atom _maps_folder_metadata_summary(State &state, DictRef metadata);
Atom _maps_folder_package_briefing_check(State &state, DictRef entry, Atom difficulty_id);

} // namespace aurelion::rules::port::scenario_select_rules
