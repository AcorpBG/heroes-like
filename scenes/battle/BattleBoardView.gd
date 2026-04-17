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
	"grass": Color(0.31, 0.40, 0.24, 1.0),
	"plains": Color(0.30, 0.38, 0.24, 1.0),
	"forest": Color(0.18, 0.31, 0.22, 1.0),
	"swamp": Color(0.24, 0.29, 0.22, 1.0),
	"hills": Color(0.37, 0.32, 0.24, 1.0),
	"road": Color(0.35, 0.30, 0.24, 1.0),
	"mire": Color(0.21, 0.27, 0.22, 1.0),
}
const TERRAIN_TEXTURE_ALIASES := {
	"plains": "grass",
	"grass": "grass",
	"forest": "forest",
	"swamp": "swamp",
	"hills": "hills",
	"road": "road",
	"mire": "mire",
}
const TERRAIN_TEXTURE_PATHS := {
	"grass": "res://art/battle/terrain/grass.png",
	"forest": "res://art/battle/terrain/forest.png",
	"swamp": "res://art/battle/terrain/swamp.png",
	"hills": "res://art/battle/terrain/hills.png",
	"road": "res://art/battle/terrain/road.png",
	"mire": "res://art/battle/terrain/mire.png",
}
const TERRAIN_TEXTURE_MODULATE := Color(0.98, 0.99, 0.95, 0.98)
const TERRAIN_TEXTURE_READABILITY_WASH := Color(0.02, 0.025, 0.022, 0.045)
const TERRAIN_HEX_TEXTURE_INSET := 1.0
const TERRAIN_HEX_FALLBACK_INSET := 0.975
const TEXTURED_HEX_LINE_COLOR := Color(0.98, 0.89, 0.62, 0.18)
const TEXTURED_HEX_CENTER_LINE := Color(1.0, 0.86, 0.46, 0.28)
const TEXTURED_DEPLOYMENT_FILL_ALPHA := 0.035
const TEXTURED_CENTER_FILL_ALPHA := 0.045
const TEXTURED_MID_LANE_FILL_ALPHA := 0.018
const TEXTURED_GRID_MAX_CELL_FILL_ALPHA := 0.05

var _session = null
var _battle: Dictionary = {}
var _player_stacks: Array = []
var _enemy_stacks: Array = []
var _active_stack: Dictionary = {}
var _target_stack: Dictionary = {}
var _field_objectives: Array = []
var _stack_hit_shapes: Array = []
var _hover_destination_cell := Vector2i(-1, -1)
var _terrain_textures: Dictionary = {}
var _terrain_texture_missing: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(620.0, 320.0)
	tooltip_text = "Green hex click moves. Highlighted enemy click attacks; blocked enemies need movement."
	_load_terrain_textures()

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
	var dispatch := _dispatch_board_click_at_position(mouse_event.position)
	if bool(dispatch.get("accepted", false)):
		accept_event()

func _dispatch_board_click_at_position(position: Vector2) -> Dictionary:
	var target_cell := _hex_cell_at_position(position)
	var battle_id := _stack_id_at_position(position)
	if battle_id != "":
		if _is_legal_destination_cell(target_cell):
			hex_destination_requested.emit(target_cell.x, target_cell.y)
			return {
				"accepted": true,
				"dispatch": "destination",
				"battle_id": "",
				"shape_battle_id": battle_id,
				"q": target_cell.x,
				"r": target_cell.y,
			}
		var cell_battle_id := _stack_id_at_cell(target_cell)
		if cell_battle_id != "" and cell_battle_id != battle_id:
			stack_focus_requested.emit(cell_battle_id)
			return {
				"accepted": true,
				"dispatch": "stack_hex",
				"battle_id": cell_battle_id,
				"shape_battle_id": battle_id,
				"q": target_cell.x,
				"r": target_cell.y,
			}
	if battle_id == "":
		battle_id = _stack_id_at_cell(target_cell)
		if battle_id != "":
			stack_focus_requested.emit(battle_id)
			return {
				"accepted": true,
				"dispatch": "stack_hex",
				"battle_id": battle_id,
				"q": target_cell.x,
				"r": target_cell.y,
			}
		if target_cell.x < 0:
			return {
				"accepted": false,
				"dispatch": "",
				"battle_id": "",
				"q": target_cell.x,
				"r": target_cell.y,
			}
		if not _is_legal_destination_cell(target_cell):
			var movement_intent := BattleRulesScript.movement_intent_for_destination(_battle, target_cell.x, target_cell.y)
			hex_destination_requested.emit(target_cell.x, target_cell.y)
			return {
				"accepted": true,
				"dispatch": "destination_blocked",
				"battle_id": "",
				"q": target_cell.x,
				"r": target_cell.y,
				"message": String(movement_intent.get("message", "")),
			}
		hex_destination_requested.emit(target_cell.x, target_cell.y)
		return {
			"accepted": true,
			"dispatch": "destination",
			"battle_id": "",
			"q": target_cell.x,
			"r": target_cell.y,
		}
	stack_focus_requested.emit(battle_id)
	var stack_cell := _stack_cell_for_battle_id(battle_id)
	return {
		"accepted": true,
		"dispatch": "stack_token",
		"battle_id": battle_id,
		"q": stack_cell.x,
		"r": stack_cell.y,
	}

