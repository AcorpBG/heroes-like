extends Node

const FLOW_BOOT_TO_SKIRMISH_OVERWORLD := "boot_to_skirmish_overworld"
const FLOW_BOOT_TO_SKIRMISH_TOWN_BATTLE := "boot_to_skirmish_town_battle"
const MAIN_MENU_SCENE := "res://scenes/menus/MainMenu.tscn"
const OVERWORLD_SCENE := "res://scenes/overworld/OverworldShell.tscn"
const TOWN_SCENE := "res://scenes/town/TownShell.tscn"
const BATTLE_SCENE := "res://scenes/battle/BattleShell.tscn"
const MAX_VALIDATION_ROUTE_STEPS := 32
const MAX_VALIDATION_BATTLE_ACTIONS := 24

var _enabled := false
var _config := {}
var _output_dir := ""
var _report := {}
var _log_lines: Array[String] = []
var _started_at_ms := 0

func _ready() -> void:
	_config = _parse_user_args(OS.get_cmdline_user_args())
	_enabled = bool(_config.get("enabled", false))
	if not _enabled:
		return
	call_deferred("_run_live_validation")

func _run_live_validation() -> void:
	_started_at_ms = Time.get_ticks_msec()
	_output_dir = _resolve_output_dir(String(_config.get("output_dir", "")))
	_ensure_output_dir()
	_begin_report()
	var success := await _execute_flow()
	_report["ok"] = success
	_report["completed_at_unix"] = Time.get_unix_time_from_system()
	_report["duration_ms"] = max(0, Time.get_ticks_msec() - _started_at_ms)
	_write_text_file(_log_path(), "\n".join(_log_lines))
	_write_json(_report_path(), _report)
	get_tree().quit(0 if success else 1)

func _execute_flow() -> bool:
	match String(_config.get("flow", "")):
		FLOW_BOOT_TO_SKIRMISH_OVERWORLD:
			return await _execute_boot_to_skirmish_overworld_flow()
		FLOW_BOOT_TO_SKIRMISH_TOWN_BATTLE:
			return await _execute_boot_to_skirmish_town_battle_flow()
		_:
			return _fail("Unsupported live validation flow requested.", {"flow": _config.get("flow", "")})

func _execute_boot_to_skirmish_overworld_flow() -> bool:
	var launch := await _enter_live_skirmish_overworld()
	if not bool(launch.get("ok", false)):
		return false
	var overworld = launch.get("overworld", null)
	if overworld == null:
		return _fail("Live launch did not provide an overworld scene instance.", launch)

	var action_result: Dictionary = overworld.call("validation_try_progress_action")
	if not _require(bool(action_result.get("ok", false)), "Overworld validation action did not change live state.", action_result):
		return false
	await _settle_frames(6)
	var after_action_snapshot: Dictionary = overworld.call("validation_snapshot")
	after_action_snapshot["progress_action"] = action_result
	_capture_step("overworld_progressed", after_action_snapshot)
	_log("Live validation flow completed successfully.")
	return true

