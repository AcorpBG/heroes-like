extends Node

const REPORT_ID := "SCENARIO_OUTCOME_NEW_SESSION_CONFIRMATION_SAFE_CANCEL_REGRESSION"
const OUTCOME_SCENE := preload("res://scenes/results/ScenarioOutcomeShell.tscn")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const FAILURE_ENV := "HEROES_LIKE_SAVE_FAIL_PHASE"
const AUTOSAVE_PATH := "user://saves/autosave.json"
const CAMPAIGN_PATH := "user://saves/campaign_progression.json"
const SETTINGS_PATHS := [
	"user://settings.cfg",
	"user://settings.cfg.candidate",
	"user://settings.cfg.backup",
]
const MANUAL_PATHS := [
	"user://saves/manual_slot_1.json",
	"user://saves/manual_slot_2.json",
	"user://saves/manual_slot_3.json",
]

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

	var rows: Array[Dictionary] = []
	var specifications := [
		{"mode": SessionState.LAUNCH_MODE_SKIRMISH, "status": "victory", "action": "skirmish_start:river-pass", "target": "river-pass", "open": "accept", "cancel": "accept"},
		{"mode": SessionState.LAUNCH_MODE_SKIRMISH, "status": "defeat", "action": "skirmish_start:river-pass", "target": "river-pass", "open": "mouse", "cancel": "back"},
		{"mode": SessionState.LAUNCH_MODE_CAMPAIGN, "status": "victory", "action": "campaign_start:causeway-stand", "target": "causeway-stand", "open": "validation", "cancel": "escape", "duplicate": "campaign_start:river-pass"},
		{"mode": SessionState.LAUNCH_MODE_CAMPAIGN, "status": "victory", "action": "campaign_start:river-pass", "target": "river-pass", "open": "mouse", "cancel": "accept"},
		{"mode": SessionState.LAUNCH_MODE_CAMPAIGN, "status": "defeat", "action": "campaign_start:river-pass", "target": "river-pass", "open": "accept", "cancel": "back"},
	]
	for specification in specifications:
		var row: Dictionary = await _exercise_action_row(specification)
		if row.is_empty():
			return
		rows.append(row)

	var stale_row: Dictionary = await _exercise_stale_guards()
	if stale_row.is_empty():
		return
	var controls_row: Dictionary = await _exercise_save_menu_and_overwrite_controls()
	if controls_row.is_empty():
		return

	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"rows": rows,
		"stale": stale_row,
		"controls": controls_row,
		"real_accept_open": true,
		"real_mouse_button_open": true,
		"keep_outcome_safe_focus": true,
		"captured_target_immutable": true,
		"confirm_once_route_parity": true,
		"viewport": "1280x720",
	})])
	get_tree().quit(0)


