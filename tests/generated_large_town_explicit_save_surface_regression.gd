extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "GENERATED_LARGE_TOWN_EXPLICIT_SAVE_SURFACE_REGRESSION"
const GENERATED_LARGE_SEED := "town-explicit-save-surface-large-10184"
const FAILURE_ENV := "HEROES_LIKE_SAVE_FAIL_PHASE"
const PROFILE_ENV := "HEROES_PROFILE_LOG"
const MANUAL_PATHS := [
	"user://saves/slot1.json",
	"user://saves/slot2.json",
	"user://saves/slot3.json",
]
const AUTHORITY_PATHS := [
	"user://saves/autosave.json",
	"user://saves/slot1.json",
	"user://saves/slot2.json",
	"user://saves/slot3.json",
	"user://saves/campaign_progression.json",
]

var _original_files: Dictionary = {}
var _previous_failure_env := ""
var _previous_profile_env := ""
var _report_rows: Dictionary = {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_previous_failure_env = OS.get_environment(FAILURE_ENV)
	_previous_profile_env = OS.get_environment(PROFILE_ENV)
	OS.unset_environment(FAILURE_ENV)
	OS.set_environment(PROFILE_ENV, "1")
	_original_files = _capture_original_file_states()
	_clear_paths(AUTHORITY_PATHS)
	SaveService.validation_clear_summary_cache()
	SaveService.validation_clear_general_profile_log()
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()

	if not _assert_required_contract():
		return
	var parity_rows: Dictionary = _assert_context_and_freshness_parity()
	if parity_rows.is_empty():
		return
	_report_rows["context_parity"] = parity_rows

	var generated_row: Dictionary = await _assert_generated_large_physical_and_transactional_flow()
	if generated_row.is_empty():
		return
	_report_rows["generated_large"] = generated_row

	_finish_success()

func _assert_required_contract() -> bool:
	for method_name in [
		"validation_build_in_session_save_surface_direct_legacy",
		"validation_clear_general_profile_log",
		"validation_general_profile_log_last_records",
		"validation_summary_cache_snapshot",
		"validation_clear_summary_cache",
	]:
		if not SaveService.has_method(method_name):
			_finish_fail("SaveService is missing explicit save-surface validation contract %s." % method_name)
			return false
	return true

func _assert_context_and_freshness_parity() -> Dictionary:
	var rows := {}
	var risk_summary_rows: Dictionary = _assert_command_risk_summary_fast_path()
	if risk_summary_rows.is_empty():
		return {}
	rows["command_risk_summary_fast_path"] = risk_summary_rows
	var town_session = _small_town_session()
	if town_session == null:
		return {}
	var town_surface: Dictionary = _assert_surface_parity("town", town_session, 1)
	if town_surface.is_empty():
		return {}
	rows["town"] = _surface_copy_signature(town_surface)

	var prior_surface := town_surface.duplicate(true)
	var resources: Dictionary = town_session.overworld.get("resources", {}) if town_session.overworld.get("resources", {}) is Dictionary else {}
	for resource_id in resources.keys():
		resources[resource_id] = 0
	town_session.overworld["resources"] = resources
	var resource_surface: Dictionary = _assert_surface_parity("town_resource_change", town_session, 1)
	if resource_surface.is_empty():
		return {}
	rows["resource_change"] = {
		"optimized_legacy_exact": true,
		"copy_changed": resource_surface != prior_surface,
		"copy": _surface_copy_signature(resource_surface),
	}

	prior_surface = resource_surface.duplicate(true)
	town_session.day += 1
	var day_surface: Dictionary = _assert_surface_parity("town_day_change", town_session, 1)
	if day_surface.is_empty() or not _assert_surface_changed(prior_surface, day_surface, "day change"):
		return {}
	rows["day_change"] = _surface_copy_signature(day_surface)

	prior_surface = day_surface.duplicate(true)
	_give_resources(town_session)
	var action_result := _perform_one_town_action(town_session)
	if action_result.is_empty() or not bool(action_result.get("ok", false)):
		_finish_fail("Town parity fixture could not perform one real action.", action_result)
		return {}
	var action_surface: Dictionary = _assert_surface_parity("town_action_change", town_session, 1)
	if action_surface.is_empty():
		return {}
	rows["action_change"] = {
		"action_id": String(action_result.get("action_id", "")),
		"optimized_legacy_exact": true,
		"copy_changed": action_surface != prior_surface,
		"copy": _surface_copy_signature(action_surface),
	}

	for context in ["overworld", "battle", "outcome", "editor", "stale_route"]:
		var session = _small_context_session(String(context))
		if session == null:
			return {}
		var surface: Dictionary = _assert_surface_parity(String(context), session, 2)
		if surface.is_empty():
			return {}
		rows[context] = _surface_copy_signature(surface)
	var enemy_state_session = _small_context_session("overworld")
	if enemy_state_session == null:
		return {}
	var enemy_state_mutation: Dictionary = _mutate_nested_enemy_state(enemy_state_session)
	if enemy_state_mutation.is_empty():
		return {}
	var enemy_state_surface: Dictionary = _assert_surface_parity("nested_enemy_state_change", enemy_state_session, 2)
	if enemy_state_surface.is_empty():
		return {}
	rows["nested_enemy_state_change"] = {
		"mutation": enemy_state_mutation,
		"optimized_trusted_direct_normalized_exact": true,
		"copy": _surface_copy_signature(enemy_state_surface),
	}
	var alias_rows := _assert_stored_recap_alias_profiles()
	if alias_rows.is_empty():
		return {}
	rows["stored_recap_alias"] = alias_rows
	var recovery_rows: Dictionary = _assert_summary_recovery_controls()
	if recovery_rows.is_empty():
		return {}
	rows["summary_recovery"] = recovery_rows
	var fallback_session = _small_town_session()
	if fallback_session == null:
		return {}
	fallback_session.day += 1
	if OverworldRules.is_runtime_session_normalized(fallback_session):
		_finish_fail("Unnormalized save-surface control unexpectedly retained runtime-normalized identity.")
		return {}
	SaveService.validation_clear_general_profile_log()
	var fallback_surface: Dictionary = _assert_surface_parity("unnormalized_fallback", fallback_session, 3)
	var fallback_record: Dictionary = _last_save_surface_record(SaveService.validation_general_profile_log_last_records(10))
	if fallback_surface.is_empty() or not _assert_normalization_profile(fallback_record, false, true, "unnormalized fallback"):
		return {}
	rows["unnormalized_fallback"] = {
		"field_count": fallback_surface.keys().size(),
		"fallback": true,
		"surface_ms": float(fallback_record.get("total_ms", 0.0)),
	}
	return rows

func _assert_stored_recap_alias_profiles() -> Dictionary:
	_clear_paths(MANUAL_PATHS)
	SaveService.validation_clear_summary_cache()
	var session = _small_context_session("overworld")
	if session == null:
		return {}
	if not bool(SaveService.save_runtime_manual_session(session, 1).get("ok", false)):
		_finish_fail("Could not seed selected/latest alias control.")
		return {}
	SaveService.set_selected_manual_slot(1)
	_warm_summary_cache()
	SaveService.validation_clear_general_profile_log()
	var alias_live_before: Dictionary = session.to_dict().duplicate(true)
	var alias_surface: Dictionary = SaveService.build_in_session_save_surface(session, 1)
	var alias_live_after: Dictionary = session.to_dict().duplicate(true)
	var alias_direct: Dictionary = _direct_legacy_surface(session, 1)
	var alias_record := _last_save_surface_record(SaveService.validation_general_profile_log_last_records(10))
	var alias_metadata: Dictionary = alias_record.get("metadata", {}) if alias_record.get("metadata", {}) is Dictionary else {}
	if alias_live_after != alias_live_before or alias_surface != alias_direct or not bool(alias_metadata.get("stored_recap_alias_reused", false)) or alias_surface.get("slot_resume_recap") != alias_surface.get("latest_resume_recap"):
		_finish_fail("Selected/latest stored recap alias was not reused exactly.", {"difference": _first_difference(alias_direct, alias_surface), "record": alias_record})
		return {}

	session.day += 1
	if not bool(SaveService.save_runtime_manual_session(session, 2).get("ok", false)):
		_finish_fail("Could not seed distinct-latest alias control.")
		return {}
	SaveService.validation_clear_general_profile_log()
	var distinct_live_before: Dictionary = session.to_dict().duplicate(true)
	var distinct_surface: Dictionary = SaveService.build_in_session_save_surface(session, 1)
	var distinct_live_after: Dictionary = session.to_dict().duplicate(true)
	var distinct_direct: Dictionary = _direct_legacy_surface(session, 1)
	var distinct_record := _last_save_surface_record(SaveService.validation_general_profile_log_last_records(10))
	var distinct_metadata: Dictionary = distinct_record.get("metadata", {}) if distinct_record.get("metadata", {}) is Dictionary else {}
	if distinct_live_after != distinct_live_before or distinct_surface != distinct_direct or bool(distinct_metadata.get("stored_recap_alias_reused", true)) or distinct_surface.get("slot_resume_recap") == distinct_surface.get("latest_resume_recap"):
		_finish_fail("Distinct selected/latest stored recaps were incorrectly aliased.", {"difference": _first_difference(distinct_direct, distinct_surface), "record": distinct_record})
		return {}
	return {
		"selected_latest_alias": true,
		"distinct_latest_alias": false,
		"alias_surface_ms": float(alias_record.get("total_ms", 0.0)),
		"distinct_surface_ms": float(distinct_record.get("total_ms", 0.0)),
	}

func _assert_summary_recovery_controls() -> Dictionary:
	var path := MANUAL_PATHS[0]
	var live_state: Dictionary = _capture_file(path)
	var live_bytes: PackedByteArray = live_state.get("bytes", PackedByteArray()) if live_state.get("bytes", PackedByteArray()) is PackedByteArray else PackedByteArray()
	if not bool(live_state.get("exists", false)) or live_bytes.is_empty():
		_finish_fail("Summary recovery control is missing its seeded Manual 1 bytes.")
		return {}
	var summary_before: Dictionary = SaveService.inspect_manual_slot(1)
	var candidate_path := "%s.candidate" % path
	if not _write_file_bytes(candidate_path, live_bytes):
		_finish_fail("Could not seed candidate summary recovery control.")
		return {}
	var candidate_summary: Dictionary = SaveService.inspect_manual_slot(1)
	if FileAccess.file_exists(candidate_path) or candidate_summary != summary_before or _capture_file(path).get("bytes", PackedByteArray()) != live_bytes:
		_finish_fail("Candidate presence did not force exact cleanup before cached summary return.", {"before": summary_before, "after": candidate_summary})
		return {}

	var cache_before_backup: Dictionary = SaveService.validation_summary_cache_snapshot()
	var backup_path := "%s.backup" % path
	if not _write_file_bytes(backup_path, live_bytes) or DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
		_finish_fail("Could not seed missing-live valid-backup recovery control.")
		return {}
	var restored_summary: Dictionary = SaveService.inspect_manual_slot(1)
	var cache_after_backup: Dictionary = SaveService.validation_summary_cache_snapshot()
	if not SaveService.can_load_summary(restored_summary) or not FileAccess.file_exists(path) or FileAccess.file_exists(backup_path) or _capture_file(path).get("bytes", PackedByteArray()) != live_bytes or cache_after_backup.is_empty() or cache_after_backup == cache_before_backup:
		_finish_fail("Valid backup recovery did not restore bytes and rebuild a loadable summary cache.", {"summary": restored_summary, "cache_before": cache_before_backup, "cache_after": cache_after_backup})
		return {}
	return {"candidate_cleanup": true, "backup_restored": true, "cache_rebuilt": true, "file_size": live_bytes.size()}

func _assert_surface_parity(label: String, session, slot: int) -> Dictionary:
	_warm_summary_cache()
	var authority_before := {
		"session": session.to_dict().duplicate(true),
		"files": _file_states(AUTHORITY_PATHS),
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
	}
	var direct_session := SessionStateStoreScript.SessionData.new()
	direct_session.from_dict(authority_before["session"])
	var optimized: Dictionary = SaveService.build_in_session_save_surface(session, slot)
	var authority_after_optimized := {
		"session": session.to_dict().duplicate(true),
		"files": _file_states(AUTHORITY_PATHS),
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
	}
	if authority_after_optimized != authority_before:
		_finish_fail("%s optimized save surface mutated session, files, or summary cache." % label, _first_difference(authority_before, authority_after_optimized))
		return {}
	var direct: Dictionary = SaveService.validation_build_in_session_save_surface_direct_legacy(direct_session, slot)
	if optimized != direct:
		_finish_fail("%s optimized save surface changed a legacy field or string." % label, _first_difference(direct, optimized))
		return {}
	var authority_after := {
		"session": session.to_dict().duplicate(true),
		"files": _file_states(AUTHORITY_PATHS),
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
	}
	if authority_after != authority_before:
		_finish_fail("%s save-surface comparison mutated session, files, or summary cache." % label, _first_difference(authority_before, authority_after))
		return {}
	if optimized.keys().size() != 17:
		_finish_fail("%s save surface changed its exact field count." % label, optimized.keys())
		return {}
	return optimized

func _assert_surface_changed(before: Dictionary, after: Dictionary, label: String) -> bool:
	if before == after:
		_finish_fail("Explicit save surface reused stale copy after %s." % label)
		return false
	return true

func _assert_generated_large_physical_and_transactional_flow() -> Dictionary:
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()
	_clear_paths(MANUAL_PATHS)
	SaveService.validation_clear_summary_cache()
	SaveService.set_selected_manual_slot(1)
	var session = _generated_large_session()
	if session == null or session.scenario_id == "":
		_finish_fail("Could not create the generated Large save-surface fixture.")
		return {}
	OverworldRules.normalize_overworld_state(session)
	var town := _first_player_town(session)
	if town.is_empty():
		_finish_fail("Generated Large save-surface fixture has no player town.")
		return {}
	_move_active_hero_to_town(session, town)
	var visit: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	if not bool(visit.get("ok", false)):
		_finish_fail("Generated Large save-surface fixture could not enter its town.", visit)
		return {}
	session.game_state = "town"
	SessionState.set_active_session(session)
	session = SessionState.ensure_active_session()
	AppRouter.validation_prepare_town_handoff_without_scene_change()
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await _settle(2)
	var picker: OptionButton = shell.get_node_or_null("%SaveSlot")
	if picker == null or picker.get_item_count() != 3:
		_finish_fail("Generated Large Town does not expose the three-slot SaveSlot control.")
		return {}

	_warm_summary_cache()
	picker.grab_focus()
	await _settle(1)
	var selection_before := _selection_authority(session, shell)
	SaveService.validation_clear_general_profile_log()
	var selection_started := Time.get_ticks_msec()
	await _press_joypad_button(JOY_BUTTON_A)
	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle(2)
	var selection_ms: int = maxi(0, Time.get_ticks_msec() - selection_started)
	if SaveService.get_selected_manual_slot() != 2 or picker.get_selected_id() != 2:
		_finish_fail("Physical SaveSlot input did not select Manual 2.", {"service": SaveService.get_selected_manual_slot(), "picker": picker.get_selected_id()})
		return {}
	var selection_after := _selection_authority(session, shell)
	if selection_after != selection_before:
		_finish_fail("Physical SaveSlot selection mutated generated session, files, cache, routes, or focus.", _first_difference(selection_before, selection_after))
		return {}
	var selection_records: Array = SaveService.validation_general_profile_log_last_records(20)
	if _runtime_save_record_count(selection_records) != 0:
		_finish_fail("SaveSlot selection performed a write.", selection_records)
		return {}
	var selection_surface := _last_save_surface_record(selection_records)
	if not _assert_surface_profile_light(selection_surface, "physical SaveSlot selection"):
		return {}
	if not _assert_normalization_profile(selection_surface, true, false, "generated-Large selection"):
		return {}
	var selection_cache_snapshot: Dictionary = shell.call("validation_town_entity_cache_snapshot")
	var selection_save_profile: Dictionary = selection_cache_snapshot.get("last_save_surface_profile", {}) if selection_cache_snapshot.get("last_save_surface_profile", {}) is Dictionary else {}
	if not bool(selection_save_profile.get("departure_reused", false)):
		_finish_fail("Generated-Large selection did not reuse the current departure surface.", selection_cache_snapshot)
		return {}
	if selection_ms >= 1000:
		_finish_fail("Physical SaveSlot selection exceeded 1000ms.", {"elapsed_ms": selection_ms, "profile": selection_surface})
		return {}
	var generated_surface: Dictionary = _assert_surface_parity("generated_large_town", session, 2)
	if generated_surface.is_empty():
		return {}

	var success_row: Dictionary = await _assert_empty_slot_success(shell, session, picker)
	if success_row.is_empty():
		return {}
	var cancel_row: Dictionary = await _assert_overwrite_cancel(shell, session, picker)
	if cancel_row.is_empty():
		return {}
	var precommit_failure_row: Dictionary = await _assert_overwrite_failure(shell, session, picker, "precommit")
	if precommit_failure_row.is_empty():
		return {}
	var after_backup_failure_row: Dictionary = await _assert_overwrite_failure(shell, session, picker, "after_backup")
	if after_backup_failure_row.is_empty():
		return {}
	var overwrite_row: Dictionary = await _assert_overwrite_success(shell, session, picker)
	if overwrite_row.is_empty():
		return {}

	shell.queue_free()
	await get_tree().process_frame
	return {
		"seed": GENERATED_LARGE_SEED,
		"scenario_id": session.scenario_id,
		"town_placement_id": String(town.get("placement_id", "")),
		"selection_ms": selection_ms,
		"selection_surface_ms": float(selection_surface.get("total_ms", 0.0)),
		"surface_field_count": generated_surface.keys().size(),
		"success": success_row,
		"overwrite_cancel": cancel_row,
		"precommit_failure": precommit_failure_row,
		"after_backup_failure": after_backup_failure_row,
		"overwrite_success": overwrite_row,
	}

func _assert_empty_slot_success(shell: Node, session, picker: OptionButton) -> Dictionary:
	SaveService.validation_clear_general_profile_log()
	var save_button: Button = shell.get_node_or_null("%Save")
	var management_tabs: TabContainer = shell.get_node_or_null("%ManagementTabs")
	var event_label: Label = shell.get_node_or_null("%Event")
	if save_button == null or save_button.disabled:
		_finish_fail("Generated Large Town Save command is unavailable.")
		return {}
	if management_tabs == null or event_label == null:
		_finish_fail("Generated Large Town management tabs are unavailable.")
		return {}
	var active_tab_before: int = management_tabs.current_tab
	save_button.grab_focus()
	await _settle(1)
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle(2)
	var records: Array = SaveService.validation_general_profile_log_last_records(30)
	if _runtime_save_record_count(records) != 1:
		_finish_fail("Empty-slot Save did not execute exactly one runtime write.", records)
		return {}
	var surface := _last_save_surface_record(records)
	if not _assert_surface_profile_light(surface, "post-empty-slot-save refresh", 1):
		return {}
	var town_save_record: Dictionary = _last_town_save_record(records)
	var town_save_buckets: Dictionary = town_save_record.get("buckets_ms", {}) if town_save_record.get("buckets_ms", {}) is Dictionary else {}
	if town_save_record.is_empty() or float(town_save_buckets.get("save_surface_force", 99999.0)) >= 1000.0:
		_finish_fail("Post-save forced Town surface refresh exceeded 1000ms.", town_save_record)
		return {}
	var town_save_metadata: Dictionary = town_save_record.get("metadata", {}) if town_save_record.get("metadata", {}) is Dictionary else {}
	var town_cache: Dictionary = town_save_metadata.get("town_entity_cache", {}) if town_save_metadata.get("town_entity_cache", {}) is Dictionary else {}
	if float(town_save_buckets.get("refresh", 99999.0)) >= 1000.0 or not bool(town_cache.get("hit", false)) or float(town_cache.get("build_ms", 99999.0)) != 0.0:
		_finish_fail("Post-save Town refresh did not reuse its warm entity cache under 1000ms.", town_save_record)
		return {}
	var saved_message := String(shell.get("_last_message")).strip_edges()
	var direct_dispatch_session := SessionStateStoreScript.SessionData.new()
	direct_dispatch_session.from_dict(session.to_dict())
	var direct_dispatch: String = TownRules.describe_event_feed(direct_dispatch_session, saved_message, {})
	if management_tabs.current_tab != active_tab_before or get_viewport().gui_get_focus_owner() != save_button or saved_message == "" or not event_label.tooltip_text.ends_with(direct_dispatch):
		_finish_fail("Post-save refresh changed the active tab, Save focus, or visible result message.", {
			"active_tab_before": active_tab_before,
			"active_tab_after": management_tabs.current_tab,
			"focus_owner": String(get_viewport().gui_get_focus_owner().name) if get_viewport().gui_get_focus_owner() != null else "",
			"message": saved_message,
			"dispatch": event_label.text,
			"dispatch_tooltip": event_label.tooltip_text,
			"direct_dispatch": direct_dispatch,
		})
		return {}
	if not _assert_current_surface_alias(session, 2, true, "post-empty-slot-save"):
		return {}
	var summary: Dictionary = SaveService.inspect_manual_slot(2)
	var restored = SaveService.restore_manual_session(2)
	var expected_restored: Dictionary = _canonical_dictionary(session.to_dict())
	var actual_restored: Dictionary = _canonical_dictionary(restored.to_dict()) if restored != null else {}
	if not SaveService.can_load_summary(summary) or restored == null or actual_restored != expected_restored:
		_finish_fail("Empty-slot Save did not persist the exact generated Town session.", {
			"summary": {
				"validity": String(summary.get("validity", "")),
				"loadable": bool(summary.get("loadable", false)),
				"payload_bytes": int(summary.get("payload_bytes", 0)),
				"payload_deferred": bool(summary.get("payload_deferred", false)),
			},
			"difference": _first_difference(expected_restored, actual_restored) if restored != null else {"restored": false},
		})
		return {}
	if picker.get_selected_id() != 2:
		_finish_fail("Post-save refresh redirected the selected slot.")
		return {}
	return {"write_count": 1, "commit_total_ms": float(town_save_record.get("total_ms", 0.0)), "surface_ms": float(surface.get("total_ms", 0.0)), "forced_refresh_ms": float(town_save_buckets.get("save_surface_force", 0.0)), "town_refresh_ms": float(town_save_buckets.get("refresh", 0.0)), "cache_hit": true, "cache_build_ms": 0.0, "bytes": FileAccess.get_size(MANUAL_PATHS[1])}

func _assert_overwrite_cancel(shell: Node, session, picker: OptionButton) -> Dictionary:
	var file_before := _file_state(MANUAL_PATHS[1])
	var cache_before := SaveService.validation_summary_cache_snapshot()
	var session_before: Dictionary = session.to_dict()
	SaveService.validation_clear_general_profile_log()
	var request: Dictionary = shell.call("validation_request_manual_save")
	var request_action: Dictionary = request.get("action", {}) if request.get("action", {}) is Dictionary else {}
	if not bool(request.get("visible", false)) or int(request.get("pending_slot", 0)) != 2 or not bool(request_action.get("requires_confirmation", false)):
		_finish_fail("Occupied generated save did not request overwrite confirmation.", request)
		return {}
	shell.call("validation_cancel_manual_save_overwrite")
	await _settle(2)
	var records: Array = SaveService.validation_general_profile_log_last_records(20)
	if _runtime_save_record_count(records) != 0 or _file_state(MANUAL_PATHS[1]) != file_before or SaveService.validation_summary_cache_snapshot() != cache_before or session.to_dict() != session_before or picker.get_selected_id() != 2:
		_finish_fail("Overwrite cancellation mutated write/session/cache/slot authority.", records)
		return {}
	return {"write_count": 0, "bytes_exact": true}

func _assert_overwrite_failure(shell: Node, session, picker: OptionButton, phase: String) -> Dictionary:
	var resources: Dictionary = session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}
	resources["gold"] = int(resources.get("gold", 0)) + 17
	session.overworld["resources"] = resources
	var file_before := _file_state(MANUAL_PATHS[1])
	var cache_before := SaveService.validation_summary_cache_snapshot()
	var session_before: Dictionary = session.to_dict()
	SaveService.validation_clear_general_profile_log()
	var request: Dictionary = shell.call("validation_request_manual_save")
	var request_action: Dictionary = request.get("action", {}) if request.get("action", {}) is Dictionary else {}
	if not bool(request.get("visible", false)) or int(request.get("pending_slot", 0)) != 2 or not bool(request_action.get("requires_confirmation", false)):
		_finish_fail("%s failure row did not open overwrite confirmation." % phase, request)
		return {}
	OS.set_environment(FAILURE_ENV, phase)
	var confirmation: Dictionary = shell.call("validation_confirm_manual_save_overwrite")
	OS.unset_environment(FAILURE_ENV)
	await _settle(2)
	var records: Array = SaveService.validation_general_profile_log_last_records(30)
	if _runtime_save_record_count(records) != 1:
		_finish_fail("Injected %s overwrite failure did not execute exactly one write attempt." % phase, records)
		return {}
	if _file_state(MANUAL_PATHS[1]) != file_before or SaveService.validation_summary_cache_snapshot() != cache_before or session.to_dict() != session_before or picker.get_selected_id() != 2 or not _artifacts_absent(MANUAL_PATHS[1]):
		_finish_fail("Injected %s overwrite failure changed prior bytes/cache/live authority or left residue." % phase, {"confirmation": confirmation, "records": records})
		return {}
	var surface := _last_save_surface_record(records)
	if not _assert_surface_profile_light(surface, "post-%s-failed-save refresh" % phase, 1):
		return {}
	if not _assert_current_surface_alias(session, 2, true, "post-%s-failed-save" % phase):
		return {}
	return {"phase": phase, "write_attempt_count": 1, "bytes_exact": true, "surface_ms": float(surface.get("total_ms", 0.0))}