func _execute_boot_to_skirmish_town_battle_flow() -> bool:
	var launch := await _enter_live_skirmish_overworld()
	if not bool(launch.get("ok", false)):
		return false
	var overworld = launch.get("overworld", null)
	if overworld == null:
		return _fail("Live launch did not provide an overworld scene instance.", launch)

	var town_route := await _route_from_overworld_to_scene(overworld, "town", "player", TOWN_SCENE)
	if not _require(bool(town_route.get("ok", false)), "Could not route from the live overworld into a player-owned town.", town_route):
		return false
	var town = town_route.get("scene", null)
	if town == null:
		return _fail("Town route completed without a town scene instance.", town_route)
	await _settle_frames(6)

	var town_snapshot: Dictionary = town.call("validation_snapshot")
	town_snapshot["route_history"] = town_route.get("history", [])
	_capture_step("town_entered", town_snapshot)

	var town_action: Dictionary = town.call("validation_try_progress_action")
	if not _require(bool(town_action.get("ok", false)), "Town validation action did not change live state.", town_action):
		return false
	await _settle_frames(6)
	var town_after_snapshot: Dictionary = town.call("validation_snapshot")
	town_after_snapshot["progress_action"] = town_action
	_capture_step("town_progressed", town_after_snapshot)

	var manual_slot := int(_config.get("manual_slot", 2))
	if not _require(
		bool(town.call("validation_select_save_slot", manual_slot)),
		"Town validation could not select the requested manual save slot.",
		{
			"manual_slot": manual_slot,
			"town_snapshot": town.call("validation_snapshot"),
		}
	):
		return false
	await _settle_frames(3)

	var town_save: Dictionary = town.call("validation_save_to_selected_slot")
	var town_save_summary := _dictionary_value(town_save.get("summary", {}))
	if not _require(bool(town_save.get("ok", false)), "Town validation could not write a manual save from the live shell.", town_save):
		return false
	if not _require(int(town_save.get("selected_slot", 0)) == manual_slot, "Town validation saved into the wrong manual slot.", town_save):
		return false
	if not _require(String(town_save_summary.get("resume_target", "")) == "town", "Town manual save did not advertise town resume.", town_save_summary):
		return false
	if not _require(String(town_save_summary.get("scenario_id", "")) == String(_config.get("scenario_id", "")), "Town manual save summary scenario id did not match the launched scenario.", town_save_summary):
		return false
	await _settle_frames(6)
	var town_saved_snapshot: Dictionary = town.call("validation_snapshot")
	town_saved_snapshot["manual_save"] = town_save
	_capture_step("town_saved", town_saved_snapshot)
	var expected_town_resume_signature := _town_resume_signature(town_saved_snapshot)

	var town_menu_return: Dictionary = town.call("validation_return_to_menu")
	if not _require(bool(town_menu_return.get("ok", false)), "Town validation could not return to the main menu through the live router.", town_menu_return):
		return false
	var menu = await _wait_for_scene(MAIN_MENU_SCENE, 10000)
	if menu == null:
		return _fail("Returning to menu after the town manual save did not reach the main menu scene.", town_menu_return)
	await _settle_frames(8)

	var latest_summary_after_menu_return := SaveService.latest_loadable_summary()
	if not _require(not latest_summary_after_menu_return.is_empty(), "Latest save summary was unavailable after town return-to-menu routing.", town_menu_return):
		return false
	if not _require(String(latest_summary_after_menu_return.get("scenario_id", "")) == String(_config.get("scenario_id", "")), "Latest save summary after town return-to-menu did not match the launched scenario.", latest_summary_after_menu_return):
		return false
	if not _require(String(latest_summary_after_menu_return.get("resume_target", "")) == "town", "Latest save summary after town return-to-menu did not point back to the town surface.", latest_summary_after_menu_return):
		return false
	var menu_after_return_snapshot: Dictionary = menu.call("validation_snapshot")
	menu_after_return_snapshot["menu_return"] = town_menu_return
	menu_after_return_snapshot["latest_save_summary"] = latest_summary_after_menu_return
	_capture_step("main_menu_after_town_return", menu_after_return_snapshot)

	menu.call("validation_open_saves_stage")
	await _settle_frames(4)
	if not _require(
		bool(menu.call("validation_select_save_summary", "manual", str(manual_slot))),
		"Main menu save browser could not select the routed town manual save.",
		menu.call("validation_snapshot")
	):
		return false
	await _settle_frames(4)
	var town_resume: Dictionary = menu.call("validation_resume_selected_save")
	if not _require(bool(town_resume.get("ok", false)), "Main menu resume did not restore the selected routed town save.", town_resume):
		return false
	var resumed_town = await _wait_for_scene(TOWN_SCENE, 10000)
	if resumed_town == null:
		return _fail("Resuming the selected manual town save did not route back into the town scene.", town_resume)
	await _settle_frames(6)

	var resumed_town_snapshot: Dictionary = resumed_town.call("validation_snapshot")
	if not _require(String(resumed_town_snapshot.get("game_state", "")) == "town", "Resumed town save did not restore the town surface.", resumed_town_snapshot):
		return false
	var actual_town_resume_signature := _town_resume_signature(resumed_town_snapshot)
	if not _require(
		JSON.stringify(actual_town_resume_signature) == JSON.stringify(expected_town_resume_signature),
		"Town manual save/resume did not preserve the routed town state.",
		{
			"expected": expected_town_resume_signature,
			"actual": actual_town_resume_signature,
		}
	):
		return false
	resumed_town_snapshot["resume"] = town_resume
	_capture_step("town_resumed", resumed_town_snapshot)
	town = resumed_town

	var leave_result: Dictionary = town.call("validation_leave_town")
	if not _require(bool(leave_result.get("ok", false)), "Town validation could not leave through the live router.", leave_result):
		return false
	var post_town_overworld = await _wait_for_scene(OVERWORLD_SCENE, 10000)
	if post_town_overworld == null:
		return _fail("Leaving town did not route back into the overworld scene.", leave_result)
	await _settle_frames(6)
	var overworld_after_town: Dictionary = post_town_overworld.call("validation_snapshot")
	overworld_after_town["town_exit"] = leave_result
	_capture_step("overworld_after_town", overworld_after_town)

	var battle_route := await _route_from_overworld_to_scene(post_town_overworld, "encounter", "", BATTLE_SCENE)
	if not _require(bool(battle_route.get("ok", false)), "Could not route from the live overworld into a battle encounter.", battle_route):
		return false
	var battle = battle_route.get("scene", null)
	if battle == null:
		return _fail("Battle route completed without a battle scene instance.", battle_route)
	await _settle_frames(6)

	var battle_snapshot: Dictionary = battle.call("validation_snapshot")
	battle_snapshot["route_history"] = battle_route.get("history", [])
	_capture_step("battle_entered", battle_snapshot)
	var battle_resume := await _save_and_resume_battle_from_main_menu(battle, manual_slot)
	if not bool(battle_resume.get("ok", false)):
		return false
	battle = battle_resume.get("battle", battle)

	var battle_actions := []
	var battle_progress_captured := false
	var current_battle = battle
	for _action_index in range(MAX_VALIDATION_BATTLE_ACTIONS):
		if current_battle == null:
			break
		var battle_action: Dictionary = current_battle.call("validation_try_progress_action")
		battle_actions.append(battle_action.duplicate(true))
		if not _require(bool(battle_action.get("ok", false)), "Battle validation action did not change live state.", battle_action):
			return false
		await _settle_frames(6)
		var current_scene = get_tree().current_scene
		if current_scene == null:
			continue
		var scene_path := String(current_scene.scene_file_path)
		if scene_path == BATTLE_SCENE and not battle_progress_captured:
			var battle_mid_snapshot: Dictionary = current_scene.call("validation_snapshot")
			battle_mid_snapshot["progress_action"] = battle_action
			_capture_step("battle_progressed", battle_mid_snapshot)
			battle_progress_captured = true
		if scene_path == OVERWORLD_SCENE:
			var overworld_after_battle: Dictionary = current_scene.call("validation_snapshot")
			overworld_after_battle["battle_actions"] = battle_actions
			_capture_step("overworld_after_battle", overworld_after_battle)
			_log("Live validation flow completed successfully.")
			return true
		if scene_path != BATTLE_SCENE:
			return _fail(
				"Battle validation routed to an unexpected scene.",
				{
					"scene_path": scene_path,
					"battle_actions": battle_actions,
				}
			)
		current_battle = current_scene

	var final_battle_payload := {"battle_actions": battle_actions}
	if current_battle != null and String(current_battle.scene_file_path) == BATTLE_SCENE:
		final_battle_payload["battle_snapshot"] = current_battle.call("validation_snapshot")
	return _fail("Battle validation did not resolve within the action budget.", final_battle_payload)

