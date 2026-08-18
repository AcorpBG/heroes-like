extends Node

const REPORT_ID := "BATTLE_CONTROLLER_BOARD_NAVIGATION_SMOKE"
const CAPTURE_DIR := "res://.artifacts/battle_controller_board_navigation_smoke"
const SEMANTIC_DEBOUNCE_SECONDS := 0.42
const RESULT_VISIBLE_SECONDS := 1.20

var _last_dispatched_stack_id := ""

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var original_session = SessionState.active_session
	for width in [1280, 1920]:
		if not await _validate_battle_board_semantics_width(width):
			return
	get_window().size = Vector2i(1280, 720)
	await _settle()
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		return _fail("Battle controller fixture has no encounter.")
	session.battle = BattleRules.create_battle_payload(session, encounter)
	var guard := 0
	while String(BattleRules.get_active_stack(session.battle).get("side", "")) != "player" and guard < 8:
		BattleRules.advance_turn(session.battle)
		guard += 1
	if String(BattleRules.get_active_stack(session.battle).get("side", "")) != "player":
		return _fail("Battle controller fixture could not reach a player turn.")
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	await _settle()

	var board: Control = shell.get_node("%BattleBoard")
	var battle_live: Label = shell.get_node("%BattleBoardCursorLive")
	var battle_semantic_timer: Timer = board.get("_battle_board_cursor_semantic_timer")
	board.stack_focus_requested.connect(_on_stack_focus_requested)
	if get_viewport().gui_get_focus_owner() == board:
		return _fail("Battle entry must retain preferred command focus instead of auto-entering the board.")
	var traversal_count := 0
	while get_viewport().gui_get_focus_owner() != board and traversal_count < 24:
		await _press_joypad_button(JOY_BUTTON_RIGHT_SHOULDER)
		traversal_count += 1
	if get_viewport().gui_get_focus_owner() != board:
		return _fail("Controller shoulder traversal did not reach the battle board.")

	var initial_summary: Dictionary = board.call("validation_hex_layout_summary")
	if not bool(initial_summary.get("controller_board_focused", false)):
		return _fail("Focused battle board did not expose controller focus ownership: %s." % initial_summary)
	var initial_cursor := Vector2i(
		int(initial_summary.get("controller_cursor_q", -1)),
		int(initial_summary.get("controller_cursor_r", -1))
	)
	if not _cell_in_bounds(initial_cursor, initial_summary):
		return _fail("Battle controller cursor did not initialize to a board cell: %s." % initial_summary)
	var probe_button := JOY_BUTTON_DPAD_RIGHT if initial_cursor.x < int(initial_summary.get("columns", 11)) - 1 else JOY_BUTTON_DPAD_LEFT
	await _press_joypad_button(probe_button)
	var moved_summary: Dictionary = board.call("validation_hex_layout_summary")
	var moved_cursor := Vector2i(
		int(moved_summary.get("controller_cursor_q", -1)),
		int(moved_summary.get("controller_cursor_r", -1))
	)
	if moved_cursor == initial_cursor:
		return _fail("Real D-pad input did not move the focused board cursor: before=%s after=%s." % [initial_cursor, moved_cursor])
	var selected_before := String(BattleRules.get_selected_target(session.battle).get("battle_id", ""))
	var enemy_target := _different_enemy_stack_cell(moved_summary, selected_before)
	if enemy_target.is_empty():
		return _fail("Battle controller fixture has no alternate enemy stack for cursor target dispatch.")
	var enemy_cell: Vector2i = enemy_target.get("cell", Vector2i(-1, -1))
	while moved_cursor.x != enemy_cell.x:
		await _press_joypad_button(JOY_BUTTON_DPAD_RIGHT if moved_cursor.x < enemy_cell.x else JOY_BUTTON_DPAD_LEFT)
		moved_cursor.x += 1 if moved_cursor.x < enemy_cell.x else -1
	while moved_cursor.y != enemy_cell.y:
		await _press_joypad_button(JOY_BUTTON_DPAD_DOWN if moved_cursor.y < enemy_cell.y else JOY_BUTTON_DPAD_UP)
		moved_cursor.y += 1 if moved_cursor.y < enemy_cell.y else -1
	var enemy_cursor_summary: Dictionary = board.call("validation_hex_layout_summary")
	if not bool(enemy_cursor_summary.get("controller_board_focused", false)):
		return _fail("Battle board lost focus while the controller cursor crossed occupied cells: %s." % enemy_cursor_summary)
	if String(enemy_cursor_summary.get("controller_cursor_battle_id", "")) != String(enemy_target.get("battle_id", "")):
		return _fail("Controller cursor did not reach the blocked enemy stack: target=%s board=%s." % [enemy_target, enemy_cursor_summary])
	var target_events_before := int(session.battle.get("recent_events", []).size())
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()
	var blocked_result_message := String(shell.get("_last_message")).strip_edges()
	var blocked_snapshot: Dictionary = shell.call("validation_snapshot")
	var blocked_dispatch := BattleRules.describe_dispatch(session, blocked_result_message)
	var blocked_full_latest := blocked_dispatch.get_slice("\n", 0)
	var blocked_expected_latest := _battle_event_word_text_control(blocked_full_latest, 96)
	var blocked_visible_latest := ""
	var blocked_latest_count := 0
	for raw_line in String(blocked_snapshot.get("event_visible_text", "")).split("\n", false):
		var line := String(raw_line).strip_edges()
		if line.begins_with("Latest:"):
			blocked_visible_latest = line
			blocked_latest_count += 1
	if blocked_full_latest.length() <= 96 \
			or blocked_latest_count != 1 \
			or blocked_visible_latest != blocked_expected_latest \
			or blocked_visible_latest.contains("...") \
			or not blocked_visible_latest.ends_with("…") \
			or _battle_event_word_text_control("Move to a highlighted hex", 10) != "Move…" \
			or not String(blocked_snapshot.get("event_tooltip_text", "")).contains(blocked_full_latest):
		return _fail("Blocked-action Battle Event line did not use exact whole-word fitting while retaining the full dispatch tooltip: full=%s expected=%s visible=%s snapshot=%s." % [blocked_full_latest, blocked_expected_latest, blocked_visible_latest, blocked_snapshot])
	var blocked_result_text := _bounded_text("Battle board result: %s" % blocked_result_message, 320)
	if _last_dispatched_stack_id != String(enemy_target.get("battle_id", "")):
		return _fail("Controller A did not dispatch the occupied enemy cursor cell through target selection: target=%s emitted=%s." % [enemy_target, _last_dispatched_stack_id])
	if int(session.battle.get("recent_events", []).size()) != target_events_before:
		return _fail("Blocked enemy cursor selection executed an unexpected battle action.")
	if blocked_result_message == "" or not _exact_result_pending(board, battle_live, battle_semantic_timer, blocked_result_text):
		return _fail("Blocked enemy controller A did not publish its exact independent Shell result: message=%s text=%s expected=%s pending=%s." % [blocked_result_message, battle_live.text, blocked_result_text, _pending_compact(board.get("_battle_board_cursor_semantic_pending"))])
	if not await _wait_for_result_clear(board, battle_live, battle_semantic_timer):
		return _fail("Blocked enemy controller result did not clear through the real 1.2 second Timer.")
	await _press_joypad_button(JOY_BUTTON_B)
	var cancel_focus := get_viewport().gui_get_focus_owner()
	if cancel_focus == null or cancel_focus == board or not shell.is_ancestor_of(cancel_focus) or (cancel_focus is BaseButton and cancel_focus.disabled):
		return _fail("Controller B did not restore a legal battle command focus: %s." % cancel_focus)
	if not _exact_result_pending(board, battle_live, battle_semantic_timer, "Battle board navigation ended. Focus returned to battle commands."):
		return _fail("Controller B did not publish its exact guarded navigation result once: text=%s pending=%s." % [battle_live.text, _pending_compact(board.get("_battle_board_cursor_semantic_pending"))])
	if not await _wait_for_result_clear(board, battle_live, battle_semantic_timer):
		return _fail("Controller B navigation result did not clear through the real 1.2 second Timer.")

	board.grab_focus()
	await _settle()
	var board_summary: Dictionary = board.call("validation_hex_layout_summary")
	var legal_destinations: Array = board_summary.get("legal_destinations", []) if board_summary.get("legal_destinations", []) is Array else []
	if legal_destinations.is_empty():
		return _fail("Battle controller fixture has no legal exact destination.")
	var destination_value = legal_destinations[0]
	if not (destination_value is Dictionary):
		return _fail("Battle controller destination payload is malformed: %s." % destination_value)
	var destination := Vector2i(int(destination_value.get("q", -1)), int(destination_value.get("r", -1)))
	var cursor := Vector2i(
		int(board_summary.get("controller_cursor_q", -1)),
		int(board_summary.get("controller_cursor_r", -1))
	)
	while cursor.x != destination.x:
		await _press_joypad_button(JOY_BUTTON_DPAD_RIGHT if cursor.x < destination.x else JOY_BUTTON_DPAD_LEFT)
		cursor.x += 1 if cursor.x < destination.x else -1
	while cursor.y != destination.y:
		await _press_joypad_button(JOY_BUTTON_DPAD_DOWN if cursor.y < destination.y else JOY_BUTTON_DPAD_UP)
		cursor.y += 1 if cursor.y < destination.y else -1
	var destination_summary: Dictionary = board.call("validation_hex_layout_summary")
	if not bool(destination_summary.get("controller_cursor_legal_destination", false)):
		return _fail("Controller cursor did not reach the selected legal destination %s: %s." % [destination, destination_summary])
	var capture_tabs: TabContainer = shell.get_node("%BattleTabs")
	var capture_tab_index: int = int(OS.get_environment("BATTLE_CONTROLLER_BOARD_CAPTURE_TAB_INDEX")) if OS.get_environment("BATTLE_CONTROLLER_BOARD_CAPTURE_TAB_INDEX").is_valid_int() else -1
	var capture_initial_tab: int = capture_tabs.current_tab
	if capture_tab_index >= 0 and capture_tab_index < capture_tabs.get_tab_count():
		capture_tabs.current_tab = capture_tab_index
		await _settle()
	await _capture_if_requested()
	if capture_tab_index >= 0 and capture_tab_index < capture_tabs.get_tab_count():
		capture_tabs.current_tab = capture_initial_tab
		await _settle()

	var active_before := BattleRules.get_active_stack(session.battle)
	var active_battle_id := String(active_before.get("battle_id", ""))
	var events_before := int(session.battle.get("recent_events", []).size())
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()
	var movement_result_message := String(shell.get("_last_message")).strip_edges()
	var movement_result_text := _bounded_text("Battle board result: %s" % movement_result_message, 320)
	var post_summary: Dictionary = shell.call("validation_snapshot").get("battle_board", {})
	var moved_stack_cell := _stack_cell(post_summary, active_battle_id)
	if moved_stack_cell != destination:
		return _fail("Controller A did not dispatch the exact board destination: expected=%s actual=%s." % [destination, moved_stack_cell])
	if int(session.battle.get("recent_events", []).size()) <= events_before:
		return _fail("Controller board move did not advance the battle event stream.")
	var post_focus := get_viewport().gui_get_focus_owner()
	if post_focus == null or post_focus == board or not shell.is_ancestor_of(post_focus):
		return _fail("Controller board move did not restore command focus after refresh: %s." % post_focus)
	if movement_result_message == "" or not _exact_result_pending(board, battle_live, battle_semantic_timer, movement_result_text):
		return _fail("Legal controller A did not publish its exact independent Shell movement result: message=%s text=%s expected=%s pending=%s." % [movement_result_message, battle_live.text, movement_result_text, _pending_compact(board.get("_battle_board_cursor_semantic_pending"))])
	if not await _wait_for_result_clear(board, battle_live, battle_semantic_timer):
		return _fail("Legal controller movement result did not clear through the real 1.2 second Timer.")

	shell.queue_free()
	await get_tree().process_frame
	SessionState.active_session = original_session
	get_window().size = original_window_size
	print("%s PASS" % REPORT_ID)
	get_tree().quit(0)

