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

static func facing_flip(animation: Dictionary, side: String) -> bool:
	# Source-facing metadata preserves the artist's camera and equipment ownership.
	# Reflection is a render transform, never a newly synthesized animation pose.
	var source_left := has_authored_poses(animation) and String(animation.get("pose_source_facing", "right")) == "left"
	return (side == "enemy") != source_left

static func elapsed_msec(playback_record: Dictionary, now_msec: int) -> int:
	# Idle loops use wall time. Event loops start at their own first contact,
	# hold during queue delay and follow the same speed as the action's travel.
	# These records are presentation-only; never put clock values into saves.
	if playback_record.is_empty(): return maxi(0, now_msec)
	var duration := maxi(1, int(playback_record.get("max_duration_ms", 1)))
	var base_duration := maxi(1, int(playback_record.get("base_duration_ms", duration)))
	var elapsed := maxi(0, now_msec - int(playback_record.get("started_at_msec", now_msec)))
	return int(float(elapsed) * float(base_duration) / float(duration))

static func waiting_for_start(playback_record: Dictionary, now_msec: int) -> bool:
	# A queued reaction still owns its future playback/corpse lifetime, but it
	# must not replace the resting pose before its audio and action clock start.
	return not playback_record.is_empty() and now_msec < int(playback_record.get("started_at_msec", now_msec))

static func idle_elapsed_msec(animation: Dictionary, now_msec: int, instance_key: String) -> int:
	# Presentation-only phase: neighboring stacks must not breathe in unison.
	# Stable identity avoids a jump when selection changes or the board redraws.
	var spec := clip(animation, "idle_hold")
	var cycle := clip_duration_msec(spec)
	return maxi(0, now_msec) + posmod(hash(instance_key), cycle)

static func clip_duration_msec(spec: Dictionary) -> int:
	var durations: Array = spec.get("frame_durations_msec", [])
	if durations.size() == int(spec.get("frames", 1)):
		var total := 0
		for duration in durations: total += maxi(1, int(duration))
		return maxi(1, total)
	return maxi(1, int(spec.get("frames", 1)) * int(spec.get("frame_msec", 150)))

static func contact_msec(spec: Dictionary) -> int:
	var count := maxi(1, int(spec.get("frames", 1)))
	var contact := clampi(int(spec.get("contact_frame", count / 2)), 0, count - 1)
	var durations: Array = spec.get("frame_durations_msec", [])
	var result := 0
	for i in range(contact):
		result += maxi(1, int(durations[i] if durations.size() == count else spec.get("frame_msec", 150)))
	return result

static func timed_frame(spec: Dictionary, elapsed: int) -> int:
	var count := maxi(1, int(spec.get("frames", 1)))
	var time := posmod(elapsed, clip_duration_msec(spec)) if bool(spec.get("loop", false)) else maxi(0, elapsed)
	var durations: Array = spec.get("frame_durations_msec", [])
	for i in range(count):
		var duration := maxi(1, int(durations[i] if durations.size() == count else spec.get("frame_msec", 150)))
		if time < duration: return i
		time -= duration
	return count - 1

static func grounded_rect(ground: Vector2, height: float, region: Rect2, animation: Dictionary = {}, flipped: bool = false) -> Rect2:
	# Expanded transparent action envelopes retain the accepted creature scale.
	# The reference height describes its original canvas, not its painted bounds.
	var reference_height := maxf(1.0, float(animation.get("pose_reference_height", region.size.y)))
	var anchors: Dictionary = animation.get("pose_region_anchors", {})
	var region_key := "%d,%d" % [int(region.position.x), int(region.position.y)]
	if anchors.has(region_key):
		var authored: Array = anchors[region_key]
		var anchor := Vector2(float(authored[0]), float(authored[1]))
		if flipped: anchor.x = region.size.x - anchor.x
		var scale := height / reference_height
		return Rect2(ground - anchor * scale, region.size * scale)
	height *= region.size.y / reference_height
	# Preserve raster aspect for long weapons and prone bodies. Gameplay body
	# cells are independent of this presentation-only transparent canvas.
	var width := height * region.size.x / maxf(1.0, region.size.y)
	# The packer puts the anatomical ground anchor above the transparent bottom
	# margin. Anchor that authored line, not the canvas edge or alpha bounds:
	# raised feet, flying bodies and prone silhouettes must keep their motion.
	# Legacy layouts without this optional metadata retain their original rect.
	var margin := clampf(float(animation.get("pose_ground_margin", 0.0)), 0.0, maxf(0.0, region.size.y - 1.0))
	var ground_offset := height * margin / maxf(1.0, region.size.y)
	# Dense atlases may trim unused horizontal padding around a long lunge.
	# Reflect the anatomical anchor with the art, including persistent corpses.
	var anchor_x := float(animation.get("pose_anchor_x", region.size.x * 0.5))
	if flipped: anchor_x = region.size.x - anchor_x
	return Rect2(Vector2(ground.x - width * anchor_x / maxf(1.0, region.size.x), ground.y - height + ground_offset), Vector2(width, height))

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
		if bool(spec.get("authored_timing", false)):
			frame = timed_frame(spec, elapsed_msec)
		elif bool(spec.get("loop", false)):
			frame = int(elapsed_msec / maxi(1, int(spec.get("frame_msec", 150)))) % count
		else:
			frame = clampi(int(progress * count), 0, count - 1)
	elif reduced_motion:
		frame = clampi(int(spec.get("static_frame", 0)), 0, count - 1)
	var indices: Array = spec.get("indices", [])
	if not indices.is_empty():
		var columns := maxi(1, int(animation.get("pose_columns", 1)))
		var index := int(indices[clampi(frame, 0, indices.size() - 1)])
		var packed: Array = animation.get("pose_frame_rects", [])
		if not packed.is_empty():
			var rect: Array = packed[index]
			return Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
		return Rect2(Vector2((index % columns) * width, int(index / columns) * height), Vector2(width, height))
	return Rect2(Vector2((int(spec.get("column", 0)) + frame) * width, int(spec.get("row", 0)) * height), Vector2(width, height))
