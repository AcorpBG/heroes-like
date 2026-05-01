extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "TOWN_EXIT_PROFILE_ACCURACY_REGRESSION"
const TOWN_SCENE := "res://scenes/town/TownShell.tscn"
const OVERWORLD_SCENE := "res://scenes/overworld/OverworldShell.tscn"
const EXIT_BUDGET_MS := 1000.0
const WALL_PROFILE_TOLERANCE_MS := 120.0
const BUCKET_SUM_TOLERANCE_MS := 35.0
const GENERATED_LARGE_SEED := "town-exit-profile-accuracy-10184"

var _previous_general_profile_env := ""

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	_detach_from_current_scene()
	call_deferred("_run")

func _detach_from_current_scene() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if get_parent() != tree.root:
		var parent := get_parent()
		parent.remove_child(self)
		tree.root.add_child(self)
	if tree.current_scene == self:
		var anchor := Node.new()
		anchor.name = "TownExitProfileAccuracySceneAnchor"
		tree.root.add_child(anchor)
		tree.current_scene = anchor

func _run() -> void:
	_previous_general_profile_env = OS.get_environment("HEROES_PROFILE_LOG")
	OS.set_environment("HEROES_PROFILE_LOG", "1")
	SaveService.validation_clear_general_profile_log()
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()

	var cases := []
	var river_session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var river_result: Dictionary = await _run_exit_case("river_pass", river_session)
	if river_result.is_empty():
		return
	cases.append(river_result)

	var large_session = _generated_large_session()
	if large_session == null:
		_fail("Could not create generated Large session for exit profiling.")
		return
	var large_result: Dictionary = await _run_exit_case("generated_large", large_session)
	if large_result.is_empty():
		return
	cases.append(large_result)

	OS.set_environment("HEROES_PROFILE_LOG", _previous_general_profile_env)
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"cases": cases,
	})])
	ContentService.clear_generated_scenario_drafts()
	get_tree().quit(0)

func _run_exit_case(label: String, session) -> Dictionary:
	if session == null:
		_fail("%s session was null." % label)
		return {}
	OverworldRules.normalize_overworld_state(session)
	var town := _first_player_town(session)
	if town.is_empty():
		_fail("%s had no player town." % label)
		return {}
	_move_active_hero_to_town(session, town)
	_mark_ordinary_overworld_opened(session)
	var placement_id := String(town.get("placement_id", ""))
	var visit_result: Dictionary = OverworldRules.set_active_town_visit(session, placement_id)
	if not bool(visit_result.get("ok", false)):
		_fail("%s could not prepare active town visit: %s" % [label, JSON.stringify(visit_result)])
		return {}
	SessionState.set_active_session(session)
	session = SessionState.ensure_active_session()
	session.flags.erase("town_return_handoff")
	var scene_error := get_tree().change_scene_to_file(TOWN_SCENE)
	if scene_error != OK:
		_fail("%s could not change to TownShell: %d" % [label, scene_error])
		return {}
	for _i in range(4):
		await get_tree().process_frame
	var town_shell := get_tree().current_scene
	if town_shell == null or String(town_shell.scene_file_path) != TOWN_SCENE or not town_shell.has_method("validation_leave_town"):
		_fail("%s did not reach TownShell before exit." % label)
		return {}

	SaveService.validation_clear_general_profile_log()
	var wall_started_usec := Time.get_ticks_usec()
	var leave_result: Dictionary = town_shell.call("validation_leave_town")
	if not bool(leave_result.get("ok", false)):
		_fail("%s leave hook failed: %s" % [label, JSON.stringify(leave_result)])
		return {}

	var profile := {}
	var overworld_reached := false
	for _i in range(180):
		await get_tree().process_frame
		var current := get_tree().current_scene
		overworld_reached = current != null and String(current.scene_file_path) == OVERWORLD_SCENE
		profile = AppRouter.validation_latest_overworld_handoff_profile()
		if overworld_reached and String(profile.get("reason", "")) == "town_exit" and not bool(profile.get("active", true)):
			break
	var wall_ms := float(Time.get_ticks_usec() - wall_started_usec) / 1000.0
	if not overworld_reached:
		_fail("%s did not reach OverworldShell after Leave." % label)
		return {}
	if profile.is_empty() or bool(profile.get("active", true)):
		_fail("%s did not finish town-exit handoff profile: %s" % [label, JSON.stringify(profile)])
		return {}

	var records: Array = SaveService.validation_general_profile_log_last_records(80)
	if _has_save_or_surface_record(records):
		_fail("%s town exit built save/autosave/save-surface records: %s" % [label, JSON.stringify(records)])
		return {}
	var exit_record := _find_record(records, "town", "exit_handoff", "town_exit_first_overworld_frame")
	if exit_record.is_empty():
		_fail("%s did not emit the end-to-end town exit JSONL record: %s" % [label, JSON.stringify(records)])
		return {}
	var router_record := _find_record(records, "router", "scene_transition", "go_to_overworld")
	if router_record.is_empty():
		_fail("%s did not preserve the router go_to_overworld record: %s" % [label, JSON.stringify(records)])
		return {}

	var record_total_ms := float(exit_record.get("total_ms", -1.0))
	var router_only_ms := float(router_record.get("total_ms", -1.0))
	var metadata: Dictionary = exit_record.get("metadata", {}) if exit_record.get("metadata", {}) is Dictionary else {}
	var first_frame_ms := float(metadata.get("first_overworld_frame_ms", -1.0))
	var first_ready_ms := float(metadata.get("first_overworld_ready_ms", -1.0))
	var buckets: Dictionary = exit_record.get("buckets_ms", {}) if exit_record.get("buckets_ms", {}) is Dictionary else {}
	var bucket_sum_ms := _sum_buckets(buckets)
	if absf(record_total_ms - wall_ms) > WALL_PROFILE_TOLERANCE_MS:
		_fail("%s profile total did not match wall clock: %s" % [label, JSON.stringify({
			"record_total_ms": record_total_ms,
			"wall_ms": wall_ms,
			"tolerance_ms": WALL_PROFILE_TOLERANCE_MS,
			"record": exit_record,
		})])
		return {}
	if absf(bucket_sum_ms - record_total_ms) > BUCKET_SUM_TOLERANCE_MS:
		_fail("%s exit buckets did not reconcile with total: %s" % [label, JSON.stringify({
			"bucket_sum_ms": bucket_sum_ms,
			"record_total_ms": record_total_ms,
			"buckets": buckets,
		})])
		return {}
	if first_frame_ms < 0.0 or first_ready_ms < 0.0:
		_fail("%s exit record missed first ready/frame markers: %s" % [label, JSON.stringify(exit_record)])
		return {}
	if record_total_ms > EXIT_BUDGET_MS:
		_fail("%s corrected end-to-end town exit exceeded budget: %s" % [label, JSON.stringify({
			"record_total_ms": record_total_ms,
			"wall_ms": wall_ms,
			"router_only_ms": router_only_ms,
			"buckets": buckets,
		})])
		return {}
	if router_only_ms > record_total_ms + WALL_PROFILE_TOLERANCE_MS:
		_fail("%s router-only timing exceeded corrected end-to-end timing unexpectedly: %s" % [label, JSON.stringify({
			"record_total_ms": record_total_ms,
			"router_only_ms": router_only_ms,
		})])
		return {}
	return {
		"label": label,
		"town_placement_id": placement_id,
		"wall_ms": snapped(wall_ms, 0.001),
		"profile_total_ms": snapped(record_total_ms, 0.001),
		"router_only_ms": snapped(router_only_ms, 0.001),
		"first_ready_ms": snapped(first_ready_ms, 0.001),
		"first_frame_ms": snapped(first_frame_ms, 0.001),
		"bucket_sum_ms": snapped(bucket_sum_ms, 0.001),
		"top_buckets": _top_buckets(buckets, 8),
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
		push_error("Generated Large setup failed: %s" % JSON.stringify(setup))
		return null
	return ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)

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