func _get_tooltip(at_position: Vector2) -> String:
	var destination_cell := _hex_cell_at_position(at_position)
	var battle_id := _stack_id_at_position(at_position)
	if battle_id != "":
		if _is_legal_destination_cell(destination_cell):
			return _movement_board_tooltip(destination_cell)
		var cell_battle_id := _stack_id_at_cell(destination_cell)
		if cell_battle_id != "" and cell_battle_id != battle_id:
			return _stack_board_tooltip(cell_battle_id)
		return _stack_board_tooltip(battle_id)
	battle_id = _stack_id_at_cell(destination_cell)
	if battle_id != "":
		return _stack_board_tooltip(battle_id)
	if _is_legal_destination_cell(destination_cell):
		return _movement_board_tooltip(destination_cell)
	if _cell_in_bounds(destination_cell):
		var movement_intent := BattleRulesScript.movement_intent_for_destination(_battle, destination_cell.x, destination_cell.y)
		var message := String(movement_intent.get("message", ""))
		if bool(movement_intent.get("blocked", false)) and message != "":
			return message
	return _fallback_board_tooltip()

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
	var terrain_id := _battle_terrain_id()
	var terrain_texture_id := _terrain_texture_id(terrain_id)
	var terrain_texture = _terrain_texture_for(terrain_id)
	var player_input_active := String(_active_stack.get("side", "")) == "player"
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
	if not player_input_active:
		legal_destinations = []
		legal_melee_targets = []
		legal_ranged_targets = []
		legal_movement_intents = []
		if not selected_legality.is_empty():
			selected_legality = selected_legality.duplicate(true)
			selected_legality["melee"] = false
			selected_legality["ranged"] = false
			selected_legality["attackable"] = false
			selected_legality["blocked"] = false
			selected_legality["input_locked"] = true
		if not selected_click_intent.is_empty():
			selected_click_intent = selected_click_intent.duplicate(true)
			selected_click_intent["action"] = ""
			selected_click_intent["label"] = ""
			selected_click_intent["attackable"] = false
			selected_click_intent["blocked"] = false
			selected_click_intent["message"] = "Input locked: it is not the player's turn."
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
		"terrain": terrain_id,
		"terrain_texture_id": terrain_texture_id,
		"terrain_texture_path": _terrain_texture_path_for(terrain_texture_id),
		"terrain_texture_loaded": terrain_texture != null,
		"terrain_texture_fallback": terrain_texture == null,
		"terrain_rendering_mode": _terrain_rendering_mode(terrain_texture != null),
		"terrain_hex_snapped": true,
		"terrain_hex_tile_count": _terrain_hex_tile_count(),
		"terrain_single_board_backdrop": false,
		"terrain_texture_visible": _terrain_texture_visible(terrain_texture != null),
		"terrain_grid_fill_mode": _terrain_grid_fill_mode(terrain_texture != null),
		"terrain_grid_max_fill_alpha": _terrain_grid_max_fill_alpha(terrain_texture != null),
		"terrain_grid_border_mode": _terrain_grid_border_mode(terrain_texture != null),
		"terrain_grid_repaints_texture_cells": _terrain_grid_repaints_texture_cells(terrain_texture != null),
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

func validation_terrain_backdrop_summary() -> Dictionary:
	return validation_terrain_rendering_summary()

func validation_terrain_rendering_summary() -> Dictionary:
	var terrain_id := _battle_terrain_id()
	var texture_id := _terrain_texture_id(terrain_id)
	var texture_path := _terrain_texture_path_for(texture_id)
	var texture = _terrain_texture_for(terrain_id)
	var texture_size := Vector2.ZERO
	var source_size := Vector2.ZERO
	if texture != null:
		texture_size = texture.get_size()
		source_size = _terrain_hex_texture_source_size(texture_size)
	return {
		"terrain": terrain_id,
		"texture_id": texture_id,
		"texture_path": texture_path,
		"texture_loaded": texture != null,
		"fallback": texture == null,
		"mapped": terrain_id != texture_id,
		"texture_width": texture_size.x,
		"texture_height": texture_size.y,
		"rendering_mode": _terrain_rendering_mode(texture != null),
		"hex_snapped": true,
		"single_board_backdrop": false,
		"hex_tile_count": _terrain_hex_tile_count(),
		"texture_sample_mode": "per_hex_clipped" if texture != null else "",
		"source_tile_width": source_size.x,
		"source_tile_height": source_size.y,
		"texture_modulate_alpha": TERRAIN_TEXTURE_MODULATE.a if texture != null else 0.0,
		"texture_readability_wash_alpha": TERRAIN_TEXTURE_READABILITY_WASH.a if texture != null else 0.0,
		"texture_hex_inset": TERRAIN_HEX_TEXTURE_INSET if texture != null else TERRAIN_HEX_FALLBACK_INSET,
		"texture_visible": _terrain_texture_visible(texture != null),
		"grid_fill_mode": _terrain_grid_fill_mode(texture != null),
		"grid_max_fill_alpha": _terrain_grid_max_fill_alpha(texture != null),
		"grid_border_mode": _terrain_grid_border_mode(texture != null),
		"grid_border_deduplicated": _terrain_grid_border_deduplicated(texture != null),
		"grid_repaints_texture_cells": _terrain_grid_repaints_texture_cells(texture != null),
	}

func validation_preview_hex_destination(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if _is_legal_destination_cell(cell):
		_hover_destination_cell = cell
	else:
		_hover_destination_cell = Vector2i(-1, -1)
	queue_redraw()
	return BattleRulesScript.movement_intent_for_destination(_battle, q, r)

func validation_perform_hex_cell_mouse_click(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if not _cell_in_bounds(cell):
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click cell is outside the battlefield.",
		}
	var probe := _validation_click_position_for_cell(cell)
	if probe.is_empty():
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click could not resolve a point inside the requested cell.",
		}
	var position: Vector2 = probe.get("position", Vector2.ZERO)
	var shape_target_before := _stack_id_at_position(position)
	var resolved_cell := _hex_cell_at_position(position)
	var cell_target_before := _stack_id_at_cell(resolved_cell)
	var tooltip_before := _get_tooltip(position)
	var dispatch := _dispatch_board_click_at_position(position)
	dispatch["shape_target_before"] = shape_target_before
	dispatch["cell_target_before"] = cell_target_before
	dispatch["tooltip_before"] = tooltip_before
	dispatch["position_x"] = position.x
	dispatch["position_y"] = position.y
	dispatch["found_shape_miss_position"] = bool(probe.get("found_shape_miss_position", false))
	dispatch["hex_radius"] = float(probe.get("hex_radius", 0.0))
	return dispatch

