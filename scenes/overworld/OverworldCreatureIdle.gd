extends RefCounted
## Original pose playback, with the RIFE in-betweens of docs/idle-inbetweens.md where a
## unit has them. Clocks and ground anchors never enter game state.

const IdleShader = preload("res://scenes/overworld/OverworldCreatureIdle.gdshader")
var units: Dictionary = {}
var _textures: Dictionary = {}
var _still_frames: Dictionary = {}

func configure(manifest: Dictionary) -> void:
	units = manifest.get("units", {}) if manifest.get("schema_id", "") == "overworld_creature_idle_v1" else {}
	_textures.clear()
	_still_frames.clear()

## The strip's resting frame as its own texture, for drawing without the shader.
func still_frame(unit_id: String) -> Texture2D:
	if _still_frames.has(unit_id):
		return _still_frames[unit_id]
	var entry: Dictionary = units.get(unit_id, {})
	var strip = load(String(entry.get("path", ""))) if not entry.is_empty() else null
	if not strip is Texture2D:
		return null
	var image: Image = strip.get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		image.decompress()
	var frame_size := Vector2i(int(entry.frame_size[0]), int(entry.frame_size[1]))
	var columns := maxi(1, int(entry.get("columns", entry.frames)))
	var cell := Vector2i(int(entry.static_frame) % columns, int(entry.static_frame) / columns)
	var frame := ImageTexture.create_from_image(image.get_region(Rect2i(cell * frame_size, frame_size)))
	_still_frames[unit_id] = frame
	return frame

func payload(unit_id: String, ground: Vector2, extent: float) -> Dictionary:
	var entry: Dictionary = units.get(unit_id, {})
	if entry.is_empty(): return {}
	if not _textures.has(unit_id):
		var texture = load(String(entry.path))
		if not texture is Texture2D: return {}
		_textures[unit_id] = texture
	var frame_size := Vector2(entry.frame_size[0], entry.frame_size[1])
	var anchor := Vector2(entry.ground_anchor[0], entry.ground_anchor[1])
	var scale := extent / maxf(1.0, float(entry.painted_extent))
	return {"unit_id": unit_id, "texture": _textures[unit_id], "entry": entry,
		"rect": Rect2(ground - anchor * scale, frame_size * scale), "ground": ground}

static func material(pose: Dictionary, phase_key: String, enabled: bool) -> ShaderMaterial:
	var entry: Dictionary = pose.entry
	var result := ShaderMaterial.new()
	result.shader = IdleShader
	result.set_shader_parameter("frame_count", float(entry.frames))
	result.set_shader_parameter("frame_columns", float(entry.get("columns", entry.frames)))
	result.set_shader_parameter("frame_seconds", float(entry.frame_msec) / 1000.0)
	result.set_shader_parameter("static_frame", float(entry.static_frame))
	result.set_shader_parameter("motion_enabled", enabled)
	# Stable placement offsets survive pan/redraw and do not consume simulation RNG.
	result.set_shader_parameter("phase", float(posmod(hash(phase_key), 10007)) / 10007.0 * float(entry.frames * entry.frame_msec) / 1000.0)
	var rect: Rect2 = pose.rect
	var edge := clampf(maxf(rect.size.x, rect.size.y) * 0.020, 1.15, 2.0)
	result.set_shader_parameter("edge_uv", Vector2(edge, edge) / rect.size)
	return result
