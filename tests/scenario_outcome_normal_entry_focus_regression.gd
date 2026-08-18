extends Node

const REPORT_ID := "SCENARIO_OUTCOME_NORMAL_ENTRY_FOCUS_REGRESSION"
const OUTCOME_SCENE := preload("res://scenes/results/ScenarioOutcomeShell.tscn")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const FAILURE_ENV := "HEROES_LIKE_SAVE_FAIL_PHASE"
const AUTOSAVE_PATH := "user://saves/autosave.json"
const MANUAL_SLOT := 2
const MANUAL_PATH := "user://saves/manual_slot_2.json"

var _original_active_session = null
var _original_profile: Dictionary = {}
var _original_selected_slot := 1
var _original_window_size := Vector2i.ZERO
var _original_files: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_capture_original_state()
	get_window().size = Vector2i(1280, 720)
	await _settle()

	var ordinary_rows: Array[Dictionary] = []
	for launch_mode in [SessionState.LAUNCH_MODE_SKIRMISH, SessionState.LAUNCH_MODE_CAMPAIGN]:
		for status in ["victory", "defeat"]:
			var row := await _exercise_ordinary_entry(String(launch_mode), String(status))
			if row.is_empty():
				return
			ordinary_rows.append(row)

	var recovery_row := await _exercise_recovery_and_overwrite()
	if recovery_row.is_empty():
		return

	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"ordinary_rows": ordinary_rows,
		"normal_primary_focus": true,
		"forward_reverse_enabled_cycle": true,
		"real_accept_exactly_once": true,
		"refresh_preserved_dynamic_action": true,
		"outcome_recap_tab_navigation": true,
		"outcome_recap_tab_authority_exact": true,
		"recovery_save_focus": true,
		"overwrite_cancel_text": recovery_row.get("cancel_text", ""),
		"overwrite_origin_restored": true,
		"recovery_recap_tab_after_cancel": recovery_row.get("recap_tab_after_cancel", -1),
		"viewport": recovery_row.get("viewport", {}),
	})])
	get_tree().quit(0)


