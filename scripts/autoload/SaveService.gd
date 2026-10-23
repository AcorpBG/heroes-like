class_name HeroesSaveService
extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

const SAVE_DIR := "user://saves"
const SAVE_PREFIX := "slot"
const MANUAL_SLOT_IDS := [1, 2, 3]
const SLOT_TYPE_MANUAL := "manual"
const SLOT_TYPE_FILE := "file"
const SLOT_TYPE_AUTOSAVE := "autosave"
const AUTOSAVE_FILE := "autosave.json"
const PROGRESSION_FILE := "campaign_progression.json"
const SAVE_METADATA_TIMESTAMP_KEY := "saved_at_unix"
const SAVE_METADATA_SLOT_TYPE_KEY := "save_slot_type"
const SAVE_METADATA_GAME_STATE_KEY := "saved_from_game_state"
const SAVE_METADATA_SCENARIO_STATUS_KEY := "saved_from_scenario_status"
const SAVE_METADATA_LAUNCH_MODE_KEY := "saved_from_launch_mode"
const SAVE_METADATA_MANUAL_NAME_KEY := "manual_slot_name"
const MANUAL_SLOT_NAME_MAX_LENGTH := 32
const TRANSITION_AUTOSAVE_INTENT_FLAGS := [
	"runtime_autosave_dirty",
	"runtime_autosave_pending_intent",
	"runtime_autosave_pending_reason",
	"runtime_autosave_pending_route",
	"runtime_autosave_pending_game_state",
	"runtime_autosave_pending_unix",
]
const GENERATED_OPENING_AUTOSAVE_PENDING_FLAG := "generated_overworld_deferred_autosave_pending"
const GENERATED_OPENING_AUTOSAVE_BRIEFING_DEFERRED_FLAG := "generated_overworld_command_briefing_autosave_deferred"
const GENERATED_OPENING_AUTOSAVE_COMPLETED_FLAG := "generated_overworld_initial_autosave_completed"
const SAVE_TRANSACTION_CANDIDATE_SUFFIX := ".candidate"
const SAVE_TRANSACTION_BACKUP_SUFFIX := ".backup"

var _selected_manual_slot := int(MANUAL_SLOT_IDS[0])
var _slot_summary_cache := {}
var _summary_inspection_trace_enabled := false
var _summary_inspection_trace_counts := {}
var _last_runtime_save_profile := {}
var _verified_save_receipts := {}
var _latest_loadable_summary_cache := {}
var _latest_loadable_summary_fingerprint := ""

# Saves run native (Phase 7, 7.12): each function is a thin wrapper over its C++
# port (src/gdextension/rules/core/port/save_service_*.cpp), which reads and
# writes the vars above.

# Named saves use the same versioned payload and transaction writer as legacy
# slots. The basename is the identity; callers can never supply an arbitrary path.
func save_file_identity(requested_name: String) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.save_file_identity", [requested_name])

func inspect_save_file(name: String) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.inspect_save_file", [name])

func list_save_files() -> Array:
	return HumanEngine.native_writing(&"SaveService.list_save_files", [])

func build_file_save_action(name: String) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.build_file_save_action", [name])

func save_runtime_file_session(session: SessionStateStoreScript.SessionData, name: String, overwrite: bool = false, expected_sha256: String = "") -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.save_runtime_file_session", [session, name, overwrite, expected_sha256])

func validation_begin_summary_inspection_trace() -> void:
	HumanEngine.native_writing(&"SaveService.validation_begin_summary_inspection_trace", [])

func validation_summary_inspection_trace_snapshot() -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.validation_summary_inspection_trace_snapshot", [])

func validation_end_summary_inspection_trace() -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.validation_end_summary_inspection_trace", [])

func validation_last_runtime_save_profile() -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.validation_last_runtime_save_profile", [])

func validation_summary_cache_snapshot() -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.validation_summary_cache_snapshot", [])

func validation_clear_summary_cache() -> void:
	HumanEngine.native_writing(&"SaveService.validation_clear_summary_cache", [])

func validation_transaction_artifact_paths(file_path: String) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.validation_transaction_artifact_paths", [file_path])

func validation_clear_general_profile_log() -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.validation_clear_general_profile_log", [])

func validation_general_profile_log_snapshot() -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.validation_general_profile_log_snapshot", [])

func validation_general_profile_log_last_records(limit: int = 5) -> Array:
	return HumanEngine.native_writing(&"SaveService.validation_general_profile_log_last_records", [limit])

func save_session(payload: Dictionary, slot: int = 1) -> String:
	return HumanEngine.native_writing(&"SaveService.save_session", [payload, slot])

func save_runtime_manual_session(session: SessionStateStoreScript.SessionData, slot: int = 1) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.save_runtime_manual_session", [session, slot])

## cache_summary stores the written save's summary for later inspections even
## when the result does not include it.
func save_runtime_autosave_session(session: SessionStateStoreScript.SessionData, include_summary: bool = true, cache_summary: bool = false) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.save_runtime_autosave_session", [session, include_summary, cache_summary])

func save_manual_session(payload: Dictionary, slot: int = 1) -> String:
	return HumanEngine.native_writing(&"SaveService.save_manual_session", [payload, slot])

func save_autosave_session(payload: Dictionary) -> String:
	return HumanEngine.native_writing(&"SaveService.save_autosave_session", [payload])

func load_session(slot: int = 1) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.load_session", [slot])

func load_autosave() -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.load_autosave", [])

func restore_manual_session(slot: int = 1):
	return HumanEngine.native_writing(&"SaveService.restore_manual_session", [slot])