func validation_perform_outer_hex_ring_mouse_click(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if not _cell_in_bounds(cell):
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click cell is outside the battlefield.",
		}
	var probe := _validation_outer_ring_click_position_for_cell(cell)
	if probe.is_empty():
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click could not find a token-miss point in the visible outer hex ring.",
		}
	var position: Vector2 = probe.get("position", Vector2.ZERO)
	var shape_target_before := _stack_id_at_position(position)
	var resolved_cell := _hex_cell_at_position(position)
	var cell_target_before := _stack_id_at_cell(resolved_cell)
	var dispatch := _dispatch_board_click_at_position(position)
	dispatch["shape_target_before"] = shape_target_before
	dispatch["cell_target_before"] = cell_target_before
	dispatch["resolved_q"] = resolved_cell.x
	dispatch["resolved_r"] = resolved_cell.y
	dispatch["position_x"] = position.x
	dispatch["position_y"] = position.y
	dispatch["found_outer_ring_position"] = bool(probe.get("found_outer_ring_position", false))
	dispatch["radius_factor"] = float(probe.get("radius_factor", 0.0))
	dispatch["hex_radius"] = float(probe.get("hex_radius", 0.0))
	return dispatch

func validation_perform_overlapped_hex_destination_mouse_click(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if not _cell_in_bounds(cell):
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click cell is outside the battlefield.",
		}
	var probe := _validation_overlapped_destination_click_position_for_cell(cell)
	if probe.is_empty():
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click could not find a friendly-shape overlap inside the requested movement cell.",
		}
	var position: Vector2 = probe.get("position", Vector2.ZERO)
	var shape_target_before := _stack_id_at_position(position)
	var resolved_cell := _hex_cell_at_position(position)
	var legal_destination_before := _is_legal_destination_cell(resolved_cell)
	var movement_intent_before := BattleRulesScript.movement_intent_for_destination(_battle, resolved_cell.x, resolved_cell.y)
	var tooltip_before := _get_tooltip(position)
	var dispatch := _dispatch_board_click_at_position(position)
	dispatch["shape_target_before"] = shape_target_before
	dispatch["shape_target_side_before"] = String(_stack_by_id(shape_target_before).get("side", ""))
	dispatch["resolved_q"] = resolved_cell.x
	dispatch["resolved_r"] = resolved_cell.y
	dispatch["legal_destination_before"] = legal_destination_before
	dispatch["movement_tooltip_before"] = String(movement_intent_before.get("message", ""))
	dispatch["tooltip_before"] = tooltip_before
	dispatch["position_x"] = position.x
	dispatch["position_y"] = position.y
	dispatch["found_friendly_shape_overlap"] = bool(probe.get("found_shape_overlap", probe.get("found_friendly_shape_overlap", false)))
	dispatch["radius_factor"] = float(probe.get("radius_factor", 0.0))
	dispatch["hex_radius"] = float(probe.get("hex_radius", 0.0))
	return dispatch

func validation_perform_enemy_overlapped_hex_destination_mouse_click(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if not _cell_in_bounds(cell):
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click cell is outside the battlefield.",
		}
	var probe := _validation_overlapped_destination_click_position_for_cell(cell, "enemy")
	if probe.is_empty():
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click could not find an enemy-shape overlap inside the requested movement cell.",
		}
	var position: Vector2 = probe.get("position", Vector2.ZERO)
	var shape_target_before := _stack_id_at_position(position)
	var resolved_cell := _hex_cell_at_position(position)
	var legal_destination_before := _is_legal_destination_cell(resolved_cell)
	var movement_intent_before := BattleRulesScript.movement_intent_for_destination(_battle, resolved_cell.x, resolved_cell.y)
	var tooltip_before := _get_tooltip(position)
	var dispatch := _dispatch_board_click_at_position(position)
	dispatch["shape_target_before"] = shape_target_before
	dispatch["shape_target_side_before"] = String(_stack_by_id(shape_target_before).get("side", ""))
	dispatch["resolved_q"] = resolved_cell.x
	dispatch["resolved_r"] = resolved_cell.y
	dispatch["legal_destination_before"] = legal_destination_before
	dispatch["movement_tooltip_before"] = String(movement_intent_before.get("message", ""))
	dispatch["tooltip_before"] = tooltip_before
	dispatch["position_x"] = position.x
	dispatch["position_y"] = position.y
	dispatch["found_enemy_shape_overlap"] = bool(probe.get("found_shape_overlap", false))
	dispatch["radius_factor"] = float(probe.get("radius_factor", 0.0))
	dispatch["hex_radius"] = float(probe.get("hex_radius", 0.0))
	return dispatch

