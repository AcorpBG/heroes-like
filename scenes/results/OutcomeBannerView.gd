extends Control

var _status := "victory"

func _ready() -> void:
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func set_outcome(status: String) -> void:
	_status = status
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var palette := _palette()
	draw_rect(Rect2(Vector2.ZERO, size), palette.background)

	var horizon_band_count := 6
	for index in range(horizon_band_count):
		var ratio := float(index) / float(max(1, horizon_band_count - 1))
		var band_color: Color = palette.background.lerp(palette.haze, 0.18 + ratio * 0.46)
		band_color.a = 0.35 + ratio * 0.08
		draw_rect(
			Rect2(0.0, lerpf(size.y * 0.04, size.y * 0.54, ratio), size.x, size.y * 0.18),
			band_color
		)

	var burst_center := Vector2(size.x * 0.78, size.y * 0.23)
	for index in range(12):
		var angle := deg_to_rad(-64.0 + float(index) * 11.0)
		var inner := burst_center + Vector2(cos(angle), sin(angle)) * size.y * 0.08
		var outer := burst_center + Vector2(cos(angle), sin(angle)) * size.y * 0.30
		draw_line(inner, outer, palette.burst, 3.0)
	draw_circle(burst_center, size.y * 0.10, palette.core)
	draw_circle(burst_center, size.y * 0.16, Color(palette.core.r, palette.core.g, palette.core.b, 0.09))

	_draw_ground(palette)
	_draw_shield(palette)
	_draw_result_marks(palette)

func _draw_ground(palette: Dictionary) -> void:
	var ridge := PackedVector2Array(
		[
			Vector2(0.0, size.y * 0.78),
			Vector2(size.x * 0.14, size.y * 0.63),
			Vector2(size.x * 0.30, size.y * 0.77),
			Vector2(size.x * 0.47, size.y * 0.60),
			Vector2(size.x * 0.63, size.y * 0.76),
			Vector2(size.x * 0.82, size.y * 0.62),
			Vector2(size.x, size.y * 0.76),
			Vector2(size.x, size.y),
			Vector2(0.0, size.y),
		]
	)
	draw_colored_polygon(ridge, palette.ridge)

	var foreground := PackedVector2Array(
		[
			Vector2(0.0, size.y * 0.86),
			Vector2(size.x * 0.18, size.y * 0.82),
			Vector2(size.x * 0.35, size.y * 0.88),
			Vector2(size.x * 0.56, size.y * 0.80),
			Vector2(size.x * 0.73, size.y * 0.90),
			Vector2(size.x, size.y * 0.84),
			Vector2(size.x, size.y),
			Vector2(0.0, size.y),
		]
	)
	draw_colored_polygon(foreground, palette.foreground)

func _draw_shield(palette: Dictionary) -> void:
	var center := Vector2(size.x * 0.34, size.y * 0.50)
	var shield := PackedVector2Array(
		[
			center + Vector2(0.0, -size.y * 0.18),
			center + Vector2(size.x * 0.12, -size.y * 0.10),
			center + Vector2(size.x * 0.10, size.y * 0.08),
			center + Vector2(0.0, size.y * 0.22),
			center + Vector2(-size.x * 0.10, size.y * 0.08),
			center + Vector2(-size.x * 0.12, -size.y * 0.10),
		]
	)
	draw_colored_polygon(shield, palette.shield)
	draw_polyline(shield, palette.trim, 4.0, true)

	draw_line(center + Vector2(-size.x * 0.08, -size.y * 0.01), center + Vector2(size.x * 0.08, -size.y * 0.01), palette.trim, 4.0)
	draw_line(center + Vector2(0.0, -size.y * 0.11), center + Vector2(0.0, size.y * 0.13), palette.trim, 4.0)

