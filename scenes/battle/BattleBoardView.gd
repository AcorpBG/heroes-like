extends Control

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")

const FRAME_FILL := Color(0.05, 0.06, 0.08, 1.0)
const BOARD_FILL := Color(0.09, 0.11, 0.12, 1.0)
const FRAME_COLOR := Color(0.82, 0.67, 0.37, 0.94)
const TEXT_COLOR := Color(0.96, 0.94, 0.89, 1.0)
const SUBTEXT_COLOR := Color(0.83, 0.87, 0.91, 0.95)
const PLAYER_COLOR := Color(0.42, 0.66, 0.90, 0.95)
const ENEMY_COLOR := Color(0.84, 0.38, 0.33, 0.95)
const NEUTRAL_COLOR := Color(0.68, 0.72, 0.78, 0.95)
const ACTIVE_COLOR := Color(0.99, 0.88, 0.48, 1.0)
const TARGET_COLOR := Color(0.97, 0.64, 0.38, 0.96)
const TERRAIN_COLORS := {
	"plains": Color(0.29, 0.38, 0.24, 1.0),
	"forest": Color(0.19, 0.31, 0.22, 1.0),
	"swamp": Color(0.25, 0.29, 0.20, 1.0),
	"hills": Color(0.36, 0.31, 0.23, 1.0),
	"road": Color(0.35, 0.30, 0.24, 1.0),
}

var _session = null
var _battle: Dictionary = {}
var _player_stacks: Array = []
var _enemy_stacks: Array = []
var _active_stack: Dictionary = {}
var _target_stack: Dictionary = {}
var _field_objectives: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(720, 350)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func set_battle_state(session) -> void:
	_session = session
	_battle = {}
	_player_stacks = []
	_enemy_stacks = []
	_active_stack = {}
	_target_stack = {}
	_field_objectives = []
	if session != null and session.battle is Dictionary:
		_battle = session.battle
		_active_stack = BattleRulesScript.get_active_stack(_battle)
		_target_stack = BattleRulesScript.get_selected_target(_battle)
		_field_objectives = _battle.get(BattleRulesScript.FIELD_OBJECTIVES_KEY, []).duplicate(true) if _battle.get(BattleRulesScript.FIELD_OBJECTIVES_KEY, []) is Array else []
		for stack in _battle.get("stacks", []):
			if not (stack is Dictionary) or int(stack.get("count", 0)) <= 0:
				continue
			if String(stack.get("side", "")) == "player":
				_player_stacks.append(stack)
			elif String(stack.get("side", "")) == "enemy":
				_enemy_stacks.append(stack)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FRAME_FILL, true)
	if _battle.is_empty():
		return

	var board_rect := Rect2(Vector2(14.0, 14.0), size - Vector2(28.0, 28.0))
	draw_rect(board_rect, BOARD_FILL, true)
	draw_rect(board_rect, FRAME_COLOR, false, 3.0)

	var field_rect := board_rect.grow(-14.0)
	_draw_terrain(field_rect)
	_draw_turn_strip(field_rect)
	_draw_distance_bands(field_rect)
	_draw_lane_guides(field_rect)
	_draw_field_objectives(field_rect)
	_draw_side_stack_cards(field_rect, _player_stacks, "player")
	_draw_side_stack_cards(field_rect, _enemy_stacks, "enemy")
	_draw_focus_link(field_rect)
	_draw_footer_line(field_rect)