func _validate_battle_board_semantics_width(width: int) -> bool:
	get_window().size = Vector2i(width, 720)
	await _settle()
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		return _fail_bool("Battle semantic fixture %d has no encounter." % width)
	session.battle = BattleRules.create_battle_payload(session, encounter)
	var guard := 0
	while String(BattleRules.get_active_stack(session.battle).get("side", "")) != "player" and guard < 8:
		BattleRules.advance_turn(session.battle)
		guard += 1
	if String(BattleRules.get_active_stack(session.battle).get("side", "")) != "player":
		return _fail_bool("Battle semantic fixture %d could not reach a player turn." % width)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var board: Control = shell.get_node("%BattleBoard")
	var live: Label = shell.get_node("%BattleBoardCursorLive")
	var semantic_timer: Timer = board.get("_battle_board_cursor_semantic_timer")
	if semantic_timer == null or not semantic_timer.one_shot or not is_equal_approx(semantic_timer.wait_time, 1.0):
		shell.queue_free()
		return _fail_bool("Battle semantic Timer was not a configured one-shot before use at %d: %s." % [width, semantic_timer])
	if not _validate_battle_status_native_ellipsis(shell, session, width, width == 1280):
		shell.queue_free()
		return false
	if not _validate_board_footer_pixel_ellipsis(board, session, width, false):
		shell.queue_free()
		return false
	if not _validate_turn_strip_identity_surface(board, session, width):
		shell.queue_free()
		return false
	if not _validate_order_tab_compact_summary(shell, session, width):
		shell.queue_free()
		return false
	if not _validate_battle_info_tab_header_fit(shell, session, width):
		shell.queue_free()
		return false
	if not await _validate_battle_focus_spell_tab_body_fit(shell, session, width):
		shell.queue_free()
		return false
	if not await _validate_battle_timing_tab_body_fit(shell, session, width):
		shell.queue_free()
		return false
	board.grab_focus()
	await _settle()
	if not _validate_board_footer_pixel_ellipsis(board, session, width, true):
		shell.queue_free()
		return false
	if live.text != "":
		shell.queue_free()
		return _fail_bool("Battle semantic label was not inactive before navigation at %d: %s." % [width, live.text])

	var summary: Dictionary = board.call("validation_hex_layout_summary")
	var active_cell := _active_stack_cell(summary)
	var friendly_cell := _first_stack_cell(summary, "player", String(session.battle.get("active_stack_id", "")))
	var enemy_cell := _first_stack_cell(summary, "enemy", "")
	var legal_cell := _first_legal_destination(summary)
	var blocked_cell := _first_blocked_empty_cell(summary)
	if not _cell_in_bounds(active_cell, summary) or not _cell_in_bounds(friendly_cell, summary) or not _cell_in_bounds(enemy_cell, summary) or not _cell_in_bounds(legal_cell, summary) or not _cell_in_bounds(blocked_cell, summary):
		shell.queue_free()
		return _fail_bool("Battle semantic fixture lacked active/friendly/enemy/legal/blocked cells at %d: %s." % [width, summary])
	var semantic_rows: Array[Dictionary] = [
		{"id": "active", "cell": active_cell},
		{"id": "friendly", "cell": friendly_cell},
		{"id": "enemy", "cell": enemy_cell},
		{"id": "legal", "cell": legal_cell},
		{"id": "blocked", "cell": blocked_cell},
	]
	for row_index in range(semantic_rows.size()):
		var row: Dictionary = semantic_rows[row_index]
		if not await _assert_semantic_context_at(
			shell,
			board,
			live,
			semantic_timer,
			session,
			row.get("cell", Vector2i(-1, -1)),
			width,
			String(row.get("id", "")),
			(row_index + width) % 2 == 0
		):
			shell.queue_free()
			return false

	# A clamped physical move and pointer hover must not replace the settled keyboard/controller context.
	var boundary := Vector2i(0, blocked_cell.y)
	if not await _move_cursor_to(board, boundary, width % 2 == 0):
		shell.queue_free()
		return _fail_bool("Battle semantic cursor could not reach its clamp boundary at %d." % width)
	await _wait_for_semantic_context(board, live, semantic_timer)
	var noop_before := _semantic_observer_snapshot(board, live, semantic_timer)
	var noop_authority := _battle_background_authority(session)
	await _send_direction(Vector2i.LEFT, width % 2 == 0)
	var noop_after := _semantic_observer_snapshot(board, live, semantic_timer)
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.position = board.size * 0.5
	mouse_motion.global_position = board.get_global_rect().position + mouse_motion.position
	Input.parse_input_event(mouse_motion)
	await _settle()
	if noop_after != noop_before or _semantic_observer_snapshot(board, live, semantic_timer) != noop_before or _battle_background_authority(session) != noop_authority:
		shell.queue_free()
		return _fail_bool("Boundary no-op or mouse hover replaced battle semantics/authority at %d: %s / %s." % [width, noop_before, _semantic_observer_snapshot(board, live, semantic_timer)])

	# Existing physical A/B behavior publishes one immediate result and clears only through the real 1.2 Timer.
	summary = board.call("validation_hex_layout_summary")
	var result_enemy_cell := _first_blocked_enemy_cell(summary)
	if not _cell_in_bounds(result_enemy_cell, summary) or not await _move_cursor_to(board, result_enemy_cell, width % 2 != 0):
		shell.queue_free()
		return _fail_bool("Battle result fixture has no blocked enemy cell at %d." % width)
	await _wait_for_semantic_context(board, live, semantic_timer)
	var result_events_before := int(session.battle.get("recent_events", []).size())
	await _press_joypad_button(JOY_BUTTON_A)
	var result_message := String(shell.get("_last_message")).strip_edges()
	var expected_result_text := _bounded_text("Battle board result: %s" % result_message, 320)
	if result_message == "" or int(session.battle.get("recent_events", []).size()) != result_events_before or not _exact_result_pending(board, live, semantic_timer, expected_result_text):
		shell.queue_free()
		return _fail_bool("Physical A did not publish its exact independent Shell result at %d: message=%s text=%s expected=%s pending=%s." % [width, result_message, live.text, expected_result_text, _pending_compact(board.get("_battle_board_cursor_semantic_pending"))])
	if not await _wait_for_result_clear(board, live, semantic_timer):
		shell.queue_free()
		return _fail_bool("Physical A result did not clear through the real 1.2 Timer at %d." % width)
	await get_tree().process_frame
	var cancel_pressed := InputEventJoypadButton.new()
	cancel_pressed.button_index = JOY_BUTTON_B
	cancel_pressed.pressed = true
	var cancel_released := InputEventJoypadButton.new()
	cancel_released.button_index = JOY_BUTTON_B
	cancel_released.pressed = false
	var cancel_delivery := {
		"root_pressed_count": 0,
		"root_released_count": 0,
		"root_pressed_handled": false,
		"root_released_handled": false,
		"pressed_gui_count": 0,
		"released_gui_count": 0,
		"board_pressed_handled": false,
		"board_released_handled": false,
		"focus_exited_count": 0,
		"cancel_signal_count": 0,
	}
	var active_exclusive_before: Variant = shell.call("_active_exclusive_confirmation_dialog")
	var quick_dialog := shell.get_node("QuickResolveConfirmationDialog") as ConfirmationDialog
	var withdrawal_dialog := shell.get_node("WithdrawalConfirmationDialog") as ConfirmationDialog
	var manual_dialog := shell.get_node("ManualSaveOverwriteDialog") as ConfirmationDialog
	var root_connections_before: Array[Dictionary] = _root_window_input_connection_rows()
	var battle_root_connection_count := _connection_row_count(root_connections_before, shell, "_on_root_window_input")
	var manual_root_connection_count := _connection_row_count(root_connections_before, manual_dialog, "_on_root_window_input")
	var quick_cancel_shortcut := _button_shortcut_snapshot(quick_dialog.get_cancel_button(), cancel_pressed, cancel_released)
	var withdrawal_cancel_shortcut := _button_shortcut_snapshot(withdrawal_dialog.get_cancel_button(), cancel_pressed, cancel_released)
	var matching_shell_shortcuts: Array[Dictionary] = _matching_shell_shortcut_rows(shell, cancel_pressed, cancel_released)
	var dialog_state_before := {
		"active_exclusive_is_null": active_exclusive_before == null,
		"quick_pending_false": not bool(shell.get("_quick_resolve_confirmation_pending")),
		"quick_hidden": not quick_dialog.visible,
		"withdrawal_pending_empty": String(shell.get("_pending_withdrawal_action")) == "",
		"withdrawal_hidden": not withdrawal_dialog.visible,
		"manual_hidden": not manual_dialog.visible,
		"manual_pending_slot_zero": int(manual_dialog.get("_pending_slot")) == 0,
		"manual_not_forwarding": not bool(manual_dialog.get("_forwarding_root_physical_input")),
		"battle_root_connection_exact": battle_root_connection_count == 1,
		"manual_root_connection_exact": manual_root_connection_count == 1,
		"quick_cancel_hidden": not bool(quick_cancel_shortcut.get("visible_in_tree", true)),
		"withdrawal_cancel_hidden": not bool(withdrawal_cancel_shortcut.get("visible_in_tree", true)),
	}
	var gui_probe := Callable(self, "_on_cancel_diagnostic_gui_input").bind(cancel_delivery)
	var focus_probe := Callable(self, "_on_cancel_diagnostic_focus_exited").bind(cancel_delivery)
	var cancel_probe := Callable(self, "_on_cancel_diagnostic_navigation_cancelled").bind(cancel_delivery)
	var root_probe := Callable(self, "_on_cancel_diagnostic_root_window_input").bind(cancel_delivery)
	var cancel_contract_checks := {
		"board_focus_before": get_viewport().gui_get_focus_owner() == board and board.has_focus(),
		"active_exclusive_dialog_null": bool(dialog_state_before.get("active_exclusive_is_null", false)),
		"quick_pending_false": bool(dialog_state_before.get("quick_pending_false", false)),
		"quick_hidden": bool(dialog_state_before.get("quick_hidden", false)),
		"withdrawal_pending_empty": bool(dialog_state_before.get("withdrawal_pending_empty", false)),
		"withdrawal_hidden": bool(dialog_state_before.get("withdrawal_hidden", false)),
		"manual_hidden": bool(dialog_state_before.get("manual_hidden", false)),
		"manual_pending_slot_zero": bool(dialog_state_before.get("manual_pending_slot_zero", false)),
		"manual_not_forwarding": bool(dialog_state_before.get("manual_not_forwarding", false)),
		"battle_root_connection_exact": bool(dialog_state_before.get("battle_root_connection_exact", false)),
		"manual_root_connection_exact": bool(dialog_state_before.get("manual_root_connection_exact", false)),
		"ui_cancel_exists": InputMap.has_action("ui_cancel"),
		"pressed_maps_to_ui_cancel": InputMap.event_is_action(cancel_pressed, "ui_cancel") and cancel_pressed.is_action_pressed("ui_cancel"),
		"released_maps_to_ui_cancel": InputMap.event_is_action(cancel_released, "ui_cancel") and cancel_released.is_action_released("ui_cancel"),
		"exact_one_b_binding": _matching_joypad_binding_count("ui_cancel", JOY_BUTTON_B) == 1,
	}
	if not _checks_exact(cancel_contract_checks):
		shell.queue_free()
		return _fail_bool("Physical B input contract was not exact before delivery at %d: checks=%s dialogs=%s active=%s root_connections=%s quick=%s withdrawal=%s matching_shortcuts=%s." % [width, cancel_contract_checks, dialog_state_before, active_exclusive_before, root_connections_before, quick_cancel_shortcut, withdrawal_cancel_shortcut, matching_shell_shortcuts])
	get_tree().root.window_input.connect(root_probe)
	board.gui_input.connect(gui_probe)
	board.focus_exited.connect(focus_probe)
	board.connect("controller_navigation_cancelled", cancel_probe)
	Input.parse_input_event(cancel_pressed)
	await get_tree().process_frame
	Input.parse_input_event(cancel_released)
	await _settle()
	get_tree().root.window_input.disconnect(root_probe)
	board.gui_input.disconnect(gui_probe)
	board.focus_exited.disconnect(focus_probe)
	board.disconnect("controller_navigation_cancelled", cancel_probe)
	var cancel_focus := get_viewport().gui_get_focus_owner()
	var cancel_delivery_checks := {
		"root_pressed_once": int(cancel_delivery.get("root_pressed_count", 0)) == 1,
		"root_released_once": int(cancel_delivery.get("root_released_count", 0)) == 1,
		"root_pressed_handled": bool(cancel_delivery.get("root_pressed_handled", false)),
		"root_released_handled": bool(cancel_delivery.get("root_released_handled", false)),
		"pressed_not_delivered_to_gui": int(cancel_delivery.get("pressed_gui_count", 0)) == 0,
		"released_delivered_at_most_once": int(cancel_delivery.get("released_gui_count", 0)) <= 1,
		"cancel_signal_once": int(cancel_delivery.get("cancel_signal_count", 0)) == 1,
		"focus_exited_once": int(cancel_delivery.get("focus_exited_count", 0)) == 1,
		"focus_owner_restored": cancel_focus != null and cancel_focus != board and shell.is_ancestor_of(cancel_focus),
		"exact_result_pending": _exact_result_pending(board, live, semantic_timer, "Battle board navigation ended. Focus returned to battle commands."),
		"input_released": not Input.is_joy_button_pressed(0, JOY_BUTTON_B),
	}
	if not _checks_exact(cancel_delivery_checks):
		shell.queue_free()
		return _fail_bool("Physical B delivery was not exact at %d: contract=%s dialogs=%s active=%s root_connections=%s quick=%s withdrawal=%s matching_shortcuts=%s delivery=%s focus=%s text=%s pending=%s timer_stopped=%s timer_wait=%s released=%s." % [width, cancel_contract_checks, dialog_state_before, active_exclusive_before, root_connections_before, quick_cancel_shortcut, withdrawal_cancel_shortcut, matching_shell_shortcuts, cancel_delivery, cancel_focus, live.text, _pending_compact(board.get("_battle_board_cursor_semantic_pending")), semantic_timer.is_stopped(), semantic_timer.wait_time, not Input.is_joy_button_pressed(0, JOY_BUTTON_B)])
	if not await _wait_for_result_clear(board, live, semantic_timer):
		shell.queue_free()
		return _fail_bool("Physical B result did not clear through the real 1.2 Timer at %d." % width)
	board.grab_focus()
	await _settle()

	# A later physical cursor step must invalidate an older deferred A result before either publishes.
	summary = board.call("validation_hex_layout_summary")
	var stale_enemy_cell := _first_blocked_enemy_cell(summary)
	if not _cell_in_bounds(stale_enemy_cell, summary) or not await _move_cursor_to(board, stale_enemy_cell, width % 2 == 0):
		shell.queue_free()
		return _fail_bool("Battle stale-result fixture has no blocked enemy cursor cell at %d." % width)
	await _wait_for_semantic_context(board, live, semantic_timer)
	var stale_events_before := int(session.battle.get("recent_events", []).size())
	var stale_direction := Vector2i.RIGHT if stale_enemy_cell.x < int(summary.get("columns", 0)) - 1 else Vector2i.LEFT
	_emit_joypad_tap_sync(JOY_BUTTON_A)
	_emit_direction_sync(stale_direction, width % 2 == 0)
	await get_tree().process_frame
	var replacement_summary_before_publish: Dictionary = board.call("validation_hex_layout_summary")
	var replacement_cell := Vector2i(
		int(replacement_summary_before_publish.get("controller_cursor_q", -1)),
		int(replacement_summary_before_publish.get("controller_cursor_r", -1))
	)
	var replacement_pending: Dictionary = (board.get("_battle_board_cursor_semantic_pending") as Dictionary).duplicate(true)
	var stale_checks := {
		"blocked_action_no_event": int(session.battle.get("recent_events", []).size()) == stale_events_before,
		"replacement_cursor_intended": replacement_cell == stale_enemy_cell + stale_direction,
		"replacement_context_pending": String(replacement_pending.get("kind", "")) == "context",
		"replacement_cell_exact": replacement_pending.get("cursor_cell", {}) == _cell_payload(replacement_cell),
		"replacement_generation_current": int(replacement_pending.get("generation", -1)) == int(board.get("_battle_board_cursor_semantic_generation")),
		"stale_result_not_published": not live.text.begins_with("Battle board result:"),
		"semantic_timer_active": not semantic_timer.is_stopped(),
		"semantic_timer_wait_exact": is_equal_approx(semantic_timer.wait_time, SEMANTIC_DEBOUNCE_SECONDS),
	}
	if not _checks_exact(stale_checks) or not await _wait_for_semantic_context(board, live, semantic_timer):
		shell.queue_free()
		return _fail_bool("Later physical cursor context did not replace the stale deferred A result at %d: %s pending=%s text=%s." % [width, stale_checks, _pending_compact(replacement_pending), live.text])
	var replacement_summary: Dictionary = board.call("validation_hex_layout_summary")
	if live.text != _expected_semantic_context(board, session, replacement_summary):
		shell.queue_free()
		return _fail_bool("Stale-result replacement did not publish the exact final cursor context at %d: %s." % [width, live.text])

	# A real enemy turn keeps the same exact surface format but changes A/Enter to the input-lock action.
	guard = 0
	while String(BattleRules.get_active_stack(session.battle).get("side", "")) == "player" and guard < 16:
		BattleRules.advance_turn(session.battle)
		guard += 1
	shell.call("_refresh")
	await _settle()
	board.grab_focus()
	await _settle()
	if String(BattleRules.get_active_stack(session.battle).get("side", "")) == "player" or not await _assert_semantic_context_at(shell, board, live, semantic_timer, session, enemy_cell, width, "input_lock_turn", width % 2 != 0):
		shell.queue_free()
		return _fail_bool("Battle input-lock semantic row was not exact at %d." % width)
	var locked_text := live.text
	if not locked_text.contains("A/Enter: unavailable while input is locked."):
		shell.queue_free()
		return _fail_bool("Battle enemy-turn semantic omitted exact input-lock action at %d: %s." % [width, locked_text])

	# Focus, modal ownership, battle identity, turn identity, and tree exit all cancel staged context.
	var cancellation_cases := ["focus", "modal", "battle", "round", "turn", "active_stack", "session", "tree"]
	for cancellation_case in cancellation_cases:
		if not await _assert_staged_context_cancellation(width, String(cancellation_case)):
			shell.queue_free()
			return false

	shell.queue_free()
	await get_tree().process_frame
	return true