func _enter_live_skirmish_overworld() -> Dictionary:
	_log("Waiting for main menu boot route.")
	var menu = await _wait_for_scene(MAIN_MENU_SCENE, 10000)
	if menu == null:
		_fail("Boot did not reach the main menu scene.", {})
		return {"ok": false}
	await _settle_frames(8)

	var menu_snapshot: Dictionary = menu.call("validation_snapshot")
	if not _require(int(menu_snapshot.get("skirmish_count", 0)) > 0, "Main menu skirmish browser did not populate.", menu_snapshot):
		return {"ok": false}
	menu.call("validation_open_skirmish_stage")
	await _settle_frames(4)
	if not _require(
		bool(menu.call("validation_select_skirmish", String(_config.get("scenario_id", "")))),
		"Requested skirmish scenario is not available in the live menu.",
		menu.call("validation_snapshot")
	):
		return {"ok": false}
	if not _require(
		bool(menu.call("validation_set_difficulty", String(_config.get("difficulty", "")))),
		"Requested difficulty is not available in the live menu.",
		menu.call("validation_snapshot")
	):
		return {"ok": false}
	menu_snapshot = menu.call("validation_snapshot")
	_capture_step("main_menu", menu_snapshot)

	var launch_result: Dictionary = menu.call("validation_start_selected_skirmish")
	if not _require(bool(launch_result.get("started", false)), "Skirmish launch did not stage an active session.", launch_result):
		return {"ok": false}

	_log("Waiting for overworld route after live menu launch.")
	var overworld = await _wait_for_scene(OVERWORLD_SCENE, 10000)
	if overworld == null:
		_fail("Live launch did not route into the overworld scene.", {"launch": launch_result})
		return {"ok": false}
	await _settle_frames(8)

	var overworld_snapshot: Dictionary = overworld.call("validation_snapshot")
	if not _require(String(overworld_snapshot.get("scenario_id", "")) == String(_config.get("scenario_id", "")), "Overworld session scenario id did not match the requested live launch.", overworld_snapshot):
		return {"ok": false}
	if not _require(String(overworld_snapshot.get("game_state", "")) == "overworld", "Overworld scene did not hold an overworld game state.", overworld_snapshot):
		return {"ok": false}
	if not _require(int(overworld_snapshot.get("movement_current", 0)) > 0, "Overworld scene started without any current movement budget.", overworld_snapshot):
		return {"ok": false}
	var latest_summary: Dictionary = SaveService.latest_loadable_summary()
	if not _require(not latest_summary.is_empty(), "Autosave summary was not available after routing into the overworld.", overworld_snapshot):
		return {"ok": false}
	if not _require(String(latest_summary.get("scenario_id", "")) == String(_config.get("scenario_id", "")), "Autosave summary scenario id did not match the launched scenario.", latest_summary):
		return {"ok": false}
	overworld_snapshot["autosave_summary"] = latest_summary
	_capture_step("overworld_entered", overworld_snapshot)
	return {
		"ok": true,
		"overworld": overworld,
	}

