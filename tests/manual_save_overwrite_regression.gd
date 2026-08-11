extends Node

const REPORT_ID := "MANUAL_SAVE_OVERWRITE_REGRESSION"
const CAPTURE_DIR := "res://.artifacts/manual_save_overwrite_regression"

var _original_file_states := {}
var _original_active_session = null
var _original_campaign_profile := {}
var _original_settings := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_original_file_states = _capture_file_states(_tracked_paths())
	_original_active_session = SessionState.active_session
	_original_campaign_profile = CampaignProgression.ensure_profile().duplicate(true)
	_original_settings = SettingsService.settings.duplicate(true)

	var protected_fixture = ScenarioFactory.create_session("river-pass", "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	protected_fixture.day = 5
	if SaveService.save_manual_session(protected_fixture.to_dict(), 1) == "":
		_fail("Could not seed Manual Slot 1.")
		return
	if SaveService.save_manual_session(protected_fixture.to_dict(), 3) == "":
		_fail("Could not seed Manual Slot 3.")
		return
	if SaveService.save_autosave_session(protected_fixture.to_dict()) == "":
		_fail("Could not seed autosave.")
		return
	var protected_states := _capture_file_states([
		_manual_slot_path(1),
		_manual_slot_path(3),
		_autosave_path(),
		_progression_path(),
		String(SettingsService.SETTINGS_FILE),
	])
	var campaign_before := CampaignProgression.ensure_profile().duplicate(true)
	var settings_before := SettingsService.settings.duplicate(true)
	var slot1_before_invalid := _file_state(_manual_slot_path(1))
	var active_for_invalid = SessionState.set_active_session(protected_fixture)
	var invalid_action := SaveService.build_manual_save_action(active_for_invalid, 99)
	var invalid_result := AppRouter.save_active_session_to_manual_slot(99)
	if not bool(invalid_action.get("disabled", false)) or bool(invalid_result.get("ok", true)) or _file_state(_manual_slot_path(1)) != slot1_before_invalid:
		_fail("Invalid manual slot 99 was not rejected without changing Manual Slot 1.")
		return

	if not await _exercise_town_cancel_ownership(protected_states, campaign_before, settings_before):
		return

	var route_specs := [
		{"id": "overworld", "scene": "res://scenes/overworld/OverworldShell.tscn", "day": 11},
		{"id": "town", "scene": "res://scenes/town/TownShell.tscn", "day": 12},
		{"id": "battle", "scene": "res://scenes/battle/BattleShell.tscn", "day": 13},
		{"id": "outcome", "scene": "res://scenes/results/ScenarioOutcomeShell.tscn", "day": 14},
	]
	for route_value in route_specs:
		var route: Dictionary = route_value
		if not await _exercise_route(route, protected_states, campaign_before, settings_before):
			return

	if not await _exercise_empty_slot(protected_states, campaign_before, settings_before):
		return
	if not await _exercise_corrupt_slot(protected_states, campaign_before, settings_before):
		return

	_restore_original_state()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"confirmed_routes": ["overworld", "town", "battle", "outcome"],
		"empty_slot_direct_save": true,
		"occupied_slot_confirmation": true,
		"corrupt_slot_confirmation": true,
		"cancel_preserved_exact_bytes": true,
		"safe_cancel_focus": "Keep Save",
		"joypad_b_cancel_exact": true,
		"escape_cancel_exact": true,
		"town_occupied_wide_escape_cancel_exact": true,
		"town_occupied_narrow_joypad_cancel_exact": true,
		"town_unreadable_wide_joypad_cancel_exact": true,
		"town_unreadable_narrow_escape_cancel_exact": true,
		"town_modal_cancel_count_exact": true,
		"town_modal_pending_action_cleared": true,
		"town_modal_route_handoff_preserved": true,
		"town_narrow_back_resumed": true,
		"town_post_modal_leave_exact": true,
		"town_save_slot_popup_cancel_unchanged": true,
		"town_settings_cancel_unchanged": true,
		"town_mouse_confirm_exact": true,
		"origin_focus_restored": true,
		"confirm_exactly_once": true,
		"pending_slot_binding_preserved": true,
		"invalid_slot_rejected": true,
		"unrelated_manual_slots_preserved": 2,
		"autosave_preserved": true,
		"campaign_progression_preserved": true,
		"device_settings_preserved": true,
		"active_session_preserved": true,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)

