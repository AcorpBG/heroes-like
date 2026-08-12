extends Node

const REPORT_ID := "MAP_EDITOR_DIRTY_WORKING_COPY_DESTRUCTIVE_TRANSITION_REGRESSION"
const SOURCE_STEM := "small-dawn-cairn-marsh-80034c5e"
const TARGET_STEM := "small-thorn-lantern-bend-b78aa337"
const FIXTURE_DIR := "user://maps"
const FAILURE_PHASES := ["precommit", "after_backup"]
const SAVE_FAILURE_ENV := "HEROES_LIKE_SAVE_FAIL_PHASE"

var _report_scene: Node
var _original_active_session = null
var _active_shell: Node = null
var _source_entry: Dictionary = {}
var _target_entry: Dictionary = {}
var _original_profile: Dictionary = {}
var _original_selected_slot := 1
var _original_summary_cache: Dictionary = {}
var _original_settings_transaction: Dictionary = {}
var _original_file_states: Dictionary = {}
var _original_window_size := Vector2i.ZERO
var _parent_probe_count := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_report_scene = self
	_original_active_session = SessionState.active_session
	_original_profile = CampaignProgression.profile.duplicate(true)
	_original_selected_slot = SaveService.get_selected_manual_slot()
	_original_summary_cache = SaveService.validation_summary_cache_snapshot()
	_original_settings_transaction = _canonical_settings_transaction()
	_original_window_size = get_window().size
	for path in _tracked_authority_paths():
		_original_file_states[path] = _file_state(path)
	if not ClassDB.class_exists("MapPackageService"):
		_fail("Native MapPackageService is unavailable.")
		return
	var source_id := ScenarioSelectRules.maps_folder_package_id_for_stem(SOURCE_STEM)
	var target_id := ScenarioSelectRules.maps_folder_package_id_for_stem(TARGET_STEM)
	if source_id == "" or target_id == "":
		_fail("Shipped package fixture ids are unavailable.")
		return
	if not _package_files_exist():
		_fail("Shipped package fixture pairs are incomplete.")
		return
	if not _copy_fixture_pairs():
		_fail("Could not copy the two shipped package fixtures into isolated user data.")
		return
	print("%s CASE fixture_copy_ready" % REPORT_ID)
	var package_index: Dictionary = ScenarioSelectRules.maps_folder_package_index({
		"package_dir": FIXTURE_DIR,
		"include_non_launchable_generated_packages": true,
		"consumer": "map_editor",
	})
	for entry_value in package_index.get("entries", []):
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var package_stem := String(entry.get("package_stem", ""))
		if package_stem == SOURCE_STEM:
			_source_entry = entry.duplicate(true)
		elif package_stem == TARGET_STEM:
			_target_entry = entry.duplicate(true)
	if _source_entry.is_empty() or _target_entry.is_empty():
		_fail("Shipped package fixtures were not loadable through the editor index.")
		return
	source_id = String(_source_entry.get("package_id", source_id))
	target_id = String(_target_entry.get("package_id", target_id))
	print("%s CASE fixture_index_ready" % REPORT_ID)
	var original_package_state := _package_file_state()
	var shell = await _create_editor_shell()
	if shell == null:
		return
	print("%s CASE exclusive_parent_start" % REPORT_ID)
	var exclusive_result := await _validate_exclusive_parent_matrix(shell, source_id, target_id, original_package_state)
	if not bool(exclusive_result.get("ok", false)):
		return

	print("%s CASE menu_start" % REPORT_ID)
	var menu_result := await _validate_menu_transition(shell, source_id, original_package_state)
	if not bool(menu_result.get("ok", false)):
		return
	print("%s CASE package_start" % REPORT_ID)
	var package_result := await _validate_package_transition(shell, source_id, target_id, original_package_state)
	if not bool(package_result.get("ok", false)):
		return
	print("%s CASE native_close_start" % REPORT_ID)
	var close_result := await _validate_native_close(shell, source_id, original_package_state)
	if not bool(close_result.get("ok", false)):
		return
	print("%s CASE safe_quit_failure_start" % REPORT_ID)
	var failure_result := await _validate_safe_quit_failure_retry(shell, source_id, original_package_state)
	if not bool(failure_result.get("ok", false)):
		return
	print("%s CASE clean_controls_start" % REPORT_ID)
	var clean_result := await _validate_clean_controls(shell, source_id, target_id, original_package_state)
	if not bool(clean_result.get("ok", false)):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"menu": menu_result,
		"package": package_result,
		"native_close": close_result,
		"safe_quit_failure_retry": failure_result,
		"clean_controls": clean_result,
		"exclusive_parent": exclusive_result,
		"save_version": SessionState.SAVE_VERSION,
	})])
	await _free_shell(shell)
	_cleanup()
	if SaveService.validation_summary_cache_snapshot() != _original_summary_cache \
			or _canonical_settings_transaction() != _original_settings_transaction \
			or _capture_file_states(_tracked_authority_paths()) != _original_file_states:
		_fail("Map Editor focused cleanup did not restore exact save/cache/settings authority.")
		return
	get_tree().quit(0)