func _assert_overwrite_success(shell: Node, session, picker: OptionButton) -> Dictionary:
	var resources: Dictionary = session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}
	resources["gold"] = int(resources.get("gold", 0)) + 19
	session.overworld["resources"] = resources
	var file_before := _file_state(MANUAL_PATHS[1])
	SaveService.validation_clear_general_profile_log()
	var request: Dictionary = shell.call("validation_request_manual_save")
	var request_action: Dictionary = request.get("action", {}) if request.get("action", {}) is Dictionary else {}
	if not bool(request.get("visible", false)) or int(request.get("pending_slot", 0)) != 2 or not bool(request_action.get("requires_confirmation", false)):
		_finish_fail("Overwrite success row did not open confirmation.", request)
		return {}
	shell.call("validation_confirm_manual_save_overwrite")
	await _settle(2)
	var records: Array = SaveService.validation_general_profile_log_last_records(30)
	if _runtime_save_record_count(records) != 1:
		_finish_fail("Confirmed overwrite did not execute exactly one runtime write.", records)
		return {}
	var file_after := _file_state(MANUAL_PATHS[1])
	var restored = SaveService.restore_manual_session(2)
	if file_after == file_before or restored == null or _canonical_dictionary(restored.to_dict()) != _canonical_dictionary(session.to_dict()) or picker.get_selected_id() != 2 or not _artifacts_absent(MANUAL_PATHS[1]):
		_finish_fail("Confirmed overwrite did not commit the exact current generated session once.", {"before": file_before, "after": file_after})
		return {}
	var surface := _last_save_surface_record(records)
	if not _assert_surface_profile_light(surface, "post-overwrite refresh", 1):
		return {}
	if not _assert_current_surface_alias(session, 2, true, "post-overwrite"):
		return {}
	return {"write_count": 1, "surface_ms": float(surface.get("total_ms", 0.0)), "bytes": int(file_after.get("size", -1))}

