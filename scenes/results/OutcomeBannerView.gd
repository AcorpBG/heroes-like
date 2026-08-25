extends Control

const STATUS_EMBLEM_PATHS := {
	"victory": "res://art/results/runtime/emblems/outcome_victory_emblem.png",
	"defeat": "res://art/results/runtime/emblems/outcome_defeat_emblem.png",
}
const STATUS_EMBLEMS := {
	"victory": preload("res://art/results/runtime/emblems/outcome_victory_emblem.png"),
	"defeat": preload("res://art/results/runtime/emblems/outcome_defeat_emblem.png"),
}
const EMBLEM_INSET := 8.0

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
	var emblem := _status_emblem()
	if emblem != null:
		draw_texture_rect(emblem, _emblem_destination_rect(emblem), false)
		return
	_draw_procedural_banner()


func validation_summary() -> Dictionary:
	var emblem := _status_emblem()
	var texture_size := Vector2.ZERO
	var destination_rect := Rect2()
	if emblem != null:
		texture_size = Vector2(emblem.get_width(), emblem.get_height())
		destination_rect = _emblem_destination_rect(emblem)
	var destination_aspect := destination_rect.size.x / destination_rect.size.y if destination_rect.size.y > 0.0 else 0.0
	var texture_aspect := texture_size.x / texture_size.y if texture_size.y > 0.0 else 0.0
	return {
		"status": _status,
		"expected_path": String(STATUS_EMBLEM_PATHS.get(_status, "")),
		"texture_path": String(emblem.resource_path) if emblem != null else "",
		"texture_loaded": emblem != null,
		"texture_size": texture_size,
		"destination_rect": destination_rect,
		"rendering_mode": "contained_authored_status_emblem" if emblem != null else "procedural_status_fallback",
		"aspect_preserved": is_equal_approx(destination_aspect, texture_aspect) if emblem != null else true,
		"destination_contained": _rect_contained(destination_rect, Rect2(Vector2.ZERO, size)) if emblem != null else true,
		"centered": destination_rect.get_center().is_equal_approx(size * 0.5) if emblem != null else true,
		"inset": EMBLEM_INSET,
		"fallback": emblem == null,
	}


func _status_emblem() -> Texture2D:
	return STATUS_EMBLEMS.get(_status, null) as Texture2D


func _emblem_destination_rect(emblem: Texture2D) -> Rect2:
	var available_size := Vector2(maxf(0.0, size.x - EMBLEM_INSET * 2.0), maxf(0.0, size.y - EMBLEM_INSET * 2.0))
	var texture_size := Vector2(emblem.get_width(), emblem.get_height())
	if available_size.x <= 0.0 or available_size.y <= 0.0 or texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2(size * 0.5, Vector2.ZERO)
	var scale := minf(available_size.x / texture_size.x, available_size.y / texture_size.y)
	var draw_size := texture_size * scale
	return Rect2((size - draw_size) * 0.5, draw_size)


func _rect_contained(inner: Rect2, outer: Rect2) -> bool:
	return (
		inner.position.x >= outer.position.x - 0.01
		and inner.position.y >= outer.position.y - 0.01
		and inner.end.x <= outer.end.x + 0.01
		and inner.end.y <= outer.end.y + 0.01
	)


func _draw_procedural_banner() -> void:

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
	var horizon_poly := PackedVector2Array(
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
	draw_colored_polygon(horizon_poly, palette.rough)

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
				"rough": Color(0.11, 0.18, 0.18, 1.0),
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
				"rough": Color(0.18, 0.08, 0.08, 1.0),
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
				"rough": Color(0.14, 0.15, 0.18, 1.0),
				"foreground": Color(0.09, 0.10, 0.12, 1.0),
				"shield": Color(0.19, 0.22, 0.27, 1.0),
				"trim": Color(0.80, 0.74, 0.50, 1.0),
			}
