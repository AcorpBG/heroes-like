extends Node

const REPORT_ID := "ACTIVE_PLAY_KEYBOARD_FOCUS_SMOKE"
const CAPTURE_DIR := "res://.artifacts/active_play_keyboard_focus_smoke"
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

var _failed := false
var _exclusive_end_turn_parent_click_counts := {}
var _exclusive_end_turn_dialog_signal_counts := {}
var _exclusive_battle_parent_click_counts := {}
var _exclusive_battle_dialog_signal_counts := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _check_overworld_focus_and_movement_key():
		return
	if not await _check_overworld_controller_movement():
		return
	if not await _check_overworld_controller_route_selection():
		return
	if not await _check_overworld_end_turn_confirmation_cancel():
		return
	if not await _check_overworld_manual_save_overwrite_cancel():
		return
	if not await _check_town_keyboard_build():
		return
	if not await _check_narrow_town_keyboard_entry():
		return
	if not await _check_battle_confirmation_exclusive_parent_input():
		return
	if not await _check_battle_keyboard_defend():
		return
	if not await _check_town_return_to_field_controller():
		return
	print("%s PASS" % REPORT_ID)
	get_tree().quit(0)

func _check_overworld_focus_and_movement_key() -> bool:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null or focus_owner.name != "PrimaryAction":
		return _fail("Overworld entry focus expected PrimaryAction, got %s." % _focus_name())
	if focus_owner.get_theme_stylebox("focus") == null:
		return _fail("Overworld entry command has no visible focus style.")
	await _press_action("ui_focus_next")
	var next_owner := get_viewport().gui_get_focus_owner()
	if next_owner == null or next_owner == focus_owner or not shell.is_ancestor_of(next_owner):
		return _fail("Overworld focus cycle did not reach another live command: %s." % _focus_name())

	var move := _legal_cardinal_move(session)
	if move.is_empty():
		return _fail("Overworld fixture has no legal cardinal move for WASD validation.")
	var before := OverworldRules.hero_position(session)
	await _press_key(int(move.get("keycode", 0)))
	var after := OverworldRules.hero_position(session)
	if after != before + move.get("delta", Vector2i.ZERO):
		return _fail("Focused overworld UI swallowed the configured movement key: before=%s after=%s move=%s focus=%s class=%s." % [before, after, move, _focus_name(), next_owner.get_class()])
	if get_viewport().gui_get_focus_owner() == null:
		return _fail("Configured overworld movement discarded keyboard focus.")
	if not _assert_accessible_surface(shell, "overworld", 3):
		return false
	shell.queue_free()
	await get_tree().process_frame
	return true

func _check_town_keyboard_build() -> bool:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var town := _first_player_town(session)
	if town.is_empty():
		return _fail("Town fixture has no player-owned town.")
	_seed_town_management_navigation_fixture(session, town)
	_move_active_hero_to_town(session, town)
	var built_before: Array = town.get("built_buildings", []).duplicate()
	var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	session = SessionState.set_active_session(session)
	town = _first_player_town(session)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	if not _assert_accessible_surface(shell, "town", 3):
		return false
	if not await _check_town_management_tab_navigation(shell, session, "wide"):
		return false

	var build_actions: Control = shell.get_node("%BuildActions")
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null or not build_actions.is_ancestor_of(focus_owner) or not (focus_owner is BaseButton) or focus_owner.disabled:
		return _fail("Town entry focus did not land on a ready construction order: %s." % _focus_name())
	var first_build_focus := focus_owner
	await _press_joypad_button(JOY_BUTTON_RIGHT_SHOULDER)
	var next_town_focus := get_viewport().gui_get_focus_owner()
	if next_town_focus == null or next_town_focus == first_build_focus or not shell.is_ancestor_of(next_town_focus):
		return _fail("Town right shoulder did not advance the active-play focus cycle: before=%s after=%s." % [first_build_focus, next_town_focus])
	await _press_joypad_button(JOY_BUTTON_LEFT_SHOULDER)
	if get_viewport().gui_get_focus_owner() != first_build_focus:
		return _fail("Town left shoulder did not return to the original construction order: expected=%s got=%s." % [first_build_focus, get_viewport().gui_get_focus_owner()])
	await _capture_if_requested("town_build_order_focus")
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()
	if town.get("built_buildings", []) != built_before or session.overworld.get("resources", {}) != resources_before:
		return _fail("Selecting a focused town order spent resources before confirmation.")

	var confirm: Button = shell.get_node("%ConfirmBuild")
	if confirm.disabled:
		return _fail("Focused town order did not enable its confirmation command.")
	confirm.grab_focus()
	await get_tree().process_frame
	await _capture_if_requested("town_build_confirmation_focus")
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()
	var built_after: Array = _first_player_town(session).get("built_buildings", [])
	if built_after.size() != built_before.size() + 1:
		return _fail("Controller-confirmed town construction did not add one building: before=%s after=%s." % [built_before, built_after])
	if session.overworld.get("resources", {}) == resources_before:
		return _fail("Controller-confirmed town construction did not spend resources.")
	if get_viewport().gui_get_focus_owner() == null:
		return _fail("Town construction refresh did not restore keyboard focus.")
	shell.queue_free()
	await get_tree().process_frame
	return true

func _check_overworld_controller_movement() -> bool:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var focus_before_dpad := get_viewport().gui_get_focus_owner()
	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	var focus_after_dpad := get_viewport().gui_get_focus_owner()
	if focus_before_dpad == null or focus_after_dpad == null or focus_after_dpad == focus_before_dpad or not shell.is_ancestor_of(focus_after_dpad):
		return _fail("Overworld D-pad did not remain available for command focus navigation: before=%s after=%s." % [focus_before_dpad, focus_after_dpad])
	await _press_joypad_button(JOY_BUTTON_RIGHT_SHOULDER)
	var focus_after_right_shoulder := get_viewport().gui_get_focus_owner()
	if focus_after_right_shoulder == null or focus_after_right_shoulder == focus_after_dpad or not shell.is_ancestor_of(focus_after_right_shoulder):
		return _fail("Overworld right shoulder did not advance the command focus cycle: before=%s after=%s." % [focus_after_dpad, focus_after_right_shoulder])
	await _press_joypad_button(JOY_BUTTON_LEFT_SHOULDER)
	if get_viewport().gui_get_focus_owner() != focus_after_dpad:
		return _fail("Overworld left shoulder did not reverse the command focus cycle: expected=%s got=%s." % [focus_after_dpad, get_viewport().gui_get_focus_owner()])
	var drawer_snapshot: Dictionary = shell.call("validation_open_command_drawer")
	if String(drawer_snapshot.get("active_drawer", "")) != "command":
		return _fail("Overworld controller-back fixture could not open the Command drawer: %s." % drawer_snapshot)
	await _press_joypad_button(JOY_BUTTON_B)
	if shell.get_node("%CommandPanel").visible or shell.get_node("%FrontierPanel").visible:
		return _fail("Overworld controller B did not close the open Command drawer.")
	var move := _legal_cardinal_move(session, 2)
	if move.is_empty():
		return _fail("Overworld fixture has no two-step legal cardinal route for controller repeat validation.")
	var before := OverworldRules.hero_position(session)
	var axis_input := _controller_axis_for_delta(move.get("delta", Vector2i.ZERO))
	var axis := int(axis_input.get("axis", -1))
	var axis_value := float(axis_input.get("value", 0.0))
	await _send_joypad_axis(axis, axis_value * 0.2)
	await _send_joypad_axis(axis, 0.0)
	if OverworldRules.hero_position(session) != before:
		return _fail("Overworld left-stick dead zone moved the hero: before=%s after=%s." % [before, OverworldRules.hero_position(session)])
	await _send_joypad_axis(axis, axis_value)
	var immediate := OverworldRules.hero_position(session)
	if immediate != before + move.get("delta", Vector2i.ZERO):
		return _fail("Overworld left-stick deflection did not move immediately: before=%s immediate=%s move=%s." % [before, immediate, move])
	await get_tree().create_timer(0.42).timeout
	var after := OverworldRules.hero_position(session)
	if after != before + move.get("delta", Vector2i.ZERO) * 2:
		return _fail("Overworld left-stick initial/repeat cadence did not move exactly two steps: before=%s after=%s move=%s." % [before, after, move])
	await _send_joypad_axis(axis, 0.0)
	if get_viewport().gui_get_focus_owner() == null:
		return _fail("Overworld left-stick movement discarded focused UI state.")
	shell.queue_free()
	await get_tree().process_frame
	return true

func _check_overworld_controller_route_selection() -> bool:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	for method_name in [
		"validation_reset_controller_route_cursor",
		"validation_controller_route_cursor_snapshot",
	]:
		if not shell.has_method(method_name):
			return _fail("Overworld right-stick route cursor is missing %s." % method_name)
	shell.call("validation_reset_controller_route_cursor")
	var focus_before_dpad := get_viewport().gui_get_focus_owner()
	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	var focus_after_dpad := get_viewport().gui_get_focus_owner()
	if focus_before_dpad == null or focus_after_dpad == null or focus_after_dpad == focus_before_dpad or not shell.is_ancestor_of(focus_after_dpad):
		return _fail("Overworld D-pad focus was not available before right-stick route selection: before=%s after=%s." % [focus_before_dpad, focus_after_dpad])

	var move := _legal_cardinal_move(session)
	if move.is_empty():
		return _fail("Overworld right-stick fixture has no legal cardinal preview destination.")
	var hero_before := OverworldRules.hero_position(session)
	var expected_tile: Vector2i = hero_before + move.get("delta", Vector2i.ZERO)
	var session_before_preview := JSON.stringify(session.to_dict())
	var route_axis := _controller_route_axis_for_delta(move.get("delta", Vector2i.ZERO))
	var route_axis_id := int(route_axis.get("axis", -1))
	var route_axis_value := float(route_axis.get("value", 0.0))
	await _send_joypad_axis(route_axis_id, route_axis_value)
	await _send_joypad_axis(route_axis_id, 0.0)
	var preview: Dictionary = shell.call("validation_controller_route_cursor_snapshot")
	if not bool(preview.get("active", false)) \
			or _controller_snapshot_tile(preview.get("selected_tile", {})) != expected_tile \
			or not (preview.get("route_preview", {}) is Dictionary) \
			or (preview.get("route_preview", {}) as Dictionary).is_empty() \
			or String((preview.get("primary_action", {}) as Dictionary).get("id", "")) == "" \
			or bool((preview.get("primary_action", {}) as Dictionary).get("disabled", false)):
		return _fail("Live right-stick input did not expose the existing route preview/action surface: expected=%s preview=%s." % [expected_tile, preview])
	if JSON.stringify(session.to_dict()) != session_before_preview:
		return _fail("Right-stick route preview mutated the live expedition before confirmation.")
	if get_viewport().gui_get_focus_owner() != focus_after_dpad:
		return _fail("Right-stick route preview stole D-pad command focus: expected=%s got=%s." % [focus_after_dpad, get_viewport().gui_get_focus_owner()])

	await _press_joypad_button(JOY_BUTTON_B)
	var canceled: Dictionary = shell.call("validation_controller_route_cursor_snapshot")
	if bool(canceled.get("active", true)) \
			or int(canceled.get("cancel_count", 0)) != 1 \
			or _controller_snapshot_tile(canceled.get("selected_tile", {})) != hero_before \
			or _controller_snapshot_tile(canceled.get("camera_focus_tile", {})) != hero_before:
		return _fail("Controller B did not reset the route cursor selection/camera to the hero: %s." % canceled)
	if JSON.stringify(session.to_dict()) != session_before_preview:
		return _fail("Controller route cancel changed the expedition.")
	if get_viewport().gui_get_focus_owner() != focus_after_dpad:
		return _fail("Controller route cancel did not preserve the originating D-pad focus: expected=%s got=%s." % [focus_after_dpad, get_viewport().gui_get_focus_owner()])

	await _send_joypad_axis(route_axis_id, route_axis_value)
	await _send_joypad_axis(route_axis_id, 0.0)
	await _press_joypad_button(JOY_BUTTON_A)
	var committed: Dictionary = shell.call("validation_controller_route_cursor_snapshot")
	if OverworldRules.hero_position(session) != expected_tile \
			or bool(committed.get("active", true)) \
			or int(committed.get("accept_count", 0)) != 1 \
			or int(committed.get("primary_action_invocation_count", 0)) != 1 \
			or not bool((committed.get("last_accept", {}) as Dictionary).get("activated", false)):
		return _fail("Controller A did not commit the previewed route exactly once: expected=%s actual=%s snapshot=%s." % [expected_tile, OverworldRules.hero_position(session), committed])
	if get_viewport().gui_get_focus_owner() != focus_after_dpad:
		return _fail("Controller route commit changed command focus: expected=%s got=%s." % [focus_after_dpad, get_viewport().gui_get_focus_owner()])

	await _press_joypad_button(JOY_BUTTON_DPAD_UP)
	var focus_after_route_dpad := get_viewport().gui_get_focus_owner()
	if focus_after_route_dpad == null or focus_after_route_dpad == focus_after_dpad or not shell.is_ancestor_of(focus_after_route_dpad):
		return _fail("D-pad command focus did not remain usable after route commit: before=%s after=%s." % [focus_after_dpad, focus_after_route_dpad])
	var left_move := _legal_cardinal_move(session)
	if left_move.is_empty():
		return _fail("Overworld right-stick integration fixture has no legal follow-up left-stick move.")
	var left_before := OverworldRules.hero_position(session)
	var left_axis := _controller_axis_for_delta(left_move.get("delta", Vector2i.ZERO))
	await _send_joypad_axis(int(left_axis.get("axis", -1)), float(left_axis.get("value", 0.0)))
	await _send_joypad_axis(int(left_axis.get("axis", -1)), 0.0)
	var left_after := OverworldRules.hero_position(session)
	var after_left: Dictionary = shell.call("validation_controller_route_cursor_snapshot")
	if left_after != left_before + left_move.get("delta", Vector2i.ZERO) or int(after_left.get("left_move_count", 0)) != 1:
		return _fail("Left-stick immediate movement changed after route-cursor use: before=%s after=%s move=%s snapshot=%s." % [left_before, left_after, left_move, after_left])
	if get_viewport().gui_get_focus_owner() == null:
		return _fail("Left-stick movement after route-cursor use discarded D-pad focus.")
	shell.queue_free()
	await get_tree().process_frame
	return true

func _check_overworld_end_turn_confirmation_cancel() -> bool:
	var original_window_size := get_window().size
	var cases := [
		{"id": "end_turn_controller_1280", "width": 1280, "cancel_input": "joypad_b", "confirm_input": "joypad_a"},
		{"id": "end_turn_keyboard_1920", "width": 1920, "cancel_input": "escape", "confirm_input": "enter"},
		{"id": "end_turn_native_mouse_1280", "width": 1280, "cancel_input": "mouse", "confirm_input": "mouse"},
	]
	for case_value in cases:
		if not await _exercise_overworld_end_turn_exclusive_case(case_value):
			get_window().size = original_window_size
			return false
	get_window().size = original_window_size
	await _settle()
	return true


