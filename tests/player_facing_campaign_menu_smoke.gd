extends Node

const REPORT_ID := "PLAYER_FACING_CAMPAIGN_MENU_SMOKE"
const CAMPAIGN_ID := "campaign_reedfall"
const START_SCENARIO_ID := "river-pass"
const CAMPAIGN_DIFFICULTY := "hard"
const CAMPAIGN_LAYOUT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]

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
	if not await _validate_native_campaign_navigation(shell):
		return
	if not await _validate_native_campaign_launch_setup(shell):
		return

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
	if not bool(snapshot.get("campaign_commander_portrait_visible", false)) \
			or String(snapshot.get("campaign_commander_portrait_path", "")) != "res://art/heroes/portraits/hero_lyra.png" \
			or String(snapshot.get("campaign_commander_portrait_tooltip", "")) != "Lyra Emberwell portrait":
		_fail("Campaign commander portrait did not match the selected authored hero: %s." % JSON.stringify(snapshot))
		return
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
	if not await _validate_scenery_first_campaign_layout(shell, snapshot):
		return
	snapshot = shell.call("validation_snapshot")
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

func _validate_native_campaign_navigation(shell: Control) -> bool:
	var previous_arc := shell.find_child("PreviousCampaignArc", true, false) as Button
	var next_arc := shell.find_child("NextCampaignArc", true, false) as Button
	var previous_chapter := shell.find_child("PreviousCampaignChapter", true, false) as Button
	var next_chapter := shell.find_child("NextCampaignChapter", true, false) as Button
	var campaign_list := shell.find_child("CampaignList", true, false) as ItemList
	var chapter_list := shell.find_child("ChapterList", true, false) as ItemList
	if previous_arc == null or next_arc == null or previous_chapter == null or next_chapter == null or campaign_list == null or chapter_list == null:
		_fail("Campaign board is missing native arc/chapter navigation controls.")
		return false
	var campaign_entries: Array = CampaignProgression.campaign_browser_entries()
	if campaign_entries.size() < 2:
		_fail("Campaign native navigation needs at least two authored arcs.")
		return false
	var campaign_ids := []
	var campaign_labels := []
	for entry_value in campaign_entries:
		var entry: Dictionary = entry_value if entry_value is Dictionary else {}
		campaign_ids.append(String(entry.get("campaign_id", "")))
		campaign_labels.append(String(entry.get("label", entry.get("campaign_id", "Campaign"))))
	if _item_list_labels(campaign_list) != campaign_labels:
		_fail("Campaign native arc controls changed the exact authored arc order.")
		return false
	var first_campaign_id := String(campaign_ids[0])
	var second_campaign_id := String(campaign_ids[1])
	var last_campaign_id := String(campaign_ids[-1])
	if not bool(shell.call("validation_select_campaign", first_campaign_id)):
		_fail("Campaign native navigation could not establish its first arc boundary.")
		return false
	await _settle_frames(2)
	var first_arc: Dictionary = shell.call("validation_snapshot")
	if (
		String(first_arc.get("selected_campaign_id", "")) != first_campaign_id
		or int(first_arc.get("selected_campaign_index", -1)) != 0
		or bool(first_arc.get("previous_campaign_arc_enabled", true))
		or not bool(first_arc.get("next_campaign_arc_enabled", false))
		or String(first_arc.get("previous_campaign_arc_text", "")) != "Previous Arc"
		or String(first_arc.get("next_campaign_arc_text", "")) != "Next Arc"
	):
		_fail("Campaign native arc controls have the wrong first-row boundary: %s" % first_arc)
		return false
	var session_before = SessionState.active_session
	var settings_before: Dictionary = SettingsService.ensure_settings().duplicate(true)
	var save_cache_before: Dictionary = SaveService.validation_summary_cache_snapshot()
	var profile_before_next: Dictionary = CampaignProgression.ensure_profile().duplicate(true)
	previous_arc.pressed.emit()
	await _settle_frames(2)
	if CampaignProgression.ensure_profile() != profile_before_next or String((shell.call("validation_snapshot") as Dictionary).get("selected_campaign_id", "")) != first_campaign_id:
		_fail("Previous Arc wrapped or changed campaign authority before the first row.")
		return false
	next_arc.grab_focus()
	next_arc.pressed.emit()
	await _settle_frames(2)
	var second_arc: Dictionary = shell.call("validation_snapshot")
	var expected_second_profile: Dictionary = CampaignRules.mark_selected_campaign(profile_before_next, second_campaign_id)
	if (
		String(second_arc.get("selected_campaign_id", "")) != second_campaign_id
		or int(second_arc.get("selected_campaign_index", -1)) != 1
		or CampaignProgression.ensure_profile() != expected_second_profile
		or campaign_list.get_selected_items() != PackedInt32Array([1])
		or get_viewport().gui_get_focus_owner() != next_arc
	):
		_fail("Next Arc did not use exact adjacent campaign selection authority: %s" % second_arc)
		return false
	previous_arc.grab_focus()
	previous_arc.pressed.emit()
	await _settle_frames(2)
	var returned_arc: Dictionary = shell.call("validation_snapshot")
	var expected_returned_profile: Dictionary = CampaignRules.mark_selected_campaign(expected_second_profile, first_campaign_id)
	if (
		String(returned_arc.get("selected_campaign_id", "")) != first_campaign_id
		or int(returned_arc.get("selected_campaign_index", -1)) != 0
		or CampaignProgression.ensure_profile() != expected_returned_profile
		or get_viewport().gui_get_focus_owner() != previous_arc
	):
		_fail("Previous Arc did not restore the exact adjacent campaign authority: %s" % returned_arc)
		return false
	if not bool(shell.call("validation_select_campaign", last_campaign_id)):
		_fail("Campaign native navigation could not establish its last arc boundary.")
		return false
	await _settle_frames(2)
	var last_arc: Dictionary = shell.call("validation_snapshot")
	var profile_before_last_noop: Dictionary = CampaignProgression.ensure_profile().duplicate(true)
	if not bool(last_arc.get("previous_campaign_arc_enabled", false)) or bool(last_arc.get("next_campaign_arc_enabled", true)):
		_fail("Campaign native arc controls have the wrong last-row boundary: %s" % last_arc)
		return false
	next_arc.pressed.emit()
	await _settle_frames(2)
	if CampaignProgression.ensure_profile() != profile_before_last_noop or String((shell.call("validation_snapshot") as Dictionary).get("selected_campaign_id", "")) != last_campaign_id:
		_fail("Next Arc wrapped or changed campaign authority after the last row.")
		return false
	if not bool(shell.call("validation_select_campaign", first_campaign_id)):
		_fail("Campaign native navigation could not restore the first arc.")
		return false
	await _settle_frames(2)

	var chapter_entries: Array = CampaignProgression.campaign_chapter_entries(first_campaign_id)
	if chapter_entries.size() < 2:
		_fail("Campaign native navigation needs at least two authored chapters in the first arc.")
		return false
	var chapter_ids := []
	var chapter_labels := []
	for entry_value in chapter_entries:
		var entry: Dictionary = entry_value if entry_value is Dictionary else {}
		chapter_ids.append(String(entry.get("scenario_id", "")))
		chapter_labels.append(String(entry.get("label", entry.get("scenario_id", "Chapter"))))
	if _item_list_labels(chapter_list) != chapter_labels:
		_fail("Campaign native chapter controls changed the exact authored chapter order.")
		return false
	var first_chapter_id := String(chapter_ids[0])
	var second_chapter_id := String(chapter_ids[1])
	var last_chapter_id := String(chapter_ids[-1])
	if not bool(shell.call("validation_select_campaign_chapter", first_chapter_id)):
		_fail("Campaign native navigation could not establish its first chapter boundary.")
		return false
	await _settle_frames(2)
	var first_chapter: Dictionary = shell.call("validation_snapshot")
	if (
		String(first_chapter.get("selected_campaign_scenario_id", "")) != first_chapter_id
		or int(first_chapter.get("selected_campaign_chapter_index", -1)) != 0
		or bool(first_chapter.get("previous_campaign_chapter_enabled", true))
		or not bool(first_chapter.get("next_campaign_chapter_enabled", false))
		or String(first_chapter.get("previous_campaign_chapter_text", "")) != "Previous Chapter"
		or String(first_chapter.get("next_campaign_chapter_text", "")) != "Next Chapter"
	):
		_fail("Campaign native chapter controls have the wrong first-row boundary: %s" % first_chapter)
		return false
	var profile_before_chapter: Dictionary = CampaignProgression.ensure_profile().duplicate(true)
	previous_chapter.pressed.emit()
	await _settle_frames(2)
	if CampaignProgression.ensure_profile() != profile_before_chapter or String((shell.call("validation_snapshot") as Dictionary).get("selected_campaign_scenario_id", "")) != first_chapter_id:
		_fail("Previous Chapter wrapped or changed campaign authority before the first row.")
		return false
	next_chapter.grab_focus()
	next_chapter.pressed.emit()
	await _settle_frames(2)
	var second_chapter: Dictionary = shell.call("validation_snapshot")
	var expected_second_chapter_profile: Dictionary = CampaignRules.mark_selected_scenario(profile_before_chapter, second_chapter_id, first_campaign_id)
	if (
		String(second_chapter.get("selected_campaign_scenario_id", "")) != second_chapter_id
		or int(second_chapter.get("selected_campaign_chapter_index", -1)) != 1
		or CampaignProgression.ensure_profile() != expected_second_chapter_profile
		or chapter_list.get_selected_items() != PackedInt32Array([1])
		or get_viewport().gui_get_focus_owner() != next_chapter
	):
		_fail("Next Chapter did not use exact adjacent chapter selection authority: %s" % second_chapter)
		return false
	previous_chapter.grab_focus()
	previous_chapter.pressed.emit()
	await _settle_frames(2)
	var returned_chapter: Dictionary = shell.call("validation_snapshot")
	var expected_returned_chapter_profile: Dictionary = CampaignRules.mark_selected_scenario(expected_second_chapter_profile, first_chapter_id, first_campaign_id)
	if (
		String(returned_chapter.get("selected_campaign_scenario_id", "")) != first_chapter_id
		or int(returned_chapter.get("selected_campaign_chapter_index", -1)) != 0
		or CampaignProgression.ensure_profile() != expected_returned_chapter_profile
		or get_viewport().gui_get_focus_owner() != previous_chapter
	):
		_fail("Previous Chapter did not restore the exact adjacent chapter authority: %s" % returned_chapter)
		return false
	if not bool(shell.call("validation_select_campaign_chapter", last_chapter_id)):
		_fail("Campaign native navigation could not establish its last chapter boundary.")
		return false
	await _settle_frames(2)
	var last_chapter: Dictionary = shell.call("validation_snapshot")
	var profile_before_last_chapter_noop: Dictionary = CampaignProgression.ensure_profile().duplicate(true)
	if not bool(last_chapter.get("previous_campaign_chapter_enabled", false)) or bool(last_chapter.get("next_campaign_chapter_enabled", true)):
		_fail("Campaign native chapter controls have the wrong last-row boundary: %s" % last_chapter)
		return false
	next_chapter.pressed.emit()
	await _settle_frames(2)
	if CampaignProgression.ensure_profile() != profile_before_last_chapter_noop or String((shell.call("validation_snapshot") as Dictionary).get("selected_campaign_scenario_id", "")) != last_chapter_id:
		_fail("Next Chapter wrapped or changed campaign authority after the last row.")
		return false
	if not bool(shell.call("validation_select_campaign_chapter", first_chapter_id)):
		_fail("Campaign native navigation could not restore the first chapter.")
		return false
	await _settle_frames(2)
	if (
		SessionState.active_session != session_before
		or SettingsService.ensure_settings() != settings_before
		or SaveService.validation_summary_cache_snapshot() != save_cache_before
	):
		_fail("Campaign native arc/chapter navigation changed non-campaign authority.")
		return false
	return true