func _assert_surface_profile_light(record: Dictionary, label: String, expected_alias: int = -1) -> bool:
	if record.is_empty():
		_finish_fail("%s did not emit a save-surface profile record." % label)
		return false
	var buckets: Dictionary = record.get("buckets_ms", {}) if record.get("buckets_ms", {}) is Dictionary else {}
	for key in ["inspect_selected_slot", "latest_loadable_summary", "detached_live_payload", "normalized_live_summary", "current_context", "detached_normalization", "detached_read_scope_begin", "shared_recap_context", "shared_progress_context", "shared_watch_context", "save_copy", "return_copy", "current_save_recap", "play_check", "recap_surfaces", "stored_resume_recaps"]:
		if not buckets.has(key):
			_finish_fail("%s omitted profile bucket %s." % [label, key], record)
			return false
	if float(record.get("total_ms", 99999.0)) >= 1000.0:
		_finish_fail("%s exceeded the 1000ms save-surface budget." % label, record)
		return false
	if expected_alias >= 0:
		var metadata: Dictionary = record.get("metadata", {}) if record.get("metadata", {}) is Dictionary else {}
		if bool(metadata.get("stored_recap_alias_reused", false)) != (expected_alias == 1):
			_finish_fail("%s reported the wrong stored-recap alias policy." % label, record)
			return false
	return true

