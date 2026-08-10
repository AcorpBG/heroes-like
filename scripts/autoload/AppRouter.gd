class_name HeroesAppRouter
extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const TownRulesScript = preload("res://scripts/core/TownRules.gd")
const ProfileLogScript = preload("res://scripts/core/ProfileLog.gd")

const MAIN_MENU_SCENE := "res://scenes/menus/MainMenu.tscn"
const SCENARIO_OUTCOME_SCENE := "res://scenes/results/ScenarioOutcomeShell.tscn"
const OVERWORLD_SCENE := "res://scenes/overworld/OverworldShell.tscn"
const BATTLE_SCENE := "res://scenes/battle/BattleShell.tscn"
const TOWN_SCENE := "res://scenes/town/TownShell.tscn"
const MAP_EDITOR_SCENE := "res://scenes/editor/MapEditorShell.tscn"
const MAIN_MENU_PACKED_SCENE := preload("res://scenes/menus/MainMenu.tscn")
const SCENARIO_OUTCOME_PACKED_SCENE := preload("res://scenes/results/ScenarioOutcomeShell.tscn")
const OVERWORLD_PACKED_SCENE := preload("res://scenes/overworld/OverworldShell.tscn")
const BATTLE_PACKED_SCENE := preload("res://scenes/battle/BattleShell.tscn")
const TOWN_PACKED_SCENE := preload("res://scenes/town/TownShell.tscn")
const MAP_EDITOR_PACKED_SCENE := preload("res://scenes/editor/MapEditorShell.tscn")
const AUTOSAVE_DIRTY_FLAG := "runtime_autosave_dirty"
const AUTOSAVE_PENDING_INTENT_FLAG := "runtime_autosave_pending_intent"
const AUTOSAVE_PENDING_REASON_FLAG := "runtime_autosave_pending_reason"
const AUTOSAVE_PENDING_ROUTE_FLAG := "runtime_autosave_pending_route"
const AUTOSAVE_PENDING_GAME_STATE_FLAG := "runtime_autosave_pending_game_state"
const AUTOSAVE_PENDING_COUNT_FLAG := "runtime_autosave_pending_count"
const AUTOSAVE_PENDING_UNIX_FLAG := "runtime_autosave_pending_unix"
const SAFE_QUIT_FAILURE_TITLE := "Unable to close safely"
const SAFE_QUIT_FAILURE_MESSAGE := "The current expedition could not be saved, so the game will remain open. Try saving again or export a support bundle from Settings if the problem continues."

var _menu_notice := ""
var _active_overworld_handoff_profile := {}
var _last_overworld_handoff_profile := {}
var _safe_quit_in_progress := false
var _safe_quit_completed := false
var _safe_quit_request_count := 0
var _safe_quit_save_attempt_count := 0
var _safe_quit_attempt_count := 0
var _safe_quit_suppressed_count := 0
var _safe_quit_last_source := ""
var _safe_quit_last_result := {}
var _safe_quit_visible_error := ""
var _validation_quit_suppressed := false
var _validation_safe_quit_reentrant_probe := false
var _validation_safe_quit_reentrant_result := {}

func _ready() -> void:
	# Native window close requests must pass through the same transactional save
	# boundary as the menu Exit command. Explicit SceneTree.quit() calls used by
	# headless harnesses remain unaffected.
	get_tree().auto_accept_quit = false
	var root_window := get_tree().root
	if root_window != null and not root_window.close_requested.is_connected(_on_root_window_close_requested):
		root_window.close_requested.connect(_on_root_window_close_requested)

func _exit_tree() -> void:
	var scene_tree := get_tree()
	if scene_tree == null:
		return
	var root_window := scene_tree.root
	if root_window != null and root_window.close_requested.is_connected(_on_root_window_close_requested):
		root_window.close_requested.disconnect(_on_root_window_close_requested)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_safe_quit("window_close")

func _on_root_window_close_requested() -> void:
	request_safe_quit("window_close")

