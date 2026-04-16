extends Node

const FLOW_BOOT_TO_SKIRMISH_OVERWORLD := "boot_to_skirmish_overworld"
const FLOW_BOOT_TO_SKIRMISH_TOWN_BATTLE := "boot_to_skirmish_town_battle"
const FLOW_BOOT_TO_SKIRMISH_RESOLVED_OUTCOME := "boot_to_skirmish_resolved_outcome"
const MAIN_MENU_SCENE := "res://scenes/menus/MainMenu.tscn"
const OVERWORLD_SCENE := "res://scenes/overworld/OverworldShell.tscn"
const TOWN_SCENE := "res://scenes/town/TownShell.tscn"
const BATTLE_SCENE := "res://scenes/battle/BattleShell.tscn"
const SCENARIO_OUTCOME_SCENE := "res://scenes/results/ScenarioOutcomeShell.tscn"
const DEFAULT_BATTLE_SAVE_STEP_ID := "battle_saved"
const DEFAULT_BATTLE_MENU_RETURN_STEP_ID := "main_menu_after_battle_return"
const DEFAULT_BATTLE_RESUME_STEP_ID := "battle_resumed"
const MAX_VALIDATION_ROUTE_STEPS := 32
const MAX_VALIDATION_BATTLE_ACTIONS := 40

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
		FLOW_BOOT_TO_SKIRMISH_RESOLVED_OUTCOME:
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

	var resolving_outcome := String(_config.get("flow", "")) == FLOW_BOOT_TO_SKIRMISH_RESOLVED_OUTCOME
	if resolving_outcome:
		var free_company_claim := await _claim_overworld_validation_target(
			post_town_overworld,
			"resource",
			"river_free_company",
			"support_site_claimed_river_free_company"
		)
		if not bool(free_company_claim.get("ok", false)):
			_fail("Could not claim the authored Free Company support site before objective clearing.", free_company_claim)
			return false
		post_town_overworld = free_company_claim.get("scene", post_town_overworld)
		var objective_clear := await _clear_required_encounters_to_overworld(post_town_overworld)
		if not bool(objective_clear.get("ok", false)):
			return false
		post_town_overworld = objective_clear.get("scene", post_town_overworld)
		var gorget_claim := await _claim_overworld_validation_target(
			post_town_overworld,
			"artifact",
			"bastion_vault",
			"support_artifact_claimed_bastion_vault"
		)
		if not bool(gorget_claim.get("ok", false)):
			_fail("Could not claim the authored Bastion Gorget before the final assault.", gorget_claim)
			return false
		post_town_overworld = gorget_claim.get("scene", post_town_overworld)

	var battle_route := await _route_from_overworld_to_scene(post_town_overworld, "town", "enemy", BATTLE_SCENE)
	if not _require(bool(battle_route.get("ok", false)), "Could not route from the live overworld into a hostile town assault.", battle_route):
		return false
	var battle = battle_route.get("scene", null)
	if battle == null:
		return _fail("Battle route completed without a battle scene instance.", battle_route)
	await _settle_frames(6)

	var assault_route := _last_history_entry(battle_route.get("history", []))
	var assaulted_town: Dictionary = _dictionary_value(assault_route.get("target", {}))
	if not _require(String(assault_route.get("pre_action_town_owner", "")) == "enemy", "Hostile-town assault route did not preserve enemy ownership before battle entry.", assault_route):
		return false
	var assault_route_town_state := _dictionary_value(assault_route.get("post_action_town_state", {}))
	if not _require(String(assault_route_town_state.get("owner", "")) == "enemy", "Hostile-town assault route flipped town ownership before battle resolution.", assault_route):
		return false
	var battle_snapshot: Dictionary = battle.call("validation_snapshot")
	if not _require(String(battle_snapshot.get("battle_context_type", "")) == "town_assault", "Battle validation did not enter a town-assault context.", battle_snapshot):
		return false
	if not _require(
		String(battle_snapshot.get("battle_context_town_placement_id", "")) == String(assaulted_town.get("placement_id", "")),
		"Battle validation routed into the wrong hostile town target.",
		{
			"route_target": assaulted_town,
			"battle_snapshot": battle_snapshot,
		}
	):
		return false
	battle_snapshot["route_history"] = battle_route.get("history", [])
	_capture_step("battle_entered", battle_snapshot)
	var battle_resume := await _save_and_resume_battle_from_main_menu(battle, manual_slot, "battle")
	if not bool(battle_resume.get("ok", false)):
		return false
	battle = battle_resume.get("battle", battle)

	var battle_resolution := await _play_battle_to_scene(
		battle,
		"battle_progressed",
		"outcome_entered" if resolving_outcome else "overworld_after_battle",
		SCENARIO_OUTCOME_SCENE if resolving_outcome else OVERWORLD_SCENE
	)
	if not bool(battle_resolution.get("ok", false)):
		return false
	if resolving_outcome:
		var resolved_ok := await _verify_outcome_route_and_followups(battle_resolution, manual_slot)
		return resolved_ok

	var captured_overworld = battle_resolution.get("scene", null)
	if captured_overworld == null:
		return _fail("Town-assault resolution did not return to the overworld scene.", battle_resolution)
	var captured_overworld_snapshot: Dictionary = battle_resolution.get("snapshot", {})
	var captured_town_state := _dictionary_value(captured_overworld_snapshot.get("active_town", {}))
	if not _require(String(captured_overworld_snapshot.get("active_context_type", "")) == "town", "Town-assault return did not leave the hero on a town context.", captured_overworld_snapshot):
		return false
	if not _require(
		String(captured_town_state.get("placement_id", "")) == String(assaulted_town.get("placement_id", "")),
		"Town-assault return focused the wrong town after battle resolution.",
		{
			"expected_town": assaulted_town,
			"actual_town": captured_town_state,
		}
	):
		return false
	if not _require(String(captured_town_state.get("owner", "")) == "player", "Town-assault victory did not transfer the hostile town to the player.", captured_town_state):
		return false
	var captured_occupation := _dictionary_value(captured_town_state.get("occupation", {}))
	if not _require(bool(captured_occupation.get("active", false)), "Captured town did not enter an active occupation state.", captured_town_state):
		return false
	if not _require(String(captured_occupation.get("mode", "")) == "pacifying", "Captured town did not enter pacification mode.", captured_occupation):
		return false
	if not _require(int(captured_occupation.get("days_to_clear", 0)) > 0, "Captured town pacification did not keep a clearance window.", captured_occupation):
		return false
	if not _require(int(captured_occupation.get("locked_headcount", 0)) > 0, "Captured town pacification did not hold back local recruits.", captured_occupation):
		return false
	var captured_front := _dictionary_value(captured_town_state.get("front", {}))
	if not _require(bool(captured_front.get("active", false)), "Captured town did not keep a hostile front anchor.", captured_town_state):
		return false
	if not _require(String(captured_front.get("mode", "")) == "retake", "Captured town front did not switch into retake posture.", captured_front):
		return false
	if not _require(
		String(captured_front.get("faction_id", "")) == String(battle_snapshot.get("battle_context_trigger_faction_id", "")),
		"Captured town retake front did not keep the hostile faction anchor.",
		{
			"front": captured_front,
			"battle_snapshot": battle_snapshot,
		}
	):
		return false
	if not _require("Occupation watch:" in String(captured_overworld_snapshot.get("frontier_watch", "")), "Frontier watch did not surface the occupied-town state after capture.", captured_overworld_snapshot):
		return false
	if not _require("Retake fronts" in String(captured_overworld_snapshot.get("frontier_watch", "")), "Frontier watch did not surface the hostile retake front after capture.", captured_overworld_snapshot):
		return false

	var captured_town_route := await _route_from_overworld_to_scene(captured_overworld, "town", "player", TOWN_SCENE)
	if not _require(bool(captured_town_route.get("ok", false)), "Could not route from the captured-town overworld state into the shipped town shell.", captured_town_route):
		return false
	var captured_town = captured_town_route.get("scene", null)
	if captured_town == null:
		return _fail("Captured-town route completed without a town scene instance.", captured_town_route)
	await _settle_frames(6)

	var captured_town_snapshot: Dictionary = captured_town.call("validation_snapshot")
	if not _require(String(captured_town_snapshot.get("town_placement_id", "")) == String(assaulted_town.get("placement_id", "")), "Captured town shell routed to an unexpected town.", captured_town_snapshot):
		return false
	if not _require(String(captured_town_snapshot.get("town_owner", "")) == "player", "Captured town shell did not reflect player ownership.", captured_town_snapshot):
		return false
	var town_occupation := _dictionary_value(captured_town_snapshot.get("occupation", {}))
	if not _require(String(town_occupation.get("mode", "")) == "pacifying", "Captured town shell lost pacification state.", captured_town_snapshot):
		return false
	var town_front := _dictionary_value(captured_town_snapshot.get("front", {}))
	if not _require(String(town_front.get("mode", "")) == "retake", "Captured town shell lost hostile retake-front posture.", captured_town_snapshot):
		return false
	if not _require(
		int(_dictionary_value(captured_town_snapshot.get("income", {})).get("gold", 0)) < int(_dictionary_value(captured_town_snapshot.get("base_income", {})).get("gold", 0)),
		"Captured town shell did not reflect reduced income during occupation.",
		captured_town_snapshot
	):
		return false
	if not _require(
		int(captured_town_snapshot.get("battle_readiness", 0)) < int(captured_town_snapshot.get("base_battle_readiness", 0)),
		"Captured town shell did not reflect reduced battle readiness during occupation.",
		captured_town_snapshot
	):
		return false
	var town_summary := String(captured_town_snapshot.get("summary", "")).to_lower()
	if not _require("occupation" in town_summary and "retake front" in town_summary, "Captured town shell summary did not surface occupation and hostile retake pressure.", captured_town_snapshot):
		return false
	captured_town_snapshot["route_history"] = captured_town_route.get("history", [])
	_capture_step("captured_town_entered", captured_town_snapshot)
	_log("Live validation flow completed successfully.")
	return true

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

