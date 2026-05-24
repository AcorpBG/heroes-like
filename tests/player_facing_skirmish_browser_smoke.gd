extends Node

const REPORT_ID := "PLAYER_FACING_SKIRMISH_BROWSER_SMOKE"
const AUTHORED_SCENARIO_ID := "river-pass"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var tree := get_tree()
	ContentService.clear_cache()
	ContentService.clear_generated_scenario_drafts()

	var entries := ScenarioSelectRules.build_skirmish_browser_entries()
	var authored_entries := []
	var generated_package_entries := []
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var scenario_id := String(entry.get("scenario_id", ""))
		if ScenarioSelectRules.maps_folder_package_id_is_valid(scenario_id):
			generated_package_entries.append(entry)
		elif String(entry.get("source_kind", "")) == "authored_scenario":
			authored_entries.append(entry)
	if authored_entries.size() < 16:
		_fail("Skirmish browser did not expose all active authored skirmish fronts: %d." % authored_entries.size())
		return
	if not _has_browser_entry(authored_entries, AUTHORED_SCENARIO_ID):
		_fail("Skirmish browser missed authored front %s." % AUTHORED_SCENARIO_ID)
		return

	var setup: Dictionary = ScenarioSelectRules.build_skirmish_setup(AUTHORED_SCENARIO_ID, "normal")
	if setup.is_empty() or String(setup.get("scenario_id", "")) != AUTHORED_SCENARIO_ID:
		_fail("Authored skirmish setup did not launch from the browser id: %s." % JSON.stringify(setup))
		return
	if String(setup.get("launch_handoff", "")).find("Skirmish") < 0 or String(setup.get("briefing_check", "")).find("Opening briefing") < 0:
		_fail("Authored skirmish setup missed launch/briefing evidence: %s." % JSON.stringify(setup))
		return

	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	shell.call("validation_open_skirmish_stage")
	await get_tree().process_frame
	if not bool(shell.call("validation_select_skirmish", AUTHORED_SCENARIO_ID)):
		_fail("Main menu could not select authored skirmish front %s." % AUTHORED_SCENARIO_ID)
		return
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var selected_setup: Dictionary = snapshot.get("selected_skirmish_setup", {}) if snapshot.get("selected_skirmish_setup", {}) is Dictionary else {}
	if String(snapshot.get("selected_skirmish_id", "")) != AUTHORED_SCENARIO_ID:
		_fail("Main menu selected skirmish id did not persist: %s." % JSON.stringify(snapshot))
		return
	if String(selected_setup.get("scenario_id", "")) != AUTHORED_SCENARIO_ID:
		_fail("Main menu selected setup did not resolve authored skirmish: %s." % JSON.stringify(selected_setup))
		return
	if not shell.has_method("validation_start_selected_skirmish"):
		_fail("Main menu is missing selected skirmish launch validation hook.")
		return
	var launch_result: Dictionary = shell.call("validation_start_selected_skirmish")
	if not bool(launch_result.get("started", false)):
		_fail("Selected authored skirmish did not start a Skirmish-mode session: %s." % JSON.stringify(launch_result))
		return
	if String(launch_result.get("active_scenario_id", "")) != AUTHORED_SCENARIO_ID:
		_fail("Started skirmish session scenario is wrong: %s." % JSON.stringify(launch_result))
		return
	if String(launch_result.get("active_launch_mode", "")) != SessionState.LAUNCH_MODE_SKIRMISH:
		_fail("Started skirmish session did not use Skirmish launch mode: %s." % JSON.stringify(launch_result))
		return
	if String(launch_result.get("active_difficulty", "")) != ScenarioSelectRules.default_difficulty_id():
		_fail("Started skirmish session difficulty is wrong: %s." % JSON.stringify(launch_result))
		return
	var save_summary := _autosave_started_skirmish_session()
	if save_summary.is_empty():
		return

	var generated_config := ScenarioSelectRules.build_random_map_player_config(
		"authored-skirmish-browser-boundary-10184",
		"",
		"",
		3,
		"land",
		false,
		"homm3_small",
		ScenarioSelectRules.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
	)
	var generated_setup: Dictionary = ScenarioSelectRules.build_random_map_skirmish_setup(generated_config, "normal")
	var generated_scenario_id := String(generated_setup.get("scenario_id", ""))
	if generated_scenario_id == "" or _has_any_browser_entry(ScenarioSelectRules.build_skirmish_browser_entries(), generated_scenario_id):
		_fail("Generated transient scenario leaked into authored skirmish browser: %s." % generated_scenario_id)
		return
	ContentService.clear_generated_scenario_drafts()

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"authored_entry_count": authored_entries.size(),
		"generated_package_entry_count": generated_package_entries.size(),
		"selected_scenario_id": AUTHORED_SCENARIO_ID,
		"generated_transient_browser_leak": false,
		"launch_started": bool(launch_result.get("started", false)),
		"active_launch_mode": String(launch_result.get("active_launch_mode", "")),
		"active_difficulty": String(launch_result.get("active_difficulty", "")),
		"latest_save_resume_target": String(save_summary.get("resume_target", "")),
		"latest_save_launch_mode": String(save_summary.get("launch_mode", "")),
	})])
	tree.quit(0)

func _autosave_started_skirmish_session() -> Dictionary:
	var save_result: Dictionary = SaveService.save_runtime_autosave_session(SessionState.ensure_active_session())
	if not bool(save_result.get("ok", false)):
		_fail("Started skirmish session could not write a resumable autosave: %s." % JSON.stringify(save_result))
		return {}
	var summary: Dictionary = save_result.get("summary", {}) if save_result.get("summary", {}) is Dictionary else {}
	if summary.is_empty():
		_fail("Started skirmish session autosave did not expose a save summary: %s." % JSON.stringify(save_result))
		return {}
	var latest_summary: Dictionary = SaveService.latest_loadable_summary()
	if String(latest_summary.get("scenario_id", "")) != AUTHORED_SCENARIO_ID:
		_fail("Latest loadable summary did not point at the started skirmish: %s." % JSON.stringify(latest_summary))
		return {}
	if String(summary.get("scenario_id", "")) != AUTHORED_SCENARIO_ID:
		_fail("Skirmish autosave summary scenario id is wrong: %s." % JSON.stringify(summary))
		return {}
	if String(summary.get("launch_mode", "")) != SessionState.LAUNCH_MODE_SKIRMISH or String(summary.get("saved_from_launch_mode", "")) != SessionState.LAUNCH_MODE_SKIRMISH:
		_fail("Skirmish autosave summary did not preserve Skirmish launch mode: %s." % JSON.stringify(summary))
		return {}
	if String(summary.get("resume_target", "")) != "overworld" or String(summary.get("scenario_status", "")) != "in_progress":
		_fail("Skirmish autosave summary did not advertise in-progress overworld resume: %s." % JSON.stringify(summary))
		return {}
	if String(summary.get("campaign_id", "")) != "" or String(summary.get("campaign_name", "")) != "":
		_fail("Skirmish autosave summary leaked campaign metadata: %s." % JSON.stringify(summary))
		return {}
	return summary

func _has_browser_entry(entries: Array, scenario_id: String) -> bool:
	for entry in entries:
		if entry is Dictionary and String(entry.get("scenario_id", "")) == scenario_id:
			return true
	return false

func _has_any_browser_entry(entries: Array, scenario_id: String) -> bool:
	return _has_browser_entry(entries, scenario_id)

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
