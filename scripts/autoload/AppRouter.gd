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
const ACTIVE_PLAY_RETURN_FAILURE_MESSAGE := "Save failed. The expedition remains open; use Save, then try Return to Main Menu again."
const ACTIVE_PLAY_RETURN_SUCCESS_MESSAGE := "Expedition saved. Returning to Main Menu."
const BATTLE_ENTRY_AUTOSAVE_FAILURE_MESSAGE := "Battle is ready, but autosave failed. Use Save now to protect it."
const BATTLE_RESOLUTION_AUTOSAVE_FAILURE_MESSAGE := "Battle resolved, but autosave failed. Use Save Battle now to protect the result."
const SCENARIO_OUTCOME_AUTOSAVE_FAILURE_MESSAGE := "Outcome is ready, but autosave failed. Use Save now to protect it."

var _menu_notice := ""
var _pending_load_resumed_presentation: Dictionary = {}
var _load_resumed_presentation_sequence := 0
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
var _safe_close_guard_request_count := 0
var _safe_close_guard_handled_count := 0
var _safe_close_guard_bypass_request_count := 0
var _safe_close_guard_bypass_consume_count := 0
var _safe_close_guard_bypass_reject_count := 0
var _safe_close_guard_in_progress := false
var _safe_close_guard_bypass_active := false
var _safe_close_guard_last_source := ""
var _safe_close_guard_last_result := {}
var _safe_close_guard_last_authorization := {}
var _validation_safe_close_guard_target: Node = null
var _active_play_return_request_count := 0
var _active_play_return_save_attempt_count := 0
var _active_play_return_save_failure_count := 0
var _active_play_return_route_attempt_count := 0
var _active_play_return_suppressed_route_count := 0
var _active_play_return_last_result := {}
var _active_play_return_last_route := {}
var _active_play_return_last_runtime_issue := {}
var _validation_active_play_return_routing_suppressed := false
var _battle_entry_request_count := 0
var _battle_entry_save_attempt_count := 0
var _battle_entry_save_failure_count := 0
var _battle_entry_route_attempt_count := 0
var _battle_entry_suppressed_route_count := 0
var _battle_entry_skipped_durable_route_count := 0
var _battle_entry_runtime_issue_count := 0
var _battle_entry_last_result := {}
var _battle_entry_last_route := {}
var _battle_entry_last_runtime_issue := {}
var _validation_battle_entry_routing_suppressed := false
var _battle_resolution_checkpoint_request_count := 0
var _battle_resolution_checkpoint_save_attempt_count := 0
var _battle_resolution_checkpoint_save_failure_count := 0
var _battle_resolution_checkpoint_already_durable_count := 0
var _battle_resolution_checkpoint_route_request_count := 0
var _battle_resolution_checkpoint_route_attempt_count := 0
var _battle_resolution_checkpoint_suppressed_route_count := 0
var _battle_resolution_checkpoint_skipped_durable_route_count := 0
var _battle_resolution_checkpoint_runtime_issue_count := 0
var _battle_resolution_checkpoint_durable := false
var _battle_resolution_checkpoint_identity := {}
var _battle_resolution_checkpoint_last_result := {}
var _battle_resolution_checkpoint_last_route := {}
var _battle_resolution_checkpoint_last_runtime_issue := {}
var _validation_battle_resolution_checkpoint_routing_suppressed := false
var _scenario_outcome_request_count := 0
var _scenario_outcome_save_attempt_count := 0
var _scenario_outcome_save_failure_count := 0
var _scenario_outcome_retry_attempt_count := 0
var _scenario_outcome_retry_success_count := 0
var _scenario_outcome_retry_failure_count := 0
var _scenario_outcome_route_attempt_count := 0
var _scenario_outcome_suppressed_route_count := 0
var _scenario_outcome_skipped_durable_route_count := 0
var _scenario_outcome_runtime_issue_count := 0
var _scenario_outcome_recovery := {}
var _scenario_outcome_last_result := {}
var _scenario_outcome_last_route := {}
var _scenario_outcome_last_runtime_issue := {}
var _validation_scenario_outcome_routing_suppressed := false

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
	var normalized_source := _normalized_safe_quit_source(source)
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
	if not _safe_close_guard_bypass_active:
		var guard_result := _request_current_scene_safe_close_guard(normalized_source)
		if bool(guard_result.get("handled", false)):
			_safe_quit_last_result = {
				"ok": false,
				"saved": false,
				"quit_requested": false,
				"guarded": true,
				"pending": bool(guard_result.get("pending", false)),
				"source": normalized_source,
				"reason": String(guard_result.get("reason", "guarded")),
				"message": String(guard_result.get("message", "Close confirmation is pending.")),
				"guard_result": guard_result.duplicate(true),
			}
			return _safe_quit_last_result.duplicate(true)

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
		_clear_scenario_outcome_recovery()
	else:
		_clear_scenario_outcome_recovery()
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

func request_safe_quit_after_close_guard(source: String = "map_editor_confirmed") -> Dictionary:
	var normalized_source := _normalized_safe_quit_source(source)
	_safe_close_guard_bypass_request_count += 1
	var scene := _safe_close_guard_target()
	if scene == null or not scene.has_method("consume_safe_close_guard_confirmation"):
		_safe_close_guard_bypass_reject_count += 1
		_safe_close_guard_last_authorization = {
			"ok": false,
			"authorized": false,
			"reason": "guard_consumer_unavailable",
			"source": normalized_source,
		}
		return {
			"ok": false,
			"saved": false,
			"quit_requested": false,
			"guarded": true,
			"source": normalized_source,
			"reason": "guard_not_confirmed",
			"message": "Close confirmation is no longer active.",
		}

	var authorization_value: Variant = scene.call("consume_safe_close_guard_confirmation", normalized_source)
	var authorization: Dictionary = authorization_value.duplicate(true) if authorization_value is Dictionary else {}
	_safe_close_guard_last_authorization = _bounded_safe_close_guard_authorization(authorization, normalized_source)
	if (
		not bool(_safe_close_guard_last_authorization.get("ok", false))
		or not bool(_safe_close_guard_last_authorization.get("authorized", false))
	):
		_safe_close_guard_bypass_reject_count += 1
		return {
			"ok": false,
			"saved": false,
			"quit_requested": false,
			"guarded": true,
			"source": normalized_source,
			"reason": "guard_not_confirmed",
			"message": String(_safe_close_guard_last_authorization.get("message", "Close confirmation is no longer active.")),
			"authorization": _safe_close_guard_last_authorization.duplicate(true),
		}

	_safe_close_guard_bypass_consume_count += 1
	_safe_close_guard_bypass_active = true
	var result := request_safe_quit(normalized_source)
	_safe_close_guard_bypass_active = false
	return result

