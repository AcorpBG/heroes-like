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

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_report_scene = self
	_original_active_session = SessionState.active_session
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
		"save_version": SessionState.SAVE_VERSION,
	})])
	await _free_shell(shell)
	_cleanup()
	get_tree().quit(0)

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
		var autosave_path := "user://saves/autosave.json"
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
	var shell = load("res://scenes/editor/MapEditorShell.tscn").instantiate()
	shell.set("validation_skip_initial_package_index", true)
	_active_shell = shell
	add_child(shell)
	await _settle()
	AppRouter.validation_set_safe_close_guard_target(shell)
	return shell

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
	for filename in ["autosave.json", "slot1.json", "slot2.json", "slot3.json"]:
		var path := "user://saves/%s" % filename
		state[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	return state

func _transaction_artifacts_exist(path: String) -> bool:
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(path)
	return FileAccess.file_exists(String(artifacts.get("candidate", ""))) or FileAccess.file_exists(String(artifacts.get("backup", "")))

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
	if is_instance_valid(shell):
		shell.queue_free()
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
		_active_shell.queue_free()
	SessionState.active_session = _original_active_session
	for stem in [SOURCE_STEM, TARGET_STEM]:
		for extension in ["amap", "ascenario"]:
			var path := "%s/%s.%s" % [FIXTURE_DIR, stem, extension]
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