func restore_autosave_session():
	return HumanEngine.native_writing(&"SaveService.restore_autosave_session", [])

func restore_session_from_summary(summary: Dictionary):
	return HumanEngine.native_writing(&"SaveService.restore_session_from_summary", [summary])

func refresh_summary(summary: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.refresh_summary", [summary])

func build_delete_action(summary: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.build_delete_action", [summary])

func build_manual_slot_name_action(summary: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.build_manual_slot_name_action", [summary])

func set_manual_slot_name_from_summary(summary: Dictionary, requested_name: String) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.set_manual_slot_name_from_summary", [summary, requested_name])

func build_manual_save_action(session: SessionStateStoreScript.SessionData, manual_slot: int) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.build_manual_save_action", [session, manual_slot])

func delete_session_from_summary(summary: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.delete_session_from_summary", [summary])

func save_progression(payload: Dictionary) -> String:
	return HumanEngine.native_writing(&"SaveService.save_progression", [payload])

func load_progression() -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.load_progression", [])

func has_progression() -> bool:
	return HumanEngine.native_writing(&"SaveService.has_progression", [])

func inspect_progression_storage() -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.inspect_progression_storage", [])

func get_manual_slot_ids() -> Array:
	return HumanEngine.native_writing(&"SaveService.get_manual_slot_ids", [])

func get_selected_manual_slot() -> int:
	return HumanEngine.native_writing(&"SaveService.get_selected_manual_slot", [])

func set_selected_manual_slot(slot: int) -> void:
	HumanEngine.native_writing(&"SaveService.set_selected_manual_slot", [slot])

func inspect_manual_slot(slot: int = 1) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.inspect_manual_slot", [slot])

func inspect_autosave() -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.inspect_autosave", [])

func list_session_summaries() -> Array:
	return HumanEngine.native_writing(&"SaveService.list_session_summaries", [])

func latest_loadable_summary() -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.latest_loadable_summary", [])

func summary_recency_timestamp(summary: Dictionary) -> float:
	return HumanEngine.native_writing(&"SaveService.summary_recency_timestamp", [summary])

## The in-session save bar's visible fields (button labels, save handoff brief,
## latest ready save) without copying the session. They match the same fields of
## build_in_session_save_surface(), whose live summary of a manual slot carries
## no stored name, only the slot and resume target these lines read.
func in_session_save_bar_status(session: SessionStateStoreScript.SessionData, manual_slot: int = -1) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.in_session_save_bar_status", [session, manual_slot])

func build_current_session_save_context(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.build_current_session_save_context", [session])

func build_in_session_save_surface(session: SessionStateStoreScript.SessionData, manual_slot: int = -1, refresh_watch_context: Dictionary = {}, include_stored_summaries: bool = true, include_stored_recaps: bool = true) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService.build_in_session_save_surface", [session, manual_slot, refresh_watch_context, include_stored_summaries, include_stored_recaps])

func resume_target_for_session(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"SaveService.resume_target_for_session", [session])

func can_load_summary(summary: Dictionary) -> bool:
	return HumanEngine.native_writing(&"SaveService.can_load_summary", [summary])

func load_action_label(summary: Dictionary) -> String:
	return HumanEngine.native_writing(&"SaveService.load_action_label", [summary])

func continue_action_label(summary: Dictionary) -> String:
	return HumanEngine.native_writing(&"SaveService.continue_action_label", [summary])

func load_action_tooltip(summary: Dictionary) -> String:
	return HumanEngine.native_writing(&"SaveService.load_action_tooltip", [summary])

func describe_summary_resume_recap(summary: Dictionary) -> String:
	return HumanEngine.native_writing(&"SaveService.describe_summary_resume_recap", [summary])

func describe_summary_play_check(summary: Dictionary) -> String:
	return HumanEngine.native_writing(&"SaveService.describe_summary_play_check", [summary])

func describe_summary_resume_handoff(summary: Dictionary) -> String:
	return HumanEngine.native_writing(&"SaveService.describe_summary_resume_handoff", [summary])

func describe_resume_brief(summary: Dictionary) -> String:
	return HumanEngine.native_writing(&"SaveService.describe_resume_brief", [summary])

func describe_slot_browser_row(summary: Dictionary) -> String:
	return HumanEngine.native_writing(&"SaveService.describe_slot_browser_row", [summary])

func describe_load_preview(summary: Dictionary) -> String:
	return HumanEngine.native_writing(&"SaveService.describe_load_preview", [summary])

func describe_slot_continuity_cue(summary: Dictionary) -> String:
	return HumanEngine.native_writing(&"SaveService.describe_slot_continuity_cue", [summary])

func describe_slot_details(summary: Dictionary) -> String:
	return HumanEngine.native_writing(&"SaveService.describe_slot_details", [summary])

func format_modified_timestamp(timestamp: int) -> String:
	return HumanEngine.native_writing(&"SaveService.format_modified_timestamp", [timestamp])

func _autosave_path() -> String:
	return HumanEngine.native_writing(&"SaveService._autosave_path", [])

func _inspect_slot(slot_type: String, slot_id: String, file_path: String) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService._inspect_slot", [slot_type, slot_id, file_path])

func _normalize_restore_result(payload: Dictionary, slot_type: String = "") -> Dictionary:
	return HumanEngine.native_writing(&"SaveService._normalize_restore_result", [payload, slot_type])

func _ensure_generated_random_map_scenario_registered(normalized_payload: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"SaveService._ensure_generated_random_map_scenario_registered", [normalized_payload])