func validation_perform_enemy_overlapped_occupied_hex_mouse_click(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if not _cell_in_bounds(cell):
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click cell is outside the battlefield.",
		}
	var cell_target_before := _stack_id_at_cell(cell)
	if cell_target_before == "":
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click cell is not occupied by a stack.",
		}
	var probe := _validation_overlapped_occupied_hex_click_position_for_cell(cell, "enemy")
	if probe.is_empty():
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click could not find an enemy-shape overlap inside the occupied hex.",
		}
	var position: Vector2 = probe.get("position", Vector2.ZERO)
	var shape_target_before := _stack_id_at_position(position)
	var resolved_cell := _hex_cell_at_position(position)
	cell_target_before = _stack_id_at_cell(resolved_cell)
	var cell_target_intent_before := BattleRulesScript.board_click_attack_intent_for_target(_battle, cell_target_before)
	var tooltip_before := _get_tooltip(position)
	var dispatch := _dispatch_board_click_at_position(position)
	dispatch["shape_target_before"] = shape_target_before
	dispatch["shape_target_side_before"] = String(_stack_by_id(shape_target_before).get("side", ""))
	dispatch["cell_target_before"] = cell_target_before
	dispatch["cell_target_side_before"] = String(_stack_by_id(cell_target_before).get("side", ""))
	dispatch["cell_target_click_action_before"] = String(cell_target_intent_before.get("action", ""))
	dispatch["cell_target_tooltip_before"] = String(cell_target_intent_before.get("message", ""))
	dispatch["tooltip_before"] = tooltip_before
	dispatch["resolved_q"] = resolved_cell.x
	dispatch["resolved_r"] = resolved_cell.y
	dispatch["position_x"] = position.x
	dispatch["position_y"] = position.y
	dispatch["found_enemy_shape_overlap"] = bool(probe.get("found_shape_overlap", false))
	dispatch["radius_factor"] = float(probe.get("radius_factor", 0.0))
	dispatch["hex_radius"] = float(probe.get("hex_radius", 0.0))
	return dispatch

func validation_board_fallback_tooltip() -> Dictionary:
	var position := _validation_fallback_tooltip_position()
	if position.x < 0.0:
		return {
			"ok": false,
			"message": "Validation could not find an empty board fallback tooltip position.",
		}
	var resolved_cell := _hex_cell_at_position(position)
	var shape_target := _stack_id_at_position(position)
	return {
		"ok": true,
		"tooltip": _get_tooltip(position),
		"position_x": position.x,
		"position_y": position.y,
		"resolved_q": resolved_cell.x,
		"resolved_r": resolved_cell.y,
		"shape_target": shape_target,
	}

func _draw() -> void:
	_stack_hit_shapes = []
	draw_rect(Rect2(Vector2.ZERO, size), FRAME_FILL, true)
	if _battle.is_empty():
		return

	var board_rect := Rect2(Vector2(14.0, 14.0), size - Vector2(28.0, 28.0))
	draw_rect(board_rect, BOARD_FILL, true)
	draw_rect(board_rect, FRAME_COLOR, false, 3.0)

	var field_rect := board_rect.grow(-12.0)
	var hex_field_rect := _hex_field_rect(field_rect)
	var hex_layout := _hex_layout(hex_field_rect)
	var terrain_texture_loaded := _draw_terrain(field_rect, hex_layout)
	_draw_hex_grid(hex_layout, terrain_texture_loaded)
	_draw_field_objectives(hex_layout)
	var stack_cells := _stack_cells()
	_draw_tactical_affordances(hex_layout, stack_cells)
	_draw_stack_tokens(hex_layout, stack_cells)
	_draw_turn_strip(field_rect)
	_draw_footer_line(field_rect)

func _draw_terrain(field_rect: Rect2, hex_layout: Dictionary) -> bool:
	var terrain := _battle_terrain_id()
	var base_color := _terrain_color_for(terrain)
	draw_rect(field_rect, base_color, true)
	var terrain_texture = _terrain_texture_for(terrain)
	if terrain_texture != null:
		_draw_hex_snapped_terrain_texture(hex_layout, terrain_texture)
		draw_rect(field_rect, TERRAIN_TEXTURE_READABILITY_WASH, true)
		draw_rect(field_rect, Color(0.0, 0.0, 0.0, 0.14), false, 2.0)
		return true
	else:
		_draw_hex_snapped_procedural_terrain(hex_layout, terrain)
	draw_rect(field_rect, Color(0.0, 0.0, 0.0, 0.14), false, 2.0)
	return false

func _draw_hex_snapped_terrain_texture(hex_layout: Dictionary, texture: Texture2D) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var radius := float(hex_layout.get("radius", 1.0))
	var source_size := _terrain_hex_texture_source_size(texture_size)
	for row in range(HEX_ROWS):
		for column in range(HEX_COLUMNS):
			var cell := Vector2i(column, row)
			var center := _hex_center(cell, hex_layout)
			var points := _hex_points(center, radius * TERRAIN_HEX_TEXTURE_INSET)
			var bounds := _points_bounds(points)
			if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
				continue
			var source_rect := Rect2(_terrain_hex_texture_source_position(cell, texture_size, source_size), source_size)
			var uvs := PackedVector2Array()
			for point in points:
				var relative := Vector2(
					(point.x - bounds.position.x) / bounds.size.x,
					(point.y - bounds.position.y) / bounds.size.y
				)
				uvs.append(source_rect.position + Vector2(relative.x * source_rect.size.x, relative.y * source_rect.size.y))
			var shade := 0.92 + _hex_variation(cell, 43.0) * 0.10
			var modulate := Color(
				clampf(TERRAIN_TEXTURE_MODULATE.r * shade, 0.0, 1.0),
				clampf(TERRAIN_TEXTURE_MODULATE.g * shade, 0.0, 1.0),
				clampf(TERRAIN_TEXTURE_MODULATE.b * shade, 0.0, 1.0),
				TERRAIN_TEXTURE_MODULATE.a
			)
			var colors := PackedColorArray()
			for _point in points:
				colors.append(modulate)
			draw_polygon(points, colors, uvs, texture)

