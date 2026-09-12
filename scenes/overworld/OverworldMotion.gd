extends RefCounted
## Presentation-only curves. Never write session state or consume gameplay RNG.

static func travel(progress: float) -> float:
	var t := clampf(progress, 0.0, 1.0)
	# Short acceleration/deceleration ramps, constant speed through the route.
	const RAMP := 0.16
	if t < RAMP:
		return t * t / (2.0 * RAMP * (1.0 - RAMP))
	if t > 1.0 - RAMP:
		return 1.0 - travel(1.0 - t)
	return (t - RAMP * 0.5) / (1.0 - RAMP)

static func emphasis(progress: float) -> float:
	var t := clampf(progress, 0.0, 1.0)
	return smoothstep(0.0, 0.16, t) * (1.0 - smoothstep(0.56, 1.0, t))

static func stride_offset(segment_progress: float, extent: float) -> Vector2:
	# Ground shadow stays fixed. Only the painting lifts, by at most 1.5 px.
	return Vector2(0.0, -sin(clampf(segment_progress, 0.0, 1.0) * PI) * minf(1.5, extent * 0.024))
