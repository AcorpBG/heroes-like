class_name HeroesSaveService
extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const TownRulesScript = preload("res://scripts/core/TownRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const ProfileLogScript = preload("res://scripts/core/ProfileLog.gd")
# Validation markers: ScenarioSelectRules.launch_mode_label / ScenarioSelectRules.difficulty_label

const SAVE_DIR := "user://saves"
const SAVE_PREFIX := "slot"
const MANUAL_SLOT_IDS := [1, 2, 3]
const SLOT_TYPE_MANUAL := "manual"
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
const SUMMARY_INLINE_PAYLOAD_MAX_BYTES := 8 * 1024 * 1024
const TRANSITION_AUTOSAVE_INTENT_FLAGS := [
	"runtime_autosave_dirty",
	"runtime_autosave_pending_intent",
	"runtime_autosave_pending_reason",
	"runtime_autosave_pending_route",
	"runtime_autosave_pending_game_state",
	"runtime_autosave_pending_unix",
]
const GENERATED_OPENING_AUTOSAVE_FORCE_FAILURE_ENV := "HEROES_LIKE_GENERATED_OPENING_AUTOSAVE_FORCE_FAILURE"
const GENERATED_OPENING_AUTOSAVE_PENDING_FLAG := "generated_overworld_deferred_autosave_pending"
const GENERATED_OPENING_AUTOSAVE_BRIEFING_DEFERRED_FLAG := "generated_overworld_command_briefing_autosave_deferred"
const GENERATED_OPENING_AUTOSAVE_COMPLETED_FLAG := "generated_overworld_initial_autosave_completed"
const SAVE_TRANSACTION_FAILURE_ENV := "HEROES_LIKE_SAVE_FAIL_PHASE"
const SAVE_TRANSACTION_CANDIDATE_SUFFIX := ".candidate"
const SAVE_TRANSACTION_BACKUP_SUFFIX := ".backup"
const PROGRESSION_STORAGE_STATUS_MISSING := "missing"
const PROGRESSION_STORAGE_STATUS_CURRENT_VALID := "current_valid"
const PROGRESSION_STORAGE_STATUS_RECOVERED := "recovered"
const PROGRESSION_STORAGE_STATUS_INVALID := "invalid"
const PROGRESSION_STORAGE_STATUS_FUTURE_VERSION := "future_version"
const MAIN_MENU_ACTION_LABEL := "Main Menu"

var _selected_manual_slot := int(MANUAL_SLOT_IDS[0])
var _slot_summary_cache := {}
var _summary_inspection_trace_enabled := false
var _summary_inspection_trace_counts := {}
var _last_runtime_save_profile := {}

func validation_begin_summary_inspection_trace() -> void:
	_summary_inspection_trace_enabled = true
	_summary_inspection_trace_counts = {
		"inspect_manual_slot": 0,
		"inspect_autosave": 0,
		"list_session_summaries": 0,
		"latest_loadable_summary": 0,
		"slot_file_inspections": 0,
	}

func validation_summary_inspection_trace_snapshot() -> Dictionary:
	return _summary_inspection_trace_counts.duplicate(true)

func validation_end_summary_inspection_trace() -> Dictionary:
	var snapshot := validation_summary_inspection_trace_snapshot()
	_summary_inspection_trace_enabled = false
	return snapshot

func validation_last_runtime_save_profile() -> Dictionary:
	return _last_runtime_save_profile.duplicate(true)

func validation_summary_cache_snapshot() -> Dictionary:
	return _slot_summary_cache.duplicate(true)

func validation_clear_summary_cache() -> void:
	_slot_summary_cache.clear()

func validation_transaction_artifact_paths(file_path: String) -> Dictionary:
	return {
		"candidate": _save_transaction_candidate_path(file_path),
		"backup": _save_transaction_backup_path(file_path),
	}

func validation_clear_general_profile_log() -> Dictionary:
	return ProfileLogScript.clear_general_log()

func validation_general_profile_log_snapshot() -> Dictionary:
	return ProfileLogScript.general_log_snapshot()

func validation_general_profile_log_last_records(limit: int = 5) -> Array:
	return ProfileLogScript.last_general_records(limit)

func validation_build_in_session_save_surface_direct_legacy(
	session: SessionStateStoreScript.SessionData,
	manual_slot: int = -1
) -> Dictionary:
	return _build_in_session_save_surface_direct_legacy(session, manual_slot)

func _trace_summary_inspection(name: String) -> void:
	if not _summary_inspection_trace_enabled:
		return
	_summary_inspection_trace_counts[name] = int(_summary_inspection_trace_counts.get(name, 0)) + 1

func save_session(payload: Dictionary, slot: int = 1) -> String:
	return save_manual_session(payload, slot)

func save_runtime_selected_manual_session(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return save_runtime_manual_session(session, _selected_manual_slot)

func save_runtime_manual_session(session: SessionStateStoreScript.SessionData, slot: int = 1) -> Dictionary:
	return _save_runtime_session(session, SLOT_TYPE_MANUAL, slot)

func save_runtime_autosave_session(
	session: SessionStateStoreScript.SessionData,
	include_summary: bool = true
) -> Dictionary:
	return _save_runtime_session(session, SLOT_TYPE_AUTOSAVE, 1, include_summary)

func save_manual_session(payload: Dictionary, slot: int = 1) -> String:
	if payload.is_empty():
		push_warning("Refusing to save an empty session payload.")
		return ""

	var normalized: Dictionary = SessionStateStoreScript.normalize_payload(payload)
	if String(normalized.get("scenario_id", "")) == "":
		push_warning("Refusing to save a session without a scenario id.")
		return ""

	var normalized_slot := _normalize_manual_slot(slot)
	var path := _save_payload(normalized, _slot_path(normalized_slot), SLOT_TYPE_MANUAL)
	if path != "":
		_selected_manual_slot = normalized_slot
	return path

func save_autosave_session(payload: Dictionary) -> String:
	if payload.is_empty():
		push_warning("Refusing to save an empty autosave payload.")
		return ""

	var normalized: Dictionary = SessionStateStoreScript.normalize_payload(payload)
	if String(normalized.get("scenario_id", "")) == "":
		push_warning("Refusing to save an autosave without a scenario id.")
		return ""
	return _save_payload(normalized, _autosave_path(), SLOT_TYPE_AUTOSAVE)

func load_session(slot: int = 1) -> Dictionary:
	return _load_summary_payload_for_restore(inspect_manual_slot(slot))

func load_autosave() -> Dictionary:
	return _load_summary_payload_for_restore(inspect_autosave())

func restore_manual_session(slot: int = 1):
	return restore_session_from_summary(inspect_manual_slot(slot))

func restore_autosave_session():
	return restore_session_from_summary(inspect_autosave())

func restore_session_from_summary(summary: Dictionary):
	var live_summary := refresh_summary(summary)
	if not can_load_summary(live_summary):
		return null
	var payload := _load_summary_payload_for_restore(live_summary)
	if payload.is_empty():
		return null
	var restore_result := _normalize_restore_result(payload, String(live_summary.get("slot_type", "")))
	if not bool(restore_result.get("ok", false)):
		return null
	return restore_result.get("session", null)

func refresh_summary(summary: Dictionary) -> Dictionary:
	if summary.is_empty():
		return {}
	var slot_type := String(summary.get("slot_type", ""))
	match slot_type:
		SLOT_TYPE_AUTOSAVE:
			return inspect_autosave()
		SLOT_TYPE_MANUAL:
			return inspect_manual_slot(int(summary.get("slot_id", MANUAL_SLOT_IDS[0])))
		_:
			return _inspect_slot(slot_type, String(summary.get("slot_id", "")), String(summary.get("path", "")))

func build_delete_action(summary: Dictionary) -> Dictionary:
	var identity := _deletable_slot_identity(summary)
	if identity.is_empty():
		return {
			"label": "Delete Save",
			"disabled": true,
			"summary": "Select an occupied autosave or manual slot before deleting.",
		}

	var live_summary := _summary_for_slot_identity(identity)
	var path := String(identity.get("path", ""))
	var occupied := path != "" and FileAccess.file_exists(path)
	var slot_label := "Autosave" if String(identity.get("slot_type", "")) == SLOT_TYPE_AUTOSAVE else "Manual Slot %s" % String(identity.get("slot_id", ""))
	var context := String(live_summary.get("scenario_name", "")).strip_edges()
	if context == "":
		context = "this unreadable save" if occupied else "this empty slot"
	var summary_text := "Delete %s for %s? This permanently removes only this expedition save. Other save slots, campaign progress, settings, and the active expedition are preserved." % [
		slot_label,
		context,
	]
	return {
		"slot_type": String(identity.get("slot_type", "")),
		"slot_id": String(identity.get("slot_id", "")),
		"slot_label": slot_label,
		"scenario_name": String(live_summary.get("scenario_name", "")),
		"label": "Delete Save",
		"disabled": not occupied,
		"summary": summary_text,
	}

func build_manual_slot_name_action(summary: Dictionary) -> Dictionary:
	var identity := _deletable_slot_identity(summary)
	if String(identity.get("slot_type", "")) != SLOT_TYPE_MANUAL:
		return {
			"disabled": true,
			"slot_id": "",
			"current_name": "",
			"message": "Select an occupied manual save before naming it.",
		}
	var live_summary := _summary_for_slot_identity(identity)
	if not can_load_summary(live_summary):
		return {
			"disabled": true,
			"slot_id": String(identity.get("slot_id", "")),
			"current_name": "",
			"message": "Only a valid occupied manual save can be named.",
		}
	return {
		"disabled": false,
		"slot_id": String(identity.get("slot_id", "")),
		"current_name": String(live_summary.get("manual_slot_name", "")),
		"message": "Set an optional name for Manual Slot %s. The save path and expedition state stay unchanged." % String(identity.get("slot_id", "")),
	}

func set_manual_slot_name_from_summary(summary: Dictionary, requested_name: String) -> Dictionary:
	var action := build_manual_slot_name_action(summary)
	if bool(action.get("disabled", true)):
		return {
			"ok": false,
			"changed": false,
			"slot_id": String(action.get("slot_id", "")),
			"name": "",
			"message": String(action.get("message", "No manual save was renamed.")),
		}
	var name_check := _validate_manual_slot_name(requested_name)
	if not bool(name_check.get("ok", false)):
		return {
			"ok": false,
			"changed": false,
			"slot_id": String(action.get("slot_id", "")),
			"name": String(action.get("current_name", "")),
			"message": String(name_check.get("message", "The save name is invalid.")),
		}

	var slot_id := String(action.get("slot_id", ""))
	var path := _slot_path(int(slot_id))
	var payload := _load_raw_dictionary(path, false)
	var structure_report := _payload_structure_report(payload, SLOT_TYPE_MANUAL)
	if payload.is_empty() or not bool(structure_report.get("ok", false)):
		return {
			"ok": false,
			"changed": false,
			"slot_id": slot_id,
			"name": String(action.get("current_name", "")),
			"message": "Manual Slot %s changed or became unreadable before its name could be saved." % slot_id,
		}
	var normalized_name := String(name_check.get("name", ""))
	var previous_name := _manual_slot_name_from_payload(payload)
	if previous_name == normalized_name:
		return {
			"ok": true,
			"changed": false,
			"slot_id": slot_id,
			"name": normalized_name,
			"path": path,
			"message": "Manual Slot %s already uses that name." % slot_id,
		}

	var previous_payload := payload.duplicate(true)
	if normalized_name == "":
		payload.erase(SAVE_METADATA_MANUAL_NAME_KEY)
	else:
		payload[SAVE_METADATA_MANUAL_NAME_KEY] = normalized_name
	if _save_raw_dictionary(payload, path) == "":
		return {
			"ok": false,
			"changed": false,
			"slot_id": slot_id,
			"name": previous_name,
			"message": "Manual Slot %s could not save its new name. Expedition data was not intentionally changed." % slot_id,
		}
	var persisted := _load_raw_dictionary(path, false)
	if persisted != payload:
		_save_raw_dictionary(previous_payload, path)
		return {
			"ok": false,
			"changed": false,
			"slot_id": slot_id,
			"name": previous_name,
			"message": "Manual Slot %s failed name verification and its previous payload was restored." % slot_id,
		}
	return {
		"ok": true,
		"changed": true,
		"slot_id": slot_id,
		"name": normalized_name,
		"path": path,
		"message": "%s Manual Slot %s." % ["Cleared the name from" if normalized_name == "" else "Named", slot_id],
	}

func build_manual_save_action(
	session: SessionStateStoreScript.SessionData,
	manual_slot: int
) -> Dictionary:
	if not MANUAL_SLOT_IDS.has(manual_slot):
		return {
			"slot": manual_slot,
			"slot_label": "Manual Slot",
			"disabled": true,
			"requires_confirmation": false,
			"summary": "Choose a valid manual save slot.",
		}
	if session == null or session.scenario_id == "":
		return {
			"slot": manual_slot,
			"slot_label": "Manual Slot %d" % manual_slot,
			"disabled": true,
			"requires_confirmation": false,
			"summary": "No active expedition is available to save.",
		}

	var existing_summary := inspect_manual_slot(manual_slot)
	var current_summary := _manual_summary_for_session(session, manual_slot)
	var occupied := FileAccess.file_exists(_slot_path(manual_slot))
	var existing_context := "Empty"
	if occupied:
		existing_context = describe_resume_brief(existing_summary) if can_load_summary(existing_summary) else "Unreadable expedition save"
	var current_context := describe_resume_brief(current_summary)
	var slot_label := "Manual Slot %d" % manual_slot
	var summary_text := "Save %s to %s." % [current_context, slot_label]
	if occupied:
		summary_text = "Replace %s?\n\nCurrently saved: %s\nNew snapshot: %s\n\nOnly %s will be replaced. Other manual saves, autosave, campaign progress, settings, and the active expedition are preserved." % [
			slot_label,
			existing_context,
			current_context,
			slot_label,
		]
	return {
		"slot": manual_slot,
		"slot_label": slot_label,
		"disabled": false,
		"occupied": occupied,
		"requires_confirmation": occupied,
		"existing_context": existing_context,
		"current_context": current_context,
		"summary": summary_text,
	}

func delete_session_from_summary(summary: Dictionary) -> Dictionary:
	var identity := _deletable_slot_identity(summary)
	var action := build_delete_action(summary)
	if identity.is_empty() or bool(action.get("disabled", true)):
		return {
			"ok": false,
			"slot_type": String(action.get("slot_type", "")),
			"slot_id": String(action.get("slot_id", "")),
			"message": "No occupied autosave or manual slot was deleted.",
		}

	var path := String(identity.get("path", ""))
	var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if remove_error != OK:
		return {
			"ok": false,
			"slot_type": String(identity.get("slot_type", "")),
			"slot_id": String(identity.get("slot_id", "")),
			"message": "%s could not be deleted. Other save slots were not changed." % String(action.get("slot_label", "Save")),
		}

	_invalidate_summary_cache_for_path(path)
	return {
		"ok": true,
		"slot_type": String(identity.get("slot_type", "")),
		"slot_id": String(identity.get("slot_id", "")),
		"slot_label": String(action.get("slot_label", "Save")),
		"message": "%s was deleted. Other save slots and progress were preserved." % String(action.get("slot_label", "Save")),
	}

func save_progression(payload: Dictionary) -> String:
	if payload.is_empty():
		push_warning("Refusing to save an empty campaign progression payload.")
		return ""
	var payload_report := _progression_payload_semantic_report(payload)
	if String(payload_report.get("status", "")) != PROGRESSION_STORAGE_STATUS_CURRENT_VALID:
		push_warning("Refusing to save incompatible campaign progression: %s" % String(payload_report.get("reason", "invalid_payload")))
		return ""
	var storage := inspect_progression_storage()
	if not bool(storage.get("writable", false)):
		push_warning(String(storage.get("message", "Campaign progress storage cannot be overwritten safely.")))
		return ""
	return _save_raw_dictionary(payload, _progression_path())

func load_progression() -> Dictionary:
	var storage := inspect_progression_storage()
	if not bool(storage.get("usable", false)):
		return {}
	var raw := _read_json_dictionary_unrecovered(_progression_path())
	if not bool(raw.get("ok", false)):
		return {}
	var payload: Dictionary = raw.get("payload", {}) if raw.get("payload", {}) is Dictionary else {}
	if String(_progression_payload_semantic_report(payload).get("status", "")) != PROGRESSION_STORAGE_STATUS_CURRENT_VALID:
		return {}
	return payload.duplicate(true)

func has_progression() -> bool:
	return bool(inspect_progression_storage().get("usable", false))

func inspect_progression_storage() -> Dictionary:
	var path := _progression_path()
	var live_before := _read_json_dictionary_unrecovered(path)
	if bool(live_before.get("ok", false)):
		var before_payload: Dictionary = live_before.get("payload", {}) if live_before.get("payload", {}) is Dictionary else {}
		var before_report := _progression_payload_semantic_report(before_payload)
		if String(before_report.get("status", "")) == PROGRESSION_STORAGE_STATUS_FUTURE_VERSION:
			# A parseable future profile is authoritative user data. Never replace it
			# with an older backup; only staging is safe to discard.
			_remove_save_transaction_artifact(_save_transaction_candidate_path(path))
			return _progression_storage_result(
				PROGRESSION_STORAGE_STATUS_FUTURE_VERSION,
				path,
				live_before,
				before_report,
				{"reason": "future_version", "recovered": false}
			)

	var recovery := _recover_save_transaction(path)
	var live := _read_json_dictionary_unrecovered(path)
	if not bool(live.get("exists", false)):
		var missing_status := PROGRESSION_STORAGE_STATUS_MISSING
		var missing_reason := String(recovery.get("reason", "missing"))
		if missing_reason in ["backup_restore_failed", "backup_restore_verification_failed"]:
			missing_status = PROGRESSION_STORAGE_STATUS_INVALID
		return _progression_storage_result(
			missing_status,
			path,
			live,
			{"status": missing_status, "reason": missing_reason, "version": -1},
			recovery
		)
	if not bool(live.get("ok", false)):
		return _progression_storage_result(
			PROGRESSION_STORAGE_STATUS_INVALID,
			path,
			live,
			{
				"status": PROGRESSION_STORAGE_STATUS_INVALID,
				"reason": "corrupt_json" if bool(live.get("readable", false)) else "unreadable",
				"version": -1,
			},
			recovery
		)
	var payload: Dictionary = live.get("payload", {}) if live.get("payload", {}) is Dictionary else {}
	var semantic_report := _progression_payload_semantic_report(payload)
	var status := String(semantic_report.get("status", PROGRESSION_STORAGE_STATUS_INVALID))
	if status == PROGRESSION_STORAGE_STATUS_CURRENT_VALID and bool(recovery.get("recovered", false)):
		status = PROGRESSION_STORAGE_STATUS_RECOVERED
	return _progression_storage_result(status, path, live, semantic_report, recovery)

func has_slot(slot: int) -> bool:
	var path := _slot_path(_normalize_manual_slot(slot))
	_recover_save_transaction(path)
	return FileAccess.file_exists(path)

func has_any_loadable_session() -> bool:
	return not latest_loadable_summary().is_empty()

func get_manual_slot_ids() -> Array:
	return MANUAL_SLOT_IDS.duplicate()

func get_selected_manual_slot() -> int:
	return _selected_manual_slot

func set_selected_manual_slot(slot: int) -> void:
	_selected_manual_slot = _normalize_manual_slot(slot)

func inspect_manual_slot(slot: int = 1) -> Dictionary:
	_trace_summary_inspection("inspect_manual_slot")
	var normalized_slot := _normalize_manual_slot(slot)
	return _inspect_slot(SLOT_TYPE_MANUAL, str(normalized_slot), _slot_path(normalized_slot))

func inspect_autosave() -> Dictionary:
	_trace_summary_inspection("inspect_autosave")
	return _inspect_slot(SLOT_TYPE_AUTOSAVE, SLOT_TYPE_AUTOSAVE, _autosave_path())

func list_session_summaries() -> Array:
	_trace_summary_inspection("list_session_summaries")
	var summaries := [inspect_autosave()]
	for slot in MANUAL_SLOT_IDS:
		summaries.append(inspect_manual_slot(int(slot)))
	return summaries

func list_loadable_session_summaries() -> Array:
	var summaries := []
	for summary in list_session_summaries():
		if can_load_summary(summary):
			summaries.append(summary)
	return summaries

func latest_loadable_summary() -> Dictionary:
	_trace_summary_inspection("latest_loadable_summary")
	var latest := {}
	for summary in list_session_summaries():
		if not can_load_summary(summary):
			continue
		if latest.is_empty() or summary_recency_timestamp(summary) > summary_recency_timestamp(latest):
			latest = summary
	return latest

func summary_recency_timestamp(summary: Dictionary) -> float:
	return _summary_sort_timestamp(summary)

func build_in_session_save_surface(
	session: SessionStateStoreScript.SessionData,
	manual_slot: int = -1,
	refresh_watch_context: Dictionary = {}
) -> Dictionary:
	var profile_started := ProfileLogScript.begin_usec()
	var buckets := {}
	var selected_slot := _normalize_manual_slot(manual_slot if manual_slot > 0 else _selected_manual_slot)
	var slot_started := ProfileLogScript.begin_usec()
	var slot_summary := inspect_manual_slot(selected_slot)
	buckets["inspect_selected_slot"] = ProfileLogScript.elapsed_ms(slot_started)
	var latest_started := ProfileLogScript.begin_usec()
	var latest_summary := latest_loadable_summary()
	buckets["latest_loadable_summary"] = ProfileLogScript.elapsed_ms(latest_started)
	var current_target := _resume_target_for_session(session)
	var payload_started := ProfileLogScript.begin_usec()
	var live_payload := session.to_dict() if session != null and session.scenario_id != "" else {}
	buckets["detached_live_payload"] = ProfileLogScript.elapsed_ms(payload_started)
	var summary_started := ProfileLogScript.begin_usec()
	var selected_live_summary := _live_session_summary_from_payload(live_payload, selected_slot, current_target)
	var default_live_summary := _live_summary_for_manual_slot(selected_live_summary, _selected_manual_slot, false)
	var detached_live_session := _session_from_owned_detached_payload(live_payload)
	buckets["normalized_live_summary"] = ProfileLogScript.elapsed_ms(summary_started)
	var context_started := ProfileLogScript.begin_usec()
	var current_context := describe_resume_brief(default_live_summary) if not default_live_summary.is_empty() else ""
	buckets["current_context"] = ProfileLogScript.elapsed_ms(context_started)
	var normalization_started := ProfileLogScript.begin_usec()
	var detached_was_runtime_normalized := OverworldRulesScript.is_runtime_session_normalized(detached_live_session)
	var detached_normalization_fallback := detached_live_session != null and not detached_was_runtime_normalized
	if detached_normalization_fallback:
		OverworldRulesScript.normalize_overworld_state(detached_live_session)
	buckets["detached_normalization"] = ProfileLogScript.elapsed_ms(normalization_started)
	var read_scope_started := ProfileLogScript.begin_usec()
	OverworldRulesScript.begin_normalized_read_scope(detached_live_session)
	TownRulesScript.begin_read_scope(detached_live_session)
	buckets["detached_read_scope_begin"] = ProfileLogScript.elapsed_ms(read_scope_started)
	var recap_started := ProfileLogScript.begin_usec()
	var recap_context_started := ProfileLogScript.begin_usec()
	var recap_context := _session_save_recap_context(detached_live_session, default_live_summary, "", true, refresh_watch_context)
	buckets["shared_recap_context"] = ProfileLogScript.elapsed_ms(recap_context_started)
	buckets["shared_progress_context"] = float(recap_context.get("profile_progress_ms", 0.0))
	buckets["shared_watch_context"] = float(recap_context.get("profile_watch_ms", 0.0))
	var save_copy_started := ProfileLogScript.begin_usec()
	var save_check := _describe_session_save_check_from_context(detached_live_session, default_live_summary, recap_context)
	var save_handoff := _describe_session_save_handoff_from_summary(detached_live_session, selected_live_summary, selected_slot)
	var save_handoff_brief := _describe_session_save_handoff_brief_from_summary(detached_live_session, selected_live_summary)
	buckets["save_copy"] = ProfileLogScript.elapsed_ms(save_copy_started)
	var return_copy_started := ProfileLogScript.begin_usec()
	var return_handoff := _describe_session_return_handoff_from_summary(detached_live_session, default_live_summary)
	buckets["return_copy"] = ProfileLogScript.elapsed_ms(return_copy_started)
	var current_recap_started := ProfileLogScript.begin_usec()
	var current_save_recap := _session_save_resume_recap_from_context(detached_live_session, default_live_summary, recap_context)
	buckets["current_save_recap"] = ProfileLogScript.elapsed_ms(current_recap_started)
	var play_check_started := ProfileLogScript.begin_usec()
	var play_check := _describe_session_play_check_from_context(detached_live_session, default_live_summary, recap_context)
	buckets["play_check"] = ProfileLogScript.elapsed_ms(play_check_started)
	buckets["recap_surfaces"] = ProfileLogScript.elapsed_ms(recap_started)
	TownRulesScript.end_read_scope(detached_live_session)
	OverworldRulesScript.end_normalized_read_scope(detached_live_session)
	var stored_recap_started := ProfileLogScript.begin_usec()
	var stored_recap_profile := {}
	var slot_resume_recap := _describe_summary_resume_recap_with_context(slot_summary, stored_recap_profile)
	var stored_recap_alias_reused := _summaries_share_storage_identity(slot_summary, latest_summary)
	var latest_resume_recap := slot_resume_recap if stored_recap_alias_reused else _describe_summary_resume_recap_with_context(latest_summary, stored_recap_profile)
	buckets["stored_resume_recaps"] = ProfileLogScript.elapsed_ms(stored_recap_started)
	var result := {
		"selected_slot": selected_slot,
		"slot_summary": slot_summary,
		"latest_summary": latest_summary,
		"save_button_label": _in_session_save_label(current_target, selected_slot),
		"save_button_tooltip": _in_session_save_tooltip(current_target, slot_summary, current_context),
		"latest_context": _latest_context_line(latest_summary, current_target),
		"current_context": current_context,
		"play_check": play_check,
		"save_check": save_check,
		"save_handoff": save_handoff,
		"save_handoff_brief": save_handoff_brief,
		"return_handoff": return_handoff,
		"current_save_recap": current_save_recap,
		"slot_resume_recap": slot_resume_recap,
		"latest_resume_recap": latest_resume_recap,
		"menu_button_label": _return_to_menu_label(current_target, detached_live_session),
		"menu_button_tooltip": _return_to_menu_tooltip(
			current_target,
			latest_summary,
			current_context,
			return_handoff
		),
	}
	ProfileLogScript.emit_general("save", "surface", "build_in_session_save_surface", ProfileLogScript.elapsed_ms(profile_started), buckets, {
		"selected_slot": selected_slot,
		"current_target": current_target,
		"detached_normalization_fallback": detached_normalization_fallback,
		"detached_was_runtime_normalized": detached_was_runtime_normalized,
		"stored_recap_alias_reused": stored_recap_alias_reused,
		"stored_recap_context_build_count": int(stored_recap_profile.get("context_build_count", 0)),
		"stored_recap_context_reuse_count": int(stored_recap_profile.get("context_reuse_count", 0)),
		"play_check_context_build_count": 1 if bool(recap_context.get("play_check_state_materialized", false)) else 0,
		"play_check_context_reuse_count": 1 if bool(recap_context.get("play_check_state_materialized", false)) else 0,
		"play_check_context_direct_fallback_count": int(recap_context.get("play_check_direct_fallback_count", 0)),
		"overworld_refresh_watch_context_preloaded": bool(recap_context.get("refresh_watch_context_preloaded", false)),
		"overworld_save_watch_context_reuse_count": 1 if bool(recap_context.get("refresh_watch_context_preloaded", false)) else 0,
		"overworld_save_watch_context_direct_fallback_count": 0 if bool(recap_context.get("refresh_watch_context_preloaded", false)) else 1,
	}, session)
	return result

func _build_in_session_save_surface_direct_legacy(
	session: SessionStateStoreScript.SessionData,
	manual_slot: int = -1
) -> Dictionary:
	var selected_slot := _normalize_manual_slot(manual_slot if manual_slot > 0 else _selected_manual_slot)
	var slot_summary := inspect_manual_slot(selected_slot)
	var latest_summary := latest_loadable_summary()
	var current_target := _resume_target_for_session(session)
	var current_context := _runtime_session_resume_brief(session)
	var save_check := describe_session_save_check(session)
	var save_handoff := describe_session_save_handoff(session, selected_slot)
	var save_handoff_brief := describe_session_save_handoff_brief(session, selected_slot)
	var return_handoff := describe_session_return_handoff(session)
	var current_save_recap := describe_session_save_recap(session)
	return {
		"selected_slot": selected_slot,
		"slot_summary": slot_summary,
		"latest_summary": latest_summary,
		"save_button_label": _in_session_save_label(current_target, selected_slot),
		"save_button_tooltip": _in_session_save_tooltip(current_target, slot_summary, current_context),
		"latest_context": _latest_context_line(latest_summary, current_target),
		"current_context": current_context,
		"play_check": describe_session_play_check(session),
		"save_check": save_check,
		"save_handoff": save_handoff,
		"save_handoff_brief": save_handoff_brief,
		"return_handoff": return_handoff,
		"current_save_recap": current_save_recap,
		"slot_resume_recap": _describe_summary_resume_recap_direct_legacy(slot_summary),
		"latest_resume_recap": _describe_summary_resume_recap_direct_legacy(latest_summary),
		"menu_button_label": _return_to_menu_label(current_target, session),
		"menu_button_tooltip": _return_to_menu_tooltip(
			current_target,
			latest_summary,
			current_context,
			describe_session_return_handoff(session)
		),
	}

func _live_session_summary_from_payload(
	payload: Dictionary,
	manual_slot: int,
	resume_target: String
) -> Dictionary:
	if payload.is_empty() or String(payload.get("scenario_id", "")) == "":
		return {}
	var selected_slot := _normalize_manual_slot(manual_slot)
	var summary := _empty_summary(SLOT_TYPE_MANUAL, str(selected_slot), _slot_path(selected_slot))
	summary = _populate_summary_from_payload(summary, payload)
	summary["payload"] = payload
	summary["valid"] = true
	summary["validity"] = "ok"
	summary["loadable"] = true
	summary["resume_target"] = resume_target
	summary["status_text"] = _status_text_for_summary(summary)
	return summary

func _session_from_owned_detached_payload(payload: Dictionary) -> SessionStateStoreScript.SessionData:
	if payload.is_empty():
		return null
	var session := SessionStateStoreScript.new_session_data()
	session.save_version = max(0, int(payload.get("save_version", SessionStateStoreScript.SAVE_VERSION)))
	session.session_id = String(payload.get("session_id", str(Time.get_ticks_msec())))
	session.scenario_id = String(payload.get("scenario_id", ""))
	session.hero_id = String(payload.get("hero_id", ""))
	session.day = max(1, int(payload.get("day", 1)))
	session.difficulty = String(payload.get("difficulty", "normal"))
	session.launch_mode = SessionStateStoreScript.normalize_launch_mode(payload.get("launch_mode", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN))
	session.game_state = SessionStateStoreScript._normalize_game_state(payload.get("game_state", "overworld"))
	session.scenario_status = SessionStateStoreScript._normalize_scenario_status(payload.get("scenario_status", "in_progress"))
	session.scenario_summary = String(payload.get("scenario_summary", ""))
	session.overworld = payload.get("overworld", {}) if payload.get("overworld", {}) is Dictionary else {}
	session.battle = payload.get("battle", {}) if payload.get("battle", {}) is Dictionary else {}
	session.flags = payload.get("flags", {}) if payload.get("flags", {}) is Dictionary else {}
	return session

func _summaries_share_storage_identity(first: Dictionary, second: Dictionary) -> bool:
	if first.is_empty() or second.is_empty():
		return false
	var first_path := String(first.get("path", ""))
	if first_path == "" or first_path != String(second.get("path", "")):
		return false
	for key in [
		"slot_type",
		"slot_id",
		"validity",
		"loadable",
		"modified_timestamp",
		"recorded_timestamp",
		"recorded_timestamp_precise",
		"payload_bytes",
	]:
		if first.get(key) != second.get(key):
			return false
	return true

func _live_summary_for_manual_slot(source: Dictionary, manual_slot: int, valid_storage: bool) -> Dictionary:
	if source.is_empty():
		return {}
	var selected_slot := _normalize_manual_slot(manual_slot)
	var summary := source.duplicate(false)
	summary["slot_type"] = SLOT_TYPE_MANUAL
	summary["slot_id"] = str(selected_slot)
	summary["path"] = _slot_path(selected_slot)
	summary["validity"] = "ok" if valid_storage else "missing"
	summary["status_text"] = _status_text_for_summary(summary)
	return summary

func _session_save_recap_context(
	session: SessionStateStoreScript.SessionData,
	summary: Dictionary,
	preloaded_progress_recap: String = "",
	include_play_check_state: bool = false,
	refresh_watch_context: Dictionary = {}
) -> Dictionary:
	if session == null or session.scenario_id == "" or summary.is_empty():
		return {
			"changed_line": "",
			"watch_line": "",
			"next_decision_line": "",
			"progress_recap": "",
			"profile_progress_ms": 0.0,
			"profile_watch_ms": 0.0,
			"play_check_state_line": "",
			"play_check_state_materialized": false,
			"play_check_direct_fallback_count": 0,
			"refresh_watch_context_preloaded": false,
		}
	var progress_started := ProfileLogScript.begin_usec()
	var resume_target := String(summary.get("resume_target", "overworld"))
	var preferred_recap := _preferred_recent_action_recap(session, resume_target)
	var recap_summary := _action_recap_change_summary(preferred_recap)
	var recap_next := _action_recap_next_step(preferred_recap)
	var battle_summary := _battle_aftermath_summary(session) if resume_target == "battle" and recap_summary == "" else ""
	var progress_recap := preloaded_progress_recap
	if (recap_summary == "" and battle_summary == "") or recap_next == "":
		if progress_recap == "":
			progress_recap = load("res://scripts/core/ScenarioRules.gd").describe_session_progress_recap_from_normalized_session(session, false)
	var changed_line := recap_summary
	if changed_line == "":
		changed_line = battle_summary
	if changed_line == "":
		var progress_recent := _line_with_prefix(progress_recap, "Recently resolved:")
		if progress_recent != "":
			changed_line = _safe_player_text(progress_recent.trim_prefix("Recently resolved:").strip_edges(), 220)
	if changed_line == "":
		var scenario_summary := String(summary.get("scenario_summary", "")).strip_edges()
		changed_line = _safe_player_text(scenario_summary, 220) if scenario_summary != "" else "No recent action recap is stored; resume to make the next scene order."
	var next_decision_line := recap_next
	if next_decision_line == "":
		var progress_next := _line_with_prefix(progress_recap, "Next step:")
		if progress_next != "":
			next_decision_line = _safe_player_text(progress_next.trim_prefix("Next step:").strip_edges(), 220)
	if next_decision_line == "":
		var action_line := _summary_resume_action_line(summary)
		next_decision_line = (
			_safe_player_text(action_line.trim_prefix("Action:").strip_edges(), 220)
			if action_line != ""
			else "Load the save, inspect the resumed scene, then choose the next order."
		)
	if include_play_check_state and progress_recap == "" and resume_target in ["overworld", "outcome"]:
		progress_recap = load("res://scripts/core/ScenarioRules.gd").describe_session_progress_recap_from_normalized_session(session, false)
	var progress_ms := ProfileLogScript.elapsed_ms(progress_started)
	var watch_started := ProfileLogScript.begin_usec()
	var refresh_watch_context_preloaded := (
		resume_target == "overworld"
		and refresh_watch_context.has("command_risk_forecast")
		and refresh_watch_context.has("management_watch")
	)
	var effective_refresh_watch_context: Dictionary = refresh_watch_context if refresh_watch_context_preloaded else {}
	var watch_line := _summary_watch_state_line(session, summary, true, progress_recap, effective_refresh_watch_context)
	var play_check_context := {
		"progress_recap": progress_recap,
		"watch_line": watch_line,
	}
	var play_check_state_line := ""
	var play_check_direct_fallback_count := 0
	if include_play_check_state:
		play_check_state_line = _summary_play_check_state_line_from_context(session, summary, play_check_context)
		play_check_direct_fallback_count = int(play_check_context.get("direct_fallback_count", 0))
	return {
		"changed_line": changed_line,
		"watch_line": watch_line,
		"next_decision_line": next_decision_line,
		"progress_recap": progress_recap,
		"profile_progress_ms": progress_ms,
		"profile_watch_ms": ProfileLogScript.elapsed_ms(watch_started),
		"play_check_state_line": play_check_state_line,
		"play_check_state_materialized": include_play_check_state,
		"play_check_direct_fallback_count": play_check_direct_fallback_count,
		"refresh_watch_context_preloaded": refresh_watch_context_preloaded,
	}

func _describe_session_save_check_from_context(
	session: SessionStateStoreScript.SessionData,
	summary: Dictionary,
	recap_context: Dictionary
) -> String:
	if session == null or session.scenario_id == "":
		return "Save check: no active expedition."
	var resume_context := _safe_player_text(_resume_context_label(summary), 44)
	var changed := _safe_player_text(String(recap_context.get("changed_line", "")), 74)
	var next_decision := _safe_player_text(String(recap_context.get("next_decision_line", "")), 74)
	var parts := []
	if resume_context != "":
		parts.append("Resume: %s" % resume_context)
	if changed != "":
		parts.append("What changed: %s" % changed)
	if next_decision != "":
		parts.append("Next: %s" % next_decision)
	return "Save check: %s" % " | ".join(parts)

func _describe_session_save_handoff_from_summary(
	session: SessionStateStoreScript.SessionData,
	summary: Dictionary,
	manual_slot: int
) -> String:
	if session == null or session.scenario_id == "":
		return "Save handoff: no active expedition is available to write."
	if summary.is_empty():
		return "Save handoff: no active expedition is available to write."
	return "Save handoff: %s writes %s as %s; Load Selected reopens %s with %s preserved." % [
		_in_session_save_label(String(summary.get("resume_target", "blocked")), manual_slot),
		_slot_label(summary),
		_resume_target_label(summary),
		_resume_context_label(summary),
		_resume_preserved_context(summary),
	]

func _describe_session_save_handoff_brief_from_summary(
	session: SessionStateStoreScript.SessionData,
	summary: Dictionary
) -> String:
	if session == null or session.scenario_id == "":
		return "Save handoff: no active expedition."
	if summary.is_empty():
		return "Save handoff: no active expedition."
	return "Save handoff: %s -> %s." % [_slot_label(summary), _resume_target_label(summary)]

func _describe_session_play_check_from_summary(
	session: SessionStateStoreScript.SessionData,
	summary: Dictionary
) -> String:
	if session == null or session.scenario_id == "":
		return "Play check: no active expedition."
	var resume_context := _safe_player_text(_resume_context_label(summary), 34)
	var next_action := _safe_player_text(
		describe_summary_next_play_action(summary).trim_prefix("Next play action:").strip_edges(),
		72
	)
	var state_line := ""
	if String(summary.get("resume_target", "overworld")) == "town":
		var defense_line := _first_meaningful_line(TownRulesScript.describe_defense_headline(session), ["Defense"])
		if defense_line != "":
			state_line = _safe_player_text("Defense: %s" % defense_line.trim_prefix("- ").strip_edges(), 72)
	else:
		state_line = _summary_play_check_state_line(session, summary)
	var parts := []
	if resume_context != "":
		parts.append("%s ready" % resume_context)
	if next_action != "":
		parts.append(next_action)
	if state_line != "":
		parts.append(state_line)
	return "Play check: %s" % " | ".join(parts.slice(0, min(3, parts.size())))

func _describe_session_play_check_from_context(
	session: SessionStateStoreScript.SessionData,
	summary: Dictionary,
	recap_context: Dictionary
) -> String:
	if not bool(recap_context.get("play_check_state_materialized", false)):
		return _describe_session_play_check_from_summary(session, summary)
	if session == null or session.scenario_id == "":
		return "Play check: no active expedition."
	var resume_context := _safe_player_text(_resume_context_label(summary), 34)
	var next_action := _safe_player_text(
		describe_summary_next_play_action(summary).trim_prefix("Next play action:").strip_edges(),
		72
	)
	var state_line := String(recap_context.get("play_check_state_line", ""))
	var parts := []
	if resume_context != "":
		parts.append("%s ready" % resume_context)
	if next_action != "":
		parts.append(next_action)
	if state_line != "":
		parts.append(state_line)
	return "Play check: %s" % " | ".join(parts.slice(0, min(3, parts.size())))

func _describe_session_return_handoff_from_summary(
	session: SessionStateStoreScript.SessionData,
	summary: Dictionary
) -> String:
	if session == null or session.scenario_id == "":
		return "Return handoff: no active expedition is available to preserve."
	var target := _resume_context_label(summary)
	var preserved := _resume_preserved_context(summary)
	if bool(session.flags.get("editor_working_copy", false)):
		return "Return handoff: Editor restores the Play Copy launch snapshot; %s keeps %s preserved while this copy is active." % [
			target,
			preserved,
		]
	return "Return handoff: Menu autosaves %s; Continue Latest returns to %s with %s preserved." % [
		describe_resume_brief(summary),
		target,
		preserved,
	]

func _session_save_resume_recap_from_context(
	session: SessionStateStoreScript.SessionData,
	summary: Dictionary,
	recap_context: Dictionary
) -> String:
	if session == null or session.scenario_id == "":
		return "Saved state: No active expedition is available."
	var lines := []
	lines.append("Saved state: %s" % describe_resume_brief(summary))
	var next_play_action := describe_summary_next_play_action(summary)
	if next_play_action != "":
		lines.append(next_play_action)
	var resume_handoff := describe_summary_resume_handoff(summary)
	if resume_handoff != "":
		lines.append(resume_handoff)
	var changed_line := String(recap_context.get("changed_line", ""))
	if changed_line != "":
		lines.append("What changed: %s" % changed_line)
	lines.append("Resume state: %s | %s" % [
		_resume_context_label(summary),
		_humanize_label(String(summary.get("game_state", "overworld"))),
	])
	var watch_line := String(recap_context.get("watch_line", ""))
	if watch_line != "":
		lines.append("Watch: %s" % watch_line.trim_prefix("Risk watch:").strip_edges())
	var next_line := String(recap_context.get("next_decision_line", ""))
	if next_line != "":
		lines.append("Next decision: %s" % next_line)
	return "\n".join(lines)

func resume_target_for_session(session: SessionStateStoreScript.SessionData) -> String:
	return _resume_target_for_session(session)

func can_load_summary(summary: Dictionary) -> bool:
	var payload = summary.get("payload", {})
	var has_inline_payload: bool = payload is Dictionary and not (payload as Dictionary).is_empty()
	return bool(summary.get("valid", false)) and bool(summary.get("loadable", false)) and (
		has_inline_payload
		or bool(summary.get("payload_deferred", false))
	)

func load_action_label(summary: Dictionary) -> String:
	if summary.is_empty() or not can_load_summary(summary):
		return "Load Selected"
	match String(summary.get("resume_target", "overworld")):
		"battle":
			return "Resume Battle"
		"town":
			return "Resume Town"
		"outcome":
			return "Review Outcome"
		_:
			return "Resume Expedition"

func continue_action_label(summary: Dictionary) -> String:
	if summary.is_empty() or not can_load_summary(summary):
		return "Continue Latest"
	match String(summary.get("resume_target", "overworld")):
		"battle":
			return "Resume Latest Battle"
		"town":
			return "Resume Latest Town"
		"outcome":
			return "Review Latest Outcome"
		_:
			return "Continue Latest"

func load_action_tooltip(summary: Dictionary) -> String:
	if summary.is_empty():
		return "No loadable saves are available."
	if not can_load_summary(summary):
		return String(summary.get("status_text", "This save cannot be resumed."))
	var scenario_name := _safe_player_text(
		String(summary.get("scenario_name", summary.get("scenario_id", "this expedition"))),
		48
	)
	var day := int(summary.get("day", 0))
	var timing := ""
	if day > 0:
		timing = " on Day %d" % day
	return "%s%s at %s. Loading does not change any saved slot." % [
		"Resume the saved expedition in %s" % scenario_name,
		timing,
		_load_destination_label(summary),
	]

func describe_session_save_recap(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.scenario_id == "":
		return "Saved state: No active expedition is available."
	var summary := _empty_summary(SLOT_TYPE_MANUAL, str(_selected_manual_slot), _slot_path(_selected_manual_slot))
	summary = _populate_summary_from_payload(summary, session.to_dict())
	summary["payload"] = session.to_dict()
	summary["valid"] = true
	summary["loadable"] = true
	summary["resume_target"] = _resume_target_for_session(session)
	summary["status_text"] = _status_text_for_summary(summary)
	return _session_save_resume_recap(session, summary)

func describe_session_save_check(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.scenario_id == "":
		return "Save check: no active expedition."
	var summary := _empty_summary(SLOT_TYPE_MANUAL, str(_selected_manual_slot), _slot_path(_selected_manual_slot))
	summary = _populate_summary_from_payload(summary, session.to_dict())
	summary["payload"] = session.to_dict()
	summary["valid"] = true
	summary["loadable"] = true
	summary["resume_target"] = _resume_target_for_session(session)
	summary["status_text"] = _status_text_for_summary(summary)
	var resume_context := _safe_player_text(_resume_context_label(summary), 44)
	var changed := _safe_player_text(_session_changed_recap_line(session, summary), 74)
	var next_decision := _safe_player_text(_session_next_decision_line(session, summary), 74)
	var parts := []
	if resume_context != "":
		parts.append("Resume: %s" % resume_context)
	if changed != "":
		parts.append("What changed: %s" % changed)
	if next_decision != "":
		parts.append("Next: %s" % next_decision)
	return "Save check: %s" % " | ".join(parts)

func describe_session_save_handoff(
	session: SessionStateStoreScript.SessionData,
	manual_slot: int = -1
) -> String:
	if session == null or session.scenario_id == "":
		return "Save handoff: no active expedition is available to write."
	var selected_slot := _normalize_manual_slot(manual_slot if manual_slot > 0 else _selected_manual_slot)
	var summary := _manual_summary_for_session(session, selected_slot)
	if summary.is_empty():
		return "Save handoff: no active expedition is available to write."
	return "Save handoff: %s writes %s as %s; Load Selected reopens %s with %s preserved." % [
		_in_session_save_label(String(summary.get("resume_target", "blocked")), selected_slot),
		_slot_label(summary),
		_resume_target_label(summary),
		_resume_context_label(summary),
		_resume_preserved_context(summary),
	]

func describe_session_save_handoff_brief(
	session: SessionStateStoreScript.SessionData,
	manual_slot: int = -1
) -> String:
	if session == null or session.scenario_id == "":
		return "Save handoff: no active expedition."
	var selected_slot := _normalize_manual_slot(manual_slot if manual_slot > 0 else _selected_manual_slot)
	var summary := _manual_summary_for_session(session, selected_slot)
	if summary.is_empty():
		return "Save handoff: no active expedition."
	return "Save handoff: %s -> %s." % [_slot_label(summary), _resume_target_label(summary)]

func describe_summary_resume_recap(summary: Dictionary) -> String:
	return _describe_summary_resume_recap_with_context(summary, {})

func _describe_summary_resume_recap_with_context(summary: Dictionary, profile: Dictionary) -> String:
	if summary.is_empty():
		return ""
	if not can_load_summary(summary):
		return "Saved state: %s" % String(summary.get("status_text", "This save cannot be resumed."))
	var session := _session_from_payload(_summary_payload(summary))
	if session == null or session.scenario_id == "":
		return "Saved state: This save cannot be inspected."
	OverworldRulesScript.normalize_overworld_state(session)
	OverworldRulesScript.begin_normalized_read_scope(session)
	TownRulesScript.begin_read_scope(session)
	var recap_context := _session_save_recap_context(session, summary)
	var result := _session_save_resume_recap_from_context(session, summary, recap_context)
	TownRulesScript.end_read_scope(session)
	OverworldRulesScript.end_normalized_read_scope(session)
	profile["context_build_count"] = int(profile.get("context_build_count", 0)) + 1
	profile["context_reuse_count"] = int(profile.get("context_reuse_count", 0)) + 3
	return result

func _describe_summary_resume_recap_direct_legacy(summary: Dictionary) -> String:
	if summary.is_empty():
		return ""
	if not can_load_summary(summary):
		return "Saved state: %s" % String(summary.get("status_text", "This save cannot be resumed."))
	var session := _session_from_payload(_summary_payload(summary))
	if session == null or session.scenario_id == "":
		return "Saved state: This save cannot be inspected."
	return _session_save_resume_recap(session, summary)

func describe_summary_next_play_action(summary: Dictionary) -> String:
	if summary.is_empty():
		return "Next play action: Select a loadable save or start a fresh expedition."
	if not can_load_summary(summary):
		return "Next play action: Select a loadable save before resuming play."
	var action := load_action_label(summary)
	match String(summary.get("resume_target", "blocked")):
		"battle":
			return "Next play action: %s, finish the encounter, then return to the field." % action
		"town":
			return "Next play action: %s, make the town order, then return to the field." % action
		"outcome":
			return "Next play action: %s, save if needed, then choose retry, next chapter, or menu." % action
		"overworld":
			return "Next play action: %s, choose the next field route, then save or end turn." % action
		_:
			return "Next play action: Select a loadable save before resuming play."

func describe_summary_play_check(summary: Dictionary) -> String:
	if summary.is_empty():
		return "Play check: no loadable save; start or select an expedition."
	if not can_load_summary(summary):
		return "Play check: save unavailable; select a loadable slot."
	var session := _session_from_payload(_summary_payload(summary))
	var resume_context := _safe_player_text(_resume_context_label(summary), 34)
	var next_action := _safe_player_text(
		describe_summary_next_play_action(summary).trim_prefix("Next play action:").strip_edges(),
		72
	)
	var state_line := _summary_play_check_state_line(session, summary)
	var parts := []
	if resume_context != "":
		parts.append("%s ready" % resume_context)
	if next_action != "":
		parts.append(next_action)
	if state_line != "":
		parts.append(state_line)
	return "Play check: %s" % " | ".join(parts.slice(0, min(3, parts.size())))

func describe_session_play_check(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.scenario_id == "":
		return "Play check: no active expedition."
	var summary := _empty_summary(SLOT_TYPE_MANUAL, str(_selected_manual_slot), _slot_path(_selected_manual_slot))
	summary = _populate_summary_from_payload(summary, session.to_dict())
	summary["payload"] = session.to_dict()
	summary["valid"] = true
	summary["loadable"] = true
	summary["resume_target"] = _resume_target_for_session(session)
	summary["status_text"] = _status_text_for_summary(summary)
	return describe_summary_play_check(summary)

func describe_summary_resume_handoff(summary: Dictionary) -> String:
	if summary.is_empty():
		return "Resume handoff: select a loadable save to see its landing surface."
	if not can_load_summary(summary):
		return "Resume handoff: this save cannot be restored safely."
	var target := _resume_context_label(summary)
	var preserved := _resume_preserved_context(summary)
	return "Resume handoff: %s opens %s with %s preserved." % [
		load_action_label(summary),
		target,
		preserved,
	]

func describe_session_return_handoff(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.scenario_id == "":
		return "Return handoff: no active expedition is available to preserve."
	var summary := _empty_summary(SLOT_TYPE_MANUAL, str(_selected_manual_slot), _slot_path(_selected_manual_slot))
	summary = _populate_summary_from_payload(summary, session.to_dict())
	summary["payload"] = session.to_dict()
	summary["valid"] = true
	summary["loadable"] = true
	summary["resume_target"] = _resume_target_for_session(session)
	summary["status_text"] = _status_text_for_summary(summary)
	var target := _resume_context_label(summary)
	var preserved := _resume_preserved_context(summary)
	if bool(session.flags.get("editor_working_copy", false)):
		return "Return handoff: Editor restores the Play Copy launch snapshot; %s keeps %s preserved while this copy is active." % [
			target,
			preserved,
		]
	return "Return handoff: Menu autosaves %s; Continue Latest returns to %s with %s preserved." % [
		describe_resume_brief(summary),
		target,
		preserved,
	]

func describe_resume_brief(summary: Dictionary) -> String:
	if summary.is_empty():
		return "No save selected."
	if not can_load_summary(summary):
		return String(summary.get("status_text", "This save cannot be resumed."))
	var parts := []
	parts.append(ScenarioSelectRulesScript.launch_mode_label(String(summary.get("launch_mode", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN))))
	var scenario_name := String(summary.get("scenario_name", summary.get("scenario_id", "Unknown Scenario")))
	if scenario_name != "":
		parts.append(scenario_name)
	var day := int(summary.get("day", 0))
	if day > 0:
		parts.append("Day %d" % day)
	parts.append(_resume_context_label(summary))
	var scenario_status := String(summary.get("scenario_status", "in_progress"))
	if scenario_status != "in_progress":
		parts.append(_humanize_label(scenario_status))
	return " | ".join(parts)

func describe_slot(summary: Dictionary) -> String:
	var slot_label := _slot_label(summary)
	if not bool(summary.get("valid", false)):
		return "%s | Blocked | %s" % [slot_label, String(summary.get("status_text", "Unavailable"))]

	var parts := [slot_label, _summary_status_badge(summary)]
	var modified_label := format_modified_timestamp(int(_summary_sort_timestamp(summary)))
	if modified_label != "":
		parts.append(modified_label)
	var scenario_name := String(summary.get("scenario_name", summary.get("scenario_id", "Unknown Scenario")))
	if scenario_name != "":
		parts.append(scenario_name)
	parts.append(ScenarioSelectRulesScript.launch_mode_label(String(summary.get("launch_mode", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN))))
	parts.append(ScenarioSelectRulesScript.difficulty_label(String(summary.get("difficulty", ScenarioSelectRulesScript.default_difficulty_id()))))
	parts.append(_resume_target_label(summary))
	var battle_name := String(summary.get("battle_name", ""))
	if battle_name != "" and String(summary.get("resume_target", "")) == "battle":
		parts.append(battle_name)
	var resume_location := String(summary.get("resume_location", ""))
	if resume_location != "" and String(summary.get("resume_target", "")) != "battle":
		parts.append(resume_location)
	var day := int(summary.get("day", 0))
	if day > 0:
		parts.append("Day %d" % day)
	return " | ".join(parts)

func describe_slot_browser_row(summary: Dictionary) -> String:
	var slot_label := _slot_label(summary)
	if not bool(summary.get("valid", false)):
		return "%s | Unavailable" % slot_label

	var parts := [slot_label]
	var scenario_name := _safe_player_text(String(summary.get("scenario_name", summary.get("scenario_id", "Unknown Scenario"))), 34)
	if scenario_name != "":
		parts.append(scenario_name)
	var day := int(summary.get("day", 0))
	if day > 0:
		parts.append("Day %d" % day)
	parts.append(_load_destination_label(summary))
	return " | ".join(parts)

func describe_load_preview(summary: Dictionary) -> String:
	if summary.is_empty():
		return "No saved expedition selected."
	if not can_load_summary(summary):
		return "%s\nUnavailable\n%s" % [
			_slot_label(summary),
			String(summary.get("status_text", "This save cannot be opened.")),
		]

	var scenario_name := _safe_player_text(
		String(summary.get("scenario_name", summary.get("scenario_id", "Saved Expedition"))),
		64
	)
	var mode_label := ScenarioSelectRulesScript.launch_mode_label(
		String(summary.get("launch_mode", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN))
	)
	var difficulty_label := ScenarioSelectRulesScript.difficulty_label(
		String(summary.get("difficulty", ScenarioSelectRulesScript.default_difficulty_id()))
	)
	var lines := [_slot_label(summary), scenario_name]
	var expedition_parts := [mode_label, difficulty_label]
	var day := int(summary.get("day", 0))
	if day > 0:
		expedition_parts.append("Day %d" % day)
	lines.append(" | ".join(expedition_parts))

	var hero_name := _safe_player_text(String(summary.get("hero_name", "")), 48)
	if hero_name != "":
		lines.append("Commander: %s" % hero_name)
	var modified_label := format_modified_timestamp(int(_summary_sort_timestamp(summary)))
	if modified_label != "":
		lines.append("Saved: %s" % modified_label)
	lines.append("Returns to: %s" % _load_destination_label(summary))

	var session := _session_from_payload(_summary_payload(summary))
	var next_decision := _safe_player_text(_session_next_decision_line(session, summary), 96)
	if next_decision == "":
		next_decision = _fallback_resume_decision(String(summary.get("resume_target", "blocked")))
	if next_decision != "":
		lines.append("Next: %s" % next_decision)
	return "\n".join(lines)

func _load_destination_label(summary: Dictionary) -> String:
	var location := _safe_player_text(String(summary.get("resume_location", "")).strip_edges(), 48)
	match String(summary.get("resume_target", "blocked")):
		"battle":
			return location if location != "" else "Active Battle"
		"town":
			return location if location != "" else "Town"
		"outcome":
			var result := _humanize_label(String(summary.get("scenario_status", "outcome")))
			return "%s Review" % result if result != "" else "Result Review"
		"overworld":
			return "Adventure Map"
		_:
			return "Unavailable"

func describe_slot_continuity_cue(summary: Dictionary) -> String:
	if summary.is_empty():
		return "Cue: select a saved expedition."
	if not can_load_summary(summary):
		return "Cue: this save cannot be resumed."

	var target := _safe_player_text(_resume_target_label(summary), 28)
	var session := _session_from_payload(_summary_payload(summary))
	var next_decision := _safe_player_text(_session_next_decision_line(session, summary), 56)
	if next_decision == "":
		next_decision = _fallback_resume_decision(String(summary.get("resume_target", "blocked")))
	if target == "":
		target = _safe_player_text(_resume_context_label(summary), 28)
	return "Cue: %s -> %s" % [target, next_decision]

func describe_slot_details(summary: Dictionary) -> String:
	return _describe_slot_details(summary)

func _describe_slot_details(
	summary: Dictionary,
	trusted_normalized_session: SessionStateStoreScript.SessionData = null,
	recap_context: Dictionary = {},
	progress_recap: String = ""
) -> String:
	var lines := [_slot_label(summary)]
	var modified_label := format_modified_timestamp(int(summary.get("modified_timestamp", 0)))
	if modified_label != "":
		lines.append("Updated: %s" % modified_label)
	var recorded_label := format_modified_timestamp(int(summary.get("recorded_timestamp", 0)))
	if recorded_label != "" and recorded_label != modified_label:
		lines.append("Recorded in save: %s" % recorded_label)

	var scenario_id := String(summary.get("scenario_id", ""))
	if scenario_id != "":
		lines.append(
			"Scenario: %s (%s)"
			% [String(summary.get("scenario_name", scenario_id)), scenario_id]
		)
	lines.append(
		"Mode: %s | Difficulty: %s"
		% [
			ScenarioSelectRulesScript.launch_mode_label(String(summary.get("launch_mode", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN))),
			ScenarioSelectRulesScript.difficulty_label(String(summary.get("difficulty", ScenarioSelectRulesScript.default_difficulty_id()))),
		]
	)

	var campaign_name := String(summary.get("campaign_name", ""))
	var chapter_label := String(summary.get("chapter_label", ""))
	if campaign_name != "" and chapter_label != "":
		lines.append("Campaign: %s | %s" % [campaign_name, chapter_label])
	elif campaign_name != "":
		lines.append("Campaign: %s" % campaign_name)
	elif chapter_label != "":
		lines.append("Chapter: %s" % chapter_label)

	var hero_name := String(summary.get("hero_name", ""))
	var hero_id := String(summary.get("hero_id", ""))
	if hero_name != "" and hero_id != "":
		lines.append("Hero: %s (%s)" % [hero_name, hero_id])
	elif hero_name != "":
		lines.append("Hero: %s" % hero_name)
	elif hero_id != "":
		lines.append("Hero: %s" % hero_id)
	var hero_specialties_summary := String(summary.get("hero_specialties_summary", ""))
	if hero_specialties_summary != "":
		lines.append("Specialties: %s" % hero_specialties_summary)
	var battle_name := String(summary.get("battle_name", ""))
	if battle_name != "" and String(summary.get("resume_target", "")) == "battle":
		lines.append("Battle: %s" % battle_name)

	var day := int(summary.get("day", 0))
	if day > 0:
		lines.append("Day: %d" % day)
	lines.append("Resume target: %s" % _resume_context_label(summary))
	var scenario_summary := String(summary.get("scenario_summary", ""))
	if scenario_summary != "":
		lines.append("Recent result: %s" % scenario_summary)
	lines.append("Integrity: %s" % _validity_label(String(summary.get("validity", "missing"))))
	lines.append("Load state: %s" % _resume_target_label(summary))

	if not bool(summary.get("valid", false)):
		lines.append("Status: %s" % String(summary.get("status_text", "Unavailable")))
		var invalid_warnings = summary.get("warnings", [])
		if invalid_warnings is Array and not invalid_warnings.is_empty():
			lines.append("Notes: %s" % "; ".join(invalid_warnings))
		return "\n".join(lines)

	lines.append(
		"Scenario status: %s"
		% _humanize_label(String(summary.get("scenario_status", "in_progress")))
	)
	lines.append(
		"Scene state: %s"
		% _humanize_label(String(summary.get("game_state", "overworld")))
	)
	lines.append(
		"Resume: %s"
		% String(summary.get("status_text", "Unavailable"))
	)
	var use_trusted_context := trusted_normalized_session != null and not recap_context.is_empty()
	var resume_recap := (
		_session_save_resume_recap_from_context(trusted_normalized_session, summary, recap_context)
		if use_trusted_context
		else describe_summary_resume_recap(summary)
	)
	if resume_recap != "":
		lines.append(resume_recap)
	var continuity_lines := (
		_summary_continuity_lines_from_context(summary, recap_context)
		if use_trusted_context
		else _summary_continuity_lines(summary)
	)
	if not continuity_lines.is_empty():
		lines.append_array(continuity_lines)
	var resolved_progress_recap := progress_recap if use_trusted_context else _summary_progress_recap(summary)
	if resolved_progress_recap != "":
		lines.append(resolved_progress_recap)

	var warnings = summary.get("warnings", [])
	if warnings is Array and not warnings.is_empty():
		lines.append("Notes: %s" % "; ".join(warnings))

	return "\n".join(lines)

func format_modified_timestamp(timestamp: int) -> String:
	if timestamp <= 0:
		return ""
	var datetime := Time.get_datetime_dict_from_unix_time(timestamp)
	if datetime.is_empty():
		return str(timestamp)
	return "%04d-%02d-%02d %02d:%02d" % [
		int(datetime.get("year", 0)),
		int(datetime.get("month", 0)),
		int(datetime.get("day", 0)),
		int(datetime.get("hour", 0)),
		int(datetime.get("minute", 0)),
	]

func _slot_path(slot: int) -> String:
	return "%s/%s%d.json" % [SAVE_DIR, SAVE_PREFIX, _normalize_manual_slot(slot)]

func _autosave_path() -> String:
	return "%s/%s" % [SAVE_DIR, AUTOSAVE_FILE]

func _progression_path() -> String:
	return "%s/%s" % [SAVE_DIR, PROGRESSION_FILE]

func _deletable_slot_identity(summary: Dictionary) -> Dictionary:
	if summary.is_empty():
		return {}
	var slot_type := String(summary.get("slot_type", ""))
	var slot_id := String(summary.get("slot_id", ""))
	if slot_type == SLOT_TYPE_AUTOSAVE and slot_id == SLOT_TYPE_AUTOSAVE:
		return {
			"slot_type": SLOT_TYPE_AUTOSAVE,
			"slot_id": SLOT_TYPE_AUTOSAVE,
			"path": _autosave_path(),
		}
	if slot_type != SLOT_TYPE_MANUAL or not slot_id.is_valid_int():
		return {}
	var manual_slot := int(slot_id)
	if manual_slot not in MANUAL_SLOT_IDS or str(manual_slot) != slot_id:
		return {}
	return {
		"slot_type": SLOT_TYPE_MANUAL,
		"slot_id": str(manual_slot),
		"path": _slot_path(manual_slot),
	}

func _summary_for_slot_identity(identity: Dictionary) -> Dictionary:
	match String(identity.get("slot_type", "")):
		SLOT_TYPE_AUTOSAVE:
			return inspect_autosave()
		SLOT_TYPE_MANUAL:
			return inspect_manual_slot(int(identity.get("slot_id", MANUAL_SLOT_IDS[0])))
		_:
			return {}

func _ensure_save_dir() -> bool:
	var absolute_path := ProjectSettings.globalize_path(SAVE_DIR)
	var error := DirAccess.make_dir_recursive_absolute(absolute_path)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("Unable to create save directory: %s" % absolute_path)
		return false
	return true

func _save_payload(
	payload: Dictionary,
	file_path: String,
	slot_type: String = SLOT_TYPE_MANUAL,
	saved_payload_out: Dictionary = {},
	profile: Dictionary = {},
	payload_is_prepared: bool = false
) -> String:
	var recovery_started := ProfileLogScript.begin_usec()
	var recovery := _verified_cached_manual_save_recovery(file_path, slot_type)
	var recovery_cache_hit := not recovery.is_empty()
	if not recovery_cache_hit:
		recovery = _recover_save_transaction(file_path)
	_runtime_save_profile_bucket(profile, "recovery", ProfileLogScript.elapsed_ms(recovery_started))
	if not profile.is_empty():
		profile["recovery_count"] = int(profile.get("recovery_count", 0)) + 1
		profile["recovery_parse_count"] = 0 if recovery_cache_hit else 1
		profile["recovery_cache_hit"] = recovery_cache_hit
		profile["recovery_reason"] = String(recovery.get("reason", "verified_live"))
	var normalize_started := ProfileLogScript.begin_usec()
	var retained_manual_name := ""
	if slot_type == SLOT_TYPE_MANUAL and bool(recovery.get("live_valid", false)):
		retained_manual_name = String(recovery.get("retained_manual_name", ""))
	var normalized: Dictionary = payload if payload_is_prepared else SessionStateStoreScript.normalize_payload(payload)
	normalized["save_version"] = SessionStateStoreScript.SAVE_VERSION
	normalized[SAVE_METADATA_TIMESTAMP_KEY] = Time.get_unix_time_from_system()
	normalized[SAVE_METADATA_SLOT_TYPE_KEY] = slot_type
	normalized[SAVE_METADATA_GAME_STATE_KEY] = String(normalized.get("game_state", "overworld"))
	normalized[SAVE_METADATA_SCENARIO_STATUS_KEY] = String(normalized.get("scenario_status", "in_progress"))
	normalized[SAVE_METADATA_LAUNCH_MODE_KEY] = String(normalized.get("launch_mode", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN))
	if retained_manual_name != "":
		normalized[SAVE_METADATA_MANUAL_NAME_KEY] = retained_manual_name
	_runtime_save_profile_bucket(profile, "save_normalize", ProfileLogScript.elapsed_ms(normalize_started))
	if not profile.is_empty():
		profile["save_normalize_skipped"] = payload_is_prepared
		if payload_is_prepared and bool(profile.get("trusted_live_payload", false)):
			profile["save_normalize_skip_reason"] = "trusted_live_normalized_autosave"
		elif payload_is_prepared:
			profile["save_normalize_skip_reason"] = "prepared_normalized_manual_payload"
		else:
			profile["save_normalize_skip_reason"] = ""
	saved_payload_out.clear()
	for key in normalized.keys():
		saved_payload_out[key] = normalized[key]
	return _save_raw_dictionary(normalized, file_path, profile, recovery)

func _verified_cached_manual_save_recovery(file_path: String, slot_type: String) -> Dictionary:
	if slot_type != SLOT_TYPE_MANUAL or file_path == "":
		return {}
	if (
		FileAccess.file_exists(_save_transaction_candidate_path(file_path))
		or FileAccess.file_exists(_save_transaction_backup_path(file_path))
	):
		return {}
	var slot_id := ""
	for manual_slot in MANUAL_SLOT_IDS:
		if file_path == _slot_path(int(manual_slot)):
			slot_id = str(int(manual_slot))
			break
	if slot_id == "":
		return {}
	var summary := _cached_slot_summary(SLOT_TYPE_MANUAL, slot_id, file_path)
	if summary.is_empty():
		return {}
	if (
		not bool(summary.get("valid", false))
		or not bool(summary.get("loadable", false))
		or String(summary.get("slot_type", "")) != SLOT_TYPE_MANUAL
		or String(summary.get("slot_id", "")) != slot_id
		or String(summary.get("path", "")) != file_path
	):
		return {}
	if (
		int(summary.get("source_save_version", 0)) > SessionStateStoreScript.SAVE_VERSION
		or int(summary.get("save_version", 0)) > SessionStateStoreScript.SAVE_VERSION
	):
		return {}
	return {
		"ok": true,
		"recovered": false,
		"live_valid": true,
		"reason": "verified_summary_cache",
		"retained_manual_name": String(summary.get("manual_slot_name", "")),
	}

func _save_runtime_session(
	session: SessionStateStoreScript.SessionData,
	slot_type: String,
	slot: int = 1,
	include_summary: bool = true
) -> Dictionary:
	var profile := {
		"slot_type": slot_type,
		"include_summary": include_summary,
		"scenario_id": session.scenario_id if session != null else "",
		"generated_random_map": bool(session.flags.get("generated_random_map", false)) if session != null else false,
		"session_metadata": ProfileLogScript.session_metadata(session),
		"started_msec": Time.get_ticks_msec(),
		"started_usec": Time.get_ticks_usec(),
		"steps": [],
		"buckets_ms": {},
		"restore_normalize_pass_count": 0,
		"recovery_count": 0,
		"recovery_parse_count": 0,
		"recovery_cache_hit": false,
		"recovery_reason": "",
		"summary_session_reconstruction_count": 0,
		"summary_owned_session_materialization_count": 0,
		"summary_detail_context_build_count": 0,
		"summary_detail_context_reuse_count": 0,
		"summary_detail_direct_fallback_count": 0,
		"verification_parse_count": 0,
		"verification_payload_copy_count": 0,
		"restore_owned_payload_transfer": false,
		"prepared_payload": false,
		"prepared_payload_reason": "",
	}
	_runtime_save_profile_step(profile, "enter")
	if session == null or session.scenario_id == "":
		_runtime_save_profile_finish(profile)
		return {"ok": false, "path": "", "summary": {}, "message": "No active expedition is available to save."}
	if _can_fast_save_generated_opening_autosave(session, slot_type, include_summary):
		return _save_generated_opening_autosave_fast(session, profile)

	_runtime_save_profile_step(profile, "to_dict_start")
	var to_dict_started := ProfileLogScript.begin_usec()
	var runtime_payload := _runtime_payload_for_save(session)
	_runtime_save_profile_bucket(profile, "to_dict", ProfileLogScript.elapsed_ms(to_dict_started))
	_runtime_save_profile_step(profile, "to_dict_done")
	var sanitized_session: SessionStateStoreScript.SessionData = null
	var payload_for_write := runtime_payload
	if _can_use_trusted_live_autosave_payload(session, runtime_payload, slot_type):
		_runtime_save_profile_step(profile, "restore_normalize_skipped")
		_runtime_save_profile_bucket(profile, "restore_normalize", 0.0)
		profile["restore_normalize_skipped"] = true
		profile["restore_normalize_skip_reason"] = "trusted_live_normalized_autosave"
		profile["trusted_live_payload"] = true
		sanitized_session = session
	else:
		_runtime_save_profile_step(profile, "restore_normalize_start")
		profile["restore_normalize_pass_count"] = 1
		var restore_started := ProfileLogScript.begin_usec()
		var restore_result := _normalize_restore_result(runtime_payload, slot_type)
		_runtime_save_profile_bucket(profile, "restore_normalize", ProfileLogScript.elapsed_ms(restore_started))
		_runtime_save_profile_step(profile, "restore_normalize_done")
		profile["restore_normalize_skipped"] = false
		profile["restore_normalize_skip_reason"] = ""
		profile["restore_owned_payload_transfer"] = bool(restore_result.get("owned_payload_transfer", false))
		if not bool(restore_result.get("ok", false)):
			_runtime_save_profile_finish(profile)
			return {
				"ok": false,
				"path": "",
				"summary": {},
				"message": String(restore_result.get("message", "This session cannot be saved safely right now.")),
			}

		sanitized_session = restore_result.get("session", null)
		if sanitized_session == null:
			_runtime_save_profile_finish(profile)
			return {"ok": false, "path": "", "summary": {}, "message": "This session could not be prepared for saving."}
		if slot_type == SLOT_TYPE_MANUAL:
			payload_for_write = _owned_payload_from_normalized_detached_session(sanitized_session)
			profile["prepared_payload"] = true
			profile["prepared_payload_reason"] = "normalized_detached_manual_session"
		else:
			payload_for_write = sanitized_session.to_dict()

	var path := ""
	var summary := {}
	var cache_slot_id := ""
	var saved_payload := {}
	var payload_is_prepared := bool(profile.get("prepared_payload", false)) or bool(profile.get("trusted_live_payload", false))
	var write_payload := payload_for_write
	if payload_is_prepared:
		_clear_transition_autosave_intent_from_owned_payload(write_payload)
	else:
		write_payload = _payload_without_transition_autosave_intent(payload_for_write)
	var generated_opening_pending := _is_generated_opening_autosave_pending(session)
	if generated_opening_pending:
		if payload_is_prepared:
			_apply_generated_opening_autosave_success_to_owned_payload(write_payload)
		else:
			write_payload = _generated_opening_autosave_success_payload_from_payload(write_payload)
	var authoritative_resume_target := _resume_target_for_session(sanitized_session)
	match slot_type:
		SLOT_TYPE_AUTOSAVE:
			_runtime_save_profile_step(profile, "write_payload_start")
			var write_to_dict_started := ProfileLogScript.begin_usec()
			var autosave_payload := write_payload
			_runtime_save_profile_bucket(profile, "write_to_dict", ProfileLogScript.elapsed_ms(write_to_dict_started))
			path = _save_payload(autosave_payload, _autosave_path(), SLOT_TYPE_AUTOSAVE, saved_payload, profile)
			_runtime_save_profile_step(profile, "write_payload_done")
			cache_slot_id = SLOT_TYPE_AUTOSAVE
			if path != "" and include_summary:
				_runtime_save_profile_step(profile, "summary_cache_store_start")
				var summary_cache_started := ProfileLogScript.begin_usec()
				_store_runtime_summary_cache(saved_payload, SLOT_TYPE_AUTOSAVE, cache_slot_id, path, authoritative_resume_target, profile)
				_runtime_save_profile_bucket(profile, "summary_cache", ProfileLogScript.elapsed_ms(summary_cache_started))
				_runtime_save_profile_step(profile, "summary_cache_store_done")
			elif path != "":
				_runtime_save_profile_step(profile, "summary_cache_deferred")
			if include_summary:
				_runtime_save_profile_step(profile, "inspect_summary_start")
				var inspect_started := ProfileLogScript.begin_usec()
				summary = inspect_autosave()
				_runtime_save_profile_bucket(profile, "inspect_summary", ProfileLogScript.elapsed_ms(inspect_started))
				_runtime_save_profile_step(profile, "inspect_summary_done")
		_:
			var normalized_slot := _normalize_manual_slot(slot)
			_runtime_save_profile_step(profile, "write_payload_start")
			var write_to_dict_started := ProfileLogScript.begin_usec()
			var manual_payload := write_payload
			_runtime_save_profile_bucket(profile, "write_to_dict", ProfileLogScript.elapsed_ms(write_to_dict_started))
			path = _save_payload(manual_payload, _slot_path(normalized_slot), SLOT_TYPE_MANUAL, saved_payload, profile, payload_is_prepared)
			_runtime_save_profile_step(profile, "write_payload_done")
			cache_slot_id = str(normalized_slot)
			if path != "" and include_summary:
				_selected_manual_slot = normalized_slot
				_runtime_save_profile_step(profile, "summary_cache_store_start")
				var summary_cache_started := ProfileLogScript.begin_usec()
				_store_runtime_summary_cache(saved_payload, SLOT_TYPE_MANUAL, cache_slot_id, path, authoritative_resume_target, profile)
				_runtime_save_profile_bucket(profile, "summary_cache", ProfileLogScript.elapsed_ms(summary_cache_started))
				_runtime_save_profile_step(profile, "summary_cache_store_done")
			elif path != "":
				_runtime_save_profile_step(profile, "summary_cache_deferred")
			if include_summary:
				_runtime_save_profile_step(profile, "inspect_summary_start")
				var inspect_started := ProfileLogScript.begin_usec()
				summary = inspect_manual_slot(normalized_slot)
				_runtime_save_profile_bucket(profile, "inspect_summary", ProfileLogScript.elapsed_ms(inspect_started))
				_runtime_save_profile_step(profile, "inspect_summary_done")

	if path == "":
		_runtime_save_profile_finish(profile)
		return {"ok": false, "path": "", "summary": summary, "message": "Save write failed."}
	if generated_opening_pending:
		_apply_generated_opening_autosave_success_to_session(session)
	else:
		_clear_transition_autosave_intent_flags(session)
	if FileAccess.file_exists(path):
		profile["written_bytes"] = FileAccess.get_size(path)
		profile["path"] = path

	var result := {
		"ok": true,
		"path": path,
		"summary": summary,
		"message": _runtime_save_message(slot_type, summary) if include_summary else "Autosave updated.",
	}
	_runtime_save_profile_finish(profile)
	return result

func _can_use_trusted_live_autosave_payload(
	session: SessionStateStoreScript.SessionData,
	payload: Dictionary,
	slot_type: String
) -> bool:
	if session == null or payload.is_empty():
		return false
	if slot_type != SLOT_TYPE_AUTOSAVE:
		return false
	if String(payload.get("scenario_id", "")) == "":
		return false
	if int(payload.get("save_version", SessionStateStoreScript.SAVE_VERSION)) > SessionStateStoreScript.SAVE_VERSION:
		return false
	if not (String(payload.get("game_state", "")) in SessionStateStoreScript.SUPPORTED_GAME_STATES):
		return false
	if not (String(payload.get("scenario_status", "")) in SessionStateStoreScript.SUPPORTED_SCENARIO_STATUSES):
		return false
	if ContentService.get_scenario_readonly(String(payload.get("scenario_id", ""))).is_empty():
		return false
	if not OverworldRulesScript.is_runtime_session_normalized(session):
		return false
	var resume_target := _resume_target_for_session(session)
	match resume_target:
		"battle":
			return not session.battle.is_empty()
		"town":
			return TownRulesScript.can_visit_active_town_bridge(session)
		"outcome":
			return session.scenario_status != "in_progress"
		_:
			return session.battle.is_empty()

func _runtime_payload_for_save(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null:
		return {}
	# Build one owned snapshot directly. Calling to_dict() and then deep-copying the
	# entire payload again for two top-level flag edits is especially expensive for
	# package-backed Large maps. Preserve every existing save field and schema key.
	var overworld_source := session.overworld.duplicate(false)
	var flags_source := session.flags.duplicate(false)
	return {
		"save_version": session.save_version,
		"session_id": session.session_id,
		"scenario_id": session.scenario_id,
		"hero_id": session.hero_id,
		"day": session.day,
		"difficulty": session.difficulty,
		"launch_mode": session.launch_mode,
		"game_state": session.game_state,
		"scenario_status": session.scenario_status,
		"scenario_summary": session.scenario_summary,
		"overworld": overworld_source.duplicate(true),
		"battle": session.battle.duplicate(true),
		"flags": flags_source.duplicate(true),
	}

func _payload_without_transition_autosave_intent(payload: Dictionary) -> Dictionary:
	# Callers pass an owned save snapshot, so only the branch being modified needs
	# duplication. Deep-copying the entire Large-map payload here doubled save time.
	var cleaned := payload.duplicate(false)
	var flags: Dictionary = cleaned.get("flags", {}).duplicate(true) if cleaned.get("flags", {}) is Dictionary else {}
	if flags.is_empty():
		return cleaned
	for key in TRANSITION_AUTOSAVE_INTENT_FLAGS:
		flags.erase(String(key))
	cleaned["flags"] = flags
	return cleaned

func _owned_payload_from_normalized_detached_session(
	session: SessionStateStoreScript.SessionData
) -> Dictionary:
	if session == null:
		return {}
	return {
		"save_version": session.save_version,
		"session_id": session.session_id,
		"scenario_id": session.scenario_id,
		"hero_id": session.hero_id,
		"day": session.day,
		"difficulty": session.difficulty,
		"launch_mode": session.launch_mode,
		"game_state": session.game_state,
		"scenario_status": session.scenario_status,
		"scenario_summary": session.scenario_summary,
		"overworld": session.overworld,
		"battle": session.battle,
		"flags": session.flags,
	}

func _clear_transition_autosave_intent_from_owned_payload(payload: Dictionary) -> void:
	var flags: Dictionary = payload.get("flags", {}) if payload.get("flags", {}) is Dictionary else {}
	for key in TRANSITION_AUTOSAVE_INTENT_FLAGS:
		flags.erase(String(key))
	payload["flags"] = flags

func _clear_transition_autosave_intent_flags(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	for key in TRANSITION_AUTOSAVE_INTENT_FLAGS:
		session.flags.erase(String(key))

func _can_fast_save_generated_opening_autosave(
	session: SessionStateStoreScript.SessionData,
	slot_type: String,
	include_summary: bool
) -> bool:
	return (
		_is_generated_opening_autosave_pending(session)
		and slot_type == SLOT_TYPE_AUTOSAVE
		and not include_summary
	)

func _is_generated_opening_autosave_pending(session: SessionStateStoreScript.SessionData) -> bool:
	return (
		session != null
		and bool(session.flags.get("generated_random_map", false))
		and bool(session.flags.get(GENERATED_OPENING_AUTOSAVE_PENDING_FLAG, false))
	)

func _save_generated_opening_autosave_fast(
	session: SessionStateStoreScript.SessionData,
	profile: Dictionary
) -> Dictionary:
	_runtime_save_profile_step(profile, "generated_opening_payload_start")
	var payload_started := ProfileLogScript.begin_usec()
	var payload := _generated_opening_autosave_success_payload(session)
	_runtime_save_profile_bucket(profile, "to_dict", ProfileLogScript.elapsed_ms(payload_started))
	_runtime_save_profile_step(profile, "generated_opening_payload_done")
	_runtime_save_profile_step(profile, "write_payload_start")
	var saved_payload := {}
	var forced_failure := OS.get_environment(GENERATED_OPENING_AUTOSAVE_FORCE_FAILURE_ENV) == "1"
	var path := "" if forced_failure else _save_payload(payload, _autosave_path(), SLOT_TYPE_AUTOSAVE, saved_payload, profile)
	_runtime_save_profile_step(profile, "write_payload_done")
	if path == "":
		_runtime_save_profile_finish(profile)
		return {"ok": false, "path": "", "summary": {}, "message": "Save write failed."}
	_apply_generated_opening_autosave_success_to_session(session)
	if FileAccess.file_exists(path):
		profile["written_bytes"] = FileAccess.get_size(path)
		profile["path"] = path
	_runtime_save_profile_step(profile, "summary_cache_deferred")
	_runtime_save_profile_finish(profile)
	return {
		"ok": true,
		"path": path,
		"summary": {},
		"message": "Autosave updated.",
	}

func _generated_opening_autosave_success_payload(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return _generated_opening_autosave_success_payload_from_payload(session.to_dict())

func _generated_opening_autosave_success_payload_from_payload(payload: Dictionary) -> Dictionary:
	var canonical_payload := _payload_without_transition_autosave_intent(payload)
	var flags: Dictionary = canonical_payload.get("flags", {}) if canonical_payload.get("flags", {}) is Dictionary else {}
	flags.erase(GENERATED_OPENING_AUTOSAVE_PENDING_FLAG)
	flags.erase(GENERATED_OPENING_AUTOSAVE_BRIEFING_DEFERRED_FLAG)
	flags[GENERATED_OPENING_AUTOSAVE_COMPLETED_FLAG] = true
	canonical_payload["flags"] = flags
	return canonical_payload

func _apply_generated_opening_autosave_success_to_owned_payload(payload: Dictionary) -> void:
	_clear_transition_autosave_intent_from_owned_payload(payload)
	var flags: Dictionary = payload.get("flags", {}) if payload.get("flags", {}) is Dictionary else {}
	flags.erase(GENERATED_OPENING_AUTOSAVE_PENDING_FLAG)
	flags.erase(GENERATED_OPENING_AUTOSAVE_BRIEFING_DEFERRED_FLAG)
	flags[GENERATED_OPENING_AUTOSAVE_COMPLETED_FLAG] = true
	payload["flags"] = flags

func _apply_generated_opening_autosave_success_to_session(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	_clear_transition_autosave_intent_flags(session)
	session.flags.erase(GENERATED_OPENING_AUTOSAVE_PENDING_FLAG)
	session.flags.erase(GENERATED_OPENING_AUTOSAVE_BRIEFING_DEFERRED_FLAG)
	session.flags[GENERATED_OPENING_AUTOSAVE_COMPLETED_FLAG] = true

func _runtime_save_profile_step(profile: Dictionary, step_name: String) -> void:
	if profile.is_empty():
		return
	var started := int(profile.get("started_msec", Time.get_ticks_msec()))
	var elapsed: int = max(0, Time.get_ticks_msec() - started)
	var steps: Array = profile.get("steps", [])
	var previous_elapsed: int = 0
	if not steps.is_empty():
		var previous: Dictionary = steps[steps.size() - 1] if steps[steps.size() - 1] is Dictionary else {}
		previous_elapsed = int(previous.get("elapsed_ms", 0))
	steps.append({
		"name": step_name,
		"elapsed_ms": elapsed,
		"delta_ms": max(0, elapsed - previous_elapsed),
	})
	profile["steps"] = steps

func _runtime_save_profile_bucket(profile: Dictionary, bucket_name: String, elapsed_ms: float) -> void:
	if profile.is_empty() or bucket_name == "":
		return
	var buckets: Dictionary = profile.get("buckets_ms", {}) if profile.get("buckets_ms", {}) is Dictionary else {}
	buckets[bucket_name] = snapped(float(buckets.get(bucket_name, 0.0)) + maxf(0.0, elapsed_ms), 0.001)
	profile["buckets_ms"] = buckets

func _runtime_save_profile_finish(profile: Dictionary) -> void:
	_runtime_save_profile_step(profile, "finished")
	profile["total_ms"] = max(0, Time.get_ticks_msec() - int(profile.get("started_msec", Time.get_ticks_msec())))
	_last_runtime_save_profile = profile.duplicate(true)
	ProfileLogScript.emit_general(
		"save",
		String(profile.get("slot_type", "runtime")),
		"runtime_save",
		float(profile.get("total_ms", 0)),
		profile.get("buckets_ms", {}) if profile.get("buckets_ms", {}) is Dictionary else {},
		{
			"slot_type": String(profile.get("slot_type", "")),
			"include_summary": bool(profile.get("include_summary", false)),
			"path": String(profile.get("path", "")),
			"written_bytes": int(profile.get("written_bytes", 0)),
			"generated_random_map": bool(profile.get("generated_random_map", false)),
			"restore_normalize_skipped": bool(profile.get("restore_normalize_skipped", false)),
			"restore_normalize_skip_reason": String(profile.get("restore_normalize_skip_reason", "")),
			"session": profile.get("session_metadata", {}),
			"steps": profile.get("steps", []),
		},
		null
	)

func _save_raw_dictionary(
	payload: Dictionary,
	file_path: String,
	profile: Dictionary = {},
	prepared_recovery: Dictionary = {}
) -> String:
	if not _ensure_save_dir():
		return ""
	var recovery := prepared_recovery
	if recovery.is_empty():
		var recovery_started := ProfileLogScript.begin_usec()
		recovery = _recover_save_transaction(file_path)
		_runtime_save_profile_bucket(profile, "recovery", ProfileLogScript.elapsed_ms(recovery_started))
		if not profile.is_empty():
			profile["recovery_count"] = int(profile.get("recovery_count", 0)) + 1
	elif not profile.is_empty():
		profile["writer_recovery_reused"] = true
	if String(recovery.get("reason", "")) in [
		"invalid_live_remove_failed",
		"backup_restore_failed",
		"backup_restore_verification_failed",
		"future_version",
	]:
		push_error("Save transaction recovery could not establish a safe commit base for %s: %s" % [file_path, recovery])
		return ""

	var stringify_started := ProfileLogScript.begin_usec()
	# Runtime saves are machine-owned. Compact JSON avoids formatting and then
	# parsing/writing several extra megabytes on object-dense generated maps.
	var json_text := JSON.stringify(payload)
	_runtime_save_profile_bucket(profile, "stringify", ProfileLogScript.elapsed_ms(stringify_started))
	var candidate_path := _save_transaction_candidate_path(file_path)
	var backup_path := _save_transaction_backup_path(file_path)
	if not _remove_save_transaction_artifact(candidate_path):
		push_error("Unable to clear stale save candidate: %s" % candidate_path)
		return ""

	var write_started := ProfileLogScript.begin_usec()
	var file := FileAccess.open(candidate_path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to open save candidate for writing: %s" % candidate_path)
		return ""
	file.store_string(json_text)
	file.flush()
	var write_error := file.get_error()
	var written_bytes := file.get_length()
	file.close()
	var expected_bytes := json_text.to_utf8_buffer().size()
	if write_error != OK or written_bytes != expected_bytes:
		push_error("Save candidate write failed for %s (error %d, bytes %d/%d)." % [candidate_path, write_error, written_bytes, expected_bytes])
		_remove_save_transaction_artifact(candidate_path)
		return ""
	var candidate_read := _read_json_dictionary_unrecovered(candidate_path, false)
	if not profile.is_empty():
		profile["verification_parse_count"] = int(profile.get("verification_parse_count", 0)) + 1
	if not bool(candidate_read.get("ok", false)) or String(candidate_read.get("text", "")) != json_text:
		push_error("Save candidate verification failed: %s" % candidate_path)
		_remove_save_transaction_artifact(candidate_path)
		return ""
	if OS.get_environment(SAVE_TRANSACTION_FAILURE_ENV) == "precommit":
		_remove_save_transaction_artifact(candidate_path)
		return ""

	var had_live := FileAccess.file_exists(file_path)
	if FileAccess.file_exists(backup_path) and not _remove_save_transaction_artifact(backup_path):
		push_error("Unable to clear stale save backup: %s" % backup_path)
		_remove_save_transaction_artifact(candidate_path)
		return ""
	if had_live:
		var backup_error := _rename_save_transaction_path(file_path, backup_path)
		if backup_error != OK:
			push_error("Unable to preserve prior save %s (error %d)." % [file_path, backup_error])
			_remove_save_transaction_artifact(candidate_path)
			return ""
	if OS.get_environment(SAVE_TRANSACTION_FAILURE_ENV) == "after_backup":
		_rollback_save_transaction(file_path, candidate_path, backup_path, had_live)
		return ""

	var commit_error := _rename_save_transaction_path(candidate_path, file_path)
	if commit_error != OK:
		push_error("Unable to commit save candidate %s (error %d)." % [candidate_path, commit_error])
		_rollback_save_transaction(file_path, candidate_path, backup_path, had_live)
		return ""
	var committed_read := _read_json_dictionary_unrecovered(file_path, false)
	if not profile.is_empty():
		profile["verification_parse_count"] = int(profile.get("verification_parse_count", 0)) + 1
	if not bool(committed_read.get("ok", false)) or String(committed_read.get("text", "")) != json_text:
		push_error("Committed save verification failed: %s" % file_path)
		_rollback_save_transaction(file_path, candidate_path, backup_path, had_live)
		return ""
	_remove_save_transaction_artifact(backup_path)
	_runtime_save_profile_bucket(profile, "write", ProfileLogScript.elapsed_ms(write_started))
	_invalidate_summary_cache_for_path(file_path)
	return file_path

func _save_transaction_candidate_path(file_path: String) -> String:
	return "%s%s" % [file_path, SAVE_TRANSACTION_CANDIDATE_SUFFIX]

func _save_transaction_backup_path(file_path: String) -> String:
	return "%s%s" % [file_path, SAVE_TRANSACTION_BACKUP_SUFFIX]

func _read_json_dictionary_unrecovered(file_path: String, include_payload: bool = true) -> Dictionary:
	var result := {
		"exists": FileAccess.file_exists(file_path),
		"readable": false,
		"ok": false,
		"text": "",
		"payload": {},
		"error_line": 0,
		"error_message": "",
	}
	if not bool(result.get("exists", false)):
		return result
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		result["error_message"] = "Unable to open file for reading."
		return result
	var text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	result["readable"] = read_error == OK
	result["text"] = text
	if read_error != OK:
		result["error_message"] = "File read failed with error %d." % read_error
		return result
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK:
		result["error_line"] = parser.get_error_line()
		result["error_message"] = parser.get_error_message()
		return result
	if not (parser.data is Dictionary):
		result["error_message"] = "JSON root is not a dictionary."
		return result
	result["ok"] = true
	if include_payload:
		result["payload"] = (parser.data as Dictionary).duplicate(true)
	return result

func _recover_save_transaction(file_path: String) -> Dictionary:
	var candidate_path := _save_transaction_candidate_path(file_path)
	var backup_path := _save_transaction_backup_path(file_path)
	var live := _read_json_dictionary_unrecovered(file_path)
	if file_path == _progression_path() and bool(live.get("ok", false)):
		var live_payload: Dictionary = live.get("payload", {}) if live.get("payload", {}) is Dictionary else {}
		var live_report := _progression_payload_semantic_report(live_payload)
		if String(live_report.get("status", "")) == PROGRESSION_STORAGE_STATUS_FUTURE_VERSION:
			# Future live data wins over every current-version backup. Candidate data
			# is staging only and may never become recovery authority.
			_remove_save_transaction_artifact(candidate_path)
			return {
				"ok": false,
				"recovered": false,
				"live_valid": false,
				"reason": "future_version",
				"version": int(live_report.get("version", -1)),
			}
	if _save_transaction_payload_valid(file_path, live):
		var live_payload: Dictionary = live.get("payload", {}) if live.get("payload", {}) is Dictionary else {}
		_remove_save_transaction_artifact(candidate_path)
		_remove_save_transaction_artifact(backup_path)
		return {
			"ok": true,
			"recovered": false,
			"live_valid": true,
			"retained_manual_name": _manual_slot_name_from_payload(live_payload),
		}

	var backup := _read_json_dictionary_unrecovered(backup_path)
	if _save_transaction_payload_valid(file_path, backup):
		if bool(live.get("exists", false)) and not _remove_save_transaction_artifact(file_path):
			return {
				"ok": false,
				"recovered": false,
				"live_valid": false,
				"reason": "invalid_live_remove_failed",
			}
		var restore_error := _rename_save_transaction_path(backup_path, file_path)
		if restore_error != OK:
			return {
				"ok": false,
				"recovered": false,
				"live_valid": false,
				"reason": "backup_restore_failed",
				"error": restore_error,
			}
		var restored := _read_json_dictionary_unrecovered(file_path)
		if not _save_transaction_payload_valid(file_path, restored) or String(restored.get("text", "")) != String(backup.get("text", "")):
			return {
				"ok": false,
				"recovered": false,
				"live_valid": false,
				"reason": "backup_restore_verification_failed",
			}
		_remove_save_transaction_artifact(candidate_path)
		_invalidate_summary_cache_for_path(file_path)
		return {
			"ok": true,
			"recovered": true,
			"live_valid": true,
			"retained_manual_name": _manual_slot_name_from_payload(
				restored.get("payload", {}) if restored.get("payload", {}) is Dictionary else {}
			),
		}

	# A candidate is never recovery authority. Without a valid backup, retain any
	# malformed live/backup bytes for diagnostics and discard staging only.
	_remove_save_transaction_artifact(candidate_path)
	return {
		"ok": not bool(live.get("exists", false)),
		"recovered": false,
		"live_valid": false,
		"reason": "no_valid_backup" if bool(live.get("exists", false)) else "live_missing",
	}

func _save_transaction_payload_valid(file_path: String, raw: Dictionary) -> bool:
	if not bool(raw.get("ok", false)):
		return false
	var payload_value: Variant = raw.get("payload", {})
	if not (payload_value is Dictionary):
		return false
	var payload: Dictionary = payload_value
	if file_path == _progression_path():
		return String(_progression_payload_semantic_report(payload).get("status", "")) == PROGRESSION_STORAGE_STATUS_CURRENT_VALID
	var slot_type := ""
	if file_path == _autosave_path():
		slot_type = SLOT_TYPE_AUTOSAVE
	else:
		for slot in MANUAL_SLOT_IDS:
			if file_path == _slot_path(int(slot)):
				slot_type = SLOT_TYPE_MANUAL
				break
	if slot_type == "":
		return false
	var recorded_slot_type := String(payload.get(SAVE_METADATA_SLOT_TYPE_KEY, ""))
	if recorded_slot_type != "" and recorded_slot_type != slot_type:
		return false
	return bool(_payload_structure_report(payload, slot_type).get("ok", false))

func _progression_payload_semantic_report(payload: Dictionary) -> Dictionary:
	var expected_version := int(CampaignRulesScript.PROFILE_VERSION)
	if not payload.has("version"):
		return {
			"status": PROGRESSION_STORAGE_STATUS_INVALID,
			"reason": "missing_version",
			"version": -1,
			"expected_version": expected_version,
		}
	var version_value: Variant = payload.get("version")
	if not (version_value is int or version_value is float):
		return {
			"status": PROGRESSION_STORAGE_STATUS_INVALID,
			"reason": "version_wrong_type",
			"version": -1,
			"expected_version": expected_version,
		}
	var version_number := float(version_value)
	var version := int(version_number)
	if version_number != float(version):
		return {
			"status": PROGRESSION_STORAGE_STATUS_INVALID,
			"reason": "version_not_integer",
			"version": -1,
			"expected_version": expected_version,
		}
	if version > expected_version:
		return {
			"status": PROGRESSION_STORAGE_STATUS_FUTURE_VERSION,
			"reason": "future_version",
			"version": version,
			"expected_version": expected_version,
		}
	if version != expected_version:
		return {
			"status": PROGRESSION_STORAGE_STATUS_INVALID,
			"reason": "unsupported_version",
			"version": version,
			"expected_version": expected_version,
		}
	for string_key in ["last_campaign_id", "last_scenario_id"]:
		if not payload.has(string_key):
			return {
				"status": PROGRESSION_STORAGE_STATUS_INVALID,
				"reason": "missing_%s" % string_key,
				"version": version,
				"expected_version": expected_version,
			}
		if not (payload.get(string_key) is String):
			return {
				"status": PROGRESSION_STORAGE_STATUS_INVALID,
				"reason": "%s_wrong_type" % string_key,
				"version": version,
				"expected_version": expected_version,
			}
	if not payload.has("campaign_states"):
		return {
			"status": PROGRESSION_STORAGE_STATUS_INVALID,
			"reason": "missing_campaign_states",
			"version": version,
			"expected_version": expected_version,
		}
	if not (payload.get("campaign_states") is Dictionary):
		return {
			"status": PROGRESSION_STORAGE_STATUS_INVALID,
			"reason": "campaign_states_wrong_type",
			"version": version,
			"expected_version": expected_version,
		}
	var campaign_states: Dictionary = payload.get("campaign_states", {})
	for campaign_id_value in campaign_states.keys():
		var campaign_id := String(campaign_id_value)
		var state_value: Variant = campaign_states.get(campaign_id_value)
		if not (state_value is Dictionary):
			return {
				"status": PROGRESSION_STORAGE_STATUS_INVALID,
				"reason": "campaign_state_wrong_type",
				"campaign_id": campaign_id,
				"version": version,
				"expected_version": expected_version,
			}
		var state: Dictionary = state_value
		for state_id_key in ["last_selected_scenario_id", "last_completed_scenario_id"]:
			if state.has(state_id_key) and not (state.get(state_id_key) is String):
				return {
					"status": PROGRESSION_STORAGE_STATUS_INVALID,
					"reason": "%s_wrong_type" % state_id_key,
					"campaign_id": campaign_id,
					"version": version,
					"expected_version": expected_version,
				}
		for collection_key in ["scenario_records", "carryover_bundles"]:
			if not state.has(collection_key):
				continue
			if not (state.get(collection_key) is Dictionary):
				return {
					"status": PROGRESSION_STORAGE_STATUS_INVALID,
					"reason": "%s_wrong_type" % collection_key,
					"campaign_id": campaign_id,
					"version": version,
					"expected_version": expected_version,
				}
			var collection: Dictionary = state.get(collection_key, {})
			for entry_id in collection.keys():
				if not (collection.get(entry_id) is Dictionary):
					return {
						"status": PROGRESSION_STORAGE_STATUS_INVALID,
						"reason": "%s_entry_wrong_type" % collection_key,
						"campaign_id": campaign_id,
						"entry_id": String(entry_id),
						"version": version,
						"expected_version": expected_version,
					}
	return {
		"status": PROGRESSION_STORAGE_STATUS_CURRENT_VALID,
		"reason": "current_valid",
		"version": version,
		"expected_version": expected_version,
	}

func _progression_storage_result(
	status: String,
	path: String,
	raw: Dictionary,
	semantic_report: Dictionary,
	recovery: Dictionary
) -> Dictionary:
	var normalized_status := status
	if normalized_status not in [
		PROGRESSION_STORAGE_STATUS_MISSING,
		PROGRESSION_STORAGE_STATUS_CURRENT_VALID,
		PROGRESSION_STORAGE_STATUS_RECOVERED,
		PROGRESSION_STORAGE_STATUS_INVALID,
		PROGRESSION_STORAGE_STATUS_FUTURE_VERSION,
	]:
		normalized_status = PROGRESSION_STORAGE_STATUS_INVALID
	var accepted := normalized_status in [
		PROGRESSION_STORAGE_STATUS_MISSING,
		PROGRESSION_STORAGE_STATUS_CURRENT_VALID,
		PROGRESSION_STORAGE_STATUS_RECOVERED,
	]
	var usable := normalized_status in [
		PROGRESSION_STORAGE_STATUS_CURRENT_VALID,
		PROGRESSION_STORAGE_STATUS_RECOVERED,
	]
	var message := "Campaign progress is unreadable or incomplete. Existing data was preserved and cannot be overwritten."
	match normalized_status:
		PROGRESSION_STORAGE_STATUS_MISSING:
			message = "No campaign progress file exists yet."
		PROGRESSION_STORAGE_STATUS_CURRENT_VALID:
			message = "Campaign progress storage is current and valid."
		PROGRESSION_STORAGE_STATUS_RECOVERED:
			message = "Campaign progress was recovered from the last valid backup."
		PROGRESSION_STORAGE_STATUS_FUTURE_VERSION:
			message = "Campaign progress was written by a newer game version. Existing data was preserved and cannot be overwritten."
	return {
		"ok": accepted,
		"status": normalized_status,
		"path": path,
		"exists": bool(raw.get("exists", false)),
		"usable": usable,
		"writable": accepted,
		"recovered": normalized_status == PROGRESSION_STORAGE_STATUS_RECOVERED,
		"version": int(semantic_report.get("version", -1)),
		"expected_version": int(CampaignRulesScript.PROFILE_VERSION),
		"reason": String(semantic_report.get("reason", normalized_status)),
		"recovery_reason": String(recovery.get("reason", "")),
		"message": message,
	}

func _rollback_save_transaction(
	file_path: String,
	candidate_path: String,
	backup_path: String,
	had_live: bool
) -> bool:
	var rolled_back := true
	if FileAccess.file_exists(file_path):
		rolled_back = _remove_save_transaction_artifact(file_path) and rolled_back
	if had_live and FileAccess.file_exists(backup_path):
		var restore_error := _rename_save_transaction_path(backup_path, file_path)
		rolled_back = restore_error == OK and rolled_back
	elif not had_live:
		_remove_save_transaction_artifact(backup_path)
	_remove_save_transaction_artifact(candidate_path)
	return rolled_back

func _remove_save_transaction_artifact(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path)) == OK

func _rename_save_transaction_path(from_path: String, to_path: String) -> int:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(from_path),
		ProjectSettings.globalize_path(to_path)
	)

func _load_raw_dictionary(file_path: String, warn_if_missing: bool) -> Dictionary:
	_recover_save_transaction(file_path)
	var raw := _read_json_dictionary_unrecovered(file_path)
	if not bool(raw.get("exists", false)):
		if warn_if_missing:
			push_warning("Missing save file: %s" % file_path)
		return {}
	if not bool(raw.get("readable", false)):
		push_error("Unable to read save file: %s" % file_path)
		return {}
	if not bool(raw.get("ok", false)):
		push_error(
			"Invalid save JSON in %s at line %d: %s"
			% [file_path, int(raw.get("error_line", 0)), String(raw.get("error_message", "Invalid JSON dictionary."))]
		)
		return {}
	return (raw.get("payload", {}) as Dictionary).duplicate(true)

func _inspect_slot(slot_type: String, slot_id: String, file_path: String) -> Dictionary:
	_trace_summary_inspection("slot_file_inspections")
	var transaction_artifacts_present := (
		FileAccess.file_exists(_save_transaction_candidate_path(file_path))
		or FileAccess.file_exists(_save_transaction_backup_path(file_path))
	)
	if transaction_artifacts_present:
		_recover_save_transaction(file_path)
	var cached_summary := _cached_slot_summary(slot_type, slot_id, file_path)
	if not cached_summary.is_empty():
		return cached_summary
	if not transaction_artifacts_present:
		_recover_save_transaction(file_path)

	var summary := _empty_summary(slot_type, slot_id, file_path)
	if not FileAccess.file_exists(file_path):
		return _finalize_and_cache_summary(summary)

	summary["modified_timestamp"] = FileAccess.get_modified_time(file_path)
	summary["payload_bytes"] = FileAccess.get_size(file_path)
	var raw_payload := _load_raw_dictionary(file_path, false)
	if raw_payload.is_empty():
		summary["validity"] = "corrupt_json"
		summary["status_text"] = "Corrupt or unreadable save data."
		return _finalize_and_cache_summary(summary)

	summary = _populate_summary_from_payload(summary, raw_payload)
	var structure_report := _payload_structure_report(raw_payload, slot_type)
	if not bool(structure_report.get("ok", false)):
		summary["validity"] = String(structure_report.get("validity", "invalid_payload"))
		summary["status_text"] = String(structure_report.get("message", "Save cannot be restored."))
		summary["warnings"] = structure_report.get("warnings", [])
		summary["resume_target"] = "blocked"
		summary["loadable"] = false
		return _finalize_and_cache_summary(summary)

	summary["valid"] = true
	summary["validity"] = String(structure_report.get("validity", "ok"))
	summary["warnings"] = structure_report.get("warnings", [])
	summary["resume_target"] = _resume_target_from_payload_summary(raw_payload)
	summary["loadable"] = summary["resume_target"] != "blocked"
	if int(summary.get("payload_bytes", 0)) <= SUMMARY_INLINE_PAYLOAD_MAX_BYTES:
		summary["payload"] = raw_payload
		summary["payload_deferred"] = false
	else:
		summary["payload"] = {}
		summary["payload_deferred"] = true
	summary["valid"] = true
	summary["status_text"] = _status_text_for_summary(summary)
	return _finalize_and_cache_summary(summary)

func _normalize_restore_result(payload: Dictionary, slot_type: String = "") -> Dictionary:
	var source_save_version: int = max(0, int(payload.get("save_version", SessionStateStoreScript.SAVE_VERSION)))
	if source_save_version > SessionStateStoreScript.SAVE_VERSION:
		return {
			"ok": false,
			"validity": "newer_version",
			"message": "Written by a newer save version.",
			"warnings": [],
		}

	var structure_report := _payload_structure_report(payload, slot_type)
	if not bool(structure_report.get("ok", false)):
		return structure_report

	var normalized: Dictionary = SessionStateStoreScript.normalize_payload(payload)
	var scenario_id := String(normalized.get("scenario_id", ""))
	if scenario_id == "":
		return {
			"ok": false,
			"validity": "invalid_payload",
			"message": "Missing scenario id.",
			"warnings": [],
		}

	var warnings = structure_report.get("warnings", [])
	if not (warnings is Array):
		warnings = []
	var generated_registration := _ensure_generated_random_map_scenario_registered(normalized)
	if bool(generated_registration.get("registered", false)):
		warnings.append(String(generated_registration.get("message", "Generated random-map scenario was restored from saved provenance.")))
	elif generated_registration.has("ok") and not bool(generated_registration.get("ok", false)):
		warnings.append(String(generated_registration.get("message", "Generated random-map provenance could not be restored.")))

	var scenario := ContentService.get_scenario_readonly(scenario_id)
	if scenario.is_empty():
		return {
			"ok": false,
			"validity": "missing_scenario",
			"message": "Scenario content is unavailable in this build.",
			"warnings": [],
		}

	var session: SessionStateStoreScript.SessionData = _session_from_owned_detached_payload(normalized)
	if session == null:
		return {
			"ok": false,
			"validity": "invalid_payload",
			"message": "Session payload could not be normalized.",
			"warnings": [],
		}

	OverworldRulesScript.normalize_overworld_state_bridge(session)

	var validity := String(structure_report.get("validity", "ok"))
	if source_save_version < SessionStateStoreScript.SAVE_VERSION:
		if validity == "ok":
			validity = "legacy"
		else:
			validity = _degraded_validity(validity)
		warnings.append("Normalized legacy save version %d." % source_save_version)

	var requested_resume_target := _resume_target_for_session(session)
	match requested_resume_target:
		"battle":
			if session.battle.is_empty():
				session.game_state = "overworld"
				validity = _degraded_validity(validity)
				warnings.append("Battle payload was missing and the session was returned to the overworld.")
			elif not BattleRulesScript.normalize_battle_state_bridge(session):
				session.battle = {}
				session.game_state = "overworld"
				validity = _degraded_validity(validity)
				warnings.append("Battle payload could not be restored and the session was returned to the overworld.")
		"town":
			if not session.battle.is_empty():
				session.battle = {}
				validity = _degraded_validity(validity)
				warnings.append("Stale battle payload was ignored because its overworld anchors were already resolved.")
			if not TownRulesScript.can_visit_active_town_bridge(session):
				session.game_state = "overworld"
				validity = _degraded_validity(validity)
				warnings.append("Town visit state was invalid and the session was returned to the overworld.")
		"outcome":
			if not session.battle.is_empty():
				session.battle = {}
				validity = _degraded_validity(validity)
				warnings.append("Stale battle payload was ignored because the scenario is already resolved.")
			session.game_state = "outcome"
		_:
			if not session.battle.is_empty():
				session.battle = {}
				validity = _degraded_validity(validity)
				warnings.append("Stale battle payload was ignored because its overworld anchors were already resolved.")
			session.game_state = "overworld"

	var resume_target := _resume_target_for_session(session)
	match resume_target:
		"battle":
			session.game_state = "battle"
		"town":
			session.game_state = "town"
		"outcome":
			session.game_state = "outcome"
		_:
			if session.scenario_status == "in_progress":
				session.game_state = "overworld"

	return {
		"ok": true,
		"validity": validity,
		"warnings": warnings,
		"session": session,
		"resume_target": resume_target,
		"owned_payload_transfer": true,
	}

func _ensure_generated_random_map_scenario_registered(normalized_payload: Dictionary) -> Dictionary:
	var scenario_id := String(normalized_payload.get("scenario_id", ""))
	if scenario_id == "" or not ContentService.get_scenario_readonly(scenario_id).is_empty():
		return {"ok": true, "registered": false}
	if String(normalized_payload.get("launch_mode", "")) != SessionStateStoreScript.LAUNCH_MODE_SKIRMISH:
		return {}
	var flags = normalized_payload.get("flags", {})
	if not (flags is Dictionary) or not bool(flags.get("generated_random_map", false)):
		return {}
	var provenance: Dictionary = flags.get("generated_random_map_provenance", {}) if flags.get("generated_random_map_provenance", {}) is Dictionary else {}
	if provenance.is_empty():
		var setup: Dictionary = flags.get("generated_random_map_setup", {}) if flags.get("generated_random_map_setup", {}) is Dictionary else {}
		provenance = setup.get("provenance", {}) if setup.get("provenance", {}) is Dictionary else {}
	if String(provenance.get("schema_id", "")) == "aurelion_native_rmg_disk_package_provenance_v1":
		return _register_native_generated_random_map_scenario_from_payload(normalized_payload, provenance)
	var config: Dictionary = provenance.get("generator_config", {}) if provenance.get("generator_config", {}) is Dictionary else {}
	if config.is_empty():
		return {"ok": false, "registered": false, "message": "Generated random-map save is missing regeneration config provenance."}

	var generated: Dictionary = RandomMapGeneratorRulesScript.generate(config)
	if not bool(generated.get("ok", false)):
		return {"ok": false, "registered": false, "message": "Generated random-map save regeneration failed validation."}
	var payload: Dictionary = generated.get("generated_map", {}) if generated.get("generated_map", {}) is Dictionary else {}
	var scenario: Dictionary = payload.get("scenario_record", {}) if payload.get("scenario_record", {}) is Dictionary else {}
	if String(scenario.get("id", "")) != scenario_id:
		return {
			"ok": false,
			"registered": false,
			"message": "Generated random-map save regenerated scenario id %s but expected %s." % [String(scenario.get("id", "")), scenario_id],
		}

	var identity: Dictionary = provenance.get("generated_identity", {}) if provenance.get("generated_identity", {}) is Dictionary else {}
	var expected_signature := String(identity.get("stable_signature", ""))
	if expected_signature != "" and String(payload.get("stable_signature", "")) != expected_signature:
		return {"ok": false, "registered": false, "message": "Generated random-map save identity signature no longer matches saved provenance."}
	var expected_materialized_signature := String(identity.get("materialized_map_signature", ""))
	var materialization: Dictionary = payload.get("runtime_materialization", {}) if payload.get("runtime_materialization", {}) is Dictionary else {}
	if expected_materialized_signature != "" and String(materialization.get("materialized_map_signature", "")) != expected_materialized_signature:
		return {"ok": false, "registered": false, "message": "Generated random-map save materialized-map signature no longer matches saved provenance."}
	var expected_export_signature := String(identity.get("generated_export_signature", ""))
	var generated_export: Dictionary = payload.get("generated_export", {}) if payload.get("generated_export", {}) is Dictionary else {}
	if expected_export_signature != "" and String(generated_export.get("round_trip_signature", "")) != expected_export_signature:
		return {"ok": false, "registered": false, "message": "Generated random-map save export signature no longer matches saved provenance."}
	var export_contract: Dictionary = provenance.get("generated_export", {}) if provenance.get("generated_export", {}) is Dictionary else {}
	if not export_contract.is_empty():
		if String(export_contract.get("tile_stream_signature", "")) != "" and String(generated_export.get("tile_stream_signature", "")) != String(export_contract.get("tile_stream_signature", "")):
			return {"ok": false, "registered": false, "message": "Generated random-map save tile stream signature no longer matches saved provenance."}
		if String(export_contract.get("object_writeout_signature", "")) != "" and String(generated_export.get("object_writeout_signature", "")) != String(export_contract.get("object_writeout_signature", "")):
			return {"ok": false, "registered": false, "message": "Generated random-map save object writeout signature no longer matches saved provenance."}

	var registration: Dictionary = ContentService.register_generated_scenario_draft(
		scenario,
		payload.get("terrain_layers_record", {}) if payload.get("terrain_layers_record", {}) is Dictionary else {}
	)
	if not bool(registration.get("ok", false)):
		return {
			"ok": false,
			"registered": false,
			"message": "Generated random-map save could not register regenerated scenario: %s" % String(registration.get("message", "")),
		}
	return {
		"ok": true,
		"registered": true,
		"message": "Generated random-map scenario restored from saved seed/config provenance.",
	}

func _register_native_generated_random_map_scenario_from_payload(normalized_payload: Dictionary, provenance: Dictionary) -> Dictionary:
	var scenario_id := String(normalized_payload.get("scenario_id", ""))
	if scenario_id == "":
		return {"ok": false, "registered": false, "message": "Native generated random-map save is missing a scenario id."}
	if not ContentService.get_scenario_readonly(scenario_id).is_empty():
		return {"ok": true, "registered": false}
	var overworld: Dictionary = normalized_payload.get("overworld", {}) if normalized_payload.get("overworld", {}) is Dictionary else {}
	var map_size: Dictionary = overworld.get("map_size", {}) if overworld.get("map_size", {}) is Dictionary else {}
	var terrain_layers: Dictionary = overworld.get("terrain_layers", {}) if overworld.get("terrain_layers", {}) is Dictionary else {}
	var generated_identity: Dictionary = provenance.get("generated_identity", {}) if provenance.get("generated_identity", {}) is Dictionary else {}
	var normalized_config: Dictionary = provenance.get("normalized_config", {}) if provenance.get("normalized_config", {}) is Dictionary else {}
	var scenario_ref: Dictionary = provenance.get("scenario_ref", {}) if provenance.get("scenario_ref", {}) is Dictionary else {}
	var start := _native_generated_restore_start(overworld)
	var scenario_record := {
		"id": scenario_id,
		"name": String(scenario_ref.get("name", scenario_id)),
		"generated": true,
		"source": "native_rmg_disk_package_save_restore",
		"selection": {"availability": {"campaign": false, "skirmish": false}},
		"map_size": map_size,
		"map": overworld.get("map", []) if overworld.get("map", []) is Array else [],
		"player_faction_id": _native_generated_restore_player_faction(overworld),
		"starting_hero_id": String(normalized_payload.get("hero_id", "hero_lyra")),
		"starting_position": start,
		"towns": overworld.get("towns", []) if overworld.get("towns", []) is Array else [],
		"resource_nodes": overworld.get("resource_nodes", []) if overworld.get("resource_nodes", []) is Array else [],
		"encounters": overworld.get("encounters", []) if overworld.get("encounters", []) is Array else [],
		"map_objects": overworld.get("map_objects", []) if overworld.get("map_objects", []) is Array else [],
		"objectives": _native_generated_restore_objectives(overworld),
		"native_generated_package": {
			"schema_id": "aurelion_native_rmg_disk_package_restore_record_v1",
			"template_id": String(generated_identity.get("template_id", normalized_config.get("template_id", ""))),
			"profile_id": String(generated_identity.get("profile_id", normalized_config.get("profile_id", ""))),
			"normalized_seed": String(generated_identity.get("normalized_seed", normalized_config.get("normalized_seed", ""))),
			"map_ref": provenance.get("map_ref", {}) if provenance.get("map_ref", {}) is Dictionary else {},
			"scenario_ref": scenario_ref,
			"boundaries": provenance.get("boundaries", {}) if provenance.get("boundaries", {}) is Dictionary else {},
		},
	}
	var registration: Dictionary = ContentService.register_generated_scenario_draft(scenario_record, terrain_layers)
	if not bool(registration.get("ok", false)):
		return {
			"ok": false,
			"registered": false,
			"message": "Native generated random-map save could not register package-backed scenario: %s" % String(registration.get("message", "")),
	}
	return {
		"ok": true,
		"registered": true,
		"message": "Native generated random-map scenario restored from saved package provenance.",
	}

func _native_generated_restore_objectives(overworld: Dictionary) -> Dictionary:
	var towns: Array = overworld.get("towns", []) if overworld.get("towns", []) is Array else []
	var starting_town_id := ""
	var rival_town_id := ""
	for town_value in towns:
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		var placement_id := String(town.get("placement_id", ""))
		if placement_id == "":
			continue
		var owner := String(town.get("owner", ""))
		if starting_town_id == "" and owner == "player":
			starting_town_id = placement_id
			continue
		if rival_town_id == "" and owner != "player":
			rival_town_id = placement_id
	if rival_town_id == "":
		for town_value in towns:
			if not (town_value is Dictionary):
				continue
			var placement_id := String(town_value.get("placement_id", ""))
			if placement_id != "" and placement_id != starting_town_id:
				rival_town_id = placement_id
				break
	var victory_objectives := []
	var defeat_objectives := []
	if rival_town_id != "":
		victory_objectives.append({
			"id": "generated_capture_rival_town",
			"type": "town_owned_by_player",
			"placement_id": rival_town_id,
			"label": "Claim a generated rival town",
			"generated_support": "ScenarioRules.town_owned_by_player",
		})
	else:
		victory_objectives.append({
			"id": "generated_hold_until_day_14",
			"type": "day_at_least",
			"day": 14,
			"label": "Hold the generated frontier until Day 14",
			"generated_support": "ScenarioRules.day_at_least",
		})
	if starting_town_id != "":
		defeat_objectives.append({
			"id": "generated_primary_town_lost",
			"type": "town_not_owned_by_player",
			"placement_id": starting_town_id,
			"label": "Do not lose the generated starting town",
			"generated_support": "ScenarioRules.town_not_owned_by_player",
		})
	return {
		"victory_text": "Generated objective completed.",
		"defeat_text": "Generated objective failed.",
		"victory": victory_objectives,
		"defeat": defeat_objectives,
	}

func _native_generated_restore_start(overworld: Dictionary) -> Dictionary:
	var position: Dictionary = overworld.get("hero_position", {}) if overworld.get("hero_position", {}) is Dictionary else {}
	if not position.is_empty():
		return {"x": int(position.get("x", 0)), "y": int(position.get("y", 0))}
	var hero: Dictionary = overworld.get("hero", {}) if overworld.get("hero", {}) is Dictionary else {}
	var hero_pos: Dictionary = hero.get("position", {}) if hero.get("position", {}) is Dictionary else {}
	if not hero_pos.is_empty():
		return {"x": int(hero_pos.get("x", 0)), "y": int(hero_pos.get("y", 0))}
	return {"x": 0, "y": 0}

func _native_generated_restore_player_faction(overworld: Dictionary) -> String:
	var hero: Dictionary = overworld.get("hero", {}) if overworld.get("hero", {}) is Dictionary else {}
	var faction_id := String(hero.get("faction_id", ""))
	if faction_id != "":
		return faction_id
	var heroes: Array = overworld.get("player_heroes", []) if overworld.get("player_heroes", []) is Array else []
	for hero_entry in heroes:
		if hero_entry is Dictionary and String(hero_entry.get("faction_id", "")) != "":
			return String(hero_entry.get("faction_id", ""))
	var towns: Array = overworld.get("towns", []) if overworld.get("towns", []) is Array else []
	for town in towns:
		if town is Dictionary and String(town.get("owner", "")) == "player" and String(town.get("faction_id", "")) != "":
			return String(town.get("faction_id", ""))
	return "faction_embercourt"

func _populate_summary_from_payload(summary: Dictionary, payload: Dictionary) -> Dictionary:
	var scenario_id := String(payload.get("scenario_id", ""))
	var scenario := ContentService.get_scenario_readonly(scenario_id)
	var launch_mode := SessionStateStoreScript.normalize_launch_mode(payload.get("launch_mode", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN))
	var campaign_metadata := _campaign_metadata_for_scenario(scenario_id, launch_mode)
	var session_flags = payload.get("flags", {})
	if session_flags is Dictionary and SessionStateStoreScript.normalize_launch_mode(launch_mode) == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
		var flagged_campaign_id := String(session_flags.get("campaign_id", ""))
		if flagged_campaign_id != "":
			campaign_metadata["campaign_id"] = flagged_campaign_id
			if String(campaign_metadata.get("campaign_name", "")) == "":
				var flagged_campaign := ContentService.get_campaign(flagged_campaign_id)
				campaign_metadata["campaign_name"] = String(flagged_campaign.get("name", flagged_campaign_id))
		var flagged_campaign_name := String(session_flags.get("campaign_name", ""))
		if flagged_campaign_name != "":
			campaign_metadata["campaign_name"] = flagged_campaign_name
		var flagged_chapter_label := String(session_flags.get("campaign_chapter_label", ""))
		if flagged_chapter_label != "":
			campaign_metadata["chapter_label"] = flagged_chapter_label
	var hero_id := String(payload.get("hero_id", ""))
	var overworld_state = payload.get("overworld", {})
	var hero_state_value = overworld_state.get("hero", {}) if overworld_state is Dictionary else {}
	var hero_state: Dictionary = hero_state_value if hero_state_value is Dictionary else {}
	var hero_template := ContentService.get_hero(hero_id)

	summary["source_save_version"] = max(0, int(payload.get("save_version", SessionStateStoreScript.SAVE_VERSION)))
	summary["save_version"] = max(0, int(payload.get("save_version", SessionStateStoreScript.SAVE_VERSION)))
	summary["recorded_timestamp_precise"] = _recorded_timestamp_precise_from_payload(payload)
	summary["recorded_timestamp"] = _recorded_timestamp_from_payload(payload, int(summary.get("modified_timestamp", 0)))
	summary["scenario_id"] = scenario_id
	summary["scenario_name"] = String(scenario.get("name", scenario_id))
	summary["scenario_summary"] = String(payload.get("scenario_summary", ""))
	summary["campaign_id"] = String(campaign_metadata.get("campaign_id", ""))
	summary["campaign_name"] = String(campaign_metadata.get("campaign_name", ""))
	summary["chapter_label"] = String(campaign_metadata.get("chapter_label", ""))
	summary["day"] = max(0, int(payload.get("day", 0)))
	summary["hero_id"] = hero_id
	summary["hero_name"] = _hero_name(hero_state, hero_template, hero_id)
	summary["hero_specialties_summary"] = HeroProgressionRulesScript.brief_summary(hero_state)
	summary["difficulty"] = ScenarioSelectRulesScript.normalize_difficulty(payload.get("difficulty", ScenarioSelectRulesScript.default_difficulty_id()))
	summary["launch_mode"] = launch_mode
	summary["scenario_status"] = SessionStateStoreScript._normalize_scenario_status(payload.get("scenario_status", "in_progress"))
	summary["game_state"] = SessionStateStoreScript._normalize_game_state(payload.get("game_state", "overworld"))
	summary["battle_name"] = _battle_name_from_payload(payload)
	summary["resume_location"] = _resume_location_from_payload(payload)
	summary["saved_from_game_state"] = String(payload.get(SAVE_METADATA_GAME_STATE_KEY, summary.get("game_state", "overworld")))
	summary["saved_from_scenario_status"] = String(payload.get(SAVE_METADATA_SCENARIO_STATUS_KEY, summary.get("scenario_status", "in_progress")))
	summary["saved_from_launch_mode"] = String(payload.get(SAVE_METADATA_LAUNCH_MODE_KEY, summary.get("launch_mode", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN)))
	summary["manual_slot_name"] = _manual_slot_name_from_payload(payload) if String(summary.get("slot_type", "")) == SLOT_TYPE_MANUAL else ""
	return summary

func _campaign_metadata_for_scenario(scenario_id: String, launch_mode: String) -> Dictionary:
	var metadata := {
		"campaign_id": "",
		"campaign_name": "",
		"chapter_label": "",
	}
	if scenario_id == "" or SessionStateStoreScript.normalize_launch_mode(launch_mode) != SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
		return metadata

	var campaign_id: String = CampaignRulesScript.get_campaign_id_for_scenario(scenario_id)
	if campaign_id == "":
		return metadata

	var campaign := ContentService.get_campaign(campaign_id)
	metadata["campaign_id"] = campaign_id
	metadata["campaign_name"] = String(campaign.get("name", campaign_id))
	for scenario_entry in campaign.get("scenarios", []):
		if not (scenario_entry is Dictionary):
			continue
		if String(scenario_entry.get("scenario_id", "")) != scenario_id:
			continue
		metadata["chapter_label"] = String(scenario_entry.get("label", ""))
		break
	return metadata

func _hero_name(hero_state: Variant, hero_template: Dictionary, hero_id: String) -> String:
	if hero_state is Dictionary:
		var hero_name := String(hero_state.get("name", ""))
		if hero_name != "":
			return hero_name
	return String(hero_template.get("name", hero_id))

func _battle_name_from_payload(normalized_payload: Dictionary) -> String:
	var battle_state = normalized_payload.get("battle", {})
	if not (battle_state is Dictionary) or battle_state.is_empty():
		return ""
	return String(battle_state.get("encounter_name", battle_state.get("encounter_id", "")))

func _resume_location_from_payload(normalized_payload: Dictionary) -> String:
	if String(normalized_payload.get("scenario_status", "in_progress")) != "in_progress":
		return _humanize_label(String(normalized_payload.get("scenario_status", "outcome")))
	var battle_name := _battle_name_from_payload(normalized_payload)
	if battle_name != "":
		return battle_name
	if String(normalized_payload.get("game_state", "overworld")) == "town":
		var town_name := _active_town_name_from_payload(normalized_payload)
		if town_name != "":
			return town_name
	var hero_pos := _hero_position_from_payload(normalized_payload)
	return "Overworld %d,%d" % [hero_pos.x, hero_pos.y]

func _active_town_name_from_payload(normalized_payload: Dictionary) -> String:
	var overworld_state = normalized_payload.get("overworld", {})
	if not (overworld_state is Dictionary):
		return ""
	var flags = normalized_payload.get("flags", {})
	var active_placement_id := ""
	if flags is Dictionary:
		active_placement_id = String(flags.get("active_town_placement_id", ""))
	var towns = overworld_state.get("towns", [])
	if not (towns is Array):
		return ""
	if active_placement_id != "":
		for town in towns:
			if town is Dictionary and String(town.get("placement_id", "")) == active_placement_id:
				return _town_name_for_summary(town)
	var hero_pos := _hero_position_from_payload(normalized_payload)
	for town in towns:
		if town is Dictionary and int(town.get("x", 0)) == hero_pos.x and int(town.get("y", 0)) == hero_pos.y:
			return _town_name_for_summary(town)
	return ""

func _town_name_for_summary(town: Dictionary) -> String:
	var town_id := String(town.get("town_id", ""))
	var town_template := ContentService.get_town(town_id)
	return String(town_template.get("name", town_id))

func _hero_position_from_payload(normalized_payload: Dictionary) -> Vector2i:
	var overworld_state = normalized_payload.get("overworld", {})
	if not (overworld_state is Dictionary):
		return Vector2i.ZERO
	var position = overworld_state.get("hero_position", {})
	if not (position is Dictionary):
		var hero_state = overworld_state.get("hero", {})
		position = hero_state.get("position", {}) if hero_state is Dictionary else {}
	return Vector2i(int(position.get("x", 0)), int(position.get("y", 0))) if position is Dictionary else Vector2i.ZERO

func _empty_summary(slot_type: String, slot_id: String, file_path: String) -> Dictionary:
	return {
		"slot_type": slot_type,
		"slot_id": slot_id,
		"path": file_path,
		"modified_timestamp": 0,
		"recorded_timestamp": 0,
		"recorded_timestamp_precise": 0.0,
		"source_save_version": 0,
		"save_version": 0,
		"scenario_id": "",
		"scenario_name": "",
		"scenario_summary": "",
		"campaign_id": "",
		"campaign_name": "",
		"chapter_label": "",
		"day": 0,
		"hero_id": "",
		"hero_name": "",
		"battle_name": "",
		"resume_location": "",
		"difficulty": ScenarioSelectRulesScript.default_difficulty_id(),
		"launch_mode": SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN,
		"scenario_status": "in_progress",
		"game_state": "overworld",
		"saved_from_game_state": "overworld",
		"saved_from_scenario_status": "in_progress",
		"saved_from_launch_mode": SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN,
		"manual_slot_name": "",
		"resume_target": "blocked",
		"validity": "missing",
		"valid": false,
		"loadable": false,
		"warnings": [],
		"status_text": "Empty slot.",
		"summary": "",
		"detail": "",
		"payload": {},
		"payload_bytes": 0,
		"payload_deferred": false,
	}

func _finalize_summary(summary: Dictionary) -> Dictionary:
	summary["summary"] = describe_slot(summary)
	summary["detail"] = describe_slot_details(summary)
	return summary

func _finalize_runtime_summary(summary: Dictionary, profile: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = summary.get("payload", {}) if summary.get("payload", {}) is Dictionary else {}
	if bool(summary.get("payload_deferred", false)) or payload.is_empty():
		if not profile.is_empty():
			profile["summary_detail_direct_fallback_count"] = int(profile.get("summary_detail_direct_fallback_count", 0)) + 1
		return _finalize_summary(summary)
	var trusted_session: SessionStateStoreScript.SessionData = _session_from_owned_detached_payload(payload)
	if trusted_session == null or trusted_session.scenario_id == "":
		if not profile.is_empty():
			profile["summary_detail_direct_fallback_count"] = int(profile.get("summary_detail_direct_fallback_count", 0)) + 1
		return _finalize_summary(summary)
	if not profile.is_empty():
		profile["summary_owned_session_materialization_count"] = int(profile.get("summary_owned_session_materialization_count", 0)) + 1
	var context_started := ProfileLogScript.begin_usec()
	OverworldRulesScript.begin_normalized_read_scope(trusted_session)
	TownRulesScript.begin_read_scope(trusted_session)
	var progress_recap: String = load("res://scripts/core/ScenarioRules.gd").describe_session_progress_recap_from_normalized_session(trusted_session, true)
	var progress_without_header := progress_recap.trim_prefix("Progress Recap\n")
	var recap_context := _session_save_recap_context(trusted_session, summary, progress_without_header)
	summary["summary"] = describe_slot(summary)
	summary["detail"] = _describe_slot_details(summary, trusted_session, recap_context, progress_recap)
	TownRulesScript.end_read_scope(trusted_session)
	OverworldRulesScript.end_normalized_read_scope(trusted_session)
	if not profile.is_empty():
		profile["summary_detail_context_build_count"] = int(profile.get("summary_detail_context_build_count", 0)) + 1
		profile["summary_detail_context_reuse_count"] = int(profile.get("summary_detail_context_reuse_count", 0)) + 3
		_runtime_save_profile_bucket(profile, "summary_detail_context", ProfileLogScript.elapsed_ms(context_started))
	return summary

func _finalize_and_cache_summary(summary: Dictionary) -> Dictionary:
	var finalized := _finalize_summary(summary)
	_store_slot_summary_cache(finalized)
	return finalized

func _cached_slot_summary(slot_type: String, slot_id: String, file_path: String) -> Dictionary:
	var key := _summary_cache_key(slot_type, slot_id, file_path)
	if not _slot_summary_cache.has(key):
		return {}
	var cached = _slot_summary_cache.get(key, {})
	if not (cached is Dictionary):
		return {}
	var signature := _slot_file_signature(file_path)
	if bool(cached.get("exists", false)) != bool(signature.get("exists", false)):
		return {}
	if int(cached.get("modified_timestamp", 0)) != int(signature.get("modified_timestamp", 0)):
		return {}
	if int(cached.get("file_size", -1)) != int(signature.get("file_size", -1)):
		return {}
	var summary = cached.get("summary", {})
	return summary.duplicate(true) if summary is Dictionary else {}

func _store_slot_summary_cache(summary: Dictionary) -> void:
	var slot_type := String(summary.get("slot_type", ""))
	var slot_id := String(summary.get("slot_id", ""))
	var file_path := String(summary.get("path", ""))
	if slot_type == "" or slot_id == "" or file_path == "":
		return
	var signature := _slot_file_signature(file_path)
	_slot_summary_cache[_summary_cache_key(slot_type, slot_id, file_path)] = {
		"exists": bool(signature.get("exists", false)),
		"file_path": file_path,
		"modified_timestamp": int(signature.get("modified_timestamp", 0)),
		"file_size": int(signature.get("file_size", -1)),
		"summary": summary.duplicate(true),
	}

func _store_runtime_summary_cache(
	payload: Dictionary,
	slot_type: String,
	slot_id: String,
	file_path: String,
	authoritative_resume_target: String = "",
	profile: Dictionary = {}
) -> void:
	if payload.is_empty() or slot_type == "" or slot_id == "" or file_path == "":
		return
	var summary := _empty_summary(slot_type, slot_id, file_path)
	summary["modified_timestamp"] = FileAccess.get_modified_time(file_path) if FileAccess.file_exists(file_path) else 0
	summary["payload_bytes"] = FileAccess.get_size(file_path) if FileAccess.file_exists(file_path) else 0
	summary = _populate_summary_from_payload(summary, payload)
	if int(summary.get("payload_bytes", 0)) <= SUMMARY_INLINE_PAYLOAD_MAX_BYTES:
		summary["payload"] = payload.duplicate(true)
		summary["payload_deferred"] = false
	else:
		summary["payload"] = {}
		summary["payload_deferred"] = true
	summary["valid"] = true
	summary["validity"] = "ok"
	summary["warnings"] = []
	if authoritative_resume_target != "":
		summary["resume_target"] = authoritative_resume_target
	else:
		var session := _session_from_payload(payload)
		summary["resume_target"] = _resume_target_for_session(session) if session != null else "blocked"
		if not profile.is_empty():
			profile["summary_session_reconstruction_count"] = int(profile.get("summary_session_reconstruction_count", 0)) + 1
	summary["loadable"] = summary["resume_target"] != "blocked"
	summary["status_text"] = _status_text_for_summary(summary)
	_store_slot_summary_cache(_finalize_runtime_summary(summary, profile))

func _invalidate_summary_cache_for_path(file_path: String) -> void:
	if file_path == "":
		return
	for key in _slot_summary_cache.keys().duplicate():
		var cached = _slot_summary_cache.get(key, {})
		if cached is Dictionary and String(cached.get("file_path", "")) == file_path:
			_slot_summary_cache.erase(key)

func _summary_cache_key(slot_type: String, slot_id: String, file_path: String) -> String:
	return "%s|%s|%s" % [slot_type, slot_id, file_path]

func _slot_file_signature(file_path: String) -> Dictionary:
	var exists := FileAccess.file_exists(file_path)
	return {
		"exists": exists,
		"modified_timestamp": FileAccess.get_modified_time(file_path) if exists else 0,
		"file_size": FileAccess.get_size(file_path) if exists else -1,
	}

func _summary_payload(summary: Dictionary) -> Dictionary:
	var payload = summary.get("payload", {})
	return payload.duplicate(true) if payload is Dictionary else {}

func _load_summary_payload_for_restore(summary: Dictionary) -> Dictionary:
	var payload := _summary_payload(summary)
	if not payload.is_empty():
		return payload
	var path := String(summary.get("path", ""))
	if path == "" or not FileAccess.file_exists(path):
		return {}
	return _load_raw_dictionary(path, false)

func _resume_target_from_payload_summary(payload: Dictionary) -> String:
	if String(payload.get("scenario_id", "")) == "":
		return "blocked"
	var scenario_status := SessionStateStoreScript._normalize_scenario_status(payload.get("scenario_status", "in_progress"))
	if scenario_status != "in_progress":
		return "outcome"
	var battle = payload.get("battle", {})
	if battle is Dictionary and not battle.is_empty() and String(payload.get("game_state", "overworld")) == "battle":
		return "battle"
	if String(payload.get("game_state", "overworld")) == "town":
		return "town"
	return "overworld"

func _summary_sort_timestamp(summary: Dictionary) -> float:
	var precise_timestamp := float(summary.get("recorded_timestamp_precise", 0.0))
	if precise_timestamp > 0.0:
		return precise_timestamp
	var recorded_timestamp := int(summary.get("recorded_timestamp", 0))
	return float(recorded_timestamp if recorded_timestamp > 0 else int(summary.get("modified_timestamp", 0)))

func _runtime_session_resume_brief(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.scenario_id == "":
		return ""
	var summary := _empty_summary(SLOT_TYPE_MANUAL, str(_selected_manual_slot), _slot_path(_selected_manual_slot))
	summary = _populate_summary_from_payload(summary, session.to_dict())
	summary["payload"] = session.to_dict()
	summary["valid"] = true
	summary["loadable"] = true
	summary["resume_target"] = _resume_target_for_session(session)
	summary["status_text"] = _status_text_for_summary(summary)
	return describe_resume_brief(summary)

func _manual_summary_for_session(
	session: SessionStateStoreScript.SessionData,
	manual_slot: int = -1
) -> Dictionary:
	if session == null or session.scenario_id == "":
		return {}
	var selected_slot := _normalize_manual_slot(manual_slot if manual_slot > 0 else _selected_manual_slot)
	var summary := _empty_summary(SLOT_TYPE_MANUAL, str(selected_slot), _slot_path(selected_slot))
	summary = _populate_summary_from_payload(summary, session.to_dict())
	summary["payload"] = session.to_dict()
	summary["valid"] = true
	summary["validity"] = "ok"
	summary["loadable"] = true
	summary["resume_target"] = _resume_target_for_session(session)
	summary["status_text"] = _status_text_for_summary(summary)
	return summary

func _session_from_payload(payload: Dictionary) -> SessionStateStoreScript.SessionData:
	if payload.is_empty():
		return null
	var session := SessionStateStoreScript.new_session_data()
	session.from_dict(payload)
	return session

func _summary_progress_recap(summary: Dictionary) -> String:
	if summary.is_empty() or not bool(summary.get("valid", false)):
		return ""
	var session := _session_from_payload(_summary_payload(summary))
	if session == null or session.scenario_id == "":
		return ""
	return load("res://scripts/core/ScenarioRules.gd").describe_session_progress_recap(session, true)

func _summary_continuity_lines(summary: Dictionary) -> Array:
	if summary.is_empty() or not bool(summary.get("valid", false)):
		return []
	var session := _session_from_payload(_summary_payload(summary))
	if session == null or session.scenario_id == "":
		return []

	var lines := []
	var action_line := _summary_resume_action_line(summary)
	if action_line != "":
		lines.append(action_line)
	var context_line := _summary_campaign_context_line(summary)
	if context_line != "":
		lines.append(context_line)
	var objective_line := _summary_objective_line(session)
	if objective_line != "":
		lines.append(objective_line)
	var watch_line := _summary_watch_state_line(session, summary)
	if watch_line != "":
		lines.append(watch_line)
	return lines

func _summary_continuity_lines_from_context(
	summary: Dictionary,
	recap_context: Dictionary
) -> Array:
	if summary.is_empty() or not bool(summary.get("valid", false)) or recap_context.is_empty():
		return []
	var lines := []
	var action_line := _summary_resume_action_line(summary)
	if action_line != "":
		lines.append(action_line)
	var context_line := _summary_campaign_context_line(summary)
	if context_line != "":
		lines.append(context_line)
	var objective_line := _summary_objective_line_from_progress_recap(String(recap_context.get("progress_recap", "")))
	if objective_line != "":
		lines.append(objective_line)
	var watch_line := String(recap_context.get("watch_line", ""))
	if watch_line != "":
		lines.append(watch_line)
	return lines

func _summary_resume_action_line(summary: Dictionary) -> String:
	if not can_load_summary(summary):
		return ""
	var action := load_action_label(summary)
	var target := _resume_context_label(summary)
	match String(summary.get("resume_target", "blocked")):
		"battle":
			return "Action: %s will restore %s before the next tactical order." % [action, target]
		"town":
			return "Action: %s will reopen %s with current build, recruit, and logistics state." % [action, target]
		"outcome":
			return "Action: %s will reopen %s and its follow-up choices." % [action, target]
		"overworld":
			return "Action: %s will restore %s with current movement, map control, and turn state." % [action, target]
		_:
			return ""

func _summary_campaign_context_line(summary: Dictionary) -> String:
	var mode_label := ScenarioSelectRulesScript.launch_mode_label(String(summary.get("launch_mode", SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN)))
	var parts := [mode_label]
	var campaign_name := String(summary.get("campaign_name", "")).strip_edges()
	var chapter_label := String(summary.get("chapter_label", "")).strip_edges()
	if campaign_name != "":
		parts.append(campaign_name)
	if chapter_label != "":
		parts.append(chapter_label)
	var day := int(summary.get("day", 0))
	if day > 0:
		parts.append("Day %d" % day)
	if parts.size() <= 1:
		return ""
	return "Continuity: %s." % " | ".join(parts)

func _summary_objective_line(session: SessionStateStoreScript.SessionData) -> String:
	var recap: String = load("res://scripts/core/ScenarioRules.gd").describe_session_progress_recap(session, false)
	return _summary_objective_line_from_progress_recap(recap)

func _summary_objective_line_from_progress_recap(recap: String) -> String:
	var progress_line := _line_with_prefix(recap, "Current progress:")
	var next_step_line := _line_with_prefix(recap, "Next step:")
	if progress_line == "" and next_step_line == "":
		return ""
	var parts := []
	if progress_line != "":
		parts.append(progress_line.trim_prefix("Current progress:").strip_edges())
	if next_step_line != "":
		parts.append(next_step_line.trim_prefix("Next step:").strip_edges())
	return "Current objective: %s" % " | ".join(parts)

func _summary_play_check_state_line(session: SessionStateStoreScript.SessionData, summary: Dictionary) -> String:
	if session == null or session.scenario_id == "":
		return ""
	match String(summary.get("resume_target", "overworld")):
		"battle":
			var battle_risk: String = BattleRulesScript.describe_risk_readiness_board(session)
			var outlook := _line_with_prefix(battle_risk, "Outlook:")
			if outlook != "":
				return _safe_player_text("Battle: %s" % outlook.trim_prefix("Outlook:").strip_edges(), 72)
		"town":
			var defense_line := _first_meaningful_line(TownRulesScript.describe_defense(session), ["Defense"])
			if defense_line != "":
				return _safe_player_text("Defense: %s" % defense_line.trim_prefix("- ").strip_edges(), 72)
		"outcome":
			var recent_line := _line_with_prefix(
				load("res://scripts/core/ScenarioRules.gd").describe_session_progress_recap(session, false),
				"Recently resolved:"
			)
			if recent_line != "":
				return _safe_player_text(recent_line, 72)
	var objective_line := _summary_objective_line(session).trim_prefix("Current objective:").strip_edges()
	if objective_line != "":
		return _safe_player_text("Objective: %s" % objective_line, 72)
	var watch_line := _summary_watch_state_line(session, summary).trim_prefix("Risk watch:").strip_edges()
	if watch_line != "":
		return _safe_player_text("Watch: %s" % watch_line, 72)
	return ""

func _summary_play_check_state_line_from_context(
	session: SessionStateStoreScript.SessionData,
	summary: Dictionary,
	recap_context: Dictionary
) -> String:
	if session == null or session.scenario_id == "":
		return ""
	var resume_target := String(summary.get("resume_target", "overworld"))
	var progress_recap := String(recap_context.get("progress_recap", ""))
	var watch_line := String(recap_context.get("watch_line", ""))
	match resume_target:
		"battle":
			var battle_watch := watch_line.trim_prefix("Risk watch:").strip_edges()
			if battle_watch != "" and not watch_line.contains("No immediate stored warning"):
				return _safe_player_text("Battle: %s" % battle_watch, 72)
		"town":
			var defense_line := _first_meaningful_line(TownRulesScript.describe_defense_headline(session), ["Defense"])
			if defense_line != "":
				return _safe_player_text("Defense: %s" % defense_line.trim_prefix("- ").strip_edges(), 72)
		"outcome":
			var recent_line := _line_with_prefix(progress_recap, "Recently resolved:")
			if recent_line != "":
				return _safe_player_text(recent_line, 72)
	var objective_line := _summary_objective_line_from_progress_recap(progress_recap).trim_prefix("Current objective:").strip_edges()
	if objective_line != "":
		return _safe_player_text("Objective: %s" % objective_line, 72)
	if resume_target in ["battle", "outcome"]:
		recap_context["direct_fallback_count"] = 1
		return _summary_play_check_state_line(session, summary)
	var watch := watch_line.trim_prefix("Risk watch:").strip_edges()
	if watch != "":
		return _safe_player_text("Watch: %s" % watch, 72)
	return ""

func _summary_watch_state_line(
	session: SessionStateStoreScript.SessionData,
	summary: Dictionary,
	trusted_normalized_session: bool = false,
	preloaded_progress_recap: String = "",
	refresh_watch_context: Dictionary = {}
) -> String:
	match String(summary.get("resume_target", "overworld")):
		"battle":
			var battle_risk: String = BattleRulesScript.describe_risk_readiness_board(session)
			var outlook := _line_with_prefix(battle_risk, "Outlook:")
			if outlook != "":
				return "Risk watch: %s" % outlook.trim_prefix("Outlook:").strip_edges()
		"outcome":
			var recent_line := _line_with_prefix(
				preloaded_progress_recap if preloaded_progress_recap != "" else load("res://scripts/core/ScenarioRules.gd").describe_session_progress_recap(session, false),
				"Recently resolved:"
			)
			if recent_line != "":
				return "Risk watch: %s" % recent_line.trim_prefix("Recently resolved:").strip_edges()
		_:
			var risk_line := ""
			var preloaded_forecast: Dictionary = refresh_watch_context.get("command_risk_forecast", {}) if refresh_watch_context.get("command_risk_forecast", {}) is Dictionary else {}
			if not preloaded_forecast.is_empty():
				if bool(preloaded_forecast.get("has_risk", false)):
					risk_line = String(preloaded_forecast.get("summary", ""))
			elif trusted_normalized_session:
				risk_line = OverworldRulesScript.describe_command_risk_summary_from_normalized_session(session)
			else:
				risk_line = _first_meaningful_line(
					OverworldRulesScript.describe_command_risk(session),
					["Command Risk"]
				)
			if risk_line != "" and not risk_line.begins_with("Steady watch"):
				return "Risk watch: %s" % risk_line
			var frontier_watch: String = OverworldRulesScript.describe_frontier_threats(session)
			var frontier_line := _first_meaningful_line(frontier_watch, ["Frontier Watch"])
			if frontier_line != "" and not frontier_line.contains("No hostile factions are active"):
				return "Risk watch: %s" % frontier_line.trim_prefix("- ").strip_edges()
			var management_watch := (
				String(refresh_watch_context.get("management_watch", ""))
				if refresh_watch_context.has("management_watch")
				else OverworldRulesScript.describe_management_watch(session)
			)
			if management_watch != "" and management_watch != "Town lines are stable.":
				return "Risk watch: %s" % management_watch
	return "Risk watch: No immediate stored warning; review the resumed scene before ending the turn."

func _session_save_resume_recap(session: SessionStateStoreScript.SessionData, summary: Dictionary) -> String:
	var lines := []
	lines.append("Saved state: %s" % describe_resume_brief(summary))
	var next_play_action := describe_summary_next_play_action(summary)
	if next_play_action != "":
		lines.append(next_play_action)
	var resume_handoff := describe_summary_resume_handoff(summary)
	if resume_handoff != "":
		lines.append(resume_handoff)
	var changed_line := _session_changed_recap_line(session, summary)
	if changed_line != "":
		lines.append("What changed: %s" % changed_line)
	lines.append("Resume state: %s | %s" % [
		_resume_context_label(summary),
		_humanize_label(String(summary.get("game_state", "overworld"))),
	])
	var watch_line := _summary_watch_state_line(session, summary)
	if watch_line != "":
		lines.append("Watch: %s" % watch_line.trim_prefix("Risk watch:").strip_edges())
	var next_line := _session_next_decision_line(session, summary)
	if next_line != "":
		lines.append("Next decision: %s" % next_line)
	return "\n".join(lines)

func _session_changed_recap_line(session: SessionStateStoreScript.SessionData, summary: Dictionary) -> String:
	var resume_target := String(summary.get("resume_target", "overworld"))
	var recap := _preferred_recent_action_recap(session, resume_target)
	var recap_summary := _action_recap_change_summary(recap)
	if recap_summary != "":
		return recap_summary
	var battle_summary := _battle_aftermath_summary(session) if resume_target == "battle" else ""
	if battle_summary != "":
		return battle_summary
	var progress_recent := _line_with_prefix(
		load("res://scripts/core/ScenarioRules.gd").describe_session_progress_recap(session, false),
		"Recently resolved:"
	)
	if progress_recent != "":
		return _safe_player_text(progress_recent.trim_prefix("Recently resolved:").strip_edges(), 220)
	var scenario_summary := String(summary.get("scenario_summary", "")).strip_edges()
	if scenario_summary != "":
		return _safe_player_text(scenario_summary, 220)
	return "No recent action recap is stored; resume to make the next scene order."

func _session_next_decision_line(session: SessionStateStoreScript.SessionData, summary: Dictionary) -> String:
	var recap := _preferred_recent_action_recap(session, String(summary.get("resume_target", "overworld")))
	var recap_next := _action_recap_next_step(recap)
	if recap_next != "":
		return recap_next
	var progress_next := _line_with_prefix(
		load("res://scripts/core/ScenarioRules.gd").describe_session_progress_recap(session, false),
		"Next step:"
	)
	if progress_next != "":
		return _safe_player_text(progress_next.trim_prefix("Next step:").strip_edges(), 220)
	var action_line := _summary_resume_action_line(summary)
	if action_line != "":
		return _safe_player_text(action_line.trim_prefix("Action:").strip_edges(), 220)
	return "Load the save, inspect the resumed scene, then choose the next order."

func _fallback_resume_decision(resume_target: String) -> String:
	match resume_target:
		"battle":
			return "finish the encounter"
		"town":
			return "make the next town order"
		"outcome":
			return "choose the follow-up result action"
		"overworld":
			return "choose the next field route"
		_:
			return "select a loadable save"

func _preferred_recent_action_recap(session: SessionStateStoreScript.SessionData, resume_target: String) -> Dictionary:
	if session == null:
		return {}
	var ordered_keys := []
	match resume_target:
		"battle":
			ordered_keys = ["last_battle_action_recap", "last_overworld_action_recap", "last_town_action_recap"]
		"town":
			ordered_keys = ["last_town_action_recap", "last_overworld_action_recap"]
		_:
			ordered_keys = ["last_overworld_action_recap", "last_town_action_recap"]
	for key in ordered_keys:
		var value = session.flags.get(key, {})
		var recap := _normalize_saved_action_recap(value)
		if not recap.is_empty():
			return recap
	return {}

func _normalize_saved_action_recap(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source: Dictionary = value
	var happened := _safe_player_text(String(source.get("happened", "")), 180)
	var affected := _safe_player_text(String(source.get("affected", "")), 180)
	var why := _safe_player_text(String(source.get("why_it_matters", source.get("matters", source.get("decision", "")))), 180)
	var next_step := _safe_player_text(String(source.get("next_step", source.get("next", source.get("next_actor", "")))), 180)
	if happened == "" and affected == "" and why == "" and next_step == "":
		return {}
	return {
		"happened": happened,
		"affected": affected,
		"why": why,
		"next_step": next_step,
	}

func _action_recap_change_summary(recap: Dictionary) -> String:
	if recap.is_empty():
		return ""
	var parts := []
	for key in ["happened", "affected", "why"]:
		var text := String(recap.get(key, "")).strip_edges()
		if text != "" and text not in parts:
			parts.append(text)
		if parts.size() >= 2:
			break
	return " | ".join(parts)

func _action_recap_next_step(recap: Dictionary) -> String:
	if recap.is_empty():
		return ""
	return String(recap.get("next_step", "")).strip_edges()

func _battle_aftermath_summary(session: SessionStateStoreScript.SessionData) -> String:
	if session == null:
		return ""
	var report = session.flags.get("last_battle_aftermath", {})
	if not (report is Dictionary):
		return ""
	for key in ["return_summary", "result_summary", "reward_summary", "world_summary", "summary"]:
		var line := _safe_player_text(String(report.get(key, "")), 220)
		if line != "":
			return line
	return ""

func _safe_player_text(value: String, max_chars: int = 220) -> String:
	var text := value.strip_edges().replace("\n", " ")
	while text.find("  ") >= 0:
		text = text.replace("  ", " ")
	if _contains_blocked_debug_token(text):
		return ""
	if text.length() <= max_chars:
		return text
	return "%s..." % text.left(max(1, max_chars - 3)).strip_edges()

func _contains_blocked_debug_token(text: String) -> bool:
	var normalized := text.to_lower()
	for token in [
		"final_priority",
		"base_value",
		"resource_affinity_value",
		"weighted_claim_value",
		"weighted_income_value",
		"assignment_penalty",
		"final_score",
		"income_value",
		"growth_value",
		"pressure_value",
		"category_bonus",
		"raid_score",
		"debug_reason",
		"raid_target_weights",
		"ai_score",
		"weight",
	]:
		if normalized.find(token) >= 0:
			return true
	return false

func _line_with_prefix(text: String, prefix: String) -> String:
	for raw_line in text.split("\n", false):
		var line := String(raw_line).strip_edges()
		if line.begins_with(prefix):
			return line
	return ""

func _first_meaningful_line(text: String, ignored_lines: Array = []) -> String:
	for raw_line in text.split("\n", false):
		var line := String(raw_line).strip_edges()
		if line == "":
			continue
		var normalized := line.trim_prefix("- ").strip_edges()
		if normalized in ignored_lines:
			continue
		return normalized
	return ""

func _slot_label(summary: Dictionary) -> String:
	if String(summary.get("slot_type", "")) == SLOT_TYPE_AUTOSAVE:
		return "Autosave"
	var manual_name := String(summary.get("manual_slot_name", "")).strip_edges()
	if manual_name != "":
		return "%s - Manual %s" % [manual_name, String(summary.get("slot_id", "1"))]
	return "Manual %s" % String(summary.get("slot_id", "1"))

func _manual_slot_name_from_payload(payload: Dictionary) -> String:
	var check := _validate_manual_slot_name(String(payload.get(SAVE_METADATA_MANUAL_NAME_KEY, "")))
	return String(check.get("name", "")) if bool(check.get("ok", false)) else ""

func _validate_manual_slot_name(value: String) -> Dictionary:
	var normalized := value.strip_edges().replace("\r", " ").replace("\n", " ").replace("\t", " ")
	while normalized.find("  ") >= 0:
		normalized = normalized.replace("  ", " ")
	if normalized.length() > MANUAL_SLOT_NAME_MAX_LENGTH:
		return {
			"ok": false,
			"name": "",
			"message": "Save names can use at most %d characters." % MANUAL_SLOT_NAME_MAX_LENGTH,
		}
	for index in range(normalized.length()):
		if normalized.unicode_at(index) < 32:
			return {"ok": false, "name": "", "message": "Save names cannot contain control characters."}
	return {"ok": true, "name": normalized, "message": ""}

func _summary_status_badge(summary: Dictionary) -> String:
	if not bool(summary.get("valid", false)):
		return "Blocked"
	if String(summary.get("resume_target", "overworld")) == "outcome":
		return "Outcome"
	match String(summary.get("validity", "ok")):
		"degraded":
			return "Recovered"
		"legacy":
			return "Legacy"
		_:
			return "Ready"

func _runtime_save_message(slot_type: String, summary: Dictionary) -> String:
	if slot_type == SLOT_TYPE_AUTOSAVE:
		return "Autosaved: %s. %s" % [describe_resume_brief(summary), _main_menu_continue_hint(summary)]
	return "Saved %s: %s. %s" % [_slot_label(summary), describe_resume_brief(summary), _main_menu_continue_hint(summary)]

func _main_menu_continue_hint(summary: Dictionary) -> String:
	if summary.is_empty() or not can_load_summary(summary):
		return "Main menu continue is unavailable for this snapshot."
	match String(summary.get("resume_target", "blocked")):
		"battle":
			var battle_context := _resume_context_label(summary)
			if battle_context != "Battle":
				return "Continue Latest will resume %s." % battle_context
			return "Continue Latest will resume the active battle."
		"town":
			return "Continue Latest will resume %s." % _resume_context_label(summary)
		"outcome":
			return "Continue Latest will review %s." % _resume_context_label(summary)
		"overworld":
			return "Continue Latest will resume %s." % _resume_context_label(summary)
		_:
			return "This snapshot cannot be resumed safely."

func _resume_target_noun(target: String) -> String:
	match target:
		"battle":
			return "battle"
		"town":
			return "town"
		"outcome":
			return "outcome"
		_:
			return "expedition"

func _return_to_menu_label(current_target: String, session: SessionStateStoreScript.SessionData = null) -> String:
	if session != null and bool(session.flags.get("editor_working_copy", false)):
		return "Editor"
	return MAIN_MENU_ACTION_LABEL

func _in_session_save_label(current_target: String, selected_slot: int) -> String:
	match current_target:
		"battle":
			return "Save Battle to Manual %d" % selected_slot
		"town":
			return "Save Town to Manual %d" % selected_slot
		"outcome":
			return "Save Outcome to Manual %d" % selected_slot
		_:
			return "Save Expedition to Manual %d" % selected_slot

func _in_session_save_tooltip(current_target: String, slot_summary: Dictionary, current_context: String = "") -> String:
	var lines := [
		"Write %s into %s." % [current_context if current_context != "" else "a safe %s snapshot" % _resume_target_noun(current_target), _slot_label(slot_summary)],
		_main_menu_continue_hint({"resume_target": current_target, "valid": true, "loadable": true, "payload": {"scenario_id": "active"}}),
	]
	var existing_status := String(slot_summary.get("status_text", ""))
	if existing_status != "":
		lines.append("Current slot: %s" % existing_status)
	return "\n".join(lines)

func _latest_context_line(latest_summary: Dictionary, current_target: String = "") -> String:
	if latest_summary.is_empty() or not can_load_summary(latest_summary):
		return "Latest ready save: none."
	var prefix := "Latest ready"
	if current_target != "" and String(latest_summary.get("resume_target", "")) == current_target:
		prefix = "Latest ready %s snapshot" % _resume_target_noun(current_target)
	return "%s: %s | %s | %s" % [
		prefix,
		_slot_label(latest_summary),
		describe_resume_brief(latest_summary),
		format_modified_timestamp(int(_summary_sort_timestamp(latest_summary))),
	]

func _return_to_menu_tooltip(
	current_target: String,
	latest_summary: Dictionary,
	current_context: String = "",
	return_handoff: String = ""
) -> String:
	var lines := [
		"Return to the main menu after refreshing autosave for %s." % (current_context if current_context != "" else "this %s state" % _resume_target_noun(current_target)),
	]
	if return_handoff != "":
		lines.append(return_handoff)
	if latest_summary.is_empty():
		lines.append("A fresh autosave will become the latest continue target.")
	else:
		lines.append(_main_menu_continue_hint({"resume_target": current_target, "valid": true, "loadable": true, "payload": {"scenario_id": "active"}}))
		lines.append("Latest before return: %s" % _slot_label(latest_summary))
	return "\n".join(lines)

func _resume_preserved_context(summary: Dictionary) -> String:
	match String(summary.get("resume_target", "blocked")):
		"battle":
			return "round order, active stack, selected target, and tactical position"
		"town":
			return "build, recruit, spell, town defense, and logistics state"
		"outcome":
			return "scenario result, progress recap, and follow-up choices"
		"overworld":
			return "hero position, movement, map control, resources, and day state"
		_:
			return "available expedition state"

func _resume_target_label(summary: Dictionary) -> String:
	match String(summary.get("resume_target", "blocked")):
		"battle":
			return "Battle Resume"
		"town":
			return "Town Resume"
		"outcome":
			return "Outcome Review"
		"overworld":
			return "Overworld Resume"
		_:
			return "Blocked"

func _resume_context_label(summary: Dictionary) -> String:
	var location := String(summary.get("resume_location", "")).strip_edges()
	match String(summary.get("resume_target", "blocked")):
		"battle":
			return "Battle: %s" % location if location != "" else "Battle"
		"town":
			return "Town: %s" % location if location != "" else "Town"
		"outcome":
			var result := _humanize_label(String(summary.get("scenario_status", "outcome")))
			return "Outcome: %s" % result if result != "" else "Outcome"
		"overworld":
			return location if location != "" else "Overworld"
		_:
			return "Blocked"

func _status_text_for_summary(summary: Dictionary) -> String:
	if not bool(summary.get("valid", false)):
		return String(summary.get("status_text", "Unavailable"))
	match String(summary.get("resume_target", "blocked")):
		"battle":
			var battle_context := _resume_context_label(summary)
			if battle_context != "Battle":
				return "Ready to resume %s." % battle_context
			return "Ready to resume the active battle."
		"town":
			return "Ready to resume %s." % _resume_context_label(summary)
		"outcome":
			return "%s is ready to review." % _resume_context_label(summary)
		"overworld":
			match String(summary.get("validity", "ok")):
				"degraded":
					return "Recovered %s is ready to resume." % _resume_context_label(summary)
				"legacy":
					return "Legacy %s is ready to resume." % _resume_context_label(summary)
				_:
					return "Ready to resume %s." % _resume_context_label(summary)
		_:
			return "This save cannot be loaded."

func _normalize_manual_slot(slot: int) -> int:
	for slot_id in MANUAL_SLOT_IDS:
		if int(slot_id) == slot:
			return slot
	return int(MANUAL_SLOT_IDS[0])

func _resume_target_for_session(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.scenario_id == "":
		return "blocked"
	if session.scenario_status != "in_progress":
		return "outcome"
	if not session.battle.is_empty() and BattleRulesScript.battle_payload_can_resume_bridge(session):
		return "battle"
	if String(session.game_state) == "town" and TownRulesScript.can_visit_active_town_bridge(session):
		return "town"
	return "overworld"

func _recorded_timestamp_from_payload(payload: Dictionary, fallback: int = 0) -> int:
	var recorded: int = max(0, int(payload.get(SAVE_METADATA_TIMESTAMP_KEY, 0)))
	return recorded if recorded > 0 else max(0, fallback)

func _recorded_timestamp_precise_from_payload(payload: Dictionary) -> float:
	return maxf(0.0, float(payload.get(SAVE_METADATA_TIMESTAMP_KEY, 0.0)))

func _payload_structure_report(payload: Dictionary, slot_type: String = "") -> Dictionary:
	var warnings := []
	var validity := "ok"
	var scenario_id := String(payload.get("scenario_id", ""))
	if scenario_id == "":
		return {
			"ok": false,
			"validity": "invalid_payload",
			"message": "Missing scenario id.",
			"warnings": warnings,
		}

	var overworld = payload.get("overworld", {})
	if not (overworld is Dictionary) or overworld.is_empty():
		return {
			"ok": false,
			"validity": "invalid_payload",
			"message": "Missing overworld expedition state.",
			"warnings": warnings,
		}
	if not _has_core_overworld_state(overworld):
		return {
			"ok": false,
			"validity": "invalid_payload",
			"message": "The save is missing core expedition state and cannot be recovered safely.",
			"warnings": warnings,
		}

	if not payload.has("save_version"):
		validity = "legacy"
		warnings.append("Save version marker was missing and compatibility fallback was applied.")
	if not payload.has("session_id") or String(payload.get("session_id", "")) == "":
		validity = _degraded_validity(validity)
		warnings.append("Session id was missing and a new runtime id will be issued.")
	if not payload.has("hero_id") or String(payload.get("hero_id", "")) == "":
		validity = _degraded_validity(validity)
		warnings.append("Commander id was missing and will be derived from restored overworld state.")
	if not (payload.get("flags", {}) is Dictionary):
		validity = _degraded_validity(validity)
		warnings.append("Session flags were missing or invalid and were reset.")

	var missing_overworld_fields := _missing_overworld_fields(overworld)
	if not missing_overworld_fields.is_empty():
		validity = _degraded_validity(validity)
		warnings.append(
			"Overworld save fields were incomplete (%s); missing data was restored from authored defaults."
			% ", ".join(missing_overworld_fields)
		)

	var raw_difficulty := String(payload.get("difficulty", ""))
	if raw_difficulty == "" or ScenarioSelectRulesScript.normalize_difficulty(raw_difficulty) != raw_difficulty:
		validity = _degraded_validity(validity)
		warnings.append("Difficulty metadata was missing or invalid and was normalized.")
	var raw_launch_mode := String(payload.get("launch_mode", ""))
	if raw_launch_mode == "" or SessionStateStoreScript.normalize_launch_mode(raw_launch_mode) != raw_launch_mode:
		validity = _degraded_validity(validity)
		warnings.append("Launch-mode metadata was missing or invalid and was normalized.")
	var raw_game_state := String(payload.get("game_state", ""))
	if raw_game_state == "" or raw_game_state not in SessionStateStoreScript.SUPPORTED_GAME_STATES:
		validity = _degraded_validity(validity)
		warnings.append("Scene-state metadata was missing or invalid and the session will resume through a safer route.")
	var raw_scenario_status := String(payload.get("scenario_status", ""))
	if raw_scenario_status == "" or raw_scenario_status not in SessionStateStoreScript.SUPPORTED_SCENARIO_STATUSES:
		validity = _degraded_validity(validity)
		warnings.append("Scenario-status metadata was missing or invalid and was normalized.")

	var recorded_slot_type := String(payload.get(SAVE_METADATA_SLOT_TYPE_KEY, ""))
	if recorded_slot_type != "" and slot_type != "" and recorded_slot_type != slot_type:
		validity = _degraded_validity(validity)
		warnings.append("Recorded slot metadata no longer matches this slot; the live file location was trusted instead.")

	return {
		"ok": true,
		"validity": validity,
		"warnings": warnings,
	}

func _has_core_overworld_state(overworld: Dictionary) -> bool:
	var has_world_state := false
	for key in ["resources", "towns", "encounters", "map"]:
		if overworld.has(key):
			has_world_state = true
			break
	var has_commander_state := false
	for key in ["hero", "player_heroes", "hero_position", "active_hero_id"]:
		if overworld.has(key):
			has_commander_state = true
			break
	return has_world_state and has_commander_state

func _missing_overworld_fields(overworld: Dictionary) -> Array:
	var missing := []
	for key in ["resources", "towns", "resource_nodes", "artifact_nodes", "encounters", "resolved_encounters", "map", "map_size"]:
		if not overworld.has(key):
			missing.append(key)
	if not overworld.has("hero") and not overworld.has("player_heroes"):
		missing.append("hero_roster")
	return missing

func _degraded_validity(current_validity: String) -> String:
	return "degraded" if current_validity in ["ok", "legacy"] else current_validity

func _humanize_label(value: String) -> String:
	return value.replace("_", " ").capitalize()

func _validity_label(validity: String) -> String:
	match validity:
		"ok":
			return "Valid"
		"legacy":
			return "Legacy save normalized"
		"degraded":
			return "Recovered with fallback"
		"missing":
			return "Empty slot"
		"corrupt_json":
			return "Corrupt or unreadable JSON"
		"invalid_payload":
			return "Invalid session payload"
		"missing_scenario":
			return "Missing scenario content"
		"newer_version":
			return "Written by a newer build"
		_:
			return _humanize_label(validity)