func _validate_exclusive_parent_matrix(shell: Node, source_id: String, target_id: String, package_state: Dictionary) -> Dictionary:
	var rows := [
		{"id": "menu_1280", "width": 1280, "action": "menu", "cancel": "joypad_b", "confirm": "joypad_a"},
		{"id": "menu_1920", "width": 1920, "action": "menu", "cancel": "escape", "confirm": "enter"},
		{"id": "package_1280", "width": 1280, "action": "package", "cancel": "joypad_b", "confirm": "mouse"},
		{"id": "package_1920", "width": 1920, "action": "package", "cancel": "escape", "confirm": "joypad_a"},
		{"id": "quit_1280", "width": 1280, "action": "quit", "cancel": "joypad_b", "confirm": "enter"},
		{"id": "quit_1920", "width": 1920, "action": "quit", "cancel": "escape", "confirm": "mouse"},
	]
	var results: Array[Dictionary] = []
	for row_value in rows:
		var row: Dictionary = row_value
		var result := await _validate_exclusive_parent_row(shell, source_id, target_id, package_state, row)
		if result.is_empty():
			return {}
		results.append(result)
	return {"ok": true, "rows": results, "widths": [1280, 1920], "real_parent_probe": true, "stale_pending_release_noop": true}

func _validate_exclusive_parent_row(
	shell: Node,
	source_id: String,
	target_id: String,
	package_state: Dictionary,
	row: Dictionary
) -> Dictionary:
	var width := int(row.get("width", 1280))
	var action := String(row.get("action", "menu"))
	var layout_host := shell.get_parent() as Control
	var parent_probe: Button = shell.get_meta("exclusive_parent_probe") as Button
	if layout_host == null or parent_probe == null:
		return _fail_dict("Exclusive Map Editor host/probe is unavailable.")
	layout_host.size = Vector2(float(width), 720.0)
	get_window().size = Vector2i(width, 720)
	await _settle()
	if not await _reset_case(shell, source_id, true):
		return {}
	shell.call("validation_set_dirty_transition_routing_enabled", false)
	AppRouter.validation_set_quit_suppressed(true)
	AppRouter.validation_reset_safe_quit_state()
	AppRouter.validation_set_safe_close_guard_target(shell)
	if action == "package":
		var selected: Dictionary = shell.call("validation_select_map_package_id", target_id)
		if not bool(selected.get("ok", false)):
			return _fail_dict("Exclusive package row could not select its captured target.")
	var origin: Button = shell.get_node("%LoadMap") if action == "package" else shell.get_node("%Menu")
	origin.grab_focus()
	await _settle()
	await _open_dirty_transition(shell, action, target_id)
	var dialog: ConfirmationDialog = shell.get_node("DirtyTransitionConfirmationDialog")
	var opened: Dictionary = shell.call("validation_dirty_transition_snapshot")
	var geometry := _exclusive_parent_click_geometry(parent_probe, dialog)
	if not _dirty_transition_opened_exact(opened, action, target_id, origin, dialog, width) or not bool(geometry.get("exact", false)):
		return _fail_dict("Exclusive %s row did not open with exact bounded native focus: %s / %s" % [action, JSON.stringify(opened), JSON.stringify(geometry)])
	var authority_before_block := _full_authority_state(shell)
	var transaction_before_block := _dirty_transaction_snapshot(shell)
	var parent_before := _parent_probe_count
	await _click_control(parent_probe)
	await _settle()
	var blocked_checks := {
		"probe_blocked": _parent_probe_count == parent_before,
		"transaction_exact": _dirty_transaction_snapshot(shell) == transaction_before_block,
		"authority_exact": _full_authority_state(shell) == authority_before_block,
		"safe_focus_exact": dialog.get_cancel_button().get_viewport().gui_get_focus_owner() == dialog.get_cancel_button(),
	}
	if not _checks_exact(blocked_checks):
		return _fail_dict("Exclusive %s first parent click escaped: %s" % [action, JSON.stringify(blocked_checks)])
	await _send_cancel(String(row.get("cancel", "joypad_b")))
	var canceled: Dictionary = shell.call("validation_dirty_transition_snapshot")
	if bool(canceled.get("pending", true)) or bool(canceled.get("dialog_visible", true)) \
			or int(canceled.get("cancel_count", 0)) != 1 or int(canceled.get("confirm_count", 0)) != 0 \
			or get_viewport().gui_get_focus_owner() != origin \
			or _full_authority_state(shell) != authority_before_block:
		return _fail_dict("Exclusive %s physical cancel was not exact: %s" % [action, JSON.stringify(canceled)])
	var positive_before := _parent_probe_count
	var positive_authority := _full_authority_state(shell)
	await _click_control(parent_probe)
	await _settle()
	if _parent_probe_count != positive_before + 1 or _full_authority_state(shell) != positive_authority:
		return _fail_dict("Exclusive %s identical parent probe was not actionable after close." % action)

	# Queue a physical press into the root bridge, replace the pending Dictionary
	# synchronously, then deliver the release normally. Both stale events must no-op.
	await _open_dirty_transition(shell, action, target_id)
	var stale_pressed := InputEventKey.new()
	stale_pressed.keycode = KEY_ESCAPE
	stale_pressed.physical_keycode = KEY_ESCAPE
	stale_pressed.pressed = true
	shell.call("_on_root_window_input", stale_pressed)
	shell.call("validation_cancel_dirty_transition")
	shell.call("validation_request_dirty_transition", action, target_id if action == "package" else "")
	await _settle()
	var replacement_before := _dirty_transaction_snapshot(shell)
	var stale_released := InputEventKey.new()
	stale_released.keycode = KEY_ESCAPE
	stale_released.physical_keycode = KEY_ESCAPE
	stale_released.pressed = false
	Input.parse_input_event(stale_released)
	await _settle()
	if _dirty_transaction_snapshot(shell) != replacement_before or not dialog.visible \
			or dialog.get_cancel_button().get_viewport().gui_get_focus_owner() != dialog.get_cancel_button():
		return _fail_dict("Exclusive %s stale pending/release reached its replacement." % action)
	var authority_before_second := _full_authority_state(shell)
	var parent_before_second := _parent_probe_count
	await _click_control(parent_probe)
	await _settle()
	if _parent_probe_count != parent_before_second or _dirty_transaction_snapshot(shell) != replacement_before \
			or _full_authority_state(shell) != authority_before_second:
		return _fail_dict("Exclusive %s second parent click changed authority." % action)
	await _send_confirm(dialog, String(row.get("confirm", "enter")))
	await _settle()
	var confirmed: Dictionary = shell.call("validation_dirty_transition_snapshot")
	var consequence_exact := false
	match action:
		"menu":
			consequence_exact = int(confirmed.get("menu_route_count", 0)) == 1
		"package":
			var editor_snapshot: Dictionary = shell.call("validation_snapshot")
			consequence_exact = int(confirmed.get("package_action_count", 0)) == 1 \
				and String(editor_snapshot.get("editor_source_package_id", "")) == target_id
		"quit":
			var quit_snapshot: Dictionary = AppRouter.validation_safe_quit_snapshot()
			consequence_exact = int(confirmed.get("quit_attempt_count", 0)) == 1 \
				and int(quit_snapshot.get("quit_attempt_count", 0)) == 1 \
				and int(quit_snapshot.get("suppressed_quit_count", 0)) == 1
	if bool(confirmed.get("pending", true)) or bool(confirmed.get("dialog_visible", true)) \
			or int(confirmed.get("confirm_count", 0)) != 1 or not consequence_exact \
			or _package_file_state() != package_state:
		return _fail_dict("Exclusive %s deliberate confirm was not exact: %s" % [action, JSON.stringify(confirmed)])
	return {"id": row.get("id"), "width": width, "action": action, "cancel": row.get("cancel"), "confirm": row.get("confirm"), "blocked": true, "stale_noop": true}