func _assert_current_surface_alias(session, slot: int, expected_alias: bool, label: String) -> bool:
	var surface: Dictionary = SaveService.build_in_session_save_surface(session, slot)
	var recaps_equal: bool = surface.get("slot_resume_recap") == surface.get("latest_resume_recap")
	if recaps_equal != expected_alias:
		_finish_fail("%s stored recaps had the wrong exact alias equality." % label, surface)
		return false
	return true

func _assert_normalization_profile(record: Dictionary, expected_normalized: bool, expected_fallback: bool, label: String) -> bool:
	var metadata: Dictionary = record.get("metadata", {}) if record.get("metadata", {}) is Dictionary else {}
	if bool(metadata.get("detached_was_runtime_normalized", not expected_normalized)) != expected_normalized or bool(metadata.get("detached_normalization_fallback", not expected_fallback)) != expected_fallback:
		_finish_fail("%s reported the wrong detached normalization path." % label, record)
		return false
	return true

func _direct_legacy_surface(session, slot: int) -> Dictionary:
	var direct_session := SessionStateStoreScript.SessionData.new()
	direct_session.from_dict(session.to_dict())
	return SaveService.validation_build_in_session_save_surface_direct_legacy(direct_session, slot)

func _small_town_session():
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var town := _first_player_town(session)
	if town.is_empty():
		_finish_fail("Small Town parity fixture has no player town.")
		return null
	_give_resources(session)
	_move_active_hero_to_town(session, town)
	var visit: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	if not bool(visit.get("ok", false)):
		_finish_fail("Small Town parity fixture could not enter town.", visit)
		return null
	session.game_state = "town"
	return session