func _mark_ordinary_overworld_opened(session) -> void:
	if session == null:
		return
	session.flags.erase("generated_overworld_deferred_autosave_pending")
	session.flags.erase("generated_overworld_command_briefing_autosave_deferred")
	if bool(session.flags.get("generated_random_map", false)):
		session.flags["generated_overworld_initial_autosave_completed"] = true
	var briefing_state = session.overworld.get("command_briefing", {})
	if not (briefing_state is Dictionary):
		briefing_state = {}
	briefing_state["shown"] = true
	briefing_state["shown_day"] = max(1, int(session.day))
	session.overworld["command_briefing"] = briefing_state

func _find_record(records: Array, surface: String, phase: String, event: String) -> Dictionary:
	for record in records:
		if record is Dictionary and String(record.get("surface", "")) == surface and String(record.get("phase", "")) == phase and String(record.get("event", "")) == event:
			return record
	return {}

func _has_save_or_surface_record(records: Array) -> bool:
	for record in records:
		if not (record is Dictionary):
			continue
		if String(record.get("surface", "")) != "save":
			continue
		var event := String(record.get("event", ""))
		if event in ["runtime_save", "build_in_session_save_surface"]:
			return true
	return false

func _sum_buckets(buckets: Dictionary) -> float:
	var total := 0.0
	for key in buckets.keys():
		var value = buckets.get(key)
		if value is int or value is float:
			total += float(value)
	return snapped(total, 0.001)

func _top_buckets(buckets: Dictionary, limit: int) -> Array:
	var items := []
	for key in buckets.keys():
		var value = buckets.get(key)
		if value is int or value is float:
			items.append({"name": String(key), "ms": float(value)})
	items.sort_custom(func(a, b): return float(a.get("ms", 0.0)) > float(b.get("ms", 0.0)))
	return items.slice(0, mini(limit, items.size()))

func _fail(message: String) -> void:
	OS.set_environment("HEROES_PROFILE_LOG", _previous_general_profile_env)
	ContentService.clear_generated_scenario_drafts()
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "message": message})])
	get_tree().quit(1)
