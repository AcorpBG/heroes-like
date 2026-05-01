extends Control

const TownRulesScript = preload("res://scripts/core/TownRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")

const FRAME_FILL := Color(0.05, 0.07, 0.09, 1.0)
const BOARD_FILL := Color(0.09, 0.11, 0.12, 1.0)
const FRAME_COLOR := Color(0.78, 0.66, 0.38, 0.94)
const SKY_COLOR := Color(0.16, 0.23, 0.31, 1.0)
const HAZE_COLOR := Color(0.40, 0.54, 0.58, 0.16)
const GROUND_COLOR := Color(0.20, 0.25, 0.17, 1.0)
const ROAD_COLOR := Color(0.42, 0.33, 0.22, 0.95)
const STONE_COLOR := Color(0.63, 0.63, 0.64, 1.0)
const STONE_SHADOW := Color(0.22, 0.24, 0.28, 1.0)
const WINDOW_GLOW := Color(0.99, 0.86, 0.52, 0.95)
const TEXT_COLOR := Color(0.96, 0.94, 0.88, 1.0)
const SUBTEXT_COLOR := Color(0.84, 0.87, 0.90, 0.96)
const PANEL_TEXT := Color(0.17, 0.21, 0.25, 0.92)
const FACTION_COLORS := {
	"faction_embercourt": Color(0.86, 0.48, 0.23, 1.0),
	"faction_mireclaw": Color(0.39, 0.69, 0.30, 1.0),
	"faction_sunvault": Color(0.84, 0.70, 0.26, 1.0),
	"faction_thornwake": Color(0.46, 0.62, 0.35, 1.0),
	"faction_brasshollow": Color(0.70, 0.52, 0.31, 1.0),
	"faction_veilmourn": Color(0.42, 0.52, 0.62, 1.0),
}
const DISTRICT_ORDER := ["military", "economy", "spellcraft", "logistics", "defense"]
const DISTRICT_LABELS := {
	"military": "WAR",
	"economy": "COIN",
	"spellcraft": "MAG",
	"logistics": "ROAD",
	"defense": "WALL",
}
const DISTRICT_COLORS := {
	"military": Color(0.71, 0.34, 0.28, 0.94),
	"economy": Color(0.76, 0.60, 0.29, 0.94),
	"spellcraft": Color(0.42, 0.55, 0.84, 0.94),
	"logistics": Color(0.33, 0.62, 0.56, 0.94),
	"defense": Color(0.53, 0.58, 0.66, 0.94),
}

var _session = null
var _town: Dictionary = {}
var _town_template: Dictionary = {}
var _faction: Dictionary = {}
var _stationed: Array = []
var _build_actions: Array = []
var _recruit_actions: Array = []
var _response_actions: Array = []
var _study_actions: Array = []
var _market_actions: Array = []
var _logistics: Dictionary = {}
var _recovery: Dictionary = {}
var _threat: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(620, 320)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func set_town_state(session) -> void:
	_clear_town_state(session)
	if session != null:
		_town = TownRulesScript.get_active_town(session)
		if not _town.is_empty():
			_town_template = ContentService.get_town(String(_town.get("town_id", "")))
			_faction = ContentService.get_faction(String(_town_template.get("faction_id", "")))
			_stationed = HeroCommandRulesScript.stationed_heroes(session, _town)
			_build_actions = TownRulesScript.get_build_actions(session)
			_recruit_actions = TownRulesScript.get_recruit_actions(session)
			_response_actions = TownRulesScript.get_response_actions(session)
			_study_actions = TownRulesScript.get_spell_learning_actions(session)
			_market_actions = TownRulesScript.get_market_actions(session)
			_logistics = OverworldRulesScript.town_logistics_state(session, _town)
			_recovery = OverworldRulesScript.town_recovery_state(session, _town)
			_threat = OverworldRulesScript.town_public_threat_state(session, _town)
	queue_redraw()

