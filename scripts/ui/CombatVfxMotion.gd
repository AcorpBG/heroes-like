extends RefCounted
## Pure presentation geometry for original, manifest-backed combat rasters.
## No clocks, RNG, textures, gameplay state or persistent particles are owned here.

const MAX_LAYERS_PER_CUE := 6
const MAX_LAYERS_PER_FRAME := 64
const MAX_SLASH_EXTENT_RADIUS := 1.15
const SLASH_CONTACT_FRACTION := 0.86
const MODES := ["projectile", "spell_projectile", "slash", "impact", "ward", "spell_target"]

static func owns(spec: Dictionary, entry: Dictionary) -> bool:
	return String(spec.get("render_mode", "")) in MODES or String(entry.get("kind", "")) == "stack_fade"

static func layers(spec: Dictionary, entry: Dictionary, preferences: Dictionary) -> Array:
	if not owns(spec, entry): return []
	var p := clampf(float(entry.get("progress", 0.0)), 0.0, 1.0)
	if p <= 0.0 or p >= 1.0: return []
	var radius := maxf(1.0, float(entry.get("hex_radius", 1.0)))
	var lift := Vector2(0, -radius * 0.62)
	var start := Vector2(float(entry.get("start_x", 0.0)), float(entry.get("start_y", 0.0))) + lift
	var end := Vector2(float(entry.get("end_x", 0.0)), float(entry.get("end_y", 0.0))) + lift
	var center := Vector2(float(entry.get("center_x", 0.0)), float(entry.get("center_y", 0.0))) + lift
	var mode := String(spec.get("render_mode", ""))
	var base_size := radius * clampf(float(spec.get("scale", 1.0)), 0.5, 3.5)
	var angle := deg_to_rad(float(spec.get("base_rotation_degrees", 0.0)))
	var fade := sin(p * PI)
	var reduced := bool(preferences.get("reduced_motion", false))
	var quiet := reduced or bool(preferences.get("reduced_flashes", false))
	var opacity := (0.48 if quiet else 0.88) * pow(fade, 0.7)
	var result := []
	if mode == "slash":
		# Keep the painted contact cue near the defender, not across the
		# attacker's articulated body. Manifest scale must not bury the pose.
		center = start.lerp(end, SLASH_CONTACT_FRACTION)
		base_size = minf(base_size, radius * MAX_SLASH_EXTENT_RADIUS)
		opacity *= 0.62
	if reduced:
		# One stationary, gently fading symbol; no sweep, travel, growth or debris.
		_stamp(result, end if mode in ["projectile", "spell_projectile", "spell_target"] else center, base_size, angle, opacity, "reduced_static")
		return result
	var eased := 1.0 - pow(1.0 - p, 2.0)
	match mode:
		"projectile", "spell_projectile":
			var direction := end - start
			angle += direction.angle()
			# Draw the tail first, newest/head last. All copies follow the real path.
			for index in range(3, 0, -1):
				var tail_p := maxf(0.0, p - float(index) * 0.075)
				_stamp(result, start.lerp(end, tail_p), base_size * (1.0 - index * 0.16), angle, opacity * (0.34 - index * 0.065), "projectile_trail")
			_stamp(result, start.lerp(end, p), base_size * 1.15, angle, opacity, "projectile_head")
		"slash":
			angle += (end - start).angle()
			for index in range(2, 0, -1):
				var prior := maxf(0.0, p - index * 0.09)
				_stamp(result, center, base_size * 0.90, angle + lerpf(-0.80, 0.65, prior), opacity * (0.25 - index * 0.065), "slash_afterimage")
			_stamp(result, center, base_size * (0.80 + 0.20 * fade), angle + lerpf(-0.80, 0.65, p), opacity, "slash_sweep")
		"impact":
			_stamp(result, center, base_size * (0.55 + eased * 1.05), angle + p * 0.35, opacity, "impact_bloom")
			# Deterministic, localized painted debris; no particle system or RNG.
			for index in range(4):
				var spoke := float(index) * TAU / 4.0 + float(int(entry.get("serial", 0)) % 7) * 0.17
				var offset := Vector2.from_angle(spoke) * radius * eased * 0.95 + Vector2(0, radius * p * p * 0.30)
				_stamp(result, center + offset, base_size * (0.25 - 0.10 * p), spoke + p, opacity * 0.48, "impact_fragments")
		"spell_target":
			center = end
			_stamp(result, center, base_size * (1.0 + 0.65 * eased), angle - p * 0.30, opacity * 0.24, "spell_echo")
			_stamp(result, center, base_size * (0.65 + 0.65 * eased), angle + p * 0.22, opacity, "spell_bloom")
			for index in range(3):
				var spoke := float(index) * TAU / 3.0 + p * 0.8
				var offset := Vector2.from_angle(spoke) * radius * (0.5 + eased * 0.45)
				_stamp(result, center + offset, base_size * 0.22, spoke, opacity * 0.45, "spell_motes")
		"ward":
			_stamp(result, center, base_size * (0.9 + 0.30 * fade), angle + p * 0.65, opacity * 0.72, "ward_turn")
			_stamp(result, center, base_size * (1.25 + 0.20 * eased), angle - p * 0.45, opacity * 0.24, "ward_echo")
		_:
			_stamp(result, center + Vector2(0, -radius * eased * 0.50), base_size * (0.8 + eased * 0.65), angle, opacity * 0.70, "defeat_dissipation")
	return result

static func _stamp(result: Array, center: Vector2, extent: float, angle: float, opacity: float, role: String) -> void:
	if result.size() >= MAX_LAYERS_PER_CUE: return
	result.append({"center": center, "extent": extent, "rotation": angle, "alpha": clampf(opacity, 0.0, 0.88), "role": role})
