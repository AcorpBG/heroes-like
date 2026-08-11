extends Node

const REPORT_ID := "MANUAL_SAVE_OVERWRITE_REGRESSION"
const CAPTURE_DIR := "res://.artifacts/manual_save_overwrite_regression"
const EXCLUSIVE_SNAPSHOT_OBSERVER_PROFILE_KEYS := [
	"field_readiness_simple_current_route_fast_path",
	"field_readiness_simple_route_fast_path",
	"hero_actions_cache_hits",
	"selected_route_cache_hits",
]
const EXCLUSIVE_BACKGROUND_CONTROLLER_MODAL_KEYS := [
	"available",
	"blocked_reason",
	"manual_overwrite_open",
]

var _original_file_states := {}
var _original_active_session = null
var _original_campaign_profile := {}
var _original_settings := {}
var _exclusive_parent_click_counts := {}

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
	if not await _exercise_overworld_drawer_cancel_ownership(protected_states, campaign_before, settings_before):
		return

	var route_specs := [
		{"id": "overworld", "scene": "res://scenes/overworld/OverworldShell.tscn", "day": 11, "width": 1280, "corrupt": false, "cancel_input": "joypad_b", "confirm_input": "joypad_a"},
		{"id": "town", "scene": "res://scenes/town/TownShell.tscn", "day": 12, "width": 1280, "corrupt": true, "cancel_input": "escape", "confirm_input": "enter"},
		{"id": "battle", "scene": "res://scenes/battle/BattleShell.tscn", "day": 13, "width": 1920, "corrupt": false, "cancel_input": "mouse", "confirm_input": "mouse"},
		{"id": "outcome", "scene": "res://scenes/results/ScenarioOutcomeShell.tscn", "day": 14, "width": 1920, "corrupt": true, "cancel_input": "joypad_b", "confirm_input": "enter"},
	]
	var route_window_size := get_window().size
	for route_value in route_specs:
		var route: Dictionary = route_value
		if not await _exercise_route(route, protected_states, campaign_before, settings_before):
			get_window().size = route_window_size
			return
	get_window().size = route_window_size
	await _settle()

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
		"overworld_command_drawer_joypad_cancel_exact": true,
		"overworld_command_drawer_escape_cancel_exact": true,
		"overworld_frontier_drawer_joypad_cancel_exact": true,
		"overworld_frontier_drawer_escape_cancel_exact": true,
		"overworld_drawer_fresh_back_closes_only_drawer": true,
		"overworld_drawer_joypad_confirm_exact": true,
		"overworld_drawer_enter_confirm_exact": true,
		"overworld_drawer_route_camera_debug_authority_exact": true,
		"overworld_save_slot_popup_cancel_unchanged": true,
		"overworld_settings_cancel_unchanged": true,
		"overworld_end_turn_cancel_unchanged": true,
		"overworld_no_drawer_cancel_route_exact": true,
		"origin_focus_restored": true,
		"confirm_exactly_once": true,
		"pending_slot_binding_preserved": true,
		"exclusive_parent_mouse_routes_exact": ["overworld", "town", "battle", "outcome"],
		"exclusive_parent_mouse_widths_exact": [1280, 1920],
		"exclusive_parent_mouse_occupied_unreadable_exact": true,
		"exclusive_parent_mouse_outside_dialog_exact": true,
		"exclusive_parent_mouse_dialog_focus_retained": true,
		"exclusive_native_mouse_cancel_confirm_exact": true,
		"exclusive_native_b_escape_a_enter_exact": true,
		"exclusive_reopened_parent_accept_guard_exact": true,
		"exclusive_battle_deferred_focus_exact": true,
		"exclusive_full_authority_exact": true,
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
	var route_id := String(route.get("id", ""))
	var corrupt := bool(route.get("corrupt", false))
	if corrupt:
		var corrupt_file := FileAccess.open(_manual_slot_path(2), FileAccess.WRITE)
		if corrupt_file == null:
			return _fail_bool("Could not seed unreadable Manual Slot 2 for %s." % route_id)
		corrupt_file.store_string(JSON.stringify({"not_a_session": true, "exclusive_route": route_id}))
		corrupt_file.close()
	elif SaveService.save_manual_session(old_fixture.to_dict(), 2) == "":
		return _fail_bool("Could not seed occupied Manual Slot 2 for %s." % route_id)
	SaveService.validation_clear_summary_cache()
	var slot2_before := _file_state(_manual_slot_path(2))

	var session = _session_for_route(route_id, int(route.get("day", 1)))
	if session == null:
		return _fail_bool("Could not create %s route fixture." % route_id)
	session = SessionState.set_active_session(session)
	SaveService.set_selected_manual_slot(2)
	var route_width := int(route.get("width", 1280))
	get_window().size = Vector2i(route_width, 720)
	await _settle()
	# Headless window geometry can lag the assignment. Give responsive production
	# code an exact positive parent Control size while retaining the physical window
	# assignment and runner-viewport mouse dispatch.
	var layout_host := Control.new()
	layout_host.name = "ExclusiveRouteLayoutHost_%s" % route_id
	layout_host.size = Vector2(float(route_width), 720.0)
	add_child(layout_host)
	var shell = load(String(route.get("scene", ""))).instantiate()
	layout_host.add_child(shell)
	var parent_probe := Button.new()
	parent_probe.name = "ExclusiveParentClickProbe_%s" % route_id
	parent_probe.text = "Parent input probe"
	parent_probe.position = Vector2(16.0, 16.0)
	parent_probe.size = Vector2(176.0, 40.0)
	parent_probe.focus_mode = Control.FOCUS_NONE
	parent_probe.z_index = 100
	_exclusive_parent_click_counts[route_id] = 0
	parent_probe.pressed.connect(_on_exclusive_parent_probe_pressed.bind(route_id))
	layout_host.add_child(parent_probe)
	await _settle_route_dialog(route_id)
	var layout_host_checks := {
		"shell_parent_exact": shell.get_parent() == layout_host,
		"width_exact": int(layout_host.size.x) == route_width,
		"height_exact": int(layout_host.size.y) == 720,
	}
	if not _checks_exact(layout_host_checks):
		return _fail_shell(shell, "%s exclusive-parent fixture did not retain its exact %dx720 Control host: checks=%s." % [route_id, route_width, JSON.stringify(layout_host_checks)])
	var active_payload: Dictionary = session.to_dict()
	var origin_button: Button = shell.get_node("%Save")
	var dialog: ConfirmationDialog = shell.get_node("ManualSaveOverwriteDialog")
	origin_button.grab_focus()
	await get_tree().process_frame

	var request: Dictionary = shell.call("validation_request_manual_save")
	await _settle_route_dialog(route_id)
	var request_text := "%s\n%s" % [String(request.get("title", "")), String(request.get("text", ""))]
	var request_checks := {
		"visible_exact": bool(request.get("visible", false)),
		"pending_slot2_exact": int(request.get("pending_slot", 0)) == 2,
	}
	if not _checks_exact(request_checks):
		return _fail_shell(shell, "%s did not require Manual Slot 2 confirmation: checks=%s request=%s." % [route.get("id", "route"), JSON.stringify(request_checks), JSON.stringify(request)])
	var required_tokens := ["Manual Slot 2", "Day %d" % int(route.get("day", 1)), "Other manual saves", "autosave"]
	if corrupt:
		required_tokens.append("Unreadable expedition save")
	else:
		required_tokens.append("Day 3")
	for token in required_tokens:
		if not request_text.contains(token):
			return _fail_shell(shell, "%s overwrite confirmation omitted %s: %s." % [route.get("id", "route"), token, request_text])
	if _file_state(_manual_slot_path(2)) != slot2_before:
		return _fail_shell(shell, "%s confirmation request changed Manual Slot 2 before approval." % route.get("id", "route"))
	var initial_dialog_checks := {
		"exclusive_exact": dialog.exclusive,
		"safe_dialog_ready_exact": _safe_dialog_ready(dialog, "Keep Save"),
	}
	if not _checks_exact(initial_dialog_checks):
		return _fail_shell(shell, "%s overwrite confirmation did not focus its compact Keep Save action: checks=%s." % [route.get("id", "route"), JSON.stringify(initial_dialog_checks)])
	var parent_geometry := _exclusive_parent_click_geometry(parent_probe, dialog)
	if not bool(parent_geometry.get("exact", false)):
		return _fail_shell(shell, "%s parent click was not mapped to a real root point outside the exclusive dialog: %s." % [route_id, JSON.stringify(parent_geometry)])
	var dialog_before_parent: Dictionary = dialog.validation_snapshot()
	var authority_before_parent := _exclusive_route_authority_snapshot(shell, session, route_id)
	var background_authority_before := _exclusive_route_background_authority(authority_before_parent)
	var initial_manual_fallback_count := _exclusive_manual_fallback_count(authority_before_parent)
	var tracks_manual_fallback_count := route_id == "overworld"
	var initial_manual_fallback_count_exact := initial_manual_fallback_count >= 0 if tracks_manual_fallback_count else initial_manual_fallback_count == -1
	var parent_click_count_before := int(_exclusive_parent_click_counts.get(route_id, 0))
	await _click_control(parent_probe)
	var dialog_after_parent: Dictionary = dialog.validation_snapshot()
	var authority_after_parent := _exclusive_route_authority_snapshot(shell, session, route_id)
	var authority_component_checks := _authority_component_checks(authority_before_parent, authority_after_parent)
	var blocked_parent_checks := {
		"dialog_exact": dialog_after_parent == dialog_before_parent,
		"dialog_visible_exact": bool(dialog_before_parent.get("visible", false)) and bool(dialog_after_parent.get("visible", false)),
		"full_authority_exact": authority_after_parent == authority_before_parent,
		"dialog_focus_exact": dialog.get_cancel_button().get_viewport().gui_get_focus_owner() == dialog.get_cancel_button(),
		"parent_count_exact": int(_exclusive_parent_click_counts.get(route_id, -1)) == parent_click_count_before,
		"slot_bytes_exact": _file_state(_manual_slot_path(2)) == slot2_before,
		"manual_fallback_count_captured_or_absent_exact": initial_manual_fallback_count_exact,
		"manual_fallback_count_unchanged": _exclusive_manual_fallback_count(authority_after_parent) == initial_manual_fallback_count,
	}
	var blocked_parent_exact := true
	for check_value in blocked_parent_checks.values():
		blocked_parent_exact = blocked_parent_exact and bool(check_value)
	if not blocked_parent_exact:
		return _fail_shell(shell, "%s exclusive blocked-parent check failed: checks=%s authority_components=%s count_before=%d count_after=%d geometry=%s dialog_before=%s dialog_after=%s authority_before=%s authority_after=%s." % [route_id, JSON.stringify(blocked_parent_checks), JSON.stringify(authority_component_checks), parent_click_count_before, int(_exclusive_parent_click_counts.get(route_id, -1)), JSON.stringify(parent_geometry), JSON.stringify(dialog_before_parent), JSON.stringify(dialog_after_parent), JSON.stringify(authority_before_parent), JSON.stringify(authority_after_parent)])

	if not await _cancel_manual_dialog_with_input(dialog, String(route.get("cancel_input", "escape"))):
		return false
	await _settle_route_dialog(route_id)
	var dialog_after_cancel: Dictionary = dialog.validation_snapshot()
	var dialog_cancel_checks := {
		"hidden_exact": not bool(dialog_after_cancel.get("visible", true)),
		"pending_cleared_exact": int(dialog_after_cancel.get("pending_slot", -1)) == 0,
		"action_dictionary_exact": dialog_after_cancel.get("action", {}) is Dictionary,
		"action_cleared_exact": dialog_after_cancel.get("action", {}) is Dictionary and dialog_after_cancel.get("action", {}).is_empty(),
		"request_count_exact": int(dialog_after_cancel.get("request_count", -1)) == int(dialog_before_parent.get("request_count", 0)),
		"cancel_count_exact": int(dialog_after_cancel.get("cancel_count", -1)) == int(dialog_before_parent.get("cancel_count", 0)) + 1,
		"confirm_count_exact": int(dialog_after_cancel.get("confirm_count", -1)) == int(dialog_before_parent.get("confirm_count", 0)),
	}
	var dialog_transaction_exact := true
	for check_value in dialog_cancel_checks.values():
		dialog_transaction_exact = dialog_transaction_exact and bool(check_value)
	var full_authority_after_cancel := _exclusive_route_authority_snapshot(shell, session, route_id)
	var background_authority_after_cancel := _exclusive_route_background_authority(full_authority_after_cancel)
	var full_shell_before_cancel: Dictionary = authority_before_parent.get("shell", {}) if authority_before_parent.get("shell", {}) is Dictionary else {}
	var full_shell_after_cancel: Dictionary = full_authority_after_cancel.get("shell", {}) if full_authority_after_cancel.get("shell", {}) is Dictionary else {}
	var outcome_focus_before_cancel: Dictionary = authority_before_parent.get("outcome_focus", {}) if authority_before_parent.get("outcome_focus", {}) is Dictionary else {}
	var outcome_focus_after_cancel: Dictionary = full_authority_after_cancel.get("outcome_focus", {}) if full_authority_after_cancel.get("outcome_focus", {}) is Dictionary else {}
	var shell_outcome_focus_before_cancel: Dictionary = full_shell_before_cancel.get("outcome_focus", {}) if full_shell_before_cancel.get("outcome_focus", {}) is Dictionary else {}
	var shell_outcome_focus_after_cancel: Dictionary = full_shell_after_cancel.get("outcome_focus", {}) if full_shell_after_cancel.get("outcome_focus", {}) is Dictionary else {}
	var outcome_modal_transition_exact := route_id != "outcome"
	var shell_outcome_modal_transition_exact := route_id != "outcome"
	if route_id == "outcome":
		outcome_modal_transition_exact = bool(outcome_focus_before_cancel.get("manual_overwrite_visible", false)) and not bool(outcome_focus_after_cancel.get("manual_overwrite_visible", true))
		shell_outcome_modal_transition_exact = bool(shell_outcome_focus_before_cancel.get("manual_overwrite_visible", false)) and not bool(shell_outcome_focus_after_cancel.get("manual_overwrite_visible", true))
	var preserved_state_checks := _preserved_state_component_checks(protected_states, active_payload, campaign_before, settings_before, _manual_slot_path(2))
	var preserved_state_exact := true
	for check_value in preserved_state_checks.values():
		preserved_state_exact = preserved_state_exact and bool(check_value)
	var cancel_authority_checks := {
		"dialog_transaction_exact": dialog_transaction_exact,
		"root_origin_control_identity_exact": get_viewport().gui_get_focus_owner() == origin_button,
		"slot2_bytes_exact": _file_state(_manual_slot_path(2)) == slot2_before,
		"normalized_background_authority_exact": background_authority_after_cancel == background_authority_before,
		"preserved_state_exact": preserved_state_exact,
		"manual_fallback_count_unchanged": _exclusive_manual_fallback_count(full_authority_after_cancel) == initial_manual_fallback_count,
		"outcome_manual_overwrite_visible_transition_exact": outcome_modal_transition_exact,
		"shell_outcome_manual_overwrite_visible_transition_exact": shell_outcome_modal_transition_exact,
	}
	var cancel_authority_exact := true
	for check_value in cancel_authority_checks.values():
		cancel_authority_exact = cancel_authority_exact and bool(check_value)
	if not cancel_authority_exact:
		var controller_routes_before: Dictionary = background_authority_before.get("controller_routes", {}) if background_authority_before.get("controller_routes", {}) is Dictionary else {}
		var controller_routes_after: Dictionary = background_authority_after_cancel.get("controller_routes", {}) if background_authority_after_cancel.get("controller_routes", {}) is Dictionary else {}
		var outcome_focus_before: Dictionary = {}
		var outcome_focus_after: Dictionary = {}
		var cancel_shell_before: Dictionary = {}
		var cancel_shell_after: Dictionary = {}
		var shell_outcome_focus_before: Dictionary = {}
		var shell_outcome_focus_after: Dictionary = {}
		if route_id == "outcome":
			outcome_focus_before = background_authority_before.get("outcome_focus", {}) if background_authority_before.get("outcome_focus", {}) is Dictionary else {}
			outcome_focus_after = background_authority_after_cancel.get("outcome_focus", {}) if background_authority_after_cancel.get("outcome_focus", {}) is Dictionary else {}
			cancel_shell_before = background_authority_before.get("shell", {}) if background_authority_before.get("shell", {}) is Dictionary else {}
			cancel_shell_after = background_authority_after_cancel.get("shell", {}) if background_authority_after_cancel.get("shell", {}) is Dictionary else {}
			shell_outcome_focus_before = cancel_shell_before.get("outcome_focus", {}) if cancel_shell_before.get("outcome_focus", {}) is Dictionary else {}
			shell_outcome_focus_after = cancel_shell_after.get("outcome_focus", {}) if cancel_shell_after.get("outcome_focus", {}) is Dictionary else {}
		return _fail_shell(shell, "%s native %s cancel authority failed: checks=%s dialog_components=%s background_components=%s preserved_components=%s controller_route_components=%s controller_route_differences=%s outcome_focus_components=%s outcome_focus_differences=%s shell_components=%s shell_differences=%s shell_outcome_focus_components=%s shell_outcome_focus_differences=%s." % [route_id, route.get("cancel_input", ""), JSON.stringify(cancel_authority_checks), JSON.stringify(dialog_cancel_checks), JSON.stringify(_authority_component_checks(background_authority_before, background_authority_after_cancel)), JSON.stringify(preserved_state_checks), JSON.stringify(_authority_component_checks(controller_routes_before, controller_routes_after)), JSON.stringify(_differing_component_values(controller_routes_before, controller_routes_after)), JSON.stringify(_authority_component_checks(outcome_focus_before, outcome_focus_after)), JSON.stringify(_differing_component_values(outcome_focus_before, outcome_focus_after)), JSON.stringify(_authority_component_checks(cancel_shell_before, cancel_shell_after)), JSON.stringify(_differing_component_values(cancel_shell_before, cancel_shell_after)), JSON.stringify(_authority_component_checks(shell_outcome_focus_before, shell_outcome_focus_after)), JSON.stringify(_differing_component_values(shell_outcome_focus_before, shell_outcome_focus_after))])

	# Use the exact same enabled parent control and root-mouse path as the blocked
	# click. Once the exclusive window is closed its native pressed signal must fire
	# exactly once, proving the preceding modal click was not a no-op fixture.
	await _click_control(parent_probe)
	var dialog_after_positive_parent: Dictionary = dialog.validation_snapshot()
	var positive_parent_full_authority_after := _exclusive_route_authority_snapshot(shell, session, route_id)
	var positive_parent_background_after := _exclusive_route_background_authority(positive_parent_full_authority_after)
	var positive_parent_checks := {
		"parent_count_increment_exact": int(_exclusive_parent_click_counts.get(route_id, -1)) == parent_click_count_before + 1,
		"dialog_transaction_exact": _manual_dialog_transaction_state(dialog_after_positive_parent) == _manual_dialog_transaction_state(dialog_after_cancel),
		"normalized_background_authority_exact": positive_parent_background_after == background_authority_before,
		"manual_fallback_count_unchanged": _exclusive_manual_fallback_count(positive_parent_full_authority_after) == initial_manual_fallback_count,
	}
	if not _checks_exact(positive_parent_checks):
		return _fail_shell(shell, "%s same parent probe click did not fire exactly once after cancel: checks=%s background_components=%s count=%d dialog=%s." % [route_id, JSON.stringify(positive_parent_checks), JSON.stringify(_authority_component_checks(background_authority_before, positive_parent_background_after)), int(_exclusive_parent_click_counts.get(route_id, -1)), JSON.stringify(dialog_after_positive_parent)])
	request = shell.call("validation_request_manual_save")
	await _settle_route_dialog(route_id)
	var reopened_snapshot: Dictionary = dialog.validation_snapshot()
	var reopened_full_authority := _exclusive_route_authority_snapshot(shell, session, route_id)
	var reopened_background_authority := _exclusive_route_background_authority(reopened_full_authority)
	var reopened_cancel_button := dialog.get_cancel_button()
	var reopened_dialog_viewport := reopened_cancel_button.get_viewport()
	var reopened_safe_checks := {
		"cancel_text_exact": reopened_cancel_button.text == "Keep Save",
		"dialog_viewport_present": reopened_dialog_viewport != null,
		"cancel_focus_exact": reopened_dialog_viewport != null and reopened_dialog_viewport.gui_get_focus_owner() == reopened_cancel_button,
		"bounded_width_exact": dialog.size.x <= 960,
		"bounded_height_exact": dialog.size.y <= 540,
	}
	var reopen_checks := {
		"visible_exact": bool(reopened_snapshot.get("visible", false)),
		"pending_slot2_exact": int(reopened_snapshot.get("pending_slot", 0)) == 2,
		"request_increment_exact": int(reopened_snapshot.get("request_count", 0)) == int(dialog_after_cancel.get("request_count", 0)) + 1,
		"cancel_count_unchanged": int(reopened_snapshot.get("cancel_count", 0)) == int(dialog_after_cancel.get("cancel_count", 0)),
		"confirm_count_unchanged": int(reopened_snapshot.get("confirm_count", 0)) == int(dialog_after_cancel.get("confirm_count", 0)),
		"normalized_background_authority_exact": reopened_background_authority == background_authority_before,
		"exclusive_exact": dialog.exclusive,
		"safe_dialog_ready_exact": _safe_dialog_ready(dialog, "Keep Save"),
		"manual_fallback_count_increment_or_absent_exact": _exclusive_manual_fallback_count(reopened_full_authority) == initial_manual_fallback_count + 1 if tracks_manual_fallback_count else _exclusive_manual_fallback_count(reopened_full_authority) == -1,
	}
	var reopen_exact := true
	for check_value in reopen_checks.values():
		reopen_exact = reopen_exact and bool(check_value)
	if not reopen_exact:
		var background_shell_before: Dictionary = background_authority_before.get("shell", {}) if background_authority_before.get("shell", {}) is Dictionary else {}
		var background_shell_after: Dictionary = reopened_background_authority.get("shell", {}) if reopened_background_authority.get("shell", {}) is Dictionary else {}
		return _fail_shell(shell, "%s overwrite confirmation did not reopen exactly once after the positive parent probe: checks=%s safe_components=%s background_components=%s shell_components=%s shell_differences=%s after_cancel=%s reopened=%s." % [route_id, JSON.stringify(reopen_checks), JSON.stringify(reopened_safe_checks), JSON.stringify(_authority_component_checks(background_authority_before, reopened_background_authority)), JSON.stringify(_authority_component_checks(background_shell_before, background_shell_after)), JSON.stringify(_differing_component_values(background_shell_before, background_shell_after)), JSON.stringify(dialog_after_cancel), JSON.stringify(reopened_snapshot)])
	var reopened_parent_count_before := int(_exclusive_parent_click_counts.get(route_id, -1))
	var reopened_parent_authority_before := _exclusive_route_authority_snapshot(shell, session, route_id)
	var reopened_parent_background_before := _exclusive_route_background_authority(reopened_parent_authority_before)
	await _click_control(parent_probe)
	var reopened_after_parent: Dictionary = dialog.validation_snapshot()
	var reopened_parent_authority_after := _exclusive_route_authority_snapshot(shell, session, route_id)
	var reopened_parent_background_after := _exclusive_route_background_authority(reopened_parent_authority_after)
	var reopened_parent_checks := {
		"parent_count_exact": int(_exclusive_parent_click_counts.get(route_id, -1)) == reopened_parent_count_before,
		"dialog_exact": reopened_after_parent == reopened_snapshot,
		"full_authority_exact": reopened_parent_authority_after == reopened_parent_authority_before,
		"background_authority_exact": reopened_parent_background_after == reopened_parent_background_before,
		"dialog_focus_exact": dialog.get_cancel_button().get_viewport().gui_get_focus_owner() == dialog.get_cancel_button(),
		"slot_bytes_exact": _file_state(_manual_slot_path(2)) == slot2_before,
		"manual_fallback_count_at_increment_or_absent_exact": _exclusive_manual_fallback_count(reopened_parent_authority_before) == initial_manual_fallback_count + 1 if tracks_manual_fallback_count else _exclusive_manual_fallback_count(reopened_parent_authority_before) == -1,
		"manual_fallback_count_unchanged": _exclusive_manual_fallback_count(reopened_parent_authority_after) == initial_manual_fallback_count + 1 if tracks_manual_fallback_count else _exclusive_manual_fallback_count(reopened_parent_authority_after) == -1,
	}
	var reopened_parent_exact := true
	for check_value in reopened_parent_checks.values():
		reopened_parent_exact = reopened_parent_exact and bool(check_value)
	if not reopened_parent_exact:
		var reopened_parent_shell_before: Dictionary = reopened_parent_authority_before.get("shell", {}) if reopened_parent_authority_before.get("shell", {}) is Dictionary else {}
		var reopened_parent_shell_after: Dictionary = reopened_parent_authority_after.get("shell", {}) if reopened_parent_authority_after.get("shell", {}) is Dictionary else {}
		var reopened_parent_recovery_before: Dictionary = reopened_parent_shell_before.get("generated_opening_autosave_recovery", {}) if reopened_parent_shell_before.get("generated_opening_autosave_recovery", {}) is Dictionary else {}
		var reopened_parent_recovery_after: Dictionary = reopened_parent_shell_after.get("generated_opening_autosave_recovery", {}) if reopened_parent_shell_after.get("generated_opening_autosave_recovery", {}) is Dictionary else {}
		return _fail_shell(shell, "%s reopened exclusive dialog did not block the parent click before native confirm: checks=%s count_before=%d count_after=%d dialog_before=%s dialog_after=%s authority_components=%s shell_components=%s shell_differences=%s recovery_components=%s recovery_differences=%s." % [route_id, JSON.stringify(reopened_parent_checks), reopened_parent_count_before, int(_exclusive_parent_click_counts.get(route_id, -1)), JSON.stringify(reopened_snapshot), JSON.stringify(reopened_after_parent), JSON.stringify(_authority_component_checks(reopened_parent_authority_before, reopened_parent_authority_after)), JSON.stringify(_authority_component_checks(reopened_parent_shell_before, reopened_parent_shell_after)), JSON.stringify(_differing_component_values(reopened_parent_shell_before, reopened_parent_shell_after)), JSON.stringify(_authority_component_checks(reopened_parent_recovery_before, reopened_parent_recovery_after)), JSON.stringify(_differing_component_values(reopened_parent_recovery_before, reopened_parent_recovery_after))])

	if not bool(shell.call("validation_select_save_slot", 3)):
		return _fail_shell(shell, "%s could not change visible selection while confirmation was pending." % route.get("id", "route"))
	var slot3_before := _file_state(_manual_slot_path(3))
	var dialog_before_confirm: Dictionary = dialog.validation_snapshot()
	var route_authority_before_confirm := {
		"app_route": AppRouter.validation_active_play_return_snapshot(),
		"overworld_handoff": AppRouter.validation_latest_overworld_handoff_profile(),
		"settings": _settings_transaction_route_authority(),
	}
	if not await _confirm_manual_dialog_with_input(dialog, String(route.get("confirm_input", "enter"))):
		return false
	await _settle_route_dialog(route_id)
	var dialog_after_confirm: Dictionary = dialog.validation_snapshot()
	var saved_summary := SaveService.inspect_manual_slot(2)
	var profile: Dictionary = SaveService.validation_last_runtime_save_profile()
	var step_counts := {}
	for step_value in profile.get("steps", []):
		if step_value is Dictionary:
			var step_name := String(step_value.get("name", ""))
			step_counts[step_name] = int(step_counts.get(step_name, 0)) + 1
	var confirm_checks := {
		"dialog_hidden_exact": not bool(dialog_after_confirm.get("visible", true)),
		"pending_cleared_exact": int(dialog_after_confirm.get("pending_slot", -1)) == 0,
		"action_dictionary_exact": dialog_after_confirm.get("action", {}) is Dictionary,
		"action_cleared_exact": dialog_after_confirm.get("action", {}) is Dictionary and dialog_after_confirm.get("action", {}).is_empty(),
		"request_count_exact": int(dialog_after_confirm.get("request_count", -1)) == int(dialog_before_confirm.get("request_count", 0)),
		"confirm_count_increment_exact": int(dialog_after_confirm.get("confirm_count", -1)) == int(dialog_before_confirm.get("confirm_count", 0)) + 1,
		"cancel_count_unchanged": int(dialog_after_confirm.get("cancel_count", -1)) == int(dialog_before_confirm.get("cancel_count", 0)),
		"summary_loadable_exact": SaveService.can_load_summary(saved_summary),
		"summary_day_exact": int(saved_summary.get("day", 0)) == int(route.get("day", 0)),
		"profile_slot_type_exact": String(profile.get("slot_type", "")) == SaveService.SLOT_TYPE_MANUAL,
		"profile_path_exact": String(profile.get("path", "")) == _manual_slot_path(2),
		"profile_written_bytes_exact": int(profile.get("written_bytes", 0)) == FileAccess.get_size(_manual_slot_path(2)),
		"profile_recovery_count_exact": int(profile.get("recovery_count", 0)) == 1,
		"profile_payload_prepared_exact": bool(profile.get("prepared_payload", false)),
		"write_payload_start_once": int(step_counts.get("write_payload_start", 0)) == 1,
		"finished_once": int(step_counts.get("finished", 0)) == 1,
		"summary_cache_exact": _summary_cache_contains_exact_summary(SaveService.validation_summary_cache_snapshot(), saved_summary),
		"app_route_exact": AppRouter.validation_active_play_return_snapshot() == route_authority_before_confirm.get("app_route", {}),
		"overworld_handoff_exact": AppRouter.validation_latest_overworld_handoff_profile() == route_authority_before_confirm.get("overworld_handoff", {}),
		"settings_transaction_exact": _settings_transaction_route_authority() == route_authority_before_confirm.get("settings", {}),
	}
	if not _checks_exact(confirm_checks):
		return _fail_shell(shell, "%s native %s confirmation did not write originally bound Manual Slot 2 exactly once: checks=%s before=%s after=%s." % [route_id, route.get("confirm_input", ""), JSON.stringify(confirm_checks), JSON.stringify(dialog_before_confirm), JSON.stringify(dialog_after_confirm)])
	if _file_state(_manual_slot_path(3)) != slot3_before:
		return _fail_shell(shell, "%s redirected overwrite into the later-selected Manual Slot 3." % route.get("id", "route"))
	if not _require_preserved_state(protected_states, active_payload, campaign_before, settings_before, _manual_slot_path(2)):
		return false
	layout_host.queue_free()
	await _settle()
	return true