func _small_context_session(context: String):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	match context:
		"overworld":
			session.game_state = "overworld"
		"battle":
			var encounter := _first_unresolved_encounter(session)
			if encounter.is_empty():
				_finish_fail("Battle parity fixture has no encounter.")
				return null
			session.battle = BattleRules.create_battle_payload(session, encounter)
			session.game_state = "battle"
		"outcome":
			session.battle = {}
			session.scenario_status = "victory"
			session.scenario_summary = "Focused explicit save-surface outcome."
			session.flags["scenario_result"] = "victory"
			session.game_state = "outcome"
		"editor":
			session.game_state = "overworld"
			session.flags["editor_working_copy"] = true
		"stale_route":
			var encounter := _first_unresolved_encounter(session)
			if encounter.is_empty():
				_finish_fail("Stale-route parity fixture has no encounter.")
				return null
			session.battle = BattleRules.create_battle_payload(session, encounter)
			session.game_state = "overworld"
		_:
			_finish_fail("Unknown parity context %s." % context)
			return null
	return session

func _perform_one_town_action(session) -> Dictionary:
	for action_value in TownRules.get_build_actions(session):
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if bool(action.get("disabled", true)):
			continue
		var full_action_id := String(action.get("id", ""))
		var action_id := full_action_id.trim_prefix("build:")
		var before: Dictionary = TownRules.town_action_consequence_signature(session)
		var result: Dictionary = TownRules.build_active_town(session, action_id)
		var recap: Dictionary = TownRules.build_town_action_recap(session, "build", full_action_id, action, result, before)
		if bool(recap.get("active", false)):
			session.flags["last_town_action_recap"] = recap.duplicate(true)
		result["action_id"] = full_action_id
		result["recap"] = recap
		return result
	return {}

