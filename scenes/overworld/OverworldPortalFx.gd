extends Control

## The magic of portal networks, drawn as particles in the network's colour
## (docs/portal-networks.md). The sprites are bare stonework with a dark
## opening; here a Wayring's opening fills with a solid disc of colour turned
## by two lighter spiral bands, a Waygate's opening fills with colour that
## darkens into its centre under a lit rim while a few sparks drift in, and a
## Wayfall's dais takes a solid column of light and a calm splash.
##
## Motion is slow and the colour is solid: one clear shape per portal, not a
## cloud of dots. Every particle is a pure function of time and its portal, so
## nothing is simulated or saved. The layer is a child of the overworld object
## layer, so camera pans keep it on the art. Colour bodies blend normally, so
## the network colour stays true on any ground; the few sparks add light on a
## child layer above them. With reduced motion, and for portals remembered
## under fog, it draws one still frame so the network colour still reads.

const GEOMETRY_PATH := "res://art/overworld/portal_network_fx.json"
const FRAME_SECONDS := 1.0 / 30.0
const SPARK_WHITENING := 0.2
const REMEMBERED_STRENGTH := 0.5

var frames_drawn := 0
var animate := true
var _entries: Array = []
var _geometry: Dictionary = {}
var _time := 0.0
var _since_frame := 0.0
var _soft: Texture2D
var _solid: Texture2D
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
	# A soft round light, and a solid disc that only softens at its edge.
	_soft = _radial_texture([[0.0, 1.0], [0.3, 0.7], [1.0, 0.0]])
	_solid = _radial_texture([[0.0, 1.0], [0.72, 1.0], [1.0, 0.0]])
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

# One pass draws the colour bodies on this layer, the other the sparks on the
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

# The Wayring's opening is a solid disc of colour. Two lighter spiral bands
# turn slowly across it and a few motes glint along its rim.
func _swirl_disc(canvas: Rect2, geometry: Dictionary, colour: Color, salt: float, t: float, strength: float) -> void:
	var center := _point(canvas, geometry.center)
	var radius := _size(canvas, geometry.radius)
	var extent := canvas.size.x
	var turn := t * 0.45 + salt * TAU
	var breathe := sin(t * 0.8 + salt * 5.0)
	_fill(center, radius * 2.1, colour, 0.97 * strength)
	_glow(center, radius * 1.3, colour.lightened(0.3), (0.45 + 0.08 * breathe) * strength)
	for arm in range(2):
		for step in range(16):
			var reach := (float(step) + 0.5) / 16.0
			var angle := float(arm) * PI + reach * 2.2 * PI - turn
			var spot := center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * reach * 0.88
			_glow(spot, Vector2.ONE * extent * lerpf(0.08, 0.05, reach), colour.lightened(0.45), lerpf(0.8, 0.35, reach) * strength)
	for index in range(5):
		var angle := float(index) / 5.0 * TAU + t * 0.3 + salt * TAU
		var twinkle := 0.6 + 0.4 * sin(t * 1.3 + float(index) * 1.9 + salt * 7.0)
		_spark(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * 0.9, extent * 0.045, colour, 0.55 * twinkle * strength)

# The Waygate's opening fills with colour that darkens into its centre under
# a lit rim, where a soft shimmer travels round; a few sparks drift in.
func _inward_vortex(canvas: Rect2, geometry: Dictionary, colour: Color, salt: float, t: float, strength: float) -> void:
	var center := _point(canvas, geometry.center)
	var radius := _size(canvas, geometry.radius)
	var extent := canvas.size.x
	_fill(center, radius * 2.1, colour.darkened(0.08), 0.96 * strength)
	_fill(center, radius * 1.05, colour.darkened(0.55), 0.6 * strength)
	for index in range(28):
		var angle := float(index) / 28.0 * TAU
		var shimmer := 0.5 + 0.5 * sin(t * 1.1 - angle * 2.0 + salt * 6.0)
		_glow(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * 0.9, Vector2.ONE * extent * 0.06, colour.lightened(0.4), (0.35 + 0.35 * shimmer) * strength)
	for index in range(8):
		var life := lerpf(3.2, 4.4, _rand(salt, index, 0))
		var cycle := t / life + _rand(salt, index, 1)
		var phase := fposmod(cycle, 1.0)
		var reach := pow(1.0 - phase, 1.2) * 1.25
		var angle := (_rand(salt, index, 2) + floorf(cycle) * 0.618) * TAU + phase * 1.6 * PI
		_spark(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * reach, extent * lerpf(0.05, 0.025, phase), colour, sin(phase * PI) * 0.75 * strength)

