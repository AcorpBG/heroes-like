class_name HeroesAppRouter
extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const TownRulesScript = preload("res://scripts/core/TownRules.gd")

const MAIN_MENU_SCENE := "res://scenes/menus/MainMenu.tscn"
const SCENARIO_OUTCOME_SCENE := "res://scenes/results/ScenarioOutcomeShell.tscn"
const OVERWORLD_SCENE := "res://scenes/overworld/OverworldShell.tscn"
const BATTLE_SCENE := "res://scenes/battle/BattleShell.tscn"
const TOWN_SCENE := "res://scenes/town/TownShell.tscn"

var _menu_notice := ""

func go_to_main_menu() -> void:
	if SessionState.has_playable_session():
		var autosave_result := _autosave_active_session(SessionState.ensure_active_session())
		_menu_notice = String(autosave_result.get("message", ""))
	else:
		_menu_notice = ""
	_change_scene(MAIN_MENU_SCENE)

func return_to_main_menu_from_active_play() -> void:
	go_to_main_menu()

func go_to_overworld() -> void:
	if not SessionState.has_playable_session():
		push_warning("Cannot enter overworld without an active scenario session.")
		_change_scene(MAIN_MENU_SCENE)
		return

	var session := SessionState.ensure_active_session()
	if session.scenario_status != "in_progress":
		go_to_scenario_outcome()
		return
	session.game_state = "overworld"
	_autosave_active_session(session)
	_change_scene(OVERWORLD_SCENE)

func go_to_town() -> void:
	if not SessionState.has_playable_session():
		push_warning("Cannot enter a town without an active scenario session.")
		_change_scene(MAIN_MENU_SCENE)
		return
	if not TownRulesScript.can_visit_active_town_bridge(SessionState.ensure_active_session()):
		push_warning("Cannot enter a town without an active controlled town.")
		go_to_overworld()
		return

	var session := SessionState.ensure_active_session()
	if session.scenario_status != "in_progress":
		go_to_scenario_outcome()
		return
	session.game_state = "town"
	_autosave_active_session(session)
	_change_scene(TOWN_SCENE)

func go_to_battle() -> void:
	if not SessionState.has_playable_session():
		push_warning("Cannot enter battle without an active scenario session.")
		_change_scene(MAIN_MENU_SCENE)
		return
	if not SessionState.has_battle_state():
		push_warning("Cannot enter battle without an active battle payload.")
		go_to_overworld()
		return

	var session := SessionState.ensure_active_session()
	if session.scenario_status != "in_progress":
		go_to_scenario_outcome()
		return
	session.game_state = "battle"
	_autosave_active_session(session)
	_change_scene(BATTLE_SCENE)

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

func boot() -> void:
	go_to_main_menu()

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

func _change_scene(scene_path: String) -> void:
	if not FileAccess.file_exists(scene_path):
		push_error("Scene file is missing: %s" % scene_path)
		return

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Failed to change scene to %s (error %d)." % [scene_path, error])

func _autosave_active_session(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null or session.scenario_id == "":
		return {"ok": false, "message": "", "summary": {}}
	return SaveService.save_runtime_autosave_session(session)