func _exercise_action_row(specification: Dictionary) -> Dictionary:
	_reset_router_state()
	var session: SessionStateStoreScript.SessionData = _terminal_session(
		String(specification.get("mode", "")),
		String(specification.get("status", ""))
	)
	session = SessionState.set_active_session(session)
	var shell: Control = _instantiate_shell()
	await _settle()
	shell.validation_set_outcome_new_session_routing_suppressed(true)
	var action_id := String(specification.get("action", ""))
	var action_button: Button = _action_button(shell, action_id)
	if action_button == null or action_button.disabled:
		return _fail_dictionary("Expected new-session action is unavailable.", {"action": action_id, "mode": specification.get("mode"), "status": specification.get("status")})

	var before: Dictionary = _authority_snapshot(session)
	var origin := action_button
	await _open_confirmation(shell, action_button, action_id, String(specification.get("open", "validation")))
	var opened: Dictionary = shell.validation_outcome_new_session_confirmation_snapshot()
	if not _confirmation_opened_exact(shell, opened, action_id, origin):
		return _fail_dictionary("New-session confirmation did not open with safe native focus and bounded geometry.", _compact_confirmation(opened))

	var duplicate_id := String(specification.get("duplicate", ""))
	if duplicate_id != "":
		var duplicate_result: Dictionary = shell.validation_request_outcome_new_session_confirmation(duplicate_id)
		var duplicate_snapshot: Dictionary = shell.validation_outcome_new_session_confirmation_snapshot()
		if String(duplicate_result.get("reason", "")) != "confirmation_already_pending" \
			or String(duplicate_snapshot.get("captured_action_id", "")) != action_id \
			or int(duplicate_snapshot.get("duplicate_request_count", 0)) != 1:
			return _fail_dictionary("A second request redirected the captured new-session target.", {"result": duplicate_result, "snapshot": _compact_confirmation(duplicate_snapshot)})

	await _cancel_confirmation(shell, String(specification.get("cancel", "accept")))
	var canceled: Dictionary = shell.validation_outcome_new_session_confirmation_snapshot()
	if bool(canceled.get("pending", true)) \
		or bool(canceled.get("dialog_visible", true)) \
		or int(canceled.get("cancel_count", 0)) != 1 \
		or int(canceled.get("confirm_count", 0)) != 0 \
		or int(canceled.get("perform_count", 0)) != 0 \
		or int(canceled.get("route_count", 0)) != 0 \
		or get_viewport().gui_get_focus_owner() != origin \
		or _authority_snapshot(session) != before:
		return _fail_dictionary("Safe cancel did not preserve exact authority and restore the exact action origin.", {
			"snapshot": _compact_confirmation(canceled),
			"focus": _control_name(get_viewport().gui_get_focus_owner()),
			"origin": _control_name(origin),
			"authority_equal": _authority_snapshot(session) == before,
		})

	await _open_confirmation(shell, action_button, action_id, "validation")
	var dialog: ConfirmationDialog = shell.get_node("NewSessionConfirmationDialog")
	dialog.get_ok_button().grab_focus()
	await _press_action("ui_focus_next")
	dialog.get_ok_button().grab_focus()
	await _settle()
	await _press_action("ui_accept")
	await _settle()
	var confirmed: Dictionary = shell.validation_outcome_new_session_confirmation_snapshot()
	var confirm_result: Dictionary = confirmed.get("last_result", {}) if confirmed.get("last_result", {}) is Dictionary else {}
	var active_session: SessionStateStoreScript.SessionData = SessionState.ensure_active_session()
	if not bool(confirm_result.get("ok", false)) \
		or not bool(confirm_result.get("performed", false)) \
		or not bool(confirm_result.get("routed", false)) \
		or not bool(confirm_result.get("route_suppressed", false)) \
		or String(confirm_result.get("route", "")) != "overworld" \
		or int(confirmed.get("confirm_count", 0)) != 1 \
		or int(confirmed.get("perform_count", 0)) != 1 \
		or int(confirmed.get("route_count", 0)) != 1 \
		or active_session.scenario_id != String(specification.get("target", "")) \
		or active_session.scenario_status != "in_progress" \
		or active_session.game_state != "overworld" \
		or not active_session.battle.is_empty():
		return _fail_dictionary("Deliberate confirm did not execute and suppress exactly one matching route.", {
			"result": confirm_result,
			"snapshot": _compact_confirmation(confirmed),
			"active": active_session.to_dict(),
		})
	var repeat_result: Dictionary = shell.validation_confirm_outcome_new_session_confirmation()
	var repeated: Dictionary = shell.validation_outcome_new_session_confirmation_snapshot()
	if String(repeat_result.get("reason", "")) != "no_pending_confirmation" \
		or int(repeated.get("confirm_count", 0)) != 1 \
		or int(repeated.get("perform_count", 0)) != 1 \
		or int(repeated.get("route_count", 0)) != 1:
		return _fail_dictionary("A repeated confirm replayed the outcome action.", {"repeat": repeat_result, "snapshot": _compact_confirmation(repeated)})

	var row := {
		"mode": specification.get("mode"),
		"status": specification.get("status"),
		"action": action_id,
		"target": active_session.scenario_id,
		"cancel": specification.get("cancel"),
	}
	_free_shell(shell)
	await _settle()
	return row


