extends Node

const FLOW_BOOT_TO_SKIRMISH_OVERWORLD := "boot_to_skirmish_overworld"
const FLOW_BOOT_TO_SKIRMISH_TOWN_BATTLE := "boot_to_skirmish_town_battle"
const FLOW_BOOT_TO_SKIRMISH_RESOLVED_OUTCOME := "boot_to_skirmish_resolved_outcome"
const FLOW_BOOT_TO_SKIRMISH_DEFEAT_OUTCOME := "boot_to_skirmish_defeat_outcome"
const FLOW_BOOT_TO_CAMPAIGN_RESOLVED_OUTCOME := "boot_to_campaign_resolved_outcome"
const FLOW_BOOT_TO_CAMPAIGN_DEFEAT_OUTCOME := "boot_to_campaign_defeat_outcome"
const FLOW_BOOT_TO_CAMPAIGN_FULL_ARC := "boot_to_campaign_full_arc"
const MAIN_MENU_SCENE := "res://scenes/menus/MainMenu.tscn"
const OVERWORLD_SCENE := "res://scenes/overworld/OverworldShell.tscn"
const TOWN_SCENE := "res://scenes/town/TownShell.tscn"
const BATTLE_SCENE := "res://scenes/battle/BattleShell.tscn"
const SCENARIO_OUTCOME_SCENE := "res://scenes/results/ScenarioOutcomeShell.tscn"
const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const DEFAULT_BATTLE_SAVE_STEP_ID := "battle_saved"
const DEFAULT_BATTLE_MENU_RETURN_STEP_ID := "main_menu_after_battle_return"
const DEFAULT_BATTLE_RESUME_STEP_ID := "battle_resumed"
const DEFAULT_OUTCOME_SAVE_STEP_ID := "outcome_saved"
const DEFAULT_OUTCOME_MENU_RETURN_STEP_ID := "main_menu_after_outcome_return"
const DEFAULT_OUTCOME_RESUME_STEP_ID := "outcome_resumed"
const DEFAULT_OUTCOME_MENU_ACTION_STEP_ID := "main_menu_after_outcome_action"
const DEFEAT_OUTCOME_SAVE_STEP_ID := "defeat_outcome_saved"
const DEFEAT_OUTCOME_MENU_RETURN_STEP_ID := "main_menu_after_defeat_outcome_return"
const DEFEAT_OUTCOME_RESUME_STEP_ID := "defeat_outcome_resumed"
const DEFEAT_OUTCOME_MENU_ACTION_STEP_ID := "main_menu_after_defeat_outcome_action"
const CAMPAIGN_OUTCOME_SAVE_STEP_ID := "campaign_outcome_saved"
const CAMPAIGN_OUTCOME_MENU_RETURN_STEP_ID := "main_menu_after_campaign_outcome_return"
const CAMPAIGN_OUTCOME_RESUME_STEP_ID := "campaign_outcome_resumed"
const CAMPAIGN_NEXT_CHAPTER_SAVE_STEP_ID := "campaign_next_chapter_saved"
const CAMPAIGN_NEXT_CHAPTER_MENU_RETURN_STEP_ID := "main_menu_after_campaign_next_chapter_return"
const CAMPAIGN_NEXT_CHAPTER_RESUME_STEP_ID := "campaign_next_chapter_resumed"
const CAMPAIGN_DEFEAT_OUTCOME_SAVE_STEP_ID := "campaign_defeat_outcome_saved"
const CAMPAIGN_DEFEAT_OUTCOME_MENU_RETURN_STEP_ID := "main_menu_after_campaign_defeat_outcome_return"
const CAMPAIGN_DEFEAT_OUTCOME_RESUME_STEP_ID := "campaign_defeat_outcome_resumed"
const CAMPAIGN_DEFEAT_OUTCOME_MENU_ACTION_STEP_ID := "main_menu_after_campaign_defeat_outcome_action"
const MAX_VALIDATION_ROUTE_STEPS := 32
const MAX_VALIDATION_BATTLE_ACTIONS := 40
const MAX_VALIDATION_DEFEAT_END_TURNS := 10
const MAX_VALIDATION_TOWN_RECRUIT_ACTIONS := 6
const MAX_VALIDATION_TOWN_PREP_ACTIONS := 12
const CAMPAIGN_TOWN_BUILD_PRIORITY := [
	"building_mire_pens",
	"building_bowyer_lodge",
	"building_slingers_post",
	"building_reed_warren",
	"building_watch_barracks",
	"building_rot_warren",
	"building_stone_store",
	"building_beacon_range",
	"building_fenscale_pens",
	"building_citadel_pikehall",
	"building_gorefen_ring",
]
const CAMPAIGN_TOWN_RECRUIT_PRIORITY := [
	"unit_gorefen_ripper",
	"unit_citadel_pikeward",
	"unit_bog_brute",
	"unit_ember_archer",
	"unit_mire_slinger",
	"unit_river_guard",
	"unit_blackbranch_cutthroat",
]
const CAMPAIGN_SPECIALTY_PRIORITY := [
	"armsmaster",
	"drillmaster",
	"mustercaptain",
	"spellwright",
	"wayfinder",
	"ledgerkeeper",
	"borderwarden",
]

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
		FLOW_BOOT_TO_SKIRMISH_DEFEAT_OUTCOME:
			return await _execute_boot_to_skirmish_defeat_outcome_flow()
		FLOW_BOOT_TO_CAMPAIGN_RESOLVED_OUTCOME:
			return await _execute_boot_to_campaign_resolved_outcome_flow()
		FLOW_BOOT_TO_CAMPAIGN_DEFEAT_OUTCOME:
			return await _execute_boot_to_campaign_defeat_outcome_flow()
		FLOW_BOOT_TO_CAMPAIGN_FULL_ARC:
			return await _execute_boot_to_campaign_full_arc_flow()
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

func _execute_boot_to_skirmish_defeat_outcome_flow() -> bool:
	var launch := await _enter_live_skirmish_overworld()
	if not bool(launch.get("ok", false)):
		return false
	var overworld = launch.get("overworld", null)
	if overworld == null:
		return _fail("Live launch did not provide an overworld scene instance for defeat validation.", launch)

	var pressure_route := await _drive_overworld_to_defeat_outcome(overworld)
	if not bool(pressure_route.get("ok", false)):
		return false
	var manual_slot := int(_config.get("manual_slot", 2))
	var outcome_ok := await _verify_outcome_route_and_followups(
		pressure_route,
		manual_slot,
		"defeat",
		"defeat_outcome"
	)
	if outcome_ok:
		_log("Live validation flow completed successfully.")
	return outcome_ok

func _execute_boot_to_campaign_resolved_outcome_flow() -> bool:
	var launch := await _enter_live_campaign_overworld()
	if not bool(launch.get("ok", false)):
		return false
	var current_overworld = launch.get("overworld", null)
	if current_overworld == null:
		return _fail("Campaign launch did not provide an overworld scene instance.", launch)

	var town_route := await _route_from_overworld_to_scene(current_overworld, "town", "player", TOWN_SCENE)
	if not _require(bool(town_route.get("ok", false)), "Could not route from the campaign overworld into the starting player town.", town_route):
		return false
	var town = town_route.get("scene", null)
	if town == null:
		return _fail("Campaign starting-town route completed without a town scene instance.", town_route)
	await _settle_frames(6)
	var town_snapshot: Dictionary = town.call("validation_snapshot")
	if not _require(String(town_snapshot.get("launch_mode", "")) == "campaign", "Campaign starting-town route did not preserve campaign launch mode.", town_snapshot):
		return false
	town_snapshot["route_history"] = town_route.get("history", [])
	_capture_step("campaign_town_entered", town_snapshot)

	var town_action: Dictionary = town.call("validation_try_progress_action")
	if not _require(bool(town_action.get("ok", false)), "Campaign starting-town validation action did not change live state.", town_action):
		return false
	await _settle_frames(6)
	var town_after_snapshot: Dictionary = town.call("validation_snapshot")
	town_after_snapshot["progress_action"] = town_action
	_capture_step("campaign_town_progressed", town_after_snapshot)

	var leave_result: Dictionary = town.call("validation_leave_town")
	if not _require(bool(leave_result.get("ok", false)), "Campaign validation could not leave the starting town through the live router.", leave_result):
		return false
	current_overworld = await _wait_for_scene(OVERWORLD_SCENE, 10000)
	if current_overworld == null:
		return _fail("Leaving the campaign starting town did not route back into the overworld scene.", leave_result)
	await _settle_frames(6)
	var post_town_snapshot: Dictionary = current_overworld.call("validation_snapshot")
	post_town_snapshot["town_exit"] = leave_result
	_capture_step("campaign_overworld_after_town", post_town_snapshot)

	if String(_config.get("scenario_id", "")) == "river-pass":
		var free_company_claim := await _claim_overworld_validation_target(
			current_overworld,
			"resource",
			"river_free_company",
			"campaign_support_site_claimed_river_free_company"
		)
		if not bool(free_company_claim.get("ok", false)):
			_fail("Could not claim the authored campaign support site before objective clearing.", free_company_claim)
			return false
		current_overworld = free_company_claim.get("scene", current_overworld)

	var objective_clear := await _clear_required_encounters_to_overworld(current_overworld)
	if not bool(objective_clear.get("ok", false)):
		return false
	current_overworld = objective_clear.get("scene", current_overworld)

	if String(_config.get("scenario_id", "")) == "river-pass":
		var gorget_claim := await _claim_overworld_validation_target(
			current_overworld,
			"artifact",
			"bastion_vault",
			"campaign_support_artifact_claimed_bastion_vault"
		)
		if not bool(gorget_claim.get("ok", false)):
			_fail("Could not claim the authored campaign Bastion Gorget before the final assault.", gorget_claim)
			return false
		current_overworld = gorget_claim.get("scene", current_overworld)

	var battle_route := await _route_from_overworld_to_scene(current_overworld, "town", "enemy", BATTLE_SCENE)
	if not _require(bool(battle_route.get("ok", false)), "Could not route from the campaign overworld into the hostile town assault.", battle_route):
		return false
	var battle = battle_route.get("scene", null)
	if battle == null:
		return _fail("Campaign town-assault route completed without a battle scene instance.", battle_route)
	await _settle_frames(6)

	var assault_route := _last_history_entry(battle_route.get("history", []))
	if not _require(String(assault_route.get("pre_action_town_owner", "")) == "enemy", "Campaign hostile-town route did not preserve enemy ownership before battle entry.", assault_route):
		return false
	var battle_snapshot: Dictionary = battle.call("validation_snapshot")
	if not _require(String(battle_snapshot.get("launch_mode", "")) == "campaign", "Campaign battle route did not preserve campaign launch mode.", battle_snapshot):
		return false
	if not _require(String(battle_snapshot.get("battle_context_type", "")) == "town_assault", "Campaign battle validation did not enter a town-assault context.", battle_snapshot):
		return false
	battle_snapshot["route_history"] = battle_route.get("history", [])
	_capture_step("campaign_battle_entered", battle_snapshot)

	var battle_resolution := await _play_battle_to_scene(
		battle,
		"campaign_battle_progressed",
		"campaign_outcome_entered",
		SCENARIO_OUTCOME_SCENE
	)
	if not bool(battle_resolution.get("ok", false)):
		return false

	var manual_slot := int(_config.get("manual_slot", 2))
	var outcome_ok := await _verify_campaign_outcome_route_and_followups(battle_resolution, manual_slot)
	if outcome_ok:
		_log("Live validation flow completed successfully.")
	return outcome_ok

func _execute_boot_to_campaign_defeat_outcome_flow() -> bool:
	var launch := await _enter_live_campaign_overworld()
	if not bool(launch.get("ok", false)):
		return false
	var overworld = launch.get("overworld", null)
	if overworld == null:
		return _fail("Campaign launch did not provide an overworld scene instance for defeat validation.", launch)

	var pressure_route := await _drive_overworld_to_defeat_outcome(overworld, "campaign_defeat")
	if not bool(pressure_route.get("ok", false)):
		return false
	var manual_slot := int(_config.get("manual_slot", 2))
	var outcome_ok := await _verify_campaign_defeat_outcome_route_and_followups(pressure_route, manual_slot)
	if outcome_ok:
		_log("Live validation flow completed successfully.")
	return outcome_ok