func _mutate_nested_enemy_state(session) -> Dictionary:
	EnemyTurnRules.normalize_enemy_states(session)
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		if not (states[index] is Dictionary):
			continue
		var state: Dictionary = states[index]
		var faction_id := String(state.get("faction_id", ""))
		if faction_id == "":
			continue
		var treasury: Dictionary = state.get("treasury", {}).duplicate(true) if state.get("treasury", {}) is Dictionary else {}
		var prior_gold := int(treasury.get("gold", 0))
		var prior_pressure := int(state.get("pressure", 0))
		treasury["gold"] = prior_gold + 17
		state["treasury"] = treasury
		state["pressure"] = prior_pressure + 1
		states[index] = state
		session.overworld["enemy_states"] = states
		OverworldRules.mark_runtime_normalized_transition_state(session)
		if not OverworldRules.is_runtime_session_normalized(session):
			_finish_fail("Nested enemy-state mutation did not retain trusted runtime-normalized identity.")
			return {}
		return {
			"faction_id": faction_id,
			"gold_before": prior_gold,
			"gold_after": prior_gold + 17,
			"pressure_before": prior_pressure,
			"pressure_after": prior_pressure + 1,
		}
	_finish_fail("Nested enemy-state parity fixture has no normalized faction state.")
	return {}