func set_precomputed_town_state(session, state: Dictionary) -> void:
	_clear_town_state(session)
	if state.is_empty():
		queue_redraw()
		return
	_town = _duplicate_dictionary(state.get("town", {}))
	_town_template = _duplicate_dictionary(state.get("town_template", {}))
	_faction = _duplicate_dictionary(state.get("faction", {}))
	_stationed = _duplicate_array(state.get("stationed", []))
	_build_actions = _duplicate_array(state.get("build_actions", []))
	_recruit_actions = _duplicate_array(state.get("recruit_actions", []))
	_response_actions = _duplicate_array(state.get("response_actions", []))
	_study_actions = _duplicate_array(state.get("study_actions", []))
	_market_actions = _duplicate_array(state.get("market_actions", []))
	_logistics = _duplicate_dictionary(state.get("logistics", {}))
	_recovery = _duplicate_dictionary(state.get("recovery", {}))
	_threat = _duplicate_dictionary(state.get("threat", {}))
	queue_redraw()

func _clear_town_state(session) -> void:
	_session = session
	_town = {}
	_town_template = {}
	_faction = {}
	_stationed = []
	_build_actions = []
	_recruit_actions = []
	_response_actions = []
	_study_actions = []
	_market_actions = []
	_logistics = {}
	_recovery = {}
	_threat = {}

func _duplicate_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _duplicate_array(value: Variant) -> Array:
	return value.duplicate(true) if value is Array else []

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FRAME_FILL, true)
	if _town.is_empty():
		return

	var board_rect := Rect2(Vector2(14.0, 14.0), size - Vector2(28.0, 28.0))
	draw_rect(board_rect, BOARD_FILL, true)
	draw_rect(board_rect, FRAME_COLOR, false, 3.0)

	var scene_rect := board_rect.grow(-12.0)
	var horizon_y := scene_rect.position.y + scene_rect.size.y * 0.58
	var sky_rect := Rect2(scene_rect.position, Vector2(scene_rect.size.x, horizon_y - scene_rect.position.y))
	var ground_rect := Rect2(Vector2(scene_rect.position.x, horizon_y), Vector2(scene_rect.size.x, scene_rect.end.y - horizon_y))
	draw_rect(sky_rect, SKY_COLOR, true)
	draw_rect(ground_rect, GROUND_COLOR, true)
	_draw_haze(scene_rect)
	_draw_roads(ground_rect)
	_draw_city(scene_rect, ground_rect)
	_draw_status_plaques(scene_rect)
	_draw_district_strip(scene_rect)
	_draw_command_markers(scene_rect)
	_draw_header(scene_rect)

func _draw_haze(scene_rect: Rect2) -> void:
	for index in range(4):
		var radius := scene_rect.size.x * (0.20 + float(index) * 0.08)
		var center := scene_rect.position + Vector2(scene_rect.size.x * (0.20 + float(index) * 0.20), scene_rect.size.y * 0.22)
		draw_circle(center, radius, HAZE_COLOR)

func _draw_roads(ground_rect: Rect2) -> void:
	var center := ground_rect.position + Vector2(ground_rect.size.x * 0.50, ground_rect.size.y * 0.12)
	var left := Vector2(ground_rect.position.x + ground_rect.size.x * 0.20, ground_rect.end.y)
	var right := Vector2(ground_rect.position.x + ground_rect.size.x * 0.80, ground_rect.end.y)
	draw_polyline(PackedVector2Array([left, center, right]), ROAD_COLOR, 10.0)
	draw_polyline(
		PackedVector2Array([left + Vector2(0.0, 5.0), center + Vector2(0.0, 3.0), right + Vector2(0.0, 5.0)]),
		Color(0.73, 0.64, 0.48, 0.55),
		2.0
	)