func _execute_boot_to_campaign_full_arc_flow() -> bool:
	var launch := await _enter_live_campaign_overworld()
	if not bool(launch.get("ok", false)):
		return false
	var current_overworld = launch.get("overworld", null)
	if current_overworld == null:
		return _fail("Campaign full-arc launch did not provide an overworld scene instance.", launch)

	var campaign_id := String(launch.get("campaign_id", _configured_campaign_id()))
	var chapter_ids := _campaign_scenario_ids(campaign_id)
	var starting_scenario_id := String(_config.get("scenario_id", ""))
	if not _require(chapter_ids.size() >= 2, "Campaign full-arc validation requires an authored multi-chapter campaign.", {"campaign_id": campaign_id, "chapter_ids": chapter_ids}):
		return false
	if not _require(starting_scenario_id == String(chapter_ids[0]), "Campaign full-arc validation must start from the authored campaign opener in the shipped browser.", {"configured_scenario_id": starting_scenario_id, "authored_opener": String(chapter_ids[0])}):
		return false

	var manual_slot := int(_config.get("manual_slot", 2))
	for chapter_index in range(chapter_ids.size()):
		var scenario_id := String(chapter_ids[chapter_index])
		_set_current_validation_scenario(scenario_id)
		var step_prefix := "campaign_arc_chapter_%d" % int(chapter_index + 1)
		var is_finale := chapter_index == chapter_ids.size() - 1
		var chapter_route := await _drive_campaign_chapter_to_victory_outcome(
			current_overworld,
			campaign_id,
			scenario_id,
			step_prefix
		)
		if not bool(chapter_route.get("ok", false)):
			return false

		var outcome = chapter_route.get("scene", null)
		if outcome == null:
			return _fail("Campaign full-arc chapter routing did not provide an outcome scene instance.", chapter_route)
		var outcome_snapshot: Dictionary = chapter_route.get("snapshot", {})
		if is_finale:
			if not _assert_campaign_finale_outcome_snapshot(outcome_snapshot, campaign_id, scenario_id):
				return false
			var finale_resume := await _save_and_resume_outcome_from_main_menu(
				outcome,
				manual_slot,
				"victory",
				"%s_outcome" % step_prefix
			)
			if not bool(finale_resume.get("ok", false)):
				return false
			outcome = finale_resume.get("outcome", outcome)
			var resumed_finale_snapshot: Dictionary = outcome.call("validation_snapshot")
			if not _assert_campaign_finale_outcome_snapshot(resumed_finale_snapshot, campaign_id, scenario_id):
				return false

			var return_action: Dictionary = outcome.call("validation_perform_action", "return_to_menu")
			if not _require(bool(return_action.get("ok", false)), "Campaign finale return-to-menu action failed through the shipped outcome action row.", return_action):
				return false
			var final_menu = await _wait_for_scene(MAIN_MENU_SCENE, 10000)
			if final_menu == null:
				return _fail("Campaign finale return-to-menu action did not reach the main menu.", return_action)
			await _settle_frames(8)

			var latest_summary := SaveService.latest_loadable_summary()
			if not _assert_campaign_save_summary(
				latest_summary,
				"Campaign finale latest save after outcome action",
				scenario_id,
				campaign_id,
				"victory",
				"outcome"
			):
				return false
			final_menu.call("validation_open_campaign_stage")
			await _settle_frames(4)
			if not _require(
				bool(final_menu.call("validation_select_campaign", campaign_id)),
				"Campaign browser could not reselect the completed campaign after finale return.",
				final_menu.call("validation_snapshot")
			):
				return false
			await _settle_frames(4)
			if not _require(
				bool(final_menu.call("validation_select_campaign_chapter", scenario_id)),
				"Campaign browser could not select the completed finale chapter after finale return.",
				final_menu.call("validation_snapshot")
			):
				return false
			await _settle_frames(4)
			var browser_snapshot: Dictionary = final_menu.call("validation_snapshot")
			browser_snapshot["outcome_action"] = return_action
			browser_snapshot["latest_save_summary"] = latest_summary
			browser_snapshot["final_outcome_signature"] = _outcome_resume_signature(resumed_finale_snapshot)
			if not _assert_campaign_completed_browser_snapshot(browser_snapshot, campaign_id, scenario_id):
				return false
			_capture_step("campaign_arc_completed_browser", browser_snapshot)
			_log("Live validation flow completed successfully.")
			return true

		if not _assert_campaign_outcome_snapshot(outcome_snapshot, campaign_id, scenario_id, "victory", true):
			return false
		var next_action_id := _campaign_next_action_id(outcome_snapshot, scenario_id)
		if not _require(next_action_id != "", "Campaign full-arc intermediate outcome did not expose a next-chapter action.", outcome_snapshot):
			return false
		var outcome_resume := await _save_and_resume_outcome_from_main_menu(
			outcome,
			manual_slot,
			"victory",
			"%s_outcome" % step_prefix
		)
		if not bool(outcome_resume.get("ok", false)):
			return false
		outcome = outcome_resume.get("outcome", outcome)
		var resumed_outcome_snapshot: Dictionary = outcome.call("validation_snapshot")
		if not _assert_campaign_outcome_snapshot(resumed_outcome_snapshot, campaign_id, scenario_id, "victory", true):
			return false
		var resumed_next_action_id := _campaign_next_action_id(resumed_outcome_snapshot, scenario_id)
		if not _require(resumed_next_action_id == next_action_id, "Campaign full-arc outcome save/resume did not preserve the next-chapter action.", {"expected": next_action_id, "actual": resumed_next_action_id, "snapshot": resumed_outcome_snapshot}):
			return false

		var outcome_action: Dictionary = outcome.call("validation_perform_action", next_action_id)
		if not _require(bool(outcome_action.get("ok", false)), "Campaign full-arc next-chapter action failed through the shipped outcome action row.", outcome_action):
			return false
		var next_overworld = await _wait_for_scene(OVERWORLD_SCENE, 10000)
		if next_overworld == null:
			return _fail("Campaign full-arc next-chapter action did not route to the overworld scene.", outcome_action)
		await _settle_frames(8)

		var next_scenario_id := next_action_id.trim_prefix("campaign_start:")
		var authored_next_scenario_id := String(chapter_ids[chapter_index + 1])
		if not _require(next_scenario_id == authored_next_scenario_id, "Campaign full-arc next-chapter action did not target the authored chapter chain.", {"action_id": next_action_id, "authored_next_scenario_id": authored_next_scenario_id}):
			return false
		_set_current_validation_scenario(next_scenario_id)
		var next_snapshot: Dictionary = next_overworld.call("validation_snapshot")
		if not _assert_campaign_downstream_overworld_snapshot(
			next_snapshot,
			campaign_id,
			next_scenario_id,
			scenario_id,
			"Campaign full-arc chapter %d follow-up overworld" % int(chapter_index + 1)
		):
			return false
		var followup_summary := SaveService.latest_loadable_summary()
		if not _assert_campaign_save_summary(
			followup_summary,
			"Campaign full-arc follow-up autosave",
			next_scenario_id,
			campaign_id,
			"in_progress",
			"overworld"
		):
			return false
		next_snapshot["outcome_action"] = outcome_action
		next_snapshot["latest_save_summary"] = followup_summary
		next_snapshot["previous_outcome_signature"] = _outcome_resume_signature(resumed_outcome_snapshot)
		_capture_step("%s_next_chapter_overworld_entered" % step_prefix, next_snapshot)

		var downstream_resume := await _save_and_resume_campaign_overworld_from_main_menu(
			next_overworld,
			manual_slot,
			next_scenario_id,
			campaign_id,
			"campaign_arc_chapter_%d_entry" % int(chapter_index + 2)
		)
		if not bool(downstream_resume.get("ok", false)):
			return false
		current_overworld = downstream_resume.get("overworld", next_overworld)
		var resumed_next_snapshot: Dictionary = downstream_resume.get("snapshot", {})
		if not _assert_campaign_downstream_overworld_snapshot(
			resumed_next_snapshot,
			campaign_id,
			next_scenario_id,
			scenario_id,
			"Resumed campaign full-arc chapter %d overworld" % int(chapter_index + 2)
		):
			return false

	return _fail("Campaign full-arc validation ended without reaching the authored finale.", {"campaign_id": campaign_id, "chapter_ids": chapter_ids})

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
		var resolved_ok := await _verify_outcome_route_and_followups(battle_resolution, manual_slot, "victory")
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

func _drive_overworld_to_defeat_outcome(overworld, step_prefix: String = "defeat") -> Dictionary:
	var current_overworld = overworld
	var turn_history := []
	var starting_snapshot: Dictionary = current_overworld.call("validation_snapshot") if current_overworld != null else {}
	_capture_step(_defeat_pressure_step_id(step_prefix, "watch_started"), starting_snapshot)
	for turn_index in range(MAX_VALIDATION_DEFEAT_END_TURNS):
		if current_overworld == null:
			return _fail_with_payload("Defeat validation lost the active overworld scene before outcome routing.", {"turn_history": turn_history})
		var before_snapshot: Dictionary = current_overworld.call("validation_snapshot")
		var end_turn_result: Dictionary = current_overworld.call("validation_end_turn")
		turn_history.append(
			{
				"turn_index": turn_index,
				"before": before_snapshot,
				"result": end_turn_result.duplicate(true),
			}
		)
		if not _require(bool(end_turn_result.get("ok", false)), "Defeat validation end-turn action failed on the shipped overworld shell.", end_turn_result):
			return {"ok": false}
		await _settle_frames(8)
		var current_scene = get_tree().current_scene
		if current_scene == null:
			continue
		var scene_path := String(current_scene.scene_file_path)
		if scene_path == SCENARIO_OUTCOME_SCENE:
			var outcome_snapshot: Dictionary = current_scene.call("validation_snapshot")
			outcome_snapshot["defeat_turn_history"] = turn_history
			if not _require(String(outcome_snapshot.get("scenario_status", "")) == "defeat", "Defeat validation reached the outcome shell without defeat state.", outcome_snapshot):
				return {"ok": false}
			if not _require(String(outcome_snapshot.get("scenario_summary", "")) != "", "Defeat outcome did not expose a scenario summary.", outcome_snapshot):
				return {"ok": false}
			_capture_step(_defeat_pressure_step_id(step_prefix, "outcome_entered"), outcome_snapshot)
			return {
				"ok": true,
				"scene": current_scene,
				"snapshot": outcome_snapshot,
			}
		if scene_path == BATTLE_SCENE:
			var battle_exit := await _resolve_defeat_pressure_battle_interrupt(current_scene, turn_history, step_prefix)
			if not bool(battle_exit.get("ok", false)):
				return battle_exit
			if String(battle_exit.get("scene_path", "")) == SCENARIO_OUTCOME_SCENE:
				var outcome_scene = battle_exit.get("scene", null)
				var outcome_snapshot: Dictionary = battle_exit.get("snapshot", {})
				outcome_snapshot["defeat_turn_history"] = turn_history
				_capture_step(_defeat_pressure_step_id(step_prefix, "outcome_entered"), outcome_snapshot)
				return {
					"ok": true,
					"scene": outcome_scene,
					"snapshot": outcome_snapshot,
				}
			current_overworld = battle_exit.get("scene", null)
			continue
		if scene_path != OVERWORLD_SCENE:
			return _fail_with_payload(
				"Defeat validation routed to an unexpected scene while advancing authored pressure.",
				{
					"scene_path": scene_path,
					"turn_history": turn_history,
				}
			)
		current_overworld = current_scene
		var after_snapshot: Dictionary = current_overworld.call("validation_snapshot")
		after_snapshot["end_turn_result"] = end_turn_result
		_capture_step(_defeat_pressure_step_id(step_prefix, "day_%d" % int(after_snapshot.get("day", turn_index + 1))), after_snapshot)

	return _fail_with_payload(
		"Defeat validation did not reach the outcome shell within the end-turn budget.",
		{
			"max_turns": MAX_VALIDATION_DEFEAT_END_TURNS,
			"turn_history": turn_history,
			"current_scene": _current_scene_path(),
		}
	)

func _resolve_defeat_pressure_battle_interrupt(battle, turn_history: Array, step_prefix: String = "defeat") -> Dictionary:
	var battle_snapshot: Dictionary = battle.call("validation_snapshot") if battle != null else {}
	battle_snapshot["defeat_turn_history"] = turn_history
	_capture_step(_defeat_pressure_step_id(step_prefix, "battle_interrupt"), battle_snapshot)
	for action_id in ["surrender", "retreat"]:
		var action_result: Dictionary = battle.call("validation_perform_action", action_id)
		await _settle_frames(8)
		var current_scene = get_tree().current_scene
		var scene_path := _current_scene_path()
		var payload := {
			"action_id": action_id,
			"action_result": action_result,
			"battle_snapshot": battle_snapshot,
			"scene_path": scene_path,
		}
		if current_scene != null and scene_path == SCENARIO_OUTCOME_SCENE:
			var outcome_snapshot: Dictionary = current_scene.call("validation_snapshot")
			if not _require(String(outcome_snapshot.get("scenario_status", "")) == "defeat", "Battle interrupt routed to outcome without defeat state.", outcome_snapshot):
				return {"ok": false}
			return {
				"ok": true,
				"scene": current_scene,
				"scene_path": scene_path,
				"snapshot": outcome_snapshot,
			}
		if bool(action_result.get("ok", false)) and current_scene != null and scene_path == OVERWORLD_SCENE:
			var overworld_snapshot: Dictionary = current_scene.call("validation_snapshot")
			overworld_snapshot["battle_interrupt_exit"] = payload
			_capture_step(_defeat_pressure_step_id(step_prefix, "after_battle_interrupt"), overworld_snapshot)
			return {
				"ok": true,
				"scene": current_scene,
				"scene_path": scene_path,
				"snapshot": overworld_snapshot,
			}
		if not bool(action_result.get("ok", false)):
			continue
	return _fail_with_payload(
		"Defeat validation could not exit an interrupting battle through a real retreat or surrender action.",
		{
			"battle_snapshot": battle_snapshot,
			"turn_history": turn_history,
			"scene_path": _current_scene_path(),
		}
	)

