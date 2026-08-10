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
		"recovery_save_focus": true,
		"overwrite_cancel_text": recovery_row.get("cancel_text", ""),
		"overwrite_origin_restored": true,
		"viewport": recovery_row.get("viewport", {}),
	})])
	get_tree().quit(0)


func _exercise_ordinary_entry(launch_mode: String, status: String) -> Dictionary:
	AppRouter.validation_reset_scenario_outcome_route_state()
	AppRouter.validation_set_scenario_outcome_routing_suppressed(true)
	var session: SessionStateStoreScript.SessionData = _terminal_session(launch_mode, status)
	session = SessionState.set_active_session(session)
	var shell = _instantiate_compact_outcome_shell()
	await _settle()

	var entry: Dictionary = shell.validation_outcome_focus_snapshot()
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
	if String(refreshed.get("focused_action_id", "")) != primary_id:
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
	}
	shell.get_parent().queue_free()
	await get_tree().process_frame
	return row


func _exercise_recovery_and_overwrite() -> Dictionary:
	AppRouter.validation_reset_scenario_outcome_route_state()
	AppRouter.validation_set_scenario_outcome_routing_suppressed(true)
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

	var shell = _instantiate_compact_outcome_shell()
	await _settle()
	var recovery_focus: Dictionary = shell.validation_outcome_focus_snapshot()
	if String(recovery_focus.get("focus_owner", "")) != "Save" \
			or not bool(recovery_focus.get("recovery_pending", false)):
		return _fail_dictionary("Outcome recovery did not override normal entry focus with Save.", _compact_focus(recovery_focus))
	var save_button: Button = shell.get_node("%Save")
	if get_viewport().gui_get_focus_owner() != save_button:
		return _fail_dictionary("Live Outcome recovery focus owner was not the Save button.")

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
			or int(dialog_snapshot.get("pending_slot", 0)) != MANUAL_SLOT:
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
			or _file_state(MANUAL_PATH) != manual_before:
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


func _instantiate_compact_outcome_shell() -> Control:
	var frame := Control.new()
	frame.name = "CompactOutcomeFrame"
	frame.size = Vector2(1280.0, 720.0)
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