func _exercise_stale_guards() -> Dictionary:
	_reset_router_state()
	var session: SessionStateStoreScript.SessionData = _terminal_session(SessionState.LAUNCH_MODE_SKIRMISH, "victory")
	session = SessionState.set_active_session(session)
	var shell: Control = _instantiate_shell()
	await _settle()
	shell.validation_set_outcome_new_session_routing_suppressed(true)
	var action_id := "skirmish_start:river-pass"
	var action_button: Button = _action_button(shell, action_id)
	await _open_confirmation(shell, action_button, action_id, "validation")
	session.day += 1
	var stale_result: Dictionary = shell.validation_confirm_outcome_new_session_confirmation()
	var stale_snapshot: Dictionary = shell.validation_outcome_new_session_confirmation_snapshot()
	if String(stale_result.get("reason", "")) != "stale_request" \
		or "day" not in stale_result.get("stale_fields", []) \
		or int(stale_snapshot.get("stale_count", 0)) != 1 \
		or int(stale_snapshot.get("perform_count", 0)) != 0 \
		or int(stale_snapshot.get("route_count", 0)) != 0:
		return _fail_dictionary("Changed outcome identity did not fail closed.", {"result": stale_result, "snapshot": _compact_confirmation(stale_snapshot)})
	_free_shell(shell)
	await _settle()

	_reset_router_state()
	session = _terminal_session(SessionState.LAUNCH_MODE_SKIRMISH, "defeat")
	session = SessionState.set_active_session(session)
	shell = _instantiate_shell()
	await _settle()
	shell.validation_set_outcome_new_session_routing_suppressed(true)
	action_button = _action_button(shell, action_id)
	await _open_confirmation(shell, action_button, action_id, "validation")
	action_button.disabled = true
	var action_stale_result: Dictionary = shell.validation_confirm_outcome_new_session_confirmation()
	var action_stale_snapshot: Dictionary = shell.validation_outcome_new_session_confirmation_snapshot()
	if String(action_stale_result.get("reason", "")) != "stale_request" \
		or "action" not in action_stale_result.get("stale_fields", []) \
		or int(action_stale_snapshot.get("perform_count", 0)) != 0 \
		or int(action_stale_snapshot.get("route_count", 0)) != 0:
		return _fail_dictionary("Disabled captured action did not fail closed.", {"result": action_stale_result, "snapshot": _compact_confirmation(action_stale_snapshot)})
	_free_shell(shell)
	await _settle()

	_reset_router_state()
	session = _terminal_session(SessionState.LAUNCH_MODE_SKIRMISH, "victory")
	session = SessionState.set_active_session(session)
	if not bool(SaveService.save_runtime_autosave_session(session).get("ok", false)):
		return _fail_dictionary("Could not seed terminal autosave for recovery guard.")
	shell = _instantiate_shell()
	await _settle()
	shell.validation_set_outcome_new_session_routing_suppressed(true)
	action_button = _action_button(shell, action_id)
	await _open_confirmation(shell, action_button, action_id, "validation")
	OS.set_environment(FAILURE_ENV, "precommit")
	var recovery_entry: Dictionary = AppRouter.go_to_scenario_outcome()
	OS.unset_environment(FAILURE_ENV)
	if not bool(recovery_entry.get("recovery_pending", false)):
		return _fail_dictionary("Could not establish Outcome recovery after confirmation opened.", recovery_entry)
	var recovery_result: Dictionary = shell.validation_confirm_outcome_new_session_confirmation()
	await _settle()
	var recovery_snapshot: Dictionary = shell.validation_outcome_new_session_confirmation_snapshot()
	if String(recovery_result.get("reason", "")) != "outcome_autosave_recovery_pending" \
		or int(recovery_snapshot.get("stale_count", 0)) != 0 \
		or int(recovery_snapshot.get("perform_count", 0)) != 0 \
		or int(recovery_snapshot.get("route_count", 0)) != 0 \
		or get_viewport().gui_get_focus_owner() != shell.get_node("%Save"):
		return _fail_dictionary("Outcome recovery did not supersede the captured action and focus Save.", {"result": recovery_result, "snapshot": _compact_confirmation(recovery_snapshot), "focus": _control_name(get_viewport().gui_get_focus_owner())})
	_free_shell(shell)
	await _settle()
	AppRouter.validation_reset_scenario_outcome_route_state()
	return {"identity": "day", "action": "disabled", "recovery": "outcome_autosave_recovery_pending"}