func _on_exclusive_parent_probe_pressed(route_id: String) -> void:
	_exclusive_parent_click_counts[route_id] = int(_exclusive_parent_click_counts.get(route_id, 0)) + 1

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

func _exercise_overworld_drawer_cancel_ownership(
	protected_states: Dictionary,
	campaign_before: Dictionary,
	settings_before: Dictionary
) -> bool:
	var cases := [
		{"id": "command_joypad", "drawer": "command", "joypad": true, "day": 36, "confirm": "joypad"},
		{"id": "command_escape", "drawer": "command", "joypad": false, "day": 37},
		{"id": "frontier_joypad", "drawer": "frontier", "joypad": true, "day": 38},
		{"id": "frontier_escape", "drawer": "frontier", "joypad": false, "day": 39, "confirm": "enter"},
	]
	for case_value in cases:
		var case: Dictionary = case_value
		if not await _exercise_overworld_drawer_cancel_case(case, protected_states, campaign_before, settings_before):
			return false
	return await _exercise_overworld_neighbor_modal_owners(protected_states, campaign_before, settings_before)

func _exercise_overworld_drawer_cancel_case(
	case: Dictionary,
	protected_states: Dictionary,
	campaign_before: Dictionary,
	settings_before: Dictionary
) -> bool:
	var old_fixture = ScenarioFactory.create_session("river-pass", "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	old_fixture.day = 3
	if SaveService.save_manual_session(old_fixture.to_dict(), 2) == "":
		return _fail_bool("Could not seed occupied Overworld drawer Manual Slot 2 fixture.")
	SaveService.validation_clear_summary_cache()
	var slot2_before := _file_state(_manual_slot_path(2))
	var session = _session_for_route("overworld", int(case.get("day", 36)))
	session = SessionState.set_active_session(session)
	SaveService.set_selected_manual_slot(2)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var save_button: Button = shell.get_node("%Save")
	var dialog: ConfirmationDialog = shell.get_node("ManualSaveOverwriteDialog")
	save_button.grab_focus()
	await get_tree().process_frame
	var baseline_authority := _overworld_drawer_authority_signature(shell, session)
	var drawer := String(case.get("drawer", ""))
	var drawer_state: Dictionary = shell.validation_open_command_drawer() if drawer == "command" else shell.validation_open_frontier_drawer()
	if not _overworld_drawer_state_exact(drawer_state, drawer):
		return _fail_shell(shell, "Overworld overwrite fixture did not open the exact %s drawer: %s." % [drawer, JSON.stringify(drawer_state)])
	save_button.grab_focus()
	await get_tree().process_frame
	var drawer_authority := _overworld_drawer_authority_signature(shell, session)
	var request: Dictionary = shell.validation_request_manual_save()
	await _settle()
	var request_snapshot: Dictionary = dialog.validation_snapshot()
	if not bool(request.get("visible", false)) \
			or int(request_snapshot.get("pending_slot", 0)) != 2 \
			or int(request_snapshot.get("request_count", 0)) <= 0 \
			or String(request_snapshot.get("return_focus_name", "")) != "Save" \
			or not _safe_dialog_ready(dialog, "Keep Save"):
		return _fail_shell(shell, "Overworld %s drawer did not open the exact occupied overwrite confirmation: %s." % [drawer, JSON.stringify(request_snapshot)])
	if bool(case.get("joypad", false)):
		await _press_joypad_button(JOY_BUTTON_B)
	else:
		await _press_key(KEY_ESCAPE)
	var after: Dictionary = dialog.validation_snapshot()
	var focus_owner := get_viewport().gui_get_focus_owner()
	var after_drawer := _overworld_chrome_state(shell)
	if bool(after.get("visible", true)) \
			or int(after.get("pending_slot", -1)) != 0 \
			or not (after.get("action", null) is Dictionary) \
			or not after.get("action", {}).is_empty() \
			or int(after.get("request_count", -1)) != int(request_snapshot.get("request_count", 0)) \
			or int(after.get("cancel_count", -1)) != int(request_snapshot.get("cancel_count", 0)) + 1 \
			or int(after.get("confirm_count", -1)) != int(request_snapshot.get("confirm_count", 0)) \
			or focus_owner != save_button \
			or not _overworld_drawer_state_exact(after_drawer, drawer) \
			or _file_state(_manual_slot_path(2)) != slot2_before \
			or _overworld_drawer_authority_signature(shell, session) != drawer_authority \
			or not _require_preserved_state(protected_states, session.to_dict(), campaign_before, settings_before, _manual_slot_path(2)):
		return _fail_shell(shell, "Overworld physical overwrite cancel escaped %s drawer ownership: case=%s before=%s after=%s drawer=%s focus=%s." % [drawer, JSON.stringify(case), JSON.stringify(request_snapshot), JSON.stringify(after), JSON.stringify(after_drawer), String(focus_owner.name) if focus_owner != null else ""])
	await _press_joypad_button(JOY_BUTTON_B)
	var closed_drawer := _overworld_chrome_state(shell)
	var after_fresh_back: Dictionary = dialog.validation_snapshot()
	if not _overworld_drawer_state_exact(closed_drawer, "") \
			or _manual_dialog_transaction_state(after_fresh_back) != _manual_dialog_transaction_state(after) \
			or _overworld_drawer_authority_signature(shell, session) != baseline_authority:
		return _fail_shell(shell, "Fresh post-overwrite Back did not close only the %s drawer: dialog=%s chrome=%s." % [drawer, JSON.stringify(after_fresh_back), JSON.stringify(closed_drawer)])
	var confirm_input := String(case.get("confirm", ""))
	if confirm_input != "" and not await _exercise_overworld_drawer_confirm(shell, session, drawer, confirm_input, protected_states, campaign_before, settings_before):
		return false
	shell.queue_free()
	await _settle()
	return true

func _exercise_overworld_drawer_confirm(
	shell,
	session,
	drawer: String,
	confirm_input: String,
	protected_states: Dictionary,
	campaign_before: Dictionary,
	settings_before: Dictionary
) -> bool:
	var save_button: Button = shell.get_node("%Save")
	var dialog: ConfirmationDialog = shell.get_node("ManualSaveOverwriteDialog")
	var drawer_state: Dictionary = shell.validation_open_command_drawer() if drawer == "command" else shell.validation_open_frontier_drawer()
	if not _overworld_drawer_state_exact(drawer_state, drawer):
		return _fail_shell(shell, "Overworld %s confirm fixture could not reopen its drawer." % drawer)
	save_button.grab_focus()
	await get_tree().process_frame
	var authority_before := _overworld_confirm_authority_signature(shell, session)
	var request: Dictionary = shell.validation_request_manual_save()
	await _settle()
	if not bool(request.get("visible", false)) or not _safe_dialog_ready(dialog, "Keep Save"):
		return _fail_shell(shell, "Overworld %s drawer could not reopen overwrite confirmation for %s." % [drawer, confirm_input])
	if not bool(shell.validation_select_save_slot(3)):
		return _fail_shell(shell, "Overworld %s drawer confirm fixture could not change visible selection to Manual Slot 3." % drawer)
	var slot3_before := _file_state(_manual_slot_path(3))
	var dialog_before: Dictionary = dialog.validation_snapshot()
	var ok_button: Button = dialog.get_ok_button()
	ok_button.grab_focus()
	await get_tree().process_frame
	if confirm_input == "joypad":
		await _press_joypad_button(JOY_BUTTON_A)
	else:
		await _press_key(KEY_ENTER)
	var dialog_after: Dictionary = dialog.validation_snapshot()
	var summary: Dictionary = SaveService.inspect_manual_slot(2)
	var profile: Dictionary = SaveService.validation_last_runtime_save_profile()
	var step_counts := {}
	for step_value in profile.get("steps", []):
		if step_value is Dictionary:
			var step_name := String(step_value.get("name", ""))
			step_counts[step_name] = int(step_counts.get(step_name, 0)) + 1
	var chrome := _overworld_chrome_state(shell)
	if bool(dialog_after.get("visible", true)) \
			or int(dialog_after.get("pending_slot", -1)) != 0 \
			or not (dialog_after.get("action", null) is Dictionary) \
			or not dialog_after.get("action", {}).is_empty() \
			or int(dialog_after.get("request_count", -1)) != int(dialog_before.get("request_count", 0)) \
			or int(dialog_after.get("confirm_count", -1)) != int(dialog_before.get("confirm_count", 0)) + 1 \
			or int(dialog_after.get("cancel_count", -1)) != int(dialog_before.get("cancel_count", 0)) \
			or not _overworld_drawer_state_exact(chrome, drawer) \
			or not SaveService.can_load_summary(summary) \
			or int(summary.get("day", 0)) != int(session.day) \
			or _file_state(_manual_slot_path(3)) != slot3_before \
			or String(profile.get("slot_type", "")) != SaveService.SLOT_TYPE_MANUAL \
			or String(profile.get("path", "")) != _manual_slot_path(2) \
			or int(profile.get("written_bytes", 0)) != FileAccess.get_size(_manual_slot_path(2)) \
			or int(profile.get("recovery_count", 0)) != 1 \
			or int(step_counts.get("write_payload_start", 0)) != 1 \
			or int(step_counts.get("finished", 0)) != 1 \
			or _overworld_confirm_authority_signature(shell, session) != authority_before \
			or not _require_preserved_state(protected_states, session.to_dict(), campaign_before, settings_before, _manual_slot_path(2)):
		return _fail_shell(shell, "Overworld %s drawer %s overwrite did not remain slot-bound and execute once: before=%s after=%s summary=%s profile=%s chrome=%s." % [drawer, confirm_input, JSON.stringify(dialog_before), JSON.stringify(dialog_after), JSON.stringify(summary), JSON.stringify(profile), JSON.stringify(chrome)])
	await _press_joypad_button(JOY_BUTTON_B)
	if not _overworld_drawer_state_exact(_overworld_chrome_state(shell), ""):
		return _fail_shell(shell, "Fresh Back did not close the %s drawer after %s overwrite confirmation." % [drawer, confirm_input])
	return true

func _exercise_overworld_neighbor_modal_owners(
	protected_states: Dictionary,
	campaign_before: Dictionary,
	settings_before: Dictionary
) -> bool:
	var session = _session_for_route("overworld", 40)
	session = SessionState.set_active_session(session)
	SaveService.set_selected_manual_slot(2)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var baseline_authority := _overworld_drawer_authority_signature(shell, session)

	var command_state: Dictionary = shell.validation_open_command_drawer()
	var picker: OptionButton = shell.get_node("%SaveSlot")
	picker.grab_focus()
	var command_authority := _overworld_drawer_authority_signature(shell, session)
	picker.show_popup()
	await _settle()
	if not picker.get_popup().visible or not _overworld_drawer_state_exact(command_state, "command"):
		return _fail_shell(shell, "Overworld SaveSlot neighbor fixture did not open above Command drawer.")
	await _press_joypad_button(JOY_BUTTON_B)
	if picker.get_popup().visible \
			or not _overworld_drawer_state_exact(_overworld_chrome_state(shell), "command") \
			or _overworld_drawer_authority_signature(shell, session) != command_authority:
		return _fail_shell(shell, "Overworld SaveSlot popup cancel escaped into Command drawer ownership.")
	await _press_joypad_button(JOY_BUTTON_B)
	if not _overworld_drawer_state_exact(_overworld_chrome_state(shell), "") \
			or _overworld_drawer_authority_signature(shell, session) != baseline_authority:
		return _fail_shell(shell, "Fresh Back did not close Command drawer after SaveSlot popup cancellation.")

	var frontier_state: Dictionary = shell.validation_open_frontier_drawer()
	var settings_button: Button = shell.get_node("%Settings")
	settings_button.grab_focus()
	await get_tree().process_frame
	var frontier_authority := _overworld_drawer_authority_signature(shell, session)
	var settings_open: Dictionary = shell.validation_open_active_play_settings()
	var settings_dialog = shell.validation_active_play_settings_dialog()
	await _settle()
	if not bool(settings_open.get("visible", false)) or not _overworld_drawer_state_exact(frontier_state, "frontier"):
		return _fail_shell(shell, "Overworld Settings neighbor fixture did not open above Frontier drawer.")
	await _press_key(KEY_ESCAPE)
	if settings_dialog.is_open() \
			or get_viewport().gui_get_focus_owner() != settings_button \
			or not _overworld_drawer_state_exact(_overworld_chrome_state(shell), "frontier") \
			or _overworld_drawer_authority_signature(shell, session) != frontier_authority:
		return _fail_shell(shell, "Overworld Settings cancel escaped into Frontier drawer ownership.")
	await _press_joypad_button(JOY_BUTTON_B)
	if not _overworld_drawer_state_exact(_overworld_chrome_state(shell), "") \
			or _overworld_drawer_authority_signature(shell, session) != baseline_authority:
		return _fail_shell(shell, "Fresh Back did not close Frontier drawer after Settings cancellation.")

	command_state = shell.validation_open_command_drawer()
	var end_turn_button: Button = shell.get_node("%EndTurn")
	end_turn_button.grab_focus()
	await get_tree().process_frame
	command_authority = _overworld_drawer_authority_signature(shell, session)
	var end_before: Dictionary = shell.validation_end_turn_confirmation_snapshot()
	var end_request: Dictionary = shell.validation_request_end_turn()
	await _settle()
	if not bool(end_request.get("confirmation_required", false)) \
			or not bool(end_request.get("dialog_visible", false)) \
			or not _overworld_drawer_state_exact(command_state, "command"):
		return _fail_shell(shell, "Overworld End Turn neighbor fixture did not open a confirmation above Command drawer: %s." % JSON.stringify(end_request))
	await _press_joypad_button(JOY_BUTTON_B)
	var end_after: Dictionary = shell.validation_end_turn_confirmation_snapshot()
	if bool(end_after.get("dialog_visible", true)) \
			or bool(end_after.get("pending", true)) \
			or int(end_after.get("request_count", -1)) != int(end_before.get("request_count", 0)) + 1 \
			or int(end_after.get("cancel_count", -1)) != int(end_before.get("cancel_count", 0)) + 1 \
			or int(end_after.get("confirm_count", -1)) != int(end_before.get("confirm_count", 0)) \
			or int(end_after.get("commit_count", -1)) != int(end_before.get("commit_count", 0)) \
			or int(end_after.get("rules_end_turn_call_count", -1)) != int(end_before.get("rules_end_turn_call_count", 0)) \
			or int(end_after.get("autosave_call_count", -1)) != int(end_before.get("autosave_call_count", 0)) \
			or get_viewport().gui_get_focus_owner() != end_turn_button \
			or not _overworld_drawer_state_exact(_overworld_chrome_state(shell), "command") \
			or _overworld_drawer_authority_signature(shell, session) != command_authority:
		return _fail_shell(shell, "Overworld End Turn cancel escaped into Command drawer ownership: before=%s after=%s." % [JSON.stringify(end_before), JSON.stringify(end_after)])
	await _press_joypad_button(JOY_BUTTON_B)
	if not _overworld_drawer_state_exact(_overworld_chrome_state(shell), "") \
			or _overworld_drawer_authority_signature(shell, session) != baseline_authority \
			or not _require_preserved_state(protected_states, session.to_dict(), campaign_before, settings_before, _manual_slot_path(2)):
		return _fail_shell(shell, "Fresh Back did not close Command drawer after End Turn cancellation without changing authority.")
	shell.queue_free()
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

func _overworld_chrome_state(shell) -> Dictionary:
	var snapshot: Dictionary = shell.validation_snapshot()
	var chrome_value: Variant = snapshot.get("chrome", {})
	return chrome_value.duplicate(true) if chrome_value is Dictionary else {}

func _manual_dialog_transaction_state(snapshot: Dictionary) -> Dictionary:
	var action_value: Variant = snapshot.get("action", {})
	var action: Dictionary = action_value.duplicate(true) if action_value is Dictionary else {}
	return {
		"visible": bool(snapshot.get("visible", false)),
		"pending_slot": int(snapshot.get("pending_slot", 0)),
		"action": action,
		"request_count": int(snapshot.get("request_count", 0)),
		"cancel_count": int(snapshot.get("cancel_count", 0)),
		"confirm_count": int(snapshot.get("confirm_count", 0)),
	}

func _overworld_drawer_state_exact(state: Dictionary, drawer: String) -> bool:
	if String(state.get("active_drawer", "")) != drawer:
		return false
	if drawer == "command":
		return bool(state.get("command_drawer_visible", false)) \
				and not bool(state.get("frontier_drawer_visible", true)) \
				and bool(state.get("command_spine_visible", false))
	if drawer == "frontier":
		return not bool(state.get("command_drawer_visible", true)) \
				and bool(state.get("frontier_drawer_visible", false)) \
				and bool(state.get("command_spine_visible", false))
	return not bool(state.get("command_drawer_visible", true)) \
			and not bool(state.get("frontier_drawer_visible", true))

func _overworld_drawer_authority_signature(shell, session) -> String:
	var shell_route: Dictionary = shell.validation_active_play_return_snapshot()
	shell_route.erase("focus_owner")
	var controller_routes: Dictionary = shell.validation_controller_route_cursor_snapshot()
	controller_routes.erase("focus_owner")
	var shell_snapshot: Dictionary = shell.validation_snapshot()
	return JSON.stringify({
		"session": session.to_dict(),
		"files": _capture_file_states(_tracked_paths()),
		"save_profile": SaveService.validation_last_runtime_save_profile(),
		"save_cache": SaveService.validation_summary_cache_snapshot(),
		"settings": _settings_transaction_route_authority(),
		"shell_route": shell_route,
		"app_route": AppRouter.validation_active_play_return_snapshot(),
		"overworld_handoff": AppRouter.validation_latest_overworld_handoff_profile(),
		"controller_routes": controller_routes,
		"map_viewport": shell_snapshot.get("map_viewport", {}),
		"debug_overlay": shell.validation_debug_overlay_snapshot(),
		"placement_debug_overlay": shell.validation_placement_debug_overlay_snapshot(),
	})

func _overworld_confirm_authority_signature(shell, session) -> String:
	var shell_route: Dictionary = shell.validation_active_play_return_snapshot()
	shell_route.erase("focus_owner")
	# A successful save intentionally changes the visible system message. Preserve
	# every route field that cannot change as part of the accepted write.
	shell_route.erase("visible_message")
	var controller_routes: Dictionary = shell.validation_controller_route_cursor_snapshot()
	controller_routes.erase("focus_owner")
	var shell_snapshot: Dictionary = shell.validation_snapshot()
	var map_view_value: Variant = shell_snapshot.get("map_viewport", {})
	var map_view: Dictionary = map_view_value.duplicate(true) if map_view_value is Dictionary else {}
	# The accepted save refresh deliberately advances renderer generations while
	# camera, route preview, geometry, and presentation authority stay exact.
	map_view.erase("render_cache")
	var placement_debug: Dictionary = shell.validation_placement_debug_overlay_snapshot()
	var placement_map_value: Variant = placement_debug.get("map_view", {})
	var placement_map: Dictionary = placement_map_value.duplicate(true) if placement_map_value is Dictionary else {}
	# The same refresh updates only the renderer-owned diagnostic reason.
	placement_map.erase("dynamic_reason")
	placement_debug["map_view"] = placement_map
	return JSON.stringify({
		"session": session.to_dict(),
		"settings": _settings_transaction_route_authority(),
		"shell_route": shell_route,
		"app_route": AppRouter.validation_active_play_return_snapshot(),
		"overworld_handoff": AppRouter.validation_latest_overworld_handoff_profile(),
		"controller_routes": controller_routes,
		"map_viewport": map_view,
		"debug_overlay": shell.validation_debug_overlay_snapshot(),
		"placement_debug_overlay": placement_debug,
	})

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

func _exclusive_route_authority_snapshot(shell, session, route_id: String) -> Dictionary:
	var shell_snapshot: Dictionary = shell.validation_snapshot()
	var shell_profile: Dictionary = shell_snapshot.get("profile", {}).duplicate(true) if shell_snapshot.get("profile", {}) is Dictionary else {}
	for profile_key in EXCLUSIVE_SNAPSHOT_OBSERVER_PROFILE_KEYS:
		shell_profile.erase(profile_key)
	shell_snapshot["profile"] = shell_profile
	if shell_snapshot.get("ambient_audio", {}) is Dictionary:
		var ambient_audio: Dictionary = shell_snapshot.get("ambient_audio", {}).duplicate(true)
		ambient_audio.erase("active_player_count")
		shell_snapshot["ambient_audio"] = ambient_audio
	var shell_route: Dictionary = shell.validation_active_play_return_snapshot()
	var authority := {
		"session": session.to_dict(),
		"files": _capture_file_states(_tracked_paths()),
		"campaign": CampaignProgression.ensure_profile(),
		"save_profile": SaveService.validation_last_runtime_save_profile(),
		"save_cache": SaveService.validation_summary_cache_snapshot(),
		"settings": _settings_transaction_route_authority(),
		"shell": shell_snapshot,
		"shell_route": shell_route,
		"app_route": AppRouter.validation_active_play_return_snapshot(),
		"overworld_handoff": AppRouter.validation_latest_overworld_handoff_profile(),
	}
	match route_id:
		"overworld":
			authority["controller_routes"] = shell.validation_controller_route_cursor_snapshot()
			authority["debug_overlay"] = shell.validation_debug_overlay_snapshot()
			authority["placement_debug_overlay"] = shell.validation_placement_debug_overlay_snapshot()
		"town":
			authority["town_cache"] = shell.validation_town_entity_cache_snapshot()
		"battle":
			authority["battle_playback"] = shell.validation_battle_playback_speed_snapshot()
		"outcome":
			authority["outcome_focus"] = shell.validation_outcome_focus_snapshot()
	return authority

func _exclusive_route_background_authority(full_authority: Dictionary) -> Dictionary:
	var background := full_authority.duplicate(true)
	var shell_snapshot: Dictionary = background.get("shell", {}).duplicate(true) if background.get("shell", {}) is Dictionary else {}
	shell_snapshot.erase("manual_save_overwrite_dialog")
	if shell_snapshot.get("generated_opening_autosave_recovery", {}) is Dictionary:
		var generated_recovery: Dictionary = shell_snapshot.get("generated_opening_autosave_recovery", {}).duplicate(true)
		generated_recovery.erase("manual_fallback_count")
		shell_snapshot["generated_opening_autosave_recovery"] = generated_recovery
	if shell_snapshot.get("outcome_focus", {}) is Dictionary:
		var shell_outcome_focus: Dictionary = shell_snapshot.get("outcome_focus", {}).duplicate(true)
		shell_outcome_focus.erase("manual_overwrite_visible")
		shell_snapshot["outcome_focus"] = shell_outcome_focus
	background["shell"] = shell_snapshot
	if background.get("outcome_focus", {}) is Dictionary:
		var outcome_focus: Dictionary = background.get("outcome_focus", {}).duplicate(true)
		outcome_focus.erase("manual_overwrite_visible")
		background["outcome_focus"] = outcome_focus
	if background.get("controller_routes", {}) is Dictionary:
		var controller_routes: Dictionary = background.get("controller_routes", {}).duplicate(true)
		for controller_key in EXCLUSIVE_BACKGROUND_CONTROLLER_MODAL_KEYS:
			controller_routes.erase(controller_key)
		background["controller_routes"] = controller_routes
	return background

func _exclusive_manual_fallback_count(full_authority: Dictionary) -> int:
	var shell_snapshot: Dictionary = full_authority.get("shell", {}) if full_authority.get("shell", {}) is Dictionary else {}
	var generated_recovery: Dictionary = shell_snapshot.get("generated_opening_autosave_recovery", {}) if shell_snapshot.get("generated_opening_autosave_recovery", {}) is Dictionary else {}
	return int(generated_recovery.get("manual_fallback_count", -1))

func _authority_component_checks(before: Dictionary, after: Dictionary) -> Dictionary:
	var checks := {}
	var keys := before.keys().duplicate()
	for key in after.keys():
		if key not in keys:
			keys.append(key)
	keys.sort()
	for key in keys:
		checks[String(key)] = before.has(key) and after.has(key) and before.get(key) == after.get(key)
	return checks

func _checks_exact(checks: Dictionary) -> bool:
	for check_value in checks.values():
		if not bool(check_value):
			return false
	return true

func _differing_component_values(before: Dictionary, after: Dictionary) -> Dictionary:
	var differences := {}
	var keys := before.keys().duplicate()
	for key in after.keys():
		if key not in keys:
			keys.append(key)
	keys.sort()
	for key in keys:
		if not before.has(key) or not after.has(key) or before.get(key) != after.get(key):
			differences[String(key)] = {
				"before": before.get(key) if before.has(key) else null,
				"after": after.get(key) if after.has(key) else null,
			}
	return differences

func _exclusive_parent_click_geometry(control: Button, dialog: ConfirmationDialog) -> Dictionary:
	var runner_viewport := get_viewport()
	var control_viewport := control.get_viewport()
	var parent_click := _control_root_click_position(control)
	var parent_rect := _control_root_rect(control)
	var dialog_rect := Rect2(Vector2(dialog.position), Vector2(dialog.size))
	var cancel_button := dialog.get_cancel_button()
	var child_click := _control_root_click_position(cancel_button)
	var child_rect := _control_root_rect(cancel_button)
	var exact := dialog.exclusive \
			and control_viewport == runner_viewport \
			and control.is_visible_in_tree() \
			and not control.disabled \
			and control.mouse_filter != Control.MOUSE_FILTER_IGNORE \
			and parent_rect.has_point(parent_click) \
			and runner_viewport.get_visible_rect().has_point(parent_click) \
			and not dialog_rect.has_point(parent_click) \
			and cancel_button.get_viewport() == dialog \
			and dialog_rect.has_point(child_click) \
			and child_rect.has_point(child_click) \
			and runner_viewport.get_visible_rect().encloses(dialog_rect)
	return {
		"exact": exact,
		"exclusive": dialog.exclusive,
		"parent_enabled": not control.disabled,
		"parent_visible": control.is_visible_in_tree(),
		"parent_viewport_is_root": control_viewport == runner_viewport,
		"parent_rect": parent_rect,
		"parent_click": parent_click,
		"parent_outside_dialog": not dialog_rect.has_point(parent_click),
		"dialog_rect": dialog_rect,
		"child_rect": child_rect,
		"child_click": child_click,
		"child_inside_dialog": dialog_rect.has_point(child_click),
		"root_rect": runner_viewport.get_visible_rect(),
	}

func _dialog_child_click_geometry(control: Control, dialog: ConfirmationDialog) -> Dictionary:
	var runner_viewport := get_viewport()
	var source_viewport := control.get_viewport()
	var click_position := _control_root_click_position(control)
	var control_rect := _control_root_rect(control)
	var dialog_rect := Rect2(Vector2(dialog.position), Vector2(dialog.size))
	var exact := source_viewport == dialog \
			and source_viewport != runner_viewport \
			and control.is_visible_in_tree() \
			and control_rect.has_point(click_position) \
			and dialog_rect.has_point(click_position) \
			and runner_viewport.get_visible_rect().encloses(dialog_rect)
	return {
		"exact": exact,
		"source_is_dialog": source_viewport == dialog,
		"source_is_child_window": source_viewport != runner_viewport,
		"control_rect": control_rect,
		"click": click_position,
		"dialog_rect": dialog_rect,
		"root_rect": runner_viewport.get_visible_rect(),
	}

func _cancel_manual_dialog_with_input(dialog: ConfirmationDialog, input_id: String) -> bool:
	match input_id:
		"joypad_b":
			await _press_joypad_button(JOY_BUTTON_B)
		"escape":
			await _press_key(KEY_ESCAPE)
		"mouse":
			var cancel_button := dialog.get_cancel_button()
			var geometry := _dialog_child_click_geometry(cancel_button, dialog)
			if not bool(geometry.get("exact", false)):
				return _fail_bool("Native dialog mouse-cancel geometry was not exact: %s." % JSON.stringify(geometry))
			await _click_control(cancel_button)
		_:
			return _fail_bool("Unsupported exclusive-dialog cancel input %s." % input_id)
	return true

func _confirm_manual_dialog_with_input(dialog: ConfirmationDialog, input_id: String) -> bool:
	var ok_button := dialog.get_ok_button()
	match input_id:
		"joypad_a":
			ok_button.grab_focus()
			await get_tree().process_frame
			await _press_joypad_button(JOY_BUTTON_A)
		"enter":
			ok_button.grab_focus()
			await get_tree().process_frame
			await _press_key(KEY_ENTER)
		"mouse":
			var geometry := _dialog_child_click_geometry(ok_button, dialog)
			if not bool(geometry.get("exact", false)):
				return _fail_bool("Native dialog mouse-confirm geometry was not exact: %s." % JSON.stringify(geometry))
			await _click_control(ok_button)
		_:
			return _fail_bool("Unsupported exclusive-dialog confirm input %s." % input_id)
	return true

func _settle_route_dialog(route_id: String) -> void:
	await _settle()
	if route_id == "battle":
		# Battle refreshes its tactical focus surfaces through deferred callbacks.
		# Wait beyond the dialog's own two-stage safe-cancel focus restoration.
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame

func _summary_cache_contains_exact_summary(cache: Dictionary, expected_summary: Dictionary) -> bool:
	for cache_value in cache.values():
		if not (cache_value is Dictionary):
			continue
		var cached_summary: Variant = cache_value.get("summary", {})
		if cached_summary is Dictionary \
				and String(cached_summary.get("slot_type", "")) == SaveService.SLOT_TYPE_MANUAL \
				and String(cached_summary.get("path", "")) == _manual_slot_path(2) \
				and cached_summary == expected_summary:
			return true
	return false

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

func _control_root_rect(control: Control) -> Rect2:
	var control_rect := control.get_global_rect()
	var source_viewport := control.get_viewport()
	var runner_viewport := get_viewport()
	if source_viewport is Window and source_viewport != runner_viewport:
		control_rect.position += Vector2((source_viewport as Window).position)
	return control_rect

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

func _preserved_state_component_checks(
	protected_states: Dictionary,
	active_payload: Dictionary,
	campaign_before: Dictionary,
	settings_before: Dictionary,
	excluded_path: String
) -> Dictionary:
	var protected_files_exact := true
	for path_value in protected_states.keys():
		var path := String(path_value)
		if path == excluded_path:
			continue
		protected_files_exact = protected_files_exact and _file_state(path) == protected_states.get(path, {})
	return {
		"protected_files_exact": protected_files_exact,
		"active_session_exact": SessionState.active_session != null and SessionState.active_session.to_dict() == active_payload,
		"campaign_progression_exact": CampaignProgression.ensure_profile() == campaign_before,
		"device_settings_exact": SettingsService.settings == settings_before,
		"save_version_exact": SessionState.SAVE_VERSION == 9,
	}

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
		if layout_host is Control and (
			String(layout_host.name).begins_with("TownLayoutHost_")
			or String(layout_host.name).begins_with("ExclusiveRouteLayoutHost_")
		):
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
