#pragma once

// scripts/autoload/SaveService.gd: saves (docs/native-rules-engine-transition.md,
// Phase 7, 7.12), ported function by function under the GDScript names. The
// autoload's vars (_selected_manual_slot, _slot_summary_cache and on) are its
// members: gd::member and gd::set_member of gd::autoload(state,
// key::SaveService). A session parameter is a SessionData object (an opaque
// Value), its view (a Dict) or null: gd::object_view gives the view of either.
// A function that returns a session returns the object.

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <cstdint>

namespace aurelion::rules::port::save_service {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using state::State;
using state::Value;
using Vector2i = overworld_rules::Vector2i;

// ProfileLog.begin_usec() and ProfileLog.elapsed_ms(started_usec), on the
// engine's clock (save_service_runtime.cpp). The rest of ProfileLog stays
// GDScript: host calls (human_registry.cpp).
int64_t profile_begin_usec(State &state);
double profile_elapsed_ms(State &state, int64_t started_usec);

// Named save files, the validation hooks, the save and load entry points, slot names, deleting, and the campaign progression's entry points (save_service_entry.cpp).
DictRef save_file_identity(State &state, Atom requested_name);
DictRef _validated_save_file_name(State &state, Atom requested_name);
DictRef _save_file_identity_in_directory(State &state, Atom validated_name, const Value &directory, PackedRef entries);
DictRef inspect_save_file(State &state, Atom name);
DictRef _inspect_listed_save_file(State &state, Atom name, const Value &directory, PackedRef entries);
ArrayRef list_save_files(State &state);
DictRef build_file_save_action(State &state, Atom name);
DictRef save_runtime_file_session(State &state, const Value &session, Atom name, bool overwrite = false, Atom expected_sha256 = state::key::empty);
void validation_begin_summary_inspection_trace(State &state);
DictRef validation_summary_inspection_trace_snapshot(State &state);
DictRef validation_end_summary_inspection_trace(State &state);
DictRef validation_last_runtime_save_profile(State &state);
DictRef validation_summary_cache_snapshot(State &state);
void validation_clear_summary_cache(State &state);
DictRef validation_transaction_artifact_paths(State &state, Atom file_path);
DictRef validation_clear_general_profile_log(State &state);
DictRef validation_general_profile_log_snapshot(State &state);
ArrayRef validation_general_profile_log_last_records(State &state, int64_t limit = 5);
void _trace_summary_inspection(State &state, Atom name);
Atom save_session(State &state, DictRef payload, int64_t slot = 1);
DictRef save_runtime_manual_session(State &state, const Value &session, int64_t slot = 1);
DictRef save_runtime_autosave_session(State &state, const Value &session, bool include_summary = true, bool cache_summary = false);
Atom save_manual_session(State &state, DictRef payload, int64_t slot = 1);
Atom save_autosave_session(State &state, DictRef payload);
DictRef load_session(State &state, int64_t slot = 1);
DictRef load_autosave(State &state);
DictRef _loaded_session_payload(State &state, DictRef payload);
Value restore_manual_session(State &state, int64_t slot = 1);
Value restore_autosave_session(State &state);
Value restore_session_from_summary(State &state, DictRef summary);
DictRef refresh_summary(State &state, DictRef summary);
DictRef build_delete_action(State &state, DictRef summary);
DictRef build_manual_slot_name_action(State &state, DictRef summary);
DictRef set_manual_slot_name_from_summary(State &state, DictRef summary, Atom requested_name);
DictRef build_manual_save_action(State &state, const Value &session, int64_t manual_slot);
DictRef delete_session_from_summary(State &state, DictRef summary);
Atom save_progression(State &state, DictRef payload);
DictRef load_progression(State &state);
bool has_progression(State &state);
DictRef inspect_progression_storage(State &state);

// Slots, the summary lists, the in-session save surface and its recap contexts (save_service_surface.cpp).
ArrayRef get_manual_slot_ids(State &state);
int64_t get_selected_manual_slot(State &state);
void set_selected_manual_slot(State &state, int64_t slot);
DictRef inspect_manual_slot(State &state, int64_t slot = 1);
DictRef inspect_autosave(State &state);
ArrayRef list_session_summaries(State &state);
DictRef latest_loadable_summary(State &state);
Atom _save_folder_fingerprint(State &state);
void _invalidate_latest_loadable_summary(State &state);
double summary_recency_timestamp(State &state, DictRef summary);
DictRef in_session_save_bar_status(State &state, const Value &session, int64_t manual_slot = -1);
DictRef build_current_session_save_context(State &state, const Value &session);
DictRef build_in_session_save_surface(State &state, const Value &session, int64_t manual_slot, DictRef refresh_watch_context, bool include_stored_summaries = true, bool include_stored_recaps = true);
DictRef _live_session_summary_from_payload(State &state, DictRef payload, int64_t manual_slot, Atom resume_target);
Value _session_from_owned_detached_payload(State &state, DictRef payload);
bool _summaries_share_storage_identity(State &state, DictRef first, DictRef second);
DictRef _live_summary_for_manual_slot(State &state, DictRef source, int64_t manual_slot, bool valid_storage);
DictRef _session_save_recap_context(State &state, const Value &session, DictRef summary, Atom preloaded_progress_recap, bool include_play_check_state, DictRef refresh_watch_context);
Atom _describe_session_save_check_from_context(State &state, const Value &session, DictRef summary, DictRef recap_context);
Atom _describe_session_save_handoff_from_summary(State &state, const Value &session, DictRef summary, int64_t manual_slot);
Atom _describe_session_save_handoff_brief_from_summary(State &state, const Value &session, DictRef summary);
Atom _describe_session_play_check_from_summary(State &state, const Value &session, DictRef summary);
Atom _describe_session_play_check_from_context(State &state, const Value &session, DictRef summary, DictRef recap_context);
Atom _describe_session_return_handoff_from_summary(State &state, const Value &session, DictRef summary);
Atom _session_save_resume_recap_from_context(State &state, const Value &session, DictRef summary, DictRef recap_context);

// The load and continue actions, the describe_* texts, slot details, paths and the summary-to-save write (save_service_describe.cpp).
Atom resume_target_for_session(State &state, const Value &session);
bool can_load_summary(State &state, DictRef summary);
Atom load_action_label(State &state, DictRef summary);
Atom continue_action_label(State &state, DictRef summary);
Atom load_action_tooltip(State &state, DictRef summary);
Atom describe_summary_resume_recap(State &state, DictRef summary);
Atom _describe_summary_resume_recap_with_context(State &state, DictRef summary, DictRef profile);
Atom describe_summary_next_play_action(State &state, DictRef summary);
Atom describe_summary_play_check(State &state, DictRef summary);
Atom describe_summary_resume_handoff(State &state, DictRef summary);
Atom describe_resume_brief(State &state, DictRef summary);
Atom describe_slot(State &state, DictRef summary);
Atom describe_slot_browser_row(State &state, DictRef summary);
Atom describe_load_preview(State &state, DictRef summary);
Atom _load_destination_label(State &state, DictRef summary);
Atom describe_slot_continuity_cue(State &state, DictRef summary);
Atom describe_slot_details(State &state, DictRef summary);
Atom _describe_slot_details(State &state, DictRef summary, const Value &trusted_normalized_session, DictRef recap_context, Atom progress_recap = state::key::empty);
Atom format_modified_timestamp(State &state, int64_t timestamp);
Atom _slot_path(State &state, int64_t slot);
Atom _autosave_path(State &state);
Atom _progression_path(State &state);
DictRef _deletable_slot_identity(State &state, DictRef summary);
DictRef _summary_for_slot_identity(State &state, DictRef identity);
bool _ensure_save_dir(State &state);
Atom _save_payload(State &state, DictRef payload, Atom file_path, Atom slot_type, DictRef saved_payload_out, DictRef profile, bool payload_is_prepared = false);

// Saving the running game: receipts, the runtime save, trusted autosaves, the generated opening's autosave, the save profile (save_service_runtime.cpp).
DictRef _verified_cached_manual_save_recovery(State &state, Atom file_path, Atom slot_type);
DictRef _verified_receipt_recovery(State &state, Atom file_path);
DictRef _save_runtime_session(State &state, const Value &session, Atom slot_type, int64_t slot = 1, bool include_summary = true, Atom save_file_name = state::key::empty, bool cache_summary = false);
bool _can_use_trusted_live_autosave_payload(State &state, const Value &session, DictRef payload, Atom slot_type);
DictRef _runtime_payload_for_save(State &state, const Value &session);
DictRef _payload_without_transition_autosave_intent(State &state, DictRef payload);
DictRef _owned_payload_from_normalized_detached_session(State &state, const Value &session);
void _clear_transition_autosave_intent_from_owned_payload(State &state, DictRef payload);
void _clear_transition_autosave_intent_flags(State &state, const Value &session);
bool _can_fast_save_generated_opening_autosave(State &state, const Value &session, Atom slot_type, bool include_summary);
bool _is_generated_opening_autosave_pending(State &state, const Value &session);
DictRef _save_generated_opening_autosave_fast(State &state, const Value &session, DictRef profile);
DictRef _generated_opening_autosave_success_payload(State &state, const Value &session);
DictRef _generated_opening_autosave_success_payload_from_payload(State &state, DictRef payload);
void _apply_generated_opening_autosave_success_to_owned_payload(State &state, DictRef payload);
void _apply_generated_opening_autosave_success_to_session(State &state, const Value &session);
void _runtime_save_profile_step(State &state, DictRef profile, Atom step_name);
void _runtime_save_profile_bucket(State &state, DictRef profile, Atom bucket_name, double elapsed_ms);
void _runtime_save_profile_finish(State &state, DictRef profile);

// The transactional write, its recovery and rollback, reading saves, the progression's storage report (save_service_transaction.cpp).
Atom _save_raw_dictionary(State &state, DictRef payload, Atom file_path, DictRef profile, DictRef prepared_recovery);
Atom _save_transaction_candidate_path(State &state, Atom file_path);
Atom _save_transaction_backup_path(State &state, Atom file_path);
Atom _save_transaction_previous_path(State &state, Atom file_path);
void _retain_previous_save_generation(State &state, Atom file_path, Atom backup_path);
DictRef _read_json_dictionary_unrecovered(State &state, Atom file_path, bool include_payload = true);
DictRef _recover_save_transaction(State &state, Atom file_path, bool include_live_read = false);
DictRef _recover_previous_save_generation(State &state, Atom file_path, bool include_live_read);
DictRef _with_live_read(State &state, DictRef recovery, DictRef live_read, bool include_live_read);
bool _save_transaction_payload_valid(State &state, Atom file_path, DictRef raw);
DictRef _progression_payload_semantic_report(State &state, DictRef payload);
DictRef _migrate_progression_payload(State &state, DictRef payload, int64_t from_version);
DictRef _migrate_progression_payload_step(State &state, DictRef payload, int64_t _from_version);
DictRef _current_progression_payload(State &state, DictRef payload, DictRef semantic_report);
DictRef _progression_storage_result(State &state, Atom status, Atom path, DictRef raw, DictRef semantic_report, DictRef recovery);
bool _rollback_save_transaction(State &state, Atom file_path, Atom candidate_path, Atom backup_path, bool had_live);
bool _remove_save_transaction_artifact(State &state, Atom file_path);
int64_t _rename_save_transaction_path(State &state, Atom from_path, Atom to_path);
DictRef _load_raw_dictionary(State &state, Atom file_path, bool warn_if_missing);
DictRef _recovered_live_read(State &state, DictRef recovery, Atom file_path);
DictRef _payload_from_raw_read(State &state, DictRef raw, Atom file_path, bool warn_if_missing);

// Inspecting a slot, restoring a session, the generated map's restore, filling a summary from a save (save_service_restore.cpp).
DictRef _inspect_slot(State &state, Atom slot_type, Atom slot_id, Atom file_path);
DictRef _normalize_restore_result(State &state, DictRef payload, Atom slot_type = state::key::empty);
DictRef _ensure_generated_random_map_scenario_registered(State &state, DictRef normalized_payload);
DictRef _register_native_generated_random_map_scenario_from_payload(State &state, DictRef normalized_payload, DictRef provenance);
DictRef _native_generated_restore_objectives(State &state, DictRef overworld);
DictRef _native_generated_restore_start(State &state, DictRef overworld);
Atom _native_generated_restore_player_faction(State &state, DictRef overworld);
DictRef _populate_summary_from_payload(State &state, DictRef summary, DictRef payload);
DictRef _campaign_metadata_for_scenario(State &state, Atom scenario_id, Atom launch_mode);
Atom _hero_name(State &state, const Value &hero_state, DictRef hero_template, Atom hero_id);
Atom _battle_name_from_payload(State &state, DictRef normalized_payload);
Atom _resume_location_from_payload(State &state, DictRef normalized_payload);
Atom _active_town_name_from_payload(State &state, DictRef normalized_payload);
Atom _town_name_for_summary(State &state, DictRef town);
Vector2i _hero_position_from_payload(State &state, DictRef normalized_payload);

// Summaries: making, finishing and caching them, file signatures, and their continuity and recap lines (save_service_summary.cpp).
DictRef _empty_summary(State &state, Atom slot_type, Atom slot_id, Atom file_path);
DictRef _finalize_summary(State &state, DictRef summary);
DictRef _finalize_runtime_summary(State &state, DictRef summary, DictRef profile);
DictRef _finalize_stored_summary(State &state, DictRef summary);
DictRef _finalize_summary_from_session(State &state, DictRef summary, const Value &trusted_session, DictRef profile);
DictRef _finalize_and_cache_summary(State &state, DictRef summary);
DictRef _cached_slot_summary(State &state, Atom slot_type, Atom slot_id, Atom file_path);
DictRef _cached_slot_summary_entry(State &state, Atom slot_type, Atom slot_id, Atom file_path);
void _store_slot_summary_cache(State &state, DictRef summary);
void _store_runtime_summary_cache(State &state, DictRef payload, Atom slot_type, Atom slot_id, Atom file_path, Atom authoritative_resume_target, DictRef profile);
void _invalidate_summary_cache_for_path(State &state, Atom file_path);
Atom _summary_cache_key(State &state, Atom slot_type, Atom slot_id, Atom file_path);
DictRef _slot_file_signature(State &state, Atom file_path, bool include_named_file_sha256 = true);
bool _slot_file_modified_recently(State &state, int64_t modified_timestamp);
DictRef _summary_payload(State &state, DictRef summary);
DictRef _load_summary_payload_for_restore(State &state, DictRef summary);
Atom _resume_target_from_payload_summary(State &state, DictRef payload);
double _summary_sort_timestamp(State &state, DictRef summary);
DictRef _manual_summary_for_session(State &state, const Value &session, int64_t manual_slot = -1);
Value _session_from_payload(State &state, DictRef payload);
Atom _summary_progress_recap(State &state, DictRef summary);
ArrayRef _summary_continuity_lines(State &state, DictRef summary);
ArrayRef _summary_continuity_lines_from_context(State &state, DictRef summary, DictRef recap_context);
Atom _summary_resume_action_line(State &state, DictRef summary);
Atom _summary_campaign_context_line(State &state, DictRef summary);
Atom _summary_objective_line(State &state, const Value &session);
Atom _summary_objective_line_from_progress_recap(State &state, Atom recap);
Atom _summary_play_check_state_line(State &state, const Value &session, DictRef summary);
Atom _summary_play_check_state_line_from_context(State &state, const Value &session, DictRef summary, DictRef recap_context);
Atom _summary_watch_state_line(State &state, const Value &session, DictRef summary, bool trusted_normalized_session, Atom preloaded_progress_recap, DictRef refresh_watch_context);
Atom _session_next_decision_line(State &state, const Value &session, DictRef summary);
Atom _fallback_resume_decision(State &state, Atom resume_target);
DictRef _preferred_recent_action_recap(State &state, const Value &session, Atom resume_target);
DictRef _normalize_saved_action_recap(State &state, const Value &value);
Atom _action_recap_change_summary(State &state, DictRef recap);
Atom _action_recap_next_step(State &state, DictRef recap);

// Labels, player text, slot names, badges, tooltips, resume targets and the save's structure report (save_service_labels.cpp).
Atom _battle_aftermath_summary(State &state, const Value &session);
Atom _safe_player_text(State &state, Atom value, int64_t max_chars = 220);
bool _contains_blocked_debug_token(State &state, Atom text);
Atom _line_with_prefix(State &state, Atom text, Atom prefix);
Atom _first_meaningful_line(State &state, Atom text, ArrayRef ignored_lines);
Atom _slot_label(State &state, DictRef summary);
Atom _manual_slot_name_from_payload(State &state, DictRef payload);
DictRef _validate_manual_slot_name(State &state, Atom value);
Atom _summary_status_badge(State &state, DictRef summary);
Atom _runtime_save_message(State &state, Atom slot_type, DictRef summary);
Atom _main_menu_continue_hint(State &state, DictRef summary);
Atom _resume_target_noun(State &state, Atom target);
Atom _return_to_menu_label(State &state, Atom current_target, const Value &session = Value());
Atom _in_session_save_label(State &state, Atom current_target, int64_t selected_slot);
Atom _in_session_save_tooltip(State &state, Atom current_target, DictRef slot_summary, Atom current_context = state::key::empty);
Atom _latest_context_line(State &state, DictRef latest_summary, Atom current_target = state::key::empty);
Atom _return_to_menu_tooltip(State &state, Atom current_target, DictRef latest_summary, Atom current_context = state::key::empty, Atom return_handoff = state::key::empty);
Atom _resume_preserved_context(State &state, DictRef summary);
Atom _resume_target_label(State &state, DictRef summary);
Atom _resume_context_label(State &state, DictRef summary);
Atom _status_text_for_summary(State &state, DictRef summary);
int64_t _normalize_manual_slot(State &state, int64_t slot);
Atom _resume_target_for_session(State &state, const Value &session);
int64_t _recorded_timestamp_from_payload(State &state, DictRef payload, int64_t fallback = 0);
double _recorded_timestamp_precise_from_payload(State &state, DictRef payload);
DictRef _payload_structure_report(State &state, DictRef payload, Atom slot_type = state::key::empty);
bool _has_core_overworld_state(State &state, DictRef overworld);
ArrayRef _missing_overworld_fields(State &state, DictRef overworld);
Atom _degraded_validity(State &state, Atom current_validity);
Atom _humanize_label(State &state, Atom value);
Atom _validity_label(State &state, Atom validity);

} // namespace aurelion::rules::port::save_service
