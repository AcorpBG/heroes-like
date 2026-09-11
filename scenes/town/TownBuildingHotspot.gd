extends Button
## Pointer ownership follows painted pixels; keyboard focus retains the full bounds.

var painted_mask: BitMap
var texture_region_ratio := Rect2(Vector2.ZERO, Vector2.ONE)
var _outline_mask: BitMap
var _outline_contours: Array[PackedVector2Array] = []

func _init() -> void:
	# Button still owns input/accessibility; its rectangular theme decoration
	# must never obscure the alpha-shaped artwork or its transparent corners.
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	clip_contents = true
	for changed in [mouse_entered, mouse_exited, focus_entered, focus_exited, button_down, button_up, resized]:
		changed.connect(queue_redraw)

func _ensure_outline_contours() -> void:
	if painted_mask == _outline_mask:
		return
	_outline_mask = painted_mask
	_outline_contours.clear()
	if painted_mask == null:
		return
	# Trace once per mask, on first highlight. Use the exact click alpha, not
	# texture bounds; no image reads or polygon extraction on steady-state hover.
	var mask_size := painted_mask.get_size()
	for polygon in painted_mask.opaque_to_polygons(Rect2i(Vector2i.ZERO, mask_size), 2.0):
		if polygon.size() < 3:
			continue
		var contour := PackedVector2Array()
		for point in polygon:
			contour.append(point / Vector2(mask_size))
		contour.append(contour[0])
		_outline_contours.append(contour)

func _outline_local_points(contour: PackedVector2Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for uv in contour:
		points.append((uv - texture_region_ratio.position) / texture_region_ratio.size * size)
	return points

func _draw() -> void:
	if disabled or not (is_hovered() or has_focus() or is_pressed()):
		return
	if size.x <= 0.0 or size.y <= 0.0 or texture_region_ratio.size.x <= 0.0 or texture_region_ratio.size.y <= 0.0:
		return
	_ensure_outline_contours()
	var width := 2.0 if has_focus() or is_pressed() else 1.25
	var color := Color(1.0, 0.94, 0.68, 1.0) if has_focus() else Color(1.0, 0.86, 0.48, 0.92)
	for contour in _outline_contours:
		var points := _outline_local_points(contour)
		draw_polyline(points, Color(0.12, 0.08, 0.03, 0.65), width + 1.0, true)
		draw_polyline(points, color, width, true)

func _has_point(point: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	if painted_mask == null:
		return true
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	var uv := texture_region_ratio.position + point / size * texture_region_ratio.size
	var mask_size := painted_mask.get_size()
	var pixel := Vector2i(floori(uv.x * mask_size.x), floori(uv.y * mask_size.y))
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= mask_size.x or pixel.y >= mask_size.y:
		return false
	return painted_mask.get_bitv(pixel)