func _exercise_save_menu_and_overwrite_controls() -> Dictionary:
	_reset_router_state()
	var session: SessionStateStoreScript.SessionData = _terminal_session(SessionState.LAUNCH_MODE_SKIRMISH, "victory")
	session = SessionState.set_active_session(session)
	var shell: Control = _instantiate_shell()
	await _settle()
	shell.validation_set_outcome_new_session_routing_suppressed(true)
	SaveService.set_selected_manual_slot(1)
	_remove_transaction_path(MANUAL_PATHS[0])
	var save_result: Dictionary = shell.validation_request_save_outcome()
	var save_snapshot: Dictionary = shell.validation_outcome_new_session_confirmation_snapshot()
	if not bool(save_result.get("ok", false)) \
		or int(save_snapshot.get("request_count", 0)) != 0 \
		or bool(save_snapshot.get("pending", false)):
		return _fail_dictionary("Save Outcome incorrectly entered new-session confirmation.", {"save": save_result, "confirmation": _compact_confirmation(save_snapshot)})
	_free_shell(shell)
	await _settle()

	_reset_router_state()
	session = _terminal_session(SessionState.LAUNCH_MODE_SKIRMISH, "victory")
	session = SessionState.set_active_session(session)
	shell = _instantiate_shell()
	await _settle()
	AppRouter.validation_set_active_play_return_routing_suppressed(true)
	var menu_result: Dictionary = shell.validation_return_to_menu()
	var menu_snapshot: Dictionary = shell.validation_outcome_new_session_confirmation_snapshot()
	if not bool(menu_result.get("ok", false)) \
		or not bool(menu_result.get("routed", false)) \
		or int(menu_snapshot.get("request_count", 0)) != 0 \
		or bool(menu_snapshot.get("pending", false)):
		return _fail_dictionary("Return to Menu incorrectly entered new-session confirmation.", {"menu": menu_result, "confirmation": _compact_confirmation(menu_snapshot)})
	_free_shell(shell)
	await _settle()

	_reset_router_state()
	var old_manual := ScenarioFactory.create_session("river-pass", "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	old_manual.day = 8
	if SaveService.save_manual_session(old_manual.to_dict(), 2) == "":
		return _fail_dictionary("Could not seed occupied Manual Slot 2.")
	var manual_before: Dictionary = _file_state(MANUAL_PATHS[1])
	SaveService.set_selected_manual_slot(2)
	session = _terminal_session(SessionState.LAUNCH_MODE_SKIRMISH, "defeat")
	session = SessionState.set_active_session(session)
	shell = _instantiate_shell()
	await _settle()
	var save_button: Button = shell.get_node("%Save")
	save_button.grab_focus()
	await _settle()
	save_button.pressed.emit()
	await _settle()
	var overwrite: ConfirmationDialog = shell.get_node("ManualSaveOverwriteDialog")
	var overwrite_snapshot: Dictionary = overwrite.validation_snapshot()
	var cancel_button := overwrite.get_cancel_button()
	var native_focus := cancel_button.get_viewport().gui_get_focus_owner()
	if not overwrite.visible \
		or String(overwrite_snapshot.get("cancel_text", "")) != "Keep Save" \
		or native_focus != cancel_button \
		or _file_state(MANUAL_PATHS[1]) != manual_before:
		return _fail_dictionary("Occupied Outcome save did not open Keep Save with native safe focus.", {"dialog": overwrite_snapshot, "focus": _control_name(native_focus)})
	await _press_key(KEY_ESCAPE)
	await _settle()
	if overwrite.visible \
		or get_viewport().gui_get_focus_owner() != save_button \
		or _file_state(MANUAL_PATHS[1]) != manual_before:
		return _fail_dictionary("Keep Save cancel did not restore the exact Save origin and bytes.", {"focus": _control_name(get_viewport().gui_get_focus_owner()), "dialog": overwrite.validation_snapshot()})
	_free_shell(shell)
	await _settle()
	return {"save": "direct", "menu": "direct", "overwrite_cancel": "Keep Save"}


func _terminal_session(launch_mode: String, status: String) -> SessionStateStoreScript.SessionData:
	var session: SessionStateStoreScript.SessionData
	if launch_mode == SessionState.LAUNCH_MODE_CAMPAIGN:
		var profile: Dictionary = CampaignRules.normalize_profile({})
		session = CampaignRules.build_session_bridge(profile, "river-pass", "normal", "campaign_reedfall")
		session.scenario_status = status
		session.scenario_summary = "Focused campaign %s outcome." % status
		session.game_state = "outcome"
		session.battle = {}
		if status == "victory":
			profile = CampaignRules.record_session_completion(profile, session)
		CampaignProgression.profile = profile.duplicate(true)
	else:
		session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
		session.scenario_status = status
		session.scenario_summary = "Focused skirmish %s outcome." % status
		session.game_state = "outcome"
		session.battle = {}
	return session


func _instantiate_shell() -> Control:
	var frame := Control.new()
	frame.name = "OutcomeConfirmationFrame"
	frame.size = Vector2(1280.0, 720.0)
	frame.clip_contents = true
	add_child(frame)
	var shell := OUTCOME_SCENE.instantiate() as Control
	frame.add_child(shell)
	return shell


func _free_shell(shell: Control) -> void:
	if is_instance_valid(shell) and is_instance_valid(shell.get_parent()):
		shell.get_parent().queue_free()


func _action_button(shell: Control, action_id: String) -> Button:
	for child in shell.get_node("%Actions").get_children():
		if child is Button and String(child.get_meta("outcome_action_id", "")) == action_id:
			return child
	return null


func _open_confirmation(shell: Control, button: Button, action_id: String, method: String) -> void:
	button.grab_focus()
	await _settle()
	match method:
		"accept":
			await _press_joypad_button(JOY_BUTTON_A)
		"mouse":
			await _click_button(button)
		_:
			shell.validation_request_outcome_new_session_confirmation(action_id)
			await _settle()


func _cancel_confirmation(shell: Control, method: String) -> void:
	match method:
		"accept":
			await _press_joypad_button(JOY_BUTTON_A)
		"back":
			await _press_joypad_button(JOY_BUTTON_B)
		_:
			await _press_key(KEY_ESCAPE)
	await _settle()


func _confirmation_opened_exact(shell: Control, snapshot: Dictionary, action_id: String, origin: Control) -> bool:
	var dialog: ConfirmationDialog = shell.get_node("NewSessionConfirmationDialog")
	var cancel_button := dialog.get_cancel_button()
	var position: Vector2i = snapshot.get("dialog_position", Vector2i(-1, -1))
	var size: Vector2i = snapshot.get("dialog_size", Vector2i.ZERO)
	var bounded := position.x >= 0 and position.y >= 0 and position.x + size.x <= 1280 and position.y + size.y <= 720
	return bool(snapshot.get("pending", false)) \
		and bool(snapshot.get("dialog_visible", false)) \
		and String(snapshot.get("captured_action_id", "")) == action_id \
		and String(snapshot.get("cancel_text", "")) == "Keep Outcome" \
		and String(snapshot.get("dialog_focus_owner", "")) == String(cancel_button.name) \
		and cancel_button.get_viewport().gui_get_focus_owner() == cancel_button \
		and String(snapshot.get("return_focus_name", "")) == String(origin.name) \
		and String(snapshot.get("title", "")) == "Start Fresh Expedition?" \
		and bounded


func _authority_snapshot(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var files := {}
	for path in _tracked_paths():
		files[path] = _file_state(path)
	var settings_tx: Dictionary = SettingsService.validation_settings_transaction_snapshot()
	return {
		"session": session.to_dict(),
		"active_same": SessionState.active_session == session,
		"profile": CampaignProgression.profile.duplicate(true),
		"selected_slot": SaveService.get_selected_manual_slot(),
		"files": files,
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
		"settings": settings_tx.get("settings", {}),
		"committed_settings": settings_tx.get("committed_settings", {}),
		"outcome_router": AppRouter.validation_scenario_outcome_route_snapshot(),
		"return_router": AppRouter.validation_active_play_return_snapshot(),
		"safe_quit": AppRouter.validation_safe_quit_snapshot(),
	}


func _reset_router_state() -> void:
	OS.unset_environment(FAILURE_ENV)
	AppRouter.validation_reset_scenario_outcome_route_state()
	AppRouter.validation_set_scenario_outcome_routing_suppressed(true)
	AppRouter.validation_reset_active_play_return_state()
	AppRouter.validation_set_active_play_return_routing_suppressed(true)
	AppRouter.validation_reset_safe_quit_state()


func _capture_original_state() -> void:
	_original_active_session = SessionState.active_session
	_original_profile = CampaignProgression.profile.duplicate(true)
	_original_selected_slot = SaveService.get_selected_manual_slot()
	_original_window_size = get_window().size
	for path in _tracked_paths():
		_original_files[path] = _file_state(path)


func _cleanup() -> void:
	OS.unset_environment(FAILURE_ENV)
	AppRouter.validation_reset_scenario_outcome_route_state()
	AppRouter.validation_set_scenario_outcome_routing_suppressed(false)
	AppRouter.validation_reset_active_play_return_state()
	AppRouter.validation_set_active_play_return_routing_suppressed(false)
	AppRouter.validation_reset_safe_quit_state()
	SessionState.active_session = _original_active_session
	CampaignProgression.profile = _original_profile.duplicate(true)
	SaveService.set_selected_manual_slot(_original_selected_slot)
	SaveService.validation_clear_summary_cache()
	for path in _original_files:
		_restore_file_state(String(path), _original_files[path])
	get_window().size = _original_window_size


func _tracked_paths() -> Array[String]:
	var paths: Array[String] = [AUTOSAVE_PATH, CAMPAIGN_PATH]
	for path in MANUAL_PATHS:
		paths.append(String(path))
	for path in SETTINGS_PATHS:
		paths.append(String(path))
	return paths


func _file_state(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "bytes": PackedByteArray()}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": true, "bytes": PackedByteArray()}
	return {"exists": true, "bytes": file.get_buffer(file.get_length())}


func _restore_file_state(path: String, state: Dictionary) -> void:
	_remove_transaction_path(path)
	if not bool(state.get("exists", false)):
		return
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(state.get("bytes", PackedByteArray()))


func _remove_transaction_path(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(path)
	for key in ["candidate", "backup"]:
		var artifact_path := String(artifacts.get(key, ""))
		if artifact_path != "":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(artifact_path))


func _compact_confirmation(snapshot: Dictionary) -> Dictionary:
	var compact := {}
	for key in ["pending", "dialog_visible", "captured_action_id", "captured_identity", "current_identity", "cancel_text", "confirm_text", "dialog_focus_owner", "return_focus_name", "origin_focus_owner", "dialog_position", "dialog_size", "request_count", "duplicate_request_count", "cancel_count", "confirm_count", "stale_count", "perform_count", "route_count", "route_suppressed", "last_result"]:
		if snapshot.has(key):
			compact[key] = snapshot[key]
	return compact


func _control_name(control: Variant) -> String:
	return String(control.name) if control is Node else "none"


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


func _click_button(button: Button) -> void:
	var center := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.position = center
	pressed.global_position = center
	pressed.pressed = true
	get_viewport().push_input(pressed, true)
	await get_tree().process_frame
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.position = center
	released.global_position = center
	released.pressed = false
	get_viewport().push_input(released, true)
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


func _press_joypad_button(button_index: JoyButton) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.button_index = button_index
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventJoypadButton.new()
	released.button_index = button_index
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().process_frame


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _fail_dictionary(message: String, details: Dictionary = {}) -> Dictionary:
	_cleanup()
	push_error("%s: %s details=%s" % [REPORT_ID, message, JSON.stringify(details)])
	get_tree().quit(1)
	return {}
