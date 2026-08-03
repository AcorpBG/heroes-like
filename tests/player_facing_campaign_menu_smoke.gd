extends Node

const REPORT_ID := "PLAYER_FACING_CAMPAIGN_MENU_SMOKE"
const CAMPAIGN_ID := "campaign_reedfall"
const START_SCENARIO_ID := "river-pass"
const CAMPAIGN_DIFFICULTY := "hard"

var _original_profile := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var tree := get_tree()
	ContentService.clear_cache()
	_original_profile = CampaignProgression.ensure_profile().duplicate(true)
	var clean_profile := CampaignRules.normalize_profile(_original_profile)
	clean_profile["campaign_states"][CAMPAIGN_ID] = {}
	clean_profile["last_campaign_id"] = CAMPAIGN_ID
	clean_profile["last_scenario_id"] = ""
	CampaignProgression.profile = CampaignRules.normalize_profile(clean_profile)
	CampaignProgression.save_profile()
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
	if not shell.has_method("validation_set_campaign_difficulty") or not bool(shell.call("validation_set_campaign_difficulty", CAMPAIGN_DIFFICULTY)):
		_fail("Main menu could not select campaign difficulty %s." % CAMPAIGN_DIFFICULTY)
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
	if String(snapshot.get("selected_campaign_difficulty", "")) != CAMPAIGN_DIFFICULTY or String(snapshot.get("campaign_difficulty_text", "")) != "Warlord":
		_fail("Campaign difficulty selection did not persist in the campaign board: %s." % JSON.stringify(snapshot))
		return
	if bool(snapshot.get("campaign_difficulty_disabled", true)) or String(snapshot.get("campaign_difficulty_tooltip", "")).find("Reduced movement and income") < 0:
		_fail("Campaign difficulty control did not expose the selected pressure consequence: %s." % JSON.stringify(snapshot))
		return
	if bool(primary_action.get("disabled", true)) or String(primary_action.get("scenario_id", "")) != START_SCENARIO_ID:
		_fail("Primary campaign action did not target the opening chapter: %s." % JSON.stringify(primary_action))
		return
	if bool(chapter_action.get("disabled", true)) or String(chapter_action.get("scenario_id", "")) != START_SCENARIO_ID:
		_fail("Selected chapter action did not target the opening chapter: %s." % JSON.stringify(chapter_action))
		return
	var commander_preview := String(snapshot.get("campaign_commander_preview_full", ""))
	var operational_board := String(snapshot.get("campaign_operational_board_full", ""))
	for preview in [commander_preview, operational_board]:
		if preview.find("Campaign difficulty: Warlord") < 0 or preview.find("Reduced movement and income") < 0:
			_fail("Campaign preview did not reflect the selected Warlord pressure: %s." % preview)
			return
	var launch_text := "\n".join([
		String(primary_action.get("summary", "")),
		String(chapter_action.get("summary", "")),
		String(snapshot.get("chapter_details_full", "")),
		String(snapshot.get("start_chapter_tooltip", "")),
	])
	if launch_text.find("Campaign mode at Warlord difficulty") < 0 or launch_text.find("Day 1 at Warlord difficulty") < 0:
		_fail("Campaign launch preview did not reflect the selected Warlord mode/day consequence: %s." % launch_text)
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
	if String(launch_result.get("requested_difficulty", "")) != CAMPAIGN_DIFFICULTY or String(launch_result.get("active_difficulty", "")) != CAMPAIGN_DIFFICULTY:
		_fail("Started campaign session did not preserve selected difficulty: %s." % JSON.stringify(launch_result))
		return
	if String(launch_result.get("active_campaign_name", "")) == "" or String(launch_result.get("active_campaign_chapter_label", "")) == "":
		_fail("Started campaign session missed campaign name or chapter label: %s." % JSON.stringify(launch_result))
		return
	var save_summary := _autosave_started_campaign_session()
	if save_summary.is_empty():
		return

	_restore_original_profile()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"campaign_count": int(snapshot.get("campaign_count", 0)),
		"campaign_id": CAMPAIGN_ID,
		"scenario_id": START_SCENARIO_ID,
		"difficulty": String(launch_result.get("active_difficulty", "")),
		"campaign_board_status": String(snapshot.get("campaign_board_status", "")),
		"primary_action_label": String(primary_action.get("label", "")),
		"chapter_action_label": String(chapter_action.get("label", "")),
		"launch_started": bool(launch_result.get("started", false)),
		"active_launch_mode": String(launch_result.get("active_launch_mode", "")),
		"active_campaign_id": String(launch_result.get("active_campaign_id", "")),
		"latest_save_resume_target": String(save_summary.get("resume_target", "")),
		"latest_save_campaign_id": String(save_summary.get("campaign_id", "")),
	})])
	tree.quit(0)

func _autosave_started_campaign_session() -> Dictionary:
	var save_result: Dictionary = SaveService.save_runtime_autosave_session(SessionState.ensure_active_session())
	if not bool(save_result.get("ok", false)):
		_fail("Started campaign session could not write a resumable autosave: %s." % JSON.stringify(save_result))
		return {}
	var summary: Dictionary = save_result.get("summary", {}) if save_result.get("summary", {}) is Dictionary else {}
	if summary.is_empty():
		_fail("Started campaign session autosave did not expose a save summary: %s." % JSON.stringify(save_result))
		return {}
	var latest_summary: Dictionary = SaveService.latest_loadable_summary()
	if String(latest_summary.get("scenario_id", "")) != START_SCENARIO_ID:
		_fail("Latest loadable summary did not point at the started campaign chapter: %s." % JSON.stringify(latest_summary))
		return {}
	if String(summary.get("scenario_id", "")) != START_SCENARIO_ID:
		_fail("Campaign autosave summary scenario id is wrong: %s." % JSON.stringify(summary))
		return {}
	if String(summary.get("launch_mode", "")) != SessionState.LAUNCH_MODE_CAMPAIGN or String(summary.get("saved_from_launch_mode", "")) != SessionState.LAUNCH_MODE_CAMPAIGN:
		_fail("Campaign autosave summary did not preserve Campaign launch mode: %s." % JSON.stringify(summary))
		return {}
	if String(summary.get("difficulty", "")) != CAMPAIGN_DIFFICULTY or String(latest_summary.get("difficulty", "")) != CAMPAIGN_DIFFICULTY:
		_fail("Campaign autosave summary did not preserve selected difficulty: %s / %s." % [JSON.stringify(summary), JSON.stringify(latest_summary)])
		return {}
	if String(summary.get("resume_target", "")) != "overworld" or String(summary.get("scenario_status", "")) != "in_progress":
		_fail("Campaign autosave summary did not advertise in-progress overworld resume: %s." % JSON.stringify(summary))
		return {}
	if String(summary.get("campaign_id", "")) != CAMPAIGN_ID or String(summary.get("campaign_name", "")) == "" or String(summary.get("chapter_label", "")) == "":
		_fail("Campaign autosave summary missed campaign metadata: %s." % JSON.stringify(summary))
		return {}
	return summary

func _fail(message: String) -> void:
	_restore_original_profile()
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)

func _restore_original_profile() -> void:
	if _original_profile.is_empty():
		return
	CampaignProgression.profile = CampaignRules.normalize_profile(_original_profile)
	CampaignProgression.save_profile()