func _item_list_labels(list: ItemList) -> Array:
	var labels := []
	for index in range(list.item_count):
		labels.append(list.get_item_text(index))
	return labels

func _validate_native_campaign_launch_setup(shell: Control) -> bool:
	var launch_row := shell.find_child("CampaignLaunchRow", true, false) as HBoxContainer
	var difficulty_picker := shell.find_child("CampaignDifficultyPicker", true, false) as OptionButton
	var primary_action := shell.find_child("CampaignPrimaryAction", true, false) as Button
	var start_chapter := shell.find_child("StartChapter", true, false) as Button
	if launch_row == null or difficulty_picker == null or primary_action == null or start_chapter == null:
		_fail("Campaign board is missing its native launch-setup row or controls.")
		return false
	if difficulty_picker.get_parent() != launch_row or primary_action.get_parent() != launch_row or start_chapter.get_parent() != launch_row:
		_fail("Campaign launch controls are not direct children of the compact native launch row.")
		return false
	var expected_options: Array = ScenarioSelectRules.build_difficulty_options()
	var expected_labels := []
	var expected_ids := []
	for option_value in expected_options:
		var option: Dictionary = option_value if option_value is Dictionary else {}
		expected_labels.append(String(option.get("label", option.get("id", "Difficulty"))))
		expected_ids.append(String(option.get("id", ScenarioSelectRules.default_difficulty_id())))
	var actual_labels := []
	var actual_ids := []
	for index in range(difficulty_picker.item_count):
		actual_labels.append(difficulty_picker.get_item_text(index))
		actual_ids.append(String(difficulty_picker.get_item_metadata(index)))
	if not launch_row.is_visible_in_tree() \
			or actual_labels != expected_labels \
			or actual_ids != expected_ids \
			or difficulty_picker.selected < 0 \
			or difficulty_picker.disabled \
			or primary_action.disabled:
		_fail("Campaign launch row changed visibility, difficulty options, or launch authority.")
		return false
	var initial_snapshot: Dictionary = shell.call("validation_snapshot")
	var initial_difficulty := String(initial_snapshot.get("selected_campaign_difficulty", ""))
	var initial_index := difficulty_picker.selected
	var next_index := (initial_index + 1) % difficulty_picker.item_count
	if next_index == initial_index:
		_fail("Campaign launch row needs at least two difficulty options for public native interaction proof.")
		return false
	var authority_before := {
		"profile": CampaignProgression.ensure_profile().duplicate(true),
		"session": SessionState.ensure_active_session().to_dict(),
		"settings": SettingsService.ensure_settings().duplicate(true),
		"save_cache": SaveService.validation_summary_cache_snapshot(),
	}
	difficulty_picker.grab_focus()
	difficulty_picker.select(next_index)
	difficulty_picker.item_selected.emit(next_index)
	await _settle_frames(2)
	var changed_snapshot: Dictionary = shell.call("validation_snapshot")
	if String(changed_snapshot.get("selected_campaign_difficulty", "")) != String(expected_ids[next_index]) \
			or String(changed_snapshot.get("campaign_difficulty_text", "")) != String(expected_labels[next_index]) \
			or get_viewport().gui_get_focus_owner() != difficulty_picker \
			or CampaignProgression.ensure_profile() != authority_before.get("profile", {}) \
			or SessionState.ensure_active_session().to_dict() != authority_before.get("session", {}) \
			or SettingsService.ensure_settings() != authority_before.get("settings", {}) \
			or SaveService.validation_summary_cache_snapshot() != authority_before.get("save_cache", {}):
		_fail("Campaign difficulty public native action changed selection, focus, or unrelated authority: %s" % changed_snapshot)
		return false
	difficulty_picker.select(initial_index)
	difficulty_picker.item_selected.emit(initial_index)
	await _settle_frames(2)
	var restored_snapshot: Dictionary = shell.call("validation_snapshot")
	if String(restored_snapshot.get("selected_campaign_difficulty", "")) != initial_difficulty \
			or String(restored_snapshot.get("campaign_difficulty_text", "")) != String(expected_labels[initial_index]) \
			or get_viewport().gui_get_focus_owner() != difficulty_picker:
		_fail("Campaign difficulty public native action did not restore exact selection and focus: %s" % restored_snapshot)
		return false
	shell.call("validation_open_skirmish_stage")
	await _settle_frames(2)
	if launch_row.is_visible_in_tree():
		_fail("Campaign launch row remained visible outside the Campaign stage.")
		return false
	shell.call("validation_open_campaign_stage")
	await _settle_frames(2)
	if not launch_row.is_visible_in_tree() or String((shell.call("validation_snapshot") as Dictionary).get("selected_campaign_difficulty", "")) != initial_difficulty:
		_fail("Campaign launch row did not restore exact visibility and difficulty after stage return.")
		return false
	return true

