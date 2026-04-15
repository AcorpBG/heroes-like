extends Control

@export_enum("menu", "overworld", "town", "battle", "outcome") var glyph_id := "menu"
@export var accent := Color(0.88, 0.72, 0.40, 1.0)
@export var fill := Color(0.10, 0.12, 0.15, 0.98)
@export var detail := Color(0.96, 0.94, 0.88, 1.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(52.0, 52.0)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func set_glyph(next_glyph_id: String, accent_color: Color = accent) -> void:
	glyph_id = next_glyph_id
	accent = accent_color
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var rect := Rect2(Vector2.ZERO, size)
	var pad: float = minf(size.x, size.y) * 0.12
	var inner := rect.grow(-pad)
	var center := inner.get_center()
	var radius: float = minf(inner.size.x, inner.size.y) * 0.46

	draw_circle(center, radius, Color(accent.r, accent.g, accent.b, 0.18))
	draw_circle(center, radius * 0.84, fill)
	draw_circle(center, radius, accent, false, 2.0)

	var crest := PackedVector2Array(
		[
			center + Vector2(0.0, -radius * 0.82),
			center + Vector2(radius * 0.62, -radius * 0.42),
			center + Vector2(radius * 0.50, radius * 0.28),
			center + Vector2(0.0, radius * 0.88),
			center + Vector2(-radius * 0.50, radius * 0.28),
			center + Vector2(-radius * 0.62, -radius * 0.42),
		]
	)
	draw_colored_polygon(crest, Color(accent.r * 0.24, accent.g * 0.24, accent.b * 0.24, 0.92))
	draw_polyline(PackedVector2Array([crest[0], crest[1], crest[2], crest[3], crest[4], crest[5], crest[0]]), accent, 2.0)

	match glyph_id:
		"overworld":
			_draw_overworld_symbol(center, radius * 0.64)
		"town":
			_draw_town_symbol(center, radius * 0.64)
		"battle":
			_draw_battle_symbol(center, radius * 0.62)
		"outcome":
			_draw_outcome_symbol(center, radius * 0.64)
		_:
			_draw_menu_symbol(center, radius * 0.64)

func _draw_menu_symbol(center: Vector2, scale: float) -> void:
	draw_circle(center, scale * 0.14, accent)
	for angle_deg in [-90.0, -18.0, 54.0, 126.0, 198.0]:
		var angle := deg_to_rad(angle_deg)
		var outer := center + Vector2(cos(angle), sin(angle)) * scale
		draw_line(center, outer, detail, 2.0)
		draw_circle(center + Vector2(cos(angle), sin(angle)) * scale * 0.72, scale * 0.08, accent)

func _draw_overworld_symbol(center: Vector2, scale: float) -> void:
	var route := PackedVector2Array(
		[
			center + Vector2(-scale * 0.88, scale * 0.18),
			center + Vector2(-scale * 0.36, -scale * 0.16),
			center + Vector2(scale * 0.12, scale * 0.10),
			center + Vector2(scale * 0.86, -scale * 0.30),
		]
	)
	draw_polyline(route, detail, 2.0)
	for point in route:
		draw_circle(point, scale * 0.08, accent)
	var pennant := PackedVector2Array(
		[
			center + Vector2(scale * 0.18, -scale * 0.80),
			center + Vector2(scale * 0.72, -scale * 0.62),
			center + Vector2(scale * 0.18, -scale * 0.38),
		]
	)
	draw_line(center + Vector2(scale * 0.18, -scale * 0.16), center + Vector2(scale * 0.18, -scale * 0.82), detail, 2.0)
	draw_colored_polygon(pennant, accent)

func _draw_town_symbol(center: Vector2, scale: float) -> void:
	var wall := Rect2(center + Vector2(-scale * 0.70, scale * 0.08), Vector2(scale * 1.40, scale * 0.42))
	draw_rect(wall, detail, true)
	draw_rect(wall, fill, false, 2.0)
	for step in [0.08, 0.38, 0.68]:
		draw_rect(Rect2(center + Vector2(-scale * 0.60 + scale * step, -scale * 0.12), Vector2(scale * 0.18, scale * 0.18)), detail, true)
	var tower := Rect2(center + Vector2(-scale * 0.18, -scale * 0.66), Vector2(scale * 0.36, scale * 0.74))
	draw_rect(tower, accent, true)
	var roof := PackedVector2Array(
		[
			tower.position + Vector2(-scale * 0.10, 0.0),
			tower.position + Vector2(tower.size.x * 0.50, -scale * 0.30),
			tower.position + Vector2(tower.size.x + scale * 0.10, 0.0),
		]
	)
	draw_colored_polygon(roof, detail)

func _draw_battle_symbol(center: Vector2, scale: float) -> void:
	draw_line(center + Vector2(-scale * 0.82, scale * 0.70), center + Vector2(scale * 0.26, -scale * 0.46), detail, 3.0)
	draw_line(center + Vector2(scale * 0.82, scale * 0.70), center + Vector2(-scale * 0.26, -scale * 0.46), accent, 3.0)
	var left_tip := PackedVector2Array(
		[
			center + Vector2(scale * 0.22, -scale * 0.50),
			center + Vector2(scale * 0.42, -scale * 0.64),
			center + Vector2(scale * 0.14, -scale * 0.76),
		]
	)
	var right_tip := PackedVector2Array(
		[
			center + Vector2(-scale * 0.22, -scale * 0.50),
			center + Vector2(-scale * 0.42, -scale * 0.64),
			center + Vector2(-scale * 0.14, -scale * 0.76),
		]
	)
	draw_colored_polygon(left_tip, detail)
	draw_colored_polygon(right_tip, accent)

func _draw_outcome_symbol(center: Vector2, scale: float) -> void:
	draw_circle(center, scale * 0.18, accent)
	for index in range(4):
		var angle := deg_to_rad(-90.0 + float(index) * 90.0)
		draw_line(center, center + Vector2(cos(angle), sin(angle)) * scale * 0.74, detail, 2.0)
	for index in range(4):
		var ratio := float(index) / 3.0
		draw_circle(center + Vector2(-scale * 0.76 + scale * 0.18 * ratio, scale * 0.48 - scale * 0.16 * ratio), scale * 0.09, detail)
		draw_circle(center + Vector2(scale * 0.76 - scale * 0.18 * ratio, scale * 0.48 - scale * 0.16 * ratio), scale * 0.09, detail)
