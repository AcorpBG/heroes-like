extends Node

const REPORT_ID := "PLAYER_FACING_CAMPAIGN_MENU_SMOKE"
const CAMPAIGN_ID := "campaign_reedfall"
const START_SCENARIO_ID := "river-pass"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var tree := get_tree()
	ContentService.clear_cache()
	var campaign_ids: Array = CampaignRules.campaign_ids()
	if CAMPAIGN_ID not in campaign_ids:
		_fail("Reactivated campaign id is not exposed by CampaignProgression: %s." % [campaign_ids])
		return

	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	if not shell.has_method("validation_open_campaign_stage"):
		_fail("Main menu is missing campaign validation stage hook.")
		return
	shell.call("validation_open_campaign_stage")
	await get_tree().process_frame

	if not bool(shell.call("validation_select_campaign", CAMPAIGN_ID)):
		_fail("Main menu could not select the reactivated campaign.")
		return
	if not bool(shell.call("validation_select_campaign_chapter", START_SCENARIO_ID)):
		_fail("Main menu could not select the reactivated opening chapter.")
		return

	var snapshot: Dictionary = shell.call("validation_snapshot")
	var primary_action: Dictionary = snapshot.get("primary_campaign_action", {}) if snapshot.get("primary_campaign_action", {}) is Dictionary else {}
	var chapter_action: Dictionary = snapshot.get("selected_chapter_action", {}) if snapshot.get("selected_chapter_action", {}) is Dictionary else {}
	if String(snapshot.get("campaign_board_status", "")) != "active":
		_fail("Campaign board is not active: %s." % JSON.stringify(snapshot))
		return
	if int(snapshot.get("campaign_count", 0)) < 5:
		_fail("Campaign board did not expose the authored campaign arcs: %s." % JSON.stringify(snapshot))
		return
	if String(snapshot.get("selected_campaign_id", "")) != CAMPAIGN_ID:
		_fail("Campaign selection did not persist in snapshot: %s." % JSON.stringify(snapshot))
		return
	if String(snapshot.get("selected_campaign_scenario_id", "")) != START_SCENARIO_ID:
		_fail("Chapter selection did not persist in snapshot: %s." % JSON.stringify(snapshot))
		return
	if bool(primary_action.get("disabled", true)) or String(primary_action.get("scenario_id", "")) != START_SCENARIO_ID:
		_fail("Primary campaign action did not target the opening chapter: %s." % JSON.stringify(primary_action))
		return
	if bool(chapter_action.get("disabled", true)) or String(chapter_action.get("scenario_id", "")) != START_SCENARIO_ID:
		_fail("Selected chapter action did not target the opening chapter: %s." % JSON.stringify(chapter_action))
		return
	var launch_text := String(chapter_action.get("launch_handoff", "")) + "\n" + String(snapshot.get("start_chapter_tooltip", ""))
	if launch_text.find("Campaign mode") < 0 or launch_text.find("Day 1") < 0:
		_fail("Campaign launch handoff is missing mode/day evidence: %s." % launch_text)
		return
	if not shell.has_method("validation_start_selected_campaign_chapter"):
		_fail("Main menu is missing selected campaign launch validation hook.")
		return
	var launch_result: Dictionary = shell.call("validation_start_selected_campaign_chapter")
	if not bool(launch_result.get("started", false)):
		_fail("Selected campaign chapter did not start a Campaign-mode session: %s." % JSON.stringify(launch_result))
		return
	if String(launch_result.get("active_scenario_id", "")) != START_SCENARIO_ID or String(launch_result.get("active_campaign_id", "")) != CAMPAIGN_ID:
		_fail("Started campaign session identity is wrong: %s." % JSON.stringify(launch_result))
		return
	if String(launch_result.get("active_launch_mode", "")) != SessionState.LAUNCH_MODE_CAMPAIGN:
		_fail("Started campaign session did not use Campaign launch mode: %s." % JSON.stringify(launch_result))
		return
	if String(launch_result.get("active_campaign_name", "")) == "" or String(launch_result.get("active_campaign_chapter_label", "")) == "":
		_fail("Started campaign session missed campaign name or chapter label: %s." % JSON.stringify(launch_result))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"campaign_count": int(snapshot.get("campaign_count", 0)),
		"campaign_id": CAMPAIGN_ID,
		"scenario_id": START_SCENARIO_ID,
		"campaign_board_status": String(snapshot.get("campaign_board_status", "")),
		"primary_action_label": String(primary_action.get("label", "")),
		"chapter_action_label": String(chapter_action.get("label", "")),
		"launch_started": bool(launch_result.get("started", false)),
		"active_launch_mode": String(launch_result.get("active_launch_mode", "")),
		"active_campaign_id": String(launch_result.get("active_campaign_id", "")),
	})])
	tree.quit(0)

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