func _draw_hex_snapped_procedural_terrain(hex_layout: Dictionary, terrain: String) -> void:
	var radius := float(hex_layout.get("radius", 1.0))
	var base_color := _terrain_color_for(terrain)
	for row in range(HEX_ROWS):
		for column in range(HEX_COLUMNS):
			var cell := Vector2i(column, row)
			var center := _hex_center(cell, hex_layout)
			var shade := 0.88 + _hex_variation(cell, 11.0) * 0.18
			var fill := Color(
				clampf(base_color.r * shade, 0.0, 1.0),
				clampf(base_color.g * shade, 0.0, 1.0),
				clampf(base_color.b * shade, 0.0, 1.0),
				0.92
			)
			_draw_hex(center, radius * TERRAIN_HEX_FALLBACK_INSET, fill, Color(0.0, 0.0, 0.0, 0.0), 0.0)
			_draw_hex_procedural_detail(center, radius, terrain, cell)

func _draw_hex_procedural_detail(center: Vector2, radius: float, terrain: String, cell: Vector2i) -> void:
	var detail_roll := _hex_variation(cell, 29.0)
	match terrain:
		"forest":
			if detail_roll > 0.34:
				_draw_tree(center + Vector2(radius * 0.12, -radius * 0.08), radius * (0.26 + detail_roll * 0.08))
		"swamp", "mire":
			if detail_roll > 0.24:
				draw_circle(center + Vector2(radius * 0.12, radius * 0.04), radius * 0.24, Color(0.10, 0.17, 0.16, 0.28))
				draw_circle(center + Vector2(radius * 0.02, -radius * 0.04), radius * 0.12, Color(0.36, 0.42, 0.31, 0.15))
		"hills":
			if detail_roll > 0.30:
				_draw_hill(center + Vector2(0.0, radius * 0.06), radius * 0.88, radius * 0.38)
		"road":
			if cell.y == 3 or (cell.y == 2 and cell.x < 4) or (cell.y == 4 and cell.x > 6):
				draw_line(center + Vector2(-radius * 0.46, radius * 0.18), center + Vector2(radius * 0.46, -radius * 0.12), Color(0.50, 0.39, 0.24, 0.36), radius * 0.20, true)
		_:
			if detail_roll > 0.48:
				draw_line(center + Vector2(-radius * 0.26, radius * 0.22), center + Vector2(radius * 0.18, radius * 0.02), Color(0.16, 0.23, 0.12, 0.24), 1.6, true)

func _load_terrain_textures() -> void:
	for terrain_id_value in TERRAIN_TEXTURE_PATHS.keys():
		_load_terrain_texture(String(terrain_id_value))

func _load_terrain_texture(terrain_id: String) -> void:
	if _terrain_textures.has(terrain_id) or _terrain_texture_missing.has(terrain_id):
		return
	var texture_path := _terrain_texture_path_for(terrain_id)
	if texture_path == "":
		_terrain_texture_missing[terrain_id] = texture_path
		return
	if ResourceLoader.exists(texture_path):
		var resource = load(texture_path)
		if resource is Texture2D:
			_terrain_textures[terrain_id] = resource
			return
	if FileAccess.file_exists(texture_path):
		var image := Image.new()
		var load_result := image.load(texture_path)
		if load_result == OK:
			_terrain_textures[terrain_id] = ImageTexture.create_from_image(image)
			return
	_terrain_texture_missing[terrain_id] = texture_path

func _terrain_texture_for(terrain_id: String):
	var texture_id := _terrain_texture_id(terrain_id)
	if texture_id == "":
		return null
	_load_terrain_texture(texture_id)
	return _terrain_textures.get(texture_id, null)

func _terrain_texture_id(terrain_id: String) -> String:
	var normalized := terrain_id.strip_edges().to_lower()
	if normalized == "":
		normalized = "plains"
	return String(TERRAIN_TEXTURE_ALIASES.get(normalized, normalized))

func _terrain_texture_path_for(texture_id: String) -> String:
	return String(TERRAIN_TEXTURE_PATHS.get(texture_id, ""))

func _battle_terrain_id() -> String:
	var terrain_id := String(_battle.get("terrain", "plains")).strip_edges().to_lower()
	return terrain_id if terrain_id != "" else "plains"

func _terrain_color_for(terrain_id: String) -> Color:
	if TERRAIN_COLORS.has(terrain_id):
		return TERRAIN_COLORS[terrain_id]
	var texture_id := _terrain_texture_id(terrain_id)
	return TERRAIN_COLORS.get(texture_id, TERRAIN_COLORS["plains"])

