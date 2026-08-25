extends Control

const MODEL := "quiet_cartographic_rail"
const INK := Color(0.72, 0.58, 0.30, 0.13)
const INK_SOFT := Color(0.55, 0.68, 0.62, 0.075)
const INK_FAINT := Color(0.78, 0.68, 0.46, 0.045)
const COMPASS_VERTICAL_RATIO := 0.73

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if size.x < 80.0 or size.y < 160.0:
		return
	_draw_chart_grid()
	_draw_route_trace()
	_draw_compass_rose()
	_draw_corner_registration()

func _draw_chart_grid() -> void:
	var left := size.x * 0.12
	var right := size.x * 0.88
	var top := size.y * 0.46
	var bottom := size.y * 0.92
	for index in range(5):
		var ratio := float(index) / 4.0
		var y := lerpf(top, bottom, ratio)
		draw_line(Vector2(left, y), Vector2(right, y), INK_FAINT, 1.0, true)
	for index in range(4):
		var ratio := float(index) / 3.0
		var x := lerpf(left, right, ratio)
		draw_line(Vector2(x, top), Vector2(x, bottom), INK_FAINT, 1.0, true)

func _draw_route_trace() -> void:
	var points := PackedVector2Array(
		[
			Vector2(size.x * 0.20, size.y * 0.87),
			Vector2(size.x * 0.36, size.y * 0.78),
			Vector2(size.x * 0.31, size.y * 0.66),
			Vector2(size.x * 0.57, size.y * 0.60),
			Vector2(size.x * 0.78, size.y * 0.49),
		]
	)
	draw_polyline(points, INK_SOFT, 1.5, true)
	for point in points:
		draw_circle(point, 2.8, INK)
		draw_circle(point, 5.4, INK_SOFT, false, 1.0, true)

func _draw_compass_rose() -> void:
	var center := Vector2(size.x * 0.62, size.y * COMPASS_VERTICAL_RATIO)
	var radius := minf(size.x * 0.22, size.y * 0.11)
	draw_circle(center, radius, INK_FAINT)
	draw_circle(center, radius, INK_SOFT, false, 1.4, true)
	draw_circle(center, radius * 0.54, INK, false, 1.0, true)
	for index in range(8):
		var angle := -PI * 0.5 + float(index) * PI * 0.25
		var length := radius * (0.90 if index % 2 == 0 else 0.58)
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(center, center + direction * length, INK, 1.2, true)
	var north := PackedVector2Array(
		[
			center + Vector2(0.0, -radius * 0.92),
			center + Vector2(radius * 0.12, -radius * 0.18),
			center,
			center + Vector2(-radius * 0.12, -radius * 0.18),
		]
	)
	draw_colored_polygon(north, INK)
	draw_circle(center, 3.2, INK)

func _draw_corner_registration() -> void:
	var inset := Vector2(size.x * 0.13, size.y * 0.47)
	var arm := minf(18.0, size.x * 0.06)
	for corner in [
		{"point": inset, "x": 1.0, "y": 1.0},
		{"point": Vector2(size.x - inset.x, inset.y), "x": -1.0, "y": 1.0},
		{"point": Vector2(inset.x, size.y - size.y * 0.08), "x": 1.0, "y": -1.0},
		{"point": Vector2(size.x - inset.x, size.y - size.y * 0.08), "x": -1.0, "y": -1.0},
	]:
		var point: Vector2 = corner["point"]
		draw_line(point, point + Vector2(float(corner["x"]) * arm, 0.0), INK_SOFT, 1.0, true)
		draw_line(point, point + Vector2(0.0, float(corner["y"]) * arm), INK_SOFT, 1.0, true)

func visual_contract() -> Dictionary:
	return {
		"model": MODEL,
		"passive": mouse_filter == Control.MOUSE_FILTER_IGNORE and focus_mode == Control.FOCUS_NONE,
		"contained": position.x >= 0.0 and position.y >= 0.0 and (position + size).x <= get_parent_control().size.x and (position + size).y <= get_parent_control().size.y,
		"grid_lines": 9,
		"route_points": 5,
		"compass_spokes": 8,
		"maximum_alpha": INK.a,
	}
