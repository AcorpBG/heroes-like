extends Control

signal stack_focus_requested(battle_id: String)
signal hex_destination_requested(q: int, r: int)

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")

const HEX_COLUMNS := 11
const HEX_ROWS := 7
const SQRT_3 := 1.7320508075688772

const FRAME_FILL := Color(0.045, 0.052, 0.061, 1.0)
const BOARD_FILL := Color(0.072, 0.078, 0.070, 1.0)
const FRAME_COLOR := Color(0.82, 0.67, 0.37, 0.94)
const HEX_LINE_COLOR := Color(0.93, 0.86, 0.62, 0.28)
const HEX_CENTER_LINE := Color(0.98, 0.86, 0.55, 0.42)
const TEXT_COLOR := Color(0.96, 0.94, 0.89, 1.0)
const SUBTEXT_COLOR := Color(0.83, 0.87, 0.91, 0.95)
const PLAYER_COLOR := Color(0.42, 0.66, 0.90, 0.98)
const ENEMY_COLOR := Color(0.84, 0.38, 0.33, 0.98)
const NEUTRAL_COLOR := Color(0.68, 0.72, 0.78, 0.94)
const ACTIVE_COLOR := Color(0.99, 0.88, 0.48, 1.0)
const TARGET_COLOR := Color(0.97, 0.64, 0.38, 0.98)
const BLOCKED_TARGET_COLOR := Color(0.78, 0.20, 0.18, 0.96)
const MOVE_COLOR := Color(0.42, 0.82, 0.66, 0.76)
const LEGAL_MELEE_COLOR := Color(1.0, 0.78, 0.36, 0.90)
const LEGAL_RANGED_COLOR := Color(0.72, 0.88, 1.0, 0.82)
const HEALTH_COLOR := Color(0.95, 0.79, 0.35, 0.96)
const SHADOW_COLOR := Color(0.025, 0.028, 0.031, 0.72)
const TERRAIN_COLORS := {
	"plains": Color(0.30, 0.38, 0.24, 1.0),
	"forest": Color(0.18, 0.31, 0.22, 1.0),
	"swamp": Color(0.24, 0.29, 0.22, 1.0),
	"hills": Color(0.37, 0.32, 0.24, 1.0),
	"road": Color(0.35, 0.30, 0.24, 1.0),
	"mire": Color(0.21, 0.27, 0.22, 1.0),
}