func _draw_hex_grid(hex_layout: Dictionary, terrain_texture_loaded: bool) -> void:
	var radius := float(hex_layout.get("radius", 1.0))
	var distance := clampi(int(_battle.get("distance", 1)), 0, 2)
	var player_front := _front_column("player", distance)
	var enemy_front := _front_column("enemy", distance)
	for row in range(HEX_ROWS):
		for column in range(HEX_COLUMNS):
			var cell := Vector2i(column, row)
			var center := _hex_center(cell, hex_layout)
			var fill := _cell_fill_color(column, player_front, enemy_front, terrain_texture_loaded)
			if terrain_texture_loaded:
				_draw_hex(center, radius * TERRAIN_HEX_TEXTURE_INSET, fill, Color(0.0, 0.0, 0.0, 0.0), 0.0)
			else:
				_draw_hex(center, radius * 0.96, fill, HEX_LINE_COLOR, 1.6)
			if column >= player_front and column <= enemy_front:
				var lane_alpha := TEXTURED_MID_LANE_FILL_ALPHA if terrain_texture_loaded else 0.035
				_draw_hex(center, radius * 0.82, Color(0.93, 0.79, 0.47, lane_alpha), Color(0.0, 0.0, 0.0, 0.0), 0.0)

	if terrain_texture_loaded:
		_draw_unique_hex_grid_lines(hex_layout, TEXTURED_HEX_LINE_COLOR, 1.05, TERRAIN_HEX_TEXTURE_INSET)

	for row in range(HEX_ROWS):
		var center_cell := Vector2i(int(HEX_COLUMNS / 2), row)
		var center_color := TEXTURED_HEX_CENTER_LINE if terrain_texture_loaded else HEX_CENTER_LINE
		var center_width := 1.1 if terrain_texture_loaded else 1.4
		_draw_hex_outline(_hex_center(center_cell, hex_layout), radius * 0.98, center_color, center_width)

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
	var player_input_active := String(_active_stack.get("side", "")) == "player"

	if player_input_active:
		for destination in BattleRulesScript.legal_destinations_for_active_stack(_battle):
			if not (destination is Dictionary):
				continue
			var cell := Vector2i(int(destination.get("q", -1)), int(destination.get("r", -1)))
			if not _cell_in_bounds(cell):
				continue
			_draw_hex(_hex_center(cell, hex_layout), radius * 0.78, Color(MOVE_COLOR.r, MOVE_COLOR.g, MOVE_COLOR.b, 0.16), MOVE_COLOR, 1.8)

	_draw_hex_outline(active_center, radius * 1.02, ACTIVE_COLOR, 3.4)

	if player_input_active:
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

	if player_input_active and not _target_stack.is_empty():
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

func _draw_unique_hex_grid_lines(hex_layout: Dictionary, stroke: Color, width: float, radius_scale: float) -> void:
	var radius := float(hex_layout.get("radius", 1.0)) * radius_scale
	var drawn_edges := {}
	for row in range(HEX_ROWS):
		for column in range(HEX_COLUMNS):
			var cell := Vector2i(column, row)
			var points := _hex_points(_hex_center(cell, hex_layout), radius)
			for index in range(points.size()):
				var start := points[index]
				var end := points[(index + 1) % points.size()]
				var edge_key := _edge_key(start, end)
				if drawn_edges.has(edge_key):
					continue
				drawn_edges[edge_key] = true
				draw_line(start, end, stroke, width, true)

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

func _points_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_position := points[0]
	var max_position := points[0]
	for point in points:
		min_position.x = minf(min_position.x, point.x)
		min_position.y = minf(min_position.y, point.y)
		max_position.x = maxf(max_position.x, point.x)
		max_position.y = maxf(max_position.y, point.y)
	return Rect2(min_position, max_position - min_position)

func _edge_key(start: Vector2, end: Vector2) -> String:
	var start_key := _point_grid_key(start)
	var end_key := _point_grid_key(end)
	if start_key.x > end_key.x or (start_key.x == end_key.x and start_key.y > end_key.y):
		var swap_key := start_key
		start_key = end_key
		end_key = swap_key
	return "%d:%d|%d:%d" % [start_key.x, start_key.y, end_key.x, end_key.y]

func _point_grid_key(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x * 10.0), roundi(point.y * 10.0))

func _terrain_hex_texture_source_size(texture_size: Vector2) -> Vector2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Vector2.ZERO
	var source_height: float = clampf(texture_size.y * 0.24, 48.0, texture_size.y)
	var source_width: float = clampf(source_height * 0.92, 48.0, texture_size.x)
	return Vector2(source_width, source_height)

func _terrain_hex_texture_source_position(cell: Vector2i, texture_size: Vector2, source_size: Vector2) -> Vector2:
	var usable := Vector2(maxf(0.0, texture_size.x - source_size.x), maxf(0.0, texture_size.y - source_size.y))
	return Vector2(
		floor(usable.x * _hex_variation(cell, 3.0)),
		floor(usable.y * _hex_variation(cell, 17.0))
	)

func _hex_variation(cell: Vector2i, salt: float) -> float:
	var value := sin(float(cell.x) * 12.9898 + float(cell.y) * 78.233 + salt) * 43758.5453
	return value - floor(value)

func _terrain_hex_tile_count() -> int:
	return HEX_COLUMNS * HEX_ROWS

func _terrain_rendering_mode(texture_loaded: bool) -> String:
	return "hex_snapped_texture" if texture_loaded else "hex_snapped_color_fallback"

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

func _cell_fill_color(column: int, player_front: int, enemy_front: int, terrain_texture_loaded: bool = false) -> Color:
	if terrain_texture_loaded:
		if column < player_front:
			return Color(0.13, 0.25, 0.31, TEXTURED_DEPLOYMENT_FILL_ALPHA)
		if column > enemy_front:
			return Color(0.34, 0.13, 0.12, TEXTURED_DEPLOYMENT_FILL_ALPHA)
		if column == int(HEX_COLUMNS / 2):
			return Color(0.50, 0.38, 0.18, TEXTURED_CENTER_FILL_ALPHA)
		return Color(0.09, 0.12, 0.10, 0.0)
	if column < player_front:
		return Color(0.13, 0.25, 0.31, 0.22)
	if column > enemy_front:
		return Color(0.34, 0.13, 0.12, 0.22)
	if column == int(HEX_COLUMNS / 2):
		return Color(0.50, 0.38, 0.18, 0.18)
	return Color(0.09, 0.12, 0.10, 0.12)

func _terrain_texture_visible(texture_loaded: bool) -> bool:
	return texture_loaded \
		and not _terrain_grid_repaints_texture_cells(texture_loaded) \
		and TERRAIN_TEXTURE_MODULATE.a >= 0.94 \
		and TERRAIN_TEXTURE_READABILITY_WASH.a <= 0.08 \
		and TERRAIN_HEX_TEXTURE_INSET >= 0.995