func _exercise_ordinary_entry(launch_mode: String, status: String) -> Dictionary:
	AppRouter.validation_reset_scenario_outcome_route_state()
	AppRouter.validation_set_scenario_outcome_routing_suppressed(true)
	var viewport_size := Vector2i(1920, 1080) if launch_mode == SessionState.LAUNCH_MODE_CAMPAIGN and status == "victory" else Vector2i(1280, 720)
	get_window().size = viewport_size
	await _settle()
	var session: SessionStateStoreScript.SessionData = _terminal_session(launch_mode, status)
	session = SessionState.set_active_session(session)
	var editor_control := SessionStateStoreScript.SessionData.new()
	editor_control.from_dict(session.to_dict())
	editor_control.flags["editor_working_copy"] = true
	var editor_surface: Dictionary = SaveService.build_in_session_save_surface(editor_control)
	if String(editor_surface.get("menu_button_label", "")) != "Editor":
		return _fail_dictionary("%s/%s detached Map Editor Play Copy control lost its distinct Editor return label." % [launch_mode, status], {
			"menu_button_label": editor_surface.get("menu_button_label", ""),
		})
	var shell = _instantiate_outcome_shell(viewport_size)
	await _settle()

	var entry: Dictionary = shell.validation_outcome_focus_snapshot()
	var save_surface: Dictionary = shell.validation_snapshot()
	if String(save_surface.get("menu_button_label", "")) != "Main Menu":
		return _fail_dictionary("%s/%s ordinary Outcome did not label the active-play route by its Main Menu destination." % [launch_mode, status], {
			"menu_button_label": save_surface.get("menu_button_label", ""),
			"menu_button_tooltip": save_surface.get("menu_button_tooltip", ""),
		})
	var primary_id := String(entry.get("primary_action_id", ""))
	if primary_id == "" \
			or String(entry.get("focused_action_id", "")) != primary_id \
			or String(entry.get("preferred_action_id", "")) != primary_id \
			or not bool(entry.get("focus_inside_outcome", false)) \
			or not bool(entry.get("focus_has_visible_style", false)):
		return _fail_dictionary("%s/%s ordinary Outcome did not focus its enabled authored primary action." % [launch_mode, status], _compact_focus(entry))
	if primary_id not in entry.get("enabled_action_ids", []):
		return _fail_dictionary("%s/%s primary Outcome action was not enabled." % [launch_mode, status], _compact_focus(entry))
	if not _focus_cycle_is_enabled(entry):
		return _fail_dictionary("%s/%s Outcome focus cycle included a disabled control." % [launch_mode, status], _compact_focus(entry))
	if not _outcome_controls_fit(shell):
		return _fail_dictionary("%s/%s Outcome controls overflowed the compact viewport." % [launch_mode, status], _viewport_snapshot(shell))
	var before: Dictionary = session.to_dict()
	var initial_owner := get_viewport().gui_get_focus_owner()
	var tab_row: Dictionary = await _exercise_outcome_recap_tab_navigation(shell, session, initial_owner, launch_mode, status)
	if tab_row.is_empty():
		return {}

	await _press_action("ui_focus_next")
	var next_owner := get_viewport().gui_get_focus_owner()
	if next_owner == null or next_owner == initial_owner or not shell.is_ancestor_of(next_owner):
		return _fail_dictionary("%s/%s forward navigation did not reach another live Outcome control." % [launch_mode, status], {
			"initial": _control_name(initial_owner),
			"next": _control_name(next_owner),
		})
	await _press_action("ui_focus_prev")
	var reverse_owner := get_viewport().gui_get_focus_owner()
	if reverse_owner != initial_owner:
		return _fail_dictionary("%s/%s reverse navigation did not return to the authored primary action." % [launch_mode, status], {
			"expected": _control_name(initial_owner),
			"actual": _control_name(reverse_owner),
		})

	shell.validation_refresh_outcome_focus()
	await _settle()
	var refreshed: Dictionary = shell.validation_outcome_focus_snapshot()
	var refreshed_tabs: Dictionary = shell.validation_outcome_recap_tab_navigation_snapshot()
	if String(refreshed.get("focused_action_id", "")) != primary_id \
			or int(refreshed_tabs.get("active_tab", -1)) != 4 \
			or int(refreshed_tabs.get("change_count", -1)) != 12:
		return _fail_dictionary("%s/%s refresh did not preserve the focused dynamic Outcome action." % [launch_mode, status], _compact_focus(refreshed))

	shell.validation_set_outcome_focus_action_execution_suppressed(true)
	shell.validation_reset_outcome_focus_state()
	await _press_action("ui_accept")
	var accepted: Dictionary = shell.validation_outcome_focus_snapshot()
	var accept_result: Dictionary = accepted.get("last_accept_result", {}) if accepted.get("last_accept_result", {}) is Dictionary else {}
	if int(accepted.get("accept_count", 0)) != 1 \
			or not bool(accept_result.get("suppressed", false)) \
			or bool(accept_result.get("performed", true)) \
			or bool(accept_result.get("routed", true)) \
			or String(accept_result.get("action_id", "")) != primary_id:
		return _fail_dictionary("%s/%s real ui_accept did not invoke exactly one suppressed primary Outcome command." % [launch_mode, status], _compact_focus(accepted))
	if session.to_dict() != before:
		return _fail_dictionary("%s/%s suppressed Outcome accept changed the live session." % [launch_mode, status])
	var router: Dictionary = AppRouter.validation_scenario_outcome_route_snapshot()
	if int(router.get("route_attempt_count", 0)) != 0:
		return _fail_dictionary("%s/%s suppressed Outcome accept attempted a route." % [launch_mode, status], {"route_attempt_count": router.get("route_attempt_count", -1)})

	var row := {
		"launch_mode": launch_mode,
		"status": status,
		"primary_action_id": primary_id,
		"cycle_size": (entry.get("focus_cycle", []) as Array).size(),
		"recap_tabs": tab_row,
		"viewport_size": viewport_size,
	}
	shell.get_parent().queue_free()
	await get_tree().process_frame
	return row


