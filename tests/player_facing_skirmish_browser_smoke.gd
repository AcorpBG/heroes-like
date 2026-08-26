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
	if not await _validate_native_skirmish_launch_setup(shell, entries):
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

func _validate_native_skirmish_launch_setup(shell: Node, entries: Array) -> bool:
	if entries.size() < 2:
		_fail("Skirmish browser needs at least two fronts for native action navigation.")
		return false
	var launch_row := shell.find_child("SkirmishLaunchRow", true, false) as HBoxContainer
	var previous_button := shell.find_child("PreviousCampaignArc", true, false) as Button
	var next_button := shell.find_child("NextCampaignArc", true, false) as Button
	var difficulty_picker := shell.find_child("DifficultyPicker", true, false) as OptionButton
	var difficulty_label := shell.find_child("SkirmishDifficultyLabel", true, false) as Label
	var start_button := shell.find_child("NextCampaignChapter", true, false) as Button
	var arc_navigation := shell.find_child("CampaignArcNavigation", true, false) as HBoxContainer
	var chapter_navigation := shell.find_child("CampaignChapterNavigation", true, false) as HBoxContainer
	var list := shell.find_child("SkirmishList", true, false) as ItemList
	var intel_toggle := shell.find_child("SkirmishIntelToggle", true, false) as Button
	var intel_row := shell.find_child("SkirmishIntelRow", true, false) as HBoxContainer
	var commander_preview := shell.find_child("SkirmishCommanderPreview", true, false) as Label
	var operational_board := shell.find_child("SkirmishOperationalBoard", true, false) as Label
	var stage := shell.get_node("StageDockPanel") as PanelContainer
	var campaign_launch_row := shell.find_child("CampaignLaunchRow", true, false) as HBoxContainer
	if launch_row == null or previous_button == null or next_button == null or difficulty_picker == null or difficulty_label == null or start_button == null or arc_navigation == null or chapter_navigation == null or list == null or intel_toggle == null or intel_row == null or commander_preview == null or operational_board == null or campaign_launch_row == null:
		_fail("Skirmish browser is missing its native launch row, front, difficulty, or launch controls.")
		return false
	if previous_button.get_parent() != arc_navigation or next_button.get_parent() != arc_navigation or start_button.get_parent() != chapter_navigation or difficulty_label.get_parent() != launch_row or difficulty_picker.get_parent() != launch_row:
		_fail("Skirmish controls left the persistent native action row or compact difficulty rail.")
		return false
	var expected_options: Array = ScenarioSelectRules.build_difficulty_options()
	var expected_difficulty_labels := []
	var expected_difficulty_ids := []
	for option_value in expected_options:
		var option: Dictionary = option_value if option_value is Dictionary else {}
		expected_difficulty_labels.append(String(option.get("label", option.get("id", "Difficulty"))))
		expected_difficulty_ids.append(String(option.get("id", ScenarioSelectRules.default_difficulty_id())))
	var actual_difficulty_labels := []
	var actual_difficulty_ids := []
	for index in range(difficulty_picker.item_count):
		actual_difficulty_labels.append(difficulty_picker.get_item_text(index))
		actual_difficulty_ids.append(String(difficulty_picker.get_item_metadata(index)))
	if not launch_row.is_visible_in_tree() or campaign_launch_row.is_visible_in_tree() or actual_difficulty_labels != expected_difficulty_labels or actual_difficulty_ids != expected_difficulty_ids or difficulty_picker.disabled or start_button.disabled:
		_fail("Skirmish launch row changed visibility, difficulty options, or launch authority.")
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
		SettingsService.call("_set_runtime_window_size", viewport_size)
		await _settle_frames(3)
		if get_window().size != viewport_size or get_tree().root.size != viewport_size:
			SettingsService.call("_set_runtime_window_size", original_window_size)
			await _settle_frames(3)
			_fail("Skirmish disclosure fixture did not reach requested window/root size %s." % viewport_size)
			return false
		var collapsed_snapshot: Dictionary = shell.call("validation_snapshot")
		var collapsed_layout: Dictionary = collapsed_snapshot.get("skirmish_layout", {}) if collapsed_snapshot.get("skirmish_layout", {}) is Dictionary else {}
		var stage_rect := stage.get_global_rect()
		var stage_combined_minimum := stage.get_combined_minimum_size()
		var expected_collapsed_width := maxf(float(viewport_size.x) * 0.733, stage_combined_minimum.x)
		var expected_collapsed_height := maxf(minf(560.0, float(viewport_size.y) * 0.720), stage_combined_minimum.y)
		var previous_rect := previous_button.get_global_rect()
		var next_rect := next_button.get_global_rect()
		var arc_navigation_rect := arc_navigation.get_global_rect()
		var chapter_navigation_rect := chapter_navigation.get_global_rect()
		var launch_row_rect := launch_row.get_global_rect()
		var difficulty_rect := difficulty_picker.get_global_rect()
		var start_rect := start_button.get_global_rect()
		var list_rect := list.get_global_rect()
		var intel_toggle_rect := intel_toggle.get_global_rect()
		if (
			not launch_row.is_visible_in_tree()
			or not previous_button.is_visible_in_tree()
			or not next_button.is_visible_in_tree()
			or not difficulty_picker.is_visible_in_tree()
			or not start_button.is_visible_in_tree()
			or not stage_rect.encloses(launch_row_rect)
			or not stage_rect.encloses(arc_navigation_rect)
			or not stage_rect.encloses(chapter_navigation_rect)
			or not arc_navigation_rect.encloses(previous_rect)
			or not arc_navigation_rect.encloses(next_rect)
			or not chapter_navigation_rect.encloses(start_rect)
			or not launch_row_rect.encloses(difficulty_rect)
			or previous_rect.intersects(next_rect)
			or previous_rect.end.x > next_rect.position.x
			or start_rect.end.y > launch_row_rect.position.y
			or previous_rect.size.x < previous_button.get_combined_minimum_size().x
			or next_rect.size.x < next_button.get_combined_minimum_size().x
			or difficulty_rect.size.x < difficulty_picker.get_combined_minimum_size().x
			or start_rect.size.x < start_button.get_combined_minimum_size().x
			or list_rect.position.y < launch_row_rect.end.y
			or not stage_rect.encloses(intel_toggle_rect)
			or absf(stage_rect.size.x - expected_collapsed_width) > 2.0
			or absf(stage_rect.size.y - expected_collapsed_height) > 2.0
			or bool(collapsed_snapshot.get("skirmish_intel_expanded", true))
			or bool(collapsed_snapshot.get("skirmish_intel_row_visible", true))
			or String(collapsed_snapshot.get("skirmish_intel_toggle_text", "")) != "Show Intel"
			or String(collapsed_layout.get("intel_toggle_text", "")) != "Show Intel"
		):
			SettingsService.call("_set_runtime_window_size", original_window_size)
			await _settle_frames(3)
			_fail("Skirmish native launch row escaped or overlapped its board at %s: %s" % [viewport_size, JSON.stringify({
				"stage": stage_rect,
				"expected_width": expected_collapsed_width,
				"expected_height": expected_collapsed_height,
				"launch": launch_row_rect,
				"arc": arc_navigation_rect,
				"chapter": chapter_navigation_rect,
				"difficulty": difficulty_rect,
				"start": start_rect,
				"list": list_rect,
				"intel_toggle": intel_toggle_rect,
				"collapsed_layout": collapsed_layout,
			})])
			return false
		var disclosure_authority_before := {
			"selected_id": String(collapsed_snapshot.get("selected_skirmish_id", "")),
			"difficulty": String(collapsed_snapshot.get("selected_difficulty", "")),
			"commander": commander_preview.text,
			"commander_full": commander_preview.tooltip_text,
			"operational": operational_board.text,
			"operational_full": operational_board.tooltip_text,
			"items": _skirmish_item_labels(list),
			"tooltips": _skirmish_item_tooltips(list),
		}
		intel_toggle.grab_focus()
		intel_toggle.pressed.emit()
		await _settle_frames(3)
		var expanded_snapshot: Dictionary = shell.call("validation_snapshot")
		var expanded_rect := stage.get_global_rect()
		var expanded_authority := {
			"selected_id": String(expanded_snapshot.get("selected_skirmish_id", "")),
			"difficulty": String(expanded_snapshot.get("selected_difficulty", "")),
			"commander": commander_preview.text,
			"commander_full": commander_preview.tooltip_text,
			"operational": operational_board.text,
			"operational_full": operational_board.tooltip_text,
			"items": _skirmish_item_labels(list),
			"tooltips": _skirmish_item_tooltips(list),
		}
		if (
			not bool(expanded_snapshot.get("skirmish_intel_expanded", false))
			or not bool(expanded_snapshot.get("skirmish_intel_row_visible", false))
			or String(expanded_snapshot.get("skirmish_intel_toggle_text", "")) != "Hide Intel"
			or not intel_row.is_visible_in_tree()
			or get_viewport().gui_get_focus_owner() != intel_toggle
			or expanded_rect.size.y + 1.0 < stage_rect.size.y
			or (viewport_size.x >= 1920 and expanded_rect.size.y < stage_rect.size.y + 200.0)
			or expanded_authority != disclosure_authority_before
		):
			SettingsService.call("_set_runtime_window_size", original_window_size)
			await _settle_frames(3)
			_fail("Skirmish intelligence disclosure changed content, focus, or responsive geometry at %s." % viewport_size)
			return false
		intel_toggle.pressed.emit()
		await _settle_frames(3)
		var restored_snapshot: Dictionary = shell.call("validation_snapshot")
		var restored_rect := stage.get_global_rect()
		if (
			bool(restored_snapshot.get("skirmish_intel_expanded", true))
			or bool(restored_snapshot.get("skirmish_intel_row_visible", true))
			or String(restored_snapshot.get("skirmish_intel_toggle_text", "")) != "Show Intel"
			or not restored_rect.position.is_equal_approx(stage_rect.position)
			or not restored_rect.size.is_equal_approx(stage_rect.size)
			or get_viewport().gui_get_focus_owner() != intel_toggle
		):
			SettingsService.call("_set_runtime_window_size", original_window_size)
			await _settle_frames(3)
			_fail("Skirmish intelligence disclosure did not restore its exact compact state at %s." % viewport_size)
			return false
	SettingsService.call("_set_runtime_window_size", original_window_size)
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
	var initial_difficulty_snapshot: Dictionary = shell.call("validation_snapshot")
	var initial_difficulty := String(initial_difficulty_snapshot.get("selected_difficulty", ""))
	var initial_difficulty_index := difficulty_picker.selected
	var next_difficulty_index := (initial_difficulty_index + 1) % difficulty_picker.item_count
	if next_difficulty_index == initial_difficulty_index:
		_fail("Skirmish native difficulty needs at least two options for public interaction proof.")
		return false
	difficulty_picker.grab_focus()
	difficulty_picker.select(next_difficulty_index)
	difficulty_picker.item_selected.emit(next_difficulty_index)
	await _settle_frames(2)
	var changed_difficulty_snapshot: Dictionary = shell.call("validation_snapshot")
	if String(changed_difficulty_snapshot.get("selected_difficulty", "")) != String(expected_difficulty_ids[next_difficulty_index]) or get_viewport().gui_get_focus_owner() != difficulty_picker:
		_fail("Skirmish public difficulty action did not publish exact selection and focus: %s" % changed_difficulty_snapshot)
		return false
	difficulty_picker.select(initial_difficulty_index)
	difficulty_picker.item_selected.emit(initial_difficulty_index)
	await _settle_frames(2)
	var restored_difficulty_snapshot: Dictionary = shell.call("validation_snapshot")
	if String(restored_difficulty_snapshot.get("selected_difficulty", "")) != initial_difficulty or get_viewport().gui_get_focus_owner() != difficulty_picker:
		_fail("Skirmish public difficulty action did not restore exact selection and focus: %s" % restored_difficulty_snapshot)
		return false
	shell.call("validation_open_campaign_stage")
	await _settle_frames(2)
	if launch_row.is_visible_in_tree() or not campaign_launch_row.is_visible_in_tree():
		_fail("Skirmish launch row remained visible outside the Skirmish stage.")
		return false
	shell.call("validation_open_skirmish_stage")
	await _settle_frames(2)
	if not launch_row.is_visible_in_tree() or campaign_launch_row.is_visible_in_tree():
		_fail("Skirmish launch row did not restore exact stage-only visibility.")
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