func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await get_tree().process_frame

func _validate_scenery_first_campaign_layout(shell: Control, initial_snapshot: Dictionary) -> bool:
	var original_window_size := get_window().size
	var authority_before := {
		"profile": CampaignProgression.ensure_profile().duplicate(true),
		"session": SessionState.ensure_active_session().to_dict(),
		"campaign_id": String(initial_snapshot.get("selected_campaign_id", "")),
		"scenario_id": String(initial_snapshot.get("selected_campaign_scenario_id", "")),
		"difficulty": String(initial_snapshot.get("selected_campaign_difficulty", "")),
		"primary_action": (initial_snapshot.get("primary_campaign_action", {}) as Dictionary).duplicate(true),
		"chapter_action": (initial_snapshot.get("selected_chapter_action", {}) as Dictionary).duplicate(true),
	}
	var expected_campaign_rows := _expected_campaign_rows()
	var expected_chapter_rows := _expected_chapter_rows()
	var intel_toggle := shell.find_child("CampaignIntelToggle", true, false) as Button
	if intel_toggle == null:
		_fail("Campaign rail is missing its contextual Intel disclosure button.")
		return false

	for target_size in CAMPAIGN_LAYOUT_SIZES:
		get_window().size = target_size
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		if get_window().size != target_size:
			_fail("Campaign rail fixture did not reach requested viewport %s: %s." % [target_size, get_window().size])
			return false
		var compact_snapshot: Dictionary = shell.call("validation_snapshot")
		if not _campaign_layout_contract_exact(compact_snapshot, false, expected_campaign_rows, expected_chapter_rows):
			return false
		var compact_layout: Dictionary = compact_snapshot.get("campaign_layout", {}) if compact_snapshot.get("campaign_layout", {}) is Dictionary else {}
		var compact_stage_rect: Dictionary = (compact_layout.get("stage_rect", {}) as Dictionary).duplicate(true)
		if not _campaign_authority_exact(compact_snapshot, authority_before):
			return false

		intel_toggle.grab_focus()
		await get_tree().process_frame
		intel_toggle.emit_signal("pressed")
		await get_tree().process_frame
		await get_tree().process_frame
		var expanded_snapshot: Dictionary = shell.call("validation_snapshot")
		if not _campaign_layout_contract_exact(expanded_snapshot, true, expected_campaign_rows, expected_chapter_rows):
			return false
		if not _campaign_authority_exact(expanded_snapshot, authority_before):
			return false
		if get_viewport().gui_get_focus_owner() != intel_toggle:
			_fail("Campaign Intel disclosure did not retain focus on its immutable toggle action.")
			return false

		intel_toggle.emit_signal("pressed")
		await get_tree().process_frame
		await get_tree().process_frame
		var restored_snapshot: Dictionary = shell.call("validation_snapshot")
		if not _campaign_layout_contract_exact(restored_snapshot, false, expected_campaign_rows, expected_chapter_rows):
			return false
		var restored_layout: Dictionary = restored_snapshot.get("campaign_layout", {}) if restored_snapshot.get("campaign_layout", {}) is Dictionary else {}
		if restored_layout.get("stage_rect", {}) != compact_stage_rect:
			_fail("Hiding Campaign Intel did not restore the exact compact dock rectangle: compact=%s restored=%s" % [JSON.stringify(compact_stage_rect), JSON.stringify(restored_layout.get("stage_rect", {}))])
			return false
		if not _campaign_authority_exact(restored_snapshot, authority_before):
			return false

	if not await _validate_distinct_chapter_action(shell, authority_before):
		return false

	get_window().size = original_window_size
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	return true