func _exercise_outcome_recap_tab_navigation(
	shell: Control,
	session: SessionStateStoreScript.SessionData,
	entry_focus: Control,
	launch_mode: String,
	status: String
) -> Dictionary:
	if not shell.has_method("validation_reset_outcome_recap_tab_navigation_state") \
			or not shell.has_method("validation_outcome_recap_tab_navigation_snapshot"):
		return _fail_dictionary("%s/%s Outcome recap-tab validation API is missing." % [launch_mode, status])
	var recap_tabs: TabContainer = shell.get_node_or_null("%RecapTabs")
	if recap_tabs == null:
		return _fail_dictionary("%s/%s Outcome is missing RecapTabs." % [launch_mode, status])
	var tab_bar: TabBar = recap_tabs.get_tab_bar()
	if tab_bar == null:
		return _fail_dictionary("%s/%s Outcome is missing the native recap TabBar." % [launch_mode, status])
	var copy_before: Dictionary = _outcome_recap_copy_snapshot(shell)
	var authority_before: Dictionary = _outcome_recap_authority_snapshot(session)
	var reset: Dictionary = shell.validation_reset_outcome_recap_tab_navigation_state()
	var expected_titles := ["Progress", "Arc", "Carry", "After", "Journal"]
	var titles: Array = reset.get("tab_titles", []) if reset.get("tab_titles", []) is Array else []
	var cycle_names: Array = reset.get("focus_cycle_names", []) if reset.get("focus_cycle_names", []) is Array else []
	var tab_bar_name := String(reset.get("tab_bar_name", ""))
	if int(reset.get("active_tab", -1)) != 0 \
			or int(reset.get("tab_count", -1)) != expected_titles.size() \
			or titles != expected_titles \
			or int(reset.get("tab_bar_focus_mode", Control.FOCUS_NONE)) != Control.FOCUS_ALL \
			or String(reset.get("tab_bar_boundary_policy", "")) != "retain" \
			or int(reset.get("tab_bar_occurrences", 0)) != 1 \
			or int(reset.get("focus_cycle_count", -1)) != cycle_names.size() \
			or cycle_names.count(tab_bar_name) != 1:
		return _fail_dictionary("%s/%s Outcome did not expose five recap tabs and one native TabBar in its focus cycle." % [launch_mode, status], reset)

	var traversal_count := 0
	while get_viewport().gui_get_focus_owner() != tab_bar and traversal_count <= cycle_names.size():
		await _press_joypad_button(JOY_BUTTON_RIGHT_SHOULDER)
		traversal_count += 1
	if get_viewport().gui_get_focus_owner() != tab_bar:
		return _fail_dictionary("%s/%s shoulder traversal could not reach the Outcome recap TabBar." % [launch_mode, status], shell.validation_outcome_recap_tab_navigation_snapshot())

	await _press_joypad_button(JOY_BUTTON_DPAD_LEFT)
	var start_boundary: Dictionary = shell.validation_outcome_recap_tab_navigation_snapshot()
	if int(start_boundary.get("active_tab", -1)) != 0 \
			or int(start_boundary.get("change_count", -1)) != 0 \
			or int(start_boundary.get("boundary_retain_count", -1)) != 1 \
			or get_viewport().gui_get_focus_owner() != tab_bar:
		return _fail_dictionary("%s/%s Outcome recap tabs wrapped left from Progress." % [launch_mode, status], start_boundary)

	for expected_tab in range(1, expected_titles.size()):
		if expected_tab == 2:
			await _press_key(KEY_RIGHT)
		else:
			await _press_joypad_button(JOY_BUTTON_DPAD_RIGHT)
		if not _assert_outcome_recap_tab_state(shell, tab_bar, expected_tab, expected_tab, expected_titles):
			return {}

	await _press_joypad_button(JOY_BUTTON_DPAD_RIGHT)
	var end_boundary: Dictionary = shell.validation_outcome_recap_tab_navigation_snapshot()
	if int(end_boundary.get("active_tab", -1)) != 4 \
			or int(end_boundary.get("change_count", -1)) != 4 \
			or int(end_boundary.get("boundary_retain_count", -1)) != 2 \
			or get_viewport().gui_get_focus_owner() != tab_bar:
		return _fail_dictionary("%s/%s Outcome recap tabs wrapped right from Journal." % [launch_mode, status], end_boundary)

	for expected_tab in [3, 2, 1, 0]:
		if expected_tab == 2:
			await _press_key(KEY_LEFT)
		else:
			await _press_joypad_button(JOY_BUTTON_DPAD_LEFT)
		var expected_count: int = 8 - int(expected_tab)
		if not _assert_outcome_recap_tab_state(shell, tab_bar, int(expected_tab), expected_count, expected_titles):
			return {}

	await _press_key(KEY_LEFT)
	var reverse_boundary: Dictionary = shell.validation_outcome_recap_tab_navigation_snapshot()
	if int(reverse_boundary.get("active_tab", -1)) != 0 \
			or int(reverse_boundary.get("change_count", -1)) != 8 \
			or int(reverse_boundary.get("boundary_retain_count", -1)) != 3 \
			or get_viewport().gui_get_focus_owner() != tab_bar:
		return _fail_dictionary("%s/%s keyboard Left wrapped from the first Outcome recap tab." % [launch_mode, status], reverse_boundary)

	await _click_outcome_recap_tab(tab_bar, 1)
	if not _assert_outcome_recap_tab_state(shell, tab_bar, 1, 9, expected_titles):
		return {}
	for expected_tab in [2, 3, 4]:
		await _press_joypad_button(JOY_BUTTON_DPAD_RIGHT)
		var expected_count: int = 9 + int(expected_tab) - 1
		if not _assert_outcome_recap_tab_state(shell, tab_bar, int(expected_tab), expected_count, expected_titles):
			return {}

	var authority_after: Dictionary = _outcome_recap_authority_snapshot(session)
	if authority_after != authority_before:
		return _fail_dictionary("%s/%s Outcome recap traversal mutated session, progression, save, settings, or route authority." % [launch_mode, status], _first_outcome_difference(authority_before, authority_after))
	var copy_after: Dictionary = _outcome_recap_copy_snapshot(shell)
	if copy_after != copy_before:
		return _fail_dictionary("%s/%s Outcome recap traversal changed authored action or recap copy." % [launch_mode, status], _first_outcome_difference(copy_before, copy_after))

	traversal_count = 0
	while get_viewport().gui_get_focus_owner() != entry_focus and traversal_count <= cycle_names.size():
		await _press_joypad_button(JOY_BUTTON_RIGHT_SHOULDER)
		traversal_count += 1
	var final_snapshot: Dictionary = shell.validation_outcome_recap_tab_navigation_snapshot()
	if get_viewport().gui_get_focus_owner() != entry_focus \
			or int(final_snapshot.get("active_tab", -1)) != 4 \
			or int(final_snapshot.get("change_count", -1)) != 12:
		return _fail_dictionary("%s/%s Outcome recap traversal did not return to the original primary action with Journal retained." % [launch_mode, status], final_snapshot)
	return {
		"tab_count": int(final_snapshot.get("tab_count", 0)),
		"change_count": int(final_snapshot.get("change_count", 0)),
		"boundary_retain_count": int(final_snapshot.get("boundary_retain_count", 0)),
		"selected_tab_title": String(final_snapshot.get("selected_tab_title", "")),
		"tab_bar_occurrences": int(final_snapshot.get("tab_bar_occurrences", 0)),
		"authority_exact": true,
		"copy_exact": true,
	}