func _exercise_route(
	route: Dictionary,
	protected_states: Dictionary,
	campaign_before: Dictionary,
	settings_before: Dictionary
) -> bool:
	var old_fixture = ScenarioFactory.create_session("river-pass", "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	old_fixture.day = 3
	if SaveService.save_manual_session(old_fixture.to_dict(), 2) == "":
		return _fail_bool("Could not seed occupied Manual Slot 2 for %s." % String(route.get("id", "route")))
	var slot2_before := _file_state(_manual_slot_path(2))

	var session = _session_for_route(String(route.get("id", "")), int(route.get("day", 1)))
	if session == null:
		return _fail_bool("Could not create %s route fixture." % String(route.get("id", "route")))
	session = SessionState.set_active_session(session)
	SaveService.set_selected_manual_slot(2)
	var shell = load(String(route.get("scene", ""))).instantiate()
	add_child(shell)
	await _settle()
	var active_payload: Dictionary = session.to_dict()
	var origin_button: Button = shell.get_node("%Save")
	var dialog: ConfirmationDialog = shell.get_node("ManualSaveOverwriteDialog")
	origin_button.grab_focus()
	await get_tree().process_frame

	var request: Dictionary = shell.call("validation_request_manual_save")
	await _settle()
	var request_text := "%s\n%s" % [String(request.get("title", "")), String(request.get("text", ""))]
	if not bool(request.get("visible", false)) or int(request.get("pending_slot", 0)) != 2:
		return _fail_shell(shell, "%s did not require Manual Slot 2 confirmation: %s." % [route.get("id", "route"), JSON.stringify(request)])
	for token in ["Manual Slot 2", "Day 3", "Day %d" % int(route.get("day", 1)), "Other manual saves", "autosave"]:
		if not request_text.contains(token):
			return _fail_shell(shell, "%s overwrite confirmation omitted %s: %s." % [route.get("id", "route"), token, request_text])
	if _file_state(_manual_slot_path(2)) != slot2_before:
		return _fail_shell(shell, "%s confirmation request changed Manual Slot 2 before approval." % route.get("id", "route"))
	if not _safe_dialog_ready(dialog, "Keep Save"):
		return _fail_shell(shell, "%s overwrite confirmation did not focus its compact Keep Save action." % route.get("id", "route"))

	if String(route.get("id", "")) == "overworld":
		await _capture("overwrite_confirmation")
		await _press_joypad_button(JOY_BUTTON_B)
		if dialog.visible or get_viewport().gui_get_focus_owner() != origin_button \
				or _file_state(_manual_slot_path(2)) != slot2_before \
				or not _require_preserved_state(protected_states, active_payload, campaign_before, settings_before, _manual_slot_path(2)):
			return _fail_shell(shell, "Joypad B did not cancel overwrite exactly and restore Save focus.")
		request = shell.call("validation_request_manual_save")
		await _settle()
		if not bool(request.get("visible", false)) or not _safe_dialog_ready(dialog, "Keep Save"):
			return _fail_shell(shell, "Overwrite confirmation did not reopen safely after joypad cancellation.")
		await _press_key(KEY_ESCAPE)
		if dialog.visible or get_viewport().gui_get_focus_owner() != origin_button \
				or _file_state(_manual_slot_path(2)) != slot2_before \
				or not _require_preserved_state(protected_states, active_payload, campaign_before, settings_before, _manual_slot_path(2)):
			return _fail_shell(shell, "Escape did not cancel overwrite exactly and restore Save focus.")
		request = shell.call("validation_request_manual_save")
		await _settle()
		if not bool(request.get("visible", false)) or not _safe_dialog_ready(dialog, "Keep Save"):
			return _fail_shell(shell, "Overwrite confirmation did not reopen safely for confirmation.")

	if not bool(shell.call("validation_select_save_slot", 3)):
		return _fail_shell(shell, "%s could not change visible selection while confirmation was pending." % route.get("id", "route"))
	var slot3_before := _file_state(_manual_slot_path(3))
	var result := {"pending_slot": 2}
	if String(route.get("id", "")) == "town":
		dialog.get_ok_button().grab_focus()
		await get_tree().process_frame
		await _press_joypad_button(JOY_BUTTON_A)
	else:
		result = shell.call("validation_confirm_manual_save_overwrite")
	var dialog_after_confirm: Dictionary = dialog.validation_snapshot()
	var saved_summary := SaveService.inspect_manual_slot(2)
	if int(result.get("pending_slot", 0)) != 2 or not SaveService.can_load_summary(saved_summary) or int(saved_summary.get("day", 0)) != int(route.get("day", 0)):
		return _fail_shell(shell, "%s confirmation did not write the originally bound Manual Slot 2: %s." % [route.get("id", "route"), JSON.stringify(result)])
	if _file_state(_manual_slot_path(3)) != slot3_before:
		return _fail_shell(shell, "%s redirected overwrite into the later-selected Manual Slot 3." % route.get("id", "route"))
	if int(dialog_after_confirm.get("confirm_count", 1)) != 1:
		return _fail_shell(shell, "%s overwrite confirmation did not execute exactly once: %s." % [route.get("id", "route"), JSON.stringify(dialog_after_confirm)])
	if not _require_preserved_state(protected_states, active_payload, campaign_before, settings_before, _manual_slot_path(2)):
		return false
	shell.queue_free()
	await _settle()
	return true

func _exercise_town_cancel_ownership(
	protected_states: Dictionary,
	campaign_before: Dictionary,
	settings_before: Dictionary
) -> bool:
	var original_window_size := get_window().size
	var cases := [
		{"id": "unreadable_narrow_escape", "width": 960, "corrupt": true, "joypad": false, "day": 34},
		{"id": "occupied_narrow_joypad", "width": 960, "corrupt": false, "joypad": true, "day": 32},
		{"id": "occupied_wide_escape", "width": 1440, "corrupt": false, "joypad": false, "day": 31},
		{"id": "unreadable_wide_joypad", "width": 1440, "corrupt": true, "joypad": true, "day": 33},
	]
	for case_value in cases:
		var case: Dictionary = case_value
		if not await _exercise_town_cancel_case(case, protected_states, campaign_before, settings_before):
			get_window().size = original_window_size
			await _settle()
			return false
	if not await _exercise_town_mouse_confirm(protected_states, campaign_before, settings_before):
		get_window().size = original_window_size
		await _settle()
		return false
	get_window().size = original_window_size
	await _settle()
	return true

func _exercise_town_cancel_case(
	case: Dictionary,
	protected_states: Dictionary,
	campaign_before: Dictionary,
	settings_before: Dictionary
) -> bool:
	var old_fixture = ScenarioFactory.create_session("river-pass", "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	old_fixture.day = 3
	if bool(case.get("corrupt", false)):
		var corrupt_file := FileAccess.open(_manual_slot_path(2), FileAccess.WRITE)
		if corrupt_file == null:
			return _fail_bool("Could not create Town unreadable Manual Slot 2 fixture.")
		corrupt_file.store_string(JSON.stringify({"not_a_session": true, "case": String(case.get("id", ""))}))
		corrupt_file.close()
	else:
		if SaveService.save_manual_session(old_fixture.to_dict(), 2) == "":
			return _fail_bool("Could not seed Town occupied Manual Slot 2 fixture.")
	SaveService.validation_clear_summary_cache()
	var slot2_before := _file_state(_manual_slot_path(2))
	var session = _session_for_route("town", int(case.get("day", 31)))
	if session == null:
		return _fail_bool("Could not create Town cancel-ownership fixture %s." % String(case.get("id", "case")))
	session = SessionState.set_active_session(session)
	SaveService.set_selected_manual_slot(2)
	get_window().size = Vector2i(int(case.get("width", 1440)), 720)
	await _settle()
	var layout_host := Control.new()
	layout_host.name = "TownLayoutHost_%s" % String(case.get("id", "case"))
	layout_host.size = Vector2(float(case.get("width", 1440)), 720.0)
	add_child(layout_host)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	layout_host.add_child(shell)
	await _settle()
	var snapshot: Dictionary = shell.validation_snapshot()
	var expects_narrow := int(case.get("width", 1440)) < 1100
	if bool(snapshot.get("narrow_layout_active", not expects_narrow)) != expects_narrow:
		return _fail_shell(shell, "Town cancel fixture did not enter its exact wide/narrow layout: %s." % JSON.stringify(case))
	if expects_narrow:
		var toggle: Dictionary = shell.validation_toggle_narrow_town_orders()
		await _settle()
		if not bool(toggle.get("ok", false)) or not bool(shell.validation_snapshot().get("narrow_orders_open", false)):
			return _fail_shell(shell, "Town cancel fixture could not open narrow orders: %s." % JSON.stringify(case))
	var save_button: Button = shell.get_node("%Save")
	var dialog: ConfirmationDialog = shell.get_node("ManualSaveOverwriteDialog")
	save_button.grab_focus()
	await get_tree().process_frame
	var request: Dictionary = shell.validation_request_manual_save()
	await _settle()
	var request_snapshot: Dictionary = dialog.validation_snapshot()
	var expected_unreadable := bool(case.get("corrupt", false))
	if not bool(request.get("visible", false)) \
			or int(request_snapshot.get("pending_slot", 0)) != 2 \
			or not (request_snapshot.get("action", {}) is Dictionary) \
			or (String(request_snapshot.get("text", "")).contains("Unreadable expedition save") != expected_unreadable) \
			or not _safe_dialog_ready(dialog, "Keep Save"):
		return _fail_shell(shell, "Town cancel fixture did not open the exact occupied/unreadable confirmation: case=%s request=%s." % [JSON.stringify(case), JSON.stringify(request_snapshot)])
	var authority_before := _town_modal_authority_signature(shell, session)
	if bool(case.get("joypad", false)):
		await _press_joypad_button(JOY_BUTTON_B)
	else:
		await _press_key(KEY_ESCAPE)
	var after: Dictionary = dialog.validation_snapshot()
	var focus_owner := get_viewport().gui_get_focus_owner()
	if bool(after.get("visible", true)) \
			or int(after.get("pending_slot", -1)) != 0 \
			or not (after.get("action", null) is Dictionary) \
			or not (after.get("action", {}).is_empty()) \
			or int(after.get("request_count", -1)) != int(request_snapshot.get("request_count", 0)) \
			or int(after.get("cancel_count", -1)) != int(request_snapshot.get("cancel_count", 0)) + 1 \
			or int(after.get("confirm_count", -1)) != int(request_snapshot.get("confirm_count", 0)) \
			or focus_owner != save_button \
			or _file_state(_manual_slot_path(2)) != slot2_before \
			or _town_modal_authority_signature(shell, session) != authority_before \
			or not _require_preserved_state(protected_states, session.to_dict(), campaign_before, settings_before, _manual_slot_path(2)):
		return _fail_shell(shell, "Town physical cancel escaped modal ownership or changed authority: case=%s before=%s after=%s focus=%s." % [JSON.stringify(case), JSON.stringify(request_snapshot), JSON.stringify(after), String(focus_owner.name) if focus_owner != null else ""])
	if bool(shell.validation_snapshot().get("narrow_orders_open", false)) != expects_narrow:
		return _fail_shell(shell, "Town modal cancel also changed narrow-order ownership: %s." % JSON.stringify(case))
	if expects_narrow:
		var post_modal_authority := _town_modal_authority_signature(shell, session)
		await _press_joypad_button(JOY_BUTTON_B)
		if bool(shell.validation_snapshot().get("narrow_orders_open", true)) \
				or _town_modal_authority_signature(shell, session) != post_modal_authority:
			return _fail_shell(shell, "Ordinary post-modal Town Back did not close narrow orders without leaving.")
	elif String(case.get("id", "")) == "occupied_wide_escape":
		if not await _exercise_town_native_modal_controls(shell, session):
			return false
	if String(case.get("id", "")) in ["occupied_wide_escape", "occupied_narrow_joypad"]:
		return await _exercise_town_post_modal_leave(shell, layout_host, session, protected_states, campaign_before, settings_before)
	layout_host.queue_free()
	await _settle()
	return true

func _exercise_town_post_modal_leave(
	shell,
	layout_host: Control,
	session,
	protected_states: Dictionary,
	campaign_before: Dictionary,
	settings_before: Dictionary
) -> bool:
	var session_before: Dictionary = session.to_dict()
	var flags_before: Dictionary = session_before.get("flags", {}).duplicate(true) if session_before.get("flags", {}) is Dictionary else {}
	var expected_handoff: Dictionary = shell.validation_prepare_town_return_handoff()
	session.flags = flags_before.duplicate(true)
	var files_before := _capture_file_states(_tracked_paths())
	var save_cache_before := SaveService.validation_summary_cache_snapshot()
	var settings_transaction_before := _settings_transaction_route_authority()
	var tree := get_tree()
	shell.reparent(tree.root)
	tree.current_scene = shell
	await get_tree().process_frame
	await _press_joypad_button(JOY_BUTTON_B)
	var routed_scene := tree.current_scene
	var route_profile: Dictionary = AppRouter.validation_latest_overworld_handoff_profile()
	var active_session = SessionState.active_session
	var actual_payload: Dictionary = active_session.to_dict() if active_session != null else {}
	var actual_flags: Dictionary = actual_payload.get("flags", {}).duplicate(true) if actual_payload.get("flags", {}) is Dictionary else {}
	var routed_snapshot: Dictionary = routed_scene.validation_snapshot() if routed_scene != null and routed_scene.has_method("validation_snapshot") else {}
	var actual_handoff: Dictionary = routed_snapshot.get("field_return_handoff", {}) if routed_snapshot.get("field_return_handoff", {}) is Dictionary else {}
	var actual_without_route := actual_payload.duplicate(true)
	var expected_without_route := session_before.duplicate(true)
	actual_without_route["game_state"] = String(expected_without_route.get("game_state", "town"))
	var actual_compare_flags: Dictionary = actual_without_route.get("flags", {}).duplicate(true) if actual_without_route.get("flags", {}) is Dictionary else {}
	var expected_compare_flags: Dictionary = expected_without_route.get("flags", {}).duplicate(true) if expected_without_route.get("flags", {}) is Dictionary else {}
	for key in [OverworldRules.ACTIVE_TOWN_PLACEMENT_KEY, "town_return_handoff", "last_action", "last_overworld_action_recap"]:
		actual_compare_flags.erase(key)
		expected_compare_flags.erase(key)
	actual_without_route["flags"] = actual_compare_flags
	expected_without_route["flags"] = expected_compare_flags
	var step_counts := {}
	for step_value in route_profile.get("steps", []):
		if step_value is Dictionary:
			var step_name := String(step_value.get("name", ""))
			step_counts[step_name] = int(step_counts.get(step_name, 0)) + 1
	var overworld_reached: bool = routed_scene != null and String(routed_scene.scene_file_path) == "res://scenes/overworld/OverworldShell.tscn"
	var route_exact: bool = String(route_profile.get("reason", "")) == "town_exit" \
			and not bool(route_profile.get("active", true)) \
			and int(step_counts.get("town_exit_button_pressed", 0)) == 1 \
			and int(step_counts.get("town_return_handoff_prepared", 0)) == 1 \
			and int(step_counts.get("go_to_overworld_change_scene_requested", 0)) == 1 \
			and int(step_counts.get("profile_finished", 0)) == 1
	var settings_transaction_after := _settings_transaction_route_authority()
	var runtime_display_before: Dictionary = settings_transaction_before.get("runtime_display", {}) if settings_transaction_before.get("runtime_display", {}) is Dictionary else {}
	var runtime_display_after: Dictionary = settings_transaction_after.get("runtime_display", {}) if settings_transaction_after.get("runtime_display", {}) is Dictionary else {}
	var result_checks := {
		"overworld_reached": overworld_reached,
		"session_identity": active_session == session,
		"handoff_exact": actual_handoff == expected_handoff,
		"last_action_exact": String(actual_flags.get("last_action", "")) == "left_town",
		"action_recap_exact": actual_flags.get("last_overworld_action_recap", {}) == expected_handoff.get("post_action_recap", {}),
		"transient_handoff_consumed": not actual_flags.has("town_return_handoff"),
		"active_town_cleared": not actual_flags.has(OverworldRules.ACTIVE_TOWN_PLACEMENT_KEY),
		"remaining_session_exact": actual_without_route == expected_without_route,
		"route_exact_once": route_exact,
		"files_exact": _capture_file_states(_tracked_paths()) == files_before,
		"save_cache_exact": SaveService.validation_summary_cache_snapshot() == save_cache_before,
		"settings_file_path_exact": settings_transaction_after.get("settings_file", null) == settings_transaction_before.get("settings_file", null),
		"settings_candidate_path_exact": settings_transaction_after.get("candidate_file", null) == settings_transaction_before.get("candidate_file", null),
		"settings_backup_path_exact": settings_transaction_after.get("backup_file", null) == settings_transaction_before.get("backup_file", null),
		"settings_live_exists_exact": settings_transaction_after.get("live_exists", null) == settings_transaction_before.get("live_exists", null),
		"settings_candidate_exists_exact": settings_transaction_after.get("candidate_exists", null) == settings_transaction_before.get("candidate_exists", null),
		"settings_backup_exists_exact": settings_transaction_after.get("backup_exists", null) == settings_transaction_before.get("backup_exists", null),
		"settings_live_exact": settings_transaction_after.get("settings", null) == settings_transaction_before.get("settings", null),
		"settings_committed_exact": settings_transaction_after.get("committed_settings", null) == settings_transaction_before.get("committed_settings", null),
		"settings_last_result_exact": settings_transaction_after.get("last_result", null) == settings_transaction_before.get("last_result", null),
		"settings_input_map_exact": settings_transaction_after.get("input_map", null) == settings_transaction_before.get("input_map", null),
		"settings_runtime_mode_exact": runtime_display_after.get("mode", null) == runtime_display_before.get("mode", null),
		"settings_runtime_borderless_exact": runtime_display_after.get("borderless", null) == runtime_display_before.get("borderless", null),
		"settings_runtime_screen_exact": runtime_display_after.get("screen", null) == runtime_display_before.get("screen", null),
		"settings_whole_transaction_exact": settings_transaction_after == settings_transaction_before,
		"protected_authority_exact": _require_preserved_state(protected_states, actual_payload, campaign_before, settings_before, _manual_slot_path(2)),
	}
	var result_ok: bool = true
	for check_value in result_checks.values():
		result_ok = result_ok and bool(check_value)
	if routed_scene != null and is_instance_valid(routed_scene):
		tree.current_scene = self
		routed_scene.queue_free()
	if layout_host != null and is_instance_valid(layout_host):
		layout_host.queue_free()
	await _settle()
	if not result_ok:
		return _fail_bool("Fresh post-modal Town Back did not leave exactly once through the real Overworld handoff: checks=%s route=%s expected_handoff=%s actual_handoff=%s settings_before=%s settings_after=%s." % [JSON.stringify(result_checks), JSON.stringify(route_profile), JSON.stringify(expected_handoff), JSON.stringify(actual_handoff), JSON.stringify(settings_transaction_before), JSON.stringify(settings_transaction_after)])
	return true

func _settings_transaction_route_authority() -> Dictionary:
	var snapshot: Dictionary = SettingsService.validation_settings_transaction_snapshot()
	var runtime_display: Dictionary = snapshot.get("runtime_display", {}).duplicate(true) if snapshot.get("runtime_display", {}) is Dictionary else {}
	var input_map: Dictionary = snapshot.get("input_map", {}).duplicate(true) if snapshot.get("input_map", {}) is Dictionary else {}
	# The wide/narrow fixture owns window geometry, and the real Town-to-Overworld
	# scene transition may finish applying that geometry asynchronously. Preserve
	# every settings transaction field and stable display mode while excluding only
	# the fixture-owned size/position pair from this post-route authority check.
	runtime_display.erase("size")
	runtime_display.erase("position")
	snapshot["runtime_display"] = runtime_display
	# SettingsService intentionally returns duplicated InputEvent resources. Convert
	# only those identity-bearing values to the same exact semantic representation
	# used by the settings transaction regression before comparing snapshots.
	for action_id in input_map:
		var action_state: Dictionary = input_map.get(action_id, {}).duplicate(true) if input_map.get(action_id, {}) is Dictionary else {}
		var serialized_events := []
		var events: Variant = action_state.get("events", [])
		if events is Array:
			for input_event in events:
				serialized_events.append(_serialize_settings_input_event(input_event) if input_event is InputEvent else input_event)
		action_state["events"] = serialized_events
		input_map[action_id] = action_state
	snapshot["input_map"] = input_map
	return snapshot

func _serialize_settings_input_event(input_event: InputEvent) -> Dictionary:
	var properties := {}
	for property_value in input_event.get_property_list():
		var property: Dictionary = property_value
		if (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var name := String(property.get("name", ""))
		if name == "" or name == "script":
			continue
		properties[name] = var_to_str(input_event.get(name))
	return {
		"class": input_event.get_class(),
		"text": input_event.as_text(),
		"properties": properties,
	}

func _exercise_town_mouse_confirm(
	protected_states: Dictionary,
	campaign_before: Dictionary,
	settings_before: Dictionary
) -> bool:
	var old_fixture = ScenarioFactory.create_session("river-pass", "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	old_fixture.day = 3
	if SaveService.save_manual_session(old_fixture.to_dict(), 2) == "":
		return _fail_bool("Could not seed Town mouse-confirm Manual Slot 2 fixture.")
	SaveService.validation_clear_summary_cache()
	var session = _session_for_route("town", 35)
	session = SessionState.set_active_session(session)
	SaveService.set_selected_manual_slot(2)
	get_window().size = Vector2i(1440, 720)
	await _settle()
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var save_button: Button = shell.get_node("%Save")
	var dialog: ConfirmationDialog = shell.get_node("ManualSaveOverwriteDialog")
	save_button.grab_focus()
	await get_tree().process_frame
	var request: Dictionary = shell.validation_request_manual_save()
	await _settle()
	if not bool(request.get("visible", false)) or not _safe_dialog_ready(dialog, "Keep Save"):
		return _fail_shell(shell, "Town mouse-confirm fixture did not open occupied overwrite confirmation.")
	if not bool(shell.validation_select_save_slot(3)):
		return _fail_shell(shell, "Town mouse-confirm fixture could not move visible selection to Manual Slot 3.")
	var slot3_before := _file_state(_manual_slot_path(3))
	var active_payload: Dictionary = session.to_dict()
	var dialog_before: Dictionary = dialog.validation_snapshot()
	var routes_before := AppRouter.validation_active_play_return_snapshot()
	var handoff_before := AppRouter.validation_latest_overworld_handoff_profile()
	var ok_button: Button = dialog.get_ok_button()
	var source_viewport: Viewport = ok_button.get_viewport()
	var runner_viewport: Viewport = get_viewport()
	var source_window: Window = source_viewport as Window
	var root_click_position := _control_root_click_position(ok_button)
	var source_rect := Rect2(Vector2(source_window.position), Vector2(source_window.size)) if source_window != null else Rect2()
	if source_window == null \
			or source_viewport == runner_viewport \
			or not runner_viewport.get_visible_rect().encloses(source_rect) \
			or not source_rect.has_point(root_click_position):
		return _fail_shell(shell, "Town mouse-confirm button/window geometry did not map inside the runner viewport: source=%s source_rect=%s click=%s root=%s." % [source_viewport, source_rect, root_click_position, runner_viewport.get_visible_rect()])
	await _click_control(ok_button)
	var dialog_after: Dictionary = dialog.validation_snapshot()
	var summary: Dictionary = SaveService.inspect_manual_slot(2)
	var profile: Dictionary = SaveService.validation_last_runtime_save_profile()
	var step_counts := {}
	for step_value in profile.get("steps", []):
		if step_value is Dictionary:
			var step_name := String(step_value.get("name", ""))
			step_counts[step_name] = int(step_counts.get(step_name, 0)) + 1
	if bool(dialog_after.get("visible", true)) \
			or int(dialog_after.get("pending_slot", -1)) != 0 \
			or not (dialog_after.get("action", {}) is Dictionary) \
			or not dialog_after.get("action", {}).is_empty() \
			or int(dialog_after.get("request_count", -1)) != int(dialog_before.get("request_count", 0)) \
			or int(dialog_after.get("confirm_count", -1)) != int(dialog_before.get("confirm_count", 0)) + 1 \
			or int(dialog_after.get("cancel_count", -1)) != int(dialog_before.get("cancel_count", 0)) \
			or not SaveService.can_load_summary(summary) \
			or int(summary.get("day", 0)) != 35 \
			or _file_state(_manual_slot_path(3)) != slot3_before \
			or String(profile.get("slot_type", "")) != SaveService.SLOT_TYPE_MANUAL \
			or String(profile.get("path", "")) != _manual_slot_path(2) \
			or int(profile.get("written_bytes", 0)) != FileAccess.get_size(_manual_slot_path(2)) \
			or int(profile.get("recovery_count", 0)) != 1 \
			or not bool(profile.get("prepared_payload", false)) \
			or int(step_counts.get("write_payload_start", 0)) != 1 \
			or int(step_counts.get("finished", 0)) != 1 \
			or session.to_dict() != active_payload \
			or AppRouter.validation_active_play_return_snapshot() != routes_before \
			or AppRouter.validation_latest_overworld_handoff_profile() != handoff_before \
			or not _require_preserved_state(protected_states, active_payload, campaign_before, settings_before, _manual_slot_path(2)):
		return _fail_shell(shell, "Town mouse overwrite did not remain slot-bound and write exactly once: before=%s after=%s summary=%s profile=%s." % [JSON.stringify(dialog_before), JSON.stringify(dialog_after), JSON.stringify(summary), JSON.stringify(profile)])
	shell.queue_free()
	await _settle()
	return true

func _exercise_town_native_modal_controls(shell, session) -> bool:
	var picker: OptionButton = shell.get_node("%SaveSlot")
	picker.grab_focus()
	picker.show_popup()
	await _settle()
	if not picker.get_popup().visible:
		return _fail_shell(shell, "Town SaveSlot popup did not open for cancel-ownership control.")
	var popup_authority := _town_modal_authority_signature(shell, session)
	await _press_joypad_button(JOY_BUTTON_B)
	if picker.get_popup().visible or _town_modal_authority_signature(shell, session) != popup_authority:
		return _fail_shell(shell, "Town SaveSlot popup cancel no longer remained GUI-owned.")
	var settings_button: Button = shell.get_node("%Settings")
	settings_button.grab_focus()
	await get_tree().process_frame
	var settings_before: Dictionary = shell.validation_open_active_play_settings()
	var settings_dialog = shell.validation_active_play_settings_dialog()
	await _settle()
	if not bool(settings_before.get("visible", false)):
		return _fail_shell(shell, "Town Settings control did not open for cancel-ownership control.")
	var settings_authority := _town_modal_authority_signature(shell, session)
	await _press_key(KEY_ESCAPE)
	if settings_dialog.is_open() \
			or get_viewport().gui_get_focus_owner() != settings_button \
			or _town_modal_authority_signature(shell, session) != settings_authority:
		return _fail_shell(shell, "Town Settings cancel no longer remained owned by the native modal.")
	return true

func _town_modal_authority_signature(shell, session) -> String:
	var shell_route: Dictionary = shell.validation_active_play_return_snapshot()
	shell_route.erase("focus_owner")
	return JSON.stringify({
		"session": session.to_dict(),
		"files": _capture_file_states(_tracked_paths()),
		"save_profile": SaveService.validation_last_runtime_save_profile(),
		"save_cache": SaveService.validation_summary_cache_snapshot(),
		"settings": SettingsService.validation_settings_transaction_snapshot(),
		"shell_route": shell_route,
		"app_route": AppRouter.validation_active_play_return_snapshot(),
		"overworld_handoff": AppRouter.validation_latest_overworld_handoff_profile(),
		"town_cache": shell.validation_town_entity_cache_snapshot(),
	})

func _click_control(control: Control) -> void:
	var source_viewport := control.get_viewport()
	# Route through the runner viewport so its embedded-window manager can deliver
	# the physical mouse event into the ConfirmationDialog subwindow.
	var viewport := get_viewport()
	var click_position := _control_root_click_position(control)
	var window_id: int = int(source_viewport.get_window_id()) if source_viewport is Window else 0
	var motion := InputEventMouseMotion.new()
	motion.window_id = window_id
	motion.position = click_position
	motion.global_position = click_position
	viewport.push_input(motion, true)
	await get_tree().process_frame
	var pressed := InputEventMouseButton.new()
	pressed.window_id = window_id
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.position = click_position
	pressed.global_position = click_position
	pressed.pressed = true
	viewport.push_input(pressed, true)
	await get_tree().process_frame
	var released := InputEventMouseButton.new()
	released.window_id = window_id
	released.button_index = MOUSE_BUTTON_LEFT
	released.position = click_position
	released.global_position = click_position
	released.pressed = false
	viewport.push_input(released, true)
	await _settle()

func _control_root_click_position(control: Control) -> Vector2:
	var click_position := control.get_global_rect().get_center()
	var source_viewport := control.get_viewport()
	var runner_viewport := get_viewport()
	if source_viewport is Window and source_viewport != runner_viewport:
		click_position += Vector2((source_viewport as Window).position)
	return click_position

func _exercise_empty_slot(
	protected_states: Dictionary,
	campaign_before: Dictionary,
	settings_before: Dictionary
) -> bool:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_manual_slot_path(2)))
	var session = _session_for_route("overworld", 20)
	session = SessionState.set_active_session(session)
	SaveService.set_selected_manual_slot(2)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var active_payload: Dictionary = session.to_dict()
	var request: Dictionary = shell.call("validation_request_manual_save")
	var summary := SaveService.inspect_manual_slot(2)
	if bool(request.get("visible", false)) or int(request.get("pending_slot", 0)) != 0 or not SaveService.can_load_summary(summary) or int(summary.get("day", 0)) != 20:
		return _fail_shell(shell, "Empty Manual Slot 2 did not save immediately: %s." % JSON.stringify(request))
	if not _require_preserved_state(protected_states, active_payload, campaign_before, settings_before, _manual_slot_path(2)):
		return false
	shell.queue_free()
	await _settle()
	return true

func _exercise_corrupt_slot(
	protected_states: Dictionary,
	campaign_before: Dictionary,
	settings_before: Dictionary
) -> bool:
	var corrupt_file := FileAccess.open(_manual_slot_path(2), FileAccess.WRITE)
	if corrupt_file == null:
		return _fail_bool("Could not create corrupt Manual Slot 2 fixture.")
	corrupt_file.store_string(JSON.stringify({"not_a_session": true}))
	corrupt_file.close()
	var corrupt_before := _file_state(_manual_slot_path(2))
	var session = _session_for_route("overworld", 21)
	session = SessionState.set_active_session(session)
	SaveService.set_selected_manual_slot(2)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var active_payload: Dictionary = session.to_dict()
	var request: Dictionary = shell.call("validation_request_manual_save")
	if not bool(request.get("visible", false)) or not String(request.get("text", "")).contains("Unreadable expedition save"):
		return _fail_shell(shell, "Corrupt Manual Slot 2 did not require an unreadable-save confirmation: %s." % JSON.stringify(request))
	shell.call("validation_cancel_manual_save_overwrite")
	if _file_state(_manual_slot_path(2)) != corrupt_before:
		return _fail_shell(shell, "Canceling corrupt-slot overwrite changed its exact bytes.")
	if not _require_preserved_state(protected_states, active_payload, campaign_before, settings_before, _manual_slot_path(2)):
		return false
	shell.queue_free()
	await _settle()
	return true

func _session_for_route(route_id: String, day: int):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.day = day
	match route_id:
		"town":
			var town := _first_player_town(session)
			if town.is_empty():
				return null
			_move_active_hero_to_town(session, town)
			session.game_state = "town"
		"battle":
			var encounter := _first_encounter(session)
			if encounter.is_empty():
				return null
			session.battle = BattleRules.create_battle_payload(session, encounter)
			session.game_state = "battle"
		"outcome":
			session.scenario_status = "victory"
			session.scenario_summary = "Overwrite confirmation outcome fixture."
			session.game_state = "outcome"
	return session

func _first_player_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return town
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["position"] = position.duplicate(true)
		session.overworld["hero"] = hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var candidate = heroes[index]
		if candidate is Dictionary and String(candidate.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			candidate["position"] = position.duplicate(true)
			heroes[index] = candidate
	session.overworld["player_heroes"] = heroes

func _first_encounter(session) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary:
			return encounter
	return {}

func _require_preserved_state(
	protected_states: Dictionary,
	active_payload: Dictionary,
	campaign_before: Dictionary,
	settings_before: Dictionary,
	excluded_path: String
) -> bool:
	for path_value in protected_states.keys():
		var path := String(path_value)
		if path == excluded_path:
			continue
		if _file_state(path) != protected_states.get(path, {}):
			return _fail_bool("Manual overwrite changed protected file %s." % path)
	if SessionState.active_session == null or SessionState.active_session.to_dict() != active_payload:
		return _fail_bool("Manual overwrite changed the active in-memory expedition.")
	if CampaignProgression.ensure_profile() != campaign_before:
		return _fail_bool("Manual overwrite changed campaign progression.")
	if SettingsService.settings != settings_before:
		return _fail_bool("Manual overwrite changed device settings.")
	if SessionState.SAVE_VERSION != 9:
		return _fail_bool("Manual overwrite changed the save-version contract.")
	return true

func _tracked_paths() -> Array:
	return [
		_autosave_path(),
		_manual_slot_path(1),
		_manual_slot_path(2),
		_manual_slot_path(3),
		_progression_path(),
		String(SettingsService.SETTINGS_FILE),
	]

func _autosave_path() -> String:
	return "%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE]

func _manual_slot_path(slot: int) -> String:
	return "%s/%s%d.json" % [SaveService.SAVE_DIR, SaveService.SAVE_PREFIX, slot]

func _progression_path() -> String:
	return "%s/%s" % [SaveService.SAVE_DIR, SaveService.PROGRESSION_FILE]

func _capture_file_states(paths: Array) -> Dictionary:
	var states := {}
	for path_value in paths:
		var path := String(path_value)
		states[path] = _file_state(path)
	return states

func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}

func _restore_original_state() -> void:
	for path_value in _original_file_states.keys():
		var path := String(path_value)
		var state: Dictionary = _original_file_states.get(path, {})
		if bool(state.get("exists", false)):
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(state.get("bytes", PackedByteArray()))
				file.close()
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SessionState.active_session = _original_active_session
	CampaignProgression.profile = _original_campaign_profile.duplicate(true)
	SettingsService.settings = _original_settings.duplicate(true)

func _capture(stem: String) -> void:
	if OS.get_environment("MANUAL_SAVE_OVERWRITE_CAPTURE") != "1":
		return
	await RenderingServer.frame_post_draw
	var absolute_dir := ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s_%dx%d.png" % [absolute_dir, stem, image.get_width(), image.get_height()])

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _safe_dialog_ready(dialog: ConfirmationDialog, expected_cancel_text: String) -> bool:
	if dialog == null or not dialog.visible or dialog.get_cancel_button().text != expected_cancel_text:
		return false
	var dialog_viewport := dialog.get_cancel_button().get_viewport()
	if dialog_viewport == null or dialog_viewport.gui_get_focus_owner() != dialog.get_cancel_button():
		return false
	return dialog.size.x <= 960 and dialog.size.y <= 540

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

func _fail_shell(shell, message: String) -> bool:
	if shell != null:
		var layout_host: Node = shell.get_parent()
		if layout_host is Control and String(layout_host.name).begins_with("TownLayoutHost_"):
			layout_host.queue_free()
		else:
			shell.queue_free()
	return _fail_bool(message)

func _fail_bool(message: String) -> bool:
	_fail(message)
	return false

func _fail(message: String) -> void:
	_restore_original_state()
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