func _enter_live_campaign_overworld() -> Dictionary:
	_log("Waiting for main menu boot route.")
	var menu = await _wait_for_scene(MAIN_MENU_SCENE, 10000)
	if menu == null:
		_fail("Boot did not reach the main menu scene.", {})
		return {"ok": false}
	await _settle_frames(8)

	var scenario_id := String(_config.get("scenario_id", ""))
	var campaign_id := _configured_campaign_id()
	var menu_snapshot: Dictionary = menu.call("validation_snapshot")
	if not _require(int(menu_snapshot.get("campaign_count", 0)) > 0, "Main menu campaign browser did not populate.", menu_snapshot):
		return {"ok": false}
	if not _require(campaign_id != "", "No authored campaign id was available for the requested campaign live validation scenario.", menu_snapshot):
		return {"ok": false}
	menu.call("validation_open_campaign_stage")
	await _settle_frames(4)
	if not _require(
		bool(menu.call("validation_select_campaign", campaign_id)),
		"Requested campaign is not available in the live campaign browser.",
		menu.call("validation_snapshot")
	):
		return {"ok": false}
	await _settle_frames(4)
	if not _require(
		bool(menu.call("validation_select_campaign_chapter", scenario_id)),
		"Requested campaign chapter is not available in the live campaign browser.",
		menu.call("validation_snapshot")
	):
		return {"ok": false}
	await _settle_frames(4)
	menu_snapshot = menu.call("validation_snapshot")
	_capture_step("main_menu_campaign", menu_snapshot)

	var launch_result: Dictionary = menu.call("validation_start_selected_campaign_chapter")
	if not _require(bool(launch_result.get("started", false)), "Campaign launch did not stage an active campaign session.", launch_result):
		return {"ok": false}

	_log("Waiting for overworld route after live campaign menu launch.")
	var overworld = await _wait_for_scene(OVERWORLD_SCENE, 10000)
	if overworld == null:
		_fail("Campaign launch did not route into the overworld scene.", {"launch": launch_result})
		return {"ok": false}
	await _settle_frames(8)

	var overworld_snapshot: Dictionary = overworld.call("validation_snapshot")
	if not _require(String(overworld_snapshot.get("scenario_id", "")) == scenario_id, "Campaign overworld scenario id did not match the requested live launch.", overworld_snapshot):
		return {"ok": false}
	if not _require(String(overworld_snapshot.get("launch_mode", "")) == "campaign", "Campaign overworld did not preserve campaign launch mode.", overworld_snapshot):
		return {"ok": false}
	if not _require(String(overworld_snapshot.get("game_state", "")) == "overworld", "Campaign launch did not route to an overworld game state.", overworld_snapshot):
		return {"ok": false}
	if not _require(int(overworld_snapshot.get("movement_current", 0)) > 0, "Campaign overworld started without any current movement budget.", overworld_snapshot):
		return {"ok": false}
	var latest_summary: Dictionary = SaveService.latest_loadable_summary()
	if not _assert_campaign_save_summary(
		latest_summary,
		"Campaign launch autosave",
		scenario_id,
		campaign_id,
		"in_progress",
		"overworld"
	):
		return {"ok": false}
	overworld_snapshot["autosave_summary"] = latest_summary
	_capture_step("campaign_overworld_entered", overworld_snapshot)
	return {
		"ok": true,
		"overworld": overworld,
		"campaign_id": campaign_id,
	}

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

func _drive_campaign_chapter_to_victory_outcome(
	overworld,
	campaign_id: String,
	scenario_id: String,
	step_prefix: String
) -> Dictionary:
	_set_current_validation_scenario(scenario_id)
	var current_overworld = overworld
	if current_overworld == null:
		return _fail_with_payload("Campaign chapter validation started without an overworld scene.", {"campaign_id": campaign_id, "scenario_id": scenario_id})

	var town_route := await _route_from_overworld_to_scene(current_overworld, "town", "player", TOWN_SCENE)
	if not _require(bool(town_route.get("ok", false)), "Could not route from the campaign chapter overworld into the starting player town.", town_route):
		return {"ok": false}
	var town = town_route.get("scene", null)
	if town == null:
		return _fail_with_payload("Campaign chapter starting-town route completed without a town scene instance.", town_route)
	await _settle_frames(6)
	var town_snapshot: Dictionary = town.call("validation_snapshot")
	if not _require(String(town_snapshot.get("launch_mode", "")) == "campaign", "Campaign chapter starting-town route did not preserve campaign launch mode.", town_snapshot):
		return {"ok": false}
	if not _require(String(town_snapshot.get("scenario_id", "")) == scenario_id, "Campaign chapter starting-town route did not preserve the active chapter id.", town_snapshot):
		return {"ok": false}
	town_snapshot["route_history"] = town_route.get("history", [])
	_capture_step("%s_town_entered" % step_prefix, town_snapshot)

	var town_preparation := await _prepare_campaign_town(town, step_prefix)
	if not bool(town_preparation.get("ok", false)):
		return town_preparation
	town = town_preparation.get("town", town)

	var leave_result: Dictionary = town.call("validation_leave_town")
	if not _require(bool(leave_result.get("ok", false)), "Campaign chapter validation could not leave the starting town through the live router.", leave_result):
		return {"ok": false}
	current_overworld = await _wait_for_scene(OVERWORLD_SCENE, 10000)
	if current_overworld == null:
		return _fail_with_payload("Leaving the campaign chapter starting town did not route back into the overworld scene.", leave_result)
	await _settle_frames(6)
	var post_town_snapshot: Dictionary = current_overworld.call("validation_snapshot")
	post_town_snapshot["town_exit"] = leave_result
	_capture_step("%s_overworld_after_town" % step_prefix, post_town_snapshot)

	if scenario_id == "river-pass":
		var free_company_claim := await _claim_overworld_validation_target(
			current_overworld,
			"resource",
			"river_free_company",
			"%s_support_site_claimed_river_free_company" % step_prefix
		)
		if not bool(free_company_claim.get("ok", false)):
			_fail("Could not claim the authored River Pass support site before objective clearing.", free_company_claim)
			return {"ok": false}
		current_overworld = free_company_claim.get("scene", current_overworld)

	if scenario_id == "causeway-stand":
		return await _drive_causeway_chapter_to_victory_outcome(current_overworld, step_prefix)
	if scenario_id == "fen-crown":
		return await _drive_fen_crown_chapter_to_victory_outcome(current_overworld, step_prefix)

	var objective_clear := await _clear_required_encounters_to_overworld(current_overworld)
	if not bool(objective_clear.get("ok", false)):
		return {"ok": false}
	current_overworld = objective_clear.get("scene", current_overworld)

	if scenario_id == "river-pass":
		var gorget_claim := await _claim_overworld_validation_target(
			current_overworld,
			"artifact",
			"bastion_vault",
			"%s_support_artifact_claimed_bastion_vault" % step_prefix
		)
		if not bool(gorget_claim.get("ok", false)):
			_fail("Could not claim the authored River Pass Bastion Gorget before the final assault.", gorget_claim)
			return {"ok": false}
		current_overworld = gorget_claim.get("scene", current_overworld)

	var battle_route := await _route_from_overworld_to_scene(current_overworld, "town", "enemy", BATTLE_SCENE)
	if not _require(bool(battle_route.get("ok", false)), "Could not route from the campaign chapter overworld into the hostile town assault.", battle_route):
		return {"ok": false}
	var battle = battle_route.get("scene", null)
	if battle == null:
		return _fail_with_payload("Campaign chapter town-assault route completed without a battle scene instance.", battle_route)
	await _settle_frames(6)

	var assault_route := _last_history_entry(battle_route.get("history", []))
	if not _require(String(assault_route.get("pre_action_town_owner", "")) == "enemy", "Campaign chapter hostile-town route did not preserve enemy ownership before battle entry.", assault_route):
		return {"ok": false}
	var battle_snapshot: Dictionary = battle.call("validation_snapshot")
	if not _require(String(battle_snapshot.get("launch_mode", "")) == "campaign", "Campaign chapter battle route did not preserve campaign launch mode.", battle_snapshot):
		return {"ok": false}
	if not _require(String(battle_snapshot.get("scenario_id", "")) == scenario_id, "Campaign chapter battle route did not preserve the active chapter id.", battle_snapshot):
		return {"ok": false}
	if not _require(String(battle_snapshot.get("battle_context_type", "")) == "town_assault", "Campaign chapter validation did not enter a town-assault context.", battle_snapshot):
		return {"ok": false}
	battle_snapshot["route_history"] = battle_route.get("history", [])
	_capture_step("%s_battle_entered" % step_prefix, battle_snapshot)

	return await _play_battle_to_scene(
		battle,
		"%s_battle_progressed" % step_prefix,
		"%s_outcome_entered" % step_prefix,
		SCENARIO_OUTCOME_SCENE
	)

func _prepare_campaign_town(town, step_prefix: String) -> Dictionary:
	var current_town = town
	if current_town == null:
		return _fail_with_payload("Campaign town preparation started without a town scene.", {"step_prefix": step_prefix})
	if not current_town.has_method("validation_action_catalog") or not current_town.has_method("validation_perform_town_action"):
		return _fail_with_payload("Campaign town scene does not expose the routed action validation hooks.", {"step_prefix": step_prefix})

	var performed_actions := []
	for action_index in range(MAX_VALIDATION_TOWN_PREP_ACTIONS):
		var catalog: Dictionary = current_town.call("validation_action_catalog")
		var action_id := _next_campaign_town_preparation_action(catalog)
		if action_id == "":
			break
		var action_result: Dictionary = current_town.call("validation_perform_town_action", action_id)
		await _settle_frames(6)
		if not bool(action_result.get("ok", false)):
			return _fail_with_payload(
				"Campaign town preparation action failed through the shipped town action row.",
				{
					"step_prefix": step_prefix,
					"action_id": action_id,
					"result": action_result,
					"snapshot": current_town.call("validation_snapshot"),
				}
			)
		performed_actions.append(action_result.duplicate(true))
		var town_after_snapshot: Dictionary = current_town.call("validation_snapshot")
		town_after_snapshot["progress_action"] = action_result
		town_after_snapshot["preparation_actions"] = performed_actions.duplicate(true)
		_capture_step("%s_town_prepared_%d" % [step_prefix, int(action_index + 1)], town_after_snapshot)

	return {
		"ok": true,
		"town": current_town,
		"actions": performed_actions,
	}

func _next_campaign_town_preparation_action(catalog: Dictionary) -> String:
	var specialty_action_id := _preferred_campaign_specialty_action_id(catalog)
	if specialty_action_id != "":
		return specialty_action_id
	var recruit_action_id := _preferred_campaign_recruit_action_id(catalog)
	if recruit_action_id != "":
		return recruit_action_id
	return _preferred_campaign_build_action_id(catalog)

func _preferred_campaign_specialty_action_id(catalog: Dictionary) -> String:
	var actions := _action_array(catalog.get("specialty", []))
	for specialty_id in CAMPAIGN_SPECIALTY_PRIORITY:
		var action_id := "choose_specialty:%s" % String(specialty_id)
		if _action_id_available(actions, action_id):
			return action_id
	return _first_enabled_action_id(actions)

func _preferred_campaign_recruit_action_id(catalog: Dictionary) -> String:
	var actions := _action_array(catalog.get("recruit", []))
	for unit_id in CAMPAIGN_TOWN_RECRUIT_PRIORITY:
		var action_id := "recruit:%s" % String(unit_id)
		if _action_id_available(actions, action_id):
			return action_id
	return _first_enabled_action_id(actions)

func _preferred_campaign_build_action_id(catalog: Dictionary) -> String:
	var actions := _action_array(catalog.get("build", []))
	for building_id in CAMPAIGN_TOWN_BUILD_PRIORITY:
		var action_id := "build:%s" % String(building_id)
		if _action_id_available(actions, action_id) and _building_adds_immediate_recruits(String(building_id)):
			return action_id
	for action in actions:
		if not (action is Dictionary) or bool(action.get("disabled", false)):
			continue
		var action_id := String(action.get("id", ""))
		if action_id.begins_with("build:") and _building_adds_immediate_recruits(action_id.trim_prefix("build:")):
			return action_id
	return ""

func _building_adds_immediate_recruits(building_id: String) -> bool:
	var building := ContentService.get_building(building_id)
	if building.is_empty():
		return false
	if String(building.get("unlock_unit_id", "")) != "":
		return true
	var growth_bonus = building.get("growth_bonus", {})
	return growth_bonus is Dictionary and not growth_bonus.is_empty()

func _action_array(value: Variant) -> Array:
	return value if value is Array else []

func _action_id_available(actions: Array, action_id: String) -> bool:
	for action in actions:
		if action is Dictionary and String(action.get("id", "")) == action_id and not bool(action.get("disabled", false)):
			return true
	return false

func _first_enabled_action_id(actions: Array) -> String:
	for action in actions:
		if action is Dictionary and not bool(action.get("disabled", false)):
			return String(action.get("id", ""))
	return ""