func _assert_outcome_recap_tab_state(
	shell: Control,
	tab_bar: TabBar,
	expected_tab: int,
	expected_count: int,
	expected_titles: Array
) -> bool:
	var snapshot: Dictionary = shell.validation_outcome_recap_tab_navigation_snapshot()
	var last: Dictionary = snapshot.get("last_change_result", {}) if snapshot.get("last_change_result", {}) is Dictionary else {}
	var expected_title := String(expected_titles[expected_tab])
	if int(snapshot.get("active_tab", -1)) != expected_tab \
			or String(snapshot.get("selected_tab_title", "")) != expected_title \
			or int(snapshot.get("change_sequence", -1)) != expected_count \
			or int(snapshot.get("change_count", -1)) != expected_count \
			or int(snapshot.get("focus_retention_count", -1)) != expected_count \
			or not bool(snapshot.get("tab_bar_has_focus", false)) \
			or get_viewport().gui_get_focus_owner() != tab_bar \
			or int(last.get("to_tab", -1)) != expected_tab \
			or String(last.get("tab_title", "")) != expected_title \
			or not bool(last.get("focus_retained", false)) \
			or int(last.get("sequence", -1)) != expected_count \
			or not String(snapshot.get("tab_bar_tooltip", "")).contains("Selected: %s." % expected_title):
		_fail_dictionary("Outcome recap tab %d did not retain exact native focus, copy, and sequence." % expected_tab, snapshot)
		return false
	return true


