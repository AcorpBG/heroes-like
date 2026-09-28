extends TextureRect
## Presentation-only world-space raster splatting. The lookup is data, not art.
const GROUND_SHADER = preload("res://scenes/overworld/overworld_ground_surface.gdshader")
var slots: Dictionary = {}
var data_image: Image
var lookup_bytes := PackedByteArray()
var data_texture: ImageTexture
var map_signature: int = -1
var fog_signature: int = -1
var map_uploads := 0
var fog_uploads := 0
var last_upload_usec := 0
var missing_terrain_ids: Array[String] = []
var configured := false

func configure(config: Dictionary, atlas: Texture2D) -> void:
	texture = atlas
	# Clean imports and lossless packages need not contain mip levels. Build
	# them once from the original raster, owned by this view (no static GPU
	# lifetime), so source and both platform packages sample identically.
	if atlas != null:
		var pixels := atlas.get_image()
		if pixels != null and not pixels.has_mipmaps():
			if pixels.is_compressed(): pixels.decompress()
			if pixels.generate_mipmaps() == OK: texture = ImageTexture.create_from_image(pixels)
	slots = config.get("terrain_slots", {}).duplicate()
	configured = atlas != null and atlas.get_size() == Vector2(2048, 2048) and not slots.is_empty()
	for slot in slots.values():
		configured = configured and float(slot) == floorf(float(slot)) and int(slot) >= 0 and int(slot) < 16
	if not configured:
		push_error("Original ground-material atlas or manifest is missing/invalid.")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shader_material := ShaderMaterial.new()
	shader_material.shader = GROUND_SHADER
	shader_material.set_shader_parameter("materials", texture)
	shader_material.set_shader_parameter("material_span_tiles", float(config.get("material_span_tiles", 4.0)))
	shader_material.set_shader_parameter("beach_slot", float(slots.get("sand", 5)))
	shader_material.set_shader_parameter("water_slots", Vector3(float(slots.get("water", 12)), float(slots.get("coast", 13)), float(slots.get("shore", 14))))
	material = shader_material
	map_signature = -1
	fog_signature = -1
	lookup_bytes = PackedByteArray()
	visible = false

func sync_lookup(rows: Array, dimensions: Vector2i, terrain_signature: int, explored: Array, exploration_signature: int) -> void:
	if not configured:
		return
	var byte_count := dimensions.x * dimensions.y * 4
	var map_changed := map_signature != terrain_signature or lookup_bytes.size() != byte_count
	var fog_changed := fog_signature != exploration_signature
	if not map_changed and not fog_changed:
		return
	var start := Time.get_ticks_usec()
	# One RGBA8 texel per tile: red is the material slot, green is explored.
	# Fill a byte buffer and upload it once instead of per-pixel Color calls.
	if map_changed:
		missing_terrain_ids.clear()
		lookup_bytes.resize(byte_count)
		lookup_bytes.fill(0)
		var slot_by_cell: Dictionary = {}
		var offset := 0
		for y in range(dimensions.y):
			var row = rows[y]
			for x in range(dimensions.x):
				var cell = row[x]
				var slot = slot_by_cell.get(cell)
				if slot == null:
					var terrain_id := str(cell).to_lower()
					if not slots.has(terrain_id):
						if terrain_id not in missing_terrain_ids:
							missing_terrain_ids.append(terrain_id)
							push_error("Unmapped ground material: " + terrain_id)
					slot = int(slots.get(terrain_id, 255))
					slot_by_cell[cell] = slot
				lookup_bytes[offset] = slot
				lookup_bytes[offset + 3] = 255
				offset += 4
		map_signature = terrain_signature
		map_uploads += 1
	for y in range(dimensions.y):
		var explored_row = explored[y] if y < explored.size() and explored[y] is Array else []
		var explored_width: int = explored_row.size()
		var offset := y * dimensions.x * 4 + 1
		for x in range(dimensions.x):
			lookup_bytes[offset] = 255 if x < explored_width and bool(explored_row[x]) else 0
			offset += 4
	data_image = Image.create_from_data(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8, lookup_bytes)
	if data_texture == null or data_texture.get_size() != Vector2(dimensions):
		data_texture = ImageTexture.create_from_image(data_image)
	else:
		data_texture.update(data_image)
	material.set_shader_parameter("terrain_data", data_texture)
	material.set_shader_parameter("map_size", Vector2(dimensions))
	fog_signature = exploration_signature
	fog_uploads += 1
	last_upload_usec = Time.get_ticks_usec() - start

func sync_layout(board: Rect2, viewport: Rect2, dimensions: Vector2i) -> void:
	var clipped := board.intersection(viewport)
	visible = configured and data_texture != null and missing_terrain_ids.is_empty() and clipped.has_area()
	if not visible:
		return
	position = clipped.position
	size = clipped.size
	var tile_size := board.size / Vector2(dimensions)
	material.set_shader_parameter("world_origin", (clipped.position - board.position) / tile_size)
	material.set_shader_parameter("world_span", clipped.size / tile_size)

func validation_snapshot() -> Dictionary:
	return {"configured": configured, "visible": visible, "map_uploads": map_uploads,
		"fog_uploads": fog_uploads, "last_upload_usec": last_upload_usec,
		"missing_terrain_ids": missing_terrain_ids.duplicate(), "terrain_slots": slots.duplicate(),
		"world_origin": material.get_shader_parameter("world_origin"),
		"world_span": material.get_shader_parameter("world_span")}
