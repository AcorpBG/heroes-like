extends Node

const REPORT_ID := "BATTLE_CONTROLLER_BOARD_NAVIGATION_SMOKE"
const CAPTURE_DIR := "res://.artifacts/battle_controller_board_navigation_smoke"

var _last_dispatched_stack_id := ""

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
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
	if _last_dispatched_stack_id != String(enemy_target.get("battle_id", "")):
		return _fail("Controller A did not dispatch the occupied enemy cursor cell through target selection: target=%s emitted=%s." % [enemy_target, _last_dispatched_stack_id])
	if int(session.battle.get("recent_events", []).size()) != target_events_before:
		return _fail("Blocked enemy cursor selection executed an unexpected battle action.")
	await _press_joypad_button(JOY_BUTTON_B)
	var cancel_focus := get_viewport().gui_get_focus_owner()
	if cancel_focus == null or cancel_focus == board or not shell.is_ancestor_of(cancel_focus) or (cancel_focus is BaseButton and cancel_focus.disabled):
		return _fail("Controller B did not restore a legal battle command focus: %s." % cancel_focus)

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
	await _capture_if_requested()

	var active_before := BattleRules.get_active_stack(session.battle)
	var active_battle_id := String(active_before.get("battle_id", ""))
	var events_before := int(session.battle.get("recent_events", []).size())
	await _press_joypad_button(JOY_BUTTON_A)
	await _settle()
	var post_summary: Dictionary = shell.call("validation_snapshot").get("battle_board", {})
	var moved_stack_cell := _stack_cell(post_summary, active_battle_id)
	if moved_stack_cell != destination:
		return _fail("Controller A did not dispatch the exact board destination: expected=%s actual=%s." % [destination, moved_stack_cell])
	if int(session.battle.get("recent_events", []).size()) <= events_before:
		return _fail("Controller board move did not advance the battle event stream.")
	var post_focus := get_viewport().gui_get_focus_owner()
	if post_focus == null or post_focus == board or not shell.is_ancestor_of(post_focus):
		return _fail("Controller board move did not restore command focus after refresh: %s." % post_focus)

	print("%s PASS" % REPORT_ID)
	get_tree().quit(0)

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