func request_safe_quit(source: String = "application") -> Dictionary:
	var normalized_source := source.strip_edges().left(64)
	if normalized_source == "":
		normalized_source = "application"
	_safe_quit_request_count += 1
	if _safe_quit_in_progress:
		return {
			"ok": false,
			"quit_requested": false,
			"source": normalized_source,
			"reason": "in_progress",
			"message": "Application close is already in progress.",
		}
	if _safe_quit_completed:
		return {
			"ok": false,
			"quit_requested": false,
			"source": normalized_source,
			"reason": "completed",
			"message": "Application close was already requested.",
		}

	_safe_quit_last_source = normalized_source
	_safe_quit_in_progress = true
	_safe_quit_visible_error = ""
	if _validation_safe_quit_reentrant_probe:
		_validation_safe_quit_reentrant_probe = false
		_validation_safe_quit_reentrant_result = request_safe_quit("validation_reentrant")

	if SessionState.has_playable_session():
		var session := SessionState.ensure_active_session()
		_safe_quit_save_attempt_count += 1
		var save_result: Dictionary = SaveService.save_runtime_autosave_session(session)
		if not bool(save_result.get("ok", false)):
			var save_message := String(save_result.get("message", "Save write failed.")).strip_edges()
			_safe_quit_visible_error = SAFE_QUIT_FAILURE_MESSAGE
			RuntimeIssueLog.emit_error(
				"application",
				"safe_quit_autosave_failed",
				SAFE_QUIT_FAILURE_MESSAGE,
				{
					"source": normalized_source,
					"save_message": save_message.left(240),
				},
				session
			)
			_safe_quit_last_result = {
				"ok": false,
				"saved": false,
				"quit_requested": false,
				"source": normalized_source,
				"reason": "autosave_failed",
				"message": SAFE_QUIT_FAILURE_MESSAGE,
			}
			_safe_quit_in_progress = false
			if DisplayServer.get_name().to_lower() != "headless":
				OS.alert(SAFE_QUIT_FAILURE_MESSAGE, SAFE_QUIT_FAILURE_TITLE)
			return _safe_quit_last_result.duplicate(true)

		_safe_quit_last_result = {
			"ok": true,
			"saved": true,
			"quit_requested": true,
			"source": normalized_source,
			"reason": "saved",
			"message": "Expedition saved. Closing game.",
			"path": String(save_result.get("path", "")),
		}
	else:
		_safe_quit_last_result = {
			"ok": true,
			"saved": false,
			"quit_requested": true,
			"source": normalized_source,
			"reason": "no_active_session",
			"message": "Closing game.",
		}

	_safe_quit_completed = true
	_safe_quit_in_progress = false
	_safe_quit_attempt_count += 1
	if _validation_quit_suppressed:
		_safe_quit_suppressed_count += 1
	else:
		get_tree().quit()
	return _safe_quit_last_result.duplicate(true)

func validation_set_quit_suppressed(suppressed: bool) -> void:
	_validation_quit_suppressed = suppressed

func validation_set_safe_quit_reentrant_probe(enabled: bool) -> void:
	_validation_safe_quit_reentrant_probe = enabled

func validation_reset_safe_quit_state() -> void:
	_safe_quit_in_progress = false
	_safe_quit_completed = false
	_safe_quit_request_count = 0
	_safe_quit_save_attempt_count = 0
	_safe_quit_attempt_count = 0
	_safe_quit_suppressed_count = 0
	_safe_quit_last_source = ""
	_safe_quit_last_result = {}
	_safe_quit_visible_error = ""
	_validation_safe_quit_reentrant_probe = false
	_validation_safe_quit_reentrant_result = {}

func validation_safe_quit_snapshot() -> Dictionary:
	return {
		"request_count": _safe_quit_request_count,
		"save_attempt_count": _safe_quit_save_attempt_count,
		"quit_attempt_count": _safe_quit_attempt_count,
		"suppressed_quit_count": _safe_quit_suppressed_count,
		"in_progress": _safe_quit_in_progress,
		"completed": _safe_quit_completed,
		"last_result": _safe_quit_last_result.duplicate(true),
		"last_source": _safe_quit_last_source,
		"visible_error": _safe_quit_visible_error,
		"reentrant_result": _validation_safe_quit_reentrant_result.duplicate(true),
	}