func _draw_terrain(field_rect: Rect2) -> void:
	var terrain := String(_battle.get("terrain", "plains"))
	var base_color: Color = TERRAIN_COLORS.get(terrain, TERRAIN_COLORS["plains"])
	draw_rect(field_rect, base_color, true)
	for band in range(4):
		var overlay_rect := Rect2(
			field_rect.position + Vector2(0.0, float(band) * field_rect.size.y * 0.25),
			Vector2(field_rect.size.x, field_rect.size.y * 0.12)
		)
		draw_rect(overlay_rect, Color(0.0, 0.0, 0.0, 0.05 + float(band) * 0.01), true)
	if terrain == "forest":
		for index in range(7):
			var center := field_rect.position + Vector2(field_rect.size.x * (0.10 + float(index) * 0.12), field_rect.size.y * (0.20 + float(index % 3) * 0.20))
			var crown = PackedVector2Array([
				center + Vector2(0.0, -16.0),
				center + Vector2(14.0, 8.0),
				center + Vector2(-14.0, 8.0),
			])
			draw_colored_polygon(crown, Color(0.12, 0.22, 0.15, 0.52))
	elif terrain == "swamp":
		for index in range(5):
			var puddle := Rect2(
				field_rect.position + Vector2(field_rect.size.x * (0.14 + float(index) * 0.15), field_rect.size.y * (0.24 + float(index % 2) * 0.24)),
				Vector2(54.0, 16.0)
			)
			draw_rect(puddle, Color(0.17, 0.24, 0.22, 0.44), true)

func _draw_turn_strip(field_rect: Rect2) -> void:
	var strip_rect := Rect2(field_rect.position + Vector2(10.0, 10.0), Vector2(field_rect.size.x - 20.0, 36.0))
	draw_rect(strip_rect, Color(0.10, 0.12, 0.15, 0.88), true)
	draw_rect(strip_rect, FRAME_COLOR, false, 2.0)
	var turn_order = _battle.get("turn_order", [])
	if not (turn_order is Array):
		return
	var chip_width: float = min(116.0, (strip_rect.size.x - 18.0) / float(max(1, min(turn_order.size(), 6))))
	var drawn := 0
	for battle_id_value in turn_order:
		if drawn >= 6:
			break
		var stack: Dictionary = _stack_by_id(String(battle_id_value))
		if stack.is_empty() or int(stack.get("count", 0)) <= 0:
			continue
		var rect := Rect2(
			strip_rect.position + Vector2(8.0 + float(drawn) * chip_width, 6.0),
			Vector2(chip_width - 6.0, strip_rect.size.y - 12.0)
		)
		var fill := _side_color(String(stack.get("side", ""))).darkened(0.16)
		if String(stack.get("battle_id", "")) == String(_battle.get("active_stack_id", "")):
			fill = ACTIVE_COLOR
		draw_rect(rect, fill, true)
		draw_rect(rect, Color(0.11, 0.14, 0.18, 0.84), false, 2.0)
		_draw_text(_stack_short_label(stack), rect.position + Vector2(8.0, 17.0), TEXT_COLOR, 11)
		_draw_text("x%d" % int(stack.get("count", 0)), rect.position + Vector2(8.0, 31.0), Color(0.13, 0.17, 0.20, 0.96), 12)
		drawn += 1

func _draw_distance_bands(field_rect: Rect2) -> void:
	var fight_rect := _fight_rect(field_rect)
	var distance := clampi(int(_battle.get("distance", 1)), 0, 2)
	var gap_ratio: float = [0.10, 0.18, 0.28][distance]
	var gap_width: float = fight_rect.size.x * gap_ratio
	var center_x := fight_rect.get_center().x
	var no_mans_land := Rect2(
		Vector2(center_x - gap_width * 0.5, fight_rect.position.y),
		Vector2(gap_width, fight_rect.size.y)
	)
	draw_rect(no_mans_land, Color(0.82, 0.78, 0.68, 0.08), true)
	draw_rect(no_mans_land, Color(0.94, 0.88, 0.70, 0.22), false, 2.0)
	var label := "Engaged" if distance == 0 else ("Closing" if distance == 1 else "Long lane")
	_draw_text(label, Vector2(no_mans_land.position.x + 12.0, no_mans_land.position.y + 22.0), SUBTEXT_COLOR, 12)

func _draw_lane_guides(field_rect: Rect2) -> void:
	var fight_rect := _fight_rect(field_rect)
	for lane in range(3):
		var y := fight_rect.position.y + fight_rect.size.y * (0.23 + float(lane) * 0.27)
		draw_line(Vector2(fight_rect.position.x, y), Vector2(fight_rect.end.x, y), Color(0.95, 0.95, 0.95, 0.10), 2.0)