var _session = null
var _battle: Dictionary = {}
var _player_stacks: Array = []
var _enemy_stacks: Array = []
var _active_stack: Dictionary = {}
var _target_stack: Dictionary = {}
var _field_objectives: Array = []
var _stack_hit_shapes: Array = []
var _hover_destination_cell := Vector2i(-1, -1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(620.0, 320.0)
	tooltip_text = "Green hex click moves. Highlighted enemy click attacks; blocked enemies need movement."

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		var hovered_cell := _hex_cell_at_position(motion_event.position)
		if not _is_legal_destination_cell(hovered_cell):
			hovered_cell = Vector2i(-1, -1)
		if hovered_cell != _hover_destination_cell:
			_hover_destination_cell = hovered_cell
			queue_redraw()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var battle_id := _stack_id_at_position(mouse_event.position)
	if battle_id == "":
		var destination_cell := _hex_cell_at_position(mouse_event.position)
		if destination_cell.x < 0 or not _is_legal_destination_cell(destination_cell):
			return
		hex_destination_requested.emit(destination_cell.x, destination_cell.y)
		accept_event()
		return
	stack_focus_requested.emit(battle_id)
	accept_event()

func _get_tooltip(at_position: Vector2) -> String:
	var battle_id := _stack_id_at_position(at_position)
	if battle_id != "":
		return _stack_board_tooltip(battle_id)
	var destination_cell := _hex_cell_at_position(at_position)
	if _is_legal_destination_cell(destination_cell):
		var movement_intent := BattleRulesScript.movement_intent_for_destination(_battle, destination_cell.x, destination_cell.y)
		var message := String(movement_intent.get("message", ""))
		if message != "":
			return message
	return tooltip_text

func set_battle_state(session) -> void:
	_session = session
	_battle = {}
	_player_stacks = []
	_enemy_stacks = []
	_active_stack = {}
	_target_stack = {}
	_field_objectives = []
	_stack_hit_shapes = []
	if not _is_legal_destination_cell(_hover_destination_cell):
		_hover_destination_cell = Vector2i(-1, -1)
	if session != null and session.battle is Dictionary:
		_battle = session.battle
		_active_stack = BattleRulesScript.get_active_stack(_battle)
		_target_stack = BattleRulesScript.get_selected_target(_battle)
		_field_objectives = _battle.get(BattleRulesScript.FIELD_OBJECTIVES_KEY, []).duplicate(true) if _battle.get(BattleRulesScript.FIELD_OBJECTIVES_KEY, []) is Array else []
		for stack in _battle.get("stacks", []):
			if not (stack is Dictionary) or _stack_alive_count(stack) <= 0:
				continue
			if String(stack.get("side", "")) == "player":
				_player_stacks.append(stack)
			elif String(stack.get("side", "")) == "enemy":
				_enemy_stacks.append(stack)
	queue_redraw()

func validation_hex_layout_summary() -> Dictionary:
	var stack_cells := _stack_cells()
	var hex_state := BattleRulesScript.battle_hex_state_summary(_battle) if not _battle.is_empty() else {}
	var legal_destinations: Array = hex_state.get("legal_destinations", []) if hex_state.get("legal_destinations", []) is Array else []
	var legal_melee_targets: Array = hex_state.get("legal_melee_targets", []) if hex_state.get("legal_melee_targets", []) is Array else []
	var legal_ranged_targets: Array = hex_state.get("legal_ranged_targets", []) if hex_state.get("legal_ranged_targets", []) is Array else []
	var selected_legality: Dictionary = hex_state.get("selected_target_legality", {}) if hex_state.get("selected_target_legality", {}) is Dictionary else {}
	var selected_click_intent: Dictionary = hex_state.get("selected_target_board_click_intent", {}) if hex_state.get("selected_target_board_click_intent", {}) is Dictionary else {}
	var selected_direct_actionable := bool(hex_state.get("selected_target_direct_actionable", false))
	var selected_continuity_context: Dictionary = hex_state.get("selected_target_continuity_context", {}) if hex_state.get("selected_target_continuity_context", {}) is Dictionary else {}
	var selected_closing_context: Dictionary = hex_state.get("selected_target_closing_context", {}) if hex_state.get("selected_target_closing_context", {}) is Dictionary else {}
	var movement_click_intent: Dictionary = hex_state.get("active_movement_board_click_intent", {}) if hex_state.get("active_movement_board_click_intent", {}) is Dictionary else {}
	var legal_movement_intents: Array = hex_state.get("legal_movement_intents", []) if hex_state.get("legal_movement_intents", []) is Array else []
	var hovered_destination_preview := _hover_destination_preview()
	var selected_target_id := String(_battle.get("selected_target_id", ""))
	var selected_target_blocked := selected_target_id != "" and bool(selected_legality.get("blocked", false))
	var stack_entries := []
	for stack in _all_visible_stacks():
		var battle_id := String(stack.get("battle_id", ""))
		var cell: Vector2i = stack_cells.get(battle_id, Vector2i(-1, -1))
		stack_entries.append(
			{
				"battle_id": battle_id,
				"side": String(stack.get("side", "")),
				"unit_id": String(stack.get("unit_id", "")),
				"q": cell.x,
				"r": cell.y,
				"alive_count": _stack_alive_count(stack),
				"active": battle_id == String(_battle.get("active_stack_id", "")),
				"selected_target": battle_id == selected_target_id,
				"preserved_setup_target": battle_id == selected_target_id and not selected_continuity_context.is_empty(),
				"ordinary_closing_target": battle_id == selected_target_id and not selected_closing_context.is_empty(),
				"selected_target_blocked": battle_id == selected_target_id and selected_target_blocked,
				"legal_melee_target": battle_id in legal_melee_targets,
				"legal_ranged_target": battle_id in legal_ranged_targets,
				"legal_attack_target": battle_id in legal_melee_targets or battle_id in legal_ranged_targets,
			}
		)

	var objective_entries := []
	for index in range(_field_objectives.size()):
		var objective_value = _field_objectives[index]
		if not (objective_value is Dictionary):
			continue
		var objective: Dictionary = objective_value
		var cell := _objective_cell(index, String(objective.get("type", "")))
		objective_entries.append(
			{
				"id": String(objective.get("id", "")),
				"type": String(objective.get("type", "")),
				"q": cell.x,
				"r": cell.y,
				"control_side": String(objective.get("control_side", "neutral")),
			}
		)

	return {
		"presentation": "hex",
		"columns": HEX_COLUMNS,
		"rows": HEX_ROWS,
		"hex_count": HEX_COLUMNS * HEX_ROWS,
		"distance": int(_battle.get("distance", 1)),
		"player_stack_count": _player_stacks.size(),
		"enemy_stack_count": _enemy_stacks.size(),
		"stack_cells": stack_entries,
		"field_objective_cells": objective_entries,
		"occupied_hexes": hex_state.get("occupied_hexes", {}),
		"legal_destinations": legal_destinations,
		"legal_destination_count": legal_destinations.size(),
		"legal_movement_intents": legal_movement_intents,
		"hovered_destination_preview": hovered_destination_preview,
		"hovered_destination_detail": String(hovered_destination_preview.get("destination_detail", "")),
		"hovered_destination_sets_up_selected_target_attack": bool(hovered_destination_preview.get("sets_up_selected_target_attack", false)),
		"hovered_destination_closes_on_selected_target": bool(hovered_destination_preview.get("closes_on_selected_target", false)),
		"active_movement_board_click_intent": movement_click_intent,
		"active_movement_board_click_action": String(movement_click_intent.get("action", "")),
		"active_movement_board_click_label": String(movement_click_intent.get("label", "")),
		"legal_melee_targets": legal_melee_targets,
		"legal_ranged_targets": legal_ranged_targets,
		"legal_attack_target_count": _unique_target_count(legal_melee_targets, legal_ranged_targets),
		"selected_target_battle_id": selected_target_id,
		"selected_target_legality": selected_legality,
		"selected_target_board_click_intent": selected_click_intent,
		"selected_target_board_click_action": String(selected_click_intent.get("action", "")),
		"selected_target_board_click_label": String(selected_click_intent.get("label", "")),
		"selected_target_direct_actionable": selected_direct_actionable,
		"selected_target_continuity_context": selected_continuity_context,
		"selected_target_preserved_setup": not selected_continuity_context.is_empty(),
		"selected_target_continuity_emphasis": String(selected_continuity_context.get("emphasis", "")),
		"selected_target_closing_context": selected_closing_context,
		"selected_target_closing_on_target": not selected_closing_context.is_empty(),
		"selected_target_closing_emphasis": String(selected_closing_context.get("emphasis", "")),
		"selected_target_footer_label": _target_state_label(),
		"selected_target_blocked": selected_target_blocked,
		"selected_target_attackable": bool(selected_legality.get("attackable", false)),
		"has_active_cell": _stack_has_cell(String(_battle.get("active_stack_id", "")), stack_cells),
		"has_selected_target_cell": _stack_has_cell(selected_target_id, stack_cells),
	}

func validation_preview_hex_destination(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if _is_legal_destination_cell(cell):
		_hover_destination_cell = cell
	else:
		_hover_destination_cell = Vector2i(-1, -1)
	queue_redraw()
	return BattleRulesScript.movement_intent_for_destination(_battle, q, r)

func _draw() -> void:
	_stack_hit_shapes = []
	draw_rect(Rect2(Vector2.ZERO, size), FRAME_FILL, true)
	if _battle.is_empty():
		return

	var board_rect := Rect2(Vector2(14.0, 14.0), size - Vector2(28.0, 28.0))
	draw_rect(board_rect, BOARD_FILL, true)
	draw_rect(board_rect, FRAME_COLOR, false, 3.0)

	var field_rect := board_rect.grow(-12.0)
	_draw_terrain(field_rect)
	var hex_field_rect := _hex_field_rect(field_rect)
	var hex_layout := _hex_layout(hex_field_rect)
	_draw_hex_grid(hex_layout)
	_draw_field_objectives(hex_layout)
	var stack_cells := _stack_cells()
	_draw_tactical_affordances(hex_layout, stack_cells)
	_draw_stack_tokens(hex_layout, stack_cells)
	_draw_turn_strip(field_rect)
	_draw_footer_line(field_rect)

func _draw_terrain(field_rect: Rect2) -> void:
	var terrain := String(_battle.get("terrain", "plains"))
	var base_color: Color = TERRAIN_COLORS.get(terrain, TERRAIN_COLORS["plains"])
	draw_rect(field_rect, base_color, true)
	draw_rect(field_rect, Color(0.0, 0.0, 0.0, 0.14), false, 2.0)

	var horizon := field_rect.position + Vector2(field_rect.size.x * 0.08, field_rect.size.y * 0.22)
	var far_path := PackedVector2Array([
		horizon,
		field_rect.position + Vector2(field_rect.size.x * 0.40, field_rect.size.y * 0.30),
		field_rect.position + Vector2(field_rect.size.x * 0.68, field_rect.size.y * 0.21),
		field_rect.position + Vector2(field_rect.size.x * 0.94, field_rect.size.y * 0.34),
	])
	draw_polyline(far_path, Color(0.96, 0.82, 0.50, 0.12), 10.0, true)
	draw_polyline(far_path, Color(0.11, 0.08, 0.05, 0.22), 2.0, true)

	match terrain:
		"forest":
			for index in range(10):
				var center := field_rect.position + Vector2(
					field_rect.size.x * (0.08 + float(index % 5) * 0.20),
					field_rect.size.y * (0.15 + float(index / 5) * 0.62)
				)
				_draw_tree(center, 13.0 + float(index % 3) * 3.0)
		"swamp", "mire":
			for index in range(7):
				var center := field_rect.position + Vector2(
					field_rect.size.x * (0.13 + float(index % 4) * 0.24),
					field_rect.size.y * (0.22 + float(index / 4) * 0.48)
				)
				draw_circle(center, 18.0 + float(index % 2) * 6.0, Color(0.13, 0.20, 0.19, 0.30))
				draw_circle(center + Vector2(8.0, -2.0), 9.0, Color(0.36, 0.42, 0.31, 0.16))
		"hills":
			for index in range(5):
				var center := field_rect.position + Vector2(
					field_rect.size.x * (0.16 + float(index) * 0.18),
					field_rect.size.y * (0.24 + float(index % 2) * 0.48)
				)
				_draw_hill(center, 52.0, 24.0)
		"road":
			var road := PackedVector2Array([
				field_rect.position + Vector2(0.0, field_rect.size.y * 0.72),
				field_rect.position + Vector2(field_rect.size.x * 0.33, field_rect.size.y * 0.58),
				field_rect.position + Vector2(field_rect.size.x * 0.70, field_rect.size.y * 0.64),
				field_rect.position + Vector2(field_rect.size.x, field_rect.size.y * 0.50),
			])
			draw_polyline(road, Color(0.49, 0.39, 0.25, 0.34), 30.0, true)
			draw_polyline(road, Color(0.21, 0.16, 0.10, 0.22), 3.0, true)
		_:
			for index in range(9):
				var start := field_rect.position + Vector2(field_rect.size.x * (0.05 + float(index) * 0.11), field_rect.size.y * 0.78)
				draw_line(start, start + Vector2(18.0, -8.0), Color(0.16, 0.23, 0.12, 0.24), 2.0)

func _draw_hex_grid(hex_layout: Dictionary) -> void:
	var radius := float(hex_layout.get("radius", 1.0))
	var distance := clampi(int(_battle.get("distance", 1)), 0, 2)
	var player_front := _front_column("player", distance)
	var enemy_front := _front_column("enemy", distance)
	for row in range(HEX_ROWS):
		for column in range(HEX_COLUMNS):
			var cell := Vector2i(column, row)
			var center := _hex_center(cell, hex_layout)
			var fill := _cell_fill_color(column, player_front, enemy_front)
			_draw_hex(center, radius * 0.96, fill, HEX_LINE_COLOR, 1.6)
			if column >= player_front and column <= enemy_front:
				_draw_hex(center, radius * 0.82, Color(0.93, 0.79, 0.47, 0.035), Color(0.0, 0.0, 0.0, 0.0), 0.0)

	for row in range(HEX_ROWS):
		var center_cell := Vector2i(int(HEX_COLUMNS / 2), row)
		_draw_hex_outline(_hex_center(center_cell, hex_layout), radius * 0.98, HEX_CENTER_LINE, 1.4)

func _draw_field_objectives(hex_layout: Dictionary) -> void:
	var marker_count: int = mini(_field_objectives.size(), 5)
	for index in range(marker_count):
		var objective_value = _field_objectives[index]
		if not (objective_value is Dictionary):
			continue
		var objective: Dictionary = objective_value
		var objective_type := String(objective.get("type", ""))
		var cell := _objective_cell(index, objective_type)
		var center := _hex_center(cell, hex_layout)
		var color := _controller_color(String(objective.get("control_side", "neutral")))
		_draw_objective_marker(center, objective, color, float(hex_layout.get("radius", 1.0)))

func _draw_tactical_affordances(hex_layout: Dictionary, stack_cells: Dictionary) -> void:
	if _active_stack.is_empty():
		return
	var active_id := String(_active_stack.get("battle_id", ""))
	if not stack_cells.has(active_id):
		return
	var radius := float(hex_layout.get("radius", 1.0))
	var active_cell: Vector2i = stack_cells.get(active_id)
	var active_center := _hex_center(active_cell, hex_layout)

	if String(_active_stack.get("side", "")) == "player":
		for destination in BattleRulesScript.legal_destinations_for_active_stack(_battle):
			if not (destination is Dictionary):
				continue
			var cell := Vector2i(int(destination.get("q", -1)), int(destination.get("r", -1)))
			if not _cell_in_bounds(cell):
				continue
			_draw_hex(_hex_center(cell, hex_layout), radius * 0.78, Color(MOVE_COLOR.r, MOVE_COLOR.g, MOVE_COLOR.b, 0.16), MOVE_COLOR, 1.8)

	_draw_hex_outline(active_center, radius * 1.02, ACTIVE_COLOR, 3.4)

	var legal_melee_targets: Array = BattleRulesScript.legal_attack_targets_for_active_stack(_battle, false)
	var legal_ranged_targets: Array = BattleRulesScript.legal_attack_targets_for_active_stack(_battle, true)
	for battle_id_value in legal_ranged_targets:
		var ranged_id := String(battle_id_value)
		if not stack_cells.has(ranged_id):
			continue
		_draw_hex_outline(_hex_center(stack_cells.get(ranged_id), hex_layout), radius * 0.90, LEGAL_RANGED_COLOR, 2.0)
	for battle_id_value in legal_melee_targets:
		var melee_id := String(battle_id_value)
		if not stack_cells.has(melee_id):
			continue
		_draw_hex_outline(_hex_center(stack_cells.get(melee_id), hex_layout), radius * 0.96, LEGAL_MELEE_COLOR, 2.4)

	if not _target_stack.is_empty():
		var target_id := String(_target_stack.get("battle_id", ""))
		if stack_cells.has(target_id):
			var target_cell: Vector2i = stack_cells.get(target_id)
			var target_center := _hex_center(target_cell, hex_layout)
			var continuity_context := BattleRulesScript.selected_target_continuity_context(_battle)
			var preserved_setup_target := not continuity_context.is_empty() and String(continuity_context.get("battle_id", "")) == target_id
			if _selected_target_is_blocked():
				_draw_hex_outline(target_center, radius * 1.02, BLOCKED_TARGET_COLOR, 3.2)
				if preserved_setup_target:
					_draw_hex_outline(target_center, radius * 1.11, BLOCKED_TARGET_COLOR.lightened(0.18), 2.0)
				_draw_blocked_target_marker(target_center, radius)
			else:
				if preserved_setup_target:
					var setup_color := LEGAL_RANGED_COLOR if String(continuity_context.get("board_click_action", "")) == "shoot" else LEGAL_MELEE_COLOR
					_draw_hex_outline(target_center, radius * 1.12, setup_color, 2.4)
				_draw_hex_outline(target_center, radius * 1.02, TARGET_COLOR, 3.2)
				_draw_focus_link(active_center, target_center, String(_active_stack.get("side", "")))

func _draw_stack_tokens(hex_layout: Dictionary, stack_cells: Dictionary) -> void:
	var radius := float(hex_layout.get("radius", 1.0))
	for stack in _all_visible_stacks():
		if not (stack is Dictionary):
			continue
		var battle_id := String(stack.get("battle_id", ""))
		if not stack_cells.has(battle_id):
			continue
		var cell: Vector2i = stack_cells.get(battle_id)
		var center := _hex_center(cell, hex_layout)
		var token_radius: float = clampf(radius * 0.58, 13.0, 28.0)
		var side := String(stack.get("side", ""))
		var is_active := battle_id == String(_battle.get("active_stack_id", ""))
		var is_target := battle_id == String(_battle.get("selected_target_id", ""))
		var is_blocked_target := is_target and _selected_target_is_blocked()
		var fill := _side_color(side)
		if bool(stack.get("defending", false)):
			fill = fill.lightened(0.16)
		draw_circle(center + Vector2(2.0, 3.0), token_radius + 4.0, SHADOW_COLOR)
		draw_circle(center, token_radius + 3.0, ACTIVE_COLOR if is_active else (BLOCKED_TARGET_COLOR if is_blocked_target else (TARGET_COLOR if is_target else Color(0.11, 0.13, 0.15, 0.90))))
		draw_circle(center, token_radius, fill)
		_draw_unit_glyph(center, token_radius, stack)
		_draw_stack_health_bar(center, radius, stack)
		_draw_count_badge(center, token_radius, stack)
		_draw_stack_caption(center, radius, stack)
		_stack_hit_shapes.append(
			{
				"battle_id": battle_id,
				"side": side,
				"center": center,
				"radius": token_radius + 10.0,
			}
		)

func _draw_turn_strip(field_rect: Rect2) -> void:
	var strip_width: float = minf(field_rect.size.x - 20.0, 430.0)
	var strip_rect := Rect2(field_rect.position + Vector2(10.0, 10.0), Vector2(strip_width, 30.0))
	draw_rect(strip_rect, Color(0.08, 0.10, 0.12, 0.82), true)
	draw_rect(strip_rect, FRAME_COLOR, false, 1.4)
	var turn_order = _battle.get("turn_order", [])
	if not (turn_order is Array):
		return
	var chip_width: float = minf(92.0, (strip_rect.size.x - 14.0) / float(maxi(1, mini(turn_order.size(), 5))))
	var drawn := 0
	for battle_id_value in turn_order:
		if drawn >= 5:
			break
		var stack: Dictionary = _stack_by_id(String(battle_id_value))
		if stack.is_empty() or _stack_alive_count(stack) <= 0:
			continue
		var rect := Rect2(
			strip_rect.position + Vector2(7.0 + float(drawn) * chip_width, 5.0),
			Vector2(chip_width - 5.0, strip_rect.size.y - 10.0)
		)
		var fill := _side_color(String(stack.get("side", ""))).darkened(0.14)
		if String(stack.get("battle_id", "")) == String(_battle.get("active_stack_id", "")):
			fill = ACTIVE_COLOR
		draw_rect(rect, fill, true)
		draw_rect(rect, Color(0.10, 0.13, 0.16, 0.84), false, 1.4)
		_draw_text("%s x%d" % [_stack_initials(stack), _stack_alive_count(stack)], rect.position + Vector2(6.0, 15.0), Color(0.10, 0.12, 0.14, 0.96), 10)
		drawn += 1

func _draw_footer_line(field_rect: Rect2) -> void:
	var footer_width: float = minf(field_rect.size.x - 20.0, 520.0)
	var footer_rect := Rect2(field_rect.position + Vector2(10.0, field_rect.end.y - 28.0), Vector2(footer_width, 22.0))
	draw_rect(footer_rect, Color(0.08, 0.10, 0.12, 0.82), true)
	draw_rect(footer_rect, FRAME_COLOR, false, 1.2)
	var summary := "%s | R%d/%d | %s | %s" % [
		String(_battle.get("encounter_name", "Battle")),
		int(_battle.get("round", 1)),
		int(_battle.get("max_rounds", 12)),
		String(_battle.get("terrain", "plains")).capitalize(),
		_distance_label(int(_battle.get("distance", 1))),
	]
	var target_state := _target_state_label()
	if target_state != "":
		summary = "%s | %s" % [summary, target_state]
	var movement_state := _movement_state_label()
	if movement_state != "":
		summary = "%s | %s" % [summary, movement_state]
	_draw_text(summary.left(84), footer_rect.position + Vector2(9.0, 15.0), SUBTEXT_COLOR, 11)

func _draw_objective_marker(center: Vector2, objective: Dictionary, color: Color, radius: float) -> void:
	var objective_type := String(objective.get("type", ""))
	var size: float = clampf(radius * 0.46, 10.0, 20.0)
	match objective_type:
		"cover_line":
			var cover_rect := Rect2(center - Vector2(size * 1.15, size * 0.38), Vector2(size * 2.3, size * 0.76))
			draw_rect(cover_rect, color.darkened(0.08), true)
			draw_rect(cover_rect, Color(0.08, 0.10, 0.12, 0.80), false, 1.6)
			draw_line(cover_rect.position + Vector2(3.0, 0.0), cover_rect.end - Vector2(3.0, 0.0), Color(0.98, 0.90, 0.66, 0.36), 1.2)
		"obstruction_line":
			draw_line(center + Vector2(-size, -size * 0.68), center + Vector2(size, size * 0.68), color, 4.0)
			draw_line(center + Vector2(size, -size * 0.68), center + Vector2(-size, size * 0.68), color, 4.0)
			draw_circle(center, size * 0.24, TEXT_COLOR)
		"lane_battery":
			draw_circle(center, size * 0.74, color)
			draw_rect(Rect2(center - Vector2(size * 0.20, size * 0.92), Vector2(size * 0.40, size * 1.12)), Color(0.08, 0.10, 0.12, 0.78), true)
			draw_line(center + Vector2(-size * 0.82, size * 0.38), center + Vector2(size * 0.82, size * 0.38), Color(0.08, 0.10, 0.12, 0.78), 3.0)
		"hazard_zone":
			var points := PackedVector2Array([
				center + Vector2(0.0, -size),
				center + Vector2(size * 0.90, size * 0.60),
				center + Vector2(-size * 0.90, size * 0.60),
			])
			draw_colored_polygon(points, color)
			draw_polyline(_closed_points(points), Color(0.08, 0.10, 0.12, 0.86), 1.8, true)
		_:
			draw_circle(center, size * 0.76, color)
			draw_circle(center, size * 0.76, Color(0.08, 0.10, 0.12, 0.82), false, 1.8)
	var progress_side := String(objective.get("progress_side", ""))
	var progress_value := int(objective.get("progress_value", 0))
	var threshold: int = maxi(1, int(objective.get("capture_threshold", 2)))
	if progress_side != "" and progress_value > 0:
		for pip in range(threshold):
			var pip_center := center + Vector2((float(pip) - float(threshold - 1) * 0.5) * 6.0, size + 5.0)
			draw_circle(pip_center, 2.0, _controller_color(progress_side) if pip < progress_value else Color(0.08, 0.10, 0.12, 0.55))

func _draw_unit_glyph(center: Vector2, radius: float, stack: Dictionary) -> void:
	var glyph_color := Color(0.08, 0.10, 0.12, 0.88)
	if bool(stack.get("ranged", false)):
		draw_line(center + Vector2(-radius * 0.52, radius * 0.25), center + Vector2(radius * 0.50, -radius * 0.28), glyph_color, 2.6)
		draw_line(center + Vector2(radius * 0.50, -radius * 0.28), center + Vector2(radius * 0.22, -radius * 0.32), glyph_color, 2.2)
		draw_line(center + Vector2(radius * 0.50, -radius * 0.28), center + Vector2(radius * 0.38, -radius * 0.02), glyph_color, 2.2)
	else:
		draw_line(center + Vector2(-radius * 0.42, radius * 0.34), center + Vector2(radius * 0.38, -radius * 0.38), glyph_color, 3.0)
		draw_line(center + Vector2(-radius * 0.20, radius * 0.10), center + Vector2(radius * 0.10, radius * 0.38), glyph_color, 2.2)
	if bool(stack.get("defending", false)):
		var shield := PackedVector2Array([
			center + Vector2(0.0, -radius * 0.58),
			center + Vector2(radius * 0.34, -radius * 0.22),
			center + Vector2(radius * 0.23, radius * 0.36),
			center + Vector2(0.0, radius * 0.58),
			center + Vector2(-radius * 0.23, radius * 0.36),
			center + Vector2(-radius * 0.34, -radius * 0.22),
		])
		draw_polyline(_closed_points(shield), Color(0.98, 0.93, 0.74, 0.80), 1.6, true)

func _draw_stack_health_bar(center: Vector2, radius: float, stack: Dictionary) -> void:
	var bar_size := Vector2(radius * 0.96, 5.0)
	var bar_rect := Rect2(center + Vector2(-bar_size.x * 0.5, radius * 0.54), bar_size)
	draw_rect(bar_rect, Color(0.07, 0.08, 0.09, 0.82), true)
	var hp_rect := bar_rect
	hp_rect.size.x *= _stack_health_ratio(stack)
	draw_rect(hp_rect, HEALTH_COLOR, true)

func _draw_count_badge(center: Vector2, token_radius: float, stack: Dictionary) -> void:
	var count := _stack_alive_count(stack)
	var badge_center := center + Vector2(token_radius * 0.70, token_radius * 0.68)
	draw_circle(badge_center, max(8.0, token_radius * 0.38), Color(0.08, 0.10, 0.12, 0.92))
	draw_circle(badge_center, max(8.0, token_radius * 0.38), Color(0.96, 0.90, 0.68, 0.76), false, 1.2)
	_draw_centered_text(str(count), badge_center + Vector2(0.0, 3.5), TEXT_COLOR, 10)

func _draw_stack_caption(center: Vector2, radius: float, stack: Dictionary) -> void:
	var label := _stack_short_label(stack)
	var caption_pos := center + Vector2(-radius * 0.72, -radius * 0.62)
	_draw_text(label, caption_pos, TEXT_COLOR, 10)

func _draw_focus_link(start: Vector2, end: Vector2, active_side: String) -> void:
	var color := ACTIVE_COLOR if active_side == "player" else TARGET_COLOR
	draw_line(start, end, Color(color.r, color.g, color.b, 0.52), 3.0, true)
	var delta := end - start
	if delta.length() <= 1.0:
		return
	var direction := delta.normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	for step in range(1, 4):
		var point := start.lerp(end, float(step) / 4.0)
		var arrow := PackedVector2Array([
			point + direction * 8.0,
			point - direction * 6.0 + perpendicular * 5.0,
			point - direction * 6.0 - perpendicular * 5.0,
		])
		draw_colored_polygon(arrow, Color(color.r, color.g, color.b, 0.58))

func _draw_blocked_target_marker(center: Vector2, radius: float) -> void:
	var marker_radius: float = clampf(radius * 0.34, 7.0, 14.0)
	var marker_center := center + Vector2(radius * 0.36, -radius * 0.36)
	draw_circle(marker_center, marker_radius, Color(0.08, 0.09, 0.10, 0.86))
	draw_line(marker_center + Vector2(-marker_radius * 0.48, -marker_radius * 0.48), marker_center + Vector2(marker_radius * 0.48, marker_radius * 0.48), BLOCKED_TARGET_COLOR, 2.2)
	draw_line(marker_center + Vector2(marker_radius * 0.48, -marker_radius * 0.48), marker_center + Vector2(-marker_radius * 0.48, marker_radius * 0.48), BLOCKED_TARGET_COLOR, 2.2)

func _draw_tree(center: Vector2, scale: float) -> void:
	var crown := PackedVector2Array([
		center + Vector2(0.0, -scale),
		center + Vector2(scale * 0.78, scale * 0.48),
		center + Vector2(-scale * 0.78, scale * 0.48),
	])
	draw_colored_polygon(crown, Color(0.10, 0.21, 0.13, 0.34))
	draw_rect(Rect2(center + Vector2(-2.0, scale * 0.28), Vector2(4.0, scale * 0.46)), Color(0.16, 0.11, 0.07, 0.26), true)

func _draw_hill(center: Vector2, width: float, height: float) -> void:
	var points := PackedVector2Array([
		center + Vector2(-width * 0.50, height * 0.35),
		center + Vector2(-width * 0.22, -height * 0.34),
		center + Vector2(width * 0.04, -height * 0.08),
		center + Vector2(width * 0.34, -height * 0.42),
		center + Vector2(width * 0.50, height * 0.35),
	])
	draw_colored_polygon(points, Color(0.18, 0.14, 0.09, 0.20))

func _draw_hex(center: Vector2, radius: float, fill: Color, stroke: Color, width: float) -> void:
	var points := _hex_points(center, radius)
	if fill.a > 0.0:
		draw_colored_polygon(points, fill)
	if stroke.a > 0.0 and width > 0.0:
		draw_polyline(_closed_points(points), stroke, width, true)

func _draw_hex_outline(center: Vector2, radius: float, stroke: Color, width: float) -> void:
	draw_polyline(_closed_points(_hex_points(center, radius)), stroke, width, true)

func _hex_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(6):
		var angle := deg_to_rad(30.0 + 60.0 * float(index))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if points.size() > 0:
		closed.append(points[0])
	return closed

func _hex_field_rect(field_rect: Rect2) -> Rect2:
	return Rect2(
		field_rect.position + Vector2(10.0, 44.0),
		Vector2(max(1.0, field_rect.size.x - 20.0), max(1.0, field_rect.size.y - 78.0))
	)

func _hex_layout(hex_field_rect: Rect2) -> Dictionary:
	var radius_x := hex_field_rect.size.x / (SQRT_3 * (float(HEX_COLUMNS) + 0.5))
	var radius_y := hex_field_rect.size.y / (1.5 * float(HEX_ROWS - 1) + 2.0)
	var radius: float = maxf(8.0, minf(radius_x, radius_y))
	var grid_size := Vector2(
		SQRT_3 * radius * (float(HEX_COLUMNS) + 0.5),
		radius * (1.5 * float(HEX_ROWS - 1) + 2.0)
	)
	var origin := hex_field_rect.position + (hex_field_rect.size - grid_size) * 0.5
	return {
		"origin": origin,
		"radius": radius,
		"hex_width": SQRT_3 * radius,
		"grid_size": grid_size,
		"rect": Rect2(origin, grid_size),
	}

func _hex_center(cell: Vector2i, layout: Dictionary) -> Vector2:
	var origin: Vector2 = layout.get("origin", Vector2.ZERO)
	var radius := float(layout.get("radius", 1.0))
	var hex_width := float(layout.get("hex_width", SQRT_3 * radius))
	return origin + Vector2(
		hex_width * (float(cell.x) + 0.5 * float(cell.y % 2)) + hex_width * 0.5,
		radius * (1.5 * float(cell.y) + 1.0)
	)

func _cell_fill_color(column: int, player_front: int, enemy_front: int) -> Color:
	if column < player_front:
		return Color(0.13, 0.25, 0.31, 0.22)
	if column > enemy_front:
		return Color(0.34, 0.13, 0.12, 0.22)
	if column == int(HEX_COLUMNS / 2):
		return Color(0.50, 0.38, 0.18, 0.18)
	return Color(0.09, 0.12, 0.10, 0.12)

func _stack_cells() -> Dictionary:
	var cells := {}
	var distance := clampi(int(_battle.get("distance", 1)), 0, 2)
	_assign_stack_cells(cells, _player_stacks, "player", distance)
	_assign_stack_cells(cells, _enemy_stacks, "enemy", distance)
	return cells

func _assign_stack_cells(cells: Dictionary, stacks: Array, side: String, distance: int) -> void:
	var rows := _formation_rows(stacks.size())
	for index in range(stacks.size()):
		var stack_value = stacks[index]
		if not (stack_value is Dictionary):
			continue
		var stack: Dictionary = stack_value
		var hex := _stack_hex_cell(stack)
		if hex.x < 0:
			var column := _front_column(side, distance)
			if bool(stack.get("ranged", false)):
				column += -1 if side == "player" else 1
			column = clampi(column, 0, HEX_COLUMNS - 1)
			var row := int(rows[index]) if index < rows.size() else clampi(index, 0, HEX_ROWS - 1)
			hex = Vector2i(column, row)
		cells[String(stack.get("battle_id", ""))] = hex

func _formation_rows(stack_count: int) -> Array:
	match stack_count:
		0:
			return []
		1:
			return [3]
		2:
			return [2, 4]
		3:
			return [1, 3, 5]
		4:
			return [1, 2, 4, 5]
		5:
			return [0, 2, 3, 4, 6]
		6:
			return [0, 1, 2, 4, 5, 6]
		_:
			return [0, 1, 2, 3, 4, 5, 6]

func _front_column(side: String, distance: int) -> int:
	var normalized_distance := clampi(distance, 0, 2)
	if side == "player":
		return [4, 3, 1][normalized_distance]
	return [5, 7, 9][normalized_distance]

func _objective_cell(index: int, objective_type: String) -> Vector2i:
	match objective_type:
		"lane_battery":
			return Vector2i(5, 1 if index % 2 == 0 else 5)
		"cover_line":
			return Vector2i(4, 2 + (index % 3))
		"obstruction_line":
			return Vector2i(5, 3)
		"hazard_zone":
			return Vector2i(6, 2 + (index % 3))
		"signal_beacon":
			return Vector2i(5, 0 if index % 2 == 0 else 6)
		"breach_point":
			return Vector2i(5, 3)
		_:
			var defaults := [Vector2i(5, 3), Vector2i(5, 2), Vector2i(5, 4), Vector2i(4, 3), Vector2i(6, 3)]
			return defaults[index % defaults.size()]

func _stack_hex_cell(stack: Dictionary) -> Vector2i:
	var hex = stack.get("hex", {})
	if not (hex is Dictionary):
		return Vector2i(-1, -1)
	var cell := Vector2i(int(hex.get("q", -1)), int(hex.get("r", -1)))
	return cell if _cell_in_bounds(cell) else Vector2i(-1, -1)

func _cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < HEX_COLUMNS and cell.y >= 0 and cell.y < HEX_ROWS

func _hex_cell_at_position(position: Vector2) -> Vector2i:
	if _battle.is_empty():
		return Vector2i(-1, -1)
	var board_rect := Rect2(Vector2(14.0, 14.0), size - Vector2(28.0, 28.0))
	var field_rect := board_rect.grow(-12.0)
	var hex_layout := _hex_layout(_hex_field_rect(field_rect))
	var radius := float(hex_layout.get("radius", 1.0))
	var best_cell := Vector2i(-1, -1)
	var best_distance := radius * 0.92
	for row in range(HEX_ROWS):
		for column in range(HEX_COLUMNS):
			var cell := Vector2i(column, row)
			var distance := position.distance_to(_hex_center(cell, hex_layout))
			if distance <= best_distance:
				best_distance = distance
				best_cell = cell
	return best_cell

func _is_legal_destination_cell(cell: Vector2i) -> bool:
	if not _cell_in_bounds(cell):
		return false
	for destination in BattleRulesScript.legal_destinations_for_active_stack(_battle):
		if not (destination is Dictionary):
			continue
		if int(destination.get("q", -1)) == cell.x and int(destination.get("r", -1)) == cell.y:
			return true
	return false

func _selected_target_is_blocked() -> bool:
	var selected_target_id := String(_battle.get("selected_target_id", ""))
	if selected_target_id == "" or _battle.is_empty():
		return false
	var legality := BattleRulesScript.selected_target_legality(_battle)
	return bool(legality.get("blocked", false))

func _target_state_label() -> String:
	if _target_stack.is_empty():
		return ""
	var continuity_context := BattleRulesScript.selected_target_continuity_context(_battle)
	if not continuity_context.is_empty():
		return String(continuity_context.get("footer_label", "Setup target"))
	var closing_context := BattleRulesScript.selected_target_closing_context(_battle)
	if not closing_context.is_empty():
		return String(closing_context.get("footer_label", "Closing target"))
	var click_intent := BattleRulesScript.board_click_attack_intent_for_target(_battle, String(_target_stack.get("battle_id", "")))
	var action_label := String(click_intent.get("label", ""))
	if action_label != "":
		return "Click: %s" % action_label
	var legality := BattleRulesScript.selected_target_legality(_battle)
	if bool(legality.get("melee", false)) and bool(legality.get("ranged", false)):
		return "Target: melee/ranged"
	if bool(legality.get("melee", false)):
		return "Target: melee"
	if bool(legality.get("ranged", false)):
		return "Target: ranged"
	if bool(legality.get("blocked", false)):
		return "Target: blocked"
	return ""

func _movement_state_label() -> String:
	var hovered_preview := _hover_destination_preview()
	if not hovered_preview.is_empty():
		var detail := String(hovered_preview.get("destination_detail", ""))
		var setup_label := String(hovered_preview.get("selected_target_setup_label", ""))
		if bool(hovered_preview.get("sets_up_selected_target_attack", false)) and setup_label != "":
			return "Green: %s -> later %s" % [detail, setup_label]
		if bool(hovered_preview.get("closes_on_selected_target", false)):
			return "Green: %s -> close target" % detail
		if detail != "":
			return "Green: %s" % detail
	var movement_intent := BattleRulesScript.active_movement_board_click_intent(_battle)
	if String(movement_intent.get("action", "")) == "move":
		if bool(movement_intent.get("selected_target_blocked", false)):
			return "Green: Move first"
		return "Green: Move"
	if bool(movement_intent.get("blocked", false)) and bool(movement_intent.get("selected_target_blocked", false)):
		return "Green: no move"
	return ""

func _hover_destination_preview() -> Dictionary:
	if _is_legal_destination_cell(_hover_destination_cell):
		return BattleRulesScript.movement_intent_for_destination(_battle, _hover_destination_cell.x, _hover_destination_cell.y)
	return {}

func _stack_board_tooltip(battle_id: String) -> String:
	var stack := _stack_by_id(battle_id)
	if stack.is_empty():
		return tooltip_text
	var side := String(stack.get("side", ""))
	if String(_active_stack.get("side", "")) == "player" and side == "enemy":
		var continuity_context := BattleRulesScript.selected_target_continuity_context(_battle)
		if not continuity_context.is_empty() and String(continuity_context.get("battle_id", "")) == battle_id:
			return String(continuity_context.get("message", tooltip_text))
		var closing_context := BattleRulesScript.selected_target_closing_context(_battle)
		if not closing_context.is_empty() and String(closing_context.get("battle_id", "")) == battle_id:
			return String(closing_context.get("message", tooltip_text))
		var click_intent := BattleRulesScript.board_click_attack_intent_for_target(_battle, battle_id)
		var message := String(click_intent.get("message", ""))
		if message != "":
			return message
	if battle_id == String(_battle.get("active_stack_id", "")):
		return "Active: %s. Click green hexes to move; highlighted enemies show attacks." % String(stack.get("name", "Stack"))
	if side == "player":
		return "%s is a friendly stack." % String(stack.get("name", "Stack"))
	return "%s is an enemy stack." % String(stack.get("name", "Stack"))

func _unique_target_count(primary: Array, secondary: Array) -> int:
	var seen := {}
	for value in primary:
		seen[String(value)] = true
	for value in secondary:
		seen[String(value)] = true
	return seen.size()

func _stack_id_at_position(position: Vector2) -> String:
	for index in range(_stack_hit_shapes.size() - 1, -1, -1):
		var shape_value = _stack_hit_shapes[index]
		if not (shape_value is Dictionary):
			continue
		var shape: Dictionary = shape_value
		var center: Vector2 = shape.get("center", Vector2.ZERO)
		var radius := float(shape.get("radius", 0.0))
		if position.distance_to(center) <= radius:
			return String(shape.get("battle_id", ""))
	return ""

func _all_visible_stacks() -> Array:
	var stacks := []
	stacks.append_array(_player_stacks)
	stacks.append_array(_enemy_stacks)
	return stacks

func _stack_has_cell(battle_id: String, stack_cells: Dictionary) -> bool:
	if battle_id == "" or not stack_cells.has(battle_id):
		return false
	var cell: Vector2i = stack_cells.get(battle_id)
	return cell.x >= 0 and cell.x < HEX_COLUMNS and cell.y >= 0 and cell.y < HEX_ROWS

func _stack_by_id(battle_id: String) -> Dictionary:
	for stack in _battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			return stack
	return {}

func _stack_alive_count(stack: Dictionary) -> int:
	var unit_hp: int = maxi(1, int(stack.get("unit_hp", stack.get("hp", 1))))
	var total_health: int = maxi(0, int(stack.get("total_health", 0)))
	if total_health <= 0:
		return 0
	return int(ceil(float(total_health) / float(unit_hp)))

func _stack_health_ratio(stack: Dictionary) -> float:
	var unit_hp: int = maxi(1, int(stack.get("unit_hp", stack.get("hp", 1))))
	var base_count: int = maxi(1, int(stack.get("base_count", _stack_alive_count(stack))))
	var max_health: int = maxi(1, unit_hp * base_count)
	return clampf(float(max(0, int(stack.get("total_health", 0)))) / float(max_health), 0.0, 1.0)

func _stack_initials(stack: Dictionary) -> String:
	var name := String(stack.get("name", stack.get("unit_id", "Stack"))).strip_edges()
	if name == "":
		return "?"
	var parts := name.split(" ", false)
	if parts.size() <= 1:
		return name.left(2).to_upper()
	return ("%s%s" % [String(parts[0]).left(1), String(parts[1]).left(1)]).to_upper()

func _stack_short_label(stack: Dictionary) -> String:
	var name := String(stack.get("name", stack.get("unit_id", "Stack")))
	return name.left(13)

func _side_color(side: String) -> Color:
	return PLAYER_COLOR if side == "player" else ENEMY_COLOR

func _controller_color(controller: String) -> Color:
	match controller:
		"player":
			return PLAYER_COLOR
		"enemy":
			return ENEMY_COLOR
		_:
			return NEUTRAL_COLOR

func _distance_label(distance: int) -> String:
	match clampi(distance, 0, 2):
		0:
			return "Engaged"
		1:
			return "Closing"
		_:
			return "Long lane"

func _draw_text(text: String, position: Vector2, color: Color, font_size: int) -> void:
	var font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw_centered_text(text: String, position: Vector2, color: Color, font_size: int) -> void:
	var font = get_theme_default_font()
	if font == null:
		return
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	draw_string(font, position - Vector2(text_size.x * 0.5, text_size.y * 0.45), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