func _draw_city(scene_rect: Rect2, ground_rect: Rect2) -> void:
	var accent := _accent_color()
	var wall_top := ground_rect.position.y - scene_rect.size.y * 0.16
	var wall_rect := Rect2(
		Vector2(scene_rect.position.x + scene_rect.size.x * 0.18, wall_top),
		Vector2(scene_rect.size.x * 0.64, scene_rect.size.y * 0.12)
	)
	draw_rect(wall_rect, STONE_COLOR, true)
	draw_rect(wall_rect, STONE_SHADOW, false, 2.0)

	var tower_count := 3 if OverworldRulesScript.town_strategic_role(_town) == "capital" else 2
	for index in range(tower_count + 1):
		var x := wall_rect.position.x + float(index) * (wall_rect.size.x / float(max(1, tower_count))) - 12.0
		var tower_rect := Rect2(Vector2(x, wall_rect.position.y - 44.0), Vector2(28.0, 88.0))
		draw_rect(tower_rect, STONE_COLOR.darkened(0.06), true)
		draw_rect(tower_rect, STONE_SHADOW, false, 2.0)
		var roof = PackedVector2Array([
			tower_rect.position + Vector2(-4.0, 0.0),
			tower_rect.position + Vector2(tower_rect.size.x * 0.5, -24.0),
			tower_rect.position + Vector2(tower_rect.size.x + 4.0, 0.0),
		])
		draw_colored_polygon(roof, accent.darkened(0.14))
		_draw_window_strip(tower_rect, 3)

	var gate_rect := Rect2(
		Vector2(wall_rect.position.x + wall_rect.size.x * 0.42, wall_rect.end.y - 30.0),
		Vector2(wall_rect.size.x * 0.16, 30.0)
	)
	draw_rect(gate_rect, Color(0.17, 0.11, 0.08, 0.96), true)
	draw_rect(gate_rect, accent, false, 2.0)

	var keep_rect := Rect2(
		Vector2(scene_rect.position.x + scene_rect.size.x * 0.40, wall_rect.position.y - 82.0),
		Vector2(scene_rect.size.x * 0.20, 84.0)
	)
	draw_rect(keep_rect, STONE_COLOR.lightened(0.06), true)
	draw_rect(keep_rect, STONE_SHADOW, false, 2.0)
	var keep_roof = PackedVector2Array([
		keep_rect.position + Vector2(-12.0, 0.0),
		keep_rect.position + Vector2(keep_rect.size.x * 0.5, -34.0),
		keep_rect.position + Vector2(keep_rect.size.x + 12.0, 0.0),
	])
	draw_colored_polygon(keep_roof, accent)
	_draw_window_strip(keep_rect, 4)

	var banner_xs := [keep_rect.position.x + 18.0, keep_rect.end.x - 18.0]
	for banner_x in banner_xs:
		draw_line(Vector2(banner_x, keep_rect.position.y + 8.0), Vector2(banner_x, keep_rect.position.y - 30.0), Color(0.93, 0.91, 0.84, 0.92), 2.0)
		var banner = PackedVector2Array([
			Vector2(banner_x, keep_rect.position.y - 28.0),
			Vector2(banner_x + 22.0, keep_rect.position.y - 22.0),
			Vector2(banner_x, keep_rect.position.y - 14.0),
		])
		draw_colored_polygon(banner, accent.lightened(0.08))

	var district_counts := _district_counts()
	var district_positions := [
		Vector2(scene_rect.position.x + scene_rect.size.x * 0.24, ground_rect.position.y - 36.0),
		Vector2(scene_rect.position.x + scene_rect.size.x * 0.33, ground_rect.position.y - 18.0),
		Vector2(scene_rect.position.x + scene_rect.size.x * 0.66, ground_rect.position.y - 20.0),
		Vector2(scene_rect.position.x + scene_rect.size.x * 0.74, ground_rect.position.y - 40.0),
	]
	for index in range(district_positions.size()):
		var district_key: String = String(DISTRICT_ORDER[index])
		var building_count := int(district_counts.get(district_key, 0))
		_draw_district_cluster(district_positions[index], building_count, DISTRICT_COLORS.get(district_key, accent))

	var guard_count := clampi(_garrison_company_count(), 0, 5)
	for index in range(guard_count):
		var guard_center := Vector2(
			wall_rect.position.x + 36.0 + float(index) * 20.0,
			wall_rect.end.y + 10.0
		)
		draw_circle(guard_center, 7.0, Color(0.92, 0.88, 0.72, 0.92))
		draw_circle(guard_center, 7.0, Color(0.11, 0.14, 0.18, 0.85), false, 2.0)