func _assert_staged_context_cancellation(width: int, cancellation_case: String) -> bool:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		return _fail_bool("Battle semantic cancellation fixture %s has no encounter." % cancellation_case)
	session.battle = BattleRules.create_battle_payload(session, encounter)
	var guard := 0
	while String(BattleRules.get_active_stack(session.battle).get("side", "")) != "player" and guard < 8:
		BattleRules.advance_turn(session.battle)
		guard += 1
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var board: Control = shell.get_node("%BattleBoard")
	var live: Label = shell.get_node("%BattleBoardCursorLive")
	var timer: Timer = board.get("_battle_board_cursor_semantic_timer")
	board.grab_focus()
	await _settle()
	var summary: Dictionary = board.call("validation_hex_layout_summary")
	var cursor := Vector2i(int(summary.get("controller_cursor_q", -1)), int(summary.get("controller_cursor_r", -1)))
	var direction := Vector2i.RIGHT if cursor.x < int(summary.get("columns", 0)) - 1 else Vector2i.LEFT
	await _send_direction(direction, width % 2 == 0)
	var staged: Dictionary = (board.get("_battle_board_cursor_semantic_pending") as Dictionary).duplicate(true)
	if String(staged.get("kind", "")) != "context" or timer.is_stopped() or live.text != "":
		shell.queue_free()
		return _fail_bool("Battle semantic cancellation %s did not establish a real staged context: %s." % [cancellation_case, _pending_compact(staged)])
	match cancellation_case:
		"focus":
			var focus_target := _first_enabled_shell_button(shell)
			if focus_target == null:
				shell.queue_free()
				return _fail_bool("Battle semantic focus cancellation has no enabled shell command.")
			focus_target.grab_focus()
		"modal":
			var dialog := shell.get_node("QuickResolveConfirmationDialog") as ConfirmationDialog
			dialog.popup_centered()
		"battle":
			session.battle["encounter_id"] = "%s-stale" % String(session.battle.get("encounter_id", "battle"))
		"round":
			session.battle["round"] = int(session.battle.get("round", 0)) + 1
		"turn":
			session.battle["turn_index"] = int(session.battle.get("turn_index", 0)) + 1
		"active_stack":
			var stacks: Array = session.battle.get("stacks", []) if session.battle.get("stacks", []) is Array else []
			for stack_value in stacks:
				if stack_value is Dictionary and String(stack_value.get("battle_id", "")) != String(session.battle.get("active_stack_id", "")):
					session.battle["active_stack_id"] = String(stack_value.get("battle_id", ""))
					break
		"session":
			var replacement = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
			replacement.battle = BattleRules.create_battle_payload(replacement, _first_encounter(replacement))
			board.call("set_battle_state", replacement)
		"tree":
			var board_parent := board.get_parent()
			board_parent.remove_child(board)
	var cancellation_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - cancellation_started <= 1000 and not timer.is_stopped():
		await get_tree().process_frame
	var detached_from_tree_exact := cancellation_case != "tree" or not board.is_inside_tree()
	if not detached_from_tree_exact or not timer.is_stopped() or not (board.get("_battle_board_cursor_semantic_pending") as Dictionary).is_empty() or live.text != "":
		var failure_inside_tree := board.is_inside_tree()
		var failure_pending := _pending_compact(board.get("_battle_board_cursor_semantic_pending"))
		var failure_text := live.text
		var failure_timer_stopped := timer.is_stopped()
		if cancellation_case == "tree" and not board.is_inside_tree():
			board.free()
		shell.queue_free()
		return _fail_bool("Battle semantic cancellation %s retained tree/pending/text/timer: inside=%s pending=%s text=%s stopped=%s." % [cancellation_case, failure_inside_tree, failure_pending, failure_text, failure_timer_stopped])
	if cancellation_case == "tree":
		board.free()
	shell.queue_free()
	await get_tree().process_frame
	return true

func _expected_semantic_context(board: Control, session, summary: Dictionary) -> String:
	var cell := Vector2i(int(summary.get("controller_cursor_q", -1)), int(summary.get("controller_cursor_r", -1)))
	var role := String(summary.get("controller_cursor_cell_role", "")).replace("_", " ")
	var battle_id := String(summary.get("controller_cursor_battle_id", ""))
	var active_stack: Dictionary = BattleRules.get_active_stack(session.battle)
	var active_side := String(active_stack.get("side", ""))
	var detail := ""
	var action := "check this hex"
	if battle_id != "":
		var stack := _stack_by_battle_id(session.battle, battle_id)
		var stack_row := _summary_stack(summary, battle_id)
		var active_prefix := "active " if battle_id == String(session.battle.get("active_stack_id", "")) else ""
		detail = "%s%s stack %s, %d units. %s" % [
			active_prefix,
			String(stack.get("side", "unknown")),
			_bounded_text(String(stack.get("name", stack.get("unit_id", "Stack"))), 48),
			int(stack_row.get("alive_count", 0)),
			String(board.call("_stack_board_tooltip", battle_id)),
		]
		if active_side == "player" and String(stack.get("side", "")) == "enemy":
			var attack_intent := BattleRules.board_click_attack_intent_for_target(session.battle, battle_id)
			var action_label := String(attack_intent.get("label", "")).strip_edges()
			action = action_label if action_label != "" else "select this target"
	else:
		var movement_intent := BattleRules.movement_intent_for_destination(session.battle, cell.x, cell.y)
		detail = String(movement_intent.get("message", board.call("_movement_board_tooltip", cell)))
		action = "move here" if bool(movement_intent.get("movable", false)) else "check this blocked hex"
	if active_side != "player":
		action = "unavailable while input is locked"
	return _bounded_text(
		"Hex %d,%d; %s. %s A/Enter: %s. B/Escape: return to battle commands." % [
			cell.x,
			cell.y,
			role,
			_bounded_text(detail, 150),
			_bounded_text(action, 44),
		],
		320
	)

