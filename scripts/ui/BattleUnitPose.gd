extends RefCounted
## Per-unit raster clip layout. Legacy sheets remain migration fallbacks only.

const REQUIRED_CLIPS := ["idle", "move", "attack", "defend", "death", "dead"]

static func clip_name(state: String) -> String:
	match state:
		"move_path_step", "retreat_withdraw_column": return "move"
		"melee_windup_release", "retaliation_release": return "attack"
		"ranged_aim_release": return "ranged"
		"defend_brace", "surrender_stand_down": return "defend"
		"death_rout_remove": return "death"
		"cast_support_anchor": return "cast"
		"hit_stagger": return "hit"
	return "idle"

static func has_authored_poses(animation: Dictionary) -> bool:
	return not String(animation.get("pose_sheet", "")).is_empty() and animation.get("pose_clips", {}) is Dictionary and not animation.get("pose_clips", {}).is_empty()

static func grounded_rect(ground: Vector2, height: float, region: Rect2) -> Rect2:
	# Preserve raster aspect for long weapons and prone bodies. Gameplay body
	# cells are independent of this presentation-only transparent canvas.
	var width := height * region.size.x / maxf(1.0, region.size.y)
	return Rect2(Vector2(ground.x - width * 0.5, ground.y - height), Vector2(width, height))

static func clip(animation: Dictionary, state: String, dead: bool = false) -> Dictionary:
	var clips: Dictionary = animation.get("pose_clips", {})
	var name := "dead" if dead else clip_name(state)
	# Dedicated ranged/cast/hit poses are preferred; explicit migration aliases
	# are part of authored metadata, never guessed from a unit's name or tier.
	var aliases: Dictionary = animation.get("pose_aliases", {})
	name = String(aliases.get(name, name))
	return clips.get(name, {})

static func region(animation: Dictionary, state: String, progress: float, elapsed_msec: int, reduced_motion: bool, dead: bool = false) -> Rect2:
	var spec := clip(animation, state, dead)
	if spec.is_empty(): return Rect2()
	var size: Dictionary = animation.get("pose_frame_size", {})
	var width := maxi(1, int(size.get("width", 256)))
	var height := maxi(1, int(size.get("height", 256)))
	var count := maxi(1, int(spec.get("frames", 1)))
	var frame := 0
	if not dead and not reduced_motion:
		if bool(spec.get("loop", false)):
			frame = int(elapsed_msec / maxi(1, int(spec.get("frame_msec", 150)))) % count
		else:
			frame = clampi(int(progress * count), 0, count - 1)
	elif reduced_motion:
		frame = clampi(int(spec.get("static_frame", 0)), 0, count - 1)
	var indices: Array = spec.get("indices", [])
	if not indices.is_empty():
		var columns := maxi(1, int(animation.get("pose_columns", 1)))
		var index := int(indices[clampi(frame, 0, indices.size() - 1)])
		return Rect2(Vector2((index % columns) * width, int(index / columns) * height), Vector2(width, height))
	return Rect2(Vector2((int(spec.get("column", 0)) + frame) * width, int(spec.get("row", 0)) * height), Vector2(width, height))
