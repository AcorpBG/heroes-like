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
const AUTOSAVE_DIRTY_FLAG := "runtime_autosave_dirty"
const AUTOSAVE_PENDING_INTENT_FLAG := "runtime_autosave_pending_intent"
const AUTOSAVE_PENDING_REASON_FLAG := "runtime_autosave_pending_reason"
const AUTOSAVE_PENDING_ROUTE_FLAG := "runtime_autosave_pending_route"
const AUTOSAVE_PENDING_GAME_STATE_FLAG := "runtime_autosave_pending_game_state"
const AUTOSAVE_PENDING_COUNT_FLAG := "runtime_autosave_pending_count"
const AUTOSAVE_PENDING_UNIX_FLAG := "runtime_autosave_pending_unix"

var _menu_notice := ""
var _active_overworld_handoff_profile := {}
var _last_overworld_handoff_profile := {}

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
	if not SessionState.has_playable_session():
		return {"ok": false, "message": "No active expedition is available to save.", "summary": {}}
	return SaveService.save_runtime_selected_manual_session(SessionState.ensure_active_session())

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
	_last_overworld_handoff_profile = _active_overworld_handoff_profile.duplicate(true)
	_active_overworld_handoff_profile = {}
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
	var autosave_intent := _record_transition_autosave_skip(session, "go_to_town", "manual_or_end_turn_only")
	return {
		"ok": true,
		"deferred_autosave": false,
		"save_before_transition_skipped": true,
		"autosave_intent": autosave_intent,
	}

func _change_scene(scene_path: String) -> void:
	if not FileAccess.file_exists(scene_path):
		push_error("Scene file is missing: %s" % scene_path)
		return

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Failed to change scene to %s (error %d)." % [scene_path, error])

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

func _battle_stack_count(session: SessionStateStoreScript.SessionData) -> int:
	if session == null or not (session.battle is Dictionary):
		return 0
	var stacks = session.battle.get("stacks", [])
	return stacks.size() if stacks is Array else 0