func _wait_for_semantic_context(board: Control, live: Label, timer: Timer) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started <= 1000 and live.text == "":
		await get_tree().process_frame
	return live.text != "" and timer.is_stopped() and (board.get("_battle_board_cursor_semantic_pending") as Dictionary).is_empty()

func _exact_result_pending(board: Control, live: Label, timer: Timer, expected_text: String) -> bool:
	var pending: Dictionary = board.get("_battle_board_cursor_semantic_pending")
	return (
		live.text == expected_text
		and live.text.length() <= 320
		and String(pending.get("kind", "")) == "result_clear"
		and int(pending.get("generation", -1)) == int(board.get("_battle_board_cursor_semantic_generation"))
		and is_same(pending.get("label_ref"), live)
		and String(pending.get("label_text", "")) == live.text
		and not timer.is_stopped()
		and is_equal_approx(timer.wait_time, RESULT_VISIBLE_SECONDS)
	)

func _wait_for_result_clear(board: Control, live: Label, timer: Timer) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started <= 1800 and (live.text != "" or not timer.is_stopped()):
		await get_tree().process_frame
	return live.text == "" and timer.is_stopped() and (board.get("_battle_board_cursor_semantic_pending") as Dictionary).is_empty()

func _move_cursor_to(board: Control, target: Vector2i, use_key: bool) -> bool:
	var summary: Dictionary = board.call("validation_hex_layout_summary")
	var cursor := Vector2i(int(summary.get("controller_cursor_q", -1)), int(summary.get("controller_cursor_r", -1)))
	if cursor == target:
		var detour := Vector2i.RIGHT if cursor.x < int(summary.get("columns", 0)) - 1 else Vector2i.LEFT
		await _send_direction(detour, use_key)
		cursor += detour
	while cursor.x != target.x:
		var direction := Vector2i.RIGHT if cursor.x < target.x else Vector2i.LEFT
		await _send_direction(direction, use_key)
		cursor += direction
	while cursor.y != target.y:
		var direction := Vector2i.DOWN if cursor.y < target.y else Vector2i.UP
		await _send_direction(direction, use_key)
		cursor += direction
	var after: Dictionary = board.call("validation_hex_layout_summary")
	return Vector2i(int(after.get("controller_cursor_q", -1)), int(after.get("controller_cursor_r", -1))) == target

func _send_direction(direction: Vector2i, use_key: bool) -> void:
	if use_key:
		var key_event := InputEventKey.new()
		key_event.keycode = _key_for_direction(direction)
		key_event.physical_keycode = key_event.keycode
		key_event.pressed = true
		Input.parse_input_event(key_event)
		var key_release := key_event.duplicate() as InputEventKey
		key_release.pressed = false
		Input.parse_input_event(key_release)
	else:
		var button := _button_for_direction(direction)
		var pressed := InputEventJoypadButton.new()
		pressed.button_index = button
		pressed.pressed = true
		Input.parse_input_event(pressed)
		var released := InputEventJoypadButton.new()
		released.button_index = button
		released.pressed = false
		Input.parse_input_event(released)
	await get_tree().process_frame

func _emit_direction_sync(direction: Vector2i, use_key: bool) -> void:
	if use_key:
		var pressed := InputEventKey.new()
		pressed.keycode = _key_for_direction(direction)
		pressed.physical_keycode = pressed.keycode
		pressed.pressed = true
		Input.parse_input_event(pressed)
		var released := pressed.duplicate() as InputEventKey
		released.pressed = false
		Input.parse_input_event(released)
	else:
		_emit_joypad_tap_sync(_button_for_direction(direction))

func _emit_joypad_tap_sync(button_index: int) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.button_index = button_index
	pressed.pressed = true
	Input.parse_input_event(pressed)
	var released := InputEventJoypadButton.new()
	released.button_index = button_index
	released.pressed = false
	Input.parse_input_event(released)

func _key_for_direction(direction: Vector2i) -> Key:
	if direction == Vector2i.LEFT:
		return KEY_LEFT
	if direction == Vector2i.RIGHT:
		return KEY_RIGHT
	if direction == Vector2i.UP:
		return KEY_UP
	return KEY_DOWN

func _button_for_direction(direction: Vector2i) -> int:
	if direction == Vector2i.LEFT:
		return JOY_BUTTON_DPAD_LEFT
	if direction == Vector2i.RIGHT:
		return JOY_BUTTON_DPAD_RIGHT
	if direction == Vector2i.UP:
		return JOY_BUTTON_DPAD_UP
	return JOY_BUTTON_DPAD_DOWN

func _active_stack_cell(summary: Dictionary) -> Vector2i:
	for entry_value in summary.get("stack_cells", []):
		if entry_value is Dictionary and bool(entry_value.get("active", false)):
			return Vector2i(int(entry_value.get("q", -1)), int(entry_value.get("r", -1)))
	return Vector2i(-1, -1)

func _first_stack_cell(summary: Dictionary, side: String, excluded_id: String) -> Vector2i:
	for entry_value in summary.get("stack_cells", []):
		if entry_value is Dictionary and String(entry_value.get("side", "")) == side and String(entry_value.get("battle_id", "")) != excluded_id:
			return Vector2i(int(entry_value.get("q", -1)), int(entry_value.get("r", -1)))
	return Vector2i(-1, -1)

func _first_blocked_enemy_cell(summary: Dictionary) -> Vector2i:
	for entry_value in summary.get("stack_cells", []):
		if entry_value is Dictionary and String(entry_value.get("side", "")) == "enemy" and not bool(entry_value.get("legal_attack_target", false)):
			return Vector2i(int(entry_value.get("q", -1)), int(entry_value.get("r", -1)))
	return Vector2i(-1, -1)

func _first_legal_destination(summary: Dictionary) -> Vector2i:
	for destination_value in summary.get("legal_destinations", []):
		if destination_value is Dictionary:
			return Vector2i(int(destination_value.get("q", -1)), int(destination_value.get("r", -1)))
	return Vector2i(-1, -1)

func _first_blocked_empty_cell(summary: Dictionary) -> Vector2i:
	var occupied := {}
	for entry_value in summary.get("stack_cells", []):
		if entry_value is Dictionary:
			occupied[_cell_key(Vector2i(int(entry_value.get("q", -1)), int(entry_value.get("r", -1))))] = true
	var legal := {}
	for destination_value in summary.get("legal_destinations", []):
		if destination_value is Dictionary:
			legal[_cell_key(Vector2i(int(destination_value.get("q", -1)), int(destination_value.get("r", -1))))] = true
	for r in range(int(summary.get("rows", 0))):
		for q in range(int(summary.get("columns", 0))):
			var cell_key := _cell_key(Vector2i(q, r))
			if not occupied.has(cell_key) and not legal.has(cell_key):
				return Vector2i(q, r)
	return Vector2i(-1, -1)

func _summary_stack(summary: Dictionary, battle_id: String) -> Dictionary:
	for entry_value in summary.get("stack_cells", []):
		if entry_value is Dictionary and String(entry_value.get("battle_id", "")) == battle_id:
			return (entry_value as Dictionary).duplicate(true)
	return {}

func _stack_by_battle_id(battle: Dictionary, battle_id: String) -> Dictionary:
	for stack_value in battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("battle_id", "")) == battle_id:
			return stack_value
	return {}

