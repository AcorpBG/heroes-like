class_name BattleCommandButton
extends Button
## A square button on the battle command bar: a drawn glyph instead of text,
## an optional badge (the hero's mana on the spellbook) and the letter of its
## hotkey. The glyphs are drawn, so they stay sharp at every window size.
## docs/battle-rework.md (D11).

const GOLD := Color(0.878, 0.722, 0.4)
const GOLD_DIM := Color(0.878, 0.722, 0.4, 0.35)
const ACTIVE := Color(0.988, 0.878, 0.478)
const INK := Color(0.925, 0.851, 0.678)
const FILL := Color(0.157, 0.129, 0.090, 0.96)
const FILL_HOVER := Color(0.208, 0.173, 0.118, 0.98)
const FILL_PRESSED := Color(0.110, 0.090, 0.059, 0.98)
const BADGE_FILL := Color(0.114, 0.239, 0.431)
const BADGE_BORDER := Color(0.510, 0.725, 1.0)
const BADGE_TEXT := Color(0.906, 0.949, 1.0)
# The glyphs are designed on a 24x24 grid.
const GRID := 24.0

@export var glyph := ""
@export var key_hint := ""
var badge_text := ""
var _scale := 1.0
var _base_size := Vector2(46.0, 46.0)
var _glyph_extent := 24.0


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	flat = false
	clip_text = true
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggled.connect(_on_toggled)
	if custom_minimum_size != Vector2.ZERO:
		_base_size = custom_minimum_size
	apply_scale(_scale, _base_size)


func _on_toggled(_on: bool) -> void:
	queue_redraw()


## Sizes and styles the button for a window scaled by k.
func apply_scale(k: float, base_size: Vector2) -> void:
	_scale = maxf(0.3, k)
	_base_size = base_size
	custom_minimum_size = base_size * _scale
	size = custom_minimum_size
	_glyph_extent = minf(base_size.x, base_size.y) * 0.52 * _scale
	var radius := int(round(10.0 * _scale))
	add_theme_stylebox_override("normal", _style(FILL, GOLD_DIM, radius))
	add_theme_stylebox_override("hover", _style(FILL_HOVER, GOLD, radius))
	add_theme_stylebox_override("pressed", _style(FILL_PRESSED, ACTIVE, radius))
	add_theme_stylebox_override("hover_pressed", _style(FILL_PRESSED, ACTIVE, radius))
	add_theme_stylebox_override("disabled", _style(Color(FILL, 0.6), Color(GOLD_DIM, 0.18), radius))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_corner_radius_all(radius + 2)
	focus.set_border_width_all(maxi(2, int(round(2.0 * _scale))))
	focus.border_color = Color(ACTIVE, 0.95)
	focus.set_expand_margin_all(3.0 * _scale)
	add_theme_stylebox_override("focus", focus)
	queue_redraw()


func set_badge(value: String) -> void:
	if value != badge_text:
		badge_text = value
		queue_redraw()


func _style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(maxi(1, int(round(1.0 * _scale))))
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = int(round(3.0 * _scale))
	style.shadow_offset = Vector2(0.0, 1.0) * _scale
	return style


