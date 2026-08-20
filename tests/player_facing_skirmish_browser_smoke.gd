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
	_stage("browser_entries_ready")

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
	_stage("menu_scene_ready")
	shell.call("validation_open_skirmish_stage")
	await get_tree().process_frame
	if not await _validate_native_front_navigation(shell, entries):
		return
	_stage("native_navigation_ready")
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
	_stage("authored_launch_ready")
	var save_summary := _autosave_started_skirmish_session()
	if save_summary.is_empty():
		return
	_stage("autosave_ready")

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
	_stage("generated_control_ready")

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

func _stage(stage: String) -> void:
	print("PLAYER_FACING_SKIRMISH_BROWSER_STAGE %s" % JSON.stringify({"ticks_msec": Time.get_ticks_msec(), "stage": stage}))

func _validate_native_front_navigation(shell: Node, entries: Array) -> bool:
	if entries.size() < 2:
		_fail("Skirmish browser needs at least two fronts for native action navigation.")
		return false
	var previous_button := shell.find_child("PreviousSkirmishFront", true, false) as Button
	var next_button := shell.find_child("NextSkirmishFront", true, false) as Button
	var list := shell.find_child("SkirmishList", true, false) as ItemList
	var stage := shell.get_node("StageDockPanel") as PanelContainer
	if previous_button == null or next_button == null or list == null:
		_fail("Skirmish browser is missing native Previous/Next front controls.")
		return false
	var expected_labels := []
	for entry_value in entries:
		var entry: Dictionary = entry_value if entry_value is Dictionary else {}
		expected_labels.append(String(entry.get("label", entry.get("scenario_id", "Scenario"))))
	if _skirmish_item_labels(list) != expected_labels:
		_fail("Native front controls changed the exact Skirmish browser order.")
		return false
	var original_window_size := get_window().size
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = viewport_size
		await _settle_frames(3)
		var stage_rect := stage.get_global_rect()
		var previous_rect := previous_button.get_global_rect()
		var next_rect := next_button.get_global_rect()
		var list_rect := list.get_global_rect()
		if (
			not previous_button.is_visible_in_tree()
			or not next_button.is_visible_in_tree()
			or not stage_rect.encloses(previous_rect)
			or not stage_rect.encloses(next_rect)
			or previous_rect.intersects(next_rect)
			or previous_rect.end.x > next_rect.position.x
			or previous_rect.size.x < previous_button.get_combined_minimum_size().x
			or next_rect.size.x < next_button.get_combined_minimum_size().x
			or list_rect.position.y < maxf(previous_rect.end.y, next_rect.end.y)
		):
			get_window().size = original_window_size
			await _settle_frames(3)
			_fail("Skirmish native front navigation escaped or overlapped its board at %s." % viewport_size)
			return false
	get_window().size = original_window_size
	await _settle_frames(3)

	var session_before = SessionState.active_session
	var settings_before: Dictionary = SettingsService.ensure_settings().duplicate(true)
	var save_cache_before: Dictionary = SaveService.validation_summary_cache_snapshot()
	var generated_before: Dictionary = shell.call("validation_generated_random_map_snapshot")
	var item_tooltips_before := _skirmish_item_tooltips(list)
	var first_id := String((entries[0] as Dictionary).get("scenario_id", ""))
	var second_id := String((entries[1] as Dictionary).get("scenario_id", ""))
	var initial: Dictionary = shell.call("validation_snapshot")
	if (
		String(initial.get("selected_skirmish_id", "")) != first_id
		or int(initial.get("selected_skirmish_index", -1)) != 0
		or bool(initial.get("previous_skirmish_front_enabled", true))
		or not bool(initial.get("next_skirmish_front_enabled", false))
		or String(initial.get("previous_skirmish_front_text", "")) != "Previous Front"
		or String(initial.get("next_skirmish_front_text", "")) != "Next Front"
	):
		_fail("Skirmish native front navigation has the wrong first-row boundary: %s" % initial)
		return false
	previous_button.pressed.emit()
	await _settle_frames(2)
	if String((shell.call("validation_snapshot") as Dictionary).get("selected_skirmish_id", "")) != first_id:
		_fail("Previous Front wrapped before the first Skirmish row.")
		return false
	next_button.grab_focus()
	next_button.pressed.emit()
	await _settle_frames(2)
	var advanced: Dictionary = shell.call("validation_snapshot")
	var advanced_setup: Dictionary = advanced.get("selected_skirmish_setup", {}) if advanced.get("selected_skirmish_setup", {}) is Dictionary else {}
	if (
		String(advanced.get("selected_skirmish_id", "")) != second_id
		or int(advanced.get("selected_skirmish_index", -1)) != 1
		or String(advanced_setup.get("scenario_id", "")) != second_id
		or not bool(advanced.get("previous_skirmish_front_enabled", false))
		or get_viewport().gui_get_focus_owner() != next_button
		or list.get_selected_items() != PackedInt32Array([1])
	):
		_fail("Next Front did not publish the exact adjacent Skirmish setup: %s" % advanced)
		return false
	previous_button.grab_focus()
	previous_button.pressed.emit()
	await _settle_frames(2)
	var returned: Dictionary = shell.call("validation_snapshot")
	if String(returned.get("selected_skirmish_id", "")) != first_id or int(returned.get("selected_skirmish_index", -1)) != 0 or get_viewport().gui_get_focus_owner() != previous_button:
		_fail("Previous Front did not return to the exact first Skirmish setup: %s" % returned)
		return false
	var last_id := String((entries[-1] as Dictionary).get("scenario_id", ""))
	if not bool(shell.call("validation_select_skirmish", last_id)):
		_fail("Could not establish the last Skirmish boundary for native navigation.")
		return false
	var last_snapshot: Dictionary = shell.call("validation_snapshot")
	if not bool(last_snapshot.get("previous_skirmish_front_enabled", false)) or bool(last_snapshot.get("next_skirmish_front_enabled", true)):
		_fail("Skirmish native front navigation has the wrong last-row boundary: %s" % last_snapshot)
		return false
	next_button.pressed.emit()
	await _settle_frames(2)
	if String((shell.call("validation_snapshot") as Dictionary).get("selected_skirmish_id", "")) != last_id:
		_fail("Next Front wrapped after the last Skirmish row.")
		return false
	if not bool(shell.call("validation_select_skirmish", first_id)):
		_fail("Could not restore the first Skirmish row after native navigation.")
		return false
	if (
		SessionState.active_session != session_before
		or SettingsService.ensure_settings() != settings_before
		or SaveService.validation_summary_cache_snapshot() != save_cache_before
		or shell.call("validation_generated_random_map_snapshot") != generated_before
		or _skirmish_item_labels(list) != expected_labels
		or _skirmish_item_tooltips(list) != item_tooltips_before
	):
		_fail("Skirmish native front navigation changed non-selection authority.")
		return false
	return true

func _skirmish_item_labels(list: ItemList) -> Array:
	var labels := []
	for index in range(list.item_count):
		labels.append(list.get_item_text(index))
	return labels

func _skirmish_item_tooltips(list: ItemList) -> Array:
	var tooltips := []
	for index in range(list.item_count):
		tooltips.append(list.get_item_tooltip(index))
	return tooltips

func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await get_tree().process_frame

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