func _validate_battle_status_native_ellipsis(shell: Control, session, width: int, expect_overflow: bool) -> bool:
	var authority_before := _battle_background_authority(session)
	var header: Label = shell.get_node("%Header")
	var status: Label = shell.get_node("%Status")
	var pressure: Label = shell.get_node("%Pressure")
	var top_bar: Control = status.get_parent()
	var expected_full := BattleRules.describe_status(session)
	var font := status.get_theme_font("font")
	var font_size := status.get_theme_font_size("font_size")
	var full_width := font.get_string_size(expected_full, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x if font != null else 0.0
	var top_rect := top_bar.get_global_rect()
	var header_rect := header.get_global_rect()
	var status_rect := status.get_global_rect()
	var pressure_rect := pressure.get_global_rect()
	if expected_full == "" \
			or not expected_full.contains("Round ") \
			or not expected_full.contains(" | Terrain ") \
			or not expected_full.contains(" | Active ") \
			or status.text != expected_full \
			or status.tooltip_text != expected_full \
			or status.text.ends_with("...") \
			or not status.clip_text \
			or status.text_overrun_behavior != TextServer.OVERRUN_TRIM_WORD_ELLIPSIS \
			or status.autowrap_mode != TextServer.AUTOWRAP_OFF \
			or font == null \
			or (full_width > status.size.x + 0.5) != expect_overflow \
			or not top_rect.encloses(header_rect) \
			or not top_rect.encloses(status_rect) \
			or not top_rect.encloses(pressure_rect) \
			or header_rect.end.x > status_rect.position.x + 0.5 \
			or status_rect.end.x > pressure_rect.position.x + 0.5 \
			or header_rect.intersects(status_rect) \
			or status_rect.intersects(pressure_rect):
		return _fail_bool("Battle status did not preserve the exact full value behind native responsive pixel fit inside the authored TopBar at %d: expected=%s overflow=%s text=%s tooltip=%s full_width=%s status_rect=%s header=%s pressure=%s top=%s overrun=%s." % [width, expected_full, expect_overflow, status.text, status.tooltip_text, full_width, status_rect, header_rect, pressure_rect, top_rect, status.text_overrun_behavior])
	if _battle_background_authority(session) != authority_before:
		return _fail_bool("Inspecting Battle status native ellipsis changed session/save/settings authority at %d." % width)
	return true

func _validate_board_footer_pixel_ellipsis(board: Control, session, width: int, expect_cursor: bool) -> bool:
	if not board.has_method("validation_footer_summary") or not board.has_method("validation_footer_fit_summary"):
		return _fail_bool("Battle board footer does not expose pixel-fit validation at %d." % width)
	var authority_before := _battle_background_authority(session)
	var board_summary: Dictionary = board.call("validation_hex_layout_summary")
	var footer: Dictionary = board.call("validation_footer_summary")
	var expected_full := "%s | R%d/%d | %s | %s" % [
		String(session.battle.get("encounter_name", "Battle")),
		int(session.battle.get("round", 1)),
		int(session.battle.get("max_rounds", 12)),
		String(session.battle.get("terrain", "plains")).capitalize(),
		_footer_distance_label_for_test(int(session.battle.get("distance", 1))),
	]
	var target_state := String(board_summary.get("selected_target_footer_label", ""))
	if target_state != "":
		expected_full = "%s | %s" % [expected_full, target_state]
	var movement_state := ""
	if String(board_summary.get("active_movement_board_click_action", "")) == "move":
		movement_state = "Move: choose destination" if bool(board_summary.get("selected_target_blocked", false)) else "Move: available"
	elif bool(board_summary.get("active_movement_board_click_intent", {}).get("blocked", false)) and bool(board_summary.get("selected_target_blocked", false)):
		movement_state = "Move: unavailable"
	if movement_state != "":
		expected_full = "%s | %s" % [expected_full, movement_state]
	var cursor_state := ""
	if bool(board_summary.get("controller_board_focused", false)):
		var cursor_battle_id := String(board_summary.get("controller_cursor_battle_id", ""))
		if cursor_battle_id != "":
			var cursor_stack := _stack_by_battle_id(session.battle, cursor_battle_id)
			cursor_state = "Cursor: %s" % String(cursor_stack.get("name", cursor_stack.get("unit_id", "Stack"))).left(13)
		else:
			cursor_state = "Cursor: %d,%d %s" % [
				int(board_summary.get("controller_cursor_q", -1)),
				int(board_summary.get("controller_cursor_r", -1)),
				"move" if bool(board_summary.get("controller_cursor_legal_destination", false)) else "blocked",
			]
	if cursor_state != "":
		expected_full = "%s | %s" % [expected_full, cursor_state]
	var visible_text := String(footer.get("visible_text", ""))
	var visible_prefix := visible_text.trim_suffix("…")
	var next_character := expected_full.substr(visible_prefix.length(), 1)
	if String(footer.get("full_text", "")) != expected_full \
			or target_state == "" \
			or movement_state == "" \
			or (cursor_state != "") != expect_cursor \
			or not bool(footer.get("footer_contained", false)) \
			or not bool(footer.get("fits", false)) \
			or float(footer.get("visible_width", INF)) > float(footer.get("max_text_width", 0.0)) + 0.01:
		return _fail_bool("Battle board footer did not preserve the full summary and render a word-safe pixel ellipsis at %d: expected=%s footer=%s board=%s." % [width, expected_full, footer, board_summary])
	if expect_cursor:
		if not bool(footer.get("truncated", false)) \
				or not visible_text.ends_with("…") \
				or visible_text.ends_with("choos") \
				or not expected_full.begins_with(visible_prefix) \
				or next_character != " ":
			return _fail_bool("Focused Battle board footer did not render its long cursor summary at a word-safe ellipsis at %d: expected=%s footer=%s." % [width, expected_full, footer])
	elif bool(footer.get("truncated", true)) or visible_text != expected_full or visible_text.ends_with("…"):
		return _fail_bool("Unfocused Battle board footer changed a fitting full summary at %d: expected=%s footer=%s." % [width, expected_full, footer])
	var short_text := "Battle | R1/1 | Grass | Engaged"
	var short_control: Dictionary = board.call("validation_footer_fit_summary", short_text)
	if String(short_control.get("full_text", "")) != short_text \
			or String(short_control.get("visible_text", "")) != short_text \
			or not bool(short_control.get("fits", false)) \
			or bool(short_control.get("truncated", true)) \
			or float(short_control.get("visible_width", INF)) > float(short_control.get("max_text_width", 0.0)) + 0.01:
		return _fail_bool("Battle board footer changed a short fitting control at %d: %s." % [width, short_control])
	if _battle_background_authority(session) != authority_before:
		return _fail_bool("Inspecting Battle board footer pixel fit changed session/save/settings authority at %d." % width)
	return true

func _footer_distance_label_for_test(distance: int) -> String:
	match clampi(distance, 0, 2):
		0:
			return "Engaged"
		1:
			return "Closing"
		_:
			return "Long lane"

func _validate_turn_strip_identity_surface(board: Control, session, width: int) -> bool:
	if not board.has_method("validation_turn_strip_identity_surface"):
		return _fail_bool("Battle board does not expose the initiative-strip identity surface at %d." % width)
	var authority_before := _battle_background_authority(session)
	var surface: Dictionary = board.call("validation_turn_strip_identity_surface")
	var rows: Array = surface.get("rows", []) if surface.get("rows", []) is Array else []
	var expected_ids: Array[String] = []
	var turn_order: Array = session.battle.get("turn_order", []) if session.battle.get("turn_order", []) is Array else []
	for battle_id_value in turn_order:
		if expected_ids.size() >= 5:
			break
		var stack := _stack_by_battle_id(session.battle, String(battle_id_value))
		if stack.is_empty() or _stack_alive_count_for_test(stack) <= 0:
			continue
		expected_ids.append(String(stack.get("battle_id", "")))
	if expected_ids.is_empty() or rows.size() != expected_ids.size() or int(surface.get("visible_count", 0)) != expected_ids.size() or int(surface.get("visible_cap", 0)) != 5:
		return _fail_bool("Battle initiative strip did not expose the exact visible live turn-order count at %d: expected=%s surface=%s." % [width, expected_ids, surface])
	var field_rect: Rect2 = surface.get("field_rect", Rect2())
	var previous_rect := Rect2()
	for index in range(rows.size()):
		var row: Dictionary = rows[index] if rows[index] is Dictionary else {}
		var stack := _stack_by_battle_id(session.battle, expected_ids[index])
		var full_name := String(stack.get("name", stack.get("unit_id", "Stack"))).strip_edges()
		if full_name == "":
			full_name = "Stack"
		var alive_count := _stack_alive_count_for_test(stack)
		var side := String(stack.get("side", ""))
		var current := expected_ids[index] == String(session.battle.get("active_stack_id", ""))
		var expected_tooltip := "Initiative Strip\n- Visible slot: %d of %d\n- Stack: %s x%d\n- Side: %s\n- State: %s\n- Inspection: hovering this chip does not advance initiative or spend an action." % [
			index + 1,
			rows.size(),
			full_name,
			alive_count,
			side.capitalize(),
			"current stack" if current else "queued stack",
		]
		var visible_label := String(row.get("visible_label", ""))
		var initials_label := "%s x%d" % [_stack_initials_for_test(full_name), alive_count]
		var rect: Rect2 = row.get("rect", Rect2())
		if (
			int(row.get("slot", 0)) != index + 1
			or String(row.get("battle_id", "")) != expected_ids[index]
			or String(row.get("full_name", "")) != full_name
			or int(row.get("alive_count", -1)) != alive_count
			or String(row.get("side", "")) != side
			or bool(row.get("current", not current)) != current
			or String(row.get("tooltip", "")) != expected_tooltip
			or visible_label == initials_label
			or not visible_label.begins_with(full_name.left(3))
			or not visible_label.ends_with(" x%d" % alive_count)
			or float(row.get("visible_label_width", INF)) > float(row.get("visible_label_max_width", 0.0)) + 0.01
			or rect.size.x <= 0.0
			or rect.size.y <= 0.0
			or not field_rect.encloses(rect)
			or (index > 0 and previous_rect.intersects(rect))
		):
			return _fail_bool("Battle initiative chip identity/geometry mismatch at %d row %d: expected=%s row=%s field=%s previous=%s." % [width, index, expected_tooltip, row, field_rect, previous_rect])
		previous_rect = rect
	if _battle_background_authority(session) != authority_before:
		return _fail_bool("Inspecting Battle initiative-strip identity changed session/save/settings authority at %d." % width)
	return true

func _validate_order_tab_compact_summary(shell: Control, session, width: int) -> bool:
	var authority_before := _battle_background_authority(session)
	var initiative_label: Label = shell.get_node("%Initiative")
	var initiative_panel: PanelContainer = shell.get_node("%InitiativePanel")
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var handoff: Dictionary = snapshot.get("initiative_handoff", {}) if snapshot.get("initiative_handoff", {}) is Dictionary else {}
	var expected_handoff := _expected_initiative_handoff_for_test(session)
	var expected_visible := "Initiative cue:\nNow: %s\nNext: %s" % [
		_short_text_for_test(String(expected_handoff.get("current_stack", "")), 18),
		_short_text_for_test(String(expected_handoff.get("next_stack", "")), 18),
	]
	var full_track := BattleRules.describe_initiative_track(session)
	var expected_tooltip := "%s\n\n%s" % [String(expected_handoff.get("tooltip_text", "")), full_track]
	var visible_lines := initiative_label.text.split("\n", false)
	var font := initiative_label.get_theme_font("font")
	var font_size := initiative_label.get_theme_font_size("font_size")
	var widest_line := 0.0
	for line_value in visible_lines:
		widest_line = maxf(widest_line, font.get_string_size(String(line_value), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	if (
		handoff != expected_handoff
		or initiative_label.text != expected_visible
		or String(snapshot.get("initiative_visible_text", "")) != expected_visible
		or initiative_label.tooltip_text != expected_tooltip
		or visible_lines.size() != 3
		or initiative_label.get_line_count() != 3
		or widest_line > initiative_label.size.x + 0.5
		or not initiative_panel.get_global_rect().encloses(initiative_label.get_global_rect())
		or initiative_label.text.contains(" | Init ")
		or initiative_label.text.contains(" | HP ")
		or not initiative_label.tooltip_text.contains(" | Init ")
		or not initiative_label.tooltip_text.contains(" | HP ")
	):
		return _fail_bool("Battle Order-tab compact initiative summary mismatch at %d: visible=%s expected=%s width=%s/%s lines=%s/%s tooltip=%s expected_tooltip=%s handoff=%s expected_handoff=%s label_rect=%s panel_rect=%s." % [width, initiative_label.text, expected_visible, widest_line, initiative_label.size.x, visible_lines.size(), initiative_label.get_line_count(), initiative_label.tooltip_text, expected_tooltip, handoff, expected_handoff, initiative_label.get_global_rect(), initiative_panel.get_global_rect()])
	if _battle_background_authority(session) != authority_before:
		return _fail_bool("Inspecting the Battle Order-tab compact summary changed session/save/settings authority at %d." % width)
	return true

func _validate_battle_info_tab_header_fit(shell: Control, session, width: int) -> bool:
	var authority_before := _battle_background_authority(session)
	var battle_tabs: TabContainer = shell.get_node("%BattleTabs")
	var tab_bar: TabBar = battle_tabs.get_tab_bar()
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var readiness: Dictionary = snapshot.get("battle_tab_readiness", {}) if snapshot.get("battle_tab_readiness", {}) is Dictionary else {}
	var semantic_tabs: Array = readiness.get("tabs", []) if readiness.get("tabs", []) is Array else []
	var expected_visible_titles := ["Order", "Focus", "Spell", "Timing"]
	var expected_semantic_titles := ["Order", "Focus", "Spells", "Timing"]
	var actual_titles: Array = snapshot.get("battle_tab_titles", []) if snapshot.get("battle_tab_titles", []) is Array else []
	var bar_rect := Rect2(Vector2.ZERO, tab_bar.size)
	var previous_right := 0.0
	var total_width := 0.0
	var geometry_exact := actual_titles == expected_visible_titles and semantic_tabs.size() == expected_semantic_titles.size()
	var semantic_exact := semantic_tabs.size() == expected_semantic_titles.size()
	for index in range(expected_visible_titles.size()):
		var rect := tab_bar.get_tab_rect(index)
		geometry_exact = geometry_exact \
			and rect.size.x > 0.0 \
			and rect.size.y > 0.0 \
			and bar_rect.encloses(rect) \
			and rect.position.x + 0.01 >= previous_right
		previous_right = rect.end.x
		total_width += rect.size.x
		if index < semantic_tabs.size() and semantic_tabs[index] is Dictionary:
			var semantic: Dictionary = semantic_tabs[index]
			var ready_count := int(semantic.get("ready_count", -1))
			var semantic_title := String(semantic.get("title", ""))
			var summary := String(semantic.get("summary", ""))
			semantic_exact = semantic_exact \
				and String(semantic.get("base_title", "")) == expected_semantic_titles[index] \
				and ready_count >= 0 \
				and (ready_count <= 0 or semantic_title == "%s %d" % [expected_semantic_titles[index], ready_count]) \
				and String(battle_tabs.tooltip_text).contains(summary)
		else:
			semantic_exact = false
	geometry_exact = geometry_exact and total_width <= tab_bar.size.x + 0.01 and previous_right <= tab_bar.size.x + 0.01
	var selected: Dictionary = readiness.get("selected_tab", {}) if readiness.get("selected_tab", {}) is Dictionary else {}
	semantic_exact = semantic_exact \
		and String(selected.get("base_title", "")) == expected_semantic_titles[battle_tabs.current_tab] \
		and String(battle_tabs.tooltip_text).contains("Selected: %s" % String(selected.get("focus", "")))
	if not geometry_exact or not semantic_exact:
		var rows: Array = []
		for index in range(battle_tabs.get_tab_count()):
			rows.append({"title": battle_tabs.get_tab_title(index), "rect": tab_bar.get_tab_rect(index)})
		return _fail_bool("Battle info-tab header fit/semantics mismatch at %d: rows=%s bar=%s total=%s geometry=%s semantic=%s readiness=%s tooltip=%s." % [width, rows, tab_bar.size, total_width, geometry_exact, semantic_exact, readiness, battle_tabs.tooltip_text])
	if _battle_background_authority(session) != authority_before:
		return _fail_bool("Inspecting the Battle info-tab compact header changed session/save/settings authority at %d." % width)
	return true

func _validate_battle_focus_spell_tab_body_fit(shell: Control, session, width: int) -> bool:
	var authority_before := _battle_background_authority(session)
	var tabs: TabContainer = shell.get_node("%BattleTabs")
	var footer: Control = shell.get_node("%Footer")
	var commander_labels: Array[Label] = [shell.get_node("%PlayerCommand"), shell.get_node("%EnemyCommand")]
	var commander_full_values := [
		BattleRules.describe_commander_summary(session, "player"),
		BattleRules.describe_commander_summary(session, "enemy"),
	]
	for index in range(commander_labels.size()):
		var commander_label := commander_labels[index]
		var commander_full := String(commander_full_values[index])
		var expected_commander_visible := _commander_visible_surface_for_test(commander_full)
		if commander_label.text != expected_commander_visible \
			or commander_label.tooltip_text != commander_full \
			or commander_label.autowrap_mode != TextServer.AUTOWRAP_OFF \
			or not commander_label.clip_text \
			or commander_label.text_overrun_behavior != TextServer.OVERRUN_TRIM_WORD_ELLIPSIS \
			or commander_label.get_line_count() != 2 \
			or commander_label.get_visible_line_count() != 2:
			return _fail_bool("Battle commander compact summary mismatch at %d percent scale for %s: text=%s expected=%s tooltip=%s expected_tooltip=%s wrap=%s clip=%s overrun=%s lines=%s/%s." % [SettingsService.ui_scale_percent(), commander_label.name, commander_label.text, expected_commander_visible, commander_label.tooltip_text, commander_full, commander_label.autowrap_mode, commander_label.clip_text, commander_label.text_overrun_behavior, commander_label.get_line_count(), commander_label.get_visible_line_count()])
	var system_actions: HBoxContainer = shell.get_node("%SaveSlot").get_parent()
	var system_controls: Array[Control] = [shell.get_node("%SaveSlot"), shell.get_node("%Save"), shell.get_node("%Settings"), shell.get_node("%Menu")]
	var system_actions_rect := system_actions.get_global_rect()
	var previous_system_right := system_actions_rect.position.x
	for control in system_controls:
		var control_rect := control.get_global_rect()
		if control.get_parent() != system_actions \
			or not system_actions_rect.encloses(control_rect) \
			or control_rect.position.x + 0.01 < previous_system_right:
			return _fail_bool("Battle system action row containment/order mismatch at %d percent scale: row=%s control=%s rect=%s previous_right=%s." % [SettingsService.ui_scale_percent(), system_actions_rect, control.name, control_rect, previous_system_right])
		previous_system_right = control_rect.end.x
	var initial_tab := tabs.current_tab
	tabs.current_tab = 0
	await _settle()
	var contained_tabs_height := tabs.size.y
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var stack_check: Dictionary = snapshot.get("stack_check", {}) if snapshot.get("stack_check", {}) is Dictionary else {}
	var engagement_check: Dictionary = snapshot.get("engagement_check", {}) if snapshot.get("engagement_check", {}) is Dictionary else {}
	var status_check: Dictionary = snapshot.get("status_check", {}) if snapshot.get("status_check", {}) is Dictionary else {}
	var active_stack := BattleRules.get_active_stack(session.battle)
	var target_stack := BattleRules.get_selected_target(session.battle)
	var spellbook_text := BattleRules.describe_spellbook(session)
	var spell_actions := BattleRules.get_spell_actions(session)
	var expected_active := _focus_visible_surface_for_test("Active", active_stack, stack_check)
	var expected_target := _focus_visible_surface_for_test("Target", target_stack, engagement_check)
	var expected_spellbook := _spellbook_visible_surface_for_test(spellbook_text, spell_actions)
	var expected_effect := _effect_visible_surface_for_test(status_check)
	var rows := [
		{
			"tab": 1,
			"panel": shell.get_node("%ContextPanel"),
			"labels": [shell.get_node("%Active"), shell.get_node("%Target")],
			"texts": [expected_active, expected_target],
			"tooltips": [
				"%s\n\n%s" % [String(stack_check.get("tooltip_text", "")), BattleRules.describe_active_context(session)],
				"%s\n\n%s" % [String(engagement_check.get("tooltip_text", "")), BattleRules.describe_target_context(session)],
			],
			"line_counts": [4, 4],
		},
		{
			"tab": 2,
			"panel": shell.get_node("%SpellPanel"),
			"labels": [shell.get_node("%Spellbook"), shell.get_node("%Effects")],
			"texts": [expected_spellbook, expected_effect],
			"tooltips": [
				spellbook_text,
				"%s\n\n%s" % [String(status_check.get("tooltip_text", "")), BattleRules.describe_effect_board(session)],
			],
			"line_counts": [3, 2],
		},
	]
	for row_value in rows:
		var row: Dictionary = row_value
		tabs.current_tab = int(row.get("tab", 0))
		await _settle()
		var panel: Control = row.get("panel")
		var labels: Array = row.get("labels", [])
		var texts: Array = row.get("texts", [])
		var tooltips: Array = row.get("tooltips", [])
		var line_counts: Array = row.get("line_counts", [])
		var geometry_exact := tabs.size.y <= contained_tabs_height + 0.01 \
			and shell.get_global_rect().encloses(footer.get_global_rect()) \
			and tabs.get_global_rect().encloses(panel.get_global_rect())
		for index in range(labels.size()):
			var label: Label = labels[index]
			var widest_line := _widest_themed_label_line_for_test(label)
			geometry_exact = geometry_exact \
				and label.text == String(texts[index]) \
				and label.tooltip_text == String(tooltips[index]) \
				and label.get_line_count() == int(line_counts[index]) \
				and label.get_visible_line_count() == int(line_counts[index]) \
				and widest_line <= label.size.x + 0.5 \
				and panel.get_global_rect().encloses(label.get_global_rect())
		if not geometry_exact:
			return _fail_bool("Battle Focus/Spell compact body overflow/semantic mismatch at %d tab %s: tabs=%s contained_height=%s panel=%s footer=%s shell=%s labels=%s expected=%s tooltips=%s expected_tooltips=%s." % [width, row.get("tab"), tabs.get_global_rect(), contained_tabs_height, panel.get_global_rect(), footer.get_global_rect(), shell.get_global_rect(), labels.map(func(label): return {"text": label.text, "tooltip": label.tooltip_text, "rect": label.get_global_rect(), "lines": label.get_line_count(), "visible_lines": label.get_visible_line_count(), "widest": _widest_themed_label_line_for_test(label)}), texts, labels.map(func(label): return label.tooltip_text), tooltips])
	tabs.current_tab = initial_tab
	await _settle()
	if _battle_background_authority(session) != authority_before:
		return _fail_bool("Inspecting the Battle Focus/Spell compact bodies changed session/save/settings authority at %d." % width)
	return true

func _validate_battle_timing_tab_body_fit(shell: Control, session, width: int) -> bool:
	var authority_before := _battle_background_authority(session)
	var tabs: TabContainer = shell.get_node("%BattleTabs")
	var panel: Control = shell.get_node("%TimingPanel")
	var timing_label: Label = shell.get_node("%Timing")
	var footer: Control = shell.get_node("%Footer")
	var initial_tab := tabs.current_tab
	tabs.current_tab = 0
	await _settle()
	var contained_tabs_height := tabs.size.y
	tabs.current_tab = 3
	await _settle()
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var timing_check: Dictionary = snapshot.get("timing_check", {}) if snapshot.get("timing_check", {}) is Dictionary else {}
	var full_board := BattleRules.describe_spell_timing_board(session)
	var expected_lines := _timing_visible_lines_for_test(timing_label, timing_check)
	var expected_visible := "\n".join(expected_lines)
	var expected_tooltip := "%s\n\n%s" % [String(timing_check.get("tooltip_text", "")), full_board]
	var widest_line := _widest_themed_label_line_for_test(timing_label)
	var geometry_exact := tabs.size.y <= contained_tabs_height + 0.01 \
		and shell.get_global_rect().encloses(footer.get_global_rect()) \
		and tabs.get_global_rect().encloses(panel.get_global_rect()) \
		and panel.get_global_rect().encloses(timing_label.get_global_rect()) \
		and timing_label.get_line_count() == 3 \
		and timing_label.get_visible_line_count() == 3 \
		and widest_line <= timing_label.size.x + 0.5
	var semantics_exact := timing_label.text == expected_visible \
		and timing_label.tooltip_text == expected_tooltip \
		and String(snapshot.get("spell_timing_text", "")) == full_board \
		and String(snapshot.get("spell_timing_visible_text", "")) == expected_visible \
		and String(snapshot.get("spell_timing_tooltip_text", "")) == expected_tooltip \
		and not timing_label.text.contains("...") \
		and not timing_label.text.contains("Spell and Ability Timing") \
		and timing_label.tooltip_text.contains("Spell and Ability Timing") \
		and timing_label.text.begins_with("Timing check: ")
	if not geometry_exact or not semantics_exact:
		return _fail_bool("Battle Timing compact body mismatch at %d: text=%s expected=%s tooltip=%s expected_tooltip=%s width=%s/%s lines=%s/%s tabs=%s contained_height=%s panel=%s label=%s footer=%s shell=%s timing=%s." % [width, timing_label.text, expected_visible, timing_label.tooltip_text, expected_tooltip, widest_line, timing_label.size.x, timing_label.get_line_count(), timing_label.get_visible_line_count(), tabs.get_global_rect(), contained_tabs_height, panel.get_global_rect(), timing_label.get_global_rect(), footer.get_global_rect(), shell.get_global_rect(), timing_check])
	tabs.current_tab = initial_tab
	await _settle()
	if _battle_background_authority(session) != authority_before:
		return _fail_bool("Inspecting the Battle Timing compact body changed session/save/settings authority at %d." % width)
	return true

func _commander_visible_surface_for_test(full_text: String) -> String:
	var lines: Array[String] = []
	for raw_line in full_text.split("\n", false):
		var line := String(raw_line).strip_edges()
		if line == "":
			continue
		if line.begins_with("- "):
			line = line.trim_prefix("- ").strip_edges()
		if line.length() > 96:
			line = "%s..." % line.left(93)
		lines.append(line)
	if lines.is_empty():
		return full_text.strip_edges()
	var first_line := lines[0]
	return "%s\n+ %d more" % [first_line, lines.size() - 1] if lines.size() > 1 else first_line

func _timing_visible_lines_for_test(label: Label, timing_check: Dictionary) -> Array[String]:
	var readiness := String(timing_check.get("readiness", "Review")).strip_edges()
	if readiness == "":
		readiness = "Review"
	var action_prefix := "Next"
	var action_value := readiness
	var ready_spell := String(timing_check.get("ready_spell", "")).strip_edges()
	var ready_order := String(timing_check.get("ready_order", "")).strip_edges()
	if ready_spell != "":
		action_prefix = "Cast"
		action_value = ready_spell.trim_prefix("Cast ").strip_edges()
	elif ready_order != "":
		action_prefix = "Order"
		action_value = ready_order
	var watch_value := _timing_clause_for_test(String(timing_check.get("burst_risk", "")))
	if watch_value == "" or watch_value.to_lower().contains("unavailable"):
		watch_value = _timing_clause_for_test(String(timing_check.get("protection_need", "")))
	if watch_value == "":
		watch_value = _timing_clause_for_test(String(timing_check.get("enemy_pressure", "")))
	if watch_value == "":
		watch_value = "review full detail"
	return [
		_fit_themed_timing_line_for_test(label, "Timing check: %s" % readiness),
		_fit_themed_timing_line_for_test(label, "%s: %s" % [action_prefix, action_value]),
		_fit_themed_timing_line_for_test(label, "Watch: %s" % watch_value),
	]

func _timing_clause_for_test(value: String) -> String:
	var clause := value.strip_edges()
	for prefix in ["Burst risk:", "Incoming burst:", "Protection need:", "Enemy spell pressure:"]:
		if clause.begins_with(prefix):
			clause = clause.trim_prefix(prefix).strip_edges()
			break
	if clause.contains(" | "):
		clause = clause.get_slice(" | ", 0).strip_edges()
	if clause.contains("; "):
		clause = clause.get_slice("; ", 0).strip_edges()
	if clause.contains(" is best placed to cast "):
		clause = clause.get_slice(" is best placed to cast ", 1).strip_edges()
		if clause.contains(" on "):
			clause = clause.get_slice(" on ", 0).strip_edges()
	return clause.trim_suffix(".").strip_edges()

func _fit_themed_timing_line_for_test(label: Label, value: String) -> String:
	var normalized := value.strip_edges()
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	if font.get_string_size(normalized, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= label.size.x:
		return normalized
	var prefix := ""
	for word_value in normalized.split(" ", false):
		var word := String(word_value)
		var candidate := word if prefix == "" else "%s %s" % [prefix, word]
		if font.get_string_size("%s…" % candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > label.size.x:
			break
		prefix = candidate
	return "%s…" % prefix if prefix != "" else "…"

func _focus_visible_surface_for_test(prefix: String, stack: Dictionary, cue: Dictionary) -> String:
	var cue_label := "Stack check:" if prefix == "Active" else "Engagement check:"
	if stack.is_empty():
		return "%s\n%s: none\nSide: unavailable\nState: %s" % [cue_label, prefix, String(cue.get("readiness", "Waiting"))]
	var name := String(stack.get("name", stack.get("battle_id", "stack"))).strip_edges()
	if name == "":
		name = "stack"
	var side_value := String(stack.get("side", ""))
	var side := "Player" if side_value == "player" else ("Enemy" if side_value == "enemy" else side_value.capitalize())
	var readiness := String(cue.get("readiness", "Ready")).strip_edges()
	if readiness == "":
		readiness = "Ready"
	var order := String(cue.get("order", "")).strip_edges()
	if order.contains(" ("):
		order = order.get_slice(" (", 0).strip_edges()
	var state_line := readiness if order == "" else "%s: %s" % [readiness, _short_text_for_test(order, 16)]
	return "%s\n%s: %s\n%s | x%d | HP %d\n%s" % [cue_label, prefix, _short_text_for_test(name, 14), side, max(0, int(stack.get("count", 0))), max(0, int(stack.get("total_health", 0))), state_line]

func _spellbook_visible_surface_for_test(spellbook_text: String, spell_actions: Array) -> String:
	var mana_line := "Mana 0/0"
	var lines := spellbook_text.split("\n", false)
	if not lines.is_empty():
		for part_value in String(lines[0]).split("|", false):
			var part := String(part_value).strip_edges()
			if part.begins_with("Mana "):
				mana_line = part
				break
	var ready_count := 0
	var first_ready := ""
	for action_value in spell_actions:
		if not (action_value is Dictionary) or bool(action_value.get("disabled", false)):
			continue
		ready_count += 1
		if first_ready == "":
			first_ready = String(action_value.get("label", action_value.get("id", "Spell"))).strip_edges()
	var ready_line := "Ready: none" if first_ready == "" else "Ready: %s" % _short_text_for_test(first_ready, 16)
	return "%s\n%s\nSpells: %d/%d ready" % [mana_line, ready_line, ready_count, spell_actions.size()]

func _effect_visible_surface_for_test(status_check: Dictionary) -> String:
	var readiness := String(status_check.get("readiness", "Review")).strip_edges()
	if readiness == "":
		readiness = "Review"
	var effect_count: int = max(0, int(status_check.get("effect_stack_count", 0)))
	return "Status check: %s\nEffects: %d stack%s" % [readiness, effect_count, "" if effect_count == 1 else "s"]

func _widest_themed_label_line_for_test(label: Label) -> float:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var widest := 0.0
	for line_value in label.text.split("\n", false):
		widest = maxf(widest, font.get_string_size(String(line_value), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return widest

func _expected_initiative_handoff_for_test(session) -> Dictionary:
	var battle: Dictionary = session.battle
	var active_stack: Dictionary = BattleRules.get_active_stack(battle)
	var turn_order: Array = battle.get("turn_order", []) if battle.get("turn_order", []) is Array else []
	var turn_index := clampi(int(battle.get("turn_index", 0)), 0, max(0, turn_order.size() - 1))
	var next_stack := _next_living_stack_for_test(battle, turn_order, turn_index + 1)
	var next_round := false
	if next_stack.is_empty():
		next_stack = _next_living_stack_for_test(battle, turn_order, 0)
		next_round = not next_stack.is_empty()
	var current_label := _initiative_stack_label_for_test(active_stack)
	var next_label := _initiative_stack_label_for_test(next_stack) if not next_stack.is_empty() else "no queued stack"
	var current_side := _initiative_side_label_for_test(String(active_stack.get("side", "")))
	var next_side := _initiative_side_label_for_test(String(next_stack.get("side", ""))) if not next_stack.is_empty() else "None"
	var round: int = maxi(1, int(battle.get("round", 1)))
	var next_round_label: int = round + 1 if next_round else round
	var current_window := "player command window" if String(active_stack.get("side", "")) == "player" else "enemy pressure window"
	var next_window := "next round opens" if next_round else "same round continues"
	var tooltip := "Initiative Handoff\n- Round: %d\n- Current: %s [%s]\n- Next: %s [%s], round %d\n- Handoff: %s; %s.\n- Player input: %s." % [
		round,
		current_label,
		current_side,
		next_label,
		next_side,
		next_round_label,
		current_window,
		next_window,
		"orders are open now" if String(active_stack.get("side", "")) == "player" else "wait for command to return",
	]
	return {
		"visible_text": "Initiative cue:\nNow: %s\nNext: %s" % [_short_text_for_test(current_label, 18), _short_text_for_test(next_label, 18)],
		"tooltip_text": tooltip,
		"current_stack": current_label,
		"current_side": current_side,
		"next_stack": next_label,
		"next_side": next_side,
		"round": round,
		"next_round": next_round_label,
		"handoff": "%s; %s" % [current_window, next_window],
	}

func _next_living_stack_for_test(battle: Dictionary, turn_order: Array, start_index: int) -> Dictionary:
	for index in range(maxi(0, start_index), turn_order.size()):
		var stack := _stack_by_battle_id(battle, String(turn_order[index]))
		if not stack.is_empty() and int(stack.get("count", 0)) > 0 and int(stack.get("total_health", 0)) > 0:
			return stack
	return {}

func _initiative_stack_label_for_test(stack: Dictionary) -> String:
	if stack.is_empty():
		return "no stack"
	var name := String(stack.get("name", "")).strip_edges()
	if name == "":
		name = String(stack.get("battle_id", "stack")).strip_edges()
	var count := int(stack.get("count", 0))
	var hp := int(stack.get("total_health", 0))
	return "%s x%d, %d HP" % [name, count, hp] if count > 0 and hp > 0 else name

func _initiative_side_label_for_test(side: String) -> String:
	match side:
		"player":
			return "Player"
		"enemy":
			return "Enemy"
	return "Neutral"

func _short_text_for_test(text: String, max_chars: int) -> String:
	var cleaned := text.strip_edges().trim_suffix(".").strip_edges()
	if max_chars <= 0 or cleaned.length() <= max_chars:
		return cleaned
	if max_chars <= 1:
		return cleaned.substr(0, max_chars)
	return "%s..." % cleaned.substr(0, max_chars - 1).strip_edges()

func _battle_event_word_text_control(text: String, max_chars: int) -> String:
	var normalized := text.strip_edges().replace("\n", " ")
	while normalized.contains("  "):
		normalized = normalized.replace("  ", " ")
	if max_chars <= 0:
		return ""
	if normalized.length() <= max_chars:
		return normalized
	if max_chars == 1:
		return "…"
	var prefix := normalized.left(max_chars - 1).strip_edges()
	var boundary := prefix.rfind(" ")
	if boundary <= 0:
		return "…"
	var fitted := prefix.left(boundary).strip_edges()
	var trailing_connectors := ["a", "an", "the", "to", "of", "and", "or", "for", "with", "from"]
	while fitted.contains(" ") and fitted.get_slice(" ", fitted.get_slice_count(" ") - 1).to_lower() in trailing_connectors:
		fitted = fitted.left(fitted.rfind(" ")).strip_edges()
	return "%s…" % fitted if fitted != "" else "…"

func _stack_alive_count_for_test(stack: Dictionary) -> int:
	var unit_hp: int = maxi(1, int(stack.get("unit_hp", stack.get("hp", 1))))
	var total_health: int = maxi(0, int(stack.get("total_health", 0)))
	return int(ceil(float(total_health) / float(unit_hp))) if total_health > 0 else 0

func _stack_initials_for_test(full_name: String) -> String:
	var parts := full_name.split(" ", false)
	if parts.size() <= 1:
		return full_name.left(2).to_upper()
	return ("%s%s" % [String(parts[0]).left(1), String(parts[1]).left(1)]).to_upper()

func _cell_payload(cell: Vector2i) -> Dictionary:
	return {"q": cell.x, "r": cell.y}

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _turn_signature(battle: Dictionary) -> String:
	var active := _stack_by_battle_id(battle, String(battle.get("active_stack_id", "")))
	return "%d|%d|%s|%s" % [int(battle.get("round", 0)), int(battle.get("turn_index", -1)), String(battle.get("active_stack_id", "")), String(active.get("side", ""))]

func _bounded_text(value: String, maximum_characters: int) -> String:
	var normalized := " ".join(value.replace("\r", "\n").split("\n", false)).strip_edges()
	while normalized.contains("  "):
		normalized = normalized.replace("  ", " ")
	return normalized.left(maximum_characters)

func _pending_compact(value: Variant) -> Dictionary:
	var pending: Dictionary = value if value is Dictionary else {}
	return {
		"kind": String(pending.get("kind", "")),
		"generation": int(pending.get("generation", -1)),
		"session_id": String(pending.get("session_id", "")),
		"battle_identity": String(pending.get("battle_identity", "")),
		"turn_signature": String(pending.get("turn_signature", "")),
		"cursor_cell": pending.get("cursor_cell", {}),
		"label_text": String(pending.get("label_text", "")),
	}

func _semantic_observer_snapshot(board: Control, live: Label, timer: Timer) -> Dictionary:
	return {
		"cursor": _cell_payload(Vector2i(int((board.call("validation_hex_layout_summary") as Dictionary).get("controller_cursor_q", -1)), int((board.call("validation_hex_layout_summary") as Dictionary).get("controller_cursor_r", -1)))),
		"live": live.text,
		"pending": _pending_compact(board.get("_battle_board_cursor_semantic_pending")),
		"timer_stopped": timer.is_stopped(),
		"timer_wait": timer.wait_time,
	}

func _battle_background_authority(session) -> Dictionary:
	var files := {}
	var base_paths: Array[String] = [
		"%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE],
		"%s/%s" % [SaveService.SAVE_DIR, SaveService.PROGRESSION_FILE],
		SettingsService.SETTINGS_FILE,
	]
	for slot_id in SaveService.MANUAL_SLOT_IDS:
		base_paths.append("%s/%s%d.json" % [SaveService.SAVE_DIR, SaveService.SAVE_PREFIX, int(slot_id)])
	for path in base_paths:
		files[path] = _file_state(path)
		files["%s%s" % [path, SaveService.SAVE_TRANSACTION_CANDIDATE_SUFFIX]] = _file_state("%s%s" % [path, SaveService.SAVE_TRANSACTION_CANDIDATE_SUFFIX])
		files["%s%s" % [path, SaveService.SAVE_TRANSACTION_BACKUP_SUFFIX]] = _file_state("%s%s" % [path, SaveService.SAVE_TRANSACTION_BACKUP_SUFFIX])
	files[SettingsService.SETTINGS_CANDIDATE_FILE] = _file_state(SettingsService.SETTINGS_CANDIDATE_FILE)
	files[SettingsService.SETTINGS_BACKUP_FILE] = _file_state(SettingsService.SETTINGS_BACKUP_FILE)
	return {
		"session": session.to_dict(),
		"active_session_same": is_same(SessionState.active_session, session),
		"battle": session.battle.duplicate(true),
		"rng_state": String(session.battle.get(BattleRules.DAMAGE_RNG_STATE_KEY, "")),
		"recent_events": session.battle.get("recent_events", []).duplicate(true),
		"files": files,
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
		"settings": _canonical_settings_transaction(SettingsService.validation_settings_transaction_snapshot()),
		"battle_resolution_route": AppRouter.validation_battle_resolution_checkpoint_snapshot(),
		"battle_entry_route": AppRouter.validation_battle_entry_snapshot(),
		"outcome_route": AppRouter.validation_scenario_outcome_route_snapshot(),
		"active_return_route": AppRouter.validation_active_play_return_snapshot(),
		"safe_quit_route": AppRouter.validation_safe_quit_snapshot(),
	}

func _file_state(path: String) -> Dictionary:
	var absolute := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(path):
		return {"exists": false, "path": path}
	var file := FileAccess.open(path, FileAccess.READ)
	return {"exists": true, "path": path, "bytes": file.get_buffer(file.get_length()) if file != null else PackedByteArray()}

func _canonical_settings_transaction(transaction: Dictionary) -> Dictionary:
	var canonical: Dictionary = transaction.duplicate(true)
	var canonical_input_map := {}
	var input_map: Dictionary = transaction.get("input_map", {}) if transaction.get("input_map", {}) is Dictionary else {}
	for action_value in input_map.keys():
		var action := String(action_value)
		var action_state: Dictionary = input_map.get(action_value, {}) if input_map.get(action_value, {}) is Dictionary else {}
		var canonical_events: Array = []
		var events: Array = action_state.get("events", []) if action_state.get("events", []) is Array else []
		for event_value in events:
			if event_value is InputEvent:
				canonical_events.append(_canonical_stored_input_event(event_value as InputEvent))
			else:
				canonical_events.append({"class": "", "as_text": var_to_str(event_value), "stored_properties": []})
		canonical_input_map[action] = {
			"action": action,
			"exists": bool(action_state.get("exists", false)),
			"deadzone": float(action_state.get("deadzone", 0.5)),
			"events": canonical_events,
		}
	canonical["input_map"] = canonical_input_map
	return canonical

func _canonical_stored_input_event(event: InputEvent) -> Dictionary:
	var stored_properties: Array = []
	for property_value in event.get_property_list():
		if not (property_value is Dictionary):
			continue
		var property: Dictionary = property_value
		var property_name := String(property.get("name", ""))
		var property_usage := int(property.get("usage", 0))
		if property_name == "script" or (property_usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		stored_properties.append({"name": property_name, "value": var_to_str(event.get(property_name))})
	return {"class": event.get_class(), "as_text": event.as_text(), "stored_properties": stored_properties}

func _first_enabled_shell_button(shell: Node) -> BaseButton:
	for node_value in shell.find_children("*", "BaseButton", true, false):
		var button := node_value as BaseButton
		if button.visible and not button.disabled:
			return button
	return null

func _checks_exact(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true

func _fail_bool(message: String) -> bool:
	_fail(message)
	return false

func _assert_semantic_context_at(
	shell: Node,
	board: Control,
	live: Label,
	semantic_timer: Timer,
	session,
	target: Vector2i,
	width: int,
	row_id: String,
	use_key: bool
) -> bool:
	var authority_before := _battle_background_authority(session)
	if not await _move_cursor_to(board, target, use_key):
		return _fail_bool("Battle semantic row %s could not reach %s at %d." % [row_id, target, width])
	var pending: Dictionary = (board.get("_battle_board_cursor_semantic_pending") as Dictionary).duplicate(true)
	var summary: Dictionary = board.call("validation_hex_layout_summary")
	var expected := _expected_semantic_context(board, session, summary)
	var pending_checks := {
		"live_empty_before_publish": live.text == "",
		"pending_context": String(pending.get("kind", "")) == "context",
		"pending_generation_current": int(pending.get("generation", -1)) == int(board.get("_battle_board_cursor_semantic_generation")),
		"pending_session_ref": is_same(pending.get("session_ref"), session),
		"pending_session_id": String(pending.get("session_id", "")) == String(session.session_id),
		"pending_battle_dictionary": pending.get("battle_ref") is Dictionary and not (pending.get("battle_ref") as Dictionary).is_empty(),
		"pending_battle_value_exact": pending.get("battle_ref") == session.battle,
		"pending_battle_identity": String(pending.get("battle_identity", "")) == String(session.battle.get("encounter_id", "")),
		"pending_turn_signature": String(pending.get("turn_signature", "")) == _turn_signature(session.battle),
		"pending_cell": pending.get("cursor_cell", {}) == _cell_payload(target),
		"pending_label_ref": is_same(pending.get("label_ref"), live),
		"timer_active": not semantic_timer.is_stopped(),
		"timer_wait_exact": is_equal_approx(semantic_timer.wait_time, SEMANTIC_DEBOUNCE_SECONDS),
		"authority_exact_before_publish": _battle_background_authority(session) == authority_before,
	}
	if not _checks_exact(pending_checks):
		return _fail_bool("Battle semantic row %s pending state was not exact at %d: %s pending=%s." % [row_id, width, pending_checks, _pending_compact(pending)])
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started <= 1000 and live.text == "":
		await get_tree().process_frame
	var published_checks := {
		"expected_nonempty": expected != "",
		"exact_text": live.text == expected,
		"bounded": live.text.length() <= 320,
		"exact_hex": live.text.begins_with("Hex %d,%d;" % [target.x, target.y]),
		"exact_role": live.text.contains("; %s." % String(summary.get("controller_cursor_cell_role", "")).replace("_", " ")),
		"accept_context": live.text.contains(" A/Enter: "),
		"cancel_context": live.text.ends_with(" B/Escape: return to battle commands."),
		"timer_stopped": semantic_timer.is_stopped(),
		"pending_empty": (board.get("_battle_board_cursor_semantic_pending") as Dictionary).is_empty(),
		"authority_exact_after_publish": _battle_background_authority(session) == authority_before,
	}
	if not _checks_exact(published_checks):
		return _fail_bool("Battle semantic row %s did not publish exact bounded context at %d: %s expected=%s actual=%s." % [row_id, width, published_checks, expected, live.text])
	return true

func _stack_cell(board_summary: Dictionary, battle_id: String) -> Vector2i:
	var entries: Array = board_summary.get("stack_cells", []) if board_summary.get("stack_cells", []) is Array else []
	for entry_value in entries:
		if entry_value is Dictionary and String(entry_value.get("battle_id", "")) == battle_id:
			return Vector2i(int(entry_value.get("q", -1)), int(entry_value.get("r", -1)))
	return Vector2i(-1, -1)

func _on_stack_focus_requested(battle_id: String) -> void:
	_last_dispatched_stack_id = battle_id

func _different_enemy_stack_cell(board_summary: Dictionary, excluded_battle_id: String) -> Dictionary:
	var entries: Array = board_summary.get("stack_cells", []) if board_summary.get("stack_cells", []) is Array else []
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var battle_id := String(entry_value.get("battle_id", ""))
		if (
			String(entry_value.get("side", "")) != "enemy"
			or battle_id == ""
			or battle_id == excluded_battle_id
			or bool(entry_value.get("legal_attack_target", false))
		):
			continue
		return {
			"battle_id": battle_id,
			"cell": Vector2i(int(entry_value.get("q", -1)), int(entry_value.get("r", -1))),
		}
	return {}

func _cell_in_bounds(cell: Vector2i, summary: Dictionary) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < int(summary.get("columns", 0)) and cell.y < int(summary.get("rows", 0))

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

func _on_cancel_diagnostic_gui_input(event: InputEvent, counters: Dictionary) -> void:
	if not (event is InputEventJoypadButton) or int((event as InputEventJoypadButton).button_index) != JOY_BUTTON_B:
		return
	if (event as InputEventJoypadButton).pressed:
		counters["pressed_gui_count"] = int(counters.get("pressed_gui_count", 0)) + 1
		counters["board_pressed_handled"] = get_viewport().is_input_handled()
	else:
		counters["released_gui_count"] = int(counters.get("released_gui_count", 0)) + 1
		counters["board_released_handled"] = get_viewport().is_input_handled()

func _on_cancel_diagnostic_root_window_input(event: InputEvent, counters: Dictionary) -> void:
	if not (event is InputEventJoypadButton) or int((event as InputEventJoypadButton).button_index) != JOY_BUTTON_B:
		return
	if (event as InputEventJoypadButton).pressed:
		counters["root_pressed_count"] = int(counters.get("root_pressed_count", 0)) + 1
		counters["root_pressed_handled"] = get_viewport().is_input_handled()
	else:
		counters["root_released_count"] = int(counters.get("root_released_count", 0)) + 1
		counters["root_released_handled"] = get_viewport().is_input_handled()

func _on_cancel_diagnostic_focus_exited(counters: Dictionary) -> void:
	counters["focus_exited_count"] = int(counters.get("focus_exited_count", 0)) + 1

func _on_cancel_diagnostic_navigation_cancelled(counters: Dictionary) -> void:
	counters["cancel_signal_count"] = int(counters.get("cancel_signal_count", 0)) + 1

func _matching_joypad_binding_count(action: StringName, button_index: int) -> int:
	var count := 0
	for event_value in InputMap.action_get_events(action):
		if event_value is InputEventJoypadButton and int((event_value as InputEventJoypadButton).button_index) == button_index:
			count += 1
	return count

func _root_window_input_connection_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for connection_value in get_tree().root.window_input.get_connections():
		if not (connection_value is Dictionary):
			continue
		var connection: Dictionary = connection_value
		var callable: Callable = connection.get("callable", Callable())
		var object: Object = callable.get_object()
		var node := object as Node
		rows.append({
			"object_id": object.get_instance_id() if object != null else 0,
			"path": String(node.get_path()) if node != null and node.is_inside_tree() else "",
			"class": object.get_class() if object != null else "",
			"method": String(callable.get_method()),
			"flags": int(connection.get("flags", 0)),
		})
	return rows

func _connection_row_count(rows: Array[Dictionary], object: Object, method_name: String) -> int:
	var count := 0
	for row in rows:
		if int(row.get("object_id", 0)) == object.get_instance_id() and String(row.get("method", "")) == method_name:
			count += 1
	return count

func _button_shortcut_snapshot(button: BaseButton, pressed: InputEvent, released: InputEvent) -> Dictionary:
	var shortcut := button.shortcut
	var event_rows: Array[Dictionary] = []
	if shortcut != null:
		for event_value in shortcut.events:
			var event := event_value as InputEvent
			event_rows.append({
				"class": event.get_class() if event != null else "",
				"action": String((event as InputEventAction).action) if event is InputEventAction else "",
				"button_index": int((event as InputEventJoypadButton).button_index) if event is InputEventJoypadButton else -1,
				"pressed": bool(event.get("pressed")) if event != null else false,
				"as_text": event.as_text() if event != null else "",
			})
	return {
		"path": String(button.get_path()),
		"text": button.text,
		"visible_in_tree": button.is_visible_in_tree(),
		"disabled": button.disabled,
		"shortcut_nonnull": shortcut != null,
		"matches_pressed": shortcut.matches_event(pressed) if shortcut != null else false,
		"matches_released": shortcut.matches_event(released) if shortcut != null else false,
		"events": event_rows,
	}

func _matching_shell_shortcut_rows(shell: Node, pressed: InputEvent, released: InputEvent) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for node_value in shell.find_children("*", "BaseButton", true, false):
		var button := node_value as BaseButton
		var snapshot := _button_shortcut_snapshot(button, pressed, released)
		if bool(snapshot.get("matches_pressed", false)):
			rows.append(snapshot)
	return rows

func _first_encounter(session) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and not bool(encounter.get("cleared", false)):
			return encounter
	return {}

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _capture_if_requested() -> void:
	var stem := OS.get_environment("BATTLE_CONTROLLER_BOARD_CAPTURE_STEM").strip_edges()
	if stem == "":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	var path := "%s/%s.png" % [CAPTURE_DIR, stem]
	var image := get_viewport().get_texture().get_image()
	if image == null:
		_fail("Controller-board capture renderer returned no viewport image.")
		return
	var error := image.save_png(path)
	if error != OK:
		_fail("Could not save controller-board capture %s: %s." % [path, error])

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