func _draw_window_strip(rect: Rect2, count: int) -> void:
	for index in range(count):
		var window_rect := Rect2(
			Vector2(rect.position.x + 8.0 + float(index % 2) * 10.0, rect.position.y + 18.0 + float(index / 2) * 18.0),
			Vector2(6.0, 10.0)
		)
		draw_rect(window_rect, WINDOW_GLOW, true)

func _draw_district_cluster(position: Vector2, strength: int, color: Color) -> void:
	var visible_houses := clampi(max(1, strength), 1, 4)
	for index in range(visible_houses):
		var offset := Vector2(float(index) * 18.0, -float(index % 2) * 12.0)
		var house_rect := Rect2(position + offset, Vector2(18.0, 14.0))
		draw_rect(house_rect, color.darkened(0.18), true)
		draw_rect(house_rect, Color(0.12, 0.14, 0.18, 0.82), false, 1.5)
		var roof = PackedVector2Array([
			house_rect.position + Vector2(-2.0, 0.0),
			house_rect.position + Vector2(house_rect.size.x * 0.5, -9.0),
			house_rect.position + Vector2(house_rect.size.x + 2.0, 0.0),
		])
		draw_colored_polygon(roof, color)
		draw_rect(Rect2(house_rect.position + Vector2(5.0, 5.0), Vector2(4.0, 5.0)), WINDOW_GLOW, true)

func _draw_status_plaques(scene_rect: Rect2) -> void:
	var readiness := OverworldRulesScript.town_battle_readiness(_town, _session)
	var spell_tier := TownRulesScript.current_spell_tier(_town)
	var pressure := OverworldRulesScript.town_pressure_output(_town, _session)
	var disrupted := int(_logistics.get("disrupted_count", 0))
	var plaque_width: float = min(132.0, (scene_rect.size.x - 54.0) / 4.0)
	var plaques = [
		{
			"title": "Guard",
			"value": "%d" % readiness,
			"color": Color(0.33, 0.60, 0.64, 0.95),
		},
		{
			"title": "Spell",
			"value": "Tier %d" % spell_tier,
			"color": Color(0.41, 0.54, 0.83, 0.95),
		},
		{
			"title": "Front",
			"value": "%d pressure" % pressure,
			"color": Color(0.75, 0.43, 0.30, 0.95),
		},
		{
			"title": "Routes",
			"value": "%d blocked" % disrupted,
			"color": Color(0.36, 0.66, 0.58, 0.95),
		},
	]
	for index in range(plaques.size()):
		var rect := Rect2(
			Vector2(scene_rect.position.x + 12.0 + float(index) * (plaque_width + 10.0), scene_rect.position.y + 12.0),
			Vector2(plaque_width, 48.0)
		)
		_draw_plaque(rect, plaques[index])

func _draw_plaque(rect: Rect2, data: Dictionary) -> void:
	var fill: Color = data.get("color", FRAME_COLOR)
	draw_rect(rect, fill, true)
	draw_rect(rect, Color(0.10, 0.13, 0.16, 0.86), false, 2.0)
	_draw_text(String(data.get("title", "")), rect.position + Vector2(10.0, 18.0), TEXT_COLOR, 12)
	_draw_text(String(data.get("value", "")), rect.position + Vector2(10.0, 36.0), Color(0.13, 0.16, 0.19, 0.96), 15)