func _request_current_scene_safe_close_guard(source: String) -> Dictionary:
	var scene := _safe_close_guard_target()
	if scene == null or not scene.has_method("request_safe_close_guard"):
		return {"handled": false}
	if _safe_close_guard_in_progress:
		return {
			"handled": true,
			"pending": true,
			"reason": "guard_in_progress",
			"message": "Close confirmation is already being prepared.",
		}
	_safe_close_guard_request_count += 1
	_safe_close_guard_last_source = source
	_safe_close_guard_in_progress = true
	var guard_value: Variant = scene.call("request_safe_close_guard", source)
	_safe_close_guard_in_progress = false
	var guard_result: Dictionary = guard_value if guard_value is Dictionary else {}
	_safe_close_guard_last_result = _bounded_safe_close_guard_result(guard_result, source, scene)
	if bool(_safe_close_guard_last_result.get("handled", false)):
		_safe_close_guard_handled_count += 1
	return _safe_close_guard_last_result.duplicate(true)

func _bounded_safe_close_guard_result(result: Dictionary, source: String, scene: Node) -> Dictionary:
	return {
		"handled": bool(result.get("handled", false)),
		"pending": bool(result.get("pending", false)),
		"reason": String(result.get("reason", "")).strip_edges().left(64),
		"action": String(result.get("action", "")).strip_edges().left(32),
		"message": String(result.get("message", "")).strip_edges().left(240),
		"source": source,
		"scene": String(scene.scene_file_path).left(160),
	}

func _bounded_safe_close_guard_authorization(result: Dictionary, source: String) -> Dictionary:
	return {
		"ok": bool(result.get("ok", false)),
		"authorized": bool(result.get("authorized", false)),
		"reason": String(result.get("reason", "")).strip_edges().left(64),
		"message": String(result.get("message", "")).strip_edges().left(240),
		"source": source,
	}

func _normalized_safe_quit_source(source: String) -> String:
	var normalized_source := source.strip_edges().left(64)
	return normalized_source if normalized_source != "" else "application"

func _safe_close_guard_target() -> Node:
	if is_instance_valid(_validation_safe_close_guard_target):
		return _validation_safe_close_guard_target
	return get_tree().current_scene if get_tree() != null else null

func validation_set_quit_suppressed(suppressed: bool) -> void:
	_validation_quit_suppressed = suppressed

func validation_set_safe_quit_reentrant_probe(enabled: bool) -> void:
	_validation_safe_quit_reentrant_probe = enabled

func validation_set_safe_close_guard_target(target: Node) -> void:
	_validation_safe_close_guard_target = target

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
	_safe_close_guard_request_count = 0
	_safe_close_guard_handled_count = 0
	_safe_close_guard_bypass_request_count = 0
	_safe_close_guard_bypass_consume_count = 0
	_safe_close_guard_bypass_reject_count = 0
	_safe_close_guard_in_progress = false
	_safe_close_guard_bypass_active = false
	_safe_close_guard_last_source = ""
	_safe_close_guard_last_result = {}
	_safe_close_guard_last_authorization = {}
	_validation_safe_close_guard_target = null

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
		"close_guard": validation_safe_close_guard_snapshot(),
	}