func _exercise_recovery_and_overwrite() -> Dictionary:
	AppRouter.validation_reset_scenario_outcome_route_state()
	AppRouter.validation_set_scenario_outcome_routing_suppressed(true)
	get_window().size = Vector2i(1280, 720)
	await _settle()
	var old_manual := ScenarioFactory.create_session("river-pass", "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	old_manual.day = 9
	if SaveService.save_manual_session(old_manual.to_dict(), MANUAL_SLOT) == "":
		return _fail_dictionary("Could not seed occupied Manual Slot %d." % MANUAL_SLOT)
	var manual_before := _file_state(MANUAL_PATH)
	SaveService.set_selected_manual_slot(MANUAL_SLOT)

	var session: SessionStateStoreScript.SessionData = _terminal_session(SessionState.LAUNCH_MODE_SKIRMISH, "victory")
	session = SessionState.set_active_session(session)
	if not bool(SaveService.save_runtime_autosave_session(session).get("ok", false)):
		return _fail_dictionary("Could not seed the prior autosave for Outcome recovery.")
	OS.set_environment(FAILURE_ENV, "precommit")
	var route_result: Dictionary = AppRouter.go_to_scenario_outcome()
	OS.unset_environment(FAILURE_ENV)
	if bool(route_result.get("ok", true)) or not bool(route_result.get("recovery_pending", false)):
		return _fail_dictionary("Injected Outcome autosave failure did not establish recovery authority.", _compact_result(route_result))

	var shell = _instantiate_outcome_shell(Vector2i(1280, 720))
	await _settle()
	var recovery_focus: Dictionary = shell.validation_outcome_focus_snapshot()
	if String(recovery_focus.get("focus_owner", "")) != "Save" \
			or not bool(recovery_focus.get("recovery_pending", false)):
		return _fail_dictionary("Outcome recovery did not override normal entry focus with Save.", _compact_focus(recovery_focus))
	var save_button: Button = shell.get_node("%Save")
	if get_viewport().gui_get_focus_owner() != save_button:
		return _fail_dictionary("Live Outcome recovery focus owner was not the Save button.")
	var recovery_copy_before: Dictionary = _outcome_recap_copy_snapshot(shell)
	var recovery_authority_before: Dictionary = _outcome_recap_authority_snapshot(session)
	var recovery_tabs: Dictionary = shell.validation_reset_outcome_recap_tab_navigation_state()
	var recap_tabs: TabContainer = shell.get_node("%RecapTabs")
	var tab_bar: TabBar = recap_tabs.get_tab_bar()
	var recovery_traversal_count := 0
	var recovery_cycle_count := int(recovery_tabs.get("focus_cycle_count", 0))
	while get_viewport().gui_get_focus_owner() != tab_bar and recovery_traversal_count <= recovery_cycle_count:
		await _press_joypad_button(JOY_BUTTON_RIGHT_SHOULDER)
		recovery_traversal_count += 1
	if get_viewport().gui_get_focus_owner() != tab_bar:
		return _fail_dictionary("Outcome recovery focus cycle could not reach its recap TabBar.", recovery_tabs)
	await _press_joypad_button(JOY_BUTTON_DPAD_RIGHT)
	if not _assert_outcome_recap_tab_state(shell, tab_bar, 1, 1, ["Progress", "Arc", "Carry", "After", "Journal"]):
		return {}
	recovery_traversal_count = 0
	while get_viewport().gui_get_focus_owner() != save_button and recovery_traversal_count <= recovery_cycle_count:
		await _press_joypad_button(JOY_BUTTON_RIGHT_SHOULDER)
		recovery_traversal_count += 1
	if get_viewport().gui_get_focus_owner() != save_button \
			or _outcome_recap_authority_snapshot(session) != recovery_authority_before \
			or _outcome_recap_copy_snapshot(shell) != recovery_copy_before:
		return _fail_dictionary("Outcome recovery recap traversal did not restore exact Save focus and authority.", shell.validation_outcome_recap_tab_navigation_snapshot())

	await _press_action("ui_accept")
	await _settle()
	var dialog: ConfirmationDialog = shell.get_node("ManualSaveOverwriteDialog")
	var dialog_snapshot: Dictionary = dialog.validation_snapshot()
	var cancel_button := dialog.get_cancel_button()
	var dialog_viewport := cancel_button.get_viewport()
	var dialog_focus_owner := dialog_viewport.gui_get_focus_owner() if dialog_viewport != null else null
	if not dialog.visible \
			or String(dialog_snapshot.get("cancel_text", "")) != "Keep Save" \
			or dialog_focus_owner != cancel_button \
			or int(dialog_snapshot.get("pending_slot", 0)) != MANUAL_SLOT \
			or int(shell.validation_outcome_recap_tab_navigation_snapshot().get("active_tab", -1)) != 1:
		return _fail_dictionary("Recovered Outcome Save did not open the occupied-slot modal with Keep Save focused.", {
			"dialog": dialog_snapshot,
			"dialog_focus": _control_name(dialog_focus_owner),
		})
	if _file_state(MANUAL_PATH) != manual_before:
		return _fail_dictionary("Opening the Outcome overwrite modal changed the occupied manual save.")

	await _press_key(KEY_ESCAPE)
	await _settle()
	dialog_snapshot = dialog.validation_snapshot()
	if dialog.visible \
			or get_viewport().gui_get_focus_owner() != save_button \
			or int(dialog_snapshot.get("cancel_count", 0)) != 1 \
			or int(dialog_snapshot.get("confirm_count", 0)) != 0 \
			or _file_state(MANUAL_PATH) != manual_before \
			or int(shell.validation_outcome_recap_tab_navigation_snapshot().get("active_tab", -1)) != 1:
		return _fail_dictionary("Canceling Outcome overwrite did not preserve bytes and restore the exact Save origin.", {
			"dialog": dialog_snapshot,
			"focus_owner": _control_name(get_viewport().gui_get_focus_owner()),
			"bytes_equal": _file_state(MANUAL_PATH) == manual_before,
		})
	var router: Dictionary = AppRouter.validation_scenario_outcome_route_snapshot()
	if int(router.get("retry_success_count", 0)) != 1 or int(router.get("route_attempt_count", 0)) != 1:
		return _fail_dictionary("Outcome recovery Save did not complete one durable retry without a second route.", {
			"retry_success_count": router.get("retry_success_count", -1),
			"route_attempt_count": router.get("route_attempt_count", -1),
		})

	var row := {
		"cancel_text": String(dialog_snapshot.get("cancel_text", "")),
		"recap_tab_after_cancel": int(shell.validation_outcome_recap_tab_navigation_snapshot().get("active_tab", -1)),
		"viewport": _viewport_snapshot(shell),
	}
	shell.get_parent().queue_free()
	await get_tree().process_frame
	return row


func _terminal_session(launch_mode: String, status: String) -> SessionStateStoreScript.SessionData:
	var session: SessionStateStoreScript.SessionData
	if launch_mode == SessionState.LAUNCH_MODE_CAMPAIGN:
		var profile := CampaignRules.normalize_profile({})
		CampaignProgression.profile = profile
		session = CampaignRules.build_session_bridge(profile, "river-pass", "normal", "campaign_reedfall")
	else:
		session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.scenario_status = status
	session.scenario_summary = "Focused %s %s outcome." % [launch_mode, status]
	session.game_state = "outcome"
	session.battle = {}
	return session


func _instantiate_outcome_shell(viewport_size: Vector2i) -> Control:
	var frame := Control.new()
	frame.name = "OutcomeFrame"
	frame.size = Vector2(viewport_size)
	frame.clip_contents = true
	add_child(frame)
	var shell := OUTCOME_SCENE.instantiate() as Control
	frame.add_child(shell)
	return shell


func _focus_cycle_is_enabled(snapshot: Dictionary) -> bool:
	var cycle: Array = snapshot.get("focus_cycle", []) if snapshot.get("focus_cycle", []) is Array else []
	if cycle.size() < 5:
		return false
	for entry_value in cycle:
		if not (entry_value is Dictionary) or bool((entry_value as Dictionary).get("disabled", true)):
			return false
	return true


func _outcome_controls_fit(shell: Control) -> bool:
	var visible := (shell.get_parent() as Control).get_global_rect()
	for node_name in ["OutcomeBanner", "ActionsPanel", "SavePanel", "Save"]:
		var control := shell.find_child(node_name, true, false) as Control
		if control == null or not control.is_visible_in_tree():
			return false
		var rect := control.get_global_rect()
		if rect.position.x < visible.position.x - 1.0 \
				or rect.position.y < visible.position.y - 1.0 \
				or rect.end.x > visible.end.x + 1.0 \
				or rect.end.y > visible.end.y + 1.0:
			return false
	return true


func _viewport_snapshot(shell: Control) -> Dictionary:
	var snapshot := {"visible_rect": (shell.get_parent() as Control).get_global_rect()}
	for node_name in ["OutcomeBanner", "ActionsPanel", "SavePanel", "Save"]:
		var control := shell.find_child(node_name, true, false) as Control
		if control != null:
			snapshot[node_name] = control.get_global_rect()
	return snapshot


func _outcome_recap_authority_snapshot(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var files := {}
	for path in [
		"user://saves/autosave.json",
		"user://saves/manual_slot_1.json",
		"user://saves/manual_slot_2.json",
		"user://saves/manual_slot_3.json",
		"user://saves/campaign_progression.json",
		SettingsService.SETTINGS_FILE,
	]:
		files[path] = _file_state(path)
		files["%s.candidate" % path] = _file_state("%s.candidate" % path)
		files["%s.backup" % path] = _file_state("%s.backup" % path)
	return {
		"session": session.to_dict(),
		"active_session_same": SessionState.active_session == session,
		"campaign_profile": CampaignProgression.ensure_profile().duplicate(true),
		"selected_manual_slot": SaveService.get_selected_manual_slot(),
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
		"settings": SettingsService.ensure_settings().duplicate(true),
		"files": files,
		"scenario_outcome_route": AppRouter.validation_scenario_outcome_route_snapshot(),
		"active_play_return": AppRouter.validation_active_play_return_snapshot(),
		"safe_quit": AppRouter.validation_safe_quit_snapshot(),
		"battle_entry": AppRouter.validation_battle_entry_snapshot(),
	}


func _outcome_recap_copy_snapshot(shell: Control) -> Dictionary:
	var snapshot: Dictionary = shell.validation_snapshot()
	var result := {}
	for key in [
		"scenario_id",
		"difficulty",
		"launch_mode",
		"scenario_status",
		"scenario_summary",
		"game_state",
		"day",
		"resume_target",
		"header",
		"summary",
		"mode_summary",
		"progression_summary",
		"campaign_arc_summary",
		"carryover_summary",
		"carryover_label",
		"carryover_tooltip",
		"aftermath_summary",
		"journal_summary",
		"next_step_summary",
		"continuity_choice_summary",
		"post_result_handoff_summary",
		"next_play_action_summary",
		"action_cue_summary",
		"actions_hint",
		"actions_hint_tooltip",
		"action_status",
		"action_ids",
		"action_tooltips",
		"actions",
		"save_status",
		"save_status_tooltip",
		"save_button_tooltip",
		"menu_button_label",
		"menu_button_tooltip",
		"return_cue",
		"return_cue_tooltip",
	]:
		result[key] = snapshot.get(key)
	return result


func _first_outcome_difference(expected: Variant, actual: Variant, path: String = "$") -> Dictionary:
	if typeof(expected) != typeof(actual):
		return {"path": path, "expected_type": type_string(typeof(expected)), "actual_type": type_string(typeof(actual))}
	if expected is Dictionary:
		var expected_dictionary: Dictionary = expected
		var actual_dictionary: Dictionary = actual
		var expected_keys: Array = expected_dictionary.keys()
		expected_keys.sort()
		var actual_keys: Array = actual_dictionary.keys()
		actual_keys.sort()
		if expected_keys != actual_keys:
			return {"path": path, "expected_keys": expected_keys, "actual_keys": actual_keys}
		for key in expected_keys:
			var nested: Dictionary = _first_outcome_difference(expected_dictionary.get(key), actual_dictionary.get(key), "%s.%s" % [path, key])
			if not nested.is_empty():
				return nested
		return {}
	if expected is Array:
		var expected_array: Array = expected
		var actual_array: Array = actual
		if expected_array.size() != actual_array.size():
			return {"path": path, "expected_size": expected_array.size(), "actual_size": actual_array.size()}
		for index in range(expected_array.size()):
			var nested: Dictionary = _first_outcome_difference(expected_array[index], actual_array[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
		return {}
	if expected != actual:
		return {"path": path, "expected": expected, "actual": actual}
	return {}


func _click_outcome_recap_tab(tab_bar: TabBar, tab_index: int) -> void:
	var rect := tab_bar.get_tab_rect(tab_index)
	var position := tab_bar.global_position + rect.position + rect.size * 0.5
	var viewport := tab_bar.get_viewport()
	var window_id: int = int(viewport.get_window_id()) if viewport is Window else 0
	var pressed := InputEventMouseButton.new()
	pressed.window_id = window_id
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.position = position
	pressed.global_position = position
	pressed.pressed = true
	viewport.push_input(pressed, true)
	await get_tree().process_frame
	var released := InputEventMouseButton.new()
	released.window_id = window_id
	released.button_index = MOUSE_BUTTON_LEFT
	released.position = position
	released.global_position = position
	released.pressed = false
	viewport.push_input(released, true)
	await _settle()


func _press_action(action: StringName) -> void:
	var pressed := InputEventAction.new()
	pressed.action = action
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventAction.new()
	released.action = action
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().process_frame


func _press_joypad_button(button_index: int) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.button_index = button_index
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventJoypadButton.new()
	released.button_index = button_index
	released.pressed = false
	Input.parse_input_event(released)
	await _settle()


func _press_key(keycode: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.physical_keycode = keycode
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventKey.new()
	released.keycode = keycode
	released.physical_keycode = keycode
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().process_frame


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _capture_original_state() -> void:
	_original_active_session = SessionState.active_session
	_original_profile = CampaignProgression.profile.duplicate(true)
	_original_selected_slot = SaveService.get_selected_manual_slot()
	_original_window_size = get_window().size
	_original_files = {
		AUTOSAVE_PATH: _file_state(AUTOSAVE_PATH),
		MANUAL_PATH: _file_state(MANUAL_PATH),
	}


func _cleanup() -> void:
	OS.unset_environment(FAILURE_ENV)
	AppRouter.validation_reset_scenario_outcome_route_state()
	AppRouter.validation_set_scenario_outcome_routing_suppressed(false)
	SessionState.active_session = _original_active_session
	CampaignProgression.profile = _original_profile.duplicate(true)
	SaveService.set_selected_manual_slot(_original_selected_slot)
	SaveService.validation_clear_summary_cache()
	for path in _original_files:
		_restore_file_state(String(path), _original_files[path])
	get_window().size = _original_window_size


func _file_state(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "bytes": PackedByteArray()}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": true, "bytes": PackedByteArray()}
	return {"exists": true, "bytes": file.get_buffer(file.get_length())}


func _restore_file_state(path: String, state: Dictionary) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.remove_absolute(absolute)
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(String(artifacts.get("candidate", ""))))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(String(artifacts.get("backup", ""))))
	if not bool(state.get("exists", false)):
		return
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(state.get("bytes", PackedByteArray()))


func _compact_focus(snapshot: Dictionary) -> Dictionary:
	var compact := {}
	for key in ["focus_owner", "focused_action_id", "preferred_action_id", "primary_action_id", "enabled_action_ids", "disabled_action_ids", "focus_cycle", "accept_count", "last_accept_result", "recovery_pending", "manual_overwrite_visible"]:
		if snapshot.has(key):
			compact[key] = snapshot[key]
	return compact


func _compact_result(result: Dictionary) -> Dictionary:
	var compact := {}
	for key in ["ok", "saved", "routed", "reason", "retry_action", "recovery_pending", "message"]:
		if result.has(key):
			compact[key] = result[key]
	return compact


func _control_name(control: Variant) -> String:
	return String(control.name) if control is Node else "none"


func _fail_dictionary(message: String, details: Dictionary = {}) -> Dictionary:
	_cleanup()
	push_error("%s: %s details=%s" % [REPORT_ID, message, JSON.stringify(details)])
	get_tree().quit(1)
	return {}