func _route_from_overworld_to_scene(overworld, target_kind: String, owner_id: String, destination_scene: String) -> Dictionary:
	var history := []
	var current_overworld = overworld
	for _step_index in range(MAX_VALIDATION_ROUTE_STEPS):
		if current_overworld == null:
			break
		var route_result: Dictionary = current_overworld.call("validation_route_step_to_nearest_target", target_kind, owner_id)
		history.append(route_result.duplicate(true))
		if not bool(route_result.get("ok", false)):
			return {
				"ok": false,
				"target_kind": target_kind,
				"destination_scene": destination_scene,
				"history": history,
				"message": String(route_result.get("message", "Route step failed.")),
			}
		await _settle_frames(6)
		var current_scene = get_tree().current_scene
		if current_scene == null:
			continue
		var scene_path := String(current_scene.scene_file_path)
		if scene_path == destination_scene:
			return {
				"ok": true,
				"scene": current_scene,
				"history": history,
			}
		if scene_path != OVERWORLD_SCENE:
			return {
				"ok": false,
				"target_kind": target_kind,
				"destination_scene": destination_scene,
				"scene_path": scene_path,
				"history": history,
				"message": "Route entered an unexpected scene.",
			}
		current_overworld = current_scene
	return {
		"ok": false,
		"target_kind": target_kind,
		"destination_scene": destination_scene,
		"history": history,
		"message": "Route did not reach the requested scene within the step budget.",
	}