func _drive_causeway_chapter_to_victory_outcome(overworld, step_prefix: String) -> Dictionary:
	var current_overworld = overworld
	for support_target in [
		{"kind": "resource", "placement_id": "causeway_fenhound_kennels", "step": "pre_outcome_support_site_claimed_causeway_fenhound_kennels"},
		{"kind": "artifact", "placement_id": "causeway_pennon", "step": "pre_outcome_support_artifact_claimed_causeway_pennon"},
	]:
		var support_claim := await _claim_overworld_validation_target(
			current_overworld,
			String(support_target.get("kind", "")),
			String(support_target.get("placement_id", "")),
			String(support_target.get("step", ""))
		)
		if not bool(support_claim.get("ok", false)):
			_fail("Could not claim the authored Causeway support target before the gate push.", support_claim)
			return {"ok": false}
		current_overworld = support_claim.get("scene", current_overworld)

	var gate_clear := await _clear_campaign_encounter_to_scene(
		current_overworld,
		"causeway_gate_marshals",
		"pre_outcome_objective_battle",
		OVERWORLD_SCENE,
		"overworld_after_pre_outcome_objective_causeway_gate_marshals"
	)
	if not bool(gate_clear.get("ok", false)):
		return {"ok": false}
	current_overworld = gate_clear.get("scene", current_overworld)

	var town_route := await _route_from_overworld_to_scene(current_overworld, "town", "enemy", BATTLE_SCENE, "blackfen_gate")
	if not _require(bool(town_route.get("ok", false)), "Could not route from Causeway overworld into the Blackfen Gate assault.", town_route):
		return {"ok": false}
	var town_battle = town_route.get("scene", null)
	if town_battle == null:
		return _fail_with_payload("Causeway Blackfen Gate assault route completed without a battle scene instance.", town_route)
	await _settle_frames(6)
	if town_battle.has_method("validation_set_support_spell_priority"):
		town_battle.call("validation_set_support_spell_priority", true)
	var town_battle_snapshot: Dictionary = town_battle.call("validation_snapshot")
	town_battle_snapshot["route_history"] = town_route.get("history", [])
	_capture_step("%s_blackfen_gate_battle_entered" % step_prefix, town_battle_snapshot)
	var town_capture := await _play_battle_to_scene(
		town_battle,
		"%s_blackfen_gate_battle_progressed" % step_prefix,
		"%s_blackfen_gate_captured" % step_prefix,
		OVERWORLD_SCENE
	)
	if not bool(town_capture.get("ok", false)):
		return {"ok": false}
	current_overworld = town_capture.get("scene", current_overworld)

	var recruited := await _recruit_from_campaign_town(current_overworld, "blackfen_gate", "%s_blackfen_gate" % step_prefix)
	if not bool(recruited.get("ok", false)):
		return recruited
	current_overworld = recruited.get("scene", current_overworld)

	var reed_clear := await _clear_campaign_encounter_to_scene(
		current_overworld,
		"causeway_reed_camp",
		"pre_outcome_objective_battle",
		OVERWORLD_SCENE,
		"overworld_after_pre_outcome_objective_causeway_reed_camp"
	)
	if not bool(reed_clear.get("ok", false)):
		return {"ok": false}
	current_overworld = reed_clear.get("scene", current_overworld)

	return await _clear_campaign_encounter_to_scene(
		current_overworld,
		"causeway_levee_cutters",
		"pre_outcome_objective_battle",
		SCENARIO_OUTCOME_SCENE,
		"%s_outcome_entered" % step_prefix
	)

func _drive_fen_crown_chapter_to_victory_outcome(overworld, step_prefix: String) -> Dictionary:
	var current_overworld = overworld
	for support_target in [
		{"kind": "resource", "placement_id": "crown_timber", "step": "pre_outcome_support_site_claimed_crown_timber"},
		{"kind": "resource", "placement_id": "reedward_ford_cache", "step": "pre_outcome_support_site_claimed_reedward_ford_cache"},
	]:
		var support_claim := await _claim_overworld_validation_target(
			current_overworld,
			String(support_target.get("kind", "")),
			String(support_target.get("placement_id", "")),
			String(support_target.get("step", ""))
		)
		if not bool(support_claim.get("ok", false)):
			_fail("Could not claim the authored Fen Crown support target before the bridgehead refit.", support_claim)
			return {"ok": false}
		current_overworld = support_claim.get("scene", current_overworld)

	var income_day := await _advance_campaign_overworld_day(current_overworld, "%s_refit_income_day" % step_prefix)
	if not bool(income_day.get("ok", false)):
		return income_day
	current_overworld = income_day.get("scene", current_overworld)

	var refit := await _recruit_from_campaign_town(current_overworld, "blackfen_bridgehead", "%s_blackfen_bridgehead_refit" % step_prefix)
	if not bool(refit.get("ok", false)):
		return refit
	current_overworld = refit.get("scene", current_overworld)

	var crown_watch := await _clear_campaign_encounter_to_scene(
		current_overworld,
		"fen_crown_watch",
		"pre_outcome_objective_battle",
		OVERWORLD_SCENE,
		"overworld_after_pre_outcome_objective_fen_crown_watch"
	)
	if not bool(crown_watch.get("ok", false)):
		return {"ok": false}
	current_overworld = crown_watch.get("scene", current_overworld)

	var bone_ferry := await _clear_campaign_encounter_to_scene(
		current_overworld,
		"bone_ferry",
		"pre_outcome_objective_battle",
		OVERWORLD_SCENE,
		"overworld_after_pre_outcome_objective_bone_ferry"
	)
	if not bool(bone_ferry.get("ok", false)):
		return {"ok": false}
	current_overworld = bone_ferry.get("scene", current_overworld)

	var ferry_watch := await _clear_campaign_encounter_to_scene(
		current_overworld,
		"fen_crown_bone_ferry_watch",
		"pre_outcome_objective_battle",
		OVERWORLD_SCENE,
		"overworld_after_pre_outcome_objective_fen_crown_bone_ferry_watch"
	)
	if not bool(ferry_watch.get("ok", false)):
		return {"ok": false}
	current_overworld = ferry_watch.get("scene", current_overworld)

	var inner_cache := await _claim_overworld_validation_target(
		current_overworld,
		"resource",
		"inner_cache",
		"pre_outcome_support_site_claimed_inner_cache"
	)
	if not bool(inner_cache.get("ok", false)):
		return inner_cache
	current_overworld = inner_cache.get("scene", current_overworld)

	var final_income_day := await _advance_campaign_overworld_day(current_overworld, "%s_final_refit_income_day" % step_prefix)
	if not bool(final_income_day.get("ok", false)):
		return final_income_day
	current_overworld = final_income_day.get("scene", current_overworld)

	var final_refit := await _recruit_from_campaign_town(current_overworld, "blackfen_bridgehead", "%s_blackfen_bridgehead_final_refit" % step_prefix)
	if not bool(final_refit.get("ok", false)):
		return final_refit
	current_overworld = final_refit.get("scene", current_overworld)

	if current_overworld.has_method("validation_cast_overworld_spell"):
		var movement_spell: Dictionary = current_overworld.call("validation_cast_overworld_spell", "spell_trailglyph")
		await _settle_frames(6)
		if not _require(bool(movement_spell.get("ok", false)), "Could not cast the real Trailglyph overworld spell before the final Fen Crown march.", movement_spell):
			return {"ok": false}
		var movement_spell_snapshot: Dictionary = current_overworld.call("validation_snapshot")
		movement_spell_snapshot["spell_result"] = movement_spell
		_capture_step("%s_final_march_spell_cast" % step_prefix, movement_spell_snapshot)

	var town_route := await _route_from_overworld_to_scene(current_overworld, "town", "enemy", BATTLE_SCENE, "fen_crown_redoubt")
	if not _require(bool(town_route.get("ok", false)), "Could not route from Fen Crown overworld into the final redoubt assault.", town_route):
		return {"ok": false}
	var town_battle = town_route.get("scene", null)
	if town_battle == null:
		return _fail_with_payload("Fen Crown redoubt assault route completed without a battle scene instance.", town_route)
	await _settle_frames(6)
	if town_battle.has_method("validation_set_support_spell_priority"):
		town_battle.call("validation_set_support_spell_priority", false)
	if town_battle.has_method("validation_set_max_spell_casts"):
		town_battle.call("validation_set_max_spell_casts", 3)
	var town_battle_snapshot: Dictionary = town_battle.call("validation_snapshot")
	if not _require(String(town_battle_snapshot.get("battle_context_type", "")) == "town_assault", "Fen Crown finale did not enter a town-assault battle for the redoubt.", town_battle_snapshot):
		return {"ok": false}
	town_battle_snapshot["route_history"] = town_route.get("history", [])
	_capture_step("%s_fen_crown_redoubt_battle_entered" % step_prefix, town_battle_snapshot)

	return await _play_battle_to_scene(
		town_battle,
		"%s_fen_crown_redoubt_battle_progressed" % step_prefix,
		"%s_outcome_entered" % step_prefix,
		SCENARIO_OUTCOME_SCENE
	)

func _recruit_from_campaign_town(overworld, placement_id: String, step_prefix: String) -> Dictionary:
	var town_route := await _route_from_overworld_to_scene(overworld, "town", "player", TOWN_SCENE, placement_id)
	if not _require(bool(town_route.get("ok", false)), "Could not route into the captured campaign town for recruitment.", town_route):
		return {"ok": false}
	var town = town_route.get("scene", null)
	if town == null:
		return _fail_with_payload("Captured campaign town route completed without a town scene instance.", town_route)
	await _settle_frames(6)
	var town_snapshot: Dictionary = town.call("validation_snapshot")
	town_snapshot["route_history"] = town_route.get("history", [])
	_capture_step("%s_town_entered" % step_prefix, town_snapshot)

	var town_preparation := await _prepare_campaign_town(town, step_prefix)
	if not bool(town_preparation.get("ok", false)):
		return town_preparation
	town = town_preparation.get("town", town)

	var leave_result: Dictionary = town.call("validation_leave_town")
	if not _require(bool(leave_result.get("ok", false)), "Could not leave the captured campaign town after recruitment.", leave_result):
		return {"ok": false}
	var current_overworld = await _wait_for_scene(OVERWORLD_SCENE, 10000)
	if current_overworld == null:
		return _fail_with_payload("Leaving the captured campaign town did not route back into the overworld scene.", leave_result)
	await _settle_frames(6)
	var post_town_snapshot: Dictionary = current_overworld.call("validation_snapshot")
	post_town_snapshot["town_exit"] = leave_result
	_capture_step("%s_overworld_after_town" % step_prefix, post_town_snapshot)
	return {
		"ok": true,
		"scene": current_overworld,
	}

func _clear_campaign_encounter_to_scene(
	overworld,
	placement_id: String,
	step_prefix: String,
	destination_scene: String,
	destination_step_id: String
) -> Dictionary:
	if _encounter_placement_resolved(placement_id):
		return {
			"ok": true,
			"scene": overworld,
		}
	var battle_route := await _route_from_overworld_to_scene(overworld, "encounter", "", BATTLE_SCENE, placement_id)
	if not _require(bool(battle_route.get("ok", false)), "Could not route into the campaign encounter objective.", battle_route):
		return {"ok": false}
	var battle = battle_route.get("scene", null)
	if battle == null:
		return _fail_with_payload("Campaign encounter route completed without a battle scene instance.", battle_route)
	await _settle_frames(6)
	_prepare_required_encounter_battle_validation(battle, placement_id)
	var battle_snapshot: Dictionary = battle.call("validation_snapshot")
	battle_snapshot["route_history"] = battle_route.get("history", [])
	battle_snapshot["objective_placement_id"] = placement_id
	_capture_step("%s_entered_%s" % [step_prefix, placement_id], battle_snapshot)
	var resolved_route := await _play_battle_to_scene(
		battle,
		"%s_progressed_%s" % [step_prefix, placement_id],
		destination_step_id,
		destination_scene
	)
	if not bool(resolved_route.get("ok", false)):
		return {"ok": false}
	if destination_scene == OVERWORLD_SCENE and not _require(
		_encounter_placement_resolved(placement_id),
		"Campaign encounter objective did not mark its placement resolved.",
		{"placement_id": placement_id, "snapshot": resolved_route.get("snapshot", {})}
	):
		return {"ok": false}
	return resolved_route