func _campaign_layout_contract_exact(snapshot: Dictionary, expanded: bool, expected_campaign_rows: Array, expected_chapter_rows: Array) -> bool:
	var layout: Dictionary = snapshot.get("campaign_layout", {}) if snapshot.get("campaign_layout", {}) is Dictionary else {}
	var detail_visibility: Dictionary = layout.get("detail_surface_visibility", {}) if layout.get("detail_surface_visibility", {}) is Dictionary else {}
	var primary_action: Dictionary = snapshot.get("primary_campaign_action", {}) if snapshot.get("primary_campaign_action", {}) is Dictionary else {}
	var chapter_action: Dictionary = snapshot.get("selected_chapter_action", {}) if snapshot.get("selected_chapter_action", {}) is Dictionary else {}
	var expected_toggle_text := "Hide Intel" if expanded else "Show Intel"
	var height_ratio := float(layout.get("height_ratio", 1.0))
	if not bool(snapshot.get("stage_dock_visible", false)) \
			or int(snapshot.get("current_tab", -1)) != 0 \
			or float(layout.get("width_ratio", 1.0)) > 0.56 \
			or height_ratio > (0.60 if expanded else 0.46) \
			or (expanded and height_ratio < 0.58) \
			or float(layout.get("uncovered_right_ratio", 0.0)) < 0.40 \
			or bool(layout.get("intel_expanded", not expanded)) != expanded \
			or String(layout.get("intel_toggle_text", "")) != expected_toggle_text:
		_fail("Campaign rail did not preserve its scenery-first viewport contract: %s" % JSON.stringify(layout))
		return false
	if primary_action != chapter_action \
			or not bool(snapshot.get("campaign_primary_visible", false)) \
			or bool(snapshot.get("start_chapter_visible", true)) \
			or not bool(snapshot.get("campaign_launch_actions_deduplicated", false)) \
			or not bool(layout.get("launch_row_visible", false)):
		_fail("Campaign rail did not collapse the exact duplicate selected-chapter launch action: %s" % JSON.stringify(snapshot))
		return false
	for key in ["arc", "arc_status", "chapter", "commander", "operational", "journal"]:
		if bool(detail_visibility.get(key, not expanded)) != expanded:
			_fail("Campaign rail detail surface %s did not match contextual disclosure state %s: %s" % [key, expanded, JSON.stringify(detail_visibility)])
			return false
	if (layout.get("campaign_items", []) as Array) != expected_campaign_rows \
			or (layout.get("chapter_items", []) as Array) != expected_chapter_rows:
		_fail("Campaign rail changed ordered arc/chapter row identity or full tooltips: %s" % JSON.stringify(layout))
		return false
	if not expanded and not _visible_campaign_controls_contained(layout):
		return false
	var control_rects: Dictionary = layout.get("control_rects", {}) if layout.get("control_rects", {}) is Dictionary else {}
	for required_control in ["CampaignLaunchRow", "CampaignDifficultyPicker", "CampaignPrimaryAction"]:
		if not control_rects.has(required_control):
			_fail("Campaign compact launch row omitted visible bounded control %s: %s" % [required_control, JSON.stringify(control_rects)])
			return false
	return true