func _draw_field_objectives(field_rect: Rect2) -> void:
	var fight_rect := _fight_rect(field_rect)
	var markers: int = min(_field_objectives.size(), 3)
	for index in range(markers):
		var objective: Dictionary = _field_objectives[index]
		if not (objective is Dictionary):
			continue
		var center := Vector2(
			fight_rect.position.x + fight_rect.size.x * (0.40 + float(index) * 0.10),
			fight_rect.position.y + fight_rect.size.y * (0.26 + float(index % 2) * 0.34)
		)
		var color := _controller_color(String(objective.get("controller", "neutral")))
		_draw_objective_marker(center, String(objective.get("type", "")), color)
		_draw_text(_objective_short_label(objective), center + Vector2(-18.0, 26.0), SUBTEXT_COLOR, 11)

func _draw_objective_marker(center: Vector2, objective_type: String, color: Color) -> void:
	match objective_type:
		"cover_line":
			draw_rect(Rect2(center - Vector2(18.0, 10.0), Vector2(36.0, 20.0)), color, true)
			draw_rect(Rect2(center - Vector2(18.0, 10.0), Vector2(36.0, 20.0)), Color(0.10, 0.13, 0.16, 0.82), false, 2.0)
		"obstruction_line":
			draw_line(center + Vector2(-18.0, -12.0), center + Vector2(18.0, 12.0), color, 4.0)
			draw_line(center + Vector2(18.0, -12.0), center + Vector2(-18.0, 12.0), color, 4.0)
			draw_circle(center, 4.0, TEXT_COLOR)
		_:
			draw_circle(center, 14.0, color)
			draw_circle(center, 14.0, Color(0.10, 0.13, 0.16, 0.84), false, 2.0)

func _draw_side_stack_cards(field_rect: Rect2, stacks: Array, side: String) -> void:
	if stacks.is_empty():
		return
	var fight_rect := _fight_rect(field_rect)
	var gap := 12.0
	var card_height := clampf((fight_rect.size.y - gap * float(max(0, stacks.size() - 1))) / float(stacks.size()), 44.0, 62.0)
	var card_width: float = min(180.0, fight_rect.size.x * 0.24)
	var distance_offset := float(2 - clampi(int(_battle.get("distance", 1)), 0, 2)) * 32.0
	var x: float = fight_rect.position.x + 10.0 + distance_offset if side == "player" else fight_rect.end.x - card_width - 10.0 - distance_offset
	for index in range(stacks.size()):
		var stack: Dictionary = stacks[index]
		if not (stack is Dictionary):
			continue
		var y := fight_rect.position.y + float(index) * (card_height + gap)
		var rect := Rect2(Vector2(x, y), Vector2(card_width, card_height))
		var fill := _side_color(side).darkened(0.14)
		if String(stack.get("battle_id", "")) == String(_battle.get("active_stack_id", "")):
			fill = ACTIVE_COLOR
		elif String(stack.get("battle_id", "")) == String(_battle.get("selected_target_id", "")):
			fill = TARGET_COLOR
		draw_rect(rect, fill, true)
		draw_rect(rect, Color(0.10, 0.13, 0.16, 0.84), false, 2.0)
		var hp_ratio := 0.0
		var total_health: int = max(1, int(stack.get("total_health", 1)))
		var base_health: int = max(1, int(stack.get("hp", 1)) * max(1, int(stack.get("count", 1))))
		hp_ratio = clampf(float(total_health) / float(base_health), 0.0, 1.0)
		var hp_bar := Rect2(rect.position + Vector2(8.0, rect.size.y - 12.0), Vector2((rect.size.x - 16.0) * hp_ratio, 5.0))
		draw_rect(Rect2(rect.position + Vector2(8.0, rect.size.y - 12.0), Vector2(rect.size.x - 16.0, 5.0)), Color(0.08, 0.10, 0.12, 0.55), true)
		draw_rect(hp_bar, Color(0.94, 0.79, 0.39, 0.92), true)
		_draw_text(_stack_short_label(stack), rect.position + Vector2(8.0, 17.0), TEXT_COLOR, 13)
		_draw_text("x%d | HP %d" % [int(stack.get("count", 0)), total_health], rect.position + Vector2(8.0, 33.0), SUBTEXT_COLOR, 11)
		var role: String = "RNG %d" % int(stack.get("shots_remaining", 0)) if bool(stack.get("ranged", false)) else "RET %d" % int(stack.get("retaliations_left", 0))
		if bool(stack.get("defending", false)):
			role += " | DEF"
		_draw_text(role, rect.position + Vector2(8.0, 47.0), Color(0.13, 0.17, 0.20, 0.96), 10)