func _save_and_resume_battle_from_main_menu(battle, manual_slot: int) -> Dictionary:
	if not _require(
		bool(battle.call("validation_select_save_slot", manual_slot)),
		"Battle validation could not select the requested manual save slot.",
		{
			"manual_slot": manual_slot,
			"battle_snapshot": battle.call("validation_snapshot"),
		}
	):
		return {"ok": false}
	await _settle_frames(3)

	var battle_save: Dictionary = battle.call("validation_save_to_selected_slot")
	var battle_save_summary := _dictionary_value(battle_save.get("summary", {}))
	if not _require(bool(battle_save.get("ok", false)), "Battle validation could not write a manual save from the live shell.", battle_save):
		return {"ok": false}
	if not _require(int(battle_save.get("selected_slot", 0)) == manual_slot, "Battle validation saved into the wrong manual slot.", battle_save):
		return {"ok": false}
	if not _require(String(battle_save_summary.get("resume_target", "")) == "battle", "Battle manual save did not advertise battle resume.", battle_save_summary):
		return {"ok": false}
	if not _require(String(battle_save_summary.get("scenario_id", "")) == String(_config.get("scenario_id", "")), "Battle manual save summary scenario id did not match the launched scenario.", battle_save_summary):
		return {"ok": false}
	if not _require(String(battle_save_summary.get("battle_name", "")) != "", "Battle manual save summary did not expose the routed battle name.", battle_save_summary):
		return {"ok": false}
	await _settle_frames(6)

	var battle_saved_snapshot: Dictionary = battle.call("validation_snapshot")
	battle_saved_snapshot["manual_save"] = battle_save
	_capture_step("battle_saved", battle_saved_snapshot)
	var expected_battle_resume_signature := _battle_resume_signature(battle_saved_snapshot)

	var battle_menu_return: Dictionary = battle.call("validation_return_to_menu")
	if not _require(bool(battle_menu_return.get("ok", false)), "Battle validation could not return to the main menu through the live router.", battle_menu_return):
		return {"ok": false}
	var menu = await _wait_for_scene(MAIN_MENU_SCENE, 10000)
	if menu == null:
		_fail("Returning to menu after the battle manual save did not reach the main menu scene.", battle_menu_return)
		return {"ok": false}
	await _settle_frames(8)

	var latest_summary_after_menu_return := SaveService.latest_loadable_summary()
	if not _require(not latest_summary_after_menu_return.is_empty(), "Latest save summary was unavailable after battle return-to-menu routing.", battle_menu_return):
		return {"ok": false}
	if not _require(String(latest_summary_after_menu_return.get("scenario_id", "")) == String(_config.get("scenario_id", "")), "Latest save summary after battle return-to-menu did not match the launched scenario.", latest_summary_after_menu_return):
		return {"ok": false}
	if not _require(String(latest_summary_after_menu_return.get("resume_target", "")) == "battle", "Latest save summary after battle return-to-menu did not point back to the battle surface.", latest_summary_after_menu_return):
		return {"ok": false}
	var menu_after_return_snapshot: Dictionary = menu.call("validation_snapshot")
	menu_after_return_snapshot["menu_return"] = battle_menu_return
	menu_after_return_snapshot["latest_save_summary"] = latest_summary_after_menu_return
	_capture_step("main_menu_after_battle_return", menu_after_return_snapshot)

	menu.call("validation_open_saves_stage")
	await _settle_frames(4)
	if not _require(
		bool(menu.call("validation_select_save_summary", "manual", str(manual_slot))),
		"Main menu save browser could not select the routed battle manual save.",
		menu.call("validation_snapshot")
	):
		return {"ok": false}
	await _settle_frames(4)

	var battle_resume: Dictionary = menu.call("validation_resume_selected_save")
	if not _require(bool(battle_resume.get("ok", false)), "Main menu resume did not restore the selected routed battle save.", battle_resume):
		return {"ok": false}
	var resumed_battle = await _wait_for_scene(BATTLE_SCENE, 10000)
	if resumed_battle == null:
		_fail("Resuming the selected manual battle save did not route back into the battle scene.", battle_resume)
		return {"ok": false}
	await _settle_frames(6)

	var resumed_battle_snapshot: Dictionary = resumed_battle.call("validation_snapshot")
	if not _require(String(resumed_battle_snapshot.get("game_state", "")) == "battle", "Resumed battle save did not restore the battle surface.", resumed_battle_snapshot):
		return {"ok": false}
	var actual_battle_resume_signature := _battle_resume_signature(resumed_battle_snapshot)
	if not _require(
		JSON.stringify(actual_battle_resume_signature) == JSON.stringify(expected_battle_resume_signature),
		"Battle manual save/resume did not preserve the routed battle state.",
		{
			"expected": expected_battle_resume_signature,
			"actual": actual_battle_resume_signature,
		}
	):
		return {"ok": false}
	resumed_battle_snapshot["resume"] = battle_resume
	_capture_step("battle_resumed", resumed_battle_snapshot)
	return {
		"ok": true,
		"battle": resumed_battle,
	}

