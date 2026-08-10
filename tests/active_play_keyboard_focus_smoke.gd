extends Node

const REPORT_ID := "ACTIVE_PLAY_KEYBOARD_FOCUS_SMOKE"
const CAPTURE_DIR := "res://.artifacts/active_play_keyboard_focus_smoke"
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

var _failed := false

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
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var end_turn: Button = shell.get_node_or_null("%EndTurn")
	var dialog: ConfirmationDialog = shell.get_node_or_null("EndTurnConfirmationDialog")
	if end_turn == null or dialog == null:
		return _fail("Overworld End Turn confirmation controls are missing.")
	var live_snapshot: Dictionary = shell.call("validation_end_turn_confirmation_snapshot")
	if not bool(live_snapshot.get("confirmation_required", false)) or not String(live_snapshot.get("surface_button_text", "")).begins_with("End?"):
		return _fail("Fresh overworld fixture does not expose a live warned End Turn state: %s." % live_snapshot)
	var session_before := JSON.stringify(session.to_dict())
	end_turn.grab_focus()
	await get_tree().process_frame
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()
	if not _assert_overworld_end_turn_dialog(shell, dialog, live_snapshot):
		return false
	await _press_joypad_button(JOY_BUTTON_B)
	await _settle()
	if dialog.visible:
		return _fail("Controller B did not close the warned End Turn confirmation.")
	if JSON.stringify(session.to_dict()) != session_before:
		return _fail("Controller B changed the byte-exact overworld session while canceling End Turn.")
	if get_viewport().gui_get_focus_owner() != end_turn:
		return _fail("Controller B did not restore focus to the exact EndTurn command: %s." % _focus_name())

	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()
	if not _assert_overworld_end_turn_dialog(shell, dialog, live_snapshot):
		return false
	await _press_key(KEY_ESCAPE)
	await _settle()
	if dialog.visible:
		return _fail("Keyboard Escape did not close the warned End Turn confirmation.")
	if JSON.stringify(session.to_dict()) != session_before:
		return _fail("Keyboard Escape changed the byte-exact overworld session while canceling End Turn.")
	if get_viewport().gui_get_focus_owner() != end_turn:
		return _fail("Keyboard Escape did not restore focus to the exact EndTurn command: %s." % _focus_name())
	shell.queue_free()
	await get_tree().process_frame
	return true

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
	for cancel_kind in ["controller_b", "escape"]:
		save_button.grab_focus()
		await get_tree().process_frame
		if get_viewport().gui_get_focus_owner() != save_button:
			return _fail("Manual overwrite could not establish exact Save origin focus before %s." % cancel_kind)
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
	return "%s/manual_slot_%d.json" % [SaveService.SAVE_DIR, slot]

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
	await _press_joypad_button(JOY_BUTTON_B)
	await _settle()
	if shell.get_node("%SidebarShell").visible or not shell.get_node("%StageColumn").visible:
		return _fail("Controller B did not return from narrow town orders to the scenic town view.")
	if _focus_name() != "TownOrdersToggle":
		return _fail("Narrow town controller back did not restore TownOrdersToggle focus: %s." % _focus_name())
	frame.queue_free()
	await get_tree().process_frame
	return true

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
	var expected_name := _battle_button_name(action_id)
	if expected_name == "" or _focus_name() != expected_name:
		return _fail("Battle entry focus did not match suggested order %s: expected=%s got=%s." % [action_id, expected_name, _focus_name()])
	var battle_entry_focus := get_viewport().gui_get_focus_owner()
	await _press_joypad_button(JOY_BUTTON_DPAD_DOWN)
	var battle_dpad_focus := get_viewport().gui_get_focus_owner()
	if battle_dpad_focus == null or battle_dpad_focus == battle_entry_focus or not shell.is_ancestor_of(battle_dpad_focus):
		return _fail("Battle D-pad did not advance the active command focus: before=%s after=%s." % [battle_entry_focus, battle_dpad_focus])
	await _press_joypad_button(JOY_BUTTON_DPAD_UP)
	if get_viewport().gui_get_focus_owner() != battle_entry_focus:
		return _fail("Battle D-pad did not return to the suggested order: expected=%s got=%s." % [battle_entry_focus, get_viewport().gui_get_focus_owner()])
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
	var post_forecast: Dictionary = post_snapshot.get("intent_forecast", {}) if post_snapshot.get("intent_forecast", {}) is Dictionary else {}
	var post_expected := _battle_button_name(String(post_forecast.get("action_id", "")))
	if post_expected != "" and post_owner.name != post_expected:
		return _fail("Battle post-action focus did not follow the next suggested order: expected=%s got=%s." % [post_expected, post_owner.name])
	if not await _check_quick_resolve_confirm_parity(shell, session):
		return false
	shell.queue_free()
	await get_tree().process_frame
	return true

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
	var center := control.get_global_rect().get_center()
	var viewport := control.get_viewport()
	var window_id: int = int(viewport.get_window_id()) if viewport is Window else 0
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