func _open_dirty_transition(shell: Node, action: String, target_id: String) -> void:
	if action == "quit":
		get_tree().root.close_requested.emit()
	else:
		shell.call("validation_request_dirty_transition", action, target_id if action == "package" else "")
	await _settle()

func _send_cancel(method: String) -> void:
	if method == "escape":
		await _press_key(KEY_ESCAPE)
	else:
		await _press_joypad_button(JOY_BUTTON_B)

func _send_confirm(dialog: ConfirmationDialog, method: String) -> void:
	dialog.get_ok_button().grab_focus()
	await get_tree().process_frame
	match method:
		"joypad_a": await _press_joypad_button(JOY_BUTTON_A)
		"mouse": await _click_control(dialog.get_ok_button())
		_: await _press_key(KEY_ENTER)

func _validate_menu_transition(shell: Node, source_id: String, package_state: Dictionary) -> Dictionary:
	if not await _reset_case(shell, source_id, true):
		return {}
	shell.call("validation_set_dirty_transition_routing_enabled", false)
	var origin: Button = shell.get_node("%Menu")
	var before := _protected_state(shell)
	origin.grab_focus()
	await get_tree().process_frame
	await _press_joypad_button(JOY_BUTTON_A)
	if not _assert_dialog(shell, "menu", "", "Keep Editing", "Menu"):
		return {}
	await _press_joypad_button(JOY_BUTTON_B)
	if not await _assert_canceled_exact(shell, before, origin, package_state, "Menu controller B"):
		return {}
	var request: Dictionary = shell.call("validation_request_dirty_transition", "menu")
	await _settle()
	if not bool(request.get("pending", false)) or not _assert_dialog(shell, "menu", "", "Keep Editing", "Menu"):
		return _fail_dict("Menu confirmation did not reopen for Escape.")
	await _press_key(KEY_ESCAPE)
	if not await _assert_canceled_exact(shell, before, origin, package_state, "Menu Escape"):
		return {}
	request = shell.call("validation_request_dirty_transition", "menu")
	await _settle()
	var confirmed: Dictionary = shell.call("validation_confirm_dirty_transition")
	var snapshot: Dictionary = shell.call("validation_dirty_transition_snapshot")
	if not bool(confirmed.get("ok", false)) or int(confirmed.get("route_attempt_delta", 0)) != 1 \
			or int(snapshot.get("confirm_count", 0)) != 1 or int(snapshot.get("menu_route_count", 0)) != 1:
		return _fail_dict("Menu confirmation did not execute exactly once: %s" % JSON.stringify({"result": confirmed, "snapshot": snapshot}))
	if _package_file_state() != package_state:
		return _fail_dict("Menu confirmation mutated shipped package files.")
	return {"ok": true, "cancel_count": 2, "confirm_count": 1, "route_count": 1}

