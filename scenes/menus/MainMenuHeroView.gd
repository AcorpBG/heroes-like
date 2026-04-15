extends Control

const SKY_COLOR := Color(0.09, 0.11, 0.16, 1.0)
const HAZE_COLOR := Color(0.18, 0.16, 0.11, 1.0)
const SUN_COLOR := Color(0.89, 0.71, 0.37, 0.95)
const MOUNTAIN_COLOR := Color(0.14, 0.16, 0.19, 1.0)
const HILL_COLOR := Color(0.10, 0.18, 0.16, 1.0)
const WALL_COLOR := Color(0.28, 0.26, 0.22, 1.0)
const TOWER_COLOR := Color(0.34, 0.31, 0.27, 1.0)
const BANNER_COLOR := Color(0.76, 0.47, 0.24, 1.0)
const HERO_COLOR := Color(0.12, 0.11, 0.12, 1.0)
const ROUTE_COLOR := Color(0.82, 0.70, 0.43, 0.7)

func _ready() -> void:
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, SKY_COLOR)

	var haze_band_count := 7
	for index in range(haze_band_count):
		var ratio := float(index) / float(max(1, haze_band_count - 1))
		var band_height := size.y * 0.18
		var band_top := lerpf(size.y * 0.02, size.y * 0.52, ratio)
		var band_color := SKY_COLOR.lerp(HAZE_COLOR, 0.18 + ratio * 0.48)
		band_color.a = 0.28 + ratio * 0.08
		draw_rect(Rect2(0.0, band_top, size.x, band_height), band_color)

	var sun_center := Vector2(size.x * 0.78, size.y * 0.24)
	draw_circle(sun_center, size.y * 0.14, SUN_COLOR)
	draw_circle(sun_center, size.y * 0.19, Color(SUN_COLOR.r, SUN_COLOR.g, SUN_COLOR.b, 0.08))

	_draw_route_lines()
	_draw_mountains()
	_draw_fortress()
	_draw_hero()
	_draw_card_markers()

func _draw_route_lines() -> void:
	var points := [
		Vector2(size.x * 0.08, size.y * 0.26),
		Vector2(size.x * 0.24, size.y * 0.18),
		Vector2(size.x * 0.42, size.y * 0.24),
		Vector2(size.x * 0.61, size.y * 0.17),
	]
	for index in range(points.size() - 1):
		draw_dashed_line(points[index], points[index + 1], ROUTE_COLOR, 2.0, 9.0)
	for point in points:
		draw_circle(point, 4.0, ROUTE_COLOR)

func _draw_mountains() -> void:
	var ridge := PackedVector2Array(
		[
			Vector2(0.0, size.y * 0.68),
			Vector2(size.x * 0.10, size.y * 0.44),
			Vector2(size.x * 0.18, size.y * 0.60),
			Vector2(size.x * 0.30, size.y * 0.38),
			Vector2(size.x * 0.44, size.y * 0.64),
			Vector2(size.x * 0.58, size.y * 0.42),
			Vector2(size.x * 0.74, size.y * 0.63),
			Vector2(size.x * 0.86, size.y * 0.46),
			Vector2(size.x, size.y * 0.68),
			Vector2(size.x, size.y),
			Vector2(0.0, size.y),
		]
	)
	draw_colored_polygon(ridge, MOUNTAIN_COLOR)

	var hill := PackedVector2Array(
		[
			Vector2(0.0, size.y * 0.80),
			Vector2(size.x * 0.16, size.y * 0.74),
			Vector2(size.x * 0.32, size.y * 0.79),
			Vector2(size.x * 0.52, size.y * 0.70),
			Vector2(size.x * 0.74, size.y * 0.78),
			Vector2(size.x, size.y * 0.72),
			Vector2(size.x, size.y),
			Vector2(0.0, size.y),
		]
	)
	draw_colored_polygon(hill, HILL_COLOR)