func _validate_distinct_chapter_action(shell: Control, authority_before: Dictionary) -> bool:
	var distinct_scenario_id := ""
	for row_value in _expected_chapter_rows():
		var row: Dictionary = row_value if row_value is Dictionary else {}
		var scenario_id := String(row.get("id", ""))
		if scenario_id != "" and scenario_id != START_SCENARIO_ID:
			distinct_scenario_id = scenario_id
			break
	if distinct_scenario_id == "":
		_fail("Campaign action deduplication fixture has no distinct authored chapter.")
		return false
	var expected_distinct_profile: Dictionary = CampaignRules.mark_selected_scenario(
		authority_before.get("profile", {}),
		distinct_scenario_id,
		CAMPAIGN_ID
	)
	if not bool(shell.call("validation_select_campaign_chapter", distinct_scenario_id)):
		_fail("Campaign action deduplication fixture could not select distinct chapter %s." % distinct_scenario_id)
		return false
	await get_tree().process_frame
	await get_tree().process_frame
	var distinct_snapshot: Dictionary = shell.call("validation_snapshot")
	var distinct_primary: Dictionary = distinct_snapshot.get("primary_campaign_action", {}) if distinct_snapshot.get("primary_campaign_action", {}) is Dictionary else {}
	var distinct_chapter: Dictionary = distinct_snapshot.get("selected_chapter_action", {}) if distinct_snapshot.get("selected_chapter_action", {}) is Dictionary else {}
	if String(distinct_snapshot.get("selected_campaign_scenario_id", "")) != distinct_scenario_id \
			or distinct_primary != authority_before.get("primary_action", {}) \
			or distinct_chapter == distinct_primary \
			or not bool(distinct_snapshot.get("start_chapter_visible", false)) \
			or bool(distinct_snapshot.get("campaign_launch_actions_deduplicated", true)) \
			or not bool(distinct_snapshot.get("start_chapter_disabled", false)):
		_fail("Distinct locked chapter did not restore its exact selected-chapter affordance: %s" % JSON.stringify(distinct_snapshot))
		return false
	var distinct_layout: Dictionary = distinct_snapshot.get("campaign_layout", {}) if distinct_snapshot.get("campaign_layout", {}) is Dictionary else {}
	var distinct_rects: Dictionary = distinct_layout.get("control_rects", {}) if distinct_layout.get("control_rects", {}) is Dictionary else {}
	if not distinct_rects.has("StartChapter") or not _visible_campaign_controls_contained(distinct_layout):
		_fail("Distinct selected-chapter action is not contained in the compact launch row: %s" % JSON.stringify(distinct_layout))
		return false
	if CampaignProgression.ensure_profile().duplicate(true) != expected_distinct_profile \
			or SessionState.ensure_active_session().to_dict() != authority_before.get("session", {}):
		_fail("Distinct chapter selection did not preserve exact selection-only profile and session authority.")
		return false
	if not bool(shell.call("validation_select_campaign_chapter", START_SCENARIO_ID)):
		_fail("Campaign action deduplication fixture could not restore the primary chapter.")
		return false
	await get_tree().process_frame
	await get_tree().process_frame
	var restored_snapshot: Dictionary = shell.call("validation_snapshot")
	if bool(restored_snapshot.get("start_chapter_visible", true)) \
			or not bool(restored_snapshot.get("campaign_launch_actions_deduplicated", false)):
		_fail("Returning to the primary chapter did not restore exact launch-action deduplication: %s" % JSON.stringify(restored_snapshot))
		return false
	if not _campaign_authority_exact(restored_snapshot, authority_before):
		return false
	return true