func _draw_result_marks(palette: Dictionary) -> void:
	var left_pole_top := Vector2(size.x * 0.14, size.y * 0.24)
	var left_pole_bottom := Vector2(size.x * 0.14, size.y * 0.82)
	var right_pole_top := Vector2(size.x * 0.56, size.y * 0.24)
	var right_pole_bottom := Vector2(size.x * 0.56, size.y * 0.82)
	draw_line(left_pole_top, left_pole_bottom, palette.trim.darkened(0.3), 4.0)
	draw_line(right_pole_top, right_pole_bottom, palette.trim.darkened(0.3), 4.0)

	match _status:
		"victory":
			_draw_banner(
				left_pole_top,
				Color(0.15, 0.31, 0.28, 1.0),
				Color(0.83, 0.72, 0.38, 1.0)
			)
			_draw_banner(
				right_pole_top,
				Color(0.17, 0.28, 0.31, 1.0),
				Color(0.86, 0.76, 0.42, 1.0)
			)
			_draw_laurels(palette.trim)
		"defeat":
			_draw_torn_banner(left_pole_top, Color(0.44, 0.18, 0.16, 1.0))
			_draw_torn_banner(right_pole_top, Color(0.38, 0.15, 0.14, 1.0))
			draw_line(
				Vector2(size.x * 0.18, size.y * 0.28),
				Vector2(size.x * 0.54, size.y * 0.76),
				Color(0.63, 0.58, 0.55, 1.0),
				5.0
			)
			draw_line(
				Vector2(size.x * 0.54, size.y * 0.28),
				Vector2(size.x * 0.18, size.y * 0.76),
				Color(0.63, 0.58, 0.55, 1.0),
				5.0
			)
		_:
			_draw_banner(left_pole_top, Color(0.18, 0.22, 0.28, 1.0), palette.trim)
			_draw_banner(right_pole_top, Color(0.18, 0.22, 0.28, 1.0), palette.trim)
			draw_circle(Vector2(size.x * 0.35, size.y * 0.64), size.y * 0.02, palette.trim)

func _draw_banner(origin: Vector2, color: Color, edge: Color) -> void:
	var shape := PackedVector2Array(
		[
			origin + Vector2(0.0, size.y * 0.04),
			origin + Vector2(size.x * 0.16, size.y * 0.07),
			origin + Vector2(size.x * 0.12, size.y * 0.18),
			origin + Vector2(size.x * 0.07, size.y * 0.14),
			origin + Vector2(0.0, size.y * 0.20),
		]
	)
	draw_colored_polygon(shape, color)
	draw_polyline(shape, edge, 3.0, true)

func _draw_torn_banner(origin: Vector2, color: Color) -> void:
	var shape := PackedVector2Array(
		[
			origin + Vector2(0.0, size.y * 0.05),
			origin + Vector2(size.x * 0.14, size.y * 0.09),
			origin + Vector2(size.x * 0.09, size.y * 0.14),
			origin + Vector2(size.x * 0.12, size.y * 0.20),
			origin + Vector2(size.x * 0.05, size.y * 0.17),
			origin + Vector2(0.0, size.y * 0.22),
		]
	)
	draw_colored_polygon(shape, color)

func _draw_laurels(color: Color) -> void:
	for index in range(5):
		var ratio := float(index) / 4.0
		draw_circle(
			Vector2(size.x * 0.22 - ratio * size.x * 0.035, size.y * 0.58 - ratio * size.y * 0.045),
			size.y * 0.016,
			color
		)
		draw_circle(
			Vector2(size.x * 0.46 + ratio * size.x * 0.035, size.y * 0.58 - ratio * size.y * 0.045),
			size.y * 0.016,
			color
		)

func _palette() -> Dictionary:
	match _status:
		"victory":
			return {
				"background": Color(0.05, 0.10, 0.11, 1.0),
				"haze": Color(0.17, 0.15, 0.10, 1.0),
				"burst": Color(0.90, 0.78, 0.46, 0.62),
				"core": Color(0.92, 0.77, 0.43, 0.95),
				"ridge": Color(0.11, 0.18, 0.18, 1.0),
				"foreground": Color(0.08, 0.12, 0.11, 1.0),
				"shield": Color(0.15, 0.29, 0.27, 1.0),
				"trim": Color(0.88, 0.73, 0.38, 1.0),
			}
		"defeat":
			return {
				"background": Color(0.11, 0.05, 0.07, 1.0),
				"haze": Color(0.19, 0.08, 0.07, 1.0),
				"burst": Color(0.86, 0.32, 0.28, 0.45),
				"core": Color(0.82, 0.28, 0.24, 0.82),
				"ridge": Color(0.18, 0.08, 0.08, 1.0),
				"foreground": Color(0.10, 0.06, 0.07, 1.0),
				"shield": Color(0.29, 0.12, 0.11, 1.0),
				"trim": Color(0.88, 0.55, 0.35, 1.0),
			}
		_:
			return {
				"background": Color(0.08, 0.09, 0.12, 1.0),
				"haze": Color(0.15, 0.13, 0.11, 1.0),
				"burst": Color(0.70, 0.70, 0.58, 0.42),
				"core": Color(0.82, 0.77, 0.55, 0.80),
				"ridge": Color(0.14, 0.15, 0.18, 1.0),
				"foreground": Color(0.09, 0.10, 0.12, 1.0),
				"shield": Color(0.19, 0.22, 0.27, 1.0),
				"trim": Color(0.80, 0.74, 0.50, 1.0),
			}
