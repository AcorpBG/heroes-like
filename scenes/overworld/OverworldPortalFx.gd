extends Control

## The magic of portal networks (docs/portal-networks.md). The sprites are bare
## stonework; the magic is the original painting's light, cut into effect
## layers (art/overworld/portal_network_fx.json) that this layer tints with the
## network colour and moves gently: a Wayring's painted swirl turns slowly
## inside its ring, a Waygate's vortex keeps sinking inward, a Wayfall's beam
## flows down and its splash ripples out. A handful of slow sparks glint on top.
##
## Everything is a pure function of time and the portal, so nothing is
## simulated or saved. The layer is a child of the overworld object layer, so
## camera pans keep it on the art. The painted light blends normally, so the
## network colour stays true on any ground; the sparks add light on a child
## layer above it. With reduced motion, and for portals remembered under fog,
## it draws one still frame so the network colour still reads.

const GEOMETRY_PATH := "res://art/overworld/portal_network_fx.json"
const FRAME_SECONDS := 1.0 / 30.0
const SPARK_WHITENING := 0.35
const REMEMBERED_STRENGTH := 0.55

var frames_drawn := 0
var animate := true
var _entries: Array = []
var _geometry: Dictionary = {}
var _time := 0.0
var _since_frame := 0.0
var _soft: Texture2D
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
	_soft = _radial_texture([[0.0, 1.0], [0.3, 0.7], [1.0, 0.0]])
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

## Effect layer asset ids for a portal sprite, by role (vortex, spill, beam,
## splash). The map view resolves them to textures.
func layer_assets(asset_id: String) -> Dictionary:
	var layers: Variant = _geometry.get(asset_id, {}).get("layers", {})
	return layers if layers is Dictionary else {}

## A portal drawn this frame: its asset id, network colour, the packed 512px
## canvas rectangle on this layer, its effect layer textures by role, whether
## it is only remembered under fog, and a per-portal seed.
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

# One pass draws the painted light on this layer, the other the sparks on the
# additive child; the effects below call both kinds and each pass keeps its own.
func _draw_pass(sparks: bool) -> void:
	_drawing_sparks = sparks
	_canvas = _sparks if sparks else self
	for entry in _entries:
		var geometry: Dictionary = _geometry.get(String(entry.asset_id), {})
		var salt := float(entry.get("seed", 0.0))
		var remembered := bool(entry.get("remembered", false))
		# A still frame differs per portal, so neighbours do not look stamped.
		var t := _time if animate and not remembered else 7.0 + salt * 11.0
		var strength := REMEMBERED_STRENGTH if remembered else 1.0
		match String(geometry.get("effect", "")):
			"swirl_disc":
				_swirl_disc(entry, geometry, salt, t, strength)
			"inward_vortex":
				_inward_vortex(entry, geometry, salt, t, strength)
			"falling_beam":
				_falling_beam(entry, geometry, salt, t, strength)

# The Wayring's painted swirl turns slowly inside its ring; light it spilled on
# the plinth breathes, its centre glows and a few motes glint on the rim.
func _swirl_disc(entry: Dictionary, geometry: Dictionary, salt: float, t: float, strength: float) -> void:
	var canvas: Rect2 = entry.canvas_rect
	var colour: Color = entry.color
	var center := _point(canvas, geometry.center)
	var radius := _size(canvas, geometry.radius)
	var breathe := sin(t * 0.7 + salt * 5.0)
	_layer(entry, "spill", colour, (0.85 + 0.1 * breathe) * strength)
	_layer(entry, "vortex", colour, strength, _turn_within(center, radius, -t * 0.3 - salt * TAU))
	_glow(center, radius * 1.1, colour, (0.18 + 0.06 * breathe) * strength)
	for index in range(4):
		var angle := float(index) / 4.0 * TAU + t * 0.25 + salt * TAU
		var twinkle := 0.5 + 0.5 * sin(t * 1.1 + float(index) * 1.9 + salt * 7.0)
		_spark(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * 0.85, canvas.size.x * 0.035, colour, 0.45 * twinkle * strength)