func go_to_main_menu() -> void:
	var started := ProfileLogScript.begin_usec()
	var buckets := {}
	var autosave_metadata := {}
	if SessionState.has_playable_session():
		var save_started := ProfileLogScript.begin_usec()
		var autosave_result := _autosave_active_session(SessionState.ensure_active_session())
		buckets["save_before_transition"] = ProfileLogScript.elapsed_ms(save_started)
		_menu_notice = String(autosave_result.get("message", ""))
		autosave_metadata = {
			"autosave_deferred_or_skipped_reason": "forced_save_required_main_menu",
			"autosave_forced": true,
			"autosave_ok": bool(autosave_result.get("ok", false)),
		}
	else:
		_menu_notice = ""
	var scene_started := ProfileLogScript.begin_usec()
	_change_scene(MAIN_MENU_SCENE)
	buckets["scene_change"] = ProfileLogScript.elapsed_ms(scene_started)
	var metadata := {
		"target_scene": MAIN_MENU_SCENE,
		"has_playable_session": SessionState.has_playable_session(),
	}
	metadata.merge(autosave_metadata, true)
	ProfileLogScript.emit_general("router", "scene_transition", "go_to_main_menu", ProfileLogScript.elapsed_ms(started), buckets, metadata, SessionState.ensure_active_session())

func return_to_main_menu_from_active_play() -> void:
	if SessionState.request_editor_return_from_active_play():
		_menu_notice = ""
		_change_scene(MAP_EDITOR_SCENE)
		return
	go_to_main_menu()

func go_to_overworld() -> void:
	var started := ProfileLogScript.begin_usec()
	var buckets := {}
	_note_overworld_handoff_step("go_to_overworld_enter")
	if not SessionState.has_playable_session():
		push_warning("Cannot enter overworld without an active scenario session.")
		_note_overworld_handoff_step("go_to_overworld_missing_session")
		var scene_started := ProfileLogScript.begin_usec()
		_change_scene(MAIN_MENU_SCENE)
		buckets["scene_change"] = ProfileLogScript.elapsed_ms(scene_started)
		ProfileLogScript.emit_general("router", "scene_transition", "go_to_overworld_missing_session", ProfileLogScript.elapsed_ms(started), buckets, {
			"target_scene": MAIN_MENU_SCENE,
			"route": "missing_session",
		}, null)
		return

	var session := SessionState.ensure_active_session()
	if session.scenario_status != "in_progress":
		_note_overworld_handoff_step("go_to_overworld_outcome_redirect")
		ProfileLogScript.emit_general("router", "scene_transition", "go_to_overworld_outcome_redirect", ProfileLogScript.elapsed_ms(started), buckets, {
			"target_scene": SCENARIO_OUTCOME_SCENE,
		}, session)
		go_to_scenario_outcome()
		return
	var state_started := ProfileLogScript.begin_usec()
	session.game_state = "overworld"
	_note_overworld_handoff_step("go_to_overworld_state_set")
	OverworldRules.clear_active_town_visit(session)
	_note_overworld_handoff_step("go_to_overworld_town_visit_cleared")
	OverworldRules.mark_runtime_normalized_transition_state(session)
	buckets["state_handoff"] = ProfileLogScript.elapsed_ms(state_started)
	var autosave_intent := {}
	if _should_defer_initial_generated_overworld_autosave(session):
		autosave_intent = _record_transition_autosave_intent(session, "go_to_overworld", "generated_initial_overworld_deferred")
		session.flags["generated_overworld_deferred_autosave_pending"] = true
		_note_overworld_handoff_step("go_to_overworld_autosave_deferred")
	else:
		autosave_intent = _record_transition_autosave_skip(session, "go_to_overworld", "manual_or_end_turn_only")
		_note_overworld_handoff_step("go_to_overworld_autosave_skipped_manual_or_end_turn_only")
	buckets["save_before_transition"] = 0.0
	_note_overworld_handoff_step("go_to_overworld_change_scene_start")
	var scene_started := ProfileLogScript.begin_usec()
	_change_scene(OVERWORLD_SCENE)
	buckets["scene_change"] = ProfileLogScript.elapsed_ms(scene_started)
	_note_overworld_handoff_step("go_to_overworld_change_scene_requested")
	var metadata := {
		"target_scene": OVERWORLD_SCENE,
		"generated_autosave_deferred": bool(session.flags.get("generated_overworld_deferred_autosave_pending", false)),
		"save_before_transition_skipped": true,
	}
	metadata.merge(autosave_intent, true)
	ProfileLogScript.emit_general("router", "scene_transition", "go_to_overworld", ProfileLogScript.elapsed_ms(started), buckets, metadata, session)