func validation_safe_close_guard_snapshot() -> Dictionary:
	var target := _safe_close_guard_target()
	return {
		"request_count": _safe_close_guard_request_count,
		"handled_count": _safe_close_guard_handled_count,
		"bypass_request_count": _safe_close_guard_bypass_request_count,
		"bypass_consume_count": _safe_close_guard_bypass_consume_count,
		"bypass_reject_count": _safe_close_guard_bypass_reject_count,
		"guard_in_progress": _safe_close_guard_in_progress,
		"bypass_active": _safe_close_guard_bypass_active,
		"last_source": _safe_close_guard_last_source,
		"last_result": _safe_close_guard_last_result.duplicate(true),
		"last_authorization": _safe_close_guard_last_authorization.duplicate(true),
		"target_override_active": is_instance_valid(_validation_safe_close_guard_target),
		"target_name": String(target.name).left(80) if target != null else "",
		"target_path": String(target.scene_file_path).left(160) if target != null else "",
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

func return_to_main_menu_from_active_play() -> Dictionary:
	_active_play_return_request_count += 1
	if SessionState.request_editor_return_from_active_play():
		_clear_scenario_outcome_recovery()
		_menu_notice = ""
		_route_active_play_return(MAP_EDITOR_SCENE, "editor_return")
		_active_play_return_last_result = _active_play_return_result(
			true,
			false,
			true,
			"editor_return",
			"Returning to Map Editor.",
			"",
			{}
		)
		return _active_play_return_last_result.duplicate(true)

	if not SessionState.has_playable_session():
		_clear_scenario_outcome_recovery()
		_menu_notice = ""
		_route_active_play_return(MAIN_MENU_SCENE, "no_active_session")
		_active_play_return_last_result = _active_play_return_result(
			true,
			false,
			true,
			"no_active_session",
			"Returning to Main Menu.",
			"",
			{}
		)
		return _active_play_return_last_result.duplicate(true)

	var session := SessionState.ensure_active_session()
	_active_play_return_save_attempt_count += 1
	var save_result: Dictionary = _autosave_active_session(session)
	if not bool(save_result.get("ok", false)):
		_active_play_return_save_failure_count += 1
		_menu_notice = ""
		_active_play_return_last_runtime_issue = RuntimeIssueLog.emit_error(
			"active_play",
			"active_play_return_autosave_failed",
			ACTIVE_PLAY_RETURN_FAILURE_MESSAGE,
			{
				"save_reason": String(save_result.get("reason", "unknown")).left(80),
				"save_message": String(save_result.get("message", "Save write failed.")).strip_edges().left(240),
				"game_state": String(session.game_state).left(40),
			},
			session
		)
		_active_play_return_last_result = _active_play_return_result(
			false,
			false,
			false,
			"autosave_failed",
			ACTIVE_PLAY_RETURN_FAILURE_MESSAGE,
			"return_to_menu",
			save_result
		)
		return _active_play_return_last_result.duplicate(true)

	_clear_scenario_outcome_recovery()
	_menu_notice = String(save_result.get("message", ""))
	_route_active_play_return(MAIN_MENU_SCENE, "saved")
	_active_play_return_last_result = _active_play_return_result(
		true,
		true,
		true,
		"saved",
		ACTIVE_PLAY_RETURN_SUCCESS_MESSAGE,
		"",
		save_result
	)
	return _active_play_return_last_result.duplicate(true)

func _active_play_return_result(
	ok: bool,
	saved: bool,
	routed: bool,
	reason: String,
	message: String,
	retry_action: String,
	save_result: Dictionary
) -> Dictionary:
	return {
		"ok": ok,
		"saved": saved,
		"routed": routed,
		"reason": reason,
		"message": message,
		"retry_action": retry_action,
		"save_result": save_result.duplicate(true),
	}

func _route_active_play_return(scene_path: String, reason: String) -> void:
	_active_play_return_route_attempt_count += 1
	_active_play_return_last_route = {
		"target_scene": scene_path,
		"reason": reason,
		"suppressed": _validation_active_play_return_routing_suppressed,
	}
	if _validation_active_play_return_routing_suppressed:
		_active_play_return_suppressed_route_count += 1
		return
	_change_scene(scene_path)

func validation_set_active_play_return_routing_suppressed(suppressed: bool) -> void:
	_validation_active_play_return_routing_suppressed = suppressed

func validation_reset_active_play_return_state() -> void:
	_active_play_return_request_count = 0
	_active_play_return_save_attempt_count = 0
	_active_play_return_save_failure_count = 0
	_active_play_return_route_attempt_count = 0
	_active_play_return_suppressed_route_count = 0
	_active_play_return_last_result = {}
	_active_play_return_last_route = {}
	_active_play_return_last_runtime_issue = {}

func validation_active_play_return_snapshot() -> Dictionary:
	return {
		"request_count": _active_play_return_request_count,
		"save_attempt_count": _active_play_return_save_attempt_count,
		"save_failure_count": _active_play_return_save_failure_count,
		"route_attempt_count": _active_play_return_route_attempt_count,
		"suppressed_route_count": _active_play_return_suppressed_route_count,
		"routing_suppressed": _validation_active_play_return_routing_suppressed,
		"last_result": _active_play_return_last_result.duplicate(true),
		"last_route": _active_play_return_last_route.duplicate(true),
		"last_runtime_issue": _active_play_return_last_runtime_issue.duplicate(true),
	}

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

func checkpoint_battle_resolution_for_overworld(route_after_checkpoint: bool = false) -> Dictionary:
	_battle_resolution_checkpoint_request_count += 1
	if not SessionState.has_playable_session():
		_clear_battle_resolution_checkpoint_authority()
		_battle_resolution_checkpoint_last_result = _battle_resolution_checkpoint_result(
			false,
			false,
			false,
			"missing_session",
			"Cannot checkpoint a resolved battle without an active expedition.",
			"",
			false,
			{}
		)
		return _battle_resolution_checkpoint_last_result.duplicate(true)

	var session := SessionState.ensure_active_session()
	if session.scenario_status != "in_progress":
		_clear_battle_resolution_checkpoint_authority()
		_battle_resolution_checkpoint_last_result = _battle_resolution_checkpoint_result(
			false,
			false,
			false,
			"scenario_terminal",
			"Resolved expeditions must use the outcome checkpoint.",
			"",
			true,
			{}
		)
		return _battle_resolution_checkpoint_last_result.duplicate(true)
	if not session.battle.is_empty():
		_clear_battle_resolution_checkpoint_authority()
		_battle_resolution_checkpoint_last_result = _battle_resolution_checkpoint_result(
			false,
			false,
			false,
			"battle_still_active",
			"The active battle must resolve before its return checkpoint can be saved.",
			"",
			false,
			{}
		)
		return _battle_resolution_checkpoint_last_result.duplicate(true)

	if _battle_resolution_checkpoint_durable:
		if _battle_resolution_checkpoint_identity_matches(session):
			_battle_resolution_checkpoint_already_durable_count += 1
			_battle_resolution_checkpoint_last_result = _battle_resolution_checkpoint_result(
				true,
				true,
				false,
				"already_saved",
				"Battle result checkpoint is already saved.",
				"",
				true,
				_battle_resolution_checkpoint_last_result.get("save_result", {})
			)
			if route_after_checkpoint:
				return _battle_resolution_checkpoint_route_after_save(_battle_resolution_checkpoint_last_result)
			return _battle_resolution_checkpoint_last_result.duplicate(true)
		_clear_battle_resolution_checkpoint_authority()

	var pre_route_snapshot: Dictionary = session.to_dict()
	_prepare_battle_resolution_overworld_state(session)
	_battle_resolution_checkpoint_save_attempt_count += 1
	var save_result: Dictionary = SaveService.save_runtime_autosave_session(session)
	if not bool(save_result.get("ok", false)):
		session.from_dict(pre_route_snapshot)
		_clear_battle_resolution_checkpoint_authority()
		_battle_resolution_checkpoint_save_failure_count += 1
		_battle_resolution_checkpoint_runtime_issue_count += 1
		_battle_resolution_checkpoint_last_runtime_issue = RuntimeIssueLog.emit_error(
			"battle",
			"battle_resolution_autosave_failed",
			BATTLE_RESOLUTION_AUTOSAVE_FAILURE_MESSAGE,
			{
				"save_reason": String(save_result.get("reason", "unknown")).left(80),
				"save_message": String(save_result.get("message", "Save write failed.")).strip_edges().left(180),
				"scenario_id": String(session.scenario_id).left(96),
				"scenario_status": String(session.scenario_status).left(32),
				"game_state": String(session.game_state).left(40),
				"battle_active": not session.battle.is_empty(),
				"battle_outcome": String(session.flags.get("last_battle_outcome", "")).left(48),
			},
			session
		)
		_battle_resolution_checkpoint_last_result = _battle_resolution_checkpoint_result(
			false,
			false,
			false,
			"autosave_failed",
			BATTLE_RESOLUTION_AUTOSAVE_FAILURE_MESSAGE,
			"manual_save",
			true,
			save_result
		)
		return _battle_resolution_checkpoint_last_result.duplicate(true)

	_battle_resolution_checkpoint_durable = true
	_battle_resolution_checkpoint_identity = _battle_resolution_checkpoint_session_identity(session)
	_battle_resolution_checkpoint_last_result = _battle_resolution_checkpoint_result(
		true,
		true,
		false,
		"saved",
		"Battle result checkpoint saved.",
		"",
		true,
		save_result
	)
	if route_after_checkpoint:
		return _battle_resolution_checkpoint_route_after_save(_battle_resolution_checkpoint_last_result)
	return _battle_resolution_checkpoint_last_result.duplicate(true)

func route_checkpointed_battle_resolution() -> Dictionary:
	_battle_resolution_checkpoint_route_request_count += 1
	if not SessionState.has_playable_session():
		_clear_battle_resolution_checkpoint_authority()
		_battle_resolution_checkpoint_last_result = _battle_resolution_checkpoint_result(
			false,
			false,
			false,
			"missing_session",
			"Cannot route a resolved battle without an active expedition.",
			"",
			false,
			{}
		)
		return _battle_resolution_checkpoint_last_result.duplicate(true)
	var session := SessionState.ensure_active_session()
	if session.scenario_status != "in_progress":
		_clear_battle_resolution_checkpoint_authority()
		_battle_resolution_checkpoint_last_result = _battle_resolution_checkpoint_result(
			false,
			false,
			false,
			"scenario_terminal",
			"Resolved expeditions must use the outcome route.",
			"",
			true,
			{}
		)
		return _battle_resolution_checkpoint_last_result.duplicate(true)
	if not session.battle.is_empty():
		_clear_battle_resolution_checkpoint_authority()
		_battle_resolution_checkpoint_last_result = _battle_resolution_checkpoint_result(
			false,
			false,
			false,
			"battle_still_active",
			"The battle is still active and cannot return to the field.",
			"",
			false,
			{}
		)
		return _battle_resolution_checkpoint_last_result.duplicate(true)
	if not _battle_resolution_checkpoint_durable:
		_battle_resolution_checkpoint_last_result = _battle_resolution_checkpoint_result(
			false,
			false,
			false,
			"checkpoint_required",
			"Save the resolved battle checkpoint before returning to the field.",
			"manual_save",
			true,
			{}
		)
		return _battle_resolution_checkpoint_last_result.duplicate(true)
	if not _battle_resolution_checkpoint_identity_matches(session):
		_clear_battle_resolution_checkpoint_authority()
		_battle_resolution_checkpoint_last_result = _battle_resolution_checkpoint_result(
			false,
			false,
			false,
			"stale_checkpoint",
			"The resolved battle changed after its checkpoint; save it again before returning.",
			"manual_save",
			true,
			{}
		)
		return _battle_resolution_checkpoint_last_result.duplicate(true)

	var save_result_value: Variant = _battle_resolution_checkpoint_last_result.get("save_result", {})
	var save_result: Dictionary = save_result_value if save_result_value is Dictionary else {}
	_clear_battle_resolution_checkpoint_authority()
	_battle_resolution_checkpoint_skipped_durable_route_count += 1
	var routed := _record_battle_resolution_checkpoint_route(OVERWORLD_SCENE, "already_saved")
	if routed:
		_change_scene(OVERWORLD_SCENE)
	_battle_resolution_checkpoint_last_result = _battle_resolution_checkpoint_result(
		true,
		true,
		true,
		"already_saved",
		"Battle result saved. Returning to the field.",
		"",
		true,
		save_result
	)
	return _battle_resolution_checkpoint_last_result.duplicate(true)

func _battle_resolution_checkpoint_route_after_save(checkpoint_result: Dictionary) -> Dictionary:
	var routed_result := route_checkpointed_battle_resolution()
	if bool(routed_result.get("ok", false)):
		routed_result["reason"] = "saved"
		routed_result["message"] = "Battle result saved. Returning to the field."
		routed_result["save_result"] = checkpoint_result.get("save_result", {}).duplicate(true)
		_battle_resolution_checkpoint_last_result = routed_result.duplicate(true)
	return routed_result

func _prepare_battle_resolution_overworld_state(session: SessionStateStoreScript.SessionData) -> void:
	session.game_state = "overworld"
	OverworldRules.clear_active_town_visit(session)
	OverworldRules.normalize_overworld_state(session)

func _battle_resolution_checkpoint_result(
	ok: bool,
	saved: bool,
	routed: bool,
	reason: String,
	message: String,
	retry_action: String,
	battle_resolved: bool,
	save_result: Dictionary
) -> Dictionary:
	var session = SessionState.ensure_active_session() if SessionState.has_playable_session() else null
	return {
		"ok": ok,
		"saved": saved,
		"routed": routed,
		"reason": reason,
		"retry_action": retry_action,
		"battle_resolved": battle_resolved,
		"battle_active": not session.battle.is_empty() if session != null else false,
		"battle_pending": not session.battle.is_empty() if session != null else false,
		"scenario_status": String(session.scenario_status) if session != null else "",
		"game_state": String(session.game_state) if session != null else "",
		"checkpoint_durable": _battle_resolution_checkpoint_durable,
		"message": message,
		"save_result": save_result.duplicate(true),
	}

func _record_battle_resolution_checkpoint_route(scene_path: String, reason: String) -> bool:
	_battle_resolution_checkpoint_route_attempt_count += 1
	_battle_resolution_checkpoint_last_route = {
		"target_scene": scene_path,
		"target": "overworld" if scene_path == OVERWORLD_SCENE else scene_path,
		"reason": reason,
		"suppressed": _validation_battle_resolution_checkpoint_routing_suppressed,
	}
	if _validation_battle_resolution_checkpoint_routing_suppressed:
		_battle_resolution_checkpoint_suppressed_route_count += 1
		return false
	return true

func _battle_resolution_checkpoint_session_identity(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null:
		return {}
	return {
		"session_id_hash": String(session.session_id).sha256_text(),
		"scenario_id": String(session.scenario_id).left(128),
		"scenario_status": String(session.scenario_status).left(32),
		"day": int(session.day),
		"battle_outcome": String(session.flags.get("last_battle_outcome", "")).left(48),
		"payload_hash": JSON.stringify(session.to_dict()).sha256_text(),
	}

func _battle_resolution_checkpoint_identity_matches(session: SessionStateStoreScript.SessionData) -> bool:
	return (
		_battle_resolution_checkpoint_durable
		and not _battle_resolution_checkpoint_identity.is_empty()
		and _battle_resolution_checkpoint_identity == _battle_resolution_checkpoint_session_identity(session)
	)

func _clear_battle_resolution_checkpoint_authority() -> void:
	_battle_resolution_checkpoint_durable = false
	_battle_resolution_checkpoint_identity = {}

func validation_set_battle_resolution_checkpoint_routing_suppressed(suppressed: bool) -> void:
	_validation_battle_resolution_checkpoint_routing_suppressed = suppressed

func validation_reset_battle_resolution_checkpoint_state() -> void:
	_battle_resolution_checkpoint_request_count = 0
	_battle_resolution_checkpoint_save_attempt_count = 0
	_battle_resolution_checkpoint_save_failure_count = 0
	_battle_resolution_checkpoint_already_durable_count = 0
	_battle_resolution_checkpoint_route_request_count = 0
	_battle_resolution_checkpoint_route_attempt_count = 0
	_battle_resolution_checkpoint_suppressed_route_count = 0
	_battle_resolution_checkpoint_skipped_durable_route_count = 0
	_battle_resolution_checkpoint_runtime_issue_count = 0
	_clear_battle_resolution_checkpoint_authority()
	_battle_resolution_checkpoint_last_result = {}
	_battle_resolution_checkpoint_last_route = {}
	_battle_resolution_checkpoint_last_runtime_issue = {}

func validation_battle_resolution_checkpoint_snapshot() -> Dictionary:
	var session = SessionState.ensure_active_session() if SessionState.has_playable_session() else null
	return {
		"request_count": _battle_resolution_checkpoint_request_count,
		"save_attempt_count": _battle_resolution_checkpoint_save_attempt_count,
		"save_failure_count": _battle_resolution_checkpoint_save_failure_count,
		"already_durable_count": _battle_resolution_checkpoint_already_durable_count,
		"route_request_count": _battle_resolution_checkpoint_route_request_count,
		"route_attempt_count": _battle_resolution_checkpoint_route_attempt_count,
		"suppressed_route_count": _battle_resolution_checkpoint_suppressed_route_count,
		"skipped_durable_route_count": _battle_resolution_checkpoint_skipped_durable_route_count,
		"runtime_issue_count": _battle_resolution_checkpoint_runtime_issue_count,
		"routing_suppressed": _validation_battle_resolution_checkpoint_routing_suppressed,
		"checkpoint_durable": _battle_resolution_checkpoint_durable,
		"checkpoint_identity": _battle_resolution_checkpoint_identity.duplicate(true),
		"battle_active": not session.battle.is_empty() if session != null else false,
		"battle_pending": not session.battle.is_empty() if session != null else false,
		"scenario_status": String(session.scenario_status) if session != null else "",
		"game_state": String(session.game_state) if session != null else "",
		"last_result": _battle_resolution_checkpoint_last_result.duplicate(true),
		"last_route": _battle_resolution_checkpoint_last_route.duplicate(true),
		"last_runtime_issue": _battle_resolution_checkpoint_last_runtime_issue.duplicate(true),
	}

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

func go_to_battle(skip_required_save: bool = false) -> Dictionary:
	_battle_entry_request_count += 1
	var started := ProfileLogScript.begin_usec()
	var buckets := {}
	if not SessionState.has_playable_session():
		push_warning("Cannot enter battle without an active scenario session.")
		var scene_started := ProfileLogScript.begin_usec()
		if _record_battle_entry_route(MAIN_MENU_SCENE, "missing_session"):
			_change_scene(MAIN_MENU_SCENE)
		buckets["scene_change"] = ProfileLogScript.elapsed_ms(scene_started)
		ProfileLogScript.emit_general("router", "scene_transition", "go_to_battle_missing_session", ProfileLogScript.elapsed_ms(started), buckets, {"target_scene": MAIN_MENU_SCENE}, null)
		_battle_entry_last_result = _battle_entry_result(
			false,
			false,
			true,
			"missing_session",
			"Cannot enter battle without an active scenario session.",
			"",
			false,
			{}
		)
		return _battle_entry_last_result.duplicate(true)
	if not SessionState.has_battle_state():
		push_warning("Cannot enter battle without an active battle payload.")
		ProfileLogScript.emit_general("router", "scene_transition", "go_to_battle_missing_payload", ProfileLogScript.elapsed_ms(started), buckets, {"target_scene": OVERWORLD_SCENE}, SessionState.ensure_active_session())
		if _record_battle_entry_route(OVERWORLD_SCENE, "missing_battle_payload"):
			go_to_overworld()
		_battle_entry_last_result = _battle_entry_result(
			false,
			false,
			true,
			"missing_battle_payload",
			"Cannot enter battle without an active battle payload.",
			"",
			false,
			{}
		)
		return _battle_entry_last_result.duplicate(true)

	var session := SessionState.ensure_active_session()
	if session.scenario_status != "in_progress":
		ProfileLogScript.emit_general("router", "scene_transition", "go_to_battle_outcome_redirect", ProfileLogScript.elapsed_ms(started), buckets, {"target_scene": SCENARIO_OUTCOME_SCENE}, session)
		if _record_battle_entry_route(SCENARIO_OUTCOME_SCENE, "terminal_redirect"):
			go_to_scenario_outcome()
		_battle_entry_last_result = _battle_entry_result(
			true,
			false,
			true,
			"terminal_redirect",
			"The resolved expedition is opening its outcome review.",
			"",
			true,
			{}
		)
		return _battle_entry_last_result.duplicate(true)

	var pre_route_game_state := String(session.game_state)
	var state_started := ProfileLogScript.begin_usec()
	session.game_state = "battle"
	buckets["state_handoff"] = ProfileLogScript.elapsed_ms(state_started)
	var autosave_result := {}
	if skip_required_save:
		_battle_entry_skipped_durable_route_count += 1
		buckets["save_before_transition"] = 0.0
	else:
		_battle_entry_save_attempt_count += 1
		var save_started := ProfileLogScript.begin_usec()
		autosave_result = _autosave_active_session(session, false)
		buckets["save_before_transition"] = ProfileLogScript.elapsed_ms(save_started)
		if not bool(autosave_result.get("ok", false)):
			session.game_state = pre_route_game_state
			_battle_entry_save_failure_count += 1
			_battle_entry_runtime_issue_count += 1
			_battle_entry_last_runtime_issue = RuntimeIssueLog.emit_error(
				"router",
				"battle_entry_autosave_failed",
				BATTLE_ENTRY_AUTOSAVE_FAILURE_MESSAGE,
				{
					"save_reason": String(autosave_result.get("reason", "unknown")).left(80),
					"save_message": String(autosave_result.get("message", "Save write failed.")).strip_edges().left(180),
					"game_state": pre_route_game_state.left(40),
					"battle_pending": not session.battle.is_empty(),
				},
				session
			)
			_battle_entry_last_result = _battle_entry_result(
				false,
				false,
				false,
				"autosave_failed",
				BATTLE_ENTRY_AUTOSAVE_FAILURE_MESSAGE,
				"manual_save",
				not session.battle.is_empty(),
				autosave_result
			)
			ProfileLogScript.emit_general("router", "scene_transition", "go_to_battle_autosave_failed", ProfileLogScript.elapsed_ms(started), buckets, {
				"target_scene": BATTLE_SCENE,
				"battle_stack_count": _battle_stack_count(session),
				"autosave_deferred_or_skipped_reason": "forced_save_required_battle",
				"autosave_forced": true,
				"autosave_ok": false,
				"routed": false,
			}, session)
			return _battle_entry_last_result.duplicate(true)

	var scene_started := ProfileLogScript.begin_usec()
	var route_reason := "already_saved" if skip_required_save else "saved"
	if _record_battle_entry_route(BATTLE_SCENE, route_reason):
		_change_scene(BATTLE_SCENE)
	buckets["scene_change"] = ProfileLogScript.elapsed_ms(scene_started)
	ProfileLogScript.emit_general("router", "scene_transition", "go_to_battle", ProfileLogScript.elapsed_ms(started), buckets, {
		"target_scene": BATTLE_SCENE,
		"battle_stack_count": _battle_stack_count(session),
		"autosave_deferred_or_skipped_reason": "durable_checkpoint_already_saved" if skip_required_save else "forced_save_required_battle",
		"autosave_forced": not skip_required_save,
		"autosave_ok": true,
		"routed": true,
	}, session)
	_battle_entry_last_result = _battle_entry_result(
		true,
		true,
		true,
		route_reason,
		"Battle checkpoint already saved. Entering battle." if skip_required_save else "Battle checkpoint saved. Entering battle.",
		"",
		true,
		autosave_result
	)
	return _battle_entry_last_result.duplicate(true)

func _battle_entry_result(
	ok: bool,
	saved: bool,
	routed: bool,
	reason: String,
	message: String,
	retry_action: String,
	battle_pending: bool,
	save_result: Dictionary
) -> Dictionary:
	return {
		"ok": ok,
		"saved": saved,
		"routed": routed,
		"reason": reason,
		"retry_action": retry_action,
		"battle_pending": battle_pending,
		"message": message,
		"save_result": save_result.duplicate(true),
	}

func _record_battle_entry_route(scene_path: String, reason: String) -> bool:
	_battle_entry_route_attempt_count += 1
	_battle_entry_last_route = {
		"target_scene": scene_path,
		"reason": reason,
		"suppressed": _validation_battle_entry_routing_suppressed,
	}
	if _validation_battle_entry_routing_suppressed:
		_battle_entry_suppressed_route_count += 1
		return false
	return true

func validation_set_battle_entry_routing_suppressed(suppressed: bool) -> void:
	_validation_battle_entry_routing_suppressed = suppressed

func validation_reset_battle_entry_state() -> void:
	_battle_entry_request_count = 0
	_battle_entry_save_attempt_count = 0
	_battle_entry_save_failure_count = 0
	_battle_entry_route_attempt_count = 0
	_battle_entry_suppressed_route_count = 0
	_battle_entry_skipped_durable_route_count = 0
	_battle_entry_runtime_issue_count = 0
	_battle_entry_last_result = {}
	_battle_entry_last_route = {}
	_battle_entry_last_runtime_issue = {}

func validation_battle_entry_snapshot() -> Dictionary:
	return {
		"request_count": _battle_entry_request_count,
		"save_attempt_count": _battle_entry_save_attempt_count,
		"save_failure_count": _battle_entry_save_failure_count,
		"route_attempt_count": _battle_entry_route_attempt_count,
		"suppressed_route_count": _battle_entry_suppressed_route_count,
		"skipped_durable_route_count": _battle_entry_skipped_durable_route_count,
		"runtime_issue_count": _battle_entry_runtime_issue_count,
		"routing_suppressed": _validation_battle_entry_routing_suppressed,
		"last_result": _battle_entry_last_result.duplicate(true),
		"last_route": _battle_entry_last_route.duplicate(true),
		"last_runtime_issue": _battle_entry_last_runtime_issue.duplicate(true),
	}

func go_to_scenario_outcome(skip_required_save: bool = false) -> Dictionary:
	_scenario_outcome_request_count += 1
	if not SessionState.has_playable_session():
		_clear_scenario_outcome_recovery()
		_scenario_outcome_last_result = _scenario_outcome_result(
			false,
			false,
			true,
			"missing_session",
			"Cannot open an outcome without an active expedition.",
			"",
			false,
			false,
			{}
		)
		if _record_scenario_outcome_route(MAIN_MENU_SCENE, "missing_session"):
			_change_scene(MAIN_MENU_SCENE)
		return _scenario_outcome_last_result.duplicate(true)

	var session := SessionState.ensure_active_session()
	if session.scenario_status == "in_progress":
		_clear_scenario_outcome_recovery()
		_scenario_outcome_last_result = _scenario_outcome_result(
			false,
			false,
			true,
			"scenario_in_progress",
			"The active expedition is returning to the field.",
			"",
			false,
			false,
			{}
		)
		if _record_scenario_outcome_route(OVERWORLD_SCENE, "in_progress_redirect"):
			go_to_overworld()
		return _scenario_outcome_last_result.duplicate(true)

	session.game_state = "outcome"
	var save_result := {}
	var reason := "already_saved" if skip_required_save else "saved"
	if skip_required_save:
		_scenario_outcome_skipped_durable_route_count += 1
		_clear_scenario_outcome_recovery()
	else:
		_scenario_outcome_save_attempt_count += 1
		save_result = SaveService.save_runtime_autosave_session(session)
		if not bool(save_result.get("ok", false)):
			_scenario_outcome_save_failure_count += 1
			_scenario_outcome_runtime_issue_count += 1
			var identity := _scenario_outcome_session_identity(session)
			_scenario_outcome_last_runtime_issue = RuntimeIssueLog.emit_error(
				"router",
				"scenario_outcome_autosave_failed",
				SCENARIO_OUTCOME_AUTOSAVE_FAILURE_MESSAGE,
				{
					"save_reason": String(save_result.get("reason", "unknown")).left(80),
					"save_message": String(save_result.get("message", "Save write failed.")).strip_edges().left(180),
					"scenario_id": String(identity.get("scenario_id", "")).left(96),
					"scenario_status": String(identity.get("scenario_status", "")).left(32),
					"day": int(identity.get("day", 0)),
				},
				session
			)
			_scenario_outcome_last_result = _scenario_outcome_result(
				false,
				false,
				true,
				"autosave_failed",
				SCENARIO_OUTCOME_AUTOSAVE_FAILURE_MESSAGE,
				"retry_outcome_autosave",
				true,
				true,
				save_result
			)
			_scenario_outcome_recovery = {
				"pending": true,
				"message": SCENARIO_OUTCOME_AUTOSAVE_FAILURE_MESSAGE,
				"identity": identity,
				"last_result": _scenario_outcome_last_result.duplicate(true),
			}
			if _record_scenario_outcome_route(SCENARIO_OUTCOME_SCENE, "autosave_failed_recovery"):
				_change_scene(SCENARIO_OUTCOME_SCENE)
			return _scenario_outcome_last_result.duplicate(true)
		_clear_scenario_outcome_recovery()

	_scenario_outcome_last_result = _scenario_outcome_result(
		true,
		true,
		true,
		reason,
		"Outcome checkpoint already saved. Opening outcome review." if skip_required_save else "Outcome checkpoint saved. Opening outcome review.",
		"",
		false,
		false,
		save_result
	)
	if _record_scenario_outcome_route(SCENARIO_OUTCOME_SCENE, reason):
		_change_scene(SCENARIO_OUTCOME_SCENE)
	return _scenario_outcome_last_result.duplicate(true)

func retry_scenario_outcome_autosave() -> Dictionary:
	_scenario_outcome_retry_attempt_count += 1
	if _scenario_outcome_recovery.is_empty() or not bool(_scenario_outcome_recovery.get("pending", false)):
		_scenario_outcome_last_result = _scenario_outcome_result(
			false,
			false,
			false,
			"no_recovery_pending",
			"No outcome autosave recovery is pending.",
			"",
			false,
			false,
			{}
		)
		return _scenario_outcome_last_result.duplicate(true)
	if not SessionState.has_playable_session():
		_clear_scenario_outcome_recovery()
		_scenario_outcome_last_result = _scenario_outcome_result(
			false,
			false,
			false,
			"stale_session",
			"The pending outcome belongs to another expedition.",
			"",
			false,
			false,
			{}
		)
		return _scenario_outcome_last_result.duplicate(true)

	var session := SessionState.ensure_active_session()
	var pending_identity: Dictionary = _scenario_outcome_recovery.get("identity", {}) if _scenario_outcome_recovery.get("identity", {}) is Dictionary else {}
	if session.scenario_status == "in_progress" or not _scenario_outcome_identity_matches(session, pending_identity):
		_clear_scenario_outcome_recovery()
		_scenario_outcome_last_result = _scenario_outcome_result(
			false,
			false,
			false,
			"stale_session",
			"The pending outcome belongs to another expedition.",
			"",
			false,
			false,
			{}
		)
		return _scenario_outcome_last_result.duplicate(true)

	session.game_state = "outcome"
	_scenario_outcome_save_attempt_count += 1
	var save_result: Dictionary = SaveService.save_runtime_autosave_session(session)
	if not bool(save_result.get("ok", false)):
		_scenario_outcome_save_failure_count += 1
		_scenario_outcome_retry_failure_count += 1
		_scenario_outcome_last_result = _scenario_outcome_result(
			false,
			false,
			false,
			"autosave_failed",
			SCENARIO_OUTCOME_AUTOSAVE_FAILURE_MESSAGE,
			"retry_outcome_autosave",
			true,
			true,
			save_result
		)
		_scenario_outcome_recovery["message"] = SCENARIO_OUTCOME_AUTOSAVE_FAILURE_MESSAGE
		_scenario_outcome_recovery["last_result"] = _scenario_outcome_last_result.duplicate(true)
		return _scenario_outcome_last_result.duplicate(true)

	_scenario_outcome_retry_success_count += 1
	_scenario_outcome_last_result = _scenario_outcome_result(
		true,
		true,
		false,
		"saved",
		"Outcome checkpoint saved.",
		"",
		false,
		false,
		save_result
	)
	_clear_scenario_outcome_recovery()
	return _scenario_outcome_last_result.duplicate(true)

func scenario_outcome_recovery_state() -> Dictionary:
	return scenario_outcome_recovery_snapshot()

func scenario_outcome_recovery_snapshot() -> Dictionary:
	_reconcile_scenario_outcome_recovery()
	var pending := not _scenario_outcome_recovery.is_empty() and bool(_scenario_outcome_recovery.get("pending", false))
	var identity: Dictionary = _scenario_outcome_recovery.get("identity", {}) if _scenario_outcome_recovery.get("identity", {}) is Dictionary else {}
	return {
		"pending": pending,
		"recovery_pending": pending,
		"message": String(_scenario_outcome_recovery.get("message", "")) if pending else "",
		"identity": identity.duplicate(true),
		"last_result": _scenario_outcome_last_result.duplicate(true),
		"request_count": _scenario_outcome_request_count,
		"save_attempt_count": _scenario_outcome_save_attempt_count,
		"save_failure_count": _scenario_outcome_save_failure_count,
		"retry_attempt_count": _scenario_outcome_retry_attempt_count,
		"retry_success_count": _scenario_outcome_retry_success_count,
		"retry_failure_count": _scenario_outcome_retry_failure_count,
		"route_attempt_count": _scenario_outcome_route_attempt_count,
		"suppressed_route_count": _scenario_outcome_suppressed_route_count,
		"skipped_durable_route_count": _scenario_outcome_skipped_durable_route_count,
		"runtime_issue_count": _scenario_outcome_runtime_issue_count,
		"routing_suppressed": _validation_scenario_outcome_routing_suppressed,
		"last_route": _scenario_outcome_last_route.duplicate(true),
		"last_runtime_issue": _scenario_outcome_last_runtime_issue.duplicate(true),
	}

func validation_set_scenario_outcome_routing_suppressed(suppressed: bool) -> void:
	_validation_scenario_outcome_routing_suppressed = suppressed

func validation_reset_scenario_outcome_route_state() -> void:
	_scenario_outcome_request_count = 0
	_scenario_outcome_save_attempt_count = 0
	_scenario_outcome_save_failure_count = 0
	_scenario_outcome_retry_attempt_count = 0
	_scenario_outcome_retry_success_count = 0
	_scenario_outcome_retry_failure_count = 0
	_scenario_outcome_route_attempt_count = 0
	_scenario_outcome_suppressed_route_count = 0
	_scenario_outcome_skipped_durable_route_count = 0
	_scenario_outcome_runtime_issue_count = 0
	_scenario_outcome_recovery = {}
	_scenario_outcome_last_result = {}
	_scenario_outcome_last_route = {}
	_scenario_outcome_last_runtime_issue = {}

func validation_scenario_outcome_route_snapshot() -> Dictionary:
	return scenario_outcome_recovery_snapshot()

func _scenario_outcome_result(
	ok: bool,
	saved: bool,
	routed: bool,
	reason: String,
	message: String,
	retry_action: String,
	outcome_pending: bool,
	recovery_pending: bool,
	save_result: Dictionary
) -> Dictionary:
	return {
		"ok": ok,
		"saved": saved,
		"routed": routed,
		"reason": reason,
		"retry_action": retry_action,
		"outcome_pending": outcome_pending,
		"recovery_pending": recovery_pending,
		"message": message,
		"save_result": save_result.duplicate(true),
	}

func _record_scenario_outcome_route(scene_path: String, reason: String) -> bool:
	_scenario_outcome_route_attempt_count += 1
	_scenario_outcome_last_route = {
		"target_scene": scene_path,
		"reason": reason,
		"suppressed": _validation_scenario_outcome_routing_suppressed,
	}
	if _validation_scenario_outcome_routing_suppressed:
		_scenario_outcome_suppressed_route_count += 1
		return false
	return true

func _scenario_outcome_session_identity(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null:
		return {}
	return {
		"session_id": String(session.session_id).left(128),
		"session_id_hash": String(session.session_id).sha256_text(),
		"scenario_id": String(session.scenario_id).left(128),
		"scenario_id_hash": String(session.scenario_id).sha256_text(),
		"launch_mode": String(session.launch_mode).left(32),
		"scenario_status": String(session.scenario_status).left(32),
		"day": int(session.day),
		"summary_hash": String(session.scenario_summary).sha256_text(),
	}

func _scenario_outcome_identity_matches(session: SessionStateStoreScript.SessionData, identity: Dictionary) -> bool:
	return not identity.is_empty() and _scenario_outcome_session_identity(session) == identity

func _reconcile_scenario_outcome_recovery() -> void:
	if _scenario_outcome_recovery.is_empty() or not bool(_scenario_outcome_recovery.get("pending", false)):
		return
	if not SessionState.has_playable_session():
		_clear_scenario_outcome_recovery()
		return
	var identity: Dictionary = _scenario_outcome_recovery.get("identity", {}) if _scenario_outcome_recovery.get("identity", {}) is Dictionary else {}
	if not _scenario_outcome_identity_matches(SessionState.ensure_active_session(), identity):
		_clear_scenario_outcome_recovery()

func _clear_scenario_outcome_recovery() -> void:
	_scenario_outcome_recovery = {}

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
		go_to_scenario_outcome(true)
		return

	match SaveService.resume_target_for_session(session):
		"battle":
			go_to_battle(true)
		"town":
			go_to_town()
		"outcome":
			go_to_scenario_outcome(true)
		_:
			go_to_overworld()

func resume_summary(summary: Dictionary) -> bool:
	_clear_pending_load_resumed_presentation()
	if summary.is_empty():
		go_to_main_menu()
		return false
	var session = SaveService.restore_session_from_summary(summary)
	if session == null:
		push_warning("The selected save could not be restored.")
		return false
	var live_summary: Dictionary = SaveService.refresh_summary(summary)
	_pending_load_resumed_presentation = _build_load_resumed_presentation(live_summary, session)
	SessionState.active_session = session
	resume_active_session()
	return true

func consume_load_resumed_presentation(surface: String) -> Dictionary:
	var pending := _pending_load_resumed_presentation.duplicate(true)
	_clear_pending_load_resumed_presentation()
	var normalized_surface := surface.strip_edges()
	if pending.is_empty() or normalized_surface == "":
		return {}
	if (
		String(pending.get("event_id", "")) != "system_load_resumed"
		or String(pending.get("cue_id", "")) != "cue_system_load_resumed"
		or String(pending.get("surface", "")) != normalized_surface
		or String(pending.get("expected_scene_path", "")) != _load_resumed_scene_path_for_surface(normalized_surface)
		or int(pending.get("sequence", 0)) <= 0
	):
		return {}
	if not SessionState.has_playable_session():
		return {}
	var session := SessionState.ensure_active_session()
	var expected_target := _load_resumed_target_for_surface(normalized_surface)
	if (
		session.scenario_id != String(pending.get("scenario_id", ""))
		or session.day != int(pending.get("day", -1))
		or session.scenario_status != String(pending.get("scenario_status", ""))
		or session.game_state != String(pending.get("game_state", ""))
		or SaveService.resume_target_for_session(session) != expected_target
		or String(pending.get("resume_target", "")) != expected_target
	):
		return {}
	var summary_identity: Dictionary = pending.get("summary_identity", {}) if pending.get("summary_identity", {}) is Dictionary else {}
	var live_summary: Dictionary = SaveService.refresh_summary(summary_identity)
	if not _load_resumed_summary_identity_matches(live_summary, summary_identity):
		return {}
	pending["consumed"] = true
	pending["consumed_surface"] = normalized_surface
	return pending.duplicate(true)

func validation_pending_load_resumed_presentation() -> Dictionary:
	return _pending_load_resumed_presentation.duplicate(true)

func validation_clear_pending_load_resumed_presentation() -> void:
	_clear_pending_load_resumed_presentation()

func _build_load_resumed_presentation(live_summary: Dictionary, session) -> Dictionary:
	if session == null or not SaveService.can_load_summary(live_summary):
		return {}
	var resume_target := SaveService.resume_target_for_session(session)
	var surface := "scenario_outcome" if resume_target == "outcome" else resume_target
	var expected_scene_path := _load_resumed_scene_path_for_surface(surface)
	var continuity_cue := SaveService.describe_slot_continuity_cue(live_summary).strip_edges()
	var summary_identity := {
		"slot_type": String(live_summary.get("slot_type", "")),
		"slot_id": String(live_summary.get("slot_id", "")),
		"path": String(live_summary.get("path", "")),
		"modified_timestamp": int(live_summary.get("modified_timestamp", 0)),
		"payload_bytes": int(live_summary.get("payload_bytes", 0)),
	}
	if (
		not resume_target in ["overworld", "town", "battle", "outcome"]
		or expected_scene_path == ""
		or continuity_cue == ""
		or String(live_summary.get("resume_target", "")) != resume_target
		or String(live_summary.get("scenario_id", "")) != session.scenario_id
		or int(live_summary.get("day", -1)) != session.day
		or String(live_summary.get("scenario_status", "")) != session.scenario_status
		or String(summary_identity.get("slot_type", "")) not in [SaveService.SLOT_TYPE_MANUAL, SaveService.SLOT_TYPE_AUTOSAVE]
		or String(summary_identity.get("slot_id", "")) == ""
		or String(summary_identity.get("path", "")) == ""
		or int(summary_identity.get("payload_bytes", 0)) <= 0
	):
		return {}
	_load_resumed_presentation_sequence += 1
	return {
		"event_id": "system_load_resumed",
		"cue_id": "cue_system_load_resumed",
		"sequence": _load_resumed_presentation_sequence,
		"surface": surface,
		"expected_scene_path": expected_scene_path,
		"scenario_id": session.scenario_id,
		"day": session.day,
		"scenario_status": session.scenario_status,
		"game_state": session.game_state,
		"resume_target": resume_target,
		"continuity_cue": continuity_cue,
		"summary_identity": summary_identity.duplicate(true),
	}.duplicate(true)

func _load_resumed_summary_identity_matches(live_summary: Dictionary, expected: Dictionary) -> bool:
	return (
		SaveService.can_load_summary(live_summary)
		and String(live_summary.get("slot_type", "")) == String(expected.get("slot_type", ""))
		and String(live_summary.get("slot_id", "")) == String(expected.get("slot_id", ""))
		and String(live_summary.get("path", "")) == String(expected.get("path", ""))
		and int(live_summary.get("modified_timestamp", 0)) == int(expected.get("modified_timestamp", -1))
		and int(live_summary.get("payload_bytes", 0)) == int(expected.get("payload_bytes", -1))
	)

func _load_resumed_target_for_surface(surface: String) -> String:
	return "outcome" if surface == "scenario_outcome" else surface

func _load_resumed_scene_path_for_surface(surface: String) -> String:
	match surface:
		"overworld":
			return OVERWORLD_SCENE
		"town":
			return TOWN_SCENE
		"battle":
			return BATTLE_SCENE
		"scenario_outcome":
			return SCENARIO_OUTCOME_SCENE
		_:
			return ""

func _clear_pending_load_resumed_presentation() -> void:
	_pending_load_resumed_presentation = {}

func _reconcile_pending_load_resumed_scene(scene_path: String) -> void:
	if _pending_load_resumed_presentation.is_empty():
		return
	if String(_pending_load_resumed_presentation.get("expected_scene_path", "")) != scene_path:
		_clear_pending_load_resumed_presentation()

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
	_reconcile_pending_load_resumed_scene(scene_path)
	var packed_scene := _packed_scene_for_route(scene_path)
	if packed_scene != null:
		var packed_error := get_tree().change_scene_to_packed(packed_scene)
		if packed_error != OK:
			_clear_pending_load_resumed_presentation()
			push_error("Failed to change scene to %s (error %d)." % [scene_path, packed_error])
		return
	if not ResourceLoader.exists(scene_path):
		_clear_pending_load_resumed_presentation()
		push_error("Scene file is missing: %s" % scene_path)
		return

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		_clear_pending_load_resumed_presentation()
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
