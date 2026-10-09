extends Control
## Floating gain text above the map (owner request 2026-10-09): what the hero
## just gained floats up from its tile, one line each (icon and words), and
## slowly fades out. Lines wait for the hero's walk to finish, appear one
## after another and follow the camera. Presentation only.

const FrontierVisualKitScript = preload("res://scripts/ui/FrontierVisualKit.gd")

const LIFETIME := 3.4
const FADE_IN := 0.25
const FADE_OUT := 1.6
const RISE := 44.0
const STAGGER := 0.35
const LINE_GAP := 30.0
const FONT_SIZE := 20
const OUTLINE_SIZE := 6
const ICON_SIZE := 26.0
const ICON_GAP := 6.0
const TONES := {
	"gain": "gold",
	"claim": "green",
	"artifact": "title",
	"cost": "red",
}

## Supplies tile positions (gain_anchor_for_tile) and the walk state
## (gain_floaters_should_wait).
var map_view: Control
var _pending: Array = []
var _live: Array = []
var _textures := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)

## Queue `lines` (OverworldGainFeed.gains) to float up from `tile`.
func show_gains(tile: Vector2i, lines: Array) -> void:
	if lines.is_empty():
		return
	_pending.append({"tile": tile, "lines": lines.duplicate(true)})
	set_process(true)

func clear() -> void:
	_pending.clear()
	_live.clear()
	set_process(false)
	queue_redraw()

## Read-only state for tests: pending groups and floating lines.
func snapshot() -> Dictionary:
	var texts := []
	for floater in _live:
		texts.append(String(floater.line.get("text", "")))
	return {"pending": _pending.size(), "live": _live.size(), "texts": texts}

func _process(delta: float) -> void:
	if not _pending.is_empty() and not _should_wait():
		for group in _pending:
			var count: int = group.lines.size()
			for index in range(count):
				var line: Dictionary = group.lines[index]
				_live.append({
					"tile": group.tile,
					"line": line,
					"row": count - 1 - index,
					"age": -STAGGER * float(index),
					"texture": _texture(String(line.get("icon", ""))),
				})
		_pending.clear()
	for floater in _live:
		floater.age += delta
	_live = _live.filter(func(floater): return float(floater.age) < LIFETIME)
	queue_redraw()
	if _live.is_empty() and _pending.is_empty():
		set_process(false)

func _should_wait() -> bool:
	return map_view != null and bool(map_view.call("gain_floaters_should_wait"))

func _draw() -> void:
	if map_view == null:
		return
	var font := get_theme_default_font()
	var reduced_motion := SettingsService.reduced_motion_enabled()
	for floater in _live:
		var age := float(floater.age)
		if age < 0.0:
			continue
		var alpha := clampf(age / FADE_IN, 0.0, 1.0) * clampf((LIFETIME - age) / FADE_OUT, 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var anchor: Vector2 = map_view.call("gain_anchor_for_tile", floater.tile)
		var rise := 0.0 if reduced_motion else RISE * (1.0 - pow(1.0 - age / LIFETIME, 2.0))
		var line: Dictionary = floater.line
		var text := String(line.get("text", ""))
		var texture: Texture2D = floater.texture
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE)
		var width := text_size.x + (ICON_SIZE + ICON_GAP if texture != null else 0.0)
		var baseline := anchor + Vector2(-width * 0.5, -float(int(floater.row)) * LINE_GAP - rise)
		var color := FrontierVisualKitScript.text_color(String(TONES.get(String(line.get("tone", "gain")), "gold")))
		color.a = alpha
		var outline := Color(0.03, 0.03, 0.04, 0.85 * alpha)
		var text_x := baseline.x
		if texture != null:
			var icon_rect := Rect2(Vector2(baseline.x, baseline.y - ICON_SIZE * 0.78), Vector2(ICON_SIZE, ICON_SIZE))
			draw_texture_rect(texture, icon_rect.grow(1.5), false, Color(0.0, 0.0, 0.0, 0.45 * alpha))
			draw_texture_rect(texture, icon_rect, false, Color(1.0, 1.0, 1.0, alpha))
			text_x += ICON_SIZE + ICON_GAP
		var position := Vector2(text_x, baseline.y)
		draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, OUTLINE_SIZE, outline)
		draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, color)

func _texture(path: String) -> Texture2D:
	if path == "":
		return null
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path, "Texture2D") else null
	return _textures[path]