# A solid column of light stands on the Wayfall's dais over a pool of colour.
# A few streaks run down it, and a ring of light spreads from its foot.
func _falling_beam(canvas: Rect2, geometry: Dictionary, colour: Color, salt: float, t: float, strength: float) -> void:
	var extent := canvas.size.x
	var beam_x := canvas.position.x + float(geometry.beam_x) * canvas.size.x
	var half_width := float(geometry.beam_half_width) * canvas.size.x
	var top := canvas.position.y + float(geometry.beam_top) * canvas.size.y
	var bottom := canvas.position.y + float(geometry.beam_bottom) * canvas.size.y
	var length := bottom - top
	var shaft := Vector2(beam_x, (top + bottom) * 0.5)
	var pulse := 0.05 * sin(t * 0.9 + salt * 5.0)
	var splash := _point(canvas, geometry.splash_center)
	var splash_radius := _size(canvas, geometry.splash_radius)
	_glow(splash, splash_radius * 2.3, colour, 0.35 * strength)
	_fill(splash, splash_radius * 1.7, colour, 0.8 * strength)
	_glow(shaft, Vector2(half_width * 4.5, length * 1.15), colour, 0.35 * strength)
	_fill(shaft, Vector2(half_width * 2.4, length * 1.02), colour, (0.88 + pulse) * strength)
	_fill(shaft, Vector2(half_width * 0.9, length * 0.98), colour.lightened(0.45), (0.7 + pulse) * strength)
	var ring := fposmod(t / 2.6 + salt, 1.0)
	for index in range(18):
		var angle := float(index) / 18.0 * TAU
		_glow(splash + Vector2(cos(angle) * splash_radius.x, sin(angle) * splash_radius.y) * lerpf(0.3, 1.15, ring), Vector2.ONE * extent * 0.04, colour.lightened(0.4), (1.0 - ring) * 0.6 * strength)
	for index in range(6):
		var life := lerpf(1.6, 2.4, _rand(salt, index, 0))
		var cycle := t / life + _rand(salt, index, 1)
		var phase := fposmod(cycle, 1.0)
		var offset := (_rand(salt + floorf(cycle), index, 2) - 0.5) * 1.2 * half_width
		_spark(Vector2(beam_x + offset, lerpf(top, bottom, phase)), extent, colour, sin(phase * PI) * 0.6 * strength, Vector2(extent * 0.025, extent * 0.11))
	for index in range(3):
		var life := lerpf(1.8, 2.4, _rand(salt, index, 7))
		var cycle := t / life + _rand(salt, index, 8)
		var age := fposmod(cycle, 1.0) * life
		var sideways := (_rand(salt + floorf(cycle), index, 9) * 2.0 - 1.0) * splash_radius.x * 0.8
		var upward := -splash_radius.y * 1.6
		var fall := splash_radius.y * 2.4
		_spark(splash + Vector2(sideways * age, upward * age + 0.5 * fall * age * age), extent * 0.04, colour, (1.0 - age / life) * 0.7 * strength)

# Solid colour with a soft edge, on the normal-blend layer.
func _fill(center: Vector2, diameter: Vector2, colour: Color, alpha: float) -> void:
	if not _drawing_sparks:
		_canvas.draw_texture_rect(_solid, Rect2(center - diameter * 0.5, diameter), false, Color(colour.r, colour.g, colour.b, clampf(alpha, 0.0, 1.0)))

# A soft pool of colour on the normal-blend layer.
func _glow(center: Vector2, diameter: Vector2, colour: Color, alpha: float) -> void:
	if not _drawing_sparks:
		_canvas.draw_texture_rect(_soft, Rect2(center - diameter * 0.5, diameter), false, Color(colour.r, colour.g, colour.b, clampf(alpha, 0.0, 1.0)))

# One glinting particle on the additive layer; stretch draws a streak.
func _spark(spot: Vector2, diameter: float, colour: Color, alpha: float, stretch: Vector2 = Vector2.ZERO) -> void:
	if alpha <= 0.01 or not _drawing_sparks:
		return
	var box := stretch if stretch != Vector2.ZERO else Vector2.ONE * diameter
	var hot := colour.lerp(Color.WHITE, SPARK_WHITENING)
	_canvas.draw_texture_rect(_soft, Rect2(spot - box * 0.5, box), false, Color(hot.r, hot.g, hot.b, clampf(alpha, 0.0, 1.0)))

func _point(canvas: Rect2, uv: Array) -> Vector2:
	return canvas.position + Vector2(float(uv[0]), float(uv[1])) * canvas.size

func _size(canvas: Rect2, uv: Array) -> Vector2:
	return Vector2(float(uv[0]), float(uv[1])) * canvas.size

func _rand(salt: float, index: int, channel: int) -> float:
	return fposmod(sin(salt * 12.9898 + float(index) * 78.233 + float(channel) * 37.719) * 43758.5453, 1.0)

# A white radial texture whose alpha follows [offset, alpha] stops.
func _radial_texture(stops: Array) -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(stops.map(func(stop): return float(stop[0])))
	gradient.colors = PackedColorArray(stops.map(func(stop): return Color(1.0, 1.0, 1.0, float(stop[1]))))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture
