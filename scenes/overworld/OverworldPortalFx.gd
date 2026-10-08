extends Control

## Animated light for portal networks (docs/portal-networks.md): motes orbit a
## Wayring's disc, sparks spiral into a Waygate, and light pours down a
## Wayfall's beam into a splash on its dais. Every particle is a pure function
## of time and its portal, so nothing is simulated or saved. The layer is a
## child of the overworld object layer, so camera pans move it with the art,
## and it draws additively in the portal's network colour.

const GEOMETRY_PATH := "res://art/overworld/portal_network_fx.json"
const FRAME_SECONDS := 1.0 / 30.0
const WHITE_CORE := 0.45

var frames_drawn := 0
var _entries: Array = []
var _geometry: Dictionary = {}
var _time := 0.0
var _since_frame := 0.0
var _sparkle: Texture2D

func _init() -> void:
	name = "PortalNetworkFx"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	_sparkle = _make_sparkle()
	var file := FileAccess.open(GEOMETRY_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	_geometry = parsed.get("assets", {}) if parsed is Dictionary else {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func clear() -> void:
	_entries.clear()
	queue_redraw()

## A visible portal drawn this frame: its asset id, network colour, the packed
## 512px canvas rectangle on this layer, its glow texture with the region the
## sprite drew, and a per-portal salt.
func add(entry: Dictionary) -> void:
	if _geometry.has(String(entry.get("asset_id", ""))):
		_entries.append(entry)

func has_portals() -> bool:
	return not _entries.is_empty()

func advance(delta: float) -> void:
	_time += maxf(0.0, delta)
	_since_frame += maxf(0.0, delta)
	if _since_frame >= FRAME_SECONDS:
		_since_frame = fmod(_since_frame, FRAME_SECONDS)
		queue_redraw()

func snapshot() -> Dictionary:
	var effects := []
	var rects := []
	for entry in _entries:
		effects.append(String(_geometry.get(String(entry.asset_id), {}).get("effect", "")))
		var canvas: Rect2 = entry.canvas_rect
		rects.append(Rect2(canvas.position + global_position, canvas.size))
	return {"portals": _entries.size(), "effects": effects, "viewport_rects": rects, "time": _time, "frames_drawn": frames_drawn}

func _draw() -> void:
	frames_drawn += 1
	for entry in _entries:
		var geometry: Dictionary = _geometry.get(String(entry.asset_id), {})
		var canvas: Rect2 = entry.canvas_rect
		var colour: Color = entry.color
		var salt := float(entry.get("seed", 0.0))
		_pulse(entry, colour, salt)
		match String(geometry.get("effect", "")):
			"orbit":
				_orbit(canvas, geometry, colour, salt)
			"inward_spiral":
				_inward_spiral(canvas, geometry, colour, salt)
			"falling_beam":
				_falling_beam(canvas, geometry, colour, salt)

# The glow layer brightens and dims, so the magic breathes.
func _pulse(entry: Dictionary, colour: Color, salt: float) -> void:
	var strength := 0.16 + 0.12 * sin(_time * 2.3 + salt * 6.0)
	draw_texture_rect_region(entry.glow, entry.glow_rect, entry.glow_source, Color(colour.r, colour.g, colour.b, strength))

# Motes circle the Wayring's disc in both directions; a few sparks drift off
# its rim and fade.
func _orbit(canvas: Rect2, geometry: Dictionary, colour: Color, salt: float) -> void:
	var center := _point(canvas, geometry.center)
	var radius := _size(canvas, geometry.radius)
	var extent := canvas.size.x
	_halo(center, radius * 3.0, colour, 0.3 + 0.1 * sin(_time * 1.7 + salt * 5.0))
	# Most motes circle just outside the stone ring, where they read against
	# the ground; a few hot ones turn inside the bright disc.
	for index in range(16):
		var band := lerpf(1.0, 1.45, _rand(salt, index, 0)) if index % 4 != 0 else lerpf(0.3, 0.75, _rand(salt, index, 0))
		var speed := lerpf(0.7, 1.6, _rand(salt, index, 1)) * (-1.0 if index % 3 == 0 else 1.0)
		var angle := _rand(salt, index, 2) * TAU + _time * speed
		var flicker := 0.55 + 0.45 * sin(_time * lerpf(3.0, 7.0, _rand(salt, index, 3)) + float(index))
		_spark(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * band, extent * lerpf(0.045, 0.075, _rand(salt, index, 4)), colour, flicker * 0.9)
	for index in range(6):
		var cycle := _time / 1.4 + _rand(salt, index, 5)
		var phase := fposmod(cycle, 1.0)
		var angle := (_rand(salt, index, 6) + floorf(cycle) * 0.618) * TAU
		var drift := Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * (1.0 + phase * 0.9)
		_spark(center + drift, extent * 0.05 * (1.0 - phase * 0.5), colour, (1.0 - phase) * 0.8)

# Sparks are drawn in from around the arch and spiral into the vortex.
func _inward_spiral(canvas: Rect2, geometry: Dictionary, colour: Color, salt: float) -> void:
	var center := _point(canvas, geometry.center)
	var radius := _size(canvas, geometry.radius)
	var extent := canvas.size.x
	_halo(center, radius * 2.8, colour, 0.28 + 0.1 * sin(_time * 2.1 + salt * 5.0))
	for index in range(18):
		var life := lerpf(1.3, 2.1, _rand(salt, index, 0))
		var cycle := _time / life + _rand(salt, index, 1)
		var phase := fposmod(cycle, 1.0)
		var reach := pow(1.0 - phase, 1.4) * 1.7
		var angle := (_rand(salt, index, 2) + floorf(cycle) * 0.618) * TAU + phase * 3.6 * PI
		var spot := center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * reach
		_spark(spot, extent * lerpf(0.07, 0.03, phase), colour, sin(phase * PI) * 0.95)

# Light streaks fall down the beam, faster as they drop; the dais splash
# sends out rings and a spray of sparks.
func _falling_beam(canvas: Rect2, geometry: Dictionary, colour: Color, salt: float) -> void:
	var extent := canvas.size.x
	var beam_x := canvas.position.x + float(geometry.beam_x) * canvas.size.x
	var half_width := float(geometry.beam_half_width) * canvas.size.x
	var top := canvas.position.y + float(geometry.beam_top) * canvas.size.y
	var bottom := canvas.position.y + float(geometry.beam_bottom) * canvas.size.y
	var flicker := 0.16 + 0.06 * sin(_time * 9.0 + salt * 7.0) + 0.04 * sin(_time * 23.0)
	_halo(Vector2(beam_x, (top + bottom) * 0.5), Vector2(half_width * 5.0, (bottom - top) * 1.15), colour, flicker)
	for index in range(16):
		var life := lerpf(0.6, 1.1, _rand(salt, index, 0))
		var cycle := _time / life + _rand(salt, index, 1)
		var phase := fposmod(cycle, 1.0)
		var offset := (_rand(salt + floorf(cycle), index, 2) - 0.5) * 1.5 * half_width
		var streak := Vector2(extent * 0.03, extent * lerpf(0.09, 0.14, _rand(salt, index, 3)))
		_spark(Vector2(beam_x + offset, lerpf(top, bottom, phase * phase)), extent, colour, sin(phase * PI) * 0.85, streak)
	var splash := _point(canvas, geometry.splash_center)
	var splash_radius := _size(canvas, geometry.splash_radius)
	_halo(splash, splash_radius * 2.6, colour, 0.3 + 0.1 * sin(_time * 3.1 + salt * 4.0))
	for ring in range(2):
		var phase := fposmod(_time / 1.1 + float(ring) * 0.5 + salt, 1.0)
		for index in range(12):
			var angle := float(index) / 12.0 * TAU
			var spread := lerpf(0.25, 1.1, phase)
			_spark(splash + Vector2(cos(angle) * splash_radius.x, sin(angle) * splash_radius.y) * spread, extent * 0.04, colour, (1.0 - phase) * 0.6)
	for index in range(10):
		var life := lerpf(0.7, 1.2, _rand(salt, index, 7))
		var cycle := _time / life + _rand(salt, index, 8)
		var age := fposmod(cycle, 1.0) * life
		var sideways := (_rand(salt + floorf(cycle), index, 9) * 2.0 - 1.0) * splash_radius.x * 2.4
		var upward := -splash_radius.y * 4.0 * lerpf(0.6, 1.0, _rand(salt, index, 10))
		var fall := splash_radius.y * 11.0
		var spot := splash + Vector2(sideways * age, upward * age + 0.5 * fall * age * age)
		_spark(spot, extent * 0.045, colour, (1.0 - age / life) * 0.9)

# A soft pool of light in the network colour, without the white core.
func _halo(center: Vector2, diameter: Vector2, colour: Color, alpha: float) -> void:
	draw_texture_rect(_sparkle, Rect2(center - diameter * 0.5, diameter), false, Color(colour.r, colour.g, colour.b, clampf(alpha, 0.0, 1.0)))

func _spark(spot: Vector2, diameter: float, colour: Color, alpha: float, stretch: Vector2 = Vector2.ZERO) -> void:
	if alpha <= 0.01:
		return
	var box := stretch if stretch != Vector2.ZERO else Vector2.ONE * diameter
	var hot := colour.lerp(Color.WHITE, WHITE_CORE)
	draw_texture_rect(_sparkle, Rect2(spot - box * 0.5, box), false, Color(hot.r, hot.g, hot.b, clampf(alpha, 0.0, 1.0)))

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