func _parse_user_args(args: Array) -> Dictionary:
	var config := {
		"enabled": false,
		"flow": "",
		"scenario_id": "river-pass",
		"difficulty": "normal",
		"manual_slot": 2,
		"output_dir": "",
	}
	for raw_arg in args:
		var arg := String(raw_arg)
		if arg == "--live-validation":
			config["enabled"] = true
			if String(config.get("flow", "")) == "":
				config["flow"] = FLOW_BOOT_TO_SKIRMISH_TOWN_BATTLE
			continue
		if arg.begins_with("--live-validation-flow="):
			config["enabled"] = true
			config["flow"] = arg.trim_prefix("--live-validation-flow=")
			continue
		if arg.begins_with("--live-validation-scenario="):
			config["enabled"] = true
			config["scenario_id"] = arg.trim_prefix("--live-validation-scenario=")
			continue
		if arg.begins_with("--live-validation-difficulty="):
			config["enabled"] = true
			config["difficulty"] = arg.trim_prefix("--live-validation-difficulty=")
			continue
		if arg.begins_with("--live-validation-manual-slot="):
			config["enabled"] = true
			config["manual_slot"] = int(arg.trim_prefix("--live-validation-manual-slot="))
			continue
		if arg.begins_with("--live-validation-output="):
			config["enabled"] = true
			config["output_dir"] = arg.trim_prefix("--live-validation-output=")
			continue
	if bool(config.get("enabled", false)) and String(config.get("flow", "")) == "":
		config["flow"] = FLOW_BOOT_TO_SKIRMISH_TOWN_BATTLE
	return config

func _resolve_output_dir(path_value: String) -> String:
	if path_value == "":
		return ProjectSettings.globalize_path("user://live_validation/%d" % int(Time.get_unix_time_from_system()))
	if path_value.begins_with("res://") or path_value.begins_with("user://"):
		return ProjectSettings.globalize_path(path_value)
	return path_value

func _ensure_output_dir() -> void:
	var error := DirAccess.make_dir_recursive_absolute(_output_dir)
	if error != OK:
		push_error("Live validation could not create output directory %s (error %d)." % [_output_dir, error])

func _begin_report() -> void:
	_report = {
		"ok": false,
		"flow": String(_config.get("flow", "")),
		"scenario_id": String(_config.get("scenario_id", "")),
		"difficulty": String(_config.get("difficulty", "")),
		"manual_slot": int(_config.get("manual_slot", 0)),
		"output_dir": _output_dir,
		"display": OS.get_environment("DISPLAY"),
		"engine_version": Engine.get_version_info(),
		"started_at_unix": Time.get_unix_time_from_system(),
		"steps": [],
		"errors": [],
		"log_path": _log_path(),
		"report_path": _report_path(),
	}
	_log("Live validation enabled for flow %s." % String(_config.get("flow", "")))
	_log("Artifacts will be written under %s." % _output_dir)