func _advance_campaign_overworld_day(overworld, step_id: String) -> Dictionary:
	if overworld == null:
		return _fail_with_payload("Campaign day advance started without an overworld scene.", {"step_id": step_id})
	var before_snapshot: Dictionary = overworld.call("validation_snapshot")
	var end_turn_result: Dictionary = overworld.call("validation_end_turn")
	await _settle_frames(8)
	if not _require(bool(end_turn_result.get("ok", false)), "Campaign validation end-turn action failed on the shipped overworld shell.", end_turn_result):
		return {"ok": false}
	var current_scene = get_tree().current_scene
	if current_scene == null:
		return _fail_with_payload(
			"Campaign validation end-turn left no active scene.",
			{
				"step_id": step_id,
				"before": before_snapshot,
				"result": end_turn_result,
			}
		)
	var scene_path := String(current_scene.scene_file_path)
	if scene_path != OVERWORLD_SCENE:
		var routed_snapshot := {}
		if current_scene.has_method("validation_snapshot"):
			routed_snapshot = current_scene.call("validation_snapshot")
		return _fail_with_payload(
			"Campaign validation end-turn routed away from overworld unexpectedly.",
			{
				"step_id": step_id,
				"scene_path": scene_path,
				"before": before_snapshot,
				"result": end_turn_result,
				"snapshot": routed_snapshot,
			}
		)
	var after_snapshot: Dictionary = current_scene.call("validation_snapshot")
	after_snapshot["before_end_turn"] = before_snapshot
	after_snapshot["end_turn_result"] = end_turn_result
	_capture_step(step_id, after_snapshot)
	return {
		"ok": true,
		"scene": current_scene,
		"snapshot": after_snapshot,
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
		_prepare_required_encounter_battle_validation(battle, placement_id)

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
	var causeway_support_claimed := false
	while true:
		var placement_id := _next_required_encounter_placement(current_overworld, required_placements)
		if placement_id == "":
			break
		if _encounter_placement_resolved(placement_id):
			continue
		if (
			String(_config.get("scenario_id", "")) == "causeway-stand"
			and placement_id == "causeway_gate_marshals"
			and not causeway_support_claimed
		):
			var kennels_claim := await _claim_overworld_validation_target(
				current_overworld,
				"resource",
				"causeway_fenhound_kennels",
				"pre_outcome_support_site_claimed_causeway_fenhound_kennels"
			)
			if not bool(kennels_claim.get("ok", false)):
				_fail("Could not claim the authored Causeway support dwelling before the gate marshals.", kennels_claim)
				return {"ok": false}
			current_overworld = kennels_claim.get("scene", current_overworld)
			var pennon_claim := await _claim_overworld_validation_target(
				current_overworld,
				"artifact",
				"causeway_pennon",
				"pre_outcome_support_artifact_claimed_causeway_pennon"
			)
			if not bool(pennon_claim.get("ok", false)):
				_fail("Could not claim the authored Causeway command pennon before the gate marshals.", pennon_claim)
				return {"ok": false}
			current_overworld = pennon_claim.get("scene", current_overworld)
			causeway_support_claimed = true
		var battle_route := await _route_from_overworld_to_scene(current_overworld, "encounter", "", BATTLE_SCENE, placement_id)
		if not _require(bool(battle_route.get("ok", false)), "Could not route from the live overworld into a required encounter objective before the final assault.", battle_route):
			return {"ok": false}
		var battle = battle_route.get("scene", null)
		if battle == null:
			_fail("Required encounter route completed without a battle scene instance before the final assault.", battle_route)
			return {"ok": false}
		await _settle_frames(6)
		_prepare_required_encounter_battle_validation(battle, placement_id)

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
	if String(_config.get("scenario_id", "")) == "causeway-stand":
		if not _encounter_placement_resolved("causeway_gate_marshals"):
			return "causeway_gate_marshals"
		if not _encounter_placement_resolved("causeway_reed_camp"):
			return "causeway_reed_camp"
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
		"low":
			difficulty_score = 0
		"medium":
			difficulty_score = 1
		"high":
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

func _prepare_required_encounter_battle_validation(battle, placement_id: String) -> void:
	if battle == null:
		return
	var scenario := ContentService.get_scenario(String(_config.get("scenario_id", "")))
	var encounter_placement := _scenario_encounter_placement(scenario, placement_id)
	var is_high_difficulty := String(encounter_placement.get("difficulty", "")) == "high"
	var is_fen_crown_route := String(scenario.get("id", "")) == "fen-crown"
	var should_enable_spells := is_high_difficulty or placement_id in ["causeway_reed_camp", "causeway_levee_cutters"]
	if battle.has_method("validation_set_spell_casting_enabled"):
		battle.call("validation_set_spell_casting_enabled", should_enable_spells)
	if battle.has_method("validation_set_support_spell_priority"):
		battle.call("validation_set_support_spell_priority", is_high_difficulty and not is_fen_crown_route and placement_id != "causeway_gate_marshals")
	if battle.has_method("validation_set_max_spell_casts"):
		battle.call("validation_set_max_spell_casts", 2 if is_fen_crown_route and should_enable_spells else 1)

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

func _save_and_resume_outcome_from_main_menu(
	outcome,
	manual_slot: int,
	expected_status: String = "victory",
	step_prefix: String = "outcome"
) -> Dictionary:
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
	if not _require(
		String(outcome_save_summary.get("scenario_status", "")) == expected_status,
		"Outcome manual save did not preserve %s status." % expected_status,
		outcome_save_summary
	):
		return {"ok": false}
	if not _require(String(outcome_save_summary.get("scenario_id", "")) == String(_config.get("scenario_id", "")), "Outcome manual save summary scenario id did not match the launched scenario.", outcome_save_summary):
		return {"ok": false}
	if String(outcome_save_summary.get("launch_mode", "")) == "campaign":
		if not _assert_campaign_save_summary(
			outcome_save_summary,
			"Campaign outcome manual save",
			String(_config.get("scenario_id", "")),
			_configured_campaign_id(),
			expected_status,
			"outcome"
		):
			return {"ok": false}
	if not _require(SaveService.load_action_label(outcome_save_summary) == "Review Outcome", "Outcome manual save did not expose the review load action.", outcome_save_summary):
		return {"ok": false}
	if not _require(SaveService.continue_action_label(outcome_save_summary) == "Review Latest Outcome", "Outcome manual save did not expose the review continue action.", outcome_save_summary):
		return {"ok": false}
	await _settle_frames(6)

	var outcome_saved_snapshot: Dictionary = outcome.call("validation_snapshot")
	outcome_saved_snapshot["manual_save"] = outcome_save
	_capture_step(_prefixed_step_id(step_prefix, "saved"), outcome_saved_snapshot)
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
	if not _require(
		String(latest_summary_after_menu_return.get("scenario_status", "")) == expected_status,
		"Latest save summary after outcome return-to-menu did not preserve %s status." % expected_status,
		latest_summary_after_menu_return
	):
		return {"ok": false}
	if String(latest_summary_after_menu_return.get("launch_mode", "")) == "campaign":
		if not _assert_campaign_save_summary(
			latest_summary_after_menu_return,
			"Latest campaign outcome save after menu return",
			String(_config.get("scenario_id", "")),
			_configured_campaign_id(),
			expected_status,
			"outcome"
		):
			return {"ok": false}
	var menu_after_return_snapshot: Dictionary = menu.call("validation_snapshot")
	menu_after_return_snapshot["menu_return"] = outcome_menu_return
	menu_after_return_snapshot["latest_save_summary"] = latest_summary_after_menu_return
	_capture_step(_prefixed_menu_step_id(step_prefix, "return"), menu_after_return_snapshot)

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
	if not _require(
		String(resumed_outcome_snapshot.get("scenario_status", "")) == expected_status,
		"Resumed outcome save did not restore %s state." % expected_status,
		resumed_outcome_snapshot
	):
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
	_capture_step(_prefixed_step_id(step_prefix, "resumed"), resumed_outcome_snapshot)
	return {
		"ok": true,
		"outcome": resumed_outcome,
	}

func _verify_outcome_route_and_followups(
	outcome_route: Dictionary,
	manual_slot: int,
	expected_status: String = "victory",
	step_prefix: String = "outcome"
) -> bool:
	var outcome = outcome_route.get("scene", null)
	if outcome == null:
		return _fail("Resolved scenario routing did not provide an outcome scene instance.", outcome_route)
	var outcome_snapshot: Dictionary = outcome_route.get("snapshot", {})
	if not _require(
		String(outcome_snapshot.get("scenario_status", "")) == expected_status,
		"Outcome shell did not receive a %s session." % expected_status,
		outcome_snapshot
	):
		return false
	if not _require(String(outcome_snapshot.get("resume_target", "")) == "outcome", "Outcome shell did not advertise outcome resume semantics.", outcome_snapshot):
		return false
	if not _require(String(outcome_snapshot.get("scenario_summary", "")) != "", "Outcome shell did not expose the resolved scenario summary.", outcome_snapshot):
		return false
	if not _require(expected_status.capitalize() in String(outcome_snapshot.get("header", "")), "Outcome header did not surface the expected result state.", outcome_snapshot):
		return false
	var latest_outcome_summary := _dictionary_value(outcome_snapshot.get("latest_save_summary", {}))
	if not _require(not latest_outcome_summary.is_empty(), "Resolved autosave summary was unavailable on the outcome shell.", outcome_snapshot):
		return false
	if not _require(String(latest_outcome_summary.get("resume_target", "")) == "outcome", "Resolved autosave did not advertise outcome review.", latest_outcome_summary):
		return false
	if not _require(
		String(latest_outcome_summary.get("scenario_status", "")) == expected_status,
		"Resolved autosave summary did not preserve %s status." % expected_status,
		latest_outcome_summary
	):
		return false
	if not _require("skirmish_start:%s" % String(_config.get("scenario_id", "")) in _string_array_value(outcome_snapshot.get("action_ids", [])), "Outcome shell did not offer the real skirmish retry action.", outcome_snapshot):
		return false
	if not _require("return_to_menu" in _string_array_value(outcome_snapshot.get("action_ids", [])), "Outcome shell did not offer the return-to-menu action.", outcome_snapshot):
		return false

	var outcome_resume := await _save_and_resume_outcome_from_main_menu(outcome, manual_slot, expected_status, step_prefix)
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
	if not _require(
		String(_dictionary_value(final_menu_snapshot.get("latest_save_summary", {})).get("scenario_status", "")) == expected_status,
		"Main menu latest save after outcome action did not preserve %s status." % expected_status,
		final_menu_snapshot
	):
		return false
	_capture_step(_prefixed_menu_step_id(step_prefix, "action"), final_menu_snapshot)
	return true

func _verify_campaign_outcome_route_and_followups(outcome_route: Dictionary, manual_slot: int) -> bool:
	var campaign_id := _configured_campaign_id()
	var scenario_id := String(_config.get("scenario_id", ""))
	var outcome = outcome_route.get("scene", null)
	if outcome == null:
		return _fail("Campaign resolved routing did not provide an outcome scene instance.", outcome_route)
	var outcome_snapshot: Dictionary = outcome_route.get("snapshot", {})
	if not _assert_campaign_outcome_snapshot(outcome_snapshot, campaign_id, scenario_id, "victory", true):
		return false

	var next_action_id := _campaign_next_action_id(outcome_snapshot, scenario_id)
	if not _require(next_action_id != "", "Campaign victory outcome did not expose an unlocked next-chapter action.", outcome_snapshot):
		return false

	var outcome_resume := await _save_and_resume_outcome_from_main_menu(outcome, manual_slot, "victory", "campaign_outcome")
	if not bool(outcome_resume.get("ok", false)):
		return false
	outcome = outcome_resume.get("outcome", outcome)
	var resumed_outcome_snapshot: Dictionary = outcome.call("validation_snapshot")
	if not _assert_campaign_outcome_snapshot(resumed_outcome_snapshot, campaign_id, scenario_id, "victory", true):
		return false
	var resumed_next_action_id := _campaign_next_action_id(resumed_outcome_snapshot, scenario_id)
	if not _require(resumed_next_action_id == next_action_id, "Campaign outcome save/resume did not preserve the next-chapter follow-up action.", {"expected": next_action_id, "actual": resumed_next_action_id, "snapshot": resumed_outcome_snapshot}):
		return false

	var outcome_action: Dictionary = outcome.call("validation_perform_action", next_action_id)
	if not _require(bool(outcome_action.get("ok", false)), "Campaign next-chapter follow-up failed through the shipped outcome action row.", outcome_action):
		return false
	var next_overworld = await _wait_for_scene(OVERWORLD_SCENE, 10000)
	if next_overworld == null:
		return _fail("Campaign next-chapter follow-up did not route to the overworld scene.", outcome_action)
	await _settle_frames(8)

	var next_scenario_id := next_action_id.trim_prefix("campaign_start:")
	var authored_next_scenario_id := _campaign_next_scenario_id(campaign_id, scenario_id)
	if not _require(authored_next_scenario_id != "", "Campaign victory did not have an authored downstream chapter to validate.", {"campaign_id": campaign_id, "scenario_id": scenario_id}):
		return false
	if not _require(next_scenario_id == authored_next_scenario_id, "Campaign next-chapter action did not target the authored downstream chapter.", {"action_id": next_action_id, "authored_next_scenario_id": authored_next_scenario_id}):
		return false
	var next_snapshot: Dictionary = next_overworld.call("validation_snapshot")
	if not _require(String(next_snapshot.get("scenario_id", "")) == next_scenario_id, "Campaign follow-up routed to the wrong chapter scenario.", next_snapshot):
		return false
	if not _require(next_scenario_id != scenario_id, "Campaign follow-up replayed the completed chapter instead of launching the next chapter.", next_snapshot):
		return false
	if not _assert_campaign_downstream_overworld_snapshot(next_snapshot, campaign_id, next_scenario_id, scenario_id, "Campaign follow-up overworld"):
		return false
	var followup_summary := SaveService.latest_loadable_summary()
	if not _assert_campaign_save_summary(
		followup_summary,
		"Campaign follow-up autosave",
		next_scenario_id,
		campaign_id,
		"in_progress",
		"overworld"
	):
		return false
	next_snapshot["outcome_action"] = outcome_action
	next_snapshot["latest_save_summary"] = followup_summary
	next_snapshot["previous_outcome_signature"] = _outcome_resume_signature(resumed_outcome_snapshot)
	_capture_step("campaign_next_chapter_overworld_entered", next_snapshot)

	var downstream_resume := await _save_and_resume_campaign_overworld_from_main_menu(
		next_overworld,
		manual_slot,
		next_scenario_id,
		campaign_id,
		"campaign_next_chapter"
	)
	if not bool(downstream_resume.get("ok", false)):
		return false
	next_overworld = downstream_resume.get("overworld", next_overworld)
	var resumed_next_snapshot: Dictionary = downstream_resume.get("snapshot", {})
	if not _assert_campaign_downstream_overworld_snapshot(resumed_next_snapshot, campaign_id, next_scenario_id, scenario_id, "Resumed campaign follow-up overworld"):
		return false

	var skirmish_baseline := await _launch_skirmish_baseline_from_campaign_overworld(
		next_overworld,
		next_scenario_id,
		campaign_id
	)
	if not bool(skirmish_baseline.get("ok", false)):
		return false
	var skirmish_snapshot: Dictionary = skirmish_baseline.get("snapshot", {})
	if not _assert_downstream_carryover_differs_from_skirmish(resumed_next_snapshot, skirmish_snapshot, scenario_id):
		return false
	skirmish_snapshot["campaign_carryover_signature"] = _campaign_carryover_signature(resumed_next_snapshot)
	skirmish_snapshot["skirmish_baseline_signature"] = _campaign_carryover_signature(skirmish_snapshot)
	_capture_step("campaign_next_chapter_skirmish_baseline", skirmish_snapshot)
	return true

func _verify_campaign_defeat_outcome_route_and_followups(outcome_route: Dictionary, manual_slot: int) -> bool:
	var campaign_id := _configured_campaign_id()
	var scenario_id := String(_config.get("scenario_id", ""))
	var outcome = outcome_route.get("scene", null)
	if outcome == null:
		return _fail("Campaign defeat routing did not provide an outcome scene instance.", outcome_route)
	var outcome_snapshot: Dictionary = outcome_route.get("snapshot", {})
	if not _assert_campaign_outcome_snapshot(outcome_snapshot, campaign_id, scenario_id, "defeat", false):
		return false
	if not _require(_campaign_next_action_id(outcome_snapshot, scenario_id) == "", "Campaign defeat outcome exposed an unlocked next-chapter action.", outcome_snapshot):
		return false

	var outcome_resume := await _save_and_resume_outcome_from_main_menu(outcome, manual_slot, "defeat", "campaign_defeat_outcome")
	if not bool(outcome_resume.get("ok", false)):
		return false
	outcome = outcome_resume.get("outcome", outcome)
	var resumed_outcome_snapshot: Dictionary = outcome.call("validation_snapshot")
	if not _assert_campaign_outcome_snapshot(resumed_outcome_snapshot, campaign_id, scenario_id, "defeat", false):
		return false
	if not _require(_campaign_next_action_id(resumed_outcome_snapshot, scenario_id) == "", "Campaign defeat outcome save/resume exposed an unlocked next-chapter action.", resumed_outcome_snapshot):
		return false

	var outcome_action: Dictionary = outcome.call("validation_perform_action", "return_to_menu")
	if not _require(bool(outcome_action.get("ok", false)), "Campaign defeat return-to-menu follow-up failed through the shipped outcome action row.", outcome_action):
		return false
	var final_menu = await _wait_for_scene(MAIN_MENU_SCENE, 10000)
	if final_menu == null:
		return _fail("Campaign defeat return-to-menu action did not reach the main menu.", outcome_action)
	await _settle_frames(8)

	var latest_summary := SaveService.latest_loadable_summary()
	if not _assert_campaign_save_summary(
		latest_summary,
		"Campaign defeat latest save after outcome action",
		scenario_id,
		campaign_id,
		"defeat",
		"outcome"
	):
		return false
	final_menu.call("validation_open_campaign_stage")
	await _settle_frames(4)
	if not _require(
		bool(final_menu.call("validation_select_campaign", campaign_id)),
		"Campaign browser could not reselect the defeated campaign after outcome return.",
		final_menu.call("validation_snapshot")
	):
		return false
	await _settle_frames(4)
	if not _require(
		bool(final_menu.call("validation_select_campaign_chapter", scenario_id)),
		"Campaign browser could not reselect the defeated chapter after outcome return.",
		final_menu.call("validation_snapshot")
	):
		return false
	await _settle_frames(4)
	var browser_snapshot: Dictionary = final_menu.call("validation_snapshot")
	var browser_chapter_details := String(browser_snapshot.get("chapter_details_full", browser_snapshot.get("chapter_details", "")))
	var expected_defeat_summary := _scenario_resolution_text(scenario_id, "defeat")
	if not _require("Last result" in browser_chapter_details, "Campaign browser did not show the recorded defeat result after outcome return.", browser_snapshot):
		return false
	if expected_defeat_summary != "" and not _require(expected_defeat_summary in browser_chapter_details, "Campaign browser did not preserve the authored defeat summary after outcome return.", browser_snapshot):
		return false
	if not _require("Retry" in String(browser_snapshot.get("chapter_details", "")), "Campaign browser did not expose retry semantics for the defeated chapter.", browser_snapshot):
		return false
	browser_snapshot["outcome_action"] = outcome_action
	browser_snapshot["latest_save_summary"] = latest_summary
	browser_snapshot["previous_outcome_signature"] = _outcome_resume_signature(resumed_outcome_snapshot)
	_capture_step(CAMPAIGN_DEFEAT_OUTCOME_MENU_ACTION_STEP_ID, browser_snapshot)
	return true

func _save_and_resume_campaign_overworld_from_main_menu(
	overworld,
	manual_slot: int,
	scenario_id: String,
	campaign_id: String,
	step_prefix: String
) -> Dictionary:
	var save_step_id := CAMPAIGN_NEXT_CHAPTER_SAVE_STEP_ID if step_prefix == "campaign_next_chapter" else "%s_saved" % step_prefix
	var menu_return_step_id := CAMPAIGN_NEXT_CHAPTER_MENU_RETURN_STEP_ID if step_prefix == "campaign_next_chapter" else "main_menu_after_%s_return" % step_prefix
	var resume_step_id := CAMPAIGN_NEXT_CHAPTER_RESUME_STEP_ID if step_prefix == "campaign_next_chapter" else "%s_resumed" % step_prefix
	if not _require(
		bool(overworld.call("validation_select_save_slot", manual_slot)),
		"Campaign downstream overworld could not select the requested manual save slot.",
		{
			"manual_slot": manual_slot,
			"overworld_snapshot": overworld.call("validation_snapshot"),
		}
	):
		return {"ok": false}
	await _settle_frames(3)

	var overworld_save: Dictionary = overworld.call("validation_save_to_selected_slot")
	var overworld_save_summary := _dictionary_value(overworld_save.get("summary", {}))
	if not _require(bool(overworld_save.get("ok", false)), "Campaign downstream overworld could not write a manual save from the shipped shell.", overworld_save):
		return {"ok": false}
	if not _require(int(overworld_save.get("selected_slot", 0)) == manual_slot, "Campaign downstream overworld saved into the wrong manual slot.", overworld_save):
		return {"ok": false}
	if not _assert_campaign_save_summary(
		overworld_save_summary,
		"Campaign downstream manual save",
		scenario_id,
		campaign_id,
		"in_progress",
		"overworld"
	):
		return {"ok": false}
	await _settle_frames(6)

	var overworld_saved_snapshot: Dictionary = overworld.call("validation_snapshot")
	overworld_saved_snapshot["manual_save"] = overworld_save
	_capture_step(save_step_id, overworld_saved_snapshot)
	var expected_resume_signature := _campaign_carryover_signature(overworld_saved_snapshot)

	var overworld_menu_return: Dictionary = overworld.call("validation_return_to_menu")
	if not _require(bool(overworld_menu_return.get("ok", false)), "Campaign downstream overworld could not return to the main menu through the live router.", overworld_menu_return):
		return {"ok": false}
	var menu = await _wait_for_scene(MAIN_MENU_SCENE, 10000)
	if menu == null:
		_fail("Returning to menu after the downstream campaign save did not reach the main menu scene.", overworld_menu_return)
		return {"ok": false}
	await _settle_frames(8)

	var latest_summary_after_menu_return := SaveService.latest_loadable_summary()
	if not _assert_campaign_save_summary(
		latest_summary_after_menu_return,
		"Latest campaign downstream save after menu return",
		scenario_id,
		campaign_id,
		"in_progress",
		"overworld"
	):
		return {"ok": false}
	var menu_after_return_snapshot: Dictionary = menu.call("validation_snapshot")
	menu_after_return_snapshot["menu_return"] = overworld_menu_return
	menu_after_return_snapshot["latest_save_summary"] = latest_summary_after_menu_return
	_capture_step(menu_return_step_id, menu_after_return_snapshot)

	menu.call("validation_open_saves_stage")
	await _settle_frames(4)
	if not _require(
		bool(menu.call("validation_select_save_summary", "manual", str(manual_slot))),
		"Main menu save browser could not select the downstream campaign manual save.",
		menu.call("validation_snapshot")
	):
		return {"ok": false}
	await _settle_frames(4)

	var overworld_resume: Dictionary = menu.call("validation_resume_selected_save")
	if not _require(bool(overworld_resume.get("ok", false)), "Main menu resume did not restore the selected downstream campaign save.", overworld_resume):
		return {"ok": false}
	var resumed_overworld = await _wait_for_scene(OVERWORLD_SCENE, 10000)
	if resumed_overworld == null:
		_fail("Resuming the downstream campaign save did not route back into the overworld scene.", overworld_resume)
		return {"ok": false}
	await _settle_frames(6)

	var resumed_snapshot: Dictionary = resumed_overworld.call("validation_snapshot")
	if not _require(String(resumed_snapshot.get("game_state", "")) == "overworld", "Resumed downstream campaign save did not restore overworld state.", resumed_snapshot):
		return {"ok": false}
	var actual_resume_signature := _campaign_carryover_signature(resumed_snapshot)
	if not _require(
		JSON.stringify(actual_resume_signature) == JSON.stringify(expected_resume_signature),
		"Downstream campaign manual save/resume did not preserve imported carryover state.",
		{
			"expected": expected_resume_signature,
			"actual": actual_resume_signature,
		}
	):
		return {"ok": false}
	resumed_snapshot["resume"] = overworld_resume
	_capture_step(resume_step_id, resumed_snapshot)
	return {
		"ok": true,
		"overworld": resumed_overworld,
		"snapshot": resumed_snapshot,
	}

func _launch_skirmish_baseline_from_campaign_overworld(overworld, scenario_id: String, campaign_id: String) -> Dictionary:
	var menu_return: Dictionary = overworld.call("validation_return_to_menu")
	if not _require(bool(menu_return.get("ok", false)), "Resumed downstream campaign overworld could not return to menu before skirmish contrast.", menu_return):
		return {"ok": false}
	var menu = await _wait_for_scene(MAIN_MENU_SCENE, 10000)
	if menu == null:
		_fail("Returning to menu before downstream skirmish contrast did not reach the main menu.", menu_return)
		return {"ok": false}
	await _settle_frames(8)

	var latest_summary := SaveService.latest_loadable_summary()
	if not _assert_campaign_save_summary(
		latest_summary,
		"Latest campaign downstream save before skirmish contrast",
		scenario_id,
		campaign_id,
		"in_progress",
		"overworld"
	):
		return {"ok": false}
	var menu_snapshot: Dictionary = menu.call("validation_snapshot")
	menu_snapshot["menu_return"] = menu_return
	menu_snapshot["latest_save_summary"] = latest_summary
	_capture_step("main_menu_after_campaign_next_chapter_resume_return", menu_snapshot)

	menu.call("validation_open_skirmish_stage")
	await _settle_frames(4)
	if not _require(
		bool(menu.call("validation_select_skirmish", scenario_id)),
		"Downstream chapter was not available for fresh skirmish contrast through the shipped browser.",
		menu.call("validation_snapshot")
	):
		return {"ok": false}
	if not _require(
		bool(menu.call("validation_set_difficulty", String(_config.get("difficulty", "")))),
		"Requested difficulty was not available for downstream skirmish contrast.",
		menu.call("validation_snapshot")
	):
		return {"ok": false}
	await _settle_frames(4)
	var skirmish_menu_snapshot: Dictionary = menu.call("validation_snapshot")
	_capture_step("main_menu_downstream_skirmish_selected", skirmish_menu_snapshot)

	var launch_result: Dictionary = menu.call("validation_start_selected_skirmish")
	if not _require(bool(launch_result.get("started", false)), "Downstream skirmish contrast launch did not stage a skirmish session.", launch_result):
		return {"ok": false}
	var skirmish_overworld = await _wait_for_scene(OVERWORLD_SCENE, 10000)
	if skirmish_overworld == null:
		_fail("Downstream skirmish contrast did not route into the overworld scene.", launch_result)
		return {"ok": false}
	await _settle_frames(8)

	var skirmish_snapshot: Dictionary = skirmish_overworld.call("validation_snapshot")
	if not _require(String(skirmish_snapshot.get("scenario_id", "")) == scenario_id, "Downstream skirmish contrast launched the wrong scenario.", skirmish_snapshot):
		return {"ok": false}
	if not _require(String(skirmish_snapshot.get("launch_mode", "")) == "skirmish", "Downstream skirmish contrast did not preserve skirmish launch mode.", skirmish_snapshot):
		return {"ok": false}
	if not _require(String(skirmish_snapshot.get("campaign_id", "")) == "", "Fresh skirmish contrast inherited campaign id state.", skirmish_snapshot):
		return {"ok": false}
	if not _require(_dictionary_value(skirmish_snapshot.get("carryover_flags", {})).is_empty(), "Fresh skirmish contrast inherited campaign carryover flags.", skirmish_snapshot):
		return {"ok": false}
	skirmish_snapshot["launch_result"] = launch_result
	return {
		"ok": true,
		"overworld": skirmish_overworld,
		"snapshot": skirmish_snapshot,
	}

func _assert_campaign_downstream_overworld_snapshot(
	snapshot: Dictionary,
	campaign_id: String,
	scenario_id: String,
	previous_scenario_id: String,
	label: String
) -> bool:
	if not _require(String(snapshot.get("scenario_id", "")) == scenario_id, "%s scenario id did not match the downstream chapter." % label, snapshot):
		return false
	if not _require(String(snapshot.get("launch_mode", "")) == "campaign", "%s did not preserve campaign launch mode." % label, snapshot):
		return false
	if not _require(String(snapshot.get("campaign_id", "")) == campaign_id, "%s did not preserve campaign id." % label, snapshot):
		return false
	if not _require(String(snapshot.get("campaign_chapter_label", "")) != "", "%s did not expose campaign chapter metadata." % label, snapshot):
		return false
	if not _require(String(snapshot.get("campaign_previous_scenario_id", "")) == previous_scenario_id, "%s did not record the imported carryover source chapter." % label, snapshot):
		return false
	if not _require(String(snapshot.get("game_state", "")) == "overworld", "%s did not route into an overworld game state." % label, snapshot):
		return false
	var commander := _dictionary_value(snapshot.get("commander_state", {}))
	if not _require(String(commander.get("hero_id", "")) != "", "%s did not expose imported commander state." % label, snapshot):
		return false
	if not _require(not _string_array_value(commander.get("spell_ids", [])).is_empty(), "%s did not expose a real spellbook payload." % label, snapshot):
		return false
	var latest_summary := _dictionary_value(snapshot.get("latest_save_summary", {}))
	return _assert_campaign_save_summary(
		latest_summary,
		"%s latest save" % label,
		scenario_id,
		campaign_id,
		"in_progress",
		"overworld"
	)

func _assert_downstream_carryover_differs_from_skirmish(
	campaign_snapshot: Dictionary,
	skirmish_snapshot: Dictionary,
	previous_scenario_id: String
) -> bool:
	var campaign_signature := _campaign_carryover_signature(campaign_snapshot)
	var skirmish_signature := _campaign_carryover_signature(skirmish_snapshot)
	var campaign_commander := _dictionary_value(campaign_signature.get("commander", {}))
	var skirmish_commander := _dictionary_value(skirmish_signature.get("commander", {}))
	var material_differences: Array[String] = []
	if JSON.stringify(campaign_signature.get("resources", {})) != JSON.stringify(skirmish_signature.get("resources", {})):
		material_differences.append("resources")
	if int(campaign_commander.get("level", 1)) > int(skirmish_commander.get("level", 1)) or int(campaign_commander.get("experience", 0)) > int(skirmish_commander.get("experience", 0)):
		material_differences.append("commander_progression")
	if JSON.stringify(campaign_commander.get("artifact_ids", [])) != JSON.stringify(skirmish_commander.get("artifact_ids", [])):
		material_differences.append("artifacts")
	if JSON.stringify(campaign_commander.get("spell_ids", [])) != JSON.stringify(skirmish_commander.get("spell_ids", [])):
		material_differences.append("spellbook")
	if JSON.stringify(campaign_signature.get("carryover_flags", {})) != JSON.stringify(skirmish_signature.get("carryover_flags", {})):
		material_differences.append("flags")

	var campaign_flags := _dictionary_value(campaign_signature.get("carryover_flags", {}))
	if not _require(not campaign_flags.is_empty(), "Downstream campaign launch did not import any carryover flags.", {"campaign": campaign_signature, "skirmish": skirmish_signature}):
		return false
	if previous_scenario_id == "river-pass" and not _require(bool(campaign_flags.get("carryover_pass_cleared", false)), "River Pass carryover did not import the authored pass-cleared flag.", {"campaign": campaign_signature, "skirmish": skirmish_signature}):
		return false
	if not _require("resources" in material_differences, "Downstream campaign resources did not materially differ from a fresh skirmish launch.", {"campaign": campaign_signature, "skirmish": skirmish_signature, "differences": material_differences}):
		return false
	if previous_scenario_id == "river-pass" and not _require("artifacts" in material_differences, "River Pass artifact carryover did not materially differ from a fresh skirmish launch.", {"campaign": campaign_signature, "skirmish": skirmish_signature, "differences": material_differences}):
		return false
	if not _require(
		"commander_progression" in material_differences or "spellbook" in material_differences or "artifacts" in material_differences,
		"Downstream campaign commander payload did not materially differ from a fresh skirmish launch.",
		{"campaign": campaign_signature, "skirmish": skirmish_signature, "differences": material_differences}
	):
		return false
	return true

func _assert_campaign_outcome_snapshot(
	snapshot: Dictionary,
	campaign_id: String,
	scenario_id: String,
	expected_status: String,
	require_next_action: bool
) -> bool:
	if not _require(String(snapshot.get("scenario_id", "")) == scenario_id, "Campaign outcome scenario id did not match the launched chapter.", snapshot):
		return false
	if not _require(String(snapshot.get("launch_mode", "")) == "campaign", "Campaign outcome did not preserve campaign launch mode.", snapshot):
		return false
	if not _require(String(snapshot.get("scenario_status", "")) == expected_status, "Campaign outcome did not receive the expected result state.", snapshot):
		return false
	if not _require(String(snapshot.get("resume_target", "")) == "outcome", "Campaign outcome did not advertise outcome review semantics.", snapshot):
		return false
	if not _require(expected_status.capitalize() in String(snapshot.get("header", "")), "Campaign outcome header did not surface the expected result state.", snapshot):
		return false
	var progression_summary := String(snapshot.get("progression_summary", ""))
	if not _require("Campaign progress" in progression_summary, "Campaign outcome did not expose campaign progression recap text.", snapshot):
		return false
	if expected_status == "victory":
		if require_next_action:
			if not _require("Next chapter unlocked" in progression_summary, "Campaign victory recap did not report the downstream chapter unlock.", snapshot):
				return false
		elif _campaign_next_scenario_id(campaign_id, scenario_id) == "":
			if not _require("The authored campaign path concludes here" in progression_summary, "Campaign finale victory recap did not state that the authored path concludes.", snapshot):
				return false
	else:
		if not _require("Downstream chapter remains blocked" in progression_summary, "Campaign defeat recap did not report downstream chapter blocking.", snapshot):
			return false
	var campaign_arc_summary := String(snapshot.get("campaign_arc_summary", ""))
	if expected_status == "victory" and not require_next_action and _campaign_next_scenario_id(campaign_id, scenario_id) == "":
		if not _require("Campaign Complete" in campaign_arc_summary, "Campaign finale outcome did not expose campaign-complete arc state.", snapshot):
			return false
	else:
		if not _require("Campaign Arc" in campaign_arc_summary, "Campaign outcome did not expose campaign arc recap text.", snapshot):
			return false
	if expected_status == "defeat" and not _require("must be won before the campaign can close" in campaign_arc_summary, "Campaign defeat arc recap did not state that the chapter must be won.", snapshot):
		return false
	var carryover_summary := String(snapshot.get("carryover_summary", ""))
	if expected_status == "victory":
		if require_next_action:
			if not _require("This victory exports" in carryover_summary, "Campaign victory outcome did not expose the carryover export recap.", snapshot):
				return false
			if not _require("Next chapter import ready" in carryover_summary, "Campaign victory outcome did not expose the downstream carryover import recap.", snapshot):
				return false
		elif _campaign_next_scenario_id(campaign_id, scenario_id) == "":
			if not _require(not ("Next chapter import ready" in carryover_summary), "Campaign finale outcome exposed a downstream carryover import recap.", snapshot):
				return false
	else:
		if not _require("Carryover export is only banked on victory" in carryover_summary, "Campaign defeat outcome did not block carryover export.", snapshot):
			return false
	var aftermath_summary := String(snapshot.get("aftermath_summary", ""))
	if expected_status == "defeat":
		var expected_aftermath := _campaign_aftermath_text(campaign_id, scenario_id, "defeat")
		if expected_aftermath != "":
			if not _require(expected_aftermath in aftermath_summary, "Campaign defeat outcome did not expose the authored defeat aftermath.", snapshot):
				return false
		elif not _require(aftermath_summary != "", "Campaign defeat outcome did not expose any defeat aftermath.", snapshot):
			return false
	var journal_summary := String(snapshot.get("journal_summary", ""))
	if expected_status == "victory":
		if not _require("Victory" in journal_summary, "Campaign outcome did not expose the campaign chronicle victory entry.", snapshot):
			return false
	else:
		if not _require("Setback" in journal_summary, "Campaign defeat outcome did not expose the campaign chronicle setback entry.", snapshot):
			return false
	var action_ids := _string_array_value(snapshot.get("action_ids", []))
	if not _require("campaign_start:%s" % scenario_id in action_ids, "Campaign outcome did not offer the real campaign replay action.", snapshot):
		return false
	if require_next_action and not _require(_campaign_next_action_id(snapshot, scenario_id) != "", "Campaign outcome did not offer the real campaign next-chapter action.", snapshot):
		return false
	if not require_next_action and not _require(_campaign_next_action_id(snapshot, scenario_id) == "", "Campaign outcome offered a next-chapter action when none should be available.", snapshot):
		return false
	if not _require("return_to_menu" in action_ids, "Campaign outcome did not offer the return-to-menu action.", snapshot):
		return false
	for action_id in action_ids:
		if not _require(not String(action_id).begins_with("skirmish_start:"), "Campaign outcome leaked a skirmish retry action into campaign follow-ups.", snapshot):
			return false
	var latest_summary := _dictionary_value(snapshot.get("latest_save_summary", {}))
	return _assert_campaign_save_summary(
		latest_summary,
		"Campaign outcome autosave",
		scenario_id,
		campaign_id,
		expected_status,
		"outcome"
	)

func _assert_campaign_save_summary(
	summary: Dictionary,
	label: String,
	scenario_id: String,
	campaign_id: String,
	expected_status: String = "",
	expected_resume_target: String = ""
) -> bool:
	if not _require(not summary.is_empty(), "%s was unavailable." % label, summary):
		return false
	if not _require(String(summary.get("scenario_id", "")) == scenario_id, "%s scenario id did not match the expected chapter." % label, summary):
		return false
	if not _require(String(summary.get("launch_mode", "")) == "campaign", "%s did not advertise campaign launch mode." % label, summary):
		return false
	if not _require(String(summary.get("saved_from_launch_mode", summary.get("launch_mode", ""))) == "campaign", "%s did not preserve saved-from campaign launch mode." % label, summary):
		return false
	if not _require(String(summary.get("campaign_id", "")) == campaign_id, "%s campaign id did not match the launched campaign." % label, summary):
		return false
	if not _require(String(summary.get("campaign_name", "")) != "", "%s did not expose the campaign name." % label, summary):
		return false
	if not _require(String(summary.get("chapter_label", "")) != "", "%s did not expose the campaign chapter label." % label, summary):
		return false
	if expected_status != "" and not _require(String(summary.get("scenario_status", "")) == expected_status, "%s did not preserve %s status." % [label, expected_status], summary):
		return false
	if expected_resume_target != "" and not _require(String(summary.get("resume_target", "")) == expected_resume_target, "%s did not preserve %s resume semantics." % [label, expected_resume_target], summary):
		return false
	return true

func _assert_campaign_finale_outcome_snapshot(snapshot: Dictionary, campaign_id: String, scenario_id: String) -> bool:
	if not _assert_campaign_outcome_snapshot(snapshot, campaign_id, scenario_id, "victory", false):
		return false
	var campaign := ContentService.get_campaign(campaign_id)
	var completion_title := String(campaign.get("completion_title", ""))
	var completion_summary := String(campaign.get("completion_summary", ""))
	var progression_summary := String(snapshot.get("progression_summary", ""))
	if not _require(not ("Next chapter unlocked" in progression_summary), "Campaign finale progression recap exposed a bogus next-chapter unlock.", snapshot):
		return false
	var campaign_arc_summary := String(snapshot.get("campaign_arc_summary", ""))
	if completion_title != "" and not _require(completion_title in campaign_arc_summary, "Campaign finale arc recap did not surface the authored completion title.", snapshot):
		return false
	if completion_summary != "" and not _require(completion_summary in campaign_arc_summary, "Campaign finale arc recap did not surface the authored completion summary.", snapshot):
		return false
	if not _require("closes the authored campaign route" in campaign_arc_summary, "Campaign finale arc recap fell back to generic chapter-only copy.", snapshot):
		return false
	if not _require("Final command snapshot" in campaign_arc_summary, "Campaign finale arc recap did not expose the closing command snapshot.", snapshot):
		return false
	var action_ids := _string_array_value(snapshot.get("action_ids", []))
	for action_id in action_ids:
		if String(action_id).begins_with("campaign_start:") and String(action_id) != "campaign_start:%s" % scenario_id:
			return _require(false, "Campaign finale outcome exposed an extra next-chapter campaign action.", snapshot)
	if not _require(not _outcome_completion_action(snapshot).is_empty(), "Campaign finale outcome did not expose the disabled campaign-complete action.", snapshot):
		return false
	return true

func _assert_campaign_completed_browser_snapshot(snapshot: Dictionary, campaign_id: String, final_scenario_id: String) -> bool:
	if not _require(String(snapshot.get("selected_campaign_id", "")) == campaign_id, "Campaign browser did not keep the completed campaign selected.", snapshot):
		return false
	if not _require(String(snapshot.get("selected_campaign_scenario_id", "")) == final_scenario_id, "Campaign browser did not select the completed finale chapter.", snapshot):
		return false
	var campaign := ContentService.get_campaign(campaign_id)
	var completion_title := String(campaign.get("completion_title", ""))
	var completion_summary := String(campaign.get("completion_summary", ""))
	var campaign_details := String(snapshot.get("campaign_details_full", snapshot.get("campaign_details", "")))
	var campaign_arc_status := String(snapshot.get("campaign_arc_status_full", snapshot.get("campaign_arc_status", "")))
	var chapter_details := String(snapshot.get("chapter_details_full", snapshot.get("chapter_details", "")))
	if not _require("Completed" in campaign_details, "Campaign browser details did not reflect the completed arc state.", snapshot):
		return false
	if not _require("Campaign finale secured" in campaign_details, "Campaign browser details did not identify the secured finale.", snapshot):
		return false
	if completion_title != "" and not _require(completion_title in campaign_details, "Campaign browser details did not surface the authored completion title.", snapshot):
		return false
	if not _require(not ("Next chapter:" in campaign_details), "Campaign browser details still advertised a next chapter after campaign completion.", snapshot):
		return false
	if not _require("Campaign Complete" in campaign_arc_status, "Campaign browser arc status did not show campaign-complete state.", snapshot):
		return false
	if completion_title != "" and not _require(completion_title in campaign_arc_status, "Campaign browser arc status did not surface the authored completion title.", snapshot):
		return false
	if completion_summary != "" and not _require(completion_summary in campaign_arc_status, "Campaign browser arc status did not surface the authored completion summary.", snapshot):
		return false
	if not _require("Closing command snapshot" in campaign_arc_status, "Campaign browser arc status did not keep the closing command snapshot.", snapshot):
		return false
	if not _require("Completed" in chapter_details and "Replay" in chapter_details, "Campaign browser finale chapter did not expose completed replay semantics.", snapshot):
		return false
	var primary_action := _dictionary_value(snapshot.get("primary_campaign_action", {}))
	if not _assert_campaign_replay_action(primary_action, final_scenario_id, "Completed campaign primary action"):
		return false
	var selected_action := _dictionary_value(snapshot.get("selected_chapter_action", {}))
	if not _assert_campaign_replay_action(selected_action, final_scenario_id, "Completed campaign selected finale action"):
		return false
	var latest_summary := _dictionary_value(snapshot.get("latest_save_summary", {}))
	return _assert_campaign_save_summary(
		latest_summary,
		"Completed campaign browser latest save",
		final_scenario_id,
		campaign_id,
		"victory",
		"outcome"
	)

func _assert_campaign_replay_action(action: Dictionary, scenario_id: String, label: String) -> bool:
	if not _require(not action.is_empty(), "%s was unavailable." % label, action):
		return false
	if not _require(String(action.get("scenario_id", "")) == scenario_id, "%s did not target the completed finale scenario." % label, action):
		return false
	if not _require(not bool(action.get("disabled", false)), "%s was disabled for a completed finale replay." % label, action):
		return false
	if not _require(String(action.get("label", "")).begins_with("Replay"), "%s did not expose replay semantics." % label, action):
		return false
	return true

func _outcome_completion_action(snapshot: Dictionary) -> Dictionary:
	var actions = snapshot.get("actions", [])
	if not (actions is Array):
		return {}
	for action in actions:
		if not (action is Dictionary):
			continue
		if String(action.get("id", "")) == "" and bool(action.get("disabled", false)) and "Campaign Complete" in String(action.get("label", "")):
			return action.duplicate(true)
	return {}

func _campaign_next_action_id(snapshot: Dictionary, current_scenario_id: String) -> String:
	for action_id in _string_array_value(snapshot.get("action_ids", [])):
		if not action_id.begins_with("campaign_start:"):
			continue
		var scenario_id := action_id.trim_prefix("campaign_start:")
		if scenario_id != "" and scenario_id != current_scenario_id:
			return action_id
	return ""

func _campaign_scenario_entry(campaign_id: String, scenario_id: String) -> Dictionary:
	var campaign := ContentService.get_campaign(campaign_id)
	for entry in campaign.get("scenarios", []):
		if entry is Dictionary and String(entry.get("scenario_id", "")) == scenario_id:
			return entry.duplicate(true)
	return {}

func _campaign_next_scenario_id(campaign_id: String, scenario_id: String) -> String:
	var campaign := ContentService.get_campaign(campaign_id)
	var found_current := false
	for entry in campaign.get("scenarios", []):
		if not (entry is Dictionary):
			continue
		var entry_scenario_id := String(entry.get("scenario_id", ""))
		if found_current:
			return entry_scenario_id
		found_current = entry_scenario_id == scenario_id
	return ""

func _campaign_scenario_ids(campaign_id: String) -> Array[String]:
	var ids: Array[String] = []
	var campaign := ContentService.get_campaign(campaign_id)
	for entry in campaign.get("scenarios", []):
		if not (entry is Dictionary):
			continue
		var scenario_id := String(entry.get("scenario_id", ""))
		if scenario_id != "":
			ids.append(scenario_id)
	return ids

func _campaign_aftermath_text(campaign_id: String, scenario_id: String, status: String) -> String:
	var entry := _campaign_scenario_entry(campaign_id, scenario_id)
	var key := "aftermath_victory" if status == "victory" else "aftermath_defeat"
	var authored := String(entry.get(key, ""))
	if authored != "":
		return authored
	return _scenario_resolution_text(scenario_id, status)

func _scenario_resolution_text(scenario_id: String, status: String) -> String:
	var scenario := ContentService.get_scenario(scenario_id)
	var objectives = scenario.get("objectives", {})
	if objectives is Dictionary:
		return String(objectives.get("%s_text" % status, ""))
	return ""

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
		"campaign_id": "campaign_reedfall",
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
		if arg.begins_with("--live-validation-campaign="):
			config["enabled"] = true
			config["campaign_id"] = arg.trim_prefix("--live-validation-campaign=")
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
		"campaign_id": String(_config.get("campaign_id", "")),
		"scenario_id": String(_config.get("scenario_id", "")),
		"current_scenario_id": String(_config.get("scenario_id", "")),
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

func _configured_campaign_id() -> String:
	var configured := String(_config.get("campaign_id", ""))
	if configured != "":
		return configured
	return CampaignRulesScript.get_campaign_id_for_scenario(String(_config.get("scenario_id", "")))

func _set_current_validation_scenario(scenario_id: String) -> void:
	_config["scenario_id"] = scenario_id
	if not _report.is_empty():
		_report["current_scenario_id"] = scenario_id

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

func _fail_with_payload(message: String, payload: Dictionary) -> Dictionary:
	_fail(message, payload)
	return {"ok": false, "message": message, "payload": payload}

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
		"progression_summary": String(snapshot.get("progression_summary", "")),
		"campaign_arc_summary": String(snapshot.get("campaign_arc_summary", "")),
		"carryover_summary": String(snapshot.get("carryover_summary", "")),
		"aftermath_summary": String(snapshot.get("aftermath_summary", "")),
		"journal_summary": String(snapshot.get("journal_summary", "")),
		"action_ids": _string_array_value(snapshot.get("action_ids", [])),
	}