func _validate_package_transition(shell: Node, source_id: String, target_id: String, package_state: Dictionary) -> Dictionary:
	if not await _reset_case(shell, source_id, true):
		return {}
	var selected: Dictionary = shell.call("validation_select_map_package_id", target_id)
	if not bool(selected.get("ok", false)):
		return _fail_dict("Target package fixture was not indexed: %s" % JSON.stringify(selected))
	var origin: Button = shell.get_node("%LoadMap")
	var before := _protected_state(shell)
	origin.grab_focus()
	await get_tree().process_frame
	await _press_joypad_button(JOY_BUTTON_A)
	if not _assert_dialog(shell, "package", target_id, "Keep Editing", "LoadMap"):
		return {}
	await _press_joypad_button(JOY_BUTTON_B)
	if not await _assert_canceled_exact(shell, before, origin, package_state, "Package controller B"):
		return {}
	var request: Dictionary = shell.call("validation_request_dirty_transition", "package", target_id)
	await _settle()
	if not bool(request.get("pending", false)):
		return _fail_dict("Package confirmation did not reopen for Escape: %s" % JSON.stringify(request))
	await _press_key(KEY_ESCAPE)
	if not await _assert_canceled_exact(shell, before, origin, package_state, "Package Escape"):
		return {}
	request = shell.call("validation_request_dirty_transition", "package", target_id)
	await _settle()
	var redirected: Dictionary = shell.call("validation_select_map_package_id", source_id)
	if not bool(redirected.get("ok", false)):
		return _fail_dict("Could not stage package-selection redirect control.")
	var confirmed: Dictionary = shell.call("validation_confirm_dirty_transition")
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var transition: Dictionary = shell.call("validation_dirty_transition_snapshot")
	if not bool(confirmed.get("ok", false)) or String(confirmed.get("package_id", "")) != target_id \
			or int(confirmed.get("load_attempt_delta", 0)) != 1 \
			or String(snapshot.get("editor_source_package_id", "")) != target_id \
			or int(transition.get("package_action_count", 0)) != 1 or int(transition.get("confirm_count", 0)) != 1:
		return _fail_dict("Package confirmation did not use its immutable captured identity exactly once: %s" % JSON.stringify({"result": confirmed, "source": snapshot.get("editor_source_package_id", ""), "transition": transition}))
	if _package_file_state() != package_state:
		return _fail_dict("Package replacement mutated shipped package files.")
	return {"ok": true, "captured_target": true, "cancel_count": 2, "confirm_count": 1, "load_count": 1}

func _validate_native_close(shell: Node, source_id: String, package_state: Dictionary) -> Dictionary:
	var active = _seed_canonical_active_session(31)
	if active == null:
		return _fail_dict("Could not seed the native-close autosave control.")
	if not await _reset_case(shell, source_id, true):
		return {}
	AppRouter.validation_set_quit_suppressed(true)
	AppRouter.validation_reset_safe_quit_state()
	AppRouter.validation_set_safe_close_guard_target(shell)
	var origin: Button = shell.get_node("%LoadMap")
	origin.grab_focus()
	await get_tree().process_frame
	var before := _protected_state(shell)
	get_tree().root.close_requested.emit()
	await _settle()
	if not _assert_dialog(shell, "quit", "", "Keep Editing", "LoadMap"):
		return {}
	AppRouter.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	await _settle()
	var duplicate: Dictionary = shell.call("validation_dirty_transition_snapshot")
	if int(duplicate.get("duplicate_request_count", 0)) != 1 or int(duplicate.get("request_count", 0)) != 1:
		return _fail_dict("Duplicate native-close notification created another confirmation: %s" % JSON.stringify(duplicate))
	await _press_joypad_button(JOY_BUTTON_B)
	if not await _assert_canceled_exact(shell, before, origin, package_state, "Native close controller B"):
		return {}
	get_tree().root.close_requested.emit()
	await _settle()
	await _press_key(KEY_ESCAPE)
	if not await _assert_canceled_exact(shell, before, origin, package_state, "Native close Escape"):
		return {}
	get_tree().root.close_requested.emit()
	await _settle()
	var confirmed: Dictionary = shell.call("validation_confirm_dirty_transition")
	var router: Dictionary = AppRouter.validation_safe_quit_snapshot()
	var guard: Dictionary = AppRouter.validation_safe_close_guard_snapshot()
	if not bool(confirmed.get("ok", false)) or not bool(confirmed.get("quit_requested", false)) \
			or int(router.get("quit_attempt_count", 0)) != 1 or int(router.get("suppressed_quit_count", 0)) != 1 \
			or int(guard.get("bypass_consume_count", 0)) != 1:
		return _fail_dict("Confirmed native close did not authorize exactly one suppressed quit: %s" % JSON.stringify({"result": confirmed, "router": router, "guard": guard}))
	if _package_file_state() != package_state:
		return _fail_dict("Native-close confirmation mutated shipped package files.")
	return {"ok": true, "cancel_count": 2, "confirm_count": 1, "quit_count": 1, "duplicate_guarded": true}