func _draw_fortress() -> void:
	var wall_top := size.y * 0.58
	var wall_height := size.y * 0.14
	var wall_rect := Rect2(size.x * 0.42, wall_top, size.x * 0.44, wall_height)
	draw_rect(wall_rect, WALL_COLOR)

	for index in range(7):
		var merlon_width := size.x * 0.036
		var gap := size.x * 0.018
		var x := wall_rect.position.x + gap + float(index) * (merlon_width + gap)
		draw_rect(Rect2(x, wall_top - size.y * 0.04, merlon_width, size.y * 0.04), WALL_COLOR)

	var tower_rect := Rect2(size.x * 0.61, size.y * 0.38, size.x * 0.12, size.y * 0.26)
	draw_rect(tower_rect, TOWER_COLOR)
	draw_rect(Rect2(size.x * 0.53, size.y * 0.46, size.x * 0.08, size.y * 0.18), TOWER_COLOR.darkened(0.08))

	var roof := PackedVector2Array(
		[
			Vector2(tower_rect.position.x - size.x * 0.02, tower_rect.position.y + size.y * 0.02),
			Vector2(tower_rect.position.x + tower_rect.size.x * 0.5, tower_rect.position.y - size.y * 0.08),
			Vector2(tower_rect.position.x + tower_rect.size.x + size.x * 0.02, tower_rect.position.y + size.y * 0.02),
		]
	)
	draw_colored_polygon(roof, Color(0.24, 0.17, 0.15, 1.0))

	draw_line(
		Vector2(tower_rect.position.x + tower_rect.size.x * 0.72, tower_rect.position.y + size.y * 0.02),
		Vector2(tower_rect.position.x + tower_rect.size.x * 0.72, tower_rect.position.y - size.y * 0.12),
		Color(0.16, 0.11, 0.10, 1.0),
		3.0
	)
	var standard := PackedVector2Array(
		[
			Vector2(tower_rect.position.x + tower_rect.size.x * 0.72, tower_rect.position.y - size.y * 0.12),
			Vector2(tower_rect.position.x + tower_rect.size.x * 0.92, tower_rect.position.y - size.y * 0.09),
			Vector2(tower_rect.position.x + tower_rect.size.x * 0.72, tower_rect.position.y - size.y * 0.04),
		]
	)
	draw_colored_polygon(standard, BANNER_COLOR)

func _draw_hero() -> void:
	var hero_base := Vector2(size.x * 0.24, size.y * 0.80)
	draw_circle(hero_base + Vector2(0.0, -size.y * 0.22), size.y * 0.05, HERO_COLOR)

	var torso := PackedVector2Array(
		[
			hero_base + Vector2(-size.x * 0.05, -size.y * 0.16),
			hero_base + Vector2(size.x * 0.03, -size.y * 0.14),
			hero_base + Vector2(size.x * 0.07, 0.0),
			hero_base + Vector2(-size.x * 0.08, 0.0),
		]
	)
	draw_colored_polygon(torso, HERO_COLOR)

	var cloak := PackedVector2Array(
		[
			hero_base + Vector2(-size.x * 0.03, -size.y * 0.12),
			hero_base + Vector2(size.x * 0.12, size.y * 0.02),
			hero_base + Vector2(size.x * 0.05, size.y * 0.16),
			hero_base + Vector2(-size.x * 0.13, size.y * 0.11),
		]
	)
	draw_colored_polygon(cloak, Color(0.22, 0.13, 0.12, 1.0))

	draw_line(hero_base + Vector2(size.x * 0.04, -size.y * 0.10), hero_base + Vector2(size.x * 0.12, -size.y * 0.36), Color(0.72, 0.74, 0.79, 1.0), 4.0)
	draw_line(hero_base + Vector2(size.x * 0.12, -size.y * 0.36), hero_base + Vector2(size.x * 0.15, -size.y * 0.33), Color(0.72, 0.74, 0.79, 1.0), 2.0)
	draw_line(hero_base + Vector2(size.x * 0.12, -size.y * 0.36), hero_base + Vector2(size.x * 0.09, -size.y * 0.33), Color(0.72, 0.74, 0.79, 1.0), 2.0)

func _draw_card_markers() -> void:
	for index in range(3):
		var x := size.x * (0.64 + float(index) * 0.10)
		var y := size.y * (0.72 + float(index % 2) * 0.04)
		var card := Rect2(x, y, size.x * 0.08, size.y * 0.10)
		draw_rect(card, Color(0.20, 0.18, 0.15, 0.95))
		draw_rect(card.grow(-3.0), Color(0.35, 0.27, 0.17, 0.9), false, 2.0)