func _draw_district_strip(scene_rect: Rect2) -> void:
	var strip_rect := Rect2(
		Vector2(scene_rect.position.x + 16.0, scene_rect.end.y - 66.0),
		Vector2(scene_rect.size.x - 32.0, 50.0)
	)
	draw_rect(strip_rect, Color(0.88, 0.85, 0.78, 0.95), true)
	draw_rect(strip_rect, FRAME_COLOR, false, 2.0)

	var card_width := (strip_rect.size.x - 24.0) / float(DISTRICT_ORDER.size())
	var district_counts := _district_counts()
	for index in range(DISTRICT_ORDER.size()):
		var key: String = String(DISTRICT_ORDER[index])
		var card_rect := Rect2(
			strip_rect.position + Vector2(12.0 + float(index) * card_width, 8.0),
			Vector2(card_width - 8.0, strip_rect.size.y - 16.0)
		)
		var card_color: Color = DISTRICT_COLORS.get(key, Color(0.48, 0.56, 0.64, 0.94))
		draw_rect(card_rect, card_color, true)
		draw_rect(card_rect, Color(0.12, 0.15, 0.19, 0.88), false, 2.0)
		_draw_text(String(DISTRICT_LABELS.get(key, key.to_upper())), card_rect.position + Vector2(8.0, 17.0), TEXT_COLOR, 11)
		_draw_text("%d" % int(district_counts.get(key, 0)), card_rect.position + Vector2(8.0, 34.0), PANEL_TEXT, 18)

func _draw_command_markers(scene_rect: Rect2) -> void:
	var rect := Rect2(
		Vector2(scene_rect.end.x - 174.0, scene_rect.position.y + 72.0),
		Vector2(156.0, 114.0)
	)
	draw_rect(rect, Color(0.15, 0.17, 0.20, 0.90), true)
	draw_rect(rect, FRAME_COLOR, false, 2.0)
	var lines := [
		"HEROES %d" % _stationed.size(),
		"BUILD %d" % _build_actions.size(),
		"RECRUIT %d" % _available_recruit_total(),
		"RESPONSE %d" % _response_actions.size(),
		"THREAT %d" % (int(_threat.get("visible_marching", 0)) + int(_threat.get("visible_pressuring", 0))),
	]
	for index in range(lines.size()):
		var y := rect.position.y + 18.0 + float(index) * 18.0
		draw_circle(Vector2(rect.position.x + 10.0, y - 4.0), 3.0, FRAME_COLOR)
		_draw_text(lines[index], Vector2(rect.position.x + 20.0, y), SUBTEXT_COLOR, 12)

func _draw_header(scene_rect: Rect2) -> void:
	var title := String(_town_template.get("name", _town.get("town_id", "Town")))
	var role := OverworldRulesScript.town_strategic_role(_town).capitalize()
	var line := "%s | %s | %s" % [
		title,
		String(_faction.get("name", _town_template.get("faction_id", "Faction"))),
		role if role != "" else "Outpost",
	]
	_draw_text(line, scene_rect.position + Vector2(18.0, scene_rect.size.y * 0.48), TEXT_COLOR, 20)
	var subline := "Garrison %d companies | %d troops | Study %d | Market %d" % [
		_garrison_company_count(),
		_garrison_headcount(),
		_study_actions.size(),
		_market_actions.size(),
	]
	_draw_text(subline, scene_rect.position + Vector2(18.0, scene_rect.size.y * 0.48 + 22.0), SUBTEXT_COLOR, 13)

func _accent_color() -> Color:
	return FACTION_COLORS.get(String(_town_template.get("faction_id", "")), Color(0.84, 0.67, 0.35, 1.0))

func _district_counts() -> Dictionary:
	var counts := {
		"military": 0,
		"economy": 0,
		"spellcraft": 0,
		"logistics": 0,
		"defense": 0,
	}
	for building_id_value in _town.get("built_buildings", []):
		var building := ContentService.get_building(String(building_id_value))
		var category := String(building.get("category", ""))
		if category == "":
			continue
		if not counts.has(category):
			counts[category] = 0
		counts[category] = int(counts.get(category, 0)) + 1
	return counts

func _garrison_company_count() -> int:
	var companies := 0
	for stack in _town.get("garrison", []):
		if stack is Dictionary and int(stack.get("count", 0)) > 0:
			companies += 1
	return companies

func _garrison_headcount() -> int:
	var total := 0
	for stack in _town.get("garrison", []):
		if stack is Dictionary:
			total += max(0, int(stack.get("count", 0)))
	return total

func _available_recruit_total() -> int:
	var total := 0
	for value in _town.get("available_recruits", {}).values():
		total += max(0, int(value))
	return total

func _draw_text(text: String, position: Vector2, color: Color, font_size: int) -> void:
	var font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