func _visible_campaign_controls_contained(layout: Dictionary) -> bool:
	var stage: Dictionary = layout.get("stage_rect", {}) if layout.get("stage_rect", {}) is Dictionary else {}
	var controls: Dictionary = layout.get("control_rects", {}) if layout.get("control_rects", {}) is Dictionary else {}
	for control_name in controls:
		var rect: Dictionary = controls[control_name] if controls[control_name] is Dictionary else {}
		if float(rect.get("x", -1.0)) < float(stage.get("x", 0.0)) - 1.0 \
				or float(rect.get("y", -1.0)) < float(stage.get("y", 0.0)) - 1.0 \
				or float(rect.get("right", 1.0e9)) > float(stage.get("right", 0.0)) + 1.0 \
				or float(rect.get("bottom", 1.0e9)) > float(stage.get("bottom", 0.0)) + 1.0:
			_fail("Visible Campaign control %s escaped the bounded rail: stage=%s control=%s" % [control_name, JSON.stringify(stage), JSON.stringify(rect)])
			return false
	return true

func _campaign_authority_exact(snapshot: Dictionary, authority_before: Dictionary) -> bool:
	var current_authority := {
		"profile": CampaignProgression.ensure_profile().duplicate(true),
		"session": SessionState.ensure_active_session().to_dict(),
		"campaign_id": String(snapshot.get("selected_campaign_id", "")),
		"scenario_id": String(snapshot.get("selected_campaign_scenario_id", "")),
		"difficulty": String(snapshot.get("selected_campaign_difficulty", "")),
		"primary_action": (snapshot.get("primary_campaign_action", {}) as Dictionary).duplicate(true),
		"chapter_action": (snapshot.get("selected_chapter_action", {}) as Dictionary).duplicate(true),
	}
	if current_authority != authority_before:
		_fail("Campaign layout disclosure changed campaign/session/action authority: before=%s after=%s" % [JSON.stringify(authority_before), JSON.stringify(current_authority)])
		return false
	return true

func _expected_campaign_rows() -> Array:
	var rows := []
	for entry in CampaignProgression.campaign_browser_entries():
		var campaign_id := String(entry.get("campaign_id", ""))
		rows.append({
			"id": campaign_id,
			"label": String(entry.get("label", campaign_id)),
			"tooltip": "\n".join([
				CampaignProgression.campaign_details(campaign_id),
				CampaignProgression.campaign_arc_status(campaign_id),
			]),
			"selected": campaign_id == CAMPAIGN_ID,
		})
	return rows

func _expected_chapter_rows() -> Array:
	var rows := []
	for entry in CampaignProgression.campaign_chapter_entries(CAMPAIGN_ID):
		var scenario_id := String(entry.get("scenario_id", ""))
		var action := CampaignProgression.chapter_action(CAMPAIGN_ID, scenario_id, CAMPAIGN_DIFFICULTY)
		rows.append({
			"id": scenario_id,
			"label": String(entry.get("label", scenario_id)),
			"tooltip": "\n".join([
				CampaignProgression.chapter_details(CAMPAIGN_ID, scenario_id, CAMPAIGN_DIFFICULTY),
				String(action.get("summary", "")),
			]),
			"selected": scenario_id == START_SCENARIO_ID,
		})
	return rows

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