func _exercise_overworld_end_turn_exclusive_case(case_data: Dictionary) -> bool:
	var case_id := String(case_data.get("id", "end_turn_exclusive"))
	var width := int(case_data.get("width", 1280))
	var autosave_states := {}
	for path in _end_turn_autosave_paths():
		autosave_states[path] = _controller_route_file_state(path)
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session = SessionState.set_active_session(session)
	get_window().size = Vector2i(width, 720)
	await _settle()
	var layout_host := Control.new()
	layout_host.name = "ExclusiveEndTurnHost_%s" % case_id
	layout_host.size = Vector2(float(width), 720.0)
	add_child(layout_host)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	layout_host.add_child(shell)
	var parent_probe := Button.new()
	parent_probe.name = "ExclusiveEndTurnParentProbe_%s" % case_id
	parent_probe.text = "End Turn parent input probe"
	parent_probe.position = Vector2(16.0, 16.0)
	parent_probe.size = Vector2(220.0, 40.0)
	parent_probe.focus_mode = Control.FOCUS_NONE
	parent_probe.z_index = 100
	_exclusive_end_turn_parent_click_counts[case_id] = 0
	_exclusive_end_turn_dialog_signal_counts[case_id] = {"canceled": 0, "confirmed": 0}
	parent_probe.pressed.connect(_on_exclusive_end_turn_parent_probe_pressed.bind(case_id))
	layout_host.add_child(parent_probe)
	await _settle_end_turn_confirmation()
	var end_turn: Button = shell.get_node_or_null("%EndTurn")
	var dialog: ConfirmationDialog = shell.get_node_or_null("EndTurnConfirmationDialog")
	if end_turn == null or dialog == null or end_turn.disabled:
		return _fail_exclusive_end_turn_case(layout_host, autosave_states, "%s is missing an actionable End Turn origin or dialog." % case_id)
	dialog.canceled.connect(_on_exclusive_end_turn_dialog_canceled.bind(case_id))
	dialog.confirmed.connect(_on_exclusive_end_turn_dialog_confirmed.bind(case_id))
	shell.call("validation_reset_end_turn_confirmation_state")
	shell.call("validation_set_end_turn_resolution_routing_enabled", false)
	var live_snapshot: Dictionary = shell.call("validation_end_turn_confirmation_snapshot")
	var fixture_checks := {
		"host_parent_exact": shell.get_parent() == layout_host,
		"host_width_exact": int(layout_host.size.x) == width,
		"host_height_exact": int(layout_host.size.y) == 720,
		"origin_root_viewport_exact": end_turn.get_viewport() == get_viewport(),
		"warning_required": bool(live_snapshot.get("confirmation_required", false)),
		"stable_action_label": String(live_snapshot.get("surface_button_text", "")) == "End Turn?",
		"surface_warned": bool(live_snapshot.get("surface_warning_hint", false)),
	}
	if not _checks_exact(fixture_checks):
		return _fail_exclusive_end_turn_case(layout_host, autosave_states, "%s exact-width End Turn fixture failed: %s." % [case_id, JSON.stringify(fixture_checks)])
	end_turn.grab_focus()
	await get_tree().process_frame
	await _click_control(end_turn)
	await _settle_end_turn_confirmation()
	if not _assert_overworld_end_turn_dialog(shell, dialog, live_snapshot):
		_cleanup_exclusive_end_turn_case(layout_host, autosave_states)
		return false
	var opened := _end_turn_confirmation_transaction_snapshot(shell)
	var geometry := _exclusive_battle_parent_click_geometry(parent_probe, dialog)
	var opened_checks := {
		"exclusive_exact": dialog.exclusive,
		"pending_identity_exact": _end_turn_pending_identity_exact(opened, session),
		"request_once": int(opened.get("request_count", -1)) == 1,
		"safe_focus_exact": dialog.get_cancel_button().get_viewport().gui_get_focus_owner() == dialog.get_cancel_button(),
		"geometry_exact": bool(geometry.get("exact", false)),
	}
	if not _checks_exact(opened_checks):
		return _fail_exclusive_end_turn_case(layout_host, autosave_states, "%s did not open an exact exclusive End Turn dialog: checks=%s geometry=%s opened=%s." % [case_id, JSON.stringify(opened_checks), JSON.stringify(geometry), JSON.stringify(opened)])
	var authority_before_block := _end_turn_exclusive_authority_snapshot(shell, session, false)
	var transaction_before_block := _end_turn_confirmation_transaction_snapshot(shell)
	var parent_count_before := int(_exclusive_end_turn_parent_click_counts.get(case_id, 0))
	await _click_control(parent_probe)
	await _settle_end_turn_confirmation()
	var first_block_checks := {
		"parent_count_exact": int(_exclusive_end_turn_parent_click_counts.get(case_id, -1)) == parent_count_before,
		"dialog_transaction_exact": _end_turn_confirmation_transaction_snapshot(shell) == transaction_before_block,
		"full_same_state_authority_exact": _end_turn_exclusive_authority_snapshot(shell, session, false) == authority_before_block,
		"dialog_focus_exact": dialog.get_cancel_button().get_viewport().gui_get_focus_owner() == dialog.get_cancel_button(),
	}
	if not _checks_exact(first_block_checks):
		return _fail_exclusive_end_turn_case(layout_host, autosave_states, "%s exclusive parent click escaped the first End Turn modal: checks=%s." % [case_id, JSON.stringify(first_block_checks)])
	if not await _send_end_turn_confirmation_cancel(dialog, String(case_data.get("cancel_input", ""))):
		_cleanup_exclusive_end_turn_case(layout_host, autosave_states)
		return false
	await _settle_end_turn_confirmation()
	var canceled := _end_turn_confirmation_transaction_snapshot(shell)
	var signal_counts: Dictionary = _exclusive_end_turn_dialog_signal_counts.get(case_id, {})
	var canceled_checks := {
		"hidden_exact": not bool(canceled.get("visible", true)),
		"pending_cleared_exact": not bool(canceled.get("pending", true)),
		"cancel_signal_once": int(signal_counts.get("canceled", 0)) == 1,
		"confirm_signal_zero": int(signal_counts.get("confirmed", 0)) == 0,
		"cancel_count_once": int(canceled.get("cancel_count", 0)) == 1,
		"commit_zero": int(canceled.get("commit_count", 0)) == 0,
		"rules_zero": int(canceled.get("rules_end_turn_call_count", 0)) == 0,
		"autosave_zero": int(canceled.get("autosave_call_count", 0)) == 0,
		"background_authority_exact": _end_turn_exclusive_authority_snapshot(shell, session, true) == _end_turn_exclusive_authority_snapshot_from_modal(authority_before_block),
		"origin_focus_exact": get_viewport().gui_get_focus_owner() == end_turn,
	}
	if not _checks_exact(canceled_checks):
		return _fail_exclusive_end_turn_case(layout_host, autosave_states, "%s forwarded/native cancel was not exact: checks=%s snapshot=%s." % [case_id, JSON.stringify(canceled_checks), JSON.stringify(canceled)])
	var positive_count_before := int(_exclusive_end_turn_parent_click_counts.get(case_id, 0))
	var authority_before_positive := _end_turn_exclusive_authority_snapshot(shell, session, true)
	await _click_control(parent_probe)
	var positive_checks := {
		"same_parent_action_once": int(_exclusive_end_turn_parent_click_counts.get(case_id, -1)) == positive_count_before + 1,
		"background_authority_exact": _end_turn_exclusive_authority_snapshot(shell, session, true) == authority_before_positive,
		"end_turn_transaction_exact": _end_turn_confirmation_transaction_snapshot(shell) == canceled,
	}
	if not _checks_exact(positive_checks):
		return _fail_exclusive_end_turn_case(layout_host, autosave_states, "%s identical parent probe was not positively actionable after cancel: %s." % [case_id, JSON.stringify(positive_checks)])

	# Queue a physical root event against one pending Dictionary, replace that request
	# synchronously, and prove the deferred bridge cannot affect the new identity. The
	# matching release is also delivered after replacement and must remain a no-op.
	end_turn.grab_focus()
	await _click_control(end_turn)
	await _settle_end_turn_confirmation()
	var stale_opened := _end_turn_confirmation_transaction_snapshot(shell)
	var stale_count_before := int(_exclusive_end_turn_parent_click_counts.get(case_id, 0))
	await _click_control(parent_probe)
	if int(_exclusive_end_turn_parent_click_counts.get(case_id, -1)) != stale_count_before:
		return _fail_exclusive_end_turn_case(layout_host, autosave_states, "%s stale-pending setup parent click escaped the modal." % case_id)
	var stale_pressed := InputEventKey.new()
	stale_pressed.keycode = KEY_ESCAPE
	stale_pressed.physical_keycode = KEY_ESCAPE
	stale_pressed.pressed = true
	shell.call("_on_root_window_input", stale_pressed)
	shell.call("validation_reset_end_turn_confirmation_state")
	var replacement_request: Dictionary = shell.call("validation_request_end_turn")
	await _settle_end_turn_confirmation()
	var stale_released := InputEventKey.new()
	stale_released.keycode = KEY_ESCAPE
	stale_released.physical_keycode = KEY_ESCAPE
	stale_released.pressed = false
	Input.parse_input_event(stale_released)
	await _settle_end_turn_confirmation()
	var reopened := _end_turn_confirmation_transaction_snapshot(shell)
	var stale_identity_checks := {
		"original_pending_identity_exact": _end_turn_pending_identity_exact(stale_opened, session),
		"replacement_requested": bool(replacement_request.get("confirmation_required", false)),
		"replacement_pending_identity_exact": _end_turn_pending_identity_exact(reopened, session),
		"request_once_after_reset": int(reopened.get("request_count", -1)) == 1,
		"stale_press_cancel_zero": int(reopened.get("cancel_count", -1)) == 0,
		"stale_press_confirm_zero": int(reopened.get("confirm_count", -1)) == 0,
		"stale_release_commit_zero": int(reopened.get("commit_count", -1)) == 0,
		"stale_release_rules_zero": int(reopened.get("rules_end_turn_call_count", -1)) == 0,
		"stale_release_autosave_zero": int(reopened.get("autosave_call_count", -1)) == 0,
		"dialog_still_visible": dialog.visible,
	}
	if not _checks_exact(stale_identity_checks):
		return _fail_exclusive_end_turn_case(layout_host, autosave_states, "%s deferred stale pending identity or release reached the replacement dialog: checks=%s snapshot=%s." % [case_id, JSON.stringify(stale_identity_checks), JSON.stringify(reopened)])
	var authority_before_second_block := _end_turn_exclusive_authority_snapshot(shell, session, false)
	var second_count_before := int(_exclusive_end_turn_parent_click_counts.get(case_id, 0))
	await _click_control(parent_probe)
	await _settle_end_turn_confirmation()
	var second_block_checks := {
		"parent_count_exact": int(_exclusive_end_turn_parent_click_counts.get(case_id, -1)) == second_count_before,
		"dialog_transaction_exact": _end_turn_confirmation_transaction_snapshot(shell) == reopened,
		"full_same_state_authority_exact": _end_turn_exclusive_authority_snapshot(shell, session, false) == authority_before_second_block,
		"dialog_focus_exact": dialog.get_cancel_button().get_viewport().gui_get_focus_owner() == dialog.get_cancel_button(),
	}
	if not _checks_exact(second_block_checks):
		return _fail_exclusive_end_turn_case(layout_host, autosave_states, "%s second blocked parent click changed End Turn authority: checks=%s." % [case_id, JSON.stringify(second_block_checks)])
	var direct_control := SessionStateStoreScript.SessionData.new()
	direct_control.from_dict(session.to_dict())
	if bool(reopened.get("risk_unconsumed", false)):
		OverworldRules.consume_command_risk_forecast(direct_control)
	var direct_result: Dictionary = OverworldRules.end_turn(direct_control)
	direct_control.flags["last_action"] = "ended_turn"
	if not await _send_end_turn_confirmation_confirm(dialog, String(case_data.get("confirm_input", ""))):
		_cleanup_exclusive_end_turn_case(layout_host, autosave_states)
		return false
	for _frame in range(180):
		await get_tree().process_frame
		if int(_end_turn_confirmation_transaction_snapshot(shell).get("commit_count", 0)) >= 1:
			break
	var confirmed := _end_turn_confirmation_transaction_snapshot(shell)
	signal_counts = _exclusive_end_turn_dialog_signal_counts.get(case_id, {})
	var restored = SaveService.restore_autosave_session()
	var raw_saved: Dictionary = SessionStateStoreScript.normalize_payload(SaveService.load_autosave())
	var confirmed_checks := {
		"hidden_exact": not bool(confirmed.get("visible", true)),
		"pending_cleared_exact": not bool(confirmed.get("pending", true)),
		"cancel_signal_once": int(signal_counts.get("canceled", 0)) == 1,
		"confirm_signal_once": int(signal_counts.get("confirmed", 0)) == 1,
		"confirm_count_once": int(confirmed.get("confirm_count", 0)) == 1,
		"commit_once": int(confirmed.get("commit_count", 0)) == 1,
		"rules_once": int(confirmed.get("rules_end_turn_call_count", 0)) == 1,
		"autosave_once": int(confirmed.get("autosave_call_count", 0)) == 1,
		"route_zero": int(confirmed.get("resolution_attempt_count", -1)) == 0,
		"rule_result_exact": _canonical_test_value(confirmed.get("last_rule_result", {})) == _canonical_test_value(direct_result),
		"direct_gameplay_exact": _end_turn_gameplay_payload(session) == _end_turn_gameplay_payload(direct_control),
		"raw_autosave_exact": _end_turn_gameplay_payload_dictionary(raw_saved) == _end_turn_gameplay_payload(session),
		"restored_autosave_exact": restored != null and _end_turn_gameplay_payload(restored) == _end_turn_gameplay_payload(session),
		"restored_route_exact": restored != null and SaveService.resume_target_for_session(restored) == "overworld",
	}
	if not _checks_exact(confirmed_checks):
		return _fail_exclusive_end_turn_case(layout_host, autosave_states, "%s forwarded/native confirmation diverged from direct End Turn/autosave parity: checks=%s snapshot=%s." % [case_id, JSON.stringify(confirmed_checks), JSON.stringify(confirmed)])
	_cleanup_exclusive_end_turn_case(layout_host, autosave_states)
	await _settle()
	return true


