extends RefCounted
## Pure presentation geometry for original, manifest-backed combat rasters.
## No clocks, RNG, textures, gameplay state or persistent particles are owned here.

const MAX_LAYERS_PER_CUE := 6
const MAX_LAYERS_PER_FRAME := 64
const MAX_SLASH_EXTENT_RADIUS := 1.15
const SLASH_CONTACT_FRACTION := 0.86
const MODES := ["projectile", "spell_projectile", "slash", "impact", "ward", "spell_target"]
const SPELL_PROFILES := ["empower", "haste", "protection", "binding", "clamp", "fogbind", "boundary"]

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
	var spell_profile := String(spec.get("motion_profile", ""))
	if mode == "spell_target" and spell_profile in SPELL_PROFILES:
		return _spell_layers(spec, spell_profile, end, radius, base_size, angle, opacity, p)
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

static func _spell_layers(spec: Dictionary, profile: String, target: Vector2, radius: float, extent: float, angle: float, opacity: float, p: float) -> Array:
	# Authored family art keeps its silhouette. No recoloring, simulation RNG,
	# extra clocks, or miniature copies of the entire symbol orbiting the unit.
	var result := []
	var variant := clampi(int(spec.get("visual_variant", 0)), 0, 2)
	var strength := clampf(float(spec.get("visual_strength", 1.0)), 0.90, 1.10)
	var eased := 1.0 - pow(1.0 - p, 3.0)
	var settle := smoothstep(0.0, 0.58, p)
	var turn := -1.0 if variant == 1 else 1.0
	extent *= strength
	match profile:
		"empower":
			# Strength rises through the company instead of spinning like a ward.
			var lift := Vector2(0, radius * (0.30 - eased * 0.62))
			_stamp(result, target + lift + Vector2(0, radius * 0.20), extent * 0.91, angle, opacity * 0.16, "empower_wake")
			_stamp(result, target + lift, extent * (0.78 + eased * 0.30), angle, opacity * 0.83, "empower_rise")
		"haste":
			# A fast directional pass with trailing echoes, not caster-to-target
			# travel (many support spells correctly target the active stack).
			var direction := Vector2(1.0, -0.32 - float(variant) * 0.08)
			for index in range(2, 0, -1):
				var behind := maxf(0.0, p - float(index) * 0.12)
				_stamp(result, target + direction * radius * (behind - 0.5) * 1.35, extent * (0.95 - index * 0.05), angle, opacity * (0.22 - index * 0.055), "haste_trail")
			_stamp(result, target + direction * radius * (p - 0.5) * 1.35, extent, angle, opacity * 0.83, "haste_sweep")
		"protection":
			# An assembling shell settles and holds; its hollow center stays clear.
			_stamp(result, target, extent * (1.22 - settle * 0.18), angle, opacity * 0.17 * (1.0 - settle), "protection_assembly")
			_stamp(result, target, extent * (1.13 - settle * 0.13), angle, opacity * 0.78, "protection_hold")
		"binding":
			# Roots/reeds grow from below and tighten around the real target.
			var grow := target + Vector2(0, radius * 0.52 * (1.0 - eased))
			_stamp(result, grow, extent * (1.32 - settle * 0.30), angle + turn * (1.0 - settle) * 0.13, opacity * 0.84, "binding_close")
		"clamp":
			# A short decisive compression followed by a stable locked pose.
			var close := smoothstep(0.06, 0.38, p)
			_stamp(result, target, extent * (1.36 - close * 0.38), angle, opacity * 0.84, "clamp_lock")
		"fogbind":
			# Narrow opposing mist folds curl inward, never a full-screen haze.
			var curl := (1.0 - settle) * radius * 0.25
			_stamp(result, target + Vector2(curl, 0), extent * 1.04, angle - turn * p * 0.22, opacity * 0.18, "fogbind_echo")
			_stamp(result, target - Vector2(curl, 0), extent * (1.20 - settle * 0.20), angle + turn * (1.0 - settle) * 0.28, opacity * 0.73, "fogbind_coil")
		"boundary":
			# Survey constraints stamp down and close; no unrelated generic halo.
			var descend := target + Vector2(0, -radius * 0.38 * (1.0 - settle))
			_stamp(result, descend, extent * (1.23 - settle * 0.23), angle + turn * (1.0 - settle) * 0.18, opacity * 0.82, "boundary_seal")
	return result

static func _stamp(result: Array, center: Vector2, extent: float, angle: float, opacity: float, role: String) -> void:
	if result.size() >= MAX_LAYERS_PER_CUE or opacity <= 0.0: return
	result.append({"center": center, "extent": extent, "rotation": angle, "alpha": clampf(opacity, 0.0, 0.88), "role": role})
