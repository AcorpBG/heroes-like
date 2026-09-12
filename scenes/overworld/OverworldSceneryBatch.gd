extends RefCounted
## Cached painter-order command batches. Only state changes rebuild these;
## shader TIME animates the original raster without a script/map scan per frame.

const SceneryShader = preload("res://scenes/overworld/OverworldScenery.gdshader")

class PaintBatch extends Node2D:
	var commands: Array = []
	func _draw() -> void:
		for command in commands:
			callv(command[0], command[1])

var batches: Array[PaintBatch] = []
var entries: Array[Dictionary] = []
var _host: Control
var _cursor := 0
var _current: PaintBatch
var recording := false
var generation := 0

func begin(host: Control) -> void:
	_host = host
	_cursor = 0
	_current = null
	entries.clear()
	recording = true
	generation += 1

func _next() -> PaintBatch:
	var batch: PaintBatch
	if _cursor < batches.size():
		batch = batches[_cursor]
	else:
		batch = PaintBatch.new()
		batch.name = "SceneryPaint%d" % _cursor
		_host.add_child(batch)
		batches.append(batch)
	batch.commands.clear()
	batch.material = null
	batch.visible = true
	batch.queue_redraw()
	_cursor += 1
	return batch

func record(method: StringName, arguments: Array) -> void:
	if _current == null:
		_current = _next()
	_current.commands.append([method, arguments])

func paint(texture: Texture2D, rect: Rect2, tint: Color, profile: Dictionary, source_region: Rect2, asset_id: String, tile: Vector2i, level: int, enabled: bool) -> void:
	var batch := _next()
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SceneryShader
	# AtlasTexture draw commands carry atlas UVs, not cell-local UVs. Keep
	# distortion/sampling inside the exact original cell without copying art.
	if texture is AtlasTexture:
		var atlas_size: Vector2 = texture.atlas.get_size()
		var atlas_region: Rect2 = texture.region
		shader_material.set_shader_parameter("texture_region", Vector4(atlas_region.position.x / atlas_size.x, atlas_region.position.y / atlas_size.y, atlas_region.size.x / atlas_size.x, atlas_region.size.y / atlas_size.y))
	shader_material.set_shader_parameter("motion_enabled", enabled)
	shader_material.set_shader_parameter("mode", int(profile.get("mode", 0)))
	shader_material.set_shader_parameter("strength", float(profile.get("strength", 0.0)))
	shader_material.set_shader_parameter("upper", float(profile.get("upper", 0.0)))
	shader_material.set_shader_parameter("anchor", float(profile.get("anchor", 1.0)))
	var area: Array = profile.get("region", [0.0, 0.0, 1.0, 1.0])
	shader_material.set_shader_parameter("activity_region", Vector4(area[0], area[1], area[2], area[3]))
	shader_material.set_shader_parameter("source_region", Vector4(source_region.position.x, source_region.position.y, source_region.size.x, source_region.size.y))
	# Transparent margin lets canopy tips move without clipping the tight crop.
	var padding := Vector2(2.0, 2.0) / rect.size
	shader_material.set_shader_parameter("padding_uv", padding)
	shader_material.set_shader_parameter("phase", float(posmod(hash("%s:%d:%d:%d" % [asset_id, tile.x, tile.y, level]), 10007)) / 10007.0 * TAU)
	batch.material = shader_material
	batch.commands.append([&"draw_texture_rect", [texture, rect.grow(2.0), false, tint]])
	entries.append({"asset_id": asset_id, "tile": tile, "level": level, "rect": rect, "profile": profile, "batch": batch})
	_current = null # Following fog, outlines and props stay ABOVE this sprite.

func finish() -> void:
	recording = false
	for index in range(_cursor, batches.size()):
		batches[index].commands.clear()
		batches[index].material = null
		batches[index].visible = false
		batches[index].queue_redraw()
	_current = null

func set_motion_enabled(enabled: bool) -> void:
	for entry in entries:
		entry.batch.material.set_shader_parameter("motion_enabled", enabled)