func _validate_safe_quit_failure_retry(shell: Node, source_id: String, package_state: Dictionary) -> Dictionary:
	var phase_results := {}
	for phase in FAILURE_PHASES:
		var active = _seed_canonical_active_session(40 + phase_results.size())
		if active == null:
			return _fail_dict("Could not seed safe-quit failure phase %s." % phase)
		if not await _reset_case(shell, source_id, true):
			return {}
		AppRouter.validation_set_quit_suppressed(true)
		AppRouter.validation_reset_safe_quit_state()
		AppRouter.validation_set_safe_close_guard_target(shell)
		var origin: Button = shell.get_node("%Menu")
		origin.grab_focus()
		await get_tree().process_frame
		var before := _protected_state(shell)
		var autosave_path := "%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE]
		var old_bytes := FileAccess.get_file_as_bytes(autosave_path)
		OS.set_environment(SAVE_FAILURE_ENV, phase)
		get_tree().root.close_requested.emit()
		await _settle()
		var failed: Dictionary = shell.call("validation_confirm_dirty_transition")
		OS.set_environment(SAVE_FAILURE_ENV, "")
		await _settle()
		var failed_router: Dictionary = AppRouter.validation_safe_quit_snapshot()
		if bool(failed.get("ok", true)) or String(failed.get("reason", "")) != "autosave_failed" \
				or int(failed_router.get("quit_attempt_count", -1)) != 0:
			return _fail_dict("Safe-quit %s failure was not honest: %s" % [phase, JSON.stringify({"result": failed, "router": failed_router})])
		if not _assert_protected_state(shell, before, package_state, "%s safe-quit failure" % phase) \
				or FileAccess.get_file_as_bytes(autosave_path) != old_bytes or _transaction_artifacts_exist(autosave_path):
			return {}
		get_tree().root.close_requested.emit()
		await _settle()
		var retried: Dictionary = shell.call("validation_confirm_dirty_transition")
		var retry_router: Dictionary = AppRouter.validation_safe_quit_snapshot()
		if not bool(retried.get("ok", false)) or int(retry_router.get("quit_attempt_count", 0)) != 1 \
				or int(retry_router.get("suppressed_quit_count", 0)) != 1 or int(retry_router.get("save_attempt_count", 0)) != 2:
			return _fail_dict("Safe-quit %s retry did not save then quit exactly once: %s" % [phase, JSON.stringify({"result": retried, "router": retry_router})])
		phase_results[phase] = {"failure_preserved": true, "retry_quit_count": 1}
	return {"ok": true, "phases": phase_results}

func _validate_clean_controls(shell: Node, source_id: String, target_id: String, package_state: Dictionary) -> Dictionary:
	_seed_canonical_active_session(51)
	if not await _reset_case(shell, source_id, false):
		return {}
	shell.call("validation_set_dirty_transition_routing_enabled", false)
	var menu: Dictionary = shell.call("_on_menu_pressed")
	if not bool(menu.get("ok", false)) or bool(menu.get("pending", true)) or int(menu.get("route_attempt_delta", 0)) != 1:
		return _fail_dict("Clean Menu did not remain direct: %s" % JSON.stringify(menu))
	var selected: Dictionary = shell.call("validation_select_map_package_id", target_id)
	var package: Dictionary = shell.call("_on_load_map_pressed")
	if not bool(selected.get("ok", false)) or not bool(package.get("ok", false)) or not bool(package.get("direct", false)) \
			or bool(package.get("pending", true)) or int(package.get("load_attempt_delta", 0)) != 1:
		return _fail_dict("Clean package load did not remain direct: %s" % JSON.stringify(package))
	AppRouter.validation_set_quit_suppressed(true)
	AppRouter.validation_reset_safe_quit_state()
	AppRouter.validation_set_safe_close_guard_target(shell)
	get_tree().root.close_requested.emit()
	await _settle()
	var close_snapshot: Dictionary = AppRouter.validation_safe_quit_snapshot()
	var transition: Dictionary = shell.call("validation_dirty_transition_snapshot")
	if bool(transition.get("dialog_visible", true)) or int(close_snapshot.get("quit_attempt_count", 0)) != 1 \
			or int(close_snapshot.get("suppressed_quit_count", 0)) != 1:
		return _fail_dict("Clean native close did not remain direct: %s" % JSON.stringify({"router": close_snapshot, "transition": transition}))
	if _package_file_state() != package_state:
		return _fail_dict("Clean controls mutated shipped package files.")
	return {"ok": true, "menu_direct": true, "package_direct": true, "native_close_direct": true}

func _create_editor_shell():
	var layout_host := Control.new()
	layout_host.name = "MapEditorExclusiveLayoutHost"
	layout_host.size = Vector2(1280.0, 720.0)
	add_child(layout_host)
	var shell = load("res://scenes/editor/MapEditorShell.tscn").instantiate()
	shell.set("validation_skip_initial_package_index", true)
	_active_shell = shell
	layout_host.add_child(shell)
	var parent_probe := Button.new()
	parent_probe.name = "MapEditorExclusiveParentProbe"
	parent_probe.text = "Map Editor parent input probe"
	parent_probe.position = Vector2(16.0, 16.0)
	parent_probe.size = Vector2(230.0, 40.0)
	parent_probe.focus_mode = Control.FOCUS_NONE
	parent_probe.z_index = 100
	parent_probe.pressed.connect(_on_parent_probe_pressed)
	layout_host.add_child(parent_probe)
	shell.set_meta("exclusive_parent_probe", parent_probe)
	await _settle()
	AppRouter.validation_set_safe_close_guard_target(shell)
	return shell

func _on_parent_probe_pressed() -> void:
	_parent_probe_count += 1