func _capture_step(step_id: String, payload: Dictionary) -> void:
	var screenshot_path := _capture_screenshot(step_id)
	var steps: Array = _report.get("steps", [])
	steps.append(
		{
			"id": step_id,
			"scene_path": _current_scene_path(),
			"screenshot": screenshot_path,
			"payload": payload.duplicate(true),
		}
	)
	_report["steps"] = steps
	_log("Captured step %s." % step_id)

func _capture_screenshot(step_id: String) -> String:
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_log("Screenshot skipped for %s because the viewport image was unavailable." % step_id)
		return ""
	image.flip_y()
	var path := "%s/%s.png" % [_output_dir, step_id]
	var error := image.save_png(path)
	if error != OK:
		_log("Screenshot save failed for %s (error %d)." % [step_id, error])
		return ""
	return path

func _wait_for_scene(scene_path: String, timeout_ms: int):
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() <= deadline:
		var current := get_tree().current_scene
		if current != null and String(current.scene_file_path) == scene_path:
			return current
		await get_tree().process_frame
	return null

func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await get_tree().process_frame

func _current_scene_path() -> String:
	var current := get_tree().current_scene
	return "" if current == null else String(current.scene_file_path)

func _require(condition: bool, message: String, payload: Dictionary) -> bool:
	if condition:
		return true
	return _fail(message, payload)

func _fail(message: String, payload: Dictionary) -> bool:
	var errors: Array = _report.get("errors", [])
	errors.append(
		{
			"message": message,
			"scene_path": _current_scene_path(),
			"payload": payload.duplicate(true),
			"screenshot": _capture_screenshot("failure"),
		}
	)
	_report["errors"] = errors
	_log("FAIL: %s" % message)
	return false

func _log(message: String) -> void:
	var line := "[live-validation] %s" % message
	print(line)
	_log_lines.append(line)

func _report_path() -> String:
	return "%s/live_validation_report.json" % _output_dir

func _log_path() -> String:
	return "%s/live_validation.log" % _output_dir

func _town_resume_signature(snapshot: Dictionary) -> Dictionary:
	return {
		"scenario_id": String(snapshot.get("scenario_id", "")),
		"difficulty": String(snapshot.get("difficulty", "")),
		"launch_mode": String(snapshot.get("launch_mode", "")),
		"game_state": String(snapshot.get("game_state", "")),
		"day": int(snapshot.get("day", 0)),
		"town_placement_id": String(snapshot.get("town_placement_id", "")),
		"town_id": String(snapshot.get("town_id", "")),
		"town_owner": String(snapshot.get("town_owner", "")),
		"built_building_count": int(snapshot.get("built_building_count", 0)),
		"available_recruits": _dictionary_value(snapshot.get("available_recruits", {})),
		"resources": _dictionary_value(snapshot.get("resources", {})),
	}

func _battle_resume_signature(snapshot: Dictionary) -> Dictionary:
	return {
		"scenario_id": String(snapshot.get("scenario_id", "")),
		"difficulty": String(snapshot.get("difficulty", "")),
		"launch_mode": String(snapshot.get("launch_mode", "")),
		"game_state": String(snapshot.get("game_state", "")),
		"encounter_id": String(snapshot.get("encounter_id", "")),
		"encounter_name": String(snapshot.get("encounter_name", "")),
		"battle_context_type": String(snapshot.get("battle_context_type", "")),
		"round": int(snapshot.get("round", 0)),
		"distance": int(snapshot.get("distance", 0)),
		"active_side": String(snapshot.get("active_side", "")),
		"active_stack": String(snapshot.get("active_stack", "")),
		"target_stack": String(snapshot.get("target_stack", "")),
		"player_roster": _string_array_value(snapshot.get("player_roster", [])),
		"enemy_roster": _string_array_value(snapshot.get("enemy_roster", [])),
	}

func _dictionary_value(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _string_array_value(value: Variant) -> Array[String]:
	var normalized: Array[String] = []
	if not (value is Array):
		return normalized
	for entry in value:
		normalized.append(String(entry))
	return normalized

func _write_json(path: String, payload: Dictionary) -> void:
	_write_text_file(path, JSON.stringify(payload, "\t"))

func _write_text_file(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Live validation could not open %s for writing." % path)
		return
	file.store_string(content)
	file.close()