func go_to_town() -> void:
	var started := ProfileLogScript.begin_usec()
	var buckets := {}
	if not SessionState.has_playable_session():
		push_warning("Cannot enter a town without an active scenario session.")
		var scene_started := ProfileLogScript.begin_usec()
		_change_scene(MAIN_MENU_SCENE)
		buckets["scene_change"] = ProfileLogScript.elapsed_ms(scene_started)
		ProfileLogScript.emit_general("router", "scene_transition", "go_to_town_missing_session", ProfileLogScript.elapsed_ms(started), buckets, {"target_scene": MAIN_MENU_SCENE}, null)
		return
	if not TownRulesScript.can_visit_active_town_bridge(SessionState.ensure_active_session()):
		push_warning("Cannot enter a town without an active controlled town.")
		ProfileLogScript.emit_general("router", "scene_transition", "go_to_town_invalid_visit", ProfileLogScript.elapsed_ms(started), buckets, {"target_scene": OVERWORLD_SCENE}, SessionState.ensure_active_session())
		go_to_overworld()
		return

	var session := SessionState.ensure_active_session()
	if session.scenario_status != "in_progress":
		ProfileLogScript.emit_general("router", "scene_transition", "go_to_town_outcome_redirect", ProfileLogScript.elapsed_ms(started), buckets, {"target_scene": SCENARIO_OUTCOME_SCENE}, session)
		go_to_scenario_outcome()
		return
	var state_started := ProfileLogScript.begin_usec()
	session.game_state = "town"
	OverworldRules.mark_runtime_normalized_transition_state(session)
	buckets["state_handoff"] = ProfileLogScript.elapsed_ms(state_started)
	var autosave_intent := _record_transition_autosave_skip(session, "go_to_town", "manual_or_end_turn_only")
	buckets["save_before_transition"] = 0.0
	var scene_started := ProfileLogScript.begin_usec()
	_change_scene(TOWN_SCENE)
	buckets["scene_change"] = ProfileLogScript.elapsed_ms(scene_started)
	var metadata := {
		"target_scene": TOWN_SCENE,
		"save_before_transition_skipped": true,
	}
	metadata.merge(autosave_intent, true)
	ProfileLogScript.emit_general("router", "scene_transition", "go_to_town", ProfileLogScript.elapsed_ms(started), buckets, metadata, session)

func go_to_battle() -> void:
	var started := ProfileLogScript.begin_usec()
	var buckets := {}
	if not SessionState.has_playable_session():
		push_warning("Cannot enter battle without an active scenario session.")
		var scene_started := ProfileLogScript.begin_usec()
		_change_scene(MAIN_MENU_SCENE)
		buckets["scene_change"] = ProfileLogScript.elapsed_ms(scene_started)
		ProfileLogScript.emit_general("router", "scene_transition", "go_to_battle_missing_session", ProfileLogScript.elapsed_ms(started), buckets, {"target_scene": MAIN_MENU_SCENE}, null)
		return
	if not SessionState.has_battle_state():
		push_warning("Cannot enter battle without an active battle payload.")
		ProfileLogScript.emit_general("router", "scene_transition", "go_to_battle_missing_payload", ProfileLogScript.elapsed_ms(started), buckets, {"target_scene": OVERWORLD_SCENE}, SessionState.ensure_active_session())
		go_to_overworld()
		return

	var session := SessionState.ensure_active_session()
	if session.scenario_status != "in_progress":
		ProfileLogScript.emit_general("router", "scene_transition", "go_to_battle_outcome_redirect", ProfileLogScript.elapsed_ms(started), buckets, {"target_scene": SCENARIO_OUTCOME_SCENE}, session)
		go_to_scenario_outcome()
		return
	var state_started := ProfileLogScript.begin_usec()
	session.game_state = "battle"
	buckets["state_handoff"] = ProfileLogScript.elapsed_ms(state_started)
	var save_started := ProfileLogScript.begin_usec()
	var autosave_result := _autosave_active_session(session, false)
	buckets["save_before_transition"] = ProfileLogScript.elapsed_ms(save_started)
	var scene_started := ProfileLogScript.begin_usec()
	_change_scene(BATTLE_SCENE)
	buckets["scene_change"] = ProfileLogScript.elapsed_ms(scene_started)
	ProfileLogScript.emit_general("router", "scene_transition", "go_to_battle", ProfileLogScript.elapsed_ms(started), buckets, {
		"target_scene": BATTLE_SCENE,
		"battle_stack_count": _battle_stack_count(session),
		"autosave_deferred_or_skipped_reason": "forced_save_required_battle",
		"autosave_forced": true,
		"autosave_ok": bool(autosave_result.get("ok", false)),
	}, session)

func go_to_scenario_outcome() -> void:
	if not SessionState.has_playable_session():
		_change_scene(MAIN_MENU_SCENE)
		return
	var session := SessionState.ensure_active_session()
	if session.scenario_status == "in_progress":
		go_to_overworld()
		return
	session.game_state = "outcome"
	SaveService.save_runtime_autosave_session(session)
	_change_scene(SCENARIO_OUTCOME_SCENE)

func go_to_map_editor() -> void:
	_change_scene(MAP_EDITOR_SCENE)

func boot() -> void:
	var started := ProfileLogScript.begin_usec()
	go_to_main_menu()
	ProfileLogScript.emit_general("router", "boot", "boot", ProfileLogScript.elapsed_ms(started), {}, {
		"target_scene": MAIN_MENU_SCENE,
	}, SessionState.ensure_active_session())

func resume_active_session() -> void:
	if not SessionState.has_playable_session():
		go_to_main_menu()
		return

	var session := SessionState.ensure_active_session()
	if session.scenario_status != "in_progress":
		go_to_scenario_outcome()
		return

	match SaveService.resume_target_for_session(session):
		"battle":
			go_to_battle()
		"town":
			go_to_town()
		"outcome":
			go_to_scenario_outcome()
		_:
			go_to_overworld()

func resume_summary(summary: Dictionary) -> bool:
	if summary.is_empty():
		go_to_main_menu()
		return false
	var session = SaveService.restore_session_from_summary(summary)
	if session == null:
		push_warning("The selected save could not be restored.")
		return false
	SessionState.active_session = session
	resume_active_session()
	return true

func resume_latest_session() -> bool:
	return resume_summary(SaveService.latest_loadable_summary())

func save_active_session_to_selected_manual_slot() -> Dictionary:
	return save_active_session_to_manual_slot(SaveService.get_selected_manual_slot())

func save_active_session_to_manual_slot(manual_slot: int) -> Dictionary:
	if not SessionState.has_playable_session():
		return {"ok": false, "message": "No active expedition is available to save.", "summary": {}}
	if not SaveService.get_manual_slot_ids().has(manual_slot):
		return {"ok": false, "message": "Choose a valid manual save slot.", "summary": {}}
	return SaveService.save_runtime_manual_session(SessionState.ensure_active_session(), manual_slot)

func active_manual_save_action(manual_slot: int = -1) -> Dictionary:
	var selected_slot := SaveService.get_selected_manual_slot() if manual_slot < 0 else manual_slot
	var session = SessionState.ensure_active_session() if SessionState.has_playable_session() else null
	return SaveService.build_manual_save_action(session, selected_slot)

func active_save_surface() -> Dictionary:
	if not SessionState.has_playable_session():
		return SaveService.build_in_session_save_surface(null)
	return SaveService.build_in_session_save_surface(
		SessionState.ensure_active_session(),
		SaveService.get_selected_manual_slot()
	)

func consume_menu_notice() -> String:
	var notice := _menu_notice
	_menu_notice = ""
	return notice

func begin_overworld_handoff_profile(reason: String, details: Dictionary = {}) -> void:
	_active_overworld_handoff_profile = {
		"active": true,
		"reason": reason,
		"started_msec": Time.get_ticks_msec(),
		"started_usec": Time.get_ticks_usec(),
		"steps": [],
		"details": details.duplicate(true),
		"debug_print": bool(details.get("debug_print", false)),
	}
	_note_overworld_handoff_step("profile_started")

func note_overworld_handoff_step(step_name: String, details: Dictionary = {}) -> void:
	_note_overworld_handoff_step(step_name, details)

func finish_overworld_handoff_profile(details: Dictionary = {}) -> Dictionary:
	if _active_overworld_handoff_profile.is_empty():
		return _last_overworld_handoff_profile.duplicate(true)
	_note_overworld_handoff_step("profile_finished", details)
	_active_overworld_handoff_profile["active"] = false
	_active_overworld_handoff_profile["total_ms"] = _profile_elapsed_ms(_active_overworld_handoff_profile)
	_active_overworld_handoff_profile["total_precise_ms"] = _profile_elapsed_precise_ms(_active_overworld_handoff_profile)
	_last_overworld_handoff_profile = _active_overworld_handoff_profile.duplicate(true)
	_active_overworld_handoff_profile = {}
	_emit_overworld_handoff_profile_record(_last_overworld_handoff_profile)
	return _last_overworld_handoff_profile.duplicate(true)

func validation_latest_overworld_handoff_profile() -> Dictionary:
	if not _active_overworld_handoff_profile.is_empty():
		return _active_overworld_handoff_profile.duplicate(true)
	return _last_overworld_handoff_profile.duplicate(true)

func validation_prepare_overworld_handoff_without_scene_change() -> Dictionary:
	if not SessionState.has_playable_session():
		return {"ok": false, "reason": "missing_session"}
	var session := SessionState.ensure_active_session()
	if session.scenario_status != "in_progress":
		return {"ok": false, "reason": "scenario_not_in_progress"}
	_note_overworld_handoff_step("go_to_overworld_enter")
	session.game_state = "overworld"
	_note_overworld_handoff_step("go_to_overworld_state_set")
	OverworldRules.clear_active_town_visit(session)
	_note_overworld_handoff_step("go_to_overworld_town_visit_cleared")
	OverworldRules.mark_runtime_normalized_transition_state(session)
	var autosave_intent := {}
	if _should_defer_initial_generated_overworld_autosave(session):
		autosave_intent = _record_transition_autosave_intent(session, "go_to_overworld", "generated_initial_overworld_deferred")
		session.flags["generated_overworld_deferred_autosave_pending"] = true
		_note_overworld_handoff_step("go_to_overworld_autosave_deferred")
	else:
		autosave_intent = _record_transition_autosave_skip(session, "go_to_overworld", "manual_or_end_turn_only")
		_note_overworld_handoff_step("go_to_overworld_autosave_skipped_manual_or_end_turn_only")
	_note_overworld_handoff_step("go_to_overworld_scene_change_skipped_for_validation")
	return {
		"ok": true,
		"deferred_autosave": bool(autosave_intent.get("autosave_deferred", false)),
		"generated_deferred_autosave": bool(session.flags.get("generated_overworld_deferred_autosave_pending", false)),
		"save_before_transition_skipped": true,
		"autosave_intent": autosave_intent,
	}

func validation_prepare_town_handoff_without_scene_change() -> Dictionary:
	if not SessionState.has_playable_session():
		return {"ok": false, "reason": "missing_session"}
	var session := SessionState.ensure_active_session()
	if session.scenario_status != "in_progress":
		return {"ok": false, "reason": "scenario_not_in_progress"}
	if not TownRulesScript.can_visit_active_town_bridge(session):
		return {"ok": false, "reason": "invalid_town_visit"}
	session.game_state = "town"
	OverworldRules.mark_runtime_normalized_transition_state(session)
	var autosave_intent := _record_transition_autosave_skip(session, "go_to_town", "manual_or_end_turn_only")
	return {
		"ok": true,
		"deferred_autosave": false,
		"save_before_transition_skipped": true,
		"autosave_intent": autosave_intent,
	}

