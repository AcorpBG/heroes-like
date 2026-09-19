extends RefCounted
## Original pose playback only. Clocks and ground anchors never enter game state.

const IdleShader = preload("res://scenes/overworld/OverworldCreatureIdle.gdshader")
var units: Dictionary = {}
var _textures: Dictionary = {}

func configure(manifest: Dictionary) -> void:
	units = manifest.get("units", {}) if manifest.get("schema_id", "") == "overworld_creature_idle_v1" else {}
	_textures.clear()

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
	result.set_shader_parameter("frame_seconds", float(entry.frame_msec) / 1000.0)
	result.set_shader_parameter("static_frame", float(entry.static_frame))
	result.set_shader_parameter("motion_enabled", enabled)
	# Stable placement offsets survive pan/redraw and do not consume simulation RNG.
	result.set_shader_parameter("phase", float(posmod(hash(phase_key), 10007)) / 10007.0 * float(entry.frames * entry.frame_msec) / 1000.0)
	var rect: Rect2 = pose.rect
	var edge := clampf(maxf(rect.size.x, rect.size.y) * 0.020, 1.15, 2.0)
	result.set_shader_parameter("edge_uv", Vector2(edge, edge) / rect.size)
	return result
