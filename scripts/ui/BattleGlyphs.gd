extends RefCounted
## The small glyphs of the battle screen, drawn on any canvas item from its
## _draw(): a bow or sword for a stack's role, an hourglass for waiting, a
## shield for defending and an arrow for shots. The board's plates and ribbon
## and the details card share them, so a glyph reads the same everywhere.
## docs/battle-rework.md (D9).


## A sword for melee stacks, a bow with an arrow for ranged ones.
static func draw_role(canvas: CanvasItem, center: Vector2, extent: float, ranged: bool, color: Color) -> void:
	var width := maxf(1.0, extent * 0.12)
	if ranged:
		var bow_center := center + Vector2(0.18, 0.0) * extent
		canvas.draw_arc(bow_center, 0.52 * extent, PI * 2.0 / 3.0, PI * 4.0 / 3.0, 12, color, width, true)
		var top := bow_center + Vector2.from_angle(PI * 2.0 / 3.0) * 0.52 * extent
		var bottom := bow_center + Vector2.from_angle(PI * 4.0 / 3.0) * 0.52 * extent
		canvas.draw_line(top, bottom, color, maxf(1.0, width * 0.6), true)
		var tip := center + Vector2(0.5, 0.0) * extent
		canvas.draw_line(center - Vector2(0.5, 0.0) * extent, tip, color, width, true)
		canvas.draw_line(tip, tip + Vector2(-0.2, -0.15) * extent, color, width, true)
		canvas.draw_line(tip, tip + Vector2(-0.2, 0.15) * extent, color, width, true)
		return
	var along := Vector2(1.0, -1.0).normalized()
	var across := Vector2(1.0, 1.0).normalized()
	var guard := center - along * 0.2 * extent
	canvas.draw_line(guard, center + along * 0.48 * extent, color, width * 1.25, true)
	canvas.draw_line(guard - across * 0.24 * extent, guard + across * 0.24 * extent, color, width, true)
	canvas.draw_line(guard, center - along * 0.42 * extent, color, width, true)
	canvas.draw_circle(center - along * 0.46 * extent, width * 0.75, color)


static func draw_hourglass(canvas: CanvasItem, center: Vector2, extent: float, color: Color) -> void:
	var width := maxf(1.0, extent * 0.1)
	var half := extent * 0.42
	var top := center.y - half
	var bottom := center.y + half
	canvas.draw_line(Vector2(center.x - extent * 0.32, top), Vector2(center.x + extent * 0.32, top), color, width, true)
	canvas.draw_line(Vector2(center.x - extent * 0.32, bottom), Vector2(center.x + extent * 0.32, bottom), color, width, true)
	canvas.draw_polyline(PackedVector2Array([
		Vector2(center.x - extent * 0.26, top),
		center,
		Vector2(center.x - extent * 0.26, bottom),
	]), color, width, true)
	canvas.draw_polyline(PackedVector2Array([
		Vector2(center.x + extent * 0.26, top),
		center,
		Vector2(center.x + extent * 0.26, bottom),
	]), color, width, true)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(center.x - extent * 0.17, bottom - extent * 0.06),
		Vector2(center.x + extent * 0.17, bottom - extent * 0.06),
		Vector2(center.x, center.y + extent * 0.14),
	]), color)


## A heater shield, for a stack that defends.
static func draw_shield(canvas: CanvasItem, center: Vector2, extent: float, color: Color) -> void:
	var points := PackedVector2Array()
	for corner in [Vector2(-0.38, -0.42), Vector2(0.38, -0.42), Vector2(0.38, 0.02), Vector2(0.24, 0.28), Vector2(0.0, 0.47), Vector2(-0.24, 0.28), Vector2(-0.38, 0.02)]:
		points.append(center + corner * extent)
	canvas.draw_colored_polygon(points, Color(color, color.a * 0.28))
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, color, maxf(1.0, extent * 0.11), true)
	canvas.draw_line(center + Vector2(0.0, -0.3) * extent, center + Vector2(0.0, 0.3) * extent, color, maxf(1.0, extent * 0.08), true)


## A small arrow flying up and to the right, for the shots left.
static func draw_shot(canvas: CanvasItem, center: Vector2, extent: float, color: Color) -> void:
	var width := maxf(1.0, extent * 0.13)
	var along := Vector2(1.0, -1.0).normalized()
	var across := Vector2(1.0, 1.0).normalized()
	var tip := center + along * 0.5 * extent
	var tail := center - along * 0.5 * extent
	canvas.draw_line(tail, tip, color, width, true)
	canvas.draw_colored_polygon(PackedVector2Array([tip, tip - along * 0.32 * extent + across * 0.17 * extent, tip - along * 0.32 * extent - across * 0.17 * extent]), color)
	for offset in [0.0, 0.16]:
		var root: Vector2 = tail + along * (offset + 0.04) * extent
		canvas.draw_line(root, root - along * 0.14 * extent + across * 0.16 * extent, color, maxf(1.0, width * 0.8), true)
		canvas.draw_line(root, root - along * 0.14 * extent - across * 0.16 * extent, color, maxf(1.0, width * 0.8), true)