func _change_scene(scene_path: String) -> void:
	var packed_scene := _packed_scene_for_route(scene_path)
	if packed_scene != null:
		var packed_error := get_tree().change_scene_to_packed(packed_scene)
		if packed_error != OK:
			push_error("Failed to change scene to %s (error %d)." % [scene_path, packed_error])
		return
	if not ResourceLoader.exists(scene_path):
		push_error("Scene file is missing: %s" % scene_path)
		return

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Failed to change scene to %s (error %d)." % [scene_path, error])

func _packed_scene_for_route(scene_path: String) -> PackedScene:
	match scene_path:
		MAIN_MENU_SCENE:
			return MAIN_MENU_PACKED_SCENE
		SCENARIO_OUTCOME_SCENE:
			return SCENARIO_OUTCOME_PACKED_SCENE
		OVERWORLD_SCENE:
			return OVERWORLD_PACKED_SCENE
		BATTLE_SCENE:
			return BATTLE_PACKED_SCENE
		TOWN_SCENE:
			return TOWN_PACKED_SCENE
		MAP_EDITOR_SCENE:
			return MAP_EDITOR_PACKED_SCENE
		_:
			return null

func _autosave_active_session(
	session: SessionStateStoreScript.SessionData,
	include_summary: bool = true
) -> Dictionary:
	if session == null or session.scenario_id == "":
		return {"ok": false, "message": "", "summary": {}}
	_clear_transition_autosave_intent(session)
	return SaveService.save_runtime_autosave_session(session, include_summary)

func _record_transition_autosave_intent(
	session: SessionStateStoreScript.SessionData,
	route: String,
	reason: String
) -> Dictionary:
	if session == null:
		return {}
	session.flags[AUTOSAVE_DIRTY_FLAG] = true
	session.flags[AUTOSAVE_PENDING_INTENT_FLAG] = true
	session.flags[AUTOSAVE_PENDING_REASON_FLAG] = reason
	session.flags[AUTOSAVE_PENDING_ROUTE_FLAG] = route
	session.flags[AUTOSAVE_PENDING_GAME_STATE_FLAG] = String(session.game_state)
	session.flags[AUTOSAVE_PENDING_UNIX_FLAG] = Time.get_unix_time_from_system()
	session.flags[AUTOSAVE_PENDING_COUNT_FLAG] = int(session.flags.get(AUTOSAVE_PENDING_COUNT_FLAG, 0)) + 1
	return {
		"autosave_deferred_or_skipped_reason": reason,
		"autosave_deferred": true,
		"autosave_pending_intent": true,
		"autosave_pending_route": route,
		"autosave_pending_game_state": String(session.game_state),
		"autosave_pending_count": int(session.flags.get(AUTOSAVE_PENDING_COUNT_FLAG, 0)),
	}

func _record_transition_autosave_skip(
	session: SessionStateStoreScript.SessionData,
	route: String,
	reason: String
) -> Dictionary:
	if session == null:
		return {}
	_clear_transition_autosave_intent(session)
	return {
		"autosave_deferred_or_skipped_reason": reason,
		"autosave_skipped_reason": reason,
		"autosave_deferred": false,
		"autosave_pending_intent": false,
		"transition_route": route,
		"transition_game_state": String(session.game_state),
	}