func _draw() -> void:
	var tint := INK
	if disabled:
		tint = Color(INK, 0.32)
	elif button_pressed and toggle_mode:
		tint = ACTIVE
	elif is_hovered():
		tint = Color(1.0, 0.953, 0.816)
	var center := size * 0.5 + (Vector2(0.0, 1.0) * _scale if is_pressed() and not toggle_mode else Vector2.ZERO)
	var unit := _glyph_extent / GRID
	draw_set_transform(center - Vector2(GRID, GRID) * 0.5 * unit, 0.0, Vector2(unit, unit))
	_draw_glyph(tint, 1.9)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if key_hint != "" and not disabled:
		var font := get_theme_default_font()
		var font_size := maxi(8, int(round(10.0 * _scale)))
		var hint_size := font.get_string_size(key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		draw_string(font, Vector2(size.x - hint_size.x - 4.0 * _scale, size.y - 3.0 * _scale), key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(INK, 0.55))
	if badge_text != "":
		_draw_badge()


func _draw_badge() -> void:
	var font := get_theme_default_font()
	var font_size := maxi(8, int(round(11.0 * _scale)))
	var text_size := font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var height := 15.0 * _scale
	var width := maxf(21.0 * _scale, text_size.x + 8.0 * _scale)
	var rect := Rect2(Vector2(size.x - width + 6.0 * _scale, -7.0 * _scale), Vector2(width, height))
	var style := StyleBoxFlat.new()
	style.bg_color = BADGE_FILL if not disabled else Color(BADGE_FILL, 0.6)
	style.border_color = BADGE_BORDER
	style.set_border_width_all(maxi(1, int(round(_scale))))
	style.set_corner_radius_all(int(round(height * 0.5)))
	draw_style_box(style, rect)
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var baseline := rect.position.y + (height + ascent - descent) * 0.5
	draw_string(font, Vector2(rect.position.x + (width - text_size.x) * 0.5, baseline), badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, BADGE_TEXT)


## Glyphs on the 24x24 grid, drawn in tint with strokes of width line.
func _draw_glyph(tint: Color, line: float) -> void:
	match glyph:
		"gear":
			var points := PackedVector2Array()
			for tooth in range(8):
				var angle := float(tooth) / 8.0 * TAU
				for pair in [[7.4, -0.33], [10.2, -0.17], [10.2, 0.17], [7.4, 0.33]]:
					var radius: float = pair[0]
					var offset: float = pair[1]
					points.append(Vector2(12.0, 12.0) + Vector2.from_angle(angle + offset) * radius)
			draw_colored_polygon(points, tint)
			draw_circle(Vector2(12.0, 12.0), 3.4, FILL)
		"flag":
			draw_line(Vector2(6.0, 3.0), Vector2(6.0, 22.0), tint, line, true)
			draw_colored_polygon(PackedVector2Array([
				Vector2(7.0, 4.0), Vector2(12.0, 2.8), Vector2(16.0, 4.6), Vector2(20.0, 3.6),
				Vector2(20.0, 12.6), Vector2(16.0, 13.6), Vector2(12.0, 11.8), Vector2(7.0, 13.0),
			]), tint)
		"retreat":
			draw_polyline(_arc(Vector2(12.0, 13.0), 7.0, -PI * 0.5, PI * 0.62, 12), tint, line, true)
			draw_line(Vector2(12.0, 6.0), Vector2(4.5, 6.0), tint, line, true)
			draw_colored_polygon(PackedVector2Array([Vector2(3.0, 6.0), Vector2(8.0, 2.0), Vector2(8.0, 10.0)]), tint)
			draw_line(Vector2(15.0, 19.4), Vector2(21.0, 19.4), tint, line, true)
		"auto":
			draw_polyline(_arc(Vector2(12.0, 12.0), 8.0, -PI * 0.92, PI * 0.08, 14), tint, line, true)
			draw_polyline(_arc(Vector2(12.0, 12.0), 8.0, PI * 0.08, PI * 1.08, 14), tint, line, true)
			draw_colored_polygon(PackedVector2Array([Vector2(17.4, 9.0), Vector2(21.6, 9.6), Vector2(19.2, 13.4)]), tint)
			draw_colored_polygon(PackedVector2Array([Vector2(6.6, 15.0), Vector2(2.4, 14.4), Vector2(4.8, 10.6)]), tint)
			draw_colored_polygon(PackedVector2Array([Vector2(10.0, 8.6), Vector2(15.4, 12.0), Vector2(10.0, 15.4)]), tint)
		"quick":
			draw_colored_polygon(PackedVector2Array([
				Vector2(13.6, 2.0), Vector2(5.0, 13.4), Vector2(11.0, 13.4), Vector2(9.6, 22.0),
				Vector2(19.0, 9.8), Vector2(13.0, 9.8),
			]), tint)
		"chevron":
			draw_polyline(PackedVector2Array([Vector2(6.0, 15.0), Vector2(12.0, 9.0), Vector2(18.0, 15.0)]), tint, line * 1.15, true)
		"book":
			draw_colored_polygon(PackedVector2Array([
				Vector2(2.5, 6.0), Vector2(7.0, 4.6), Vector2(11.2, 5.6), Vector2(11.2, 20.0),
				Vector2(7.0, 18.8), Vector2(2.5, 20.0),
			]), tint)
			draw_colored_polygon(PackedVector2Array([
				Vector2(12.8, 5.6), Vector2(17.0, 4.6), Vector2(21.5, 6.0), Vector2(21.5, 20.0),
				Vector2(17.0, 18.8), Vector2(12.8, 20.0),
			]), tint)
			for y in [9.0, 12.0, 15.0]:
				draw_line(Vector2(4.6, y), Vector2(9.4, y - 0.6), FILL, 1.0, true)
				draw_line(Vector2(14.6, y - 0.6), Vector2(19.4, y), FILL, 1.0, true)
		"hourglass":
			draw_line(Vector2(5.0, 3.0), Vector2(19.0, 3.0), tint, line, true)
			draw_line(Vector2(5.0, 21.0), Vector2(19.0, 21.0), tint, line, true)
			draw_polyline(PackedVector2Array([Vector2(7.0, 3.0), Vector2(7.0, 6.0), Vector2(12.0, 12.0), Vector2(7.0, 18.0), Vector2(7.0, 21.0)]), tint, line, true)
			draw_polyline(PackedVector2Array([Vector2(17.0, 3.0), Vector2(17.0, 6.0), Vector2(12.0, 12.0), Vector2(17.0, 18.0), Vector2(17.0, 21.0)]), tint, line, true)
			draw_colored_polygon(PackedVector2Array([Vector2(9.0, 19.6), Vector2(12.0, 15.6), Vector2(15.0, 19.6)]), tint)
		"shield":
			draw_colored_polygon(PackedVector2Array([
				Vector2(12.0, 2.4), Vector2(20.0, 5.2), Vector2(19.4, 12.6), Vector2(16.6, 17.8),
				Vector2(12.0, 21.6), Vector2(7.4, 17.8), Vector2(4.6, 12.6), Vector2(4.0, 5.2),
			]), tint)
			draw_line(Vector2(12.0, 5.4), Vector2(12.0, 18.4), FILL, 1.4, true)
			draw_line(Vector2(6.8, 10.0), Vector2(17.2, 10.0), FILL, 1.4, true)
		_:
			draw_circle(Vector2(12.0, 12.0), 4.0, tint)


func _arc(center: Vector2, radius: float, from_angle: float, to_angle: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in range(steps + 1):
		points.append(center + Vector2.from_angle(lerpf(from_angle, to_angle, float(step) / float(steps))) * radius)
	return points