func _end_turn_confirmation_transaction_snapshot(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_end_turn_confirmation_snapshot")
	return {
		"pending": bool(snapshot.get("pending", false)),
		"visible": bool(snapshot.get("dialog_visible", false)),
		"requested_session_id": String(snapshot.get("requested_session_id", "")),
		"requested_day": int(snapshot.get("requested_day", 0)),
		"requested_status": String(snapshot.get("requested_status", "")),
		"requested_warning_signature": String(snapshot.get("requested_warning_signature", "")),
		"risk_unconsumed": bool(snapshot.get("risk_unconsumed", false)),
		"request_count": int(snapshot.get("request_count", 0)),
		"cancel_count": int(snapshot.get("cancel_count", 0)),
		"confirm_count": int(snapshot.get("confirm_count", 0)),
		"commit_count": int(snapshot.get("commit_count", 0)),
		"rules_end_turn_call_count": int(snapshot.get("rules_end_turn_call_count", 0)),
		"autosave_call_count": int(snapshot.get("autosave_call_count", 0)),
		"resolution_attempt_count": int(snapshot.get("resolution_attempt_count", 0)),
		"last_result": snapshot.get("last_result", {}),
		"last_rule_result": snapshot.get("last_rule_result", {}),
		"last_autosave_result": snapshot.get("last_autosave_result", {}),
	}


func _end_turn_pending_identity_exact(snapshot: Dictionary, session) -> bool:
	return bool(snapshot.get("pending", false)) \
		and bool(snapshot.get("visible", false)) \
		and String(snapshot.get("requested_session_id", "")) == String(session.session_id) \
		and int(snapshot.get("requested_day", 0)) == int(session.day) \
		and String(snapshot.get("requested_status", "")) == String(session.scenario_status) \
		and String(snapshot.get("requested_warning_signature", "")) != ""


func _end_turn_exclusive_authority_snapshot(shell: Node, session, normalize_modal_derivations: bool) -> Dictionary:
	var controller_routes: Dictionary = shell.call("validation_controller_route_cursor_snapshot")
	if normalize_modal_derivations:
		for key in ["available", "blocked_reason", "end_turn_confirmation_open", "focus_owner"]:
			controller_routes.erase(key)
	var settings_snapshot: Dictionary = SettingsService.validation_settings_transaction_snapshot()
	var files := {}
	var authority_paths := _end_turn_authority_paths()
	for path in authority_paths:
		files[path] = _controller_route_file_state(path)
	return {
		"session": session.to_dict(),
		"active_same": SessionState.active_session == session,
		"profile": CampaignProgression.ensure_profile().duplicate(true),
		"files": files,
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
		"settings": settings_snapshot.get("settings", {}),
		"committed_settings": settings_snapshot.get("committed_settings", {}),
		"controller_routes": controller_routes,
		"debug_overlay": shell.call("validation_debug_overlay_snapshot"),
		"placement_overlay": shell.call("validation_placement_debug_overlay_snapshot"),
		"battle_resolution": AppRouter.validation_battle_resolution_checkpoint_snapshot(),
		"battle_entry": AppRouter.validation_battle_entry_snapshot(),
		"outcome": AppRouter.validation_scenario_outcome_route_snapshot(),
		"return_to_menu": AppRouter.validation_active_play_return_snapshot(),
		"safe_quit": AppRouter.validation_safe_quit_snapshot(),
	}


func _end_turn_exclusive_authority_snapshot_from_modal(snapshot: Dictionary) -> Dictionary:
	var normalized := snapshot.duplicate(true)
	var controller_routes: Dictionary = normalized.get("controller_routes", {})
	for key in ["available", "blocked_reason", "end_turn_confirmation_open", "focus_owner"]:
		controller_routes.erase(key)
	normalized["controller_routes"] = controller_routes
	return normalized


func _end_turn_gameplay_payload(session) -> Dictionary:
	return _end_turn_gameplay_payload_dictionary(session.to_dict()) if session != null else {}


func _end_turn_gameplay_payload_dictionary(value: Dictionary) -> Dictionary:
	var payload: Dictionary = _canonical_test_value(value)
	var flags: Dictionary = payload.get("flags", {}) if payload.get("flags", {}) is Dictionary else {}
	flags.erase("last_action")
	payload["flags"] = flags
	var overworld: Dictionary = payload.get("overworld", {}) if payload.get("overworld", {}) is Dictionary else {}
	overworld.erase("command_briefing")
	payload["overworld"] = overworld
	return payload


func _canonical_test_value(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _send_end_turn_confirmation_cancel(dialog: ConfirmationDialog, input_id: String) -> bool:
	match input_id:
		"joypad_b":
			await _press_joypad_button(JOY_BUTTON_B)
		"escape":
			await _press_key(KEY_ESCAPE)
		"mouse":
			var geometry := _battle_dialog_child_click_geometry(dialog.get_cancel_button(), dialog)
			if not bool(geometry.get("exact", false)):
				return _fail("Native End Turn cancel geometry was not exact: %s." % JSON.stringify(geometry))
			await _click_control(dialog.get_cancel_button())
		_:
			return _fail("Unsupported End Turn confirmation cancel input %s." % input_id)
	return true


func _send_end_turn_confirmation_confirm(dialog: ConfirmationDialog, input_id: String) -> bool:
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
			var geometry := _battle_dialog_child_click_geometry(ok_button, dialog)
			if not bool(geometry.get("exact", false)):
				return _fail("Native End Turn confirm geometry was not exact: %s." % JSON.stringify(geometry))
			await _click_control(ok_button)
		_:
			return _fail("Unsupported End Turn confirmation confirm input %s." % input_id)
	return true


func _settle_end_turn_confirmation() -> void:
	await _settle()
	await get_tree().process_frame
	await get_tree().process_frame


func _end_turn_autosave_paths() -> Array:
	var autosave_path := "%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE]
	return [autosave_path, "%s.candidate" % autosave_path, "%s.backup" % autosave_path]


func _end_turn_authority_paths() -> Array:
	var paths := _end_turn_autosave_paths()
	for slot in SaveService.MANUAL_SLOT_IDS:
		var slot_path := "%s/%s%d.json" % [SaveService.SAVE_DIR, SaveService.SAVE_PREFIX, int(slot)]
		paths.append(slot_path)
		paths.append("%s.candidate" % slot_path)
		paths.append("%s.backup" % slot_path)
	paths.append("%s/%s" % [SaveService.SAVE_DIR, SaveService.PROGRESSION_FILE])
	paths.append(SettingsService.SETTINGS_FILE)
	paths.append("%s.candidate" % SettingsService.SETTINGS_FILE)
	paths.append("%s.backup" % SettingsService.SETTINGS_FILE)
	return paths


func _cleanup_exclusive_end_turn_case(layout_host: Node, autosave_states: Dictionary) -> void:
	for path in autosave_states:
		_restore_controller_file_state(String(path), autosave_states[path])
	SaveService.validation_clear_summary_cache()
	if is_instance_valid(layout_host):
		layout_host.queue_free()


func _fail_exclusive_end_turn_case(layout_host: Node, autosave_states: Dictionary, message: String) -> bool:
	_cleanup_exclusive_end_turn_case(layout_host, autosave_states)
	return _fail(message)


func _on_exclusive_end_turn_parent_probe_pressed(case_id: String) -> void:
	_exclusive_end_turn_parent_click_counts[case_id] = int(_exclusive_end_turn_parent_click_counts.get(case_id, 0)) + 1


func _on_exclusive_end_turn_dialog_canceled(case_id: String) -> void:
	var counts: Dictionary = _exclusive_end_turn_dialog_signal_counts.get(case_id, {}).duplicate(true)
	counts["canceled"] = int(counts.get("canceled", 0)) + 1
	_exclusive_end_turn_dialog_signal_counts[case_id] = counts


func _on_exclusive_end_turn_dialog_confirmed(case_id: String) -> void:
	var counts: Dictionary = _exclusive_end_turn_dialog_signal_counts.get(case_id, {}).duplicate(true)
	counts["confirmed"] = int(counts.get("confirmed", 0)) + 1
	_exclusive_end_turn_dialog_signal_counts[case_id] = counts

func _check_overworld_manual_save_overwrite_cancel() -> bool:
	const MANUAL_SLOT := 2
	var manual_path := _manual_slot_path(MANUAL_SLOT)
	var original_manual_state := _controller_route_file_state(manual_path)
	var original_selected_slot := SaveService.get_selected_manual_slot()
	var old_fixture = ScenarioFactory.create_session("river-pass", "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	old_fixture.day = 3
	if SaveService.save_manual_session(old_fixture.to_dict(), MANUAL_SLOT) == "":
		return _fail("Could not seed the occupied manual save for controller overwrite confirmation.")

	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.day = 8
	session = SessionState.set_active_session(session)
	SaveService.set_selected_manual_slot(MANUAL_SLOT)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var save_button: Button = shell.get_node_or_null("%Save")
	var dialog: ConfirmationDialog = shell.get_node_or_null("ManualSaveOverwriteDialog")
	if save_button == null or dialog == null or save_button.disabled:
		return _fail("Occupied active-play manual slot did not expose a live Save overwrite origin.")
	var protected_before := _manual_overwrite_protected_state(session, MANUAL_SLOT)
	shell.call("validation_reset_end_turn_confirmation_state")
	for cancel_kind in ["controller_b", "escape"]:
		save_button.grab_focus()
		await get_tree().process_frame
		if get_viewport().gui_get_focus_owner() != save_button:
			return _fail("Manual overwrite could not establish exact Save origin focus before %s." % cancel_kind)
		var end_turn_bridge_before := _end_turn_confirmation_transaction_snapshot(shell)
		await _press_joypad_button(JOY_BUTTON_A)
		await _settle()
		var dialog_snapshot_value: Variant = shell.call("validation_snapshot").get("manual_save_overwrite_dialog", {})
		var dialog_snapshot: Dictionary = dialog_snapshot_value if dialog_snapshot_value is Dictionary else {}
		if not dialog.visible or int(dialog_snapshot.get("pending_slot", 0)) != MANUAL_SLOT:
			return _fail("Controller A did not open a slot-bound active-play overwrite confirmation: %s." % dialog_snapshot)
		if dialog.get_cancel_button().text != "Keep Save":
			return _fail("Manual overwrite safe-cancel action expected 'Keep Save', got '%s'." % dialog.get_cancel_button().text)
		var dialog_viewport := dialog.get_cancel_button().get_viewport()
		var dialog_focus_owner := dialog_viewport.gui_get_focus_owner() if dialog_viewport != null else null
		if dialog_focus_owner != dialog.get_cancel_button():
			return _fail("Manual overwrite did not initially focus Keep Save in its native dialog viewport: %s." % dialog_focus_owner)
		if not _dialog_fits_root_viewport(dialog):
			return _fail("Manual overwrite confirmation exceeded the live viewport: position=%s size=%s viewport=%s." % [dialog.position, dialog.size, get_viewport().get_visible_rect().size])
		if _manual_overwrite_protected_state(session, MANUAL_SLOT) != protected_before:
			return _fail("Opening active-play manual overwrite mutated live session or save state.")
		if cancel_kind == "controller_b":
			await _press_joypad_button(JOY_BUTTON_B)
		else:
			await _press_key(KEY_ESCAPE)
		await _settle()
		dialog_snapshot_value = shell.call("validation_snapshot").get("manual_save_overwrite_dialog", {})
		dialog_snapshot = dialog_snapshot_value if dialog_snapshot_value is Dictionary else {}
		if dialog.visible or int(dialog_snapshot.get("pending_slot", -1)) != 0:
			return _fail("Active-play manual overwrite did not close and clear after %s: %s." % [cancel_kind, dialog_snapshot])
		if _manual_overwrite_protected_state(session, MANUAL_SLOT) != protected_before:
			return _fail("Canceling active-play manual overwrite with %s mutated live session or save state." % cancel_kind)
		var end_turn_bridge_after := _end_turn_confirmation_transaction_snapshot(shell)
		if end_turn_bridge_after != end_turn_bridge_before \
				or bool(end_turn_bridge_after.get("pending", true)) \
				or bool(end_turn_bridge_after.get("visible", true)):
			return _fail("Inactive End Turn transaction changed during isolated ManualSaveOverwrite physical %s ownership: before=%s after=%s." % [cancel_kind, end_turn_bridge_before, end_turn_bridge_after])
		if get_viewport().gui_get_focus_owner() != save_button:
			return _fail("Canceling active-play manual overwrite with %s did not restore the exact Save origin: %s." % [cancel_kind, _focus_name()])
	var final_dialog_value: Variant = shell.call("validation_snapshot").get("manual_save_overwrite_dialog", {})
	var final_dialog: Dictionary = final_dialog_value if final_dialog_value is Dictionary else {}
	if int(final_dialog.get("request_count", -1)) != 2 \
			or int(final_dialog.get("cancel_count", -1)) != 2 \
			or int(final_dialog.get("confirm_count", -1)) != 0 \
			or String(final_dialog.get("return_focus_name", "")) != "" \
			or String(final_dialog.get("origin_focus_owner", "")) != String(save_button.name):
		return _fail("Active-play manual overwrite controller cancel counts/origin snapshot were not exact: %s." % final_dialog)

	shell.queue_free()
	await get_tree().process_frame
	_restore_controller_file_state(manual_path, original_manual_state)
	SaveService.set_selected_manual_slot(original_selected_slot)
	SaveService.validation_clear_summary_cache()
	return true

func _manual_overwrite_protected_state(session, slot: int) -> Dictionary:
	var save_states := {}
	for manual_slot in SaveService.get_manual_slot_ids():
		save_states["manual_%d" % int(manual_slot)] = _controller_route_file_state(_manual_slot_path(int(manual_slot)))
	save_states["autosave"] = _controller_route_file_state("%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE])
	save_states["progression"] = _controller_route_file_state("%s/%s" % [SaveService.SAVE_DIR, SaveService.PROGRESSION_FILE])
	return {
		"session": session.to_dict(),
		"selected_slot": SaveService.get_selected_manual_slot(),
		"bound_slot": slot,
		"save_files": save_states,
		"settings": SettingsService.ensure_settings().duplicate(true),
		"settings_file": _controller_route_file_state(SettingsService.SETTINGS_FILE),
		"campaign_profile": CampaignProgression.ensure_profile().duplicate(true),
	}

func _manual_slot_path(slot: int) -> String:
	return "%s/%s%d.json" % [SaveService.SAVE_DIR, SaveService.SAVE_PREFIX, slot]

func _restore_controller_file_state(path: String, state: Dictionary) -> void:
	if bool(state.get("exists", false)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(state.get("bytes", PackedByteArray()))
			file.close()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _assert_overworld_end_turn_dialog(shell: Node, dialog: ConfirmationDialog, live_snapshot: Dictionary) -> bool:
	if not dialog.visible:
		return _fail("Controller A did not open the warned End Turn confirmation.")
	if dialog.title != "Confirm End Turn?" or dialog.get_ok_button().text != "End Turn" or dialog.get_cancel_button().text != "Keep Waiting":
		return _fail("End Turn confirmation actions are unclear: title=%s confirm=%s cancel=%s." % [dialog.title, dialog.get_ok_button().text, dialog.get_cancel_button().text])
	for key in ["surface_confirmation", "surface_spend_check"]:
		var required_copy := String(live_snapshot.get(key, "")).strip_edges()
		if required_copy != "" and required_copy not in dialog.dialog_text:
			return _fail("End Turn confirmation omitted live %s copy: expected=%s dialog=%s." % [key, required_copy, dialog.dialog_text])
	if bool(live_snapshot.get("risk_unconsumed", false)):
		var risk_summary := String(live_snapshot.get("risk_summary", "")).strip_edges()
		var risk_copy := "Next-day risk: %s." % risk_summary.trim_suffix(".") if risk_summary != "" else ""
		if risk_copy != "" and risk_copy not in dialog.dialog_text:
			return _fail("End Turn confirmation omitted the compact live unconsumed risk summary: expected=%s dialog=%s." % [risk_copy, dialog.dialog_text])
	var pending_snapshot: Dictionary = shell.call("validation_end_turn_confirmation_snapshot")
	if not bool(pending_snapshot.get("pending", false)) or not bool(pending_snapshot.get("dialog_visible", false)):
		return _fail("End Turn confirmation did not retain a pending request identity: %s." % pending_snapshot)
	var dialog_viewport := dialog.get_cancel_button().get_viewport()
	var dialog_focus_owner := dialog_viewport.gui_get_focus_owner() if dialog_viewport != null else null
	if dialog_focus_owner != dialog.get_cancel_button():
		return _fail("End Turn confirmation did not focus the safer Keep Waiting action in its native dialog viewport: %s." % dialog_focus_owner)
	return true

func _check_narrow_town_keyboard_entry() -> bool:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var town := _first_player_town(session)
	if town.is_empty():
		return _fail("Narrow town fixture has no player-owned town.")
	_seed_town_management_navigation_fixture(session, town)
	_move_active_hero_to_town(session, town)
	session = SessionState.set_active_session(session)
	var frame := Control.new()
	frame.name = "NarrowTownFrame"
	frame.size = Vector2(1024.0, 600.0)
	add_child(frame)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	frame.add_child(shell)
	await _settle()
	if _focus_name() != "TownOrdersToggle":
		return _fail("Narrow town entry focus expected TownOrdersToggle, got %s." % _focus_name())
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()
	if not shell.get_node("%SidebarShell").visible or shell.get_node("%StageColumn").visible:
		return _fail("Controller-confirmed Town Orders did not open narrow management.")
	var build_actions: Control = shell.get_node("%BuildActions")
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null or not build_actions.is_ancestor_of(focus_owner) or not (focus_owner is BaseButton) or focus_owner.disabled:
		return _fail("Narrow town management did not move focus into a ready construction order: %s." % _focus_name())
	if not await _check_town_management_tab_navigation(shell, session, "narrow"):
		return false
	await _press_joypad_button(JOY_BUTTON_B)
	await _settle()
	if shell.get_node("%SidebarShell").visible or not shell.get_node("%StageColumn").visible:
		return _fail("Controller B did not return from narrow town orders to the scenic town view.")
	if _focus_name() != "TownOrdersToggle":
		return _fail("Narrow town controller back did not restore TownOrdersToggle focus: %s." % _focus_name())
	frame.queue_free()
	await get_tree().process_frame
	return true

func _check_town_management_tab_navigation(shell: Node, session, layout: String) -> bool:
	if not shell.has_method("validation_reset_town_management_tab_navigation_state") \
			or not shell.has_method("validation_town_management_tab_navigation_snapshot"):
		return _fail("Town %s management navigation validation API is missing." % layout)
	var management_tabs: TabContainer = shell.get_node_or_null("%ManagementTabs")
	if management_tabs == null:
		return _fail("Town %s management navigation is missing ManagementTabs." % layout)
	var tab_bar: TabBar = management_tabs.get_tab_bar()
	if tab_bar == null:
		return _fail("Town %s management navigation is missing its native TabBar." % layout)
	var authority_before := _town_management_authority_snapshot(session)
	var reset: Dictionary = shell.call("validation_reset_town_management_tab_navigation_state")
	var expected_titles := ["Build", "Muster", "Spells", "Trade", "Log"]
	if int(reset.get("active_tab", -1)) != 0 \
			or int(reset.get("tab_count", -1)) != expected_titles.size() \
			or int(reset.get("tab_bar_focus_mode", Control.FOCUS_NONE)) != Control.FOCUS_ALL:
		return _fail("Town %s management navigation did not expose five focusable native tabs: %s." % [layout, reset])
	var raw_titles: Array = reset.get("tab_titles", []) if reset.get("tab_titles", []) is Array else []
	if raw_titles.size() != expected_titles.size():
		return _fail("Town %s management navigation exposed the wrong tab-title count: %s." % [layout, raw_titles])
	for index in range(expected_titles.size()):
		if not String(raw_titles[index]).begins_with(String(expected_titles[index])):
			return _fail("Town %s management tab %d lost its %s title: %s." % [layout, index, expected_titles[index], raw_titles[index]])

	await _press_joypad_button(JOY_BUTTON_LEFT_SHOULDER)
	if get_viewport().gui_get_focus_owner() != tab_bar:
		return _fail("Town %s controller could not reach the native TabBar from the first Build command: %s." % [layout, _focus_name()])
	await _press_joypad_button(JOY_BUTTON_DPAD_LEFT)
	var boundary_start: Dictionary = shell.call("validation_town_management_tab_navigation_snapshot")
	if int(boundary_start.get("active_tab", -1)) != 0 \
			or int(boundary_start.get("change_count", -1)) != 0 \
			or get_viewport().gui_get_focus_owner() != tab_bar:
		return _fail("Town %s native TabBar wrapped left from Build instead of holding the boundary: %s." % [layout, boundary_start])

	for expected_tab in range(1, expected_titles.size()):
		if expected_tab == 2:
			await _press_key(KEY_RIGHT)
		else:
			await _press_joypad_button(JOY_BUTTON_DPAD_RIGHT)
		if not _assert_town_management_tab_handoff(shell, expected_tab, expected_tab, layout):
			return false
		var forward_authority := _town_management_authority_snapshot(session)
		if forward_authority != authority_before:
			return _fail("Town %s forward management-tab traversal mutated authority at tab %d: %s." % [layout, expected_tab, _first_town_management_difference(authority_before, forward_authority)])
		await _press_joypad_button(JOY_BUTTON_LEFT_SHOULDER)
		if get_viewport().gui_get_focus_owner() != tab_bar:
			return _fail("Town %s controller could not return from tab %d's first command to the native TabBar: %s." % [layout, expected_tab, _focus_name()])

	await _press_joypad_button(JOY_BUTTON_DPAD_RIGHT)
	var boundary_end: Dictionary = shell.call("validation_town_management_tab_navigation_snapshot")
	if int(boundary_end.get("active_tab", -1)) != 4 \
			or int(boundary_end.get("change_count", -1)) != 4 \
			or get_viewport().gui_get_focus_owner() != tab_bar:
		return _fail("Town %s native TabBar wrapped right from Log instead of holding the boundary: %s." % [layout, boundary_end])

	for expected_tab in [3, 2, 1, 0]:
		if expected_tab == 3:
			await _press_key(KEY_LEFT)
		else:
			await _press_joypad_button(JOY_BUTTON_DPAD_LEFT)
		var expected_change_count: int = 8 - int(expected_tab)
		if not _assert_town_management_tab_handoff(shell, expected_tab, expected_change_count, layout):
			return false
		var reverse_authority := _town_management_authority_snapshot(session)
		if reverse_authority != authority_before:
			return _fail("Town %s reverse management-tab traversal mutated authority at tab %d: %s." % [layout, expected_tab, _first_town_management_difference(authority_before, reverse_authority)])
		await _press_joypad_button(JOY_BUTTON_LEFT_SHOULDER)
		if get_viewport().gui_get_focus_owner() != tab_bar:
			return _fail("Town %s reverse traversal could not return to the native TabBar from tab %d." % [layout, expected_tab])

	await _press_key(KEY_LEFT)
	var reverse_boundary: Dictionary = shell.call("validation_town_management_tab_navigation_snapshot")
	if int(reverse_boundary.get("active_tab", -1)) != 0 \
			or int(reverse_boundary.get("change_count", -1)) != 8 \
			or get_viewport().gui_get_focus_owner() != tab_bar:
		return _fail("Town %s keyboard Left wrapped from Build instead of holding the native boundary: %s." % [layout, reverse_boundary])

	await _click_town_management_tab(tab_bar, 3)
	if not _assert_town_management_tab_handoff(shell, 3, 9, layout):
		return false
	await _click_town_management_tab(tab_bar, 0)
	if not _assert_town_management_tab_handoff(shell, 0, 10, layout):
		return false
	if _town_management_authority_snapshot(session) != authority_before:
		return _fail("Town %s mouse management-tab controls mutated session, town, save, settings, profile, or route authority." % layout)
	if not await _town_management_core_controls_reachable(shell):
		return _fail("Town %s management traversal lost Save, Settings, Return, or Menu focus authority." % layout)
	var final_snapshot: Dictionary = shell.call("validation_town_management_tab_navigation_snapshot")
	var final_first: Dictionary = final_snapshot.get("first_enabled_command", {}) if final_snapshot.get("first_enabled_command", {}) is Dictionary else {}
	var final_focus := shell.find_child(String(final_first.get("node_name", "")), true, false) as Control
	if final_focus == null:
		return _fail("Town %s management traversal could not restore its first Build command for downstream controls: %s." % [layout, final_snapshot])
	final_focus.grab_focus()
	await get_tree().process_frame
	return true

func _assert_town_management_tab_handoff(shell: Node, expected_tab: int, expected_change_count: int, layout: String) -> bool:
	var snapshot: Dictionary = shell.call("validation_town_management_tab_navigation_snapshot")
	var first: Dictionary = snapshot.get("first_enabled_command", {}) if snapshot.get("first_enabled_command", {}) is Dictionary else {}
	var last: Dictionary = snapshot.get("last_change_result", {}) if snapshot.get("last_change_result", {}) is Dictionary else {}
	var focus_owner := get_viewport().gui_get_focus_owner()
	if int(snapshot.get("active_tab", -1)) != expected_tab \
			or int(snapshot.get("change_count", -1)) != expected_change_count \
			or int(snapshot.get("focus_handoff_count", -1)) != expected_change_count \
			or first.is_empty() \
			or bool(first.get("disabled", true)) \
			or int(first.get("focus_mode", Control.FOCUS_NONE)) == Control.FOCUS_NONE \
			or focus_owner == null \
			or String(focus_owner.name) != String(first.get("node_name", "")) \
			or not bool(snapshot.get("focus_owner_in_active_tab", false)) \
			or int(last.get("to_tab", -1)) != expected_tab \
			or not bool(last.get("focus_handoff", false)) \
			or not bool(last.get("focus_owner_in_active_tab", false)):
		return _fail("Town %s tab %d did not hand focus exactly once to its first enabled command: %s." % [layout, expected_tab, snapshot])
	return true

func _town_management_core_controls_reachable(shell: Node) -> bool:
	var required := {
		"Save": shell.get_node_or_null("%Save"),
		"Settings": shell.get_node_or_null("%Settings"),
		"Leave": shell.get_node_or_null("%Leave"),
		"Menu": shell.get_node_or_null("%Menu"),
	}
	var reached := {}
	for _step in range(96):
		var owner := get_viewport().gui_get_focus_owner()
		for key in required:
			if owner == required[key]:
				reached[key] = true
		if reached.size() == required.size():
			return true
		await _press_joypad_button(JOY_BUTTON_RIGHT_SHOULDER)
	return false

func _click_town_management_tab(tab_bar: TabBar, tab_index: int) -> void:
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

func _town_management_authority_snapshot(session) -> Dictionary:
	var settings := SettingsService.ensure_settings().duplicate(true)
	var campaign_profile := CampaignProgression.ensure_profile().duplicate(true)
	var files := {}
	for path in [
		"user://saves/autosave.json",
		"user://saves/manual_slot_1.json",
		"user://saves/manual_slot_2.json",
		"user://saves/manual_slot_3.json",
		"user://saves/campaign_progression.json",
		SettingsService.SETTINGS_FILE,
		"%s.candidate" % SettingsService.SETTINGS_FILE,
		"%s.backup" % SettingsService.SETTINGS_FILE,
	]:
		files[path] = _controller_route_file_state(path)
	return {
		"session": session.to_dict(),
		"active_session_same": SessionState.active_session == session,
		"selected_manual_slot": SaveService.get_selected_manual_slot(),
		"save_files": files,
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
		"settings": settings,
		"campaign_profile": campaign_profile,
		"battle_entry": AppRouter.validation_battle_entry_snapshot(),
		"outcome": AppRouter.validation_scenario_outcome_route_snapshot(),
		"return_to_menu": AppRouter.validation_active_play_return_snapshot(),
		"safe_quit": AppRouter.validation_safe_quit_snapshot(),
	}

func _seed_town_management_navigation_fixture(session, town: Dictionary) -> void:
	var built: Array = town.get("built_buildings", []).duplicate()
	for building_id in ["building_lantern_archive", "building_market_square"]:
		if building_id not in built:
			built.append(building_id)
	town["built_buildings"] = built
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("placement_id", "")) == String(town.get("placement_id", "")):
			towns[index] = town
	session.overworld["towns"] = towns

func _first_town_management_difference(expected: Variant, actual: Variant, path: String = "$") -> Dictionary:
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
			var nested: Dictionary = _first_town_management_difference(expected_dictionary.get(key), actual_dictionary.get(key), "%s.%s" % [path, key])
			if not nested.is_empty():
				return nested
		return {}
	if expected is Array:
		var expected_array: Array = expected
		var actual_array: Array = actual
		if expected_array.size() != actual_array.size():
			return {"path": path, "expected_size": expected_array.size(), "actual_size": actual_array.size()}
		for index in range(expected_array.size()):
			var nested: Dictionary = _first_town_management_difference(expected_array[index], actual_array[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
		return {}
	if expected != actual:
		return {"path": path, "expected": expected, "actual": actual}
	return {}

func _check_battle_keyboard_defend() -> bool:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		return _fail("Battle fixture has no encounter.")
	session.battle = BattleRules.create_battle_payload(session, encounter)
	var guard := 0
	while String(BattleRules.get_active_stack(session.battle).get("side", "")) != "player" and guard < 8:
		BattleRules.advance_turn(session.battle)
		guard += 1
	if String(BattleRules.get_active_stack(session.battle).get("side", "")) != "player":
		return _fail("Battle fixture could not advance to a player command turn.")
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	if not _assert_accessible_surface(shell, "battle", 2):
		return false

	var snapshot: Dictionary = shell.call("validation_snapshot")
	var forecast: Dictionary = snapshot.get("intent_forecast", {}) if snapshot.get("intent_forecast", {}) is Dictionary else {}
	var action_id := String(forecast.get("action_id", ""))
	var battle_entry_focus := get_viewport().gui_get_focus_owner()
	if not _battle_focus_matches_action(battle_entry_focus, action_id):
		return _fail("Battle entry focus did not match suggested order %s: got=%s metadata=%s." % [
			action_id,
			_focus_name(),
			String(battle_entry_focus.get_meta("battle_action_id", "")) if battle_entry_focus != null else "",
		])
	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	var battle_dpad_focus := get_viewport().gui_get_focus_owner()
	if battle_dpad_focus == null or battle_dpad_focus == battle_entry_focus or not shell.is_ancestor_of(battle_dpad_focus):
		return _fail("Battle D-pad did not advance the active command focus: before=%s after=%s." % [battle_entry_focus, battle_dpad_focus])
	await _press_joypad_button(JOY_BUTTON_DPAD_UP)
	if get_viewport().gui_get_focus_owner() != battle_entry_focus:
		return _fail("Battle D-pad did not return to the suggested order: expected=%s got=%s." % [battle_entry_focus, get_viewport().gui_get_focus_owner()])
	if not await _check_battle_info_tab_controller_navigation(shell, session, battle_entry_focus):
		return false
	await _capture_if_requested("battle_suggested_order_focus")
	var previous_target: Button = shell.get_node("%PrevTarget")
	if not previous_target.disabled:
		previous_target.grab_focus()
		await _press_joypad_button(JOY_BUTTON_A)
		await _settle()
		if _focus_name() != "PrevTarget":
			return _fail("Battle target cycling did not preserve focus on the target command: %s." % _focus_name())

	var quick_resolve: Button = shell.get_node("%QuickResolve")
	if quick_resolve.disabled:
		return _fail("Battle Quick Resolve command is disabled during an active battle.")
	shell.call("validation_reset_quick_resolve_confirmation_state")
	for cancel_method in ["accept", "back", "escape"]:
		if not await _check_quick_resolve_safe_cancel(shell, session, String(cancel_method)):
			return false
	if not await _check_battle_withdrawal_controller_cancel(shell, session, "retreat", "Retreat"):
		return false
	if not await _check_battle_withdrawal_controller_cancel(shell, session, "surrender", "Surrender"):
		return false

	var defend: Button = shell.get_node("%Defend")
	if defend.disabled:
		return _fail("Battle Defend command is disabled on a player turn.")
	var battle_before := JSON.stringify(session.battle)
	var recent_before := int(session.battle.get("recent_events", []).size())
	var tab_before_action: Dictionary = shell.call("validation_battle_info_tab_navigation_snapshot")
	if int(tab_before_action.get("active_tab", -1)) != 3:
		return _fail("Battle info-tab traversal did not retain Timing for the real action refresh: %s." % tab_before_action)
	defend.grab_focus()
	await get_tree().process_frame
	await _capture_if_requested("battle_defend_focus")
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()
	if JSON.stringify(session.battle) == battle_before or int(session.battle.get("recent_events", []).size()) <= recent_before:
		return _fail("Controller-confirmed Battle Defend did not mutate battle state and advance the event stream.")
	var post_owner := get_viewport().gui_get_focus_owner()
	if post_owner == null or not shell.is_ancestor_of(post_owner) or (post_owner is BaseButton and post_owner.disabled):
		return _fail("Battle action refresh did not restore focus to a legal command: %s." % _focus_name())
	var post_snapshot: Dictionary = shell.call("validation_snapshot")
	var post_tab_snapshot: Dictionary = shell.call("validation_battle_info_tab_navigation_snapshot")
	if int(post_tab_snapshot.get("active_tab", -1)) != 3 \
			or int(post_tab_snapshot.get("change_count", -1)) != int(tab_before_action.get("change_count", -2)) \
			or String(post_tab_snapshot.get("focus_owner", "")) != String(post_owner.name):
		return _fail("Battle action refresh did not retain the selected Timing tab and legal refreshed focus: before=%s after=%s." % [tab_before_action, post_tab_snapshot])
	var post_forecast: Dictionary = post_snapshot.get("intent_forecast", {}) if post_snapshot.get("intent_forecast", {}) is Dictionary else {}
	var post_action_id := String(post_forecast.get("action_id", ""))
	if not _battle_focus_matches_action(post_owner, post_action_id):
		return _fail("Battle post-action focus did not follow the next suggested order: action=%s got=%s metadata=%s." % [
			post_action_id,
			post_owner.name,
			String(post_owner.get_meta("battle_action_id", "")),
		])
	if not await _check_quick_resolve_confirm_parity(shell, session):
		return false
	shell.queue_free()
	await get_tree().process_frame
	return true

func _check_battle_info_tab_controller_navigation(shell: Node, session, entry_focus: Control) -> bool:
	if not shell.has_method("validation_reset_battle_info_tab_navigation_state") \
			or not shell.has_method("validation_battle_info_tab_navigation_snapshot"):
		return _fail("Battle info-tab navigation validation API is missing.")
	var battle_tabs: TabContainer = shell.get_node_or_null("%BattleTabs")
	if battle_tabs == null:
		return _fail("Battle info-tab navigation is missing BattleTabs.")
	var tab_bar: TabBar = battle_tabs.get_tab_bar()
	if tab_bar == null:
		return _fail("Battle info-tab navigation is missing its native TabBar.")
	var details_button: Button = shell.get_node_or_null("%TacticalDetails")
	var sidebar: Control = shell.get_node_or_null("%SidebarShell")
	if details_button == null or sidebar == null or not details_button.is_visible_in_tree() or sidebar.is_visible_in_tree():
		return _fail("Battle tactical disclosure did not begin in the wide field-first state.")
	var authority_before: Dictionary = _battle_info_tab_authority_snapshot(session)
	details_button.grab_focus()
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()
	if not sidebar.is_visible_in_tree() or get_viewport().gui_get_focus_owner() != details_button:
		return _fail("Battle controller confirm did not disclose the tactical rail and retain control focus.")
	var reset: Dictionary = shell.call("validation_reset_battle_info_tab_navigation_state")
	var expected_titles := ["Order", "Focus", "Spell", "Timing"]
	var raw_titles: Array = reset.get("tab_titles", []) if reset.get("tab_titles", []) is Array else []
	var cycle_names: Array = reset.get("focus_cycle_names", []) if reset.get("focus_cycle_names", []) is Array else []
	var tab_bar_name := String(reset.get("tab_bar_name", ""))
	if int(reset.get("active_tab", -1)) != 0 \
			or int(reset.get("tab_count", -1)) != expected_titles.size() \
			or int(reset.get("tab_bar_focus_mode", Control.FOCUS_NONE)) != Control.FOCUS_ALL \
			or String(reset.get("tab_bar_boundary_policy", "")) != "retain" \
			or int(reset.get("tab_bar_occurrences", 0)) != 1 \
			or int(reset.get("focus_cycle_count", 0)) != cycle_names.size() \
			or cycle_names.count(tab_bar_name) != 1:
		return _fail("Battle info tabs did not expose one focusable native TabBar in the authoritative cycle: %s." % reset)
	if raw_titles.size() != expected_titles.size():
		return _fail("Battle info-tab navigation exposed the wrong title count: %s." % raw_titles)
	for index in range(expected_titles.size()):
		if not String(raw_titles[index]).begins_with(String(expected_titles[index])):
			return _fail("Battle info tab %d lost its %s title: %s." % [index, expected_titles[index], raw_titles[index]])

	var traversal_count := 0
	while get_viewport().gui_get_focus_owner() != tab_bar and traversal_count <= cycle_names.size():
		await _press_joypad_button(JOY_BUTTON_RIGHT_SHOULDER)
		traversal_count += 1
	if get_viewport().gui_get_focus_owner() != tab_bar:
		return _fail("Battle controller shoulder traversal could not reach the native info TabBar: %s." % shell.call("validation_battle_info_tab_navigation_snapshot"))
	await _press_joypad_button(JOY_BUTTON_DPAD_LEFT)
	var start_boundary: Dictionary = shell.call("validation_battle_info_tab_navigation_snapshot")
	if int(start_boundary.get("active_tab", -1)) != 0 \
			or int(start_boundary.get("change_count", -1)) != 0 \
			or int(start_boundary.get("boundary_retain_count", -1)) != 1 \
			or get_viewport().gui_get_focus_owner() != tab_bar:
		return _fail("Battle info TabBar wrapped left from Order instead of retaining its boundary: %s." % start_boundary)

	for expected_tab in range(1, expected_titles.size()):
		if expected_tab == 2:
			await _press_key(KEY_RIGHT)
		else:
			await _press_joypad_button(JOY_BUTTON_DPAD_RIGHT)
		if not _assert_battle_info_tab_state(shell, expected_tab, expected_tab, expected_tab, tab_bar):
			return false
		if expected_tab in [1, 2] and not _battle_info_tab_footer_contained(shell):
			return _fail("Battle forward info-tab traversal exposed a Focus/Spell body that overflowed the shell at tab %d." % expected_tab)
		var forward_authority: Dictionary = _battle_info_tab_authority_snapshot(session)
		if forward_authority != authority_before:
			return _fail("Battle forward info-tab traversal mutated battle, session, save, settings, or route authority at tab %d: %s." % [expected_tab, _first_town_management_difference(authority_before, forward_authority)])

	await _press_joypad_button(JOY_BUTTON_DPAD_RIGHT)
	var end_boundary: Dictionary = shell.call("validation_battle_info_tab_navigation_snapshot")
	if int(end_boundary.get("active_tab", -1)) != 3 \
			or int(end_boundary.get("change_count", -1)) != 3 \
			or int(end_boundary.get("boundary_retain_count", -1)) != 2 \
			or get_viewport().gui_get_focus_owner() != tab_bar:
		return _fail("Battle info TabBar wrapped right from Timing instead of retaining its boundary: %s." % end_boundary)

	for expected_tab in [2, 1, 0]:
		if expected_tab == 1:
			await _press_key(KEY_LEFT)
		else:
			await _press_joypad_button(JOY_BUTTON_DPAD_LEFT)
		var expected_count: int = 6 - int(expected_tab)
		if not _assert_battle_info_tab_state(shell, expected_tab, expected_count, expected_count, tab_bar):
			return false
		if expected_tab in [1, 2] and not _battle_info_tab_footer_contained(shell):
			return _fail("Battle reverse info-tab traversal exposed a Focus/Spell body that overflowed the shell at tab %d." % expected_tab)
		var reverse_authority: Dictionary = _battle_info_tab_authority_snapshot(session)
		if reverse_authority != authority_before:
			return _fail("Battle reverse info-tab traversal mutated battle, session, save, settings, or route authority at tab %d: %s." % [expected_tab, _first_town_management_difference(authority_before, reverse_authority)])

	await _press_key(KEY_LEFT)
	var reverse_boundary: Dictionary = shell.call("validation_battle_info_tab_navigation_snapshot")
	if int(reverse_boundary.get("active_tab", -1)) != 0 \
			or int(reverse_boundary.get("change_count", -1)) != 6 \
			or int(reverse_boundary.get("boundary_retain_count", -1)) != 3 \
			or get_viewport().gui_get_focus_owner() != tab_bar:
		return _fail("Battle keyboard Left wrapped from Order instead of retaining its boundary: %s." % reverse_boundary)

	await _click_battle_info_tab(tab_bar, 1)
	if not _assert_battle_info_tab_state(shell, 1, 7, 7, tab_bar):
		return false
	if not _battle_info_tab_footer_contained(shell):
		return _fail("Battle mouse info-tab selection exposed a Focus body that overflowed the shell.")
	if _battle_info_tab_authority_snapshot(session) != authority_before:
		return _fail("Battle mouse info-tab selection mutated battle, session, save, settings, or route authority.")
	for expected_tab in [2, 3]:
		await _press_joypad_button(JOY_BUTTON_DPAD_RIGHT)
		var expected_count: int = 7 + int(expected_tab) - 1
		if not _assert_battle_info_tab_state(shell, int(expected_tab), expected_count, expected_count, tab_bar):
			return false

	traversal_count = 0
	while get_viewport().gui_get_focus_owner() != entry_focus and traversal_count <= cycle_names.size():
		await _press_joypad_button(JOY_BUTTON_RIGHT_SHOULDER)
		traversal_count += 1
	if get_viewport().gui_get_focus_owner() != entry_focus:
		return _fail("Battle info-tab traversal did not return to the original suggested command: expected=%s got=%s." % [entry_focus, get_viewport().gui_get_focus_owner()])
	var final_snapshot: Dictionary = shell.call("validation_battle_info_tab_navigation_snapshot")
	if int(final_snapshot.get("active_tab", -1)) != 3 \
		or int(final_snapshot.get("change_count", -1)) != 9 \
		or _battle_info_tab_authority_snapshot(session) != authority_before:
		return _fail("Battle info-tab navigation lost selected-tab or authority state when returning to commands: %s." % final_snapshot)
	details_button.grab_focus()
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()
	if sidebar.is_visible_in_tree() or details_button.text != "Tactical Details" \
		or _battle_info_tab_authority_snapshot(session) != authority_before:
		return _fail("Battle controller confirm did not restore the field-first state without authority drift.")
	return true

func _battle_info_tab_footer_contained(shell: Node) -> bool:
	var shell_control: Control = shell as Control
	var footer: Control = shell.get_node_or_null("%Footer")
	return shell_control != null and footer != null and shell_control.get_global_rect().encloses(footer.get_global_rect())

func _assert_battle_info_tab_state(shell: Node, expected_tab: int, expected_change_count: int, expected_retention_count: int, tab_bar: TabBar) -> bool:
	var snapshot: Dictionary = shell.call("validation_battle_info_tab_navigation_snapshot")
	var last: Dictionary = snapshot.get("last_change_result", {}) if snapshot.get("last_change_result", {}) is Dictionary else {}
	if int(snapshot.get("active_tab", -1)) != expected_tab \
			or int(snapshot.get("change_sequence", -1)) != expected_change_count \
			or int(snapshot.get("change_count", -1)) != expected_change_count \
			or int(snapshot.get("focus_retention_count", -1)) != expected_retention_count \
			or not bool(snapshot.get("tab_bar_has_focus", false)) \
			or get_viewport().gui_get_focus_owner() != tab_bar \
			or int(last.get("to_tab", -1)) != expected_tab \
			or not bool(last.get("focus_retained", false)) \
			or int(last.get("sequence", -1)) != expected_change_count:
		return _fail("Battle info tab %d did not retain native focus with exact sequencing: %s." % [expected_tab, snapshot])
	return true

func _click_battle_info_tab(tab_bar: TabBar, tab_index: int) -> void:
	await _click_town_management_tab(tab_bar, tab_index)

func _battle_info_tab_authority_snapshot(session) -> Dictionary:
	return _town_management_authority_snapshot(session)

func _check_town_return_to_field_controller() -> bool:
	_detach_for_scene_transition()
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var town := _first_player_town(session)
	if town.is_empty():
		return _fail("Town return controller fixture has no player-owned town.")
	_move_active_hero_to_town(session, town)
	var visit_result: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	if not bool(visit_result.get("ok", false)):
		return _fail("Town return controller fixture could not establish its active visit: %s." % visit_result)
	session.game_state = "town"
	session = SessionState.set_active_session(session)
	var session_identity = session
	var day_before := int(session.day)
	var status_before := String(session.scenario_status)
	var movement_before := _controller_route_movement_snapshot(session)
	var autosave_before := _controller_route_file_state("user://saves/autosave.json")
	if get_tree().change_scene_to_file("res://scenes/town/TownShell.tscn") != OK:
		return _fail("Town return controller fixture could not enter TownShell.")
	for _frame in range(8):
		await get_tree().process_frame
	var town_shell := get_tree().current_scene
	if town_shell == null or String(town_shell.scene_file_path) != "res://scenes/town/TownShell.tscn":
		return _fail("Town return controller fixture did not reach TownShell.")
	var return_to_field: Button = town_shell.get_node_or_null("%Leave")
	if return_to_field == null or return_to_field.text != "Return to Field":
		return _fail("Town controller route did not expose the exact Return to Field command.")
	return_to_field.grab_focus()
	await get_tree().process_frame
	await _press_joypad_button(JOY_BUTTON_A)
	var overworld_shell = null
	for _frame in range(180):
		await get_tree().process_frame
		var current = get_tree().current_scene
		if current != null and String(current.scene_file_path) == "res://scenes/overworld/OverworldShell.tscn":
			overworld_shell = current
			break
	if overworld_shell == null:
		return _fail("Controller A on Return to Field did not reach OverworldShell.")
	var active_session = SessionState.ensure_active_session()
	if active_session != session_identity \
			or int(active_session.day) != day_before \
			or String(active_session.scenario_status) != status_before \
			or _controller_route_movement_snapshot(active_session) != movement_before \
			or _controller_route_file_state("user://saves/autosave.json") != autosave_before:
		return _fail("Controller Return to Field changed session identity, day, status, movement, or autosave bytes.")
	var end_turn: Button = overworld_shell.get_node_or_null("%EndTurn")
	if end_turn == null:
		return _fail("Returned overworld is missing EndTurn.")
	var reached_end_turn := get_viewport().gui_get_focus_owner() == end_turn
	for _step in range(24):
		if reached_end_turn:
			break
		await _press_joypad_button(JOY_BUTTON_RIGHT_SHOULDER)
		reached_end_turn = get_viewport().gui_get_focus_owner() == end_turn
	if not reached_end_turn:
		return _fail("Controller could not reach the separate overworld EndTurn command after Return to Field: %s." % _focus_name())
	return true

func _detach_for_scene_transition() -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene != self:
		return
	var parent := get_parent()
	if parent != null:
		parent.remove_child(self)
	tree.root.add_child(self)
	var anchor := Node.new()
	anchor.name = "ActivePlayKeyboardFocusSceneAnchor"
	tree.root.add_child(anchor)
	tree.current_scene = anchor

func _controller_route_movement_snapshot(session) -> Dictionary:
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	var movement: Dictionary = hero.get("movement", {}) if hero.get("movement", {}) is Dictionary else {}
	return {
		"current": int(movement.get("current", session.overworld.get("movement", {}).get("current", 0))),
		"max": int(movement.get("max", session.overworld.get("movement", {}).get("max", 0))),
	}

func _controller_route_file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}


func _check_quick_resolve_safe_cancel(shell: Node, session, cancel_method: String) -> bool:
	var quick_resolve: Button = shell.get_node("%QuickResolve")
	var dialog: ConfirmationDialog = shell.get_node("QuickResolveConfirmationDialog")
	var authority_before := _quick_resolve_authority_snapshot(session)
	quick_resolve.grab_focus()
	await get_tree().process_frame
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()
	var opened: Dictionary = shell.call("validation_quick_resolve_confirmation_snapshot")
	var cancel_button := dialog.get_cancel_button()
	var dialog_viewport := cancel_button.get_viewport()
	var dialog_focus_owner := dialog_viewport.gui_get_focus_owner() if dialog_viewport != null else null
	var dialog_position: Vector2i = opened.get("dialog_position", Vector2i(-1, -1))
	var dialog_size: Vector2i = opened.get("dialog_size", Vector2i.ZERO)
	if not bool(opened.get("pending", false)) \
		or not bool(opened.get("dialog_visible", false)) \
		or String(opened.get("cancel_text", "")) != "Keep Fighting" \
		or String(opened.get("dialog_focus_owner", "")) == "" \
		or dialog_focus_owner != cancel_button \
		or String(opened.get("return_focus_name", "")) != "QuickResolve" \
		or dialog_position.x < 0 or dialog_position.y < 0 \
		or dialog_size.x <= 0 or dialog_size.y <= 0:
		return _fail("Quick Resolve did not open a bounded native confirmation with Keep Fighting focused: %s." % opened)
	var confirmation_copy := String(opened.get("text", "")).to_lower()
	for required_copy in ["permanent casualties", "mana", "outcome", "objective consequences"]:
		if required_copy not in confirmation_copy:
			return _fail("Quick Resolve confirmation omitted required consequence copy '%s': %s." % [required_copy, opened.get("text", "")])
	match cancel_method:
		"accept":
			await _press_joypad_button(JOY_BUTTON_A)
		"back":
			await _press_joypad_button(JOY_BUTTON_B)
		_:
			await _press_key(KEY_ESCAPE)
	await _settle()
	var canceled: Dictionary = shell.call("validation_quick_resolve_confirmation_snapshot")
	if bool(canceled.get("pending", true)) \
		or bool(canceled.get("dialog_visible", true)) \
		or int(canceled.get("perform_count", 0)) != 0 \
		or int(canceled.get("confirm_count", 0)) != 0 \
		or _quick_resolve_authority_snapshot(session) != authority_before \
		or get_viewport().gui_get_focus_owner() != quick_resolve:
		return _fail("Quick Resolve %s cancel changed authority or failed to restore the exact origin: snapshot=%s focus=%s authority_equal=%s." % [
			cancel_method,
			canceled,
			_focus_name(),
			_quick_resolve_authority_snapshot(session) == authority_before,
		])
	return true


func _check_battle_confirmation_exclusive_parent_input() -> bool:
	var original_window_size := get_window().size
	var cases := [
		{"id": "quick_resolve_1280", "action_id": "quick_resolve", "button_name": "QuickResolve", "dialog_name": "QuickResolveConfirmationDialog", "width": 1280, "cancel_input": "joypad_b", "confirm_input": "joypad_a"},
		{"id": "quick_resolve_1920", "action_id": "quick_resolve", "button_name": "QuickResolve", "dialog_name": "QuickResolveConfirmationDialog", "width": 1920, "cancel_input": "mouse", "confirm_input": "mouse"},
		{"id": "retreat_1280", "action_id": "retreat", "button_name": "Retreat", "dialog_name": "WithdrawalConfirmationDialog", "width": 1280, "cancel_input": "escape", "confirm_input": "enter"},
		{"id": "retreat_1920", "action_id": "retreat", "button_name": "Retreat", "dialog_name": "WithdrawalConfirmationDialog", "width": 1920, "cancel_input": "joypad_b", "confirm_input": "mouse"},
		{"id": "surrender_1280", "action_id": "surrender", "button_name": "Surrender", "dialog_name": "WithdrawalConfirmationDialog", "width": 1280, "cancel_input": "escape", "confirm_input": "joypad_a"},
		{"id": "surrender_1920", "action_id": "surrender", "button_name": "Surrender", "dialog_name": "WithdrawalConfirmationDialog", "width": 1920, "cancel_input": "mouse", "confirm_input": "enter"},
	]
	for case_value in cases:
		if not await _exercise_battle_confirmation_exclusive_case(case_value):
			get_window().size = original_window_size
			return false
	get_window().size = original_window_size
	await _settle()
	return true


func _exercise_battle_confirmation_exclusive_case(case_data: Dictionary) -> bool:
	var case_id := String(case_data.get("id", "battle_confirmation"))
	var action_id := String(case_data.get("action_id", ""))
	var width := int(case_data.get("width", 1280))
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		return _fail("%s fixture has no encounter." % case_id)
	session.battle = BattleRules.create_battle_payload(session, encounter)
	session.battle["retreat_allowed"] = true
	session.battle["surrender_allowed"] = true
	var guard := 0
	while String(BattleRules.get_active_stack(session.battle).get("side", "")) != "player" and guard < 12:
		BattleRules.advance_turn(session.battle)
		guard += 1
	if String(BattleRules.get_active_stack(session.battle).get("side", "")) != "player":
		return _fail("%s could not reach a player command turn." % case_id)
	session = SessionState.set_active_session(session)
	get_window().size = Vector2i(width, 720)
	await _settle()
	var layout_host := Control.new()
	layout_host.name = "ExclusiveBattleConfirmationHost_%s" % case_id
	layout_host.size = Vector2(float(width), 720.0)
	add_child(layout_host)
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	layout_host.add_child(shell)
	var parent_probe := Button.new()
	parent_probe.name = "ExclusiveBattleParentProbe_%s" % case_id
	parent_probe.text = "Battle parent input probe"
	parent_probe.position = Vector2(16.0, 16.0)
	parent_probe.size = Vector2(210.0, 40.0)
	parent_probe.focus_mode = Control.FOCUS_NONE
	parent_probe.z_index = 100
	_exclusive_battle_parent_click_counts[case_id] = 0
	_exclusive_battle_dialog_signal_counts[case_id] = {"canceled": 0, "confirmed": 0}
	parent_probe.pressed.connect(_on_exclusive_battle_parent_probe_pressed.bind(case_id))
	layout_host.add_child(parent_probe)
	await _settle_battle_confirmation()
	var origin_button: Button = shell.get_node_or_null("%%%s" % String(case_data.get("button_name", "")))
	var dialog: ConfirmationDialog = shell.get_node_or_null(String(case_data.get("dialog_name", "")))
	if origin_button == null or dialog == null or origin_button.disabled:
		return _fail_exclusive_battle_case(layout_host, "%s is missing an actionable origin or confirmation dialog." % case_id)
	dialog.canceled.connect(_on_exclusive_battle_dialog_canceled.bind(case_id))
	dialog.confirmed.connect(_on_exclusive_battle_dialog_confirmed.bind(case_id))
	if action_id == "quick_resolve":
		shell.call("validation_reset_quick_resolve_confirmation_state")
		AppRouter.validation_reset_battle_resolution_checkpoint_state()
		AppRouter.validation_set_battle_resolution_checkpoint_routing_suppressed(true)
		AppRouter.validation_reset_scenario_outcome_route_state()
		AppRouter.validation_set_scenario_outcome_routing_suppressed(true)
	else:
		shell.call("validation_set_battle_resolution_routing_enabled", false)
	var fixture_checks := {
		"host_parent_exact": shell.get_parent() == layout_host,
		"host_width_exact": int(layout_host.size.x) == width,
		"host_height_exact": int(layout_host.size.y) == 720,
		"origin_root_viewport_exact": origin_button.get_viewport() == get_viewport(),
	}
	if not _checks_exact(fixture_checks):
		return _fail_exclusive_battle_case(layout_host, "%s exact-width Battle host failed: %s." % [case_id, JSON.stringify(fixture_checks)])
	origin_button.grab_focus()
	await get_tree().process_frame
	await _click_control(origin_button)
	await _settle_battle_confirmation()
	var opened := _battle_confirmation_transaction_snapshot(shell, action_id)
	var geometry := _exclusive_battle_parent_click_geometry(parent_probe, dialog)
	var opened_checks := {
		"exclusive_exact": dialog.exclusive,
		"pending_exact": bool(opened.get("pending", false)),
		"visible_exact": bool(opened.get("visible", false)),
		"safe_focus_exact": dialog.get_cancel_button().get_viewport().gui_get_focus_owner() == dialog.get_cancel_button(),
		"geometry_exact": bool(geometry.get("exact", false)),
	}
	if not _checks_exact(opened_checks):
		return _fail_exclusive_battle_case(layout_host, "%s did not open an exact exclusive native dialog: checks=%s geometry=%s snapshot=%s." % [case_id, JSON.stringify(opened_checks), JSON.stringify(geometry), JSON.stringify(opened)])
	var authority_before_block := _quick_resolve_authority_snapshot(session)
	var transaction_before_block := _battle_confirmation_transaction_snapshot(shell, action_id)
	var parent_count_before := int(_exclusive_battle_parent_click_counts.get(case_id, 0))
	await _click_control(parent_probe)
	await _settle_battle_confirmation()
	var blocked_checks := {
		"parent_count_exact": int(_exclusive_battle_parent_click_counts.get(case_id, -1)) == parent_count_before,
		"dialog_transaction_exact": _battle_confirmation_transaction_snapshot(shell, action_id) == transaction_before_block,
		"authority_exact": _quick_resolve_authority_snapshot(session) == authority_before_block,
		"dialog_focus_exact": dialog.get_cancel_button().get_viewport().gui_get_focus_owner() == dialog.get_cancel_button(),
	}
	if not _checks_exact(blocked_checks):
		return _fail_exclusive_battle_case(layout_host, "%s exclusive parent click escaped the first modal: checks=%s." % [case_id, JSON.stringify(blocked_checks)])
	if not await _send_battle_confirmation_cancel(dialog, String(case_data.get("cancel_input", ""))):
		_cleanup_exclusive_battle_case(layout_host)
		return false
	await _settle_battle_confirmation()
	var canceled := _battle_confirmation_transaction_snapshot(shell, action_id)
	var signal_counts: Dictionary = _exclusive_battle_dialog_signal_counts.get(case_id, {})
	var canceled_checks := {
		"hidden_exact": not bool(canceled.get("visible", true)),
		"pending_cleared_exact": not bool(canceled.get("pending", true)),
		"cancel_signal_once": int(signal_counts.get("canceled", 0)) == 1,
		"confirm_signal_zero": int(signal_counts.get("confirmed", 0)) == 0,
		"perform_zero": int(canceled.get("perform_count", 0)) == 0,
		"route_zero": int(canceled.get("route_count", 0)) == 0,
		"authority_exact": _quick_resolve_authority_snapshot(session) == authority_before_block,
		"origin_focus_exact": get_viewport().gui_get_focus_owner() == origin_button,
	}
	if not _checks_exact(canceled_checks):
		return _fail_exclusive_battle_case(layout_host, "%s forwarded/native cancel was not exact: checks=%s snapshot=%s." % [case_id, JSON.stringify(canceled_checks), JSON.stringify(canceled)])
	var positive_count_before := int(_exclusive_battle_parent_click_counts.get(case_id, 0))
	await _click_control(parent_probe)
	if int(_exclusive_battle_parent_click_counts.get(case_id, -1)) != positive_count_before + 1 \
			or _quick_resolve_authority_snapshot(session) != authority_before_block:
		return _fail_exclusive_battle_case(layout_host, "%s identical parent probe was not positively actionable after cancel." % case_id)
	origin_button.grab_focus()
	await _click_control(origin_button)
	await _settle_battle_confirmation()
	var reopened := _battle_confirmation_transaction_snapshot(shell, action_id)
	var authority_before_second_block := _quick_resolve_authority_snapshot(session)
	var second_count_before := int(_exclusive_battle_parent_click_counts.get(case_id, 0))
	await _click_control(parent_probe)
	await _settle_battle_confirmation()
	var second_block_checks := {
		"reopened_pending_exact": bool(reopened.get("pending", false)),
		"reopened_visible_exact": bool(reopened.get("visible", false)),
		"parent_count_exact": int(_exclusive_battle_parent_click_counts.get(case_id, -1)) == second_count_before,
		"dialog_transaction_exact": _battle_confirmation_transaction_snapshot(shell, action_id) == reopened,
		"authority_exact": _quick_resolve_authority_snapshot(session) == authority_before_second_block,
	}
	if not _checks_exact(second_block_checks):
		return _fail_exclusive_battle_case(layout_host, "%s second blocked parent click changed confirmation authority: checks=%s." % [case_id, JSON.stringify(second_block_checks)])
	var perform_before := int(reopened.get("perform_count", 0))
	var route_before := int(reopened.get("route_count", 0))
	session.battle[BattleRules.PRESENTATION_SPEED_KEY] = BattleRules.PRESENTATION_SPEED_INSTANT
	var direct_control := SessionStateStoreScript.SessionData.new()
	direct_control.from_dict(session.to_dict())
	var direct_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(direct_control) \
		if action_id == "quick_resolve" \
		else BattleRules.perform_player_action(direct_control, action_id)
	if not await _send_battle_confirmation_confirm(dialog, String(case_data.get("confirm_input", ""))):
		_cleanup_exclusive_battle_case(layout_host)
		return false
	for _frame in range(180):
		await get_tree().process_frame
		var probe := _battle_confirmation_transaction_snapshot(shell, action_id)
		if int(probe.get("perform_count", 0)) >= perform_before + 1:
			break
	var confirmed := _battle_confirmation_transaction_snapshot(shell, action_id)
	signal_counts = _exclusive_battle_dialog_signal_counts.get(case_id, {})
	var confirmation_result: Dictionary = confirmed.get("last_result", {}) if confirmed.get("last_result", {}) is Dictionary else {}
	var shell_action_result: Dictionary = confirmation_result.get("result", {}) if confirmation_result.get("result", {}) is Dictionary else {}
	var direct_route_exact := _battle_confirmation_direct_route_exact(shell, action_id, direct_control, confirmed)
	var confirmed_checks := {
		"hidden_exact": not bool(confirmed.get("visible", true)),
		"pending_cleared_exact": not bool(confirmed.get("pending", true)),
		"cancel_signal_unchanged": int(signal_counts.get("canceled", 0)) == 1,
		"confirm_signal_once": int(signal_counts.get("confirmed", 0)) == 1,
		"perform_once": int(confirmed.get("perform_count", 0)) == perform_before + 1,
		"route_once": int(confirmed.get("route_count", 0)) == route_before + 1,
		"action_exact": action_id == "quick_resolve" or String(confirmation_result.get("action_id", "")) == action_id,
		"result_exact": shell_action_result == direct_result,
		"gameplay_session_rng_exact": _battle_confirmation_gameplay_payload(session) == _battle_confirmation_gameplay_payload(direct_control),
		"terminal_state_exact": _battle_confirmation_terminal_state_exact(action_id, session, direct_control),
		"terminal_route_exact": direct_route_exact,
	}
	if not _checks_exact(confirmed_checks):
		return _fail_exclusive_battle_case(layout_host, "%s forwarded/native confirm diverged from its direct consequence: checks=%s snapshot=%s direct_result=%s." % [case_id, JSON.stringify(confirmed_checks), JSON.stringify(confirmed), JSON.stringify(direct_result)])
	_cleanup_exclusive_battle_case(layout_host)
	await _settle()
	return true


func _cleanup_exclusive_battle_case(layout_host: Node) -> void:
	AppRouter.validation_set_battle_resolution_checkpoint_routing_suppressed(false)
	AppRouter.validation_set_scenario_outcome_routing_suppressed(false)
	if is_instance_valid(layout_host):
		layout_host.queue_free()


func _fail_exclusive_battle_case(layout_host: Node, message: String) -> bool:
	_cleanup_exclusive_battle_case(layout_host)
	return _fail(message)


func _on_exclusive_battle_parent_probe_pressed(case_id: String) -> void:
	_exclusive_battle_parent_click_counts[case_id] = int(_exclusive_battle_parent_click_counts.get(case_id, 0)) + 1


func _on_exclusive_battle_dialog_canceled(case_id: String) -> void:
	var counts: Dictionary = _exclusive_battle_dialog_signal_counts.get(case_id, {}).duplicate(true)
	counts["canceled"] = int(counts.get("canceled", 0)) + 1
	_exclusive_battle_dialog_signal_counts[case_id] = counts


func _on_exclusive_battle_dialog_confirmed(case_id: String) -> void:
	var counts: Dictionary = _exclusive_battle_dialog_signal_counts.get(case_id, {}).duplicate(true)
	counts["confirmed"] = int(counts.get("confirmed", 0)) + 1
	_exclusive_battle_dialog_signal_counts[case_id] = counts


func _battle_confirmation_transaction_snapshot(shell: Node, action_id: String) -> Dictionary:
	if action_id == "quick_resolve":
		var snapshot: Dictionary = shell.call("validation_quick_resolve_confirmation_snapshot")
		return {
			"pending": bool(snapshot.get("pending", false)),
			"visible": bool(snapshot.get("dialog_visible", false)),
			"request_count": int(snapshot.get("request_count", 0)),
			"cancel_count": int(snapshot.get("cancel_count", 0)),
			"confirm_count": int(snapshot.get("confirm_count", 0)),
			"perform_count": int(snapshot.get("perform_count", 0)),
			"route_count": _quick_resolve_route_count(snapshot),
			"last_result": snapshot.get("last_result", {}),
		}
	var snapshot: Dictionary = shell.call("validation_snapshot")
	return {
		"pending": String(snapshot.get("withdrawal_pending_action", "")) == action_id,
		"visible": bool(snapshot.get("withdrawal_confirmation_visible", false)),
		"pending_action": String(snapshot.get("withdrawal_pending_action", "")),
		"title": String(snapshot.get("withdrawal_confirmation_title", "")),
		"confirm_text": String(snapshot.get("withdrawal_confirmation_ok_text", "")),
		"cancel_text": String(snapshot.get("withdrawal_confirmation_cancel_text", "")),
		"last_result": snapshot.get("withdrawal_last_result", {}),
		"perform_count": _action_perform_count(snapshot, action_id),
		"route_count": int(snapshot.get("validation_battle_resolution_attempt_count", 0)),
		"last_route": snapshot.get("validation_last_battle_resolution_route", {}),
	}


func _action_perform_count(snapshot: Dictionary, action_id: String) -> int:
	var counts: Dictionary = snapshot.get("validation_perform_action_counts", {}) if snapshot.get("validation_perform_action_counts", {}) is Dictionary else {}
	return int(counts.get(action_id, 0))


func _quick_resolve_route_count(snapshot: Dictionary) -> int:
	var checkpoint: Dictionary = snapshot.get("checkpoint", {}) if snapshot.get("checkpoint", {}) is Dictionary else {}
	var checkpoint_router: Dictionary = checkpoint.get("router_snapshot", {}) if checkpoint.get("router_snapshot", {}) is Dictionary else {}
	var outcome: Dictionary = AppRouter.validation_scenario_outcome_route_snapshot()
	return int(checkpoint_router.get("route_attempt_count", 0)) + int(outcome.get("route_attempt_count", 0))


func _battle_confirmation_direct_route_exact(shell: Node, action_id: String, direct_control, confirmed: Dictionary) -> bool:
	if action_id != "quick_resolve":
		var confirmation_result: Dictionary = confirmed.get("last_result", {}) if confirmed.get("last_result", {}) is Dictionary else {}
		var last_route: Dictionary = confirmed.get("last_route", {}) if confirmed.get("last_route", {}) is Dictionary else {}
		return bool(confirmation_result.get("routed", false)) \
			and String(confirmation_result.get("route_target", "")) == "overworld" \
			and String(last_route.get("target", "")) == "overworld" \
			and String(last_route.get("state", "")) == action_id
	var quick_snapshot: Dictionary = shell.call("validation_quick_resolve_confirmation_snapshot")
	var checkpoint: Dictionary = quick_snapshot.get("checkpoint", {}) if quick_snapshot.get("checkpoint", {}) is Dictionary else {}
	var checkpoint_router: Dictionary = checkpoint.get("router_snapshot", {}) if checkpoint.get("router_snapshot", {}) is Dictionary else {}
	var outcome: Dictionary = AppRouter.validation_scenario_outcome_route_snapshot()
	if String(direct_control.scenario_status) != "in_progress":
		return int(checkpoint.get("checkpoint_request_count", 0)) == 0 \
			and int(outcome.get("save_attempt_count", 0)) == 1 \
			and int(outcome.get("route_attempt_count", 0)) == 1 \
			and int(outcome.get("suppressed_route_count", 0)) == 1
	return int(checkpoint.get("checkpoint_request_count", 0)) == 1 \
		and int(checkpoint.get("checkpoint_success_count", 0)) == 1 \
		and int(checkpoint_router.get("save_attempt_count", 0)) == 1 \
		and int(checkpoint_router.get("route_attempt_count", 0)) == 1 \
		and int(checkpoint_router.get("suppressed_route_count", 0)) == 1


func _battle_confirmation_gameplay_payload(session) -> Dictionary:
	var payload: Dictionary = session.to_dict()
	# Scene routing owns this scalar after the rules consequence has completed.
	# It is asserted independently by _battle_confirmation_terminal_state_exact.
	payload.erase("game_state")
	var flags: Dictionary = payload.get("flags", {}) if payload.get("flags", {}) is Dictionary else {}
	flags.erase("last_battle_action_recap")
	payload["flags"] = flags
	var overworld: Dictionary = payload.get("overworld", {}) if payload.get("overworld", {}) is Dictionary else {}
	overworld.erase("command_risk_forecast")
	payload["overworld"] = overworld
	return payload


func _battle_confirmation_terminal_state_exact(action_id: String, session, direct_control) -> bool:
	if String(session.scenario_status) != String(direct_control.scenario_status):
		return false
	if action_id != "quick_resolve":
		return String(session.game_state) == String(direct_control.game_state)
	var expected_route_state := "outcome" if String(direct_control.scenario_status) != "in_progress" else "overworld"
	return String(session.game_state) == expected_route_state and String(direct_control.game_state) == "battle"


func _send_battle_confirmation_cancel(dialog: ConfirmationDialog, input_id: String) -> bool:
	match input_id:
		"joypad_b":
			await _press_joypad_button(JOY_BUTTON_B)
		"escape":
			await _press_key(KEY_ESCAPE)
		"mouse":
			var geometry := _battle_dialog_child_click_geometry(dialog.get_cancel_button(), dialog)
			if not bool(geometry.get("exact", false)):
				return _fail("Native Battle cancel geometry was not exact: %s." % JSON.stringify(geometry))
			await _click_control(dialog.get_cancel_button())
		_:
			return _fail("Unsupported Battle confirmation cancel input %s." % input_id)
	return true


func _send_battle_confirmation_confirm(dialog: ConfirmationDialog, input_id: String) -> bool:
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
			var geometry := _battle_dialog_child_click_geometry(ok_button, dialog)
			if not bool(geometry.get("exact", false)):
				return _fail("Native Battle confirm geometry was not exact: %s." % JSON.stringify(geometry))
			await _click_control(ok_button)
		_:
			return _fail("Unsupported Battle confirmation confirm input %s." % input_id)
	return true


func _settle_battle_confirmation() -> void:
	await _settle()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _checks_exact(checks: Dictionary) -> bool:
	for check_value in checks.values():
		if not bool(check_value):
			return false
	return true


func _exclusive_battle_parent_click_geometry(control: Button, dialog: ConfirmationDialog) -> Dictionary:
	var runner_viewport := get_viewport()
	var parent_click := _control_root_click_position(control)
	var parent_rect := _control_root_rect(control)
	var dialog_rect := Rect2(Vector2(dialog.position), Vector2(dialog.size))
	var cancel_button := dialog.get_cancel_button()
	var child_click := _control_root_click_position(cancel_button)
	var child_rect := _control_root_rect(cancel_button)
	return {
		"exact": dialog.exclusive \
			and control.get_viewport() == runner_viewport \
			and control.is_visible_in_tree() \
			and not control.disabled \
			and parent_rect.has_point(parent_click) \
			and runner_viewport.get_visible_rect().has_point(parent_click) \
			and not dialog_rect.has_point(parent_click) \
			and cancel_button.get_viewport() == dialog \
			and dialog_rect.has_point(child_click) \
			and child_rect.has_point(child_click),
		"parent_click": parent_click,
		"parent_rect": parent_rect,
		"dialog_rect": dialog_rect,
		"child_click": child_click,
		"child_rect": child_rect,
	}


func _battle_dialog_child_click_geometry(control: Control, dialog: ConfirmationDialog) -> Dictionary:
	var click_position := _control_root_click_position(control)
	var control_rect := _control_root_rect(control)
	var dialog_rect := Rect2(Vector2(dialog.position), Vector2(dialog.size))
	return {
		"exact": control.get_viewport() == dialog \
			and control.get_viewport() != get_viewport() \
			and control.is_visible_in_tree() \
			and control_rect.has_point(click_position) \
			and dialog_rect.has_point(click_position),
		"click": click_position,
		"control_rect": control_rect,
		"dialog_rect": dialog_rect,
	}


func _check_quick_resolve_confirm_parity(shell: Node, session) -> bool:
	var quick_resolve: Button = shell.get_node("%QuickResolve")
	var dialog: ConfirmationDialog = shell.get_node("QuickResolveConfirmationDialog")
	var control := SessionStateStoreScript.SessionData.new()
	control.from_dict(session.to_dict())
	control.battle[BattleRules.PRESENTATION_SPEED_KEY] = BattleRules.PRESENTATION_SPEED_INSTANT
	session.battle[BattleRules.PRESENTATION_SPEED_KEY] = BattleRules.PRESENTATION_SPEED_INSTANT
	var control_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(control)
	if not bool(control_result.get("ok", false)) or not bool(control_result.get("completed", false)):
		return _fail("Quick Resolve direct parity control did not reach a terminal result: %s." % control_result)
	var scenario_terminal: bool = control.scenario_status != "in_progress"
	AppRouter.validation_reset_battle_resolution_checkpoint_state()
	AppRouter.validation_set_battle_resolution_checkpoint_routing_suppressed(true)
	AppRouter.validation_reset_scenario_outcome_route_state()
	AppRouter.validation_set_scenario_outcome_routing_suppressed(true)
	shell.call("validation_reset_quick_resolve_confirmation_state")
	await _click_control(quick_resolve)
	await _settle()
	var opened: Dictionary = shell.call("validation_quick_resolve_confirmation_snapshot")
	if not bool(opened.get("pending", false)) or int(opened.get("request_count", 0)) != 1:
		AppRouter.validation_set_battle_resolution_checkpoint_routing_suppressed(false)
		return _fail("Real mouse Quick Resolve did not open exactly one confirmation: %s." % opened)
	var ok_button := dialog.get_ok_button()
	await _press_action("ui_focus_next")
	if ok_button.get_viewport().gui_get_focus_owner() != ok_button:
		ok_button.grab_focus()
		await get_tree().process_frame
	await _press_joypad_button(JOY_BUTTON_A)
	for _frame in range(180):
		await get_tree().process_frame
		var checkpoint_probe: Dictionary = AppRouter.validation_battle_resolution_checkpoint_snapshot()
		var outcome_probe: Dictionary = AppRouter.validation_scenario_outcome_route_snapshot()
		if (scenario_terminal and int(outcome_probe.get("route_attempt_count", 0)) >= 1) \
			or (not scenario_terminal and int(checkpoint_probe.get("route_attempt_count", 0)) >= 1):
			break
	var confirmed: Dictionary = shell.call("validation_quick_resolve_confirmation_snapshot")
	var last_result: Dictionary = confirmed.get("last_result", {}) if confirmed.get("last_result", {}) is Dictionary else {}
	var checkpoint: Dictionary = confirmed.get("checkpoint", {}) if confirmed.get("checkpoint", {}) is Dictionary else {}
	var router: Dictionary = checkpoint.get("router_snapshot", {}) if checkpoint.get("router_snapshot", {}) is Dictionary else {}
	var outcome_router: Dictionary = AppRouter.validation_scenario_outcome_route_snapshot()
	var common_parity_ok: bool = int(confirmed.get("confirm_count", 0)) == 1 \
		and int(confirmed.get("perform_count", 0)) == 1 \
		and bool(last_result.get("performed", false)) \
		and bool(last_result.get("ok", false)) \
		and last_result.get("result", {}) == control_result \
		and session.battle.is_empty() \
		and control.battle.is_empty() \
		and session.overworld == control.overworld \
		and session.flags == control.flags \
		and session.scenario_status == control.scenario_status
	var route_parity_ok: bool = false
	if scenario_terminal:
		route_parity_ok = int(checkpoint.get("checkpoint_request_count", 0)) == 0 \
			and int(outcome_router.get("save_attempt_count", 0)) == 1 \
			and int(outcome_router.get("route_attempt_count", 0)) == 1 \
			and int(outcome_router.get("suppressed_route_count", 0)) == 1
	else:
		route_parity_ok = int(checkpoint.get("checkpoint_request_count", 0)) == 1 \
			and int(checkpoint.get("checkpoint_success_count", 0)) == 1 \
			and int(router.get("save_attempt_count", 0)) == 1 \
			and int(router.get("route_attempt_count", 0)) == 1 \
			and int(router.get("suppressed_route_count", 0)) == 1
	if not common_parity_ok \
		or not route_parity_ok:
		AppRouter.validation_set_battle_resolution_checkpoint_routing_suppressed(false)
		AppRouter.validation_set_scenario_outcome_routing_suppressed(false)
		return _fail("Mouse-opened, controller-confirmed Quick Resolve diverged from direct result/routing parity: terminal=%s confirmation=%s checkpoint=%s outcome=%s." % [scenario_terminal, confirmed, checkpoint, outcome_router])
	var repeat_result: Dictionary = shell.call("validation_confirm_quick_resolve_confirmation")
	var repeated: Dictionary = shell.call("validation_quick_resolve_confirmation_snapshot")
	AppRouter.validation_set_battle_resolution_checkpoint_routing_suppressed(false)
	AppRouter.validation_set_scenario_outcome_routing_suppressed(false)
	if String(repeat_result.get("reason", "")) != "no_pending_confirmation" \
		or int(repeated.get("confirm_count", 0)) != 1 \
		or int(repeated.get("perform_count", 0)) != 1:
		return _fail("Repeated Quick Resolve confirmation replayed the resolver: repeat=%s snapshot=%s." % [repeat_result, repeated])
	return true


func _quick_resolve_authority_snapshot(session) -> Dictionary:
	var settings_snapshot: Dictionary = SettingsService.validation_settings_transaction_snapshot()
	var files := {}
	for path in [
		"user://saves/autosave.json",
		"user://saves/manual_slot_1.json",
		"user://saves/manual_slot_2.json",
		"user://saves/manual_slot_3.json",
		"user://saves/campaign_progression.json",
		"user://settings.cfg",
		"user://settings.cfg.candidate",
		"user://settings.cfg.backup",
	]:
		files[path] = _controller_route_file_state(path)
	return {
		"session": session.to_dict(),
		"active_same": SessionState.active_session == session,
		"profile": CampaignProgression.profile.duplicate(true),
		"files": files,
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
		"settings": settings_snapshot.get("settings", {}),
		"committed_settings": settings_snapshot.get("committed_settings", {}),
		"battle_resolution": AppRouter.validation_battle_resolution_checkpoint_snapshot(),
		"battle_entry": AppRouter.validation_battle_entry_snapshot(),
		"outcome": AppRouter.validation_scenario_outcome_route_snapshot(),
		"return_to_menu": AppRouter.validation_active_play_return_snapshot(),
		"safe_quit": AppRouter.validation_safe_quit_snapshot(),
	}


func _check_battle_withdrawal_controller_cancel(shell: Node, session, action_id: String, button_name: String) -> bool:
	var origin_button: Button = shell.get_node_or_null("%%%s" % button_name)
	var dialog: ConfirmationDialog = shell.get_node_or_null("WithdrawalConfirmationDialog")
	if origin_button == null or dialog == null:
		return _fail("Battle %s confirmation controls are missing." % button_name)
	if origin_button.disabled:
		return _fail("Battle %s command is disabled during the active player turn." % button_name)

	var action_surface: Dictionary = BattleRules.get_action_surface(session)
	var action_value: Variant = action_surface.get(action_id, {})
	var action: Dictionary = action_value if action_value is Dictionary else {}
	if action.is_empty() or bool(action.get("disabled", true)):
		return _fail("Battle %s fixture has no ready live action surface: %s." % [button_name, action])
	var snapshot_before := JSON.stringify(session.to_dict())
	origin_button.grab_focus()
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()

	if not dialog.visible:
		return _fail("Controller-confirmed %s did not open the shared withdrawal confirmation." % button_name)
	if dialog.title != "Confirm %s?" % button_name:
		return _fail("%s confirmation title is not action-specific: %s." % [button_name, dialog.title])
	if dialog.get_ok_button().text != "Confirm %s" % button_name or dialog.get_cancel_button().text != "Keep Fighting":
		return _fail("%s confirmation actions are unclear: confirm=%s cancel=%s." % [button_name, dialog.get_ok_button().text, dialog.get_cancel_button().text])
	for field in ["summary", "consequence", "confirmation"]:
		var required_copy := String(action.get(field, "")).strip_edges()
		if required_copy == "" or required_copy not in dialog.dialog_text:
			return _fail("%s confirmation omitted the live %s copy: expected=%s dialog=%s." % [button_name, field, required_copy, dialog.dialog_text])
	var shell_snapshot: Dictionary = shell.call("validation_snapshot")
	var exit_cues_value: Variant = shell_snapshot.get("battle_exit_order_cues", {})
	var exit_cues: Dictionary = exit_cues_value if exit_cues_value is Dictionary else {}
	for field in ["route", "save"]:
		var required_cue := String(exit_cues.get(field, "")).strip_edges()
		if required_cue == "" or required_cue not in dialog.dialog_text:
			return _fail("%s confirmation omitted the live %s cue: expected=%s dialog=%s." % [button_name, field, required_cue, dialog.dialog_text])
	var dialog_viewport := dialog.get_cancel_button().get_viewport()
	var dialog_focus_owner := dialog_viewport.gui_get_focus_owner() if dialog_viewport != null else null
	if dialog_focus_owner != dialog.get_cancel_button():
		return _fail("%s confirmation did not place initial focus on the safer Keep Fighting action in its native dialog viewport: %s." % [button_name, dialog_focus_owner])

	await _press_joypad_button(JOY_BUTTON_B)
	await _settle()
	if dialog.visible:
		return _fail("Controller B did not close the %s confirmation." % button_name)
	var snapshot_after := JSON.stringify(session.to_dict())
	if snapshot_after != snapshot_before:
		return _fail("Controller-canceling %s changed the byte-exact session snapshot." % button_name)
	if get_viewport().gui_get_focus_owner() != origin_button:
		return _fail("Canceling %s did not restore focus to the exact originating command: %s." % [button_name, _focus_name()])
	return true

func _legal_cardinal_move(session, minimum_steps: int = 1) -> Dictionary:
	for candidate in [
		{"keycode": SettingsService.hero_movement_keycode(&"hero_move_up"), "delta": Vector2i.UP},
		{"keycode": SettingsService.hero_movement_keycode(&"hero_move_down"), "delta": Vector2i.DOWN},
		{"keycode": SettingsService.hero_movement_keycode(&"hero_move_left"), "delta": Vector2i.LEFT},
		{"keycode": SettingsService.hero_movement_keycode(&"hero_move_right"), "delta": Vector2i.RIGHT},
	]:
		var probe = SessionState.new_session_data()
		probe.from_dict(session.to_dict())
		var delta: Vector2i = candidate.delta
		var route_is_legal := true
		for _step in range(maxi(1, minimum_steps)):
			var result: Dictionary = OverworldRules.try_move(probe, delta.x, delta.y)
			if not bool(result.get("ok", false)) or String(result.get("route", "")) != "":
				route_is_legal = false
				break
		if route_is_legal:
			return candidate
	return {}

func _battle_button_name(action_id: String) -> String:
	return {
		"advance": "Advance",
		"strike": "Strike",
		"shoot": "Shoot",
		"defend": "Defend",
		"retreat": "Retreat",
		"surrender": "Surrender",
	}.get(action_id, "")

func _battle_focus_matches_action(focus_owner: Control, action_id: String) -> bool:
	if focus_owner == null or action_id == "":
		return false
	if action_id.begins_with("cast_spell:"):
		return String(focus_owner.get_meta("battle_action_id", "")) == action_id
	var expected_name := _battle_button_name(action_id)
	return expected_name != "" and String(focus_owner.name) == expected_name

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


func _click_control(control: Control) -> void:
	var source_viewport := control.get_viewport()
	var viewport := get_viewport()
	var center := _control_root_click_position(control)
	var window_id: int = int(source_viewport.get_window_id()) if source_viewport is Window else 0
	var motion := InputEventMouseMotion.new()
	motion.window_id = window_id
	motion.position = center
	motion.global_position = center
	viewport.push_input(motion, true)
	await get_tree().process_frame
	var pressed := InputEventMouseButton.new()
	pressed.window_id = window_id
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.position = center
	pressed.global_position = center
	pressed.pressed = true
	viewport.push_input(pressed, true)
	await get_tree().process_frame
	var released := InputEventMouseButton.new()
	released.window_id = window_id
	released.button_index = MOUSE_BUTTON_LEFT
	released.position = center
	released.global_position = center
	released.pressed = false
	viewport.push_input(released, true)
	await _settle()


func _control_root_click_position(control: Control) -> Vector2:
	var click_position := control.get_global_rect().get_center()
	var source_viewport := control.get_viewport()
	if source_viewport is Window and source_viewport != get_viewport():
		click_position += Vector2((source_viewport as Window).position)
	return click_position


func _control_root_rect(control: Control) -> Rect2:
	var control_rect := control.get_global_rect()
	var source_viewport := control.get_viewport()
	if source_viewport is Window and source_viewport != get_viewport():
		control_rect.position += Vector2((source_viewport as Window).position)
	return control_rect


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

func _send_joypad_axis(axis: int, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = value
	Input.parse_input_event(motion)
	await get_tree().process_frame

func _controller_axis_for_delta(delta: Vector2i) -> Dictionary:
	return {
		Vector2i.UP: {"axis": JOY_AXIS_LEFT_Y, "value": -1.0},
		Vector2i.DOWN: {"axis": JOY_AXIS_LEFT_Y, "value": 1.0},
		Vector2i.LEFT: {"axis": JOY_AXIS_LEFT_X, "value": -1.0},
		Vector2i.RIGHT: {"axis": JOY_AXIS_LEFT_X, "value": 1.0},
	}.get(delta, {})

func _controller_route_axis_for_delta(delta: Vector2i) -> Dictionary:
	return {
		Vector2i.UP: {"axis": JOY_AXIS_RIGHT_Y, "value": -1.0},
		Vector2i.DOWN: {"axis": JOY_AXIS_RIGHT_Y, "value": 1.0},
		Vector2i.LEFT: {"axis": JOY_AXIS_RIGHT_X, "value": -1.0},
		Vector2i.RIGHT: {"axis": JOY_AXIS_RIGHT_X, "value": 1.0},
	}.get(delta, {})

func _controller_snapshot_tile(value: Variant) -> Vector2i:
	if not (value is Dictionary):
		return Vector2i(-1, -1)
	return Vector2i(int(value.get("x", -1)), int(value.get("y", -1)))

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _capture_if_requested(stem: String) -> void:
	if OS.get_environment("ACTIVE_PLAY_KEYBOARD_CAPTURE") != "1":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	var path := "%s/%s.png" % [CAPTURE_DIR, stem]
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		_fail("Could not save visual capture %s: %s." % [path, error])

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

func _focus_name() -> String:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return "none" if focus_owner == null else String(focus_owner.name)

func _dialog_fits_root_viewport(dialog: Window) -> bool:
	var viewport_size := Vector2i(get_viewport().get_visible_rect().size)
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return true
	var dialog_end := dialog.position + dialog.size
	return dialog.position.x >= 0 and dialog.position.y >= 0 \
		and dialog_end.x <= viewport_size.x and dialog_end.y <= viewport_size.y

func _assert_accessible_surface(shell: Node, context: String, minimum_live_regions: int) -> bool:
	var snapshot: Dictionary = UiAccessibility.validation_snapshot(shell)
	if not bool(snapshot.get("ok", false)):
		return _fail("%s visible focusable controls are missing native accessibility semantics: %s" % [context, snapshot])
	if int(snapshot.get("live_region_count", 0)) < minimum_live_regions:
		return _fail("%s exposes too few polite live regions: %s" % [context, snapshot])
	return true

func _fail(message: String) -> bool:
	if _failed:
		return false
	_failed = true
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
	return false