func _reset_case(shell: Node, source_id: String, dirty: bool) -> bool:
	shell.call("validation_reset_dirty_transition_state")
	AppRouter.validation_reset_safe_quit_state()
	AppRouter.validation_set_safe_close_guard_target(shell)
	shell.set("_map_package_entries", [_source_entry.duplicate(true), _target_entry.duplicate(true)])
	var picker: OptionButton = shell.get_node("%MapPackagePicker")
	picker.clear()
	for entry in [_source_entry, _target_entry]:
		picker.add_item(String(entry.get("display_name", entry.get("package_stem", "Map Package"))))
		picker.set_item_metadata(picker.get_item_count() - 1, String(entry.get("package_id", "")))
	var loaded: bool = bool(shell.call("_load_maps_folder_package_entry_working_copy", _source_entry.duplicate(true)))
	if not loaded:
		_fail("Editor could not load shipped package fixture %s." % source_id)
		return false
	if dirty:
		var session = shell.get("_session")
		var current := String(session.overworld.get("map", [])[0][0])
		var replacement := "forest" if current != "forest" else "grass"
		shell.call("validation_set_tool", "terrain")
		shell.call("validation_select_tile", 0, 0)
		var edit: Dictionary = shell.call("validation_paint_terrain", 0, 0, replacement)
		if not bool(edit.get("ok", false)) or not bool(shell.call("validation_dirty_transition_snapshot").get("dirty", false)):
			_fail("Could not dirty editor working copy deterministically: %s" % JSON.stringify(edit))
			return false
	await _settle()
	return true

func _assert_dialog(shell: Node, action: String, package_id: String, cancel_text: String, origin_name: String) -> bool:
	var snapshot: Dictionary = shell.call("validation_dirty_transition_snapshot")
	var dialog: ConfirmationDialog = shell.get_node("DirtyTransitionConfirmationDialog")
	var cancel_button := dialog.get_cancel_button()
	var focus_owner := cancel_button.get_viewport().gui_get_focus_owner()
	if not bool(snapshot.get("pending", false)) or not bool(snapshot.get("dialog_visible", false)) \
			or String(snapshot.get("action", "")) != action or String(snapshot.get("package_id", "")) != package_id \
			or String(snapshot.get("cancel_text", "")) != cancel_text or String(snapshot.get("return_focus_name", "")) != origin_name \
			or focus_owner != cancel_button:
		_fail("%s confirmation did not open with safe native-dialog focus: %s" % [action, JSON.stringify(snapshot)])
		return false
	return true

func _assert_canceled_exact(shell: Node, before: Dictionary, origin: Control, package_state: Dictionary, label: String) -> bool:
	await _settle()
	var snapshot: Dictionary = shell.call("validation_dirty_transition_snapshot")
	if bool(snapshot.get("pending", true)) or bool(snapshot.get("dialog_visible", true)) or get_viewport().gui_get_focus_owner() != origin:
		_fail("%s did not close and restore exact origin focus: %s" % [label, JSON.stringify(snapshot)])
		return false
	return _assert_protected_state(shell, before, package_state, label)

func _assert_protected_state(shell: Node, before: Dictionary, package_state: Dictionary, label: String) -> bool:
	var after := _protected_state(shell)
	if after != before:
		_fail("%s changed protected editor/session/save state: %s" % [label, _first_difference(before, after)])
		return false
	if _package_file_state() != package_state:
		_fail("%s changed shipped package bytes." % label)
		return false
	return true

func _protected_state(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_dirty_transition_snapshot")
	var session = shell.get("_session")
	return {
		"working_copy": session.to_dict() if session != null else {},
		"dirty": bool(snapshot.get("dirty", false)),
		"tool": String(snapshot.get("tool", "")),
		"selected_tile": snapshot.get("selected_tile", {}).duplicate(true),
		"selected_map_package_id": String(snapshot.get("selected_map_package_id", "")),
		"active_session": SessionState.ensure_active_session().to_dict() if SessionState.has_playable_session() else {},
		"save_files": _save_file_state(),
	}

func _seed_canonical_active_session(day: int):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.day = day
	SessionState.set_active_session(session)
	OS.set_environment(SAVE_FAILURE_ENV, "")
	var saved: Dictionary = SaveService.save_runtime_autosave_session(session)
	if not bool(saved.get("ok", false)):
		return null
	var restored = SaveService.restore_autosave_session()
	if restored == null:
		return null
	SessionState.set_active_session(restored)
	return restored

func _package_files_exist() -> bool:
	for stem in [SOURCE_STEM, TARGET_STEM]:
		for extension in ["amap", "ascenario"]:
			if not FileAccess.file_exists("res://maps/%s.%s" % [stem, extension]):
				return false
	return true

func _copy_fixture_pairs() -> bool:
	var mkdir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE_DIR))
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		return false
	for stem in [SOURCE_STEM, TARGET_STEM]:
		for extension in ["amap", "ascenario"]:
			var source := "res://maps/%s.%s" % [stem, extension]
			var target := "%s/%s.%s" % [FIXTURE_DIR, stem, extension]
			var copy_error := DirAccess.copy_absolute(
				ProjectSettings.globalize_path(source),
				ProjectSettings.globalize_path(target)
			)
			if copy_error != OK:
				return false
	return true

