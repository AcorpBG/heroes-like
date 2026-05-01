extends Node

const REPORT_ID := "TOWN_TRANSITION_FAST_PATH_REGRESSION"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var previous_general := OS.get_environment("HEROES_PROFILE_LOG")
	OS.set_environment("HEROES_PROFILE_LOG", "1")
	SaveService.validation_clear_general_profile_log()

	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var town := _first_player_town(session)
	if town.is_empty():
		_finish_fail("No player town was available for transition fast-path coverage.")
		return
	_move_active_hero_to_town(session, town)
	var visit_result: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	if not bool(visit_result.get("ok", false)):
		_finish_fail("Could not prepare active town visit.", visit_result)
		return
	SessionState.set_active_session(session)
	session = SessionState.ensure_active_session()

	var town_result: Dictionary = AppRouter.validation_prepare_town_handoff_without_scene_change()
	if not _assert_transition_result(town_result, "go_to_town", "town"):
		return
	if not _assert_no_runtime_save_records("go_to_town"):
		return
	if not _assert_no_pending_autosave_intent(session, "go_to_town"):
		return

	var overworld_result: Dictionary = AppRouter.validation_prepare_overworld_handoff_without_scene_change()
	if not _assert_transition_result(overworld_result, "go_to_overworld", "overworld"):
		return
	if not _assert_no_runtime_save_records("go_to_overworld"):
		return
	if not _assert_no_pending_autosave_intent(session, "go_to_overworld"):
		return
	if int(session.flags.get("runtime_autosave_pending_count", 0)) != 0:
		_finish_fail("Ordinary town transitions should not record transition autosave intent counts.", session.flags)
		return

	OS.set_environment("HEROES_PROFILE_LOG", previous_general)
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"town_result": town_result,
		"overworld_result": overworld_result,
		"pending_count": int(session.flags.get("runtime_autosave_pending_count", 0)),
	})])
	get_tree().quit(0)

func _assert_transition_result(result: Dictionary, route: String, expected_state: String) -> bool:
	if not bool(result.get("ok", false)):
		_finish_fail("%s validation handoff failed." % route, result)
		return false
	if not bool(result.get("save_before_transition_skipped", false)):
		_finish_fail("%s did not mark save_before_transition skipped." % route, result)
		return false
	if bool(result.get("deferred_autosave", true)):
		_finish_fail("%s marked an ordinary transition as a deferred autosave." % route, result)
		return false
	var intent: Dictionary = result.get("autosave_intent", {}) if result.get("autosave_intent", {}) is Dictionary else {}
	if bool(intent.get("autosave_pending_intent", false)):
		_finish_fail("%s recorded a pending autosave intent for an ordinary transition." % route, result)
		return false
	if String(intent.get("autosave_skipped_reason", "")) != "manual_or_end_turn_only":
		_finish_fail("%s used the wrong autosave skip reason." % route, result)
		return false
	if String(intent.get("autosave_deferred_or_skipped_reason", "")) != "manual_or_end_turn_only":
		_finish_fail("%s used the wrong autosave skip/defer compatibility reason." % route, result)
		return false
	if intent.has("autosave_pending_route") or intent.has("autosave_pending_game_state") or intent.has("autosave_pending_count"):
		_finish_fail("%s exposed pending autosave metadata for a skipped ordinary transition." % route, result)
		return false
	if String(intent.get("transition_route", "")) != route:
		_finish_fail("%s recorded the wrong transition route." % route, result)
		return false
	if String(intent.get("transition_game_state", "")) != expected_state:
		_finish_fail("%s recorded the wrong transition game state." % route, result)
		return false
	return true

func _assert_no_runtime_save_records(label: String) -> bool:
	var records: Array = SaveService.validation_general_profile_log_last_records(20)
	for record in records:
		if record is Dictionary and String(record.get("surface", "")) == "save" and String(record.get("event", "")) == "runtime_save":
			_finish_fail("%s synchronously wrote a runtime autosave." % label, records)
			return false
	return true

func _assert_no_pending_autosave_intent(session, route: String) -> bool:
	if not bool(session.flags.get("runtime_autosave_dirty", false)):
		return true
	if bool(session.flags.get("runtime_autosave_pending_intent", false)):
		_finish_fail("%s kept pending autosave intent for a manual/end-turn-only save policy." % route, session.flags)
		return false
	if session.flags.has("runtime_autosave_pending_route") or session.flags.has("runtime_autosave_pending_game_state"):
		_finish_fail("%s kept transition autosave route/state flags for a skipped ordinary transition." % route, session.flags)
		return false
	return true

func _first_player_town(session) -> Dictionary:
	for candidate in session.overworld.get("towns", []):
		if candidate is Dictionary and String(candidate.get("owner", "")) == "player":
			return candidate
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _finish_fail(message: String, details: Variant = {}) -> void:
	OS.set_environment("HEROES_PROFILE_LOG", "")
	push_error("%s %s" % [message, JSON.stringify(details)])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "message": message, "details": details})])
	get_tree().quit(1)