func _campaign_carryover_signature(snapshot: Dictionary) -> Dictionary:
	var commander := _dictionary_value(snapshot.get("commander_state", {}))
	return {
		"scenario_id": String(snapshot.get("scenario_id", "")),
		"difficulty": String(snapshot.get("difficulty", "")),
		"launch_mode": String(snapshot.get("launch_mode", "")),
		"game_state": String(snapshot.get("game_state", "")),
		"day": int(snapshot.get("day", 0)),
		"campaign_id": String(snapshot.get("campaign_id", "")),
		"campaign_chapter_label": String(snapshot.get("campaign_chapter_label", "")),
		"campaign_previous_scenario_id": String(snapshot.get("campaign_previous_scenario_id", "")),
		"resources": _dictionary_value(snapshot.get("resources", {})),
		"carryover_flags": _dictionary_value(snapshot.get("carryover_flags", {})),
		"commander": {
			"hero_id": String(commander.get("hero_id", "")),
			"hero_name": String(commander.get("hero_name", "")),
			"level": int(commander.get("level", 1)),
			"experience": int(commander.get("experience", 0)),
			"next_level_experience": int(commander.get("next_level_experience", 250)),
			"command": _command_signature(commander.get("command", {})),
			"specialties": _string_array_value(commander.get("specialties", [])),
			"spell_ids": _string_array_value(commander.get("spell_ids", [])),
			"artifact_ids": _string_array_value(commander.get("artifact_ids", [])),
			"artifacts": _dictionary_value(commander.get("artifacts", {})),
			"army": _dictionary_value(commander.get("army", {})),
		},
	}