func _route_from_overworld_to_scene(
	overworld,
	target_kind: String,
	owner_id: String,
	destination_scene: String,
	placement_id: String = ""
) -> Dictionary:
	var history := []
	var current_overworld = overworld
	for _step_index in range(MAX_VALIDATION_ROUTE_STEPS):
		if current_overworld == null:
			break
		var route_result: Dictionary = (
			current_overworld.call("validation_route_step_to_target_placement", target_kind, placement_id)
			if placement_id != ""
			else current_overworld.call("validation_route_step_to_nearest_target", target_kind, owner_id)
		)
		history.append(route_result.duplicate(true))
		if not bool(route_result.get("ok", false)):
			return {
				"ok": false,
				"target_kind": target_kind,
				"placement_id": placement_id,
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
			if (
				destination_scene == OVERWORLD_SCENE
				and placement_id != ""
				and target_kind in ["resource", "artifact"]
				and (
					int(route_result.get("remaining_steps", 0)) > 0
					or String(route_result.get("action", "")) == "end_turn_for_route"
				)
			):
				current_overworld = current_scene
				continue
			if placement_id != "" and destination_scene == BATTLE_SCENE:
				var route_action := String(route_result.get("action", ""))
				var last_action := String(route_result.get("last_action", ""))
				if target_kind == "encounter" and route_action != "enter_battle" and last_action != "entered_battle":
					return {
						"ok": false,
						"target_kind": target_kind,
						"placement_id": placement_id,
						"destination_scene": destination_scene,
						"scene_path": scene_path,
						"history": history,
						"message": "Route entered battle before the requested encounter target interaction.",
					}
			return {
				"ok": true,
				"scene": current_scene,
				"history": history,
			}
		if scene_path != OVERWORLD_SCENE:
			return {
				"ok": false,
				"target_kind": target_kind,
				"placement_id": placement_id,
				"destination_scene": destination_scene,
				"scene_path": scene_path,
				"history": history,
				"message": "Route entered an unexpected scene.",
			}
		current_overworld = current_scene
	return {
		"ok": false,
		"target_kind": target_kind,
		"placement_id": placement_id,
		"destination_scene": destination_scene,
		"history": history,
		"message": "Route did not reach the requested scene within the step budget.",
	}

func _claim_overworld_validation_target(overworld, target_kind: String, placement_id: String, step_id: String) -> Dictionary:
	var route := await _route_from_overworld_to_scene(overworld, target_kind, "", OVERWORLD_SCENE, placement_id)
	if not bool(route.get("ok", false)):
		return route
	var routed_overworld = route.get("scene", null)
	if routed_overworld == null:
		return {
			"ok": false,
			"target_kind": target_kind,
			"placement_id": placement_id,
			"message": "Overworld validation target route completed without an overworld scene instance.",
			"route": route,
		}
	await _settle_frames(6)
	var snapshot: Dictionary = routed_overworld.call("validation_snapshot")
	snapshot["route_history"] = route.get("history", [])
	snapshot["claimed_target_kind"] = target_kind
	snapshot["claimed_placement_id"] = placement_id
	_capture_step(step_id, snapshot)
	return {
		"ok": true,
		"scene": routed_overworld,
		"route": route,
	}

func _clear_required_encounters_to_outcome(overworld) -> Dictionary:
	var required_placements := _required_encounter_placements_for_resolution()
	if required_placements.is_empty():
		_fail("No authored encounter objectives were available for resolved-session validation.", {"scenario_id": _config.get("scenario_id", "")})
		return {"ok": false}

	var current_overworld = overworld
	for index in range(required_placements.size()):
		var placement_id := String(required_placements[index])
		if _encounter_placement_resolved(placement_id):
			continue
		var battle_route := await _route_from_overworld_to_scene(current_overworld, "encounter", "", BATTLE_SCENE, placement_id)
		if not bool(battle_route.get("ok", false)):
			var blocker_route := await _clear_nearest_encounter_to_overworld(
				current_overworld,
				"route_blocker_before_%s" % placement_id
			)
			if not bool(blocker_route.get("ok", false)):
				battle_route["blocker_route"] = blocker_route
				if not _require(false, "Could not route from the live overworld into a required encounter objective.", battle_route):
					return {"ok": false}
			current_overworld = blocker_route.get("scene", current_overworld)
			if _encounter_placement_resolved(placement_id):
				continue
			battle_route = await _route_from_overworld_to_scene(current_overworld, "encounter", "", BATTLE_SCENE, placement_id)
			if not _require(bool(battle_route.get("ok", false)), "Could not route from the live overworld into a required encounter objective after clearing a reachable blocker.", battle_route):
				return {"ok": false}
		var battle = battle_route.get("scene", null)
		if battle == null:
			_fail("Required encounter route completed without a battle scene instance.", battle_route)
			return {"ok": false}
		await _settle_frames(6)

		var battle_snapshot: Dictionary = battle.call("validation_snapshot")
		battle_snapshot["route_history"] = battle_route.get("history", [])
		battle_snapshot["objective_placement_id"] = placement_id
		_capture_step("objective_battle_entered_%s" % placement_id, battle_snapshot)

		var is_final_objective := _remaining_required_encounters_after(placement_id, required_placements).is_empty()
		var destination_scene := SCENARIO_OUTCOME_SCENE if is_final_objective else OVERWORLD_SCENE
		var resolved_route := await _play_battle_to_scene(
			battle,
			"objective_battle_progressed_%s" % placement_id,
			"outcome_entered" if is_final_objective else "overworld_after_objective_%s" % placement_id,
			destination_scene
		)
		if not bool(resolved_route.get("ok", false)):
			return {"ok": false}

		if is_final_objective:
			return resolved_route

		current_overworld = resolved_route.get("scene", null)
		if current_overworld == null:
			_fail("Required encounter resolution did not return to overworld for remaining objectives.", resolved_route)
			return {"ok": false}
		if not _require(_encounter_placement_resolved(placement_id), "Required encounter did not mark its authored placement resolved after battle victory.", {"placement_id": placement_id, "snapshot": resolved_route.get("snapshot", {})}):
			return {"ok": false}

	_fail("Required encounters ended without routing to the outcome shell.", {"required_placements": required_placements})
	return {"ok": false}

func _clear_required_encounters_to_overworld(overworld) -> Dictionary:
	var required_placements := _required_encounter_placements_for_resolution()
	if required_placements.is_empty():
		_fail("No authored encounter objectives were available for pre-assault validation.", {"scenario_id": _config.get("scenario_id", "")})
		return {"ok": false}

	var current_overworld = overworld
	while true:
		var placement_id := _next_required_encounter_placement(current_overworld, required_placements)
		if placement_id == "":
			break
		if _encounter_placement_resolved(placement_id):
			continue
		var battle_route := await _route_from_overworld_to_scene(current_overworld, "encounter", "", BATTLE_SCENE, placement_id)
		if not _require(bool(battle_route.get("ok", false)), "Could not route from the live overworld into a required encounter objective before the final assault.", battle_route):
			return {"ok": false}
		var battle = battle_route.get("scene", null)
		if battle == null:
			_fail("Required encounter route completed without a battle scene instance before the final assault.", battle_route)
			return {"ok": false}
		await _settle_frames(6)

		var battle_snapshot: Dictionary = battle.call("validation_snapshot")
		battle_snapshot["route_history"] = battle_route.get("history", [])
		battle_snapshot["objective_placement_id"] = placement_id
		_capture_step("pre_outcome_objective_battle_entered_%s" % placement_id, battle_snapshot)
		var resolved_route := await _play_battle_to_scene(
			battle,
			"pre_outcome_objective_battle_progressed_%s" % placement_id,
			"overworld_after_pre_outcome_objective_%s" % placement_id,
			OVERWORLD_SCENE
		)
		if not bool(resolved_route.get("ok", false)):
			return {"ok": false}
		current_overworld = resolved_route.get("scene", null)
		if current_overworld == null:
			_fail("Required encounter resolution did not return to overworld before the final assault.", resolved_route)
			return {"ok": false}
		if not _require(_encounter_placement_resolved(placement_id), "Required encounter did not mark its authored placement resolved before the final assault.", {"placement_id": placement_id, "snapshot": resolved_route.get("snapshot", {})}):
			return {"ok": false}

	for placement_id_value in required_placements:
		if not _require(_encounter_placement_resolved(String(placement_id_value)), "Required encounter clearing ended with an unresolved objective before the final assault.", {"placement_id": String(placement_id_value)}):
			return {"ok": false}
	return {
		"ok": true,
		"scene": current_overworld,
	}

func _next_required_encounter_placement(overworld, required_placements: Array[String]) -> String:
	var snapshot: Dictionary = overworld.call("validation_snapshot") if overworld != null else {}
	var hero_position := _dictionary_value(snapshot.get("hero_position", {}))
	var scenario := ContentService.get_scenario(String(_config.get("scenario_id", "")))
	var direct_placements := _direct_required_encounter_placements_for_resolution()
	var best_placement_id := ""
	var best_score := 999999
	for placement_id_value in required_placements:
		var placement_id := String(placement_id_value)
		if _encounter_placement_resolved(placement_id):
			continue
		var encounter_placement := _scenario_encounter_placement(scenario, placement_id)
		if encounter_placement.is_empty():
			continue
		var score := _encounter_route_order_score(encounter_placement, hero_position)
		if placement_id in direct_placements:
			score -= 50
		if best_placement_id == "" or score < best_score:
			best_placement_id = placement_id
			best_score = score
	return best_placement_id

func _direct_required_encounter_placements_for_resolution() -> Array[String]:
	var scenario := ContentService.get_scenario(String(_config.get("scenario_id", "")))
	var objectives = scenario.get("objectives", {})
	var direct: Array[String] = []
	if not (objectives is Dictionary):
		return direct
	for objective in objectives.get("victory", []):
		if not (objective is Dictionary):
			continue
		if String(objective.get("type", "")) != "encounter_resolved":
			continue
		var placement_id := String(objective.get("placement_id", ""))
		if placement_id != "" and placement_id not in direct:
			direct.append(placement_id)
	return direct

func _scenario_encounter_placement(scenario: Dictionary, placement_id: String) -> Dictionary:
	for placement in scenario.get("encounters", []):
		if placement is Dictionary and String(placement.get("placement_id", "")) == placement_id:
			return placement.duplicate(true)
	return {}

func _encounter_route_order_score(encounter_placement: Dictionary, hero_position: Dictionary) -> int:
	var difficulty_score := 3
	match String(encounter_placement.get("difficulty", "medium")):
		"high":
			difficulty_score = 0
		"medium":
			difficulty_score = 1
		"low":
			difficulty_score = 2
	var distance: int = abs(int(encounter_placement.get("x", 0)) - int(hero_position.get("x", 0))) + abs(int(encounter_placement.get("y", 0)) - int(hero_position.get("y", 0)))
	return (difficulty_score * 100) + distance

func _clear_nearest_encounter_to_overworld(overworld, step_prefix: String) -> Dictionary:
	var battle_route := await _route_from_overworld_to_scene(overworld, "encounter", "", BATTLE_SCENE)
	if not bool(battle_route.get("ok", false)):
		return battle_route
	var battle = battle_route.get("scene", null)
	if battle == null:
		return {
			"ok": false,
			"message": "Reachable encounter blocker route completed without a battle scene instance.",
			"route": battle_route,
		}
	await _settle_frames(6)

	var blocker_placement_id := _route_target_placement_id(battle_route.get("history", []))
	var battle_snapshot: Dictionary = battle.call("validation_snapshot")
	battle_snapshot["route_history"] = battle_route.get("history", [])
	battle_snapshot["objective_placement_id"] = blocker_placement_id
	_capture_step("%s_entered" % step_prefix, battle_snapshot)
	var resolved_route := await _play_battle_to_scene(
		battle,
		"%s_progressed" % step_prefix,
		"overworld_after_%s" % step_prefix,
		OVERWORLD_SCENE
	)
	if bool(resolved_route.get("ok", false)):
		resolved_route["placement_id"] = blocker_placement_id
	return resolved_route

func _required_encounter_placements_for_resolution() -> Array[String]:
	var scenario := ContentService.get_scenario(String(_config.get("scenario_id", "")))
	var objectives = scenario.get("objectives", {})
	var required: Array[String] = []
	if not (objectives is Dictionary):
		return required
	for objective in objectives.get("victory", []):
		if not (objective is Dictionary):
			continue
		match String(objective.get("type", "")):
			"encounter_resolved":
				var placement_id := String(objective.get("placement_id", ""))
				if placement_id != "" and placement_id not in required:
					required.append(placement_id)
			"flag_true":
				var flag := String(objective.get("flag", ""))
				for placement_id in _encounter_placements_for_victory_flag(scenario, flag):
					if placement_id != "" and placement_id not in required:
						required.append(placement_id)
	return required

func _encounter_placements_for_victory_flag(scenario: Dictionary, flag: String) -> Array[String]:
	var placements: Array[String] = []
	if flag == "":
		return placements
	for placement in scenario.get("encounters", []):
		if not (placement is Dictionary):
			continue
		var encounter := ContentService.get_encounter(String(placement.get("encounter_id", "")))
		var victory_flags = encounter.get("victory_flags", [])
		if not (victory_flags is Array) or flag not in victory_flags:
			continue
		var placement_id := String(placement.get("placement_id", ""))
		if placement_id != "" and placement_id not in placements:
			placements.append(placement_id)
	return placements

func _remaining_required_encounters_after(completed_placement_id: String, required_placements: Array[String]) -> Array[String]:
	var remaining: Array[String] = []
	var found_completed := false
	for placement_id in required_placements:
		if not found_completed:
			found_completed = String(placement_id) == completed_placement_id
			continue
		if not _encounter_placement_resolved(String(placement_id)):
			remaining.append(String(placement_id))
	return remaining

func _encounter_placement_resolved(placement_id: String) -> bool:
	if placement_id == "" or not SessionState.has_playable_session():
		return false
	var resolved = SessionState.ensure_active_session().overworld.get("resolved_encounters", [])
	return resolved is Array and placement_id in resolved

func _route_target_placement_id(history_value: Variant) -> String:
	var last_entry := _last_history_entry(history_value)
	var target := _dictionary_value(last_entry.get("target", {}))
	return String(target.get("placement_id", ""))

func _save_and_resume_battle_from_main_menu(battle, manual_slot: int, step_prefix: String = "battle") -> Dictionary:
	var save_step_id := DEFAULT_BATTLE_SAVE_STEP_ID if step_prefix == "battle" else "%s_saved" % step_prefix
	var menu_step_id := (
		DEFAULT_BATTLE_MENU_RETURN_STEP_ID
		if step_prefix == "battle"
		else "main_menu_after_%s_return" % step_prefix
	)
	var resume_step_id := DEFAULT_BATTLE_RESUME_STEP_ID if step_prefix == "battle" else "%s_resumed" % step_prefix
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
	_capture_step(save_step_id, battle_saved_snapshot)
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
	_capture_step(menu_step_id, menu_after_return_snapshot)

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
	_capture_step(resume_step_id, resumed_battle_snapshot)
	return {
		"ok": true,
		"battle": resumed_battle,
	}

func _save_and_resume_outcome_from_main_menu(outcome, manual_slot: int) -> Dictionary:
	if not _require(
		bool(outcome.call("validation_select_save_slot", manual_slot)),
		"Outcome validation could not select the requested manual save slot.",
		{
			"manual_slot": manual_slot,
			"outcome_snapshot": outcome.call("validation_snapshot"),
		}
	):
		return {"ok": false}
	await _settle_frames(3)

	var outcome_save: Dictionary = outcome.call("validation_save_to_selected_slot")
	var outcome_save_summary := _dictionary_value(outcome_save.get("summary", {}))
	if not _require(bool(outcome_save.get("ok", false)), "Outcome validation could not write a manual save from the live shell.", outcome_save):
		return {"ok": false}
	if not _require(int(outcome_save.get("selected_slot", 0)) == manual_slot, "Outcome validation saved into the wrong manual slot.", outcome_save):
		return {"ok": false}
	if not _require(String(outcome_save_summary.get("resume_target", "")) == "outcome", "Outcome manual save did not advertise outcome review.", outcome_save_summary):
		return {"ok": false}
	if not _require(String(outcome_save_summary.get("scenario_status", "")) == "victory", "Outcome manual save did not preserve victory status.", outcome_save_summary):
		return {"ok": false}
	if not _require(String(outcome_save_summary.get("scenario_id", "")) == String(_config.get("scenario_id", "")), "Outcome manual save summary scenario id did not match the launched scenario.", outcome_save_summary):
		return {"ok": false}
	if not _require(SaveService.load_action_label(outcome_save_summary) == "Review Outcome", "Outcome manual save did not expose the review load action.", outcome_save_summary):
		return {"ok": false}
	if not _require(SaveService.continue_action_label(outcome_save_summary) == "Review Latest Outcome", "Outcome manual save did not expose the review continue action.", outcome_save_summary):
		return {"ok": false}
	await _settle_frames(6)

	var outcome_saved_snapshot: Dictionary = outcome.call("validation_snapshot")
	outcome_saved_snapshot["manual_save"] = outcome_save
	_capture_step("outcome_saved", outcome_saved_snapshot)
	var expected_outcome_resume_signature := _outcome_resume_signature(outcome_saved_snapshot)

	var outcome_menu_return: Dictionary = outcome.call("validation_return_to_menu")
	if not _require(bool(outcome_menu_return.get("ok", false)), "Outcome validation could not return to the main menu through the live router.", outcome_menu_return):
		return {"ok": false}
	var menu = await _wait_for_scene(MAIN_MENU_SCENE, 10000)
	if menu == null:
		_fail("Returning to menu after the outcome manual save did not reach the main menu scene.", outcome_menu_return)
		return {"ok": false}
	await _settle_frames(8)

	var latest_summary_after_menu_return := SaveService.latest_loadable_summary()
	if not _require(not latest_summary_after_menu_return.is_empty(), "Latest save summary was unavailable after outcome return-to-menu routing.", outcome_menu_return):
		return {"ok": false}
	if not _require(String(latest_summary_after_menu_return.get("scenario_id", "")) == String(_config.get("scenario_id", "")), "Latest save summary after outcome return-to-menu did not match the launched scenario.", latest_summary_after_menu_return):
		return {"ok": false}
	if not _require(String(latest_summary_after_menu_return.get("resume_target", "")) == "outcome", "Latest save summary after outcome return-to-menu did not point back to outcome review.", latest_summary_after_menu_return):
		return {"ok": false}
	var menu_after_return_snapshot: Dictionary = menu.call("validation_snapshot")
	menu_after_return_snapshot["menu_return"] = outcome_menu_return
	menu_after_return_snapshot["latest_save_summary"] = latest_summary_after_menu_return
	_capture_step("main_menu_after_outcome_return", menu_after_return_snapshot)

	menu.call("validation_open_saves_stage")
	await _settle_frames(4)
	if not _require(
		bool(menu.call("validation_select_save_summary", "manual", str(manual_slot))),
		"Main menu save browser could not select the routed outcome manual save.",
		menu.call("validation_snapshot")
	):
		return {"ok": false}
	await _settle_frames(4)

	var outcome_resume: Dictionary = menu.call("validation_resume_selected_save")
	if not _require(bool(outcome_resume.get("ok", false)), "Main menu resume did not restore the selected routed outcome save.", outcome_resume):
		return {"ok": false}
	var resumed_outcome = await _wait_for_scene(SCENARIO_OUTCOME_SCENE, 10000)
	if resumed_outcome == null:
		_fail("Resuming the selected manual outcome save did not route back into the outcome scene.", outcome_resume)
		return {"ok": false}
	await _settle_frames(6)

	var resumed_outcome_snapshot: Dictionary = resumed_outcome.call("validation_snapshot")
	if not _require(String(resumed_outcome_snapshot.get("resume_target", "")) == "outcome", "Resumed outcome save did not restore outcome review semantics.", resumed_outcome_snapshot):
		return {"ok": false}
	var actual_outcome_resume_signature := _outcome_resume_signature(resumed_outcome_snapshot)
	if not _require(
		JSON.stringify(actual_outcome_resume_signature) == JSON.stringify(expected_outcome_resume_signature),
		"Outcome manual save/resume did not preserve the routed outcome state.",
		{
			"expected": expected_outcome_resume_signature,
			"actual": actual_outcome_resume_signature,
		}
	):
		return {"ok": false}
	resumed_outcome_snapshot["resume"] = outcome_resume
	_capture_step("outcome_resumed", resumed_outcome_snapshot)
	return {
		"ok": true,
		"outcome": resumed_outcome,
	}

func _verify_outcome_route_and_followups(outcome_route: Dictionary, manual_slot: int) -> bool:
	var outcome = outcome_route.get("scene", null)
	if outcome == null:
		return _fail("Resolved scenario routing did not provide an outcome scene instance.", outcome_route)
	var outcome_snapshot: Dictionary = outcome_route.get("snapshot", {})
	if not _require(String(outcome_snapshot.get("scenario_status", "")) == "victory", "Outcome shell did not receive a victory session.", outcome_snapshot):
		return false
	if not _require(String(outcome_snapshot.get("resume_target", "")) == "outcome", "Outcome shell did not advertise outcome resume semantics.", outcome_snapshot):
		return false
	if not _require(String(outcome_snapshot.get("scenario_summary", "")) != "", "Outcome shell did not expose the resolved scenario summary.", outcome_snapshot):
		return false
	var latest_outcome_summary := _dictionary_value(outcome_snapshot.get("latest_save_summary", {}))
	if not _require(not latest_outcome_summary.is_empty(), "Resolved autosave summary was unavailable on the outcome shell.", outcome_snapshot):
		return false
	if not _require(String(latest_outcome_summary.get("resume_target", "")) == "outcome", "Resolved autosave did not advertise outcome review.", latest_outcome_summary):
		return false
	if not _require(String(latest_outcome_summary.get("scenario_status", "")) == "victory", "Resolved autosave summary did not preserve victory status.", latest_outcome_summary):
		return false
	if not _require("skirmish_start:%s" % String(_config.get("scenario_id", "")) in _string_array_value(outcome_snapshot.get("action_ids", [])), "Outcome shell did not offer the real skirmish retry action.", outcome_snapshot):
		return false
	if not _require("return_to_menu" in _string_array_value(outcome_snapshot.get("action_ids", [])), "Outcome shell did not offer the return-to-menu action.", outcome_snapshot):
		return false

	var outcome_resume := await _save_and_resume_outcome_from_main_menu(outcome, manual_slot)
	if not bool(outcome_resume.get("ok", false)):
		return false
	outcome = outcome_resume.get("outcome", outcome)
	var outcome_action: Dictionary = outcome.call("validation_perform_action", "return_to_menu")
	if not _require(bool(outcome_action.get("ok", false)), "Outcome return-to-menu action failed through the shipped action row.", outcome_action):
		return false
	var final_menu = await _wait_for_scene(MAIN_MENU_SCENE, 10000)
	if final_menu == null:
		return _fail("Outcome return-to-menu action did not reach the main menu.", outcome_action)
	await _settle_frames(8)
	var final_menu_snapshot: Dictionary = final_menu.call("validation_snapshot")
	final_menu_snapshot["outcome_action"] = outcome_action
	final_menu_snapshot["latest_save_summary"] = SaveService.latest_loadable_summary()
	if not _require(String(_dictionary_value(final_menu_snapshot.get("latest_save_summary", {})).get("resume_target", "")) == "outcome", "Main menu latest save after outcome action did not keep outcome review semantics.", final_menu_snapshot):
		return false
	_capture_step("main_menu_after_outcome_action", final_menu_snapshot)
	return true

func _play_battle_to_overworld(battle, battle_progress_step_id: String, overworld_step_id: String) -> Dictionary:
	return await _play_battle_to_scene(battle, battle_progress_step_id, overworld_step_id, OVERWORLD_SCENE)

func _play_battle_to_scene(
	battle,
	battle_progress_step_id: String,
	destination_step_id: String,
	destination_scene: String
) -> Dictionary:
	var battle_actions := []
	var battle_progress_captured := false
	var current_battle = battle
	for _action_index in range(MAX_VALIDATION_BATTLE_ACTIONS):
		if current_battle == null:
			break
		var battle_action: Dictionary = current_battle.call("validation_try_progress_action")
		battle_actions.append(battle_action.duplicate(true))
		if not _require(bool(battle_action.get("ok", false)), "Battle validation action did not change live state.", battle_action):
			return {"ok": false}
		await _settle_frames(6)
		var current_scene = get_tree().current_scene
		if current_scene == null:
			continue
		var scene_path := String(current_scene.scene_file_path)
		if scene_path == BATTLE_SCENE and not battle_progress_captured:
			var battle_mid_snapshot: Dictionary = current_scene.call("validation_snapshot")
			battle_mid_snapshot["progress_action"] = battle_action
			_capture_step(battle_progress_step_id, battle_mid_snapshot)
			battle_progress_captured = true
		if scene_path == destination_scene:
			var destination_snapshot: Dictionary = current_scene.call("validation_snapshot")
			destination_snapshot["battle_actions"] = battle_actions
			_capture_step(destination_step_id, destination_snapshot)
			return {
				"ok": true,
				"scene": current_scene,
				"snapshot": destination_snapshot,
			}
		if scene_path != BATTLE_SCENE:
			_fail(
				"Battle validation routed to an unexpected scene.",
				{
					"scene_path": scene_path,
					"destination_scene": destination_scene,
					"battle_actions": battle_actions,
				}
			)
			return {"ok": false}
		current_battle = current_scene

	var final_battle_payload := {"battle_actions": battle_actions}
	if current_battle != null and String(current_battle.scene_file_path) == BATTLE_SCENE:
		final_battle_payload["battle_snapshot"] = current_battle.call("validation_snapshot")
	_fail("Battle validation did not resolve within the action budget.", final_battle_payload)
	return {"ok": false}

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
				config["flow"] = FLOW_BOOT_TO_SKIRMISH_RESOLVED_OUTCOME
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
		config["flow"] = FLOW_BOOT_TO_SKIRMISH_RESOLVED_OUTCOME
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

func _last_history_entry(history_value: Variant) -> Dictionary:
	if not (history_value is Array) or history_value.is_empty():
		return {}
	var last_entry = history_value[history_value.size() - 1]
	return _dictionary_value(last_entry)

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

func _outcome_resume_signature(snapshot: Dictionary) -> Dictionary:
	return {
		"scenario_id": String(snapshot.get("scenario_id", "")),
		"difficulty": String(snapshot.get("difficulty", "")),
		"launch_mode": String(snapshot.get("launch_mode", "")),
		"scenario_status": String(snapshot.get("scenario_status", "")),
		"scenario_summary": String(snapshot.get("scenario_summary", "")),
		"resume_target": String(snapshot.get("resume_target", "")),
		"header": String(snapshot.get("header", "")),
		"summary": String(snapshot.get("summary", "")),
		"mode_summary": String(snapshot.get("mode_summary", "")),
		"action_ids": _string_array_value(snapshot.get("action_ids", [])),
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