func _assert_command_risk_summary_fast_path() -> Dictionary:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	EnemyTurnRules.normalize_enemy_states(session)
	var states: Array = session.overworld.get("enemy_states", []) if session.overworld.get("enemy_states", []) is Array else []
	for index in range(states.size()):
		if states[index] is Dictionary:
			var state: Dictionary = states[index]
			state["pressure"] = 0
			state["posture"] = "probing"
			states[index] = state
	session.overworld["enemy_states"] = states
	var resolved: Array = []
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) != "":
			resolved.append(String(encounter.get("placement_id", "")))
	session.overworld["resolved_encounters"] = resolved
	session.overworld["towns"] = []
	session.overworld["resource_nodes"] = []
	OverworldRules.mark_runtime_normalized_transition_state(session)
	var full_surface: Dictionary = OverworldRules.describe_command_risk_surfaces(session)
	var full_risk: String = String(full_surface.get("risk", ""))
	var full_lines: PackedStringArray = full_risk.split("\n", false)
	var expected_summary: String = String(full_lines[1]) if full_lines.size() > 1 else ""
	var authority_before: Dictionary = session.to_dict().duplicate(true)
	var actual_summary: String = OverworldRules.describe_command_risk_summary_from_normalized_session(session)
	var authority_after: Dictionary = session.to_dict().duplicate(true)
	var steady_copy := "Steady watch | No concrete next-day break is signaled from the current frontier watch."
	if expected_summary != steady_copy or actual_summary != expected_summary or authority_after != authority_before:
		_finish_fail("Steady command-risk summary fast path diverged or mutated authority.", {
			"expected": expected_summary,
			"actual": actual_summary,
			"difference": _first_difference(authority_before, authority_after),
		})
		return {}
	var items: Array = [
		{"key": "town:gamma", "severity": 5, "summary": "Shared front exposed", "gate": false},
		{"key": "logistics:alpha", "severity": 5, "summary": "Shared front exposed", "gate": false},
		{"key": "objective:beta", "severity": 5, "summary": "Objective near trigger", "gate": true},
		{"key": "posture:delta", "severity": 4, "summary": "Raid window opening", "gate": false},
		{"key": "field:epsilon", "severity": 3, "summary": "Active command exposed", "gate": false},
	]
	var reduction: Dictionary = OverworldRules._reduce_command_risk_items(items)
	var selected: Array = reduction.get("selected_items", []) if reduction.get("selected_items", []) is Array else []
	var selected_keys: Array = []
	for item in selected:
		if item is Dictionary:
			selected_keys.append(String(item.get("key", "")))
	var expected_keys: Array = ["logistics:alpha", "objective:beta", "town:gamma"]
	var expected_reduction_summary := "Severe risk | Shared front exposed | Objective near trigger"
	if selected_keys != expected_keys or selected.size() != 3 \
			or int(reduction.get("severity", 0)) != 5 \
			or String(reduction.get("summary", "")) != expected_reduction_summary \
			or String(reduction.get("summary", "")).count("Shared front exposed") != 1 \
			or not bool(reduction.get("gate_end_turn", false)):
		_finish_fail("Command-risk reducer family/order/top3/dedupe/grade/gate contract diverged.", {
			"reduction": reduction,
			"selected_keys": selected_keys,
		})
		return {}
	return {
		"steady": {
			"summary": actual_summary,
			"full_risk_exact": true,
			"full_forecast_data": full_surface.get("forecast_data", {}),
			"authority_exact": true,
		},
		"family_reducer": {
			"all_keys": ["town:gamma", "logistics:alpha", "objective:beta", "posture:delta", "field:epsilon"],
			"selected_keys": selected_keys,
			"summary": expected_reduction_summary,
			"severity": 5,
			"top3": true,
			"duplicate_summary_deduped": true,
			"grade_exact": true,
			"selected_gate": true,
		},
	}

func _generated_large_session():
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		ScenarioSelectRulesScript.build_random_map_player_config(
			GENERATED_LARGE_SEED,
			"translated_rmg_template_042_v1",
			"translated_rmg_profile_042_v1",
			4,
			"land",
			false,
			"homm3_large"
		),
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	if not bool(setup.get("ok", false)):
		_finish_fail("Generated Large setup failed.", setup)
		return null
	return ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)

func _first_player_town(session) -> Dictionary:
	for value in session.overworld.get("towns", []):
		if value is Dictionary and String(value.get("owner", "")) == "player":
			return value
	return {}

func _first_unresolved_encounter(session) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and not bool(value.get("resolved", false)):
			return value
	return {}

func _give_resources(session) -> void:
	var resources: Dictionary = session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}
	for resource_id in ["gold", "wood", "ore"]:
		resources[resource_id] = 99999
	session.overworld["resources"] = resources

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["x"] = int(town.get("x", 0))
	hero["y"] = int(town.get("y", 0))
	session.overworld["hero"] = hero
	var active_hero_id := String(hero.get("id", ""))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and (active_hero_id == "" or String(heroes[index].get("id", "")) == active_hero_id):
			heroes[index]["x"] = int(town.get("x", 0))
			heroes[index]["y"] = int(town.get("y", 0))
			break
	session.overworld["player_heroes"] = heroes

func _selection_authority(session, shell: Node) -> Dictionary:
	return {
		"session": JSON.stringify(session.to_dict()),
		"files": _file_states(AUTHORITY_PATHS),
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
		"routes": _route_snapshot(session, shell),
		"focus_instance": _focus_owner_instance_id(),
	}

func _route_snapshot(session, shell: Node) -> Dictionary:
	var current_scene := get_tree().current_scene
	return {
		"current_scene_instance_id": current_scene.get_instance_id() if current_scene != null else 0,
		"shell_instance_id": shell.get_instance_id(),
		"shell_inside_tree": shell.is_inside_tree(),
		"scenario_id": session.scenario_id,
		"scenario_status": session.scenario_status,
		"game_state": session.game_state,
		"battle_entry": AppRouter.validation_battle_entry_snapshot(),
		"outcome": AppRouter.validation_scenario_outcome_route_snapshot(),
		"return": AppRouter.validation_active_play_return_snapshot(),
		"quit": AppRouter.validation_safe_quit_snapshot(),
	}

func _surface_copy_signature(surface: Dictionary) -> Dictionary:
	return {
		"field_count": surface.keys().size(),
		"selected_slot": int(surface.get("selected_slot", 0)),
		"current_context": String(surface.get("current_context", "")),
		"play_check": String(surface.get("play_check", "")),
		"save_check": String(surface.get("save_check", "")),
		"save_handoff_brief": String(surface.get("save_handoff_brief", "")),
		"menu_button_label": String(surface.get("menu_button_label", "")),
	}