func _terrain_grid_fill_mode(texture_loaded: bool) -> String:
	return "texture_transparent_tactical_tint" if texture_loaded else "fallback_readability_fill"

func _terrain_grid_border_mode(texture_loaded: bool) -> String:
	return "deduplicated_texture_grid" if texture_loaded else "per_cell_fallback_grid"

func _terrain_grid_border_deduplicated(texture_loaded: bool) -> bool:
	return texture_loaded

func _terrain_grid_repaints_texture_cells(texture_loaded: bool) -> bool:
	return texture_loaded and _terrain_grid_max_fill_alpha(texture_loaded) > TEXTURED_GRID_MAX_CELL_FILL_ALPHA

func _terrain_grid_max_fill_alpha(texture_loaded: bool) -> float:
	var distance := clampi(int(_battle.get("distance", 1)), 0, 2)
	var player_front := _front_column("player", distance)
	var enemy_front := _front_column("enemy", distance)
	var max_alpha := 0.0
	for column in range(HEX_COLUMNS):
		var fill := _cell_fill_color(column, player_front, enemy_front, texture_loaded)
		max_alpha = maxf(max_alpha, fill.a)
		if column >= player_front and column <= enemy_front:
			max_alpha = maxf(max_alpha, TEXTURED_MID_LANE_FILL_ALPHA if texture_loaded else 0.035)
	return max_alpha

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
	var hex_layout := _current_hex_layout()
	var radius := float(hex_layout.get("radius", 1.0))
	var best_cell := Vector2i(-1, -1)
	var best_distance := 999999.0
	for row in range(HEX_ROWS):
		for column in range(HEX_COLUMNS):
			var cell := Vector2i(column, row)
			var center := _hex_center(cell, hex_layout)
			if not Geometry2D.is_point_in_polygon(position, _hex_points(center, radius)):
				continue
			var distance := position.distance_to(center)
			if distance < best_distance:
				best_distance = distance
				best_cell = cell
	if best_cell.x >= 0:
		return best_cell

	best_distance = radius * 0.92
	for row in range(HEX_ROWS):
		for column in range(HEX_COLUMNS):
			var cell := Vector2i(column, row)
			var distance := position.distance_to(_hex_center(cell, hex_layout))
			if distance <= best_distance:
				best_distance = distance
				best_cell = cell
	return best_cell

func _current_hex_layout() -> Dictionary:
	var board_rect := Rect2(Vector2(14.0, 14.0), size - Vector2(28.0, 28.0))
	var field_rect := board_rect.grow(-12.0)
	return _hex_layout(_hex_field_rect(field_rect))

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
	var active_side := String(_active_stack.get("side", ""))
	if active_side != "" and active_side != "player":
		return "Input locked"
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
	if String(_active_stack.get("side", "")) != "player":
		return ""
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
	var active_side := String(_active_stack.get("side", ""))
	if active_side != "" and active_side != "player":
		if battle_id == String(_battle.get("active_stack_id", "")):
			return "Active: %s. It is not the player's turn." % String(stack.get("name", "Stack"))
		return "%s is %s stack. It is not the player's turn." % [
			String(stack.get("name", "Stack")),
			"a friendly" if side == "player" else "an enemy",
		]
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

func _movement_board_tooltip(cell: Vector2i) -> String:
	var movement_intent := BattleRulesScript.movement_intent_for_destination(_battle, cell.x, cell.y)
	var message := String(movement_intent.get("message", ""))
	return message if message != "" else tooltip_text

func _fallback_board_tooltip() -> String:
	if String(_active_stack.get("side", "")) != "" and String(_active_stack.get("side", "")) != "player":
		return "Input locked: it is not the player's turn."
	return tooltip_text

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

func _stack_id_at_cell(cell: Vector2i) -> String:
	if not _cell_in_bounds(cell):
		return ""
	var stack_cells := _stack_cells()
	for stack in _all_visible_stacks():
		if not (stack is Dictionary):
			continue
		var battle_id := String(stack.get("battle_id", ""))
		if battle_id == "":
			continue
		var stack_cell: Vector2i = stack_cells.get(battle_id, Vector2i(-1, -1))
		if stack_cell == cell:
			return battle_id
	return ""

func _stack_cell_for_battle_id(battle_id: String) -> Vector2i:
	if battle_id == "":
		return Vector2i(-1, -1)
	var stack_cells := _stack_cells()
	return stack_cells.get(battle_id, Vector2i(-1, -1))

func _validation_click_position_for_cell(cell: Vector2i) -> Dictionary:
	var layout := _current_hex_layout()
	var center := _hex_center(cell, layout)
	var radius := float(layout.get("radius", 1.0))
	var fallback_position := center
	var angles := [0.0, 60.0, 120.0, 180.0, 240.0, 300.0, 30.0, 90.0, 150.0, 210.0, 270.0, 330.0]
	for factor in [0.91, 0.86, 0.80, 0.72, 0.64, 0.56, 0.48]:
		for angle_degrees in angles:
			var angle := deg_to_rad(float(angle_degrees))
			var position := center + Vector2(cos(angle), sin(angle)) * radius * float(factor)
			if _hex_cell_at_position(position) != cell:
				continue
			fallback_position = position
			if _stack_id_at_position(position) == "":
				return {
					"position": position,
					"found_shape_miss_position": true,
					"hex_radius": radius,
				}
	return {
		"position": fallback_position,
		"found_shape_miss_position": false,
		"hex_radius": radius,
	}