func _command_signature(value: Variant) -> Dictionary:
	var command := _dictionary_value(value)
	return {
		"attack": int(command.get("attack", 0)),
		"defense": int(command.get("defense", 0)),
		"power": int(command.get("power", 0)),
		"knowledge": int(command.get("knowledge", 0)),
	}

func _prefixed_step_id(step_prefix: String, suffix: String) -> String:
	if step_prefix == "" or step_prefix == "outcome":
		if suffix == "saved":
			return DEFAULT_OUTCOME_SAVE_STEP_ID
		if suffix == "resumed":
			return DEFAULT_OUTCOME_RESUME_STEP_ID
		return "outcome_%s" % suffix
	if step_prefix == "defeat_outcome":
		if suffix == "saved":
			return DEFEAT_OUTCOME_SAVE_STEP_ID
		if suffix == "resumed":
			return DEFEAT_OUTCOME_RESUME_STEP_ID
	if step_prefix == "campaign_outcome":
		if suffix == "saved":
			return CAMPAIGN_OUTCOME_SAVE_STEP_ID
		if suffix == "resumed":
			return CAMPAIGN_OUTCOME_RESUME_STEP_ID
	if step_prefix == "campaign_defeat_outcome":
		if suffix == "saved":
			return CAMPAIGN_DEFEAT_OUTCOME_SAVE_STEP_ID
		if suffix == "resumed":
			return CAMPAIGN_DEFEAT_OUTCOME_RESUME_STEP_ID
	return "%s_%s" % [step_prefix, suffix]

func _prefixed_menu_step_id(step_prefix: String, suffix: String) -> String:
	if step_prefix == "" or step_prefix == "outcome":
		match suffix:
			"return":
				return DEFAULT_OUTCOME_MENU_RETURN_STEP_ID
			"action":
				return DEFAULT_OUTCOME_MENU_ACTION_STEP_ID
			_:
				return "main_menu_after_outcome_%s" % suffix
	if step_prefix == "defeat_outcome":
		match suffix:
			"return":
				return DEFEAT_OUTCOME_MENU_RETURN_STEP_ID
			"action":
				return DEFEAT_OUTCOME_MENU_ACTION_STEP_ID
			_:
				return "main_menu_after_defeat_outcome_%s" % suffix
	if step_prefix == "campaign_outcome":
		match suffix:
			"return":
				return CAMPAIGN_OUTCOME_MENU_RETURN_STEP_ID
			_:
				return "main_menu_after_campaign_outcome_%s" % suffix
	if step_prefix == "campaign_defeat_outcome":
		match suffix:
			"return":
				return CAMPAIGN_DEFEAT_OUTCOME_MENU_RETURN_STEP_ID
			"action":
				return CAMPAIGN_DEFEAT_OUTCOME_MENU_ACTION_STEP_ID
			_:
				return "main_menu_after_campaign_defeat_outcome_%s" % suffix
	match suffix:
		"return":
			return "main_menu_after_%s_return" % step_prefix
		"action":
			return "main_menu_after_%s_action" % step_prefix
		_:
			return "main_menu_after_%s_%s" % [step_prefix, suffix]

func _defeat_pressure_step_id(step_prefix: String, suffix: String) -> String:
	if step_prefix == "" or step_prefix == "defeat":
		match suffix:
			"watch_started":
				return "defeat_pressure_watch_started"
			"outcome_entered":
				return "defeat_outcome_entered"
			"battle_interrupt":
				return "defeat_pressure_battle_interrupt"
			"after_battle_interrupt":
				return "overworld_after_defeat_pressure_battle_interrupt"
			_:
				if suffix.begins_with("day_"):
					return "defeat_pressure_day_%s" % suffix.trim_prefix("day_")
				return "defeat_pressure_%s" % suffix
	if step_prefix == "campaign_defeat":
		match suffix:
			"watch_started":
				return "campaign_defeat_pressure_watch_started"
			"outcome_entered":
				return "campaign_defeat_outcome_entered"
			"battle_interrupt":
				return "campaign_defeat_pressure_battle_interrupt"
			"after_battle_interrupt":
				return "overworld_after_campaign_defeat_pressure_battle_interrupt"
			_:
				if suffix.begins_with("day_"):
					return "campaign_defeat_pressure_day_%s" % suffix.trim_prefix("day_")
				return "campaign_defeat_pressure_%s" % suffix
	return "%s_%s" % [step_prefix, suffix]

func _dictionary_value(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _available_recruit_total(snapshot: Dictionary) -> int:
	var recruits := _dictionary_value(snapshot.get("available_recruits", {}))
	var total := 0
	for unit_id in recruits.keys():
		total += max(0, int(recruits.get(unit_id, 0)))
	return total

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