func _last_save_surface_record(records: Array) -> Dictionary:
	for index in range(records.size() - 1, -1, -1):
		var record = records[index]
		if record is Dictionary and String(record.get("surface", "")) == "save" and String(record.get("event", "")) == "build_in_session_save_surface":
			return record
	return {}

func _runtime_save_record_count(records: Array) -> int:
	var count := 0
	for record in records:
		if record is Dictionary and String(record.get("surface", "")) == "save" and String(record.get("event", "")) == "runtime_save":
			count += 1
	return count

func _last_town_save_record(records: Array) -> Dictionary:
	for index in range(records.size() - 1, -1, -1):
		var record = records[index]
		if record is Dictionary and String(record.get("surface", "")) == "town" and String(record.get("event", "")) == "save":
			return record
	return {}

func _warm_summary_cache() -> void:
	SaveService.inspect_autosave()
	for slot in [1, 2, 3]:
		SaveService.inspect_manual_slot(slot)

func _file_states(paths: Array) -> Dictionary:
	var result := {}
	for path_value in paths:
		var path := String(path_value)
		result[path] = _file_state(path)
		for artifact in ["%s.candidate" % path, "%s.backup" % path]:
			result[artifact] = _file_state(artifact)
	return result

func _file_state(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "size": -1, "sha256": "", "modified": 0}
	return {
		"exists": true,
		"size": FileAccess.get_size(path),
		"sha256": FileAccess.get_sha256(path),
		"modified": FileAccess.get_modified_time(path),
	}

func _artifacts_absent(path: String) -> bool:
	return not FileAccess.file_exists("%s.candidate" % path) and not FileAccess.file_exists("%s.backup" % path)

func _clear_paths(paths: Array) -> void:
	for path_value in paths:
		var path := String(path_value)
		for candidate in [path, "%s.candidate" % path, "%s.backup" % path]:
			if FileAccess.file_exists(candidate):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))

func _capture_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "bytes": PackedByteArray()}
	var file := FileAccess.open(path, FileAccess.READ)
	return {"exists": file != null, "bytes": file.get_buffer(file.get_length()) if file != null else PackedByteArray()}

func _write_file_bytes(path: String, bytes: PackedByteArray) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	return file.get_error() == OK

func _restore_original_files() -> void:
	_clear_paths(AUTHORITY_PATHS)
	for path_value in AUTHORITY_PATHS:
		var path := String(path_value)
		var state: Dictionary = _original_files.get(path, {}) if _original_files.get(path, {}) is Dictionary else {}
		if not bool(state.get("exists", false)):
			continue
		var original := _capture_original_bytes(path)
		if original.is_empty():
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(original)

func _capture_original_bytes(path: String) -> PackedByteArray:
	var state: Dictionary = _original_files.get(path, {}) if _original_files.get(path, {}) is Dictionary else {}
	var bytes_value = state.get("bytes", PackedByteArray())
	return bytes_value if bytes_value is PackedByteArray else PackedByteArray()

func _capture_original_file_states() -> Dictionary:
	var result := {}
	for path_value in AUTHORITY_PATHS:
		var path := String(path_value)
		result[path] = _capture_file(path)
	return result

func _focus_owner_instance_id() -> int:
	var owner := get_viewport().gui_get_focus_owner()
	return owner.get_instance_id() if owner != null else 0

func _press_joypad_button(button_index: int) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.button_index = button_index
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventJoypadButton.new()
	released.button_index = button_index
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().process_frame

func _settle(frames: int = 2) -> void:
	for _index in range(frames):
		await get_tree().process_frame

func _first_difference(expected: Variant, actual: Variant, path: String = "$") -> Dictionary:
	if typeof(expected) != typeof(actual):
		return {"path": path, "expected_type": type_string(typeof(expected)), "actual_type": type_string(typeof(actual))}
	if expected is Dictionary:
		var expected_dict: Dictionary = expected
		var actual_dict: Dictionary = actual
		var expected_keys := expected_dict.keys()
		var actual_keys := actual_dict.keys()
		expected_keys.sort()
		actual_keys.sort()
		if expected_keys != actual_keys:
			return {"path": path, "expected_keys": expected_keys, "actual_keys": actual_keys}
		for key in expected_keys:
			var nested := _first_difference(expected_dict.get(key), actual_dict.get(key), "%s.%s" % [path, key])
			if not nested.is_empty():
				return nested
		return {}
	if expected is Array:
		var expected_array: Array = expected
		var actual_array: Array = actual
		if expected_array.size() != actual_array.size():
			return {"path": path, "expected_size": expected_array.size(), "actual_size": actual_array.size()}
		for index in range(expected_array.size()):
			var nested := _first_difference(expected_array[index], actual_array[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
		return {}
	if expected != actual:
		return {"path": path, "expected": expected, "actual": actual}
	return {}

func _canonical_dictionary(value: Dictionary) -> Dictionary:
	var parsed = JSON.parse_string(JSON.stringify(value))
	return parsed if parsed is Dictionary else {}

func _finish_success() -> void:
	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "rows": _report_rows})])
	get_tree().quit(0)

func _finish_fail(message: String, details: Variant = {}) -> void:
	_cleanup()
	push_error("%s %s" % [message, JSON.stringify(details)])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "message": message, "details": details})])
	get_tree().quit(1)

func _cleanup() -> void:
	OS.unset_environment(FAILURE_ENV)
	if _previous_failure_env != "":
		OS.set_environment(FAILURE_ENV, _previous_failure_env)
	OS.unset_environment(PROFILE_ENV)
	if _previous_profile_env != "":
		OS.set_environment(PROFILE_ENV, _previous_profile_env)
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()
	_restore_original_files()
	SaveService.validation_clear_summary_cache()