# The Waygate's painted vortex stays put while fainter copies of it keep
# shrinking into its centre, so it seems to draw inward; a few sparks drift in.
func _inward_vortex(entry: Dictionary, geometry: Dictionary, salt: float, t: float, strength: float) -> void:
	var canvas: Rect2 = entry.canvas_rect
	var colour: Color = entry.color
	var center := _point(canvas, geometry.center)
	var radius := _size(canvas, geometry.radius)
	_layer(entry, "spill", colour, (0.85 + 0.1 * sin(t * 0.7 + salt * 5.0)) * strength)
	_layer(entry, "vortex", colour, strength)
	for copy in range(2):
		var phase := fposmod(t / 3.6 + float(copy) * 0.5 + salt, 1.0)
		_layer(entry, "vortex", colour.lightened(0.25), sin(phase * PI) * 0.35 * strength, _scale_about(center, lerpf(1.0, 0.6, phase)))
	for index in range(5):
		var life := lerpf(3.4, 4.6, _rand(salt, index, 0))
		var cycle := t / life + _rand(salt, index, 1)
		var phase := fposmod(cycle, 1.0)
		var reach := pow(1.0 - phase, 1.2) * 1.1
		var angle := (_rand(salt, index, 2) + floorf(cycle) * 0.618) * TAU + phase * 1.4 * PI
		_spark(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * reach, canvas.size.x * lerpf(0.04, 0.02, phase), colour, sin(phase * PI) * 0.6 * strength)

# The Wayfall's painted beam flows down, fainter copies of it sliding toward
# the dais; its painted splash ripples outward and a few streaks glint.
func _falling_beam(entry: Dictionary, geometry: Dictionary, salt: float, t: float, strength: float) -> void:
	var canvas: Rect2 = entry.canvas_rect
	var colour: Color = entry.color
	var extent := canvas.size.x
	var beam_x := canvas.position.x + float(geometry.beam_x) * canvas.size.x
	var half_width := float(geometry.beam_half_width) * canvas.size.x
	var top := canvas.position.y + float(geometry.beam_top) * canvas.size.y
	var bottom := canvas.position.y + float(geometry.beam_bottom) * canvas.size.y
	var splash := _point(canvas, geometry.splash_center)
	_layer(entry, "splash", colour, strength)
	for copy in range(2):
		var phase := fposmod(t / 3.0 + float(copy) * 0.5 + salt, 1.0)
		_layer(entry, "splash", colour.lightened(0.2), (1.0 - phase) * 0.35 * strength, _scale_about(splash, lerpf(0.9, 1.35, phase)))
	_layer(entry, "beam", colour, (0.92 + 0.06 * sin(t * 1.1 + salt * 4.0)) * strength)
	for copy in range(2):
		var phase := fposmod(t / 2.2 + float(copy) * 0.5 + salt, 1.0)
		_layer(entry, "beam", colour.lightened(0.25), sin(phase * PI) * 0.3 * strength, Transform2D(0.0, Vector2(0.0, phase * (bottom - top) * 0.15)))
	for index in range(4):
		var life := lerpf(1.8, 2.6, _rand(salt, index, 0))
		var cycle := t / life + _rand(salt, index, 1)
		var phase := fposmod(cycle, 1.0)
		var offset := (_rand(salt + floorf(cycle), index, 2) - 0.5) * 1.2 * half_width
		_spark(Vector2(beam_x + offset, lerpf(top, bottom, phase)), extent, colour, sin(phase * PI) * 0.45 * strength, Vector2(extent * 0.02, extent * 0.09))

# A painted effect layer over the portal's whole 512px canvas, tinted with the
# network colour, optionally moved by a transform on the layer's coordinates.
func _layer(entry: Dictionary, role: String, colour: Color, alpha: float, motion: Transform2D = Transform2D()) -> void:
	var texture: Variant = entry.get("layers", {}).get(role)
	if _drawing_sparks or not (texture is Texture2D) or alpha <= 0.01:
		return
	_canvas.draw_set_transform_matrix(motion)
	_canvas.draw_texture_rect(texture, entry.canvas_rect, false, Color(colour.r, colour.g, colour.b, clampf(alpha, 0.0, 1.0)))
	_canvas.draw_set_transform_matrix(Transform2D())

# Turns a layer about an ellipse's centre while keeping the ellipse in place:
# squash it to a circle, rotate, stretch back.
func _turn_within(center: Vector2, radius: Vector2, angle: float) -> Transform2D:
	var squash := Transform2D(Vector2(1.0, 0.0), Vector2(0.0, radius.y / maxf(radius.x, 0.001)), Vector2.ZERO)
	return Transform2D(0.0, center) * squash * Transform2D(angle, Vector2.ZERO) * squash.affine_inverse() * Transform2D(0.0, -center)

func _scale_about(center: Vector2, factor: float) -> Transform2D:
	return Transform2D(0.0, center) * Transform2D(0.0, Vector2.ONE * factor, 0.0, Vector2.ZERO) * Transform2D(0.0, -center)

# A soft pool of light on the normal-blend layer.
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