func _clear_transition_autosave_intent(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	session.flags.erase(AUTOSAVE_DIRTY_FLAG)
	session.flags.erase(AUTOSAVE_PENDING_INTENT_FLAG)
	session.flags.erase(AUTOSAVE_PENDING_REASON_FLAG)
	session.flags.erase(AUTOSAVE_PENDING_ROUTE_FLAG)
	session.flags.erase(AUTOSAVE_PENDING_GAME_STATE_FLAG)
	session.flags.erase(AUTOSAVE_PENDING_UNIX_FLAG)

func _should_defer_initial_generated_overworld_autosave(session: SessionStateStoreScript.SessionData) -> bool:
	if session == null:
		return false
	if not bool(session.flags.get("generated_random_map", false)):
		return false
	if bool(session.flags.get("generated_overworld_initial_autosave_completed", false)):
		return false
	return true

func _note_overworld_handoff_step(step_name: String, details: Dictionary = {}) -> void:
	if _active_overworld_handoff_profile.is_empty():
		return
	var elapsed := _profile_elapsed_ms(_active_overworld_handoff_profile)
	var steps: Array = _active_overworld_handoff_profile.get("steps", [])
	var previous_elapsed := 0
	if not steps.is_empty():
		var previous: Dictionary = steps[steps.size() - 1] if steps[steps.size() - 1] is Dictionary else {}
		previous_elapsed = int(previous.get("elapsed_ms", 0))
	steps.append({
		"name": step_name,
		"elapsed_ms": elapsed,
		"delta_ms": max(0, elapsed - previous_elapsed),
		"details": details.duplicate(true),
	})
	if bool(_active_overworld_handoff_profile.get("debug_print", false)):
		print("OVERWORLD_HANDOFF_STEP %s %d" % [step_name, elapsed])
	_active_overworld_handoff_profile["steps"] = steps

func _profile_elapsed_ms(profile: Dictionary) -> int:
	return max(0, Time.get_ticks_msec() - int(profile.get("started_msec", Time.get_ticks_msec())))

func _profile_elapsed_precise_ms(profile: Dictionary) -> float:
	return ProfileLogScript.elapsed_ms(int(profile.get("started_usec", Time.get_ticks_usec())))

func _emit_overworld_handoff_profile_record(profile: Dictionary) -> void:
	if String(profile.get("reason", "")) != "town_exit":
		return
	var session := SessionState.ensure_active_session() if SessionState.has_playable_session() else null
	var buckets := _handoff_step_delta_buckets(profile)
	var details: Dictionary = profile.get("details", {}) if profile.get("details", {}) is Dictionary else {}
	var metadata := {
		"reason": String(profile.get("reason", "")),
		"details": details.duplicate(true),
		"steps": profile.get("steps", []),
		"first_overworld_ready_ms": _handoff_step_elapsed(profile, "overworld_ready_render_state_done"),
		"first_overworld_frame_ms": _handoff_step_elapsed(profile, "overworld_first_frame_after_return"),
		"router_only_ms": _handoff_step_span_ms(profile, "go_to_overworld_enter", "go_to_overworld_change_scene_requested"),
		"save_before_transition_skipped": true,
	}
	ProfileLogScript.emit_general(
		"town",
		"exit_handoff",
		"town_exit_first_overworld_frame",
		float(profile.get("total_precise_ms", profile.get("total_ms", 0.0))),
		buckets,
		metadata,
		session
	)

func _handoff_step_delta_buckets(profile: Dictionary) -> Dictionary:
	var buckets := {}
	var steps: Array = profile.get("steps", []) if profile.get("steps", []) is Array else []
	for index in range(steps.size()):
		var step: Dictionary = steps[index] if steps[index] is Dictionary else {}
		var name := _handoff_bucket_name(String(step.get("name", "step_%d" % index)))
		if name == "":
			name = "step_%d" % index
		if buckets.has(name):
			name = "%s_%d" % [name, index]
		buckets[name] = float(step.get("delta_ms", 0.0))
	return buckets

func _handoff_bucket_name(step_name: String) -> String:
	return step_name.strip_edges().to_lower().replace("/", "_").replace("-", "_").replace(" ", "_")

func _handoff_step_elapsed(profile: Dictionary, step_name: String) -> int:
	var steps: Array = profile.get("steps", []) if profile.get("steps", []) is Array else []
	for step_value in steps:
		if not (step_value is Dictionary):
			continue
		var step: Dictionary = step_value
		if String(step.get("name", "")) == step_name:
			return int(step.get("elapsed_ms", -1))
	return -1

func _handoff_step_span_ms(profile: Dictionary, start_step: String, end_step: String) -> int:
	var start_ms := _handoff_step_elapsed(profile, start_step)
	var end_ms := _handoff_step_elapsed(profile, end_step)
	if start_ms < 0 or end_ms < 0:
		return -1
	return max(0, end_ms - start_ms)

func _battle_stack_count(session: SessionStateStoreScript.SessionData) -> int:
	if session == null or not (session.battle is Dictionary):
		return 0
	var stacks = session.battle.get("stacks", [])
	return stacks.size() if stacks is Array else 0
