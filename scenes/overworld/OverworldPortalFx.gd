extends Control

## The magic of portal networks, drawn entirely as particles in the network's
## colour (docs/portal-networks.md). The sprites are bare stonework with a dark
## opening; here a Wayring's disc swirls in three spiral arms with motes
## circling its ring, a Waygate's vortex draws sparks in around its lit rim,
## and a Wayfall's column of light pours onto its dais and splashes.
##
## Every particle is a pure function of time and its portal, so nothing is
## simulated or saved. The layer is a child of the overworld object layer,
## so camera pans keep it on the art. Glow bodies blend normally, so the
## network colour stays true on any ground; sparks add light on a child layer
## above them. With reduced motion, and for portals remembered under fog, it
## draws one still frame so the network colour still reads.

const GEOMETRY_PATH := "res://art/overworld/portal_network_fx.json"
const FRAME_SECONDS := 1.0 / 30.0
const WHITE_CORE := 0.45
const REMEMBERED_STRENGTH := 0.45

var frames_drawn := 0
var animate := true
var _entries: Array = []
var _geometry: Dictionary = {}
var _time := 0.0
var _since_frame := 0.0
var _sparkle: Texture2D
var _sparks: Control
var _canvas: CanvasItem
var _drawing_sparks := false

func _init() -> void:
	name = "PortalNetworkFx"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_sparks = Control.new()
	_sparks.name = "PortalNetworkSparks"
	_sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparks.focus_mode = Control.FOCUS_NONE
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sparks.material = additive
	_sparks.draw.connect(_draw_pass.bind(true))
	add_child(_sparks)
	_sparkle = _make_sparkle()
	var file := FileAccess.open(GEOMETRY_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	_geometry = parsed.get("assets", {}) if parsed is Dictionary else {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sparks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func clear() -> void:
	_entries.clear()
	_redraw()

func _redraw() -> void:
	queue_redraw()
	_sparks.queue_redraw()

## A portal drawn this frame: its asset id, network colour, the packed 512px
## canvas rectangle on this layer, whether it is only remembered under fog,
## and a per-portal seed.
func add(entry: Dictionary) -> void:
	if _geometry.has(String(entry.get("asset_id", ""))):
		_entries.append(entry)

func has_portals() -> bool:
	return not _entries.is_empty()

## Whether any portal on screen moves: remembered portals and reduced motion
## keep a still frame and need no frame loop.
func is_animating() -> bool:
	return animate and _entries.any(func(entry): return not bool(entry.get("remembered", false)))

func advance(delta: float) -> void:
	_time += maxf(0.0, delta)
	_since_frame += maxf(0.0, delta)
	if _since_frame >= FRAME_SECONDS:
		_since_frame = fmod(_since_frame, FRAME_SECONDS)
		_redraw()

func snapshot() -> Dictionary:
	var effects := []
	var rects := []
	for entry in _entries:
		effects.append(String(_geometry.get(String(entry.asset_id), {}).get("effect", "")))
		var canvas: Rect2 = entry.canvas_rect
		rects.append(Rect2(canvas.position + global_position, canvas.size))
	return {"portals": _entries.size(), "effects": effects, "viewport_rects": rects, "animating": is_animating(), "time": _time, "frames_drawn": frames_drawn}

func _draw() -> void:
	frames_drawn += 1
	_draw_pass(false)

# One pass draws the glow bodies on this layer, the other the sparks on the
# additive child; the effects below call both kinds and each pass keeps its own.
func _draw_pass(sparks: bool) -> void:
	_drawing_sparks = sparks
	_canvas = _sparks if sparks else self
	for entry in _entries:
		var geometry: Dictionary = _geometry.get(String(entry.asset_id), {})
		var canvas: Rect2 = entry.canvas_rect
		var salt := float(entry.get("seed", 0.0))
		var remembered := bool(entry.get("remembered", false))
		# A still frame differs per portal, so neighbours do not look stamped.
		var t := _time if animate and not remembered else 7.0 + salt * 11.0
		var strength := REMEMBERED_STRENGTH if remembered else 1.0
		var colour: Color = entry.color
		match String(geometry.get("effect", "")):
			"swirl_disc":
				_swirl_disc(canvas, geometry, colour, salt, t, strength)
			"inward_vortex":
				_inward_vortex(canvas, geometry, colour, salt, t, strength)
			"falling_beam":
				_falling_beam(canvas, geometry, colour, salt, t, strength)

# The Wayring's disc glows and turns in three spiral arms; motes circle just
# outside the ring and a few sparks drift off it.
func _swirl_disc(canvas: Rect2, geometry: Dictionary, colour: Color, salt: float, t: float, strength: float) -> void:
	var center := _point(canvas, geometry.center)
	var radius := _size(canvas, geometry.radius)
	var extent := canvas.size.x
	var breathe := sin(t * 1.7 + salt * 5.0)
	_halo(center, radius * 2.0, colour, (0.85 + 0.1 * breathe) * strength)
	_halo(center, radius * 1.0, colour.lerp(Color.WHITE, 0.35), (0.6 + 0.15 * breathe) * strength)
	for arm in range(3):
		for step in range(18):
			var reach := (float(step) + 0.5) / 18.0
			var angle := float(arm) * TAU / 3.0 + reach * 2.6 * PI - t * 1.5 + salt * TAU
			var wobble := 1.0 + 0.06 * sin(t * 3.0 + float(step) + float(arm) * 2.0)
			var spot := center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * reach * 0.92 * wobble
			var flicker := 0.6 + 0.4 * sin(t * lerpf(2.5, 6.0, _rand(salt, arm * 18 + step, 0)) + float(step))
			_spark(spot, extent * lerpf(0.06, 0.03, reach), colour.lerp(Color.WHITE, (1.0 - reach) * 0.6), flicker * lerpf(0.95, 0.55, reach) * strength)
	for index in range(14):
		var band := lerpf(1.0, 1.4, _rand(salt, index, 1))
		var speed := lerpf(0.7, 1.5, _rand(salt, index, 2)) * (-1.0 if index % 3 == 0 else 1.0)
		var angle := _rand(salt, index, 3) * TAU + t * speed
		var flicker := 0.55 + 0.45 * sin(t * lerpf(3.0, 7.0, _rand(salt, index, 4)) + float(index))
		_spark(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * band, extent * lerpf(0.04, 0.065, _rand(salt, index, 5)), colour, flicker * 0.85 * strength)
	for index in range(6):
		var cycle := t / 1.4 + _rand(salt, index, 6)
		var phase := fposmod(cycle, 1.0)
		var angle := (_rand(salt, index, 7) + floorf(cycle) * 0.618) * TAU
		var drift := Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * (1.0 + phase * 0.9)
		_spark(center + drift, extent * 0.05 * (1.0 - phase * 0.5), colour, (1.0 - phase) * 0.8 * strength)

# The Waygate's opening fills with a dim glow and a lit rim, and sparks are
# drawn in from around the arch and spiral down into the dark centre.
func _inward_vortex(canvas: Rect2, geometry: Dictionary, colour: Color, salt: float, t: float, strength: float) -> void:
	var center := _point(canvas, geometry.center)
	var radius := _size(canvas, geometry.radius)
	var extent := canvas.size.x
	_halo(center, radius * 2.0, colour.darkened(0.25), (0.8 + 0.1 * sin(t * 2.1 + salt * 5.0)) * strength)
	for index in range(22):
		var angle := float(index) / 22.0 * TAU
		var flicker := 0.5 + 0.5 * sin(t * 4.0 + float(index) * 1.7 + salt * 9.0)
		_spark(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * 0.95, extent * 0.035, colour, (0.35 + 0.4 * flicker) * strength)
	for index in range(34):
		var life := lerpf(1.2, 2.0, _rand(salt, index, 0))
		var cycle := t / life + _rand(salt, index, 1)
		var phase := fposmod(cycle, 1.0)
		var reach := pow(1.0 - phase, 1.3) * (1.6 if index % 4 == 0 else 1.0)
		var angle := (_rand(salt, index, 2) + floorf(cycle) * 0.618) * TAU + phase * 3.6 * PI
		var spot := center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * reach
		var tone := colour.lerp(Color.WHITE, phase * 0.5)
		_spark(spot, extent * lerpf(0.07, 0.025, phase), tone, sin(phase * PI) * 0.95 * strength)

# A column of light pours down onto the Wayfall's dais: a glowing shaft with
# falling streaks, and a splash that rings outward and throws sparks.
func _falling_beam(canvas: Rect2, geometry: Dictionary, colour: Color, salt: float, t: float, strength: float) -> void:
	var extent := canvas.size.x
	var beam_x := canvas.position.x + float(geometry.beam_x) * canvas.size.x
	var half_width := float(geometry.beam_half_width) * canvas.size.x
	var top := canvas.position.y + float(geometry.beam_top) * canvas.size.y
	var bottom := canvas.position.y + float(geometry.beam_bottom) * canvas.size.y
	var flicker := 0.06 * sin(t * 9.0 + salt * 7.0) + 0.04 * sin(t * 23.0 + salt)
	var shaft := Vector2(beam_x, (top + bottom) * 0.5)
	_halo(shaft, Vector2(half_width * 3.6, (bottom - top) * 1.15), colour, (0.7 + flicker) * strength)
	_halo(shaft, Vector2(half_width * 1.5, (bottom - top) * 1.05), colour.lerp(Color.WHITE, 0.5), (0.75 + flicker) * strength)
	for index in range(20):
		var life := lerpf(0.6, 1.1, _rand(salt, index, 0))
		var cycle := t / life + _rand(salt, index, 1)
		var phase := fposmod(cycle, 1.0)
		var offset := (_rand(salt + floorf(cycle), index, 2) - 0.5) * 1.6 * half_width
		var streak := Vector2(extent * 0.03, extent * lerpf(0.09, 0.15, _rand(salt, index, 3)))
		_spark(Vector2(beam_x + offset, lerpf(top, bottom, phase * phase)), extent, colour.lerp(Color.WHITE, 0.3), sin(phase * PI) * 0.9 * strength, streak)
	var splash := _point(canvas, geometry.splash_center)
	var splash_radius := _size(canvas, geometry.splash_radius)
	_halo(splash, splash_radius * 2.0, colour, (0.65 + 0.1 * sin(t * 3.1 + salt * 4.0)) * strength)
	for ring in range(2):
		var phase := fposmod(t / 1.1 + float(ring) * 0.5 + salt, 1.0)
		for index in range(14):
			var angle := float(index) / 14.0 * TAU
			_spark(splash + Vector2(cos(angle) * splash_radius.x, sin(angle) * splash_radius.y) * lerpf(0.25, 1.1, phase), extent * 0.04, colour, (1.0 - phase) * 0.65 * strength)
	for index in range(10):
		var life := lerpf(0.7, 1.2, _rand(salt, index, 7))
		var cycle := t / life + _rand(salt, index, 8)
		var age := fposmod(cycle, 1.0) * life
		var sideways := (_rand(salt + floorf(cycle), index, 9) * 2.0 - 1.0) * splash_radius.x * 2.4
		var upward := -splash_radius.y * 4.0 * lerpf(0.6, 1.0, _rand(salt, index, 10))
		var fall := splash_radius.y * 11.0
		_spark(splash + Vector2(sideways * age, upward * age + 0.5 * fall * age * age), extent * 0.045, colour, (1.0 - age / life) * 0.9 * strength)

# A soft pool of light in the network colour.
func _halo(center: Vector2, diameter: Vector2, colour: Color, alpha: float) -> void:
	if _drawing_sparks:
		return
	_canvas.draw_texture_rect(_sparkle, Rect2(center - diameter * 0.5, diameter), false, Color(colour.r, colour.g, colour.b, clampf(alpha, 0.0, 1.0)))

# One glowing particle with a whiter core; stretch draws a streak instead.
func _spark(spot: Vector2, diameter: float, colour: Color, alpha: float, stretch: Vector2 = Vector2.ZERO) -> void:
	if alpha <= 0.01 or not _drawing_sparks:
		return
	var box := stretch if stretch != Vector2.ZERO else Vector2.ONE * diameter
	var hot := colour.lerp(Color.WHITE, WHITE_CORE)
	_canvas.draw_texture_rect(_sparkle, Rect2(spot - box * 0.5, box), false, Color(hot.r, hot.g, hot.b, clampf(alpha, 0.0, 1.0)))

func _point(canvas: Rect2, uv: Array) -> Vector2:
	return canvas.position + Vector2(float(uv[0]), float(uv[1])) * canvas.size

func _size(canvas: Rect2, uv: Array) -> Vector2:
	return Vector2(float(uv[0]), float(uv[1])) * canvas.size

func _rand(salt: float, index: int, channel: int) -> float:
	return fposmod(sin(salt * 12.9898 + float(index) * 78.233 + float(channel) * 37.719) * 43758.5453, 1.0)

func _make_sparkle() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.3, Color(1.0, 1.0, 1.0, 0.7))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	return texture