func _package_file_state() -> Dictionary:
	var state := {}
	for stem in [SOURCE_STEM, TARGET_STEM]:
		for extension in ["amap", "ascenario"]:
			for root in ["res://maps", FIXTURE_DIR]:
				var path := "%s/%s.%s" % [root, stem, extension]
				state[path] = {"size": FileAccess.get_size(path), "sha256": FileAccess.get_sha256(path)}
	return state

func _save_file_state() -> Dictionary:
	var state := {}
	var paths: Array[String] = ["%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE]]
	for slot in [1, 2, 3]:
		paths.append("%s/%s%d.json" % [SaveService.SAVE_DIR, SaveService.SAVE_PREFIX, slot])
	for path in paths:
		state[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	return state

func _transaction_artifacts_exist(path: String) -> bool:
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(path)
	return FileAccess.file_exists(String(artifacts.get("candidate", ""))) or FileAccess.file_exists(String(artifacts.get("backup", "")))

func _dirty_transition_opened_exact(snapshot: Dictionary, action: String, target_id: String, origin: Control, dialog: ConfirmationDialog, width: int) -> bool:
	var position: Vector2i = snapshot.get("dialog_position", Vector2i(-1, -1))
	var size: Vector2i = snapshot.get("dialog_size", Vector2i.ZERO)
	return dialog.exclusive and bool(snapshot.get("pending", false)) and bool(snapshot.get("dialog_visible", false)) \
		and String(snapshot.get("action", "")) == action \
		and String(snapshot.get("package_id", "")) == (target_id if action == "package" else "") \
		and String(snapshot.get("cancel_text", "")) == "Keep Editing" \
		and String(snapshot.get("return_focus_name", "")) == String(origin.name) \
		and dialog.get_cancel_button().get_viewport().gui_get_focus_owner() == dialog.get_cancel_button() \
		and position.x >= 0 and position.y >= 0 and position.x + size.x <= width and position.y + size.y <= 720

func _dirty_transaction_snapshot(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_dirty_transition_snapshot")
	var compact := {}
	for key in ["pending", "dialog_visible", "action", "package_id", "package_label", "source", "cancel_text", "confirm_text", "dialog_focus_owner", "return_focus_name", "dialog_position", "dialog_size", "dirty", "request_count", "cancel_count", "confirm_count", "duplicate_request_count", "menu_route_count", "package_action_count", "quit_attempt_count", "routing_enabled", "last_result"]:
		compact[key] = snapshot.get(key)
	return compact

func _exclusive_parent_click_geometry(control: Button, dialog: ConfirmationDialog) -> Dictionary:
	var parent_click := _control_root_click_position(control)
	var parent_rect := _control_root_rect(control)
	var dialog_rect := Rect2(Vector2(dialog.position), Vector2(dialog.size))
	var cancel_button := dialog.get_cancel_button()
	var child_click := _control_root_click_position(cancel_button)
	var child_rect := _control_root_rect(cancel_button)
	return {
		"exact": control.get_viewport() == get_viewport() and control.is_visible_in_tree() and not control.disabled \
			and parent_rect.has_point(parent_click) and get_viewport().get_visible_rect().has_point(parent_click) \
			and not dialog_rect.has_point(parent_click) and cancel_button.get_viewport() == dialog \
			and child_rect.has_point(child_click) and dialog_rect.has_point(child_click) \
			and get_viewport().get_visible_rect().encloses(dialog_rect),
		"parent_click": parent_click,
		"parent_rect": parent_rect,
		"dialog_rect": dialog_rect,
		"child_click": child_click,
	}

func _click_control(control: Control) -> void:
	var source_viewport := control.get_viewport()
	var click_position := _control_root_click_position(control)
	var window_id: int = int(source_viewport.get_window_id()) if source_viewport is Window else 0
	var motion := InputEventMouseMotion.new()
	motion.window_id = window_id
	motion.position = click_position
	motion.global_position = click_position
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	for pressed_state in [true, false]:
		var event := InputEventMouseButton.new()
		event.window_id = window_id
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = click_position
		event.global_position = click_position
		event.pressed = pressed_state
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	await _settle()

func _control_root_click_position(control: Control) -> Vector2:
	var position := control.get_global_rect().get_center()
	var source_viewport := control.get_viewport()
	if source_viewport is Window and source_viewport != get_viewport():
		position += Vector2((source_viewport as Window).position)
	return position

func _control_root_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	var source_viewport := control.get_viewport()
	if source_viewport is Window and source_viewport != get_viewport():
		rect.position += Vector2((source_viewport as Window).position)
	return rect

func _checks_exact(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true

func _full_authority_state(shell: Node) -> Dictionary:
	var editor_snapshot: Dictionary = shell.call("validation_snapshot")
	for key in ["dirty_transition", "focus_owner"]:
		editor_snapshot.erase(key)
	return {
		"protected": _protected_state(shell),
		"editor": editor_snapshot,
		"packages": _package_file_state(),
		"files": _capture_file_states(_tracked_authority_paths()),
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
		"settings": _canonical_settings_transaction(),
		"profile": CampaignProgression.profile.duplicate(true),
		"selected_slot": SaveService.get_selected_manual_slot(),
		"safe_quit": AppRouter.validation_safe_quit_snapshot(),
		"close_guard": AppRouter.validation_safe_close_guard_snapshot(),
		"return_route": AppRouter.validation_active_play_return_snapshot(),
		"outcome_route": AppRouter.validation_scenario_outcome_route_snapshot(),
	}

func _canonical_settings_transaction() -> Dictionary:
	var transaction: Dictionary = SettingsService.validation_settings_transaction_snapshot()
	transaction["input_map"] = _canonical_input_map(transaction.get("input_map", {}))
	var runtime: Dictionary = (transaction.get("runtime_display", {}) as Dictionary).duplicate(true)
	runtime.erase("size")
	runtime.erase("position")
	transaction["runtime_display"] = runtime
	return transaction

func _canonical_input_map(value: Variant) -> Dictionary:
	var input_map: Dictionary = value if value is Dictionary else {}
	var result := {}
	for action_value in input_map:
		var row: Dictionary = input_map.get(action_value, {}) if input_map.get(action_value, {}) is Dictionary else {}
		var events := []
		for event_value in row.get("events", []):
			if event_value is InputEvent:
				events.append(_serialize_input_event(event_value))
		result[String(action_value)] = {"exists": bool(row.get("exists", false)), "deadzone": float(row.get("deadzone", 0.5)), "events": events}
	return result

func _serialize_input_event(input_event: InputEvent) -> Dictionary:
	var properties := {}
	for property_value in input_event.get_property_list():
		var property: Dictionary = property_value
		if (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var property_name := String(property.get("name", ""))
		if property_name == "" or property_name == "script":
			continue
		properties[property_name] = var_to_str(input_event.get(property_name))
	return {"class": input_event.get_class(), "text": input_event.as_text(), "properties": properties}

func _tracked_authority_paths() -> Array[String]:
	var base_paths: Array[String] = [
		"%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE],
		"%s/%s" % [SaveService.SAVE_DIR, SaveService.PROGRESSION_FILE],
		SettingsService.SETTINGS_FILE,
	]
	for slot in [1, 2, 3]:
		base_paths.append("%s/%s%d.json" % [SaveService.SAVE_DIR, SaveService.SAVE_PREFIX, slot])
	for stem in [SOURCE_STEM, TARGET_STEM]:
		for extension in ["amap", "ascenario"]:
			base_paths.append("%s/%s.%s" % [FIXTURE_DIR, stem, extension])
	var paths: Array[String] = []
	for path in base_paths:
		if path not in paths:
			paths.append(path)
		for artifact in SaveService.validation_transaction_artifact_paths(path).values():
			var artifact_path := String(artifact)
			if artifact_path != "" and artifact_path not in paths:
				paths.append(artifact_path)
	for path in [SettingsService.SETTINGS_CANDIDATE_FILE, SettingsService.SETTINGS_BACKUP_FILE]:
		if path not in paths:
			paths.append(path)
	return paths

func _capture_file_states(paths: Array[String]) -> Dictionary:
	var states := {}
	for path in paths:
		states[path] = _file_state(path)
	return states

func _file_state(path: String) -> Dictionary:
	return {"exists": FileAccess.file_exists(path), "bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()}

func _restore_file_state(path: String, state: Dictionary) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not bool(state.get("exists", false)):
		return
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(state.get("bytes", PackedByteArray()))

func _first_difference(expected: Variant, actual: Variant, path: String = "root") -> String:
	if typeof(expected) != typeof(actual):
		return "%s type %s != %s" % [path, typeof(expected), typeof(actual)]
	if expected is Dictionary:
		var keys: Array = expected.keys()
		for key in actual.keys():
			if key not in keys:
				keys.append(key)
		keys.sort_custom(func(a, b): return String(a) < String(b))
		for key in keys:
			if not expected.has(key) or not actual.has(key):
				return "%s.%s presence differs" % [path, key]
			var nested := _first_difference(expected[key], actual[key], "%s.%s" % [path, key])
			if nested != "":
				return nested
		return ""
	if expected is Array:
		if expected.size() != actual.size():
			return "%s size %d != %d" % [path, expected.size(), actual.size()]
		for index in range(expected.size()):
			var nested := _first_difference(expected[index], actual[index], "%s[%d]" % [path, index])
			if nested != "":
				return nested
		return ""
	return "" if expected == actual else "%s differs" % path

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
	await _settle()

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

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _free_shell(shell: Node) -> void:
	AppRouter.validation_set_safe_close_guard_target(null)
	if is_instance_valid(shell) and is_instance_valid(shell.get_parent()):
		shell.get_parent().queue_free()
	await _settle()
	_active_shell = null

func _fail_dict(message: String) -> Dictionary:
	_fail(message)
	return {}

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	_cleanup()
	get_tree().quit(1)

func _cleanup() -> void:
	OS.set_environment(SAVE_FAILURE_ENV, "")
	AppRouter.validation_set_quit_suppressed(true)
	AppRouter.validation_reset_safe_quit_state()
	if is_instance_valid(_active_shell):
		AppRouter.validation_set_safe_close_guard_target(null)
		if is_instance_valid(_active_shell.get_parent()):
			_active_shell.get_parent().queue_free()
	SessionState.active_session = _original_active_session
	CampaignProgression.profile = _original_profile.duplicate(true)
	SaveService.set_selected_manual_slot(_original_selected_slot)
	for path in _original_file_states:
		_restore_file_state(String(path), _original_file_states[path])
	SaveService._slot_summary_cache = _original_summary_cache.duplicate(true)
	get_window().size = _original_window_size