func _validation_outer_ring_click_position_for_cell(cell: Vector2i) -> Dictionary:
	var layout := _current_hex_layout()
	var center := _hex_center(cell, layout)
	var radius := float(layout.get("radius", 1.0))
	var angles := [30.0, 90.0, 150.0, 210.0, 270.0, 330.0, 0.0, 60.0, 120.0, 180.0, 240.0, 300.0]
	for factor in [0.99, 0.97, 0.95, 0.93]:
		for angle_degrees in angles:
			var angle := deg_to_rad(float(angle_degrees))
			var position := center + Vector2(cos(angle), sin(angle)) * radius * float(factor)
			if position.distance_to(center) <= radius * 0.92:
				continue
			if _hex_cell_at_position(position) != cell:
				continue
			if _stack_id_at_position(position) != "":
				continue
			return {
				"position": position,
				"found_outer_ring_position": true,
				"radius_factor": float(factor),
				"hex_radius": radius,
			}
	return {}

func _validation_overlapped_destination_click_position_for_cell(cell: Vector2i, overlap_side: String = "player") -> Dictionary:
	if not _is_legal_destination_cell(cell):
		return {}
	var layout := _current_hex_layout()
	var center := _hex_center(cell, layout)
	var radius := float(layout.get("radius", 1.0))
	var stack_cells := _stack_cells()
	var candidate_ids := []
	var active_id := String(_battle.get("active_stack_id", ""))
	if active_id != "" and overlap_side == "player":
		candidate_ids.append(active_id)
	for stack in _all_visible_stacks():
		if not (stack is Dictionary):
			continue
		var battle_id := String(stack.get("battle_id", ""))
		if battle_id == "" or battle_id in candidate_ids:
			continue
		if overlap_side != "" and String(stack.get("side", "")) != overlap_side:
			continue
		candidate_ids.append(battle_id)
	for battle_id in candidate_ids:
		var stack_cell: Vector2i = stack_cells.get(String(battle_id), Vector2i(-1, -1))
		if not _cell_in_bounds(stack_cell) or stack_cell == cell:
			continue
		var stack_center := _hex_center(stack_cell, layout)
		var toward_stack := stack_center - center
		if toward_stack.length() <= 0.01:
			continue
		var direction := toward_stack.normalized()
		for factor in [0.86, 0.84, 0.82, 0.78, 0.74, 0.70, 0.66, 0.62, 0.58, 0.54, 0.50]:
			var position := center + direction * radius * float(factor)
			if _hex_cell_at_position(position) != cell:
				continue
			var overlap_id := _stack_id_at_position(position)
			if overlap_id == "":
				continue
			if overlap_side != "" and String(_stack_by_id(overlap_id).get("side", "")) != overlap_side:
				continue
			var overlap_result := {
				"position": position,
				"found_shape_overlap": true,
				"radius_factor": float(factor),
				"hex_radius": radius,
			}
			overlap_result["found_%s_shape_overlap" % overlap_side] = true
			return overlap_result
	return {}

func _validation_overlapped_occupied_hex_click_position_for_cell(cell: Vector2i, overlap_side: String = "enemy") -> Dictionary:
	var cell_battle_id := _stack_id_at_cell(cell)
	if cell_battle_id == "":
		return {}
	var layout := _current_hex_layout()
	var center := _hex_center(cell, layout)
	var radius := float(layout.get("radius", 1.0))
	var stack_cells := _stack_cells()
	var candidate_ids := []
	for stack in _all_visible_stacks():
		if not (stack is Dictionary):
			continue
		var battle_id := String(stack.get("battle_id", ""))
		if battle_id == "" or battle_id == cell_battle_id:
			continue
		if overlap_side != "" and String(stack.get("side", "")) != overlap_side:
			continue
		candidate_ids.append(battle_id)
	for battle_id in candidate_ids:
		var stack_cell: Vector2i = stack_cells.get(String(battle_id), Vector2i(-1, -1))
		if not _cell_in_bounds(stack_cell) or stack_cell == cell:
			continue
		var stack_center := _hex_center(stack_cell, layout)
		var toward_stack := stack_center - center
		if toward_stack.length() <= 0.01:
			continue
		var direction := toward_stack.normalized()
		for factor in [0.86, 0.84, 0.82, 0.78, 0.74, 0.70, 0.66, 0.62, 0.58, 0.54, 0.50]:
			var position := center + direction * radius * float(factor)
			if _hex_cell_at_position(position) != cell:
				continue
			var overlap_id := _stack_id_at_position(position)
			if overlap_id == "" or overlap_id == cell_battle_id:
				continue
			if overlap_side != "" and String(_stack_by_id(overlap_id).get("side", "")) != overlap_side:
				continue
			var overlap_result := {
				"position": position,
				"found_shape_overlap": true,
				"radius_factor": float(factor),
				"hex_radius": radius,
			}
			overlap_result["found_%s_shape_overlap" % overlap_side] = true
			return overlap_result
	return {}

func _validation_fallback_tooltip_position() -> Vector2:
	var candidates := [
		Vector2(4.0, 4.0),
		Vector2(maxf(4.0, size.x - 4.0), 4.0),
		Vector2(4.0, maxf(4.0, size.y - 4.0)),
		Vector2(maxf(4.0, size.x - 4.0), maxf(4.0, size.y - 4.0)),
		Vector2(size.x * 0.5, 20.0),
		Vector2(size.x * 0.5, maxf(20.0, size.y - 20.0)),
	]
	for position in candidates:
		if position.x < 0.0 or position.y < 0.0 or position.x > size.x or position.y > size.y:
			continue
		if _hex_cell_at_position(position).x >= 0:
			continue
		if _stack_id_at_position(position) != "":
			continue
		return position
	return Vector2(-1.0, -1.0)

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