func _draw_focus_link(field_rect: Rect2) -> void:
	if _active_stack.is_empty() or _target_stack.is_empty():
		return
	var active_side := String(_active_stack.get("side", ""))
	var fight_rect := _fight_rect(field_rect)
	var start_x := fight_rect.position.x + fight_rect.size.x * (0.31 if active_side == "player" else 0.69)
	var end_x := fight_rect.position.x + fight_rect.size.x * (0.69 if active_side == "player" else 0.31)
	var start_y := fight_rect.position.y + _stack_vertical_center(_active_stack, active_side, fight_rect)
	var end_y := fight_rect.position.y + _stack_vertical_center(_target_stack, String(_target_stack.get("side", "")), fight_rect)
	var color := ACTIVE_COLOR if active_side == "player" else TARGET_COLOR
	draw_line(Vector2(start_x, start_y), Vector2(end_x, end_y), color, 3.0)
	draw_circle(Vector2(end_x, end_y), 6.0, color)

func _draw_footer_line(field_rect: Rect2) -> void:
	var footer_rect := Rect2(field_rect.position + Vector2(10.0, field_rect.end.y - 34.0), Vector2(field_rect.size.x - 20.0, 24.0))
	draw_rect(footer_rect, Color(0.10, 0.12, 0.15, 0.88), true)
	draw_rect(footer_rect, FRAME_COLOR, false, 2.0)
	var summary := "%s | Round %d/%d | %s" % [
		String(_battle.get("encounter_name", "Battle")),
		int(_battle.get("round", 1)),
		int(_battle.get("max_rounds", 12)),
		String(_battle.get("terrain", "plains")).capitalize(),
	]
	_draw_text(summary, footer_rect.position + Vector2(10.0, 17.0), SUBTEXT_COLOR, 12)

func _fight_rect(field_rect: Rect2) -> Rect2:
	return Rect2(
		field_rect.position + Vector2(0.0, 54.0),
		Vector2(field_rect.size.x, field_rect.size.y - 88.0)
	)

func _stack_vertical_center(stack: Dictionary, side: String, fight_rect: Rect2) -> float:
	var stacks := _player_stacks if side == "player" else _enemy_stacks
	var gap := 12.0
	var card_height := clampf((fight_rect.size.y - gap * float(max(0, stacks.size() - 1))) / float(max(1, stacks.size())), 44.0, 62.0)
	for index in range(stacks.size()):
		var entry = stacks[index]
		if entry is Dictionary and String(entry.get("battle_id", "")) == String(stack.get("battle_id", "")):
			return float(index) * (card_height + gap) + card_height * 0.5
	return fight_rect.size.y * 0.5

func _stack_by_id(battle_id: String) -> Dictionary:
	for stack in _battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			return stack
	return {}

func _stack_short_label(stack: Dictionary) -> String:
	var name := String(stack.get("name", stack.get("unit_id", "Stack")))
	return name.left(16)

func _objective_short_label(objective: Dictionary) -> String:
	var objective_type := String(objective.get("type", ""))
	match objective_type:
		"cover_line":
			return "CVR"
		"obstruction_line":
			return "OBS"
		"lane_battery":
			return "BAT"
		"hazard_zone":
			return "HAZ"
		"signal_beacon":
			return "SIG"
		_:
			return String(objective.get("label", objective_type)).left(3).to_upper()

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

func _draw_text(text: String, position: Vector2, color: Color, font_size: int) -> void:
	var font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
