extends RefCounted
## Layered approved paintings, animated on the GPU with no per-frame map rebuild.
const MineShader = preload("res://scenes/overworld/OverworldMine.gdshader")
# Keep the roof silhouette close to two tile rows without flattening the art.
# The ground anchor and gameplay footprint stay fixed; every FX layer follows.
const BUILDING_SCALE := 0.75
var manifest: Dictionary = {}
var _textures: Dictionary = {}

func configure(data: Dictionary) -> void:
	manifest = data if data.get("schema_id", "") == "unified_common_mines_v1" else {}
	_textures.clear()

func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		var loaded = load(path) if ResourceLoader.exists(path) else null
		if not loaded is Texture2D:
			var image := Image.load_from_file(path)
			if image == null or image.is_empty(): return null
			loaded = ImageTexture.create_from_image(image)
		_textures[path] = loaded
	return _textures[path]

func payload(resource: String, footprint: Rect2) -> Dictionary:
	var entry: Dictionary = manifest.get("mines", {}).get(resource, {})
	if entry.is_empty(): return {}
	var canvas := Vector2(manifest.canvas_size[0], manifest.canvas_size[1])
	var ground := Vector2(footprint.get_center().x, footprint.end.y - footprint.size.y * .06)
	var scale := footprint.size.x * .95 * BUILDING_SCALE / float(manifest.painted_width)
	var anchor := Vector2(manifest.ground_anchor[0], manifest.ground_anchor[1])
	return {"resource": resource, "entry": entry, "texture": texture(entry.base),
		"parts_texture": texture(entry.parts_texture), "canvas": canvas,
		"rect": Rect2(ground - anchor * scale, canvas * scale), "ground": ground}

static func material(pose: Dictionary, phase_key: String, enabled: bool) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = MineShader
	var entry: Dictionary = pose.entry
	var canvas: Vector2 = pose.canvas
	result.set_shader_parameter("parts_texture", pose.parts_texture)
	result.set_shader_parameter("motion_enabled", enabled)
	result.set_shader_parameter("phase", float(posmod(hash(phase_key), 10007)) / 10007.0 * 13.0)
	result.set_shader_parameter("chimney", Vector2(entry.chimney[0], entry.chimney[1]) / canvas)
	result.set_shader_parameter("part_count", entry.parts.size())
	for i in range(entry.parts.size()):
		var part: Dictionary = entry.parts[i]
		var r: Array = part.rect
		var s: Array = part.source
		var prefix := "part_%d_" % i
		result.set_shader_parameter(prefix + "rect", Vector4(r[0] / canvas.x, r[1] / canvas.y, r[2] / canvas.x, r[3] / canvas.y))
		result.set_shader_parameter(prefix + "source", Vector4(s[0] / 384.0, s[1] / 128.0, s[2] / 384.0, s[3] / 128.0))
		result.set_shader_parameter(prefix + "motion", Vector4(part.mode, part.speed, part.travel[0] / canvas.x, part.travel[1] / canvas.y))
		result.set_shader_parameter(prefix + "rope", Vector2(part.rope[0], part.rope[1]) / canvas)
	result.set_shader_parameter("light_count", entry.lights.size())
	for i in range(entry.lights.size()):
		result.set_shader_parameter("light_%d" % i, Vector2(entry.lights[i][0], entry.lights[i][1]) / canvas)
	return result
