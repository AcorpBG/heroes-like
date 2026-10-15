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
var decals_configured := false
## Terrain id -> true when the ground is impassable land the shader walls off
## as a void. Set by the map view from the movement rules; unset, no void.
var is_void_terrain: Callable

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
	# Which ground spills over which at a border, by material slot.
	var priority := PackedFloat32Array()
	priority.resize(16)
	var priorities: Array = config.get("border_priority", [])
	for slot in range(mini(priorities.size(), 16)):
		priority[slot] = float(priorities[slot])
	shader_material.set_shader_parameter("border_priority", priority)
	material = shader_material
	map_signature = -1
	fog_signature = -1
	lookup_bytes = PackedByteArray()
	visible = false

## Ground detail decals (art/overworld/terrain_decals_v4.json): which decal
## set each material slot uses and how densely it is scattered. The shader
## places them; a ground without a set (water) stays clean.
func configure_decals(config: Dictionary, atlas: Texture2D) -> void:
	decals_configured = false
	if material == null or atlas == null or atlas.get_size() != Vector2(2048, 2048):
		if not config.is_empty():
			push_error("Terrain decal atlas or manifest is missing/invalid.")
		return
	var set_for_slot := PackedFloat32Array()
	set_for_slot.resize(16)
	set_for_slot.fill(-1.0)
	var density_for_set := PackedFloat32Array()
	density_for_set.resize(16)
	var sets: Array = config.get("sets", [])
	for set_index in range(mini(sets.size(), 16)):
		var entry: Dictionary = sets[set_index]
		density_for_set[set_index] = float(entry.get("density", 0.0))
		for slot in entry.get("material_slots", []):
			if int(slot) >= 0 and int(slot) < 16:
				set_for_slot[int(slot)] = float(set_index)
	var pixels := atlas.get_image()
	var texture: Texture2D = atlas
	if pixels != null and not pixels.has_mipmaps():
		if pixels.is_compressed(): pixels.decompress()
		if pixels.generate_mipmaps() == OK: texture = ImageTexture.create_from_image(pixels)
	material.set_shader_parameter("decals", texture)
	material.set_shader_parameter("decal_set_for_slot", set_for_slot)
	material.set_shader_parameter("decal_density_for_set", density_for_set)
	material.set_shader_parameter("decal_cell_tiles", float(config.get("cell_tiles", 0.6)))
	material.set_shader_parameter("decal_opacity", float(config.get("opacity", 0.92)))
	decals_configured = true
	material.set_shader_parameter("decals_enabled", true)

func sync_lookup(rows: Array, dimensions: Vector2i, terrain_signature: int, explored: Array, exploration_signature: int, road_tiles: Array = []) -> void:
	if not configured:
		return
	var byte_count := dimensions.x * dimensions.y * 4
	var map_changed := map_signature != terrain_signature or lookup_bytes.size() != byte_count
	var fog_changed := fog_signature != exploration_signature
	if not map_changed and not fog_changed:
		return
	var start := Time.get_ticks_usec()
	# One RGBA8 texel per tile: red is the material slot, green is exploration,
	# alpha is 0 on impassable land.
	# Fill a byte buffer and upload it once instead of per-pixel Color calls.
	if map_changed:
		missing_terrain_ids.clear()
		lookup_bytes.resize(byte_count)
		lookup_bytes.fill(0)
		var slot_by_cell: Dictionary = {}
		var void_by_cell: Dictionary = {}
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
					# Alpha 0 marks land no one can walk on (rock), so the shader
					# can draw it as a walled-off void.
					void_by_cell[cell] = is_void_terrain.is_valid() and bool(is_void_terrain.call(terrain_id))
				lookup_bytes[offset] = slot
				lookup_bytes[offset + 3] = 0 if void_by_cell[cell] else 255
				offset += 4
		# Blue marks road tiles, which keep their decals off.
		for road in road_tiles:
			var tile: Vector2i = road
			if tile.x >= 0 and tile.y >= 0 and tile.x < dimensions.x and tile.y < dimensions.y:
				lookup_bytes[(tile.y * dimensions.x + tile.x) * 4 + 2] = 255
		map_signature = terrain_signature
		map_uploads += 1
	# Green: 255 explored, 128 the fog edge (unexplored, touching explored land
	# in any of 8 directions: the soft fog edge may show its ground), 0 deeper.
	var width := dimensions.x
	var near_row := PackedByteArray()
	near_row.resize(width * dimensions.y)
	for y in range(dimensions.y):
		var explored_row = explored[y] if y < explored.size() and explored[y] is Array else []
		var explored_width: int = explored_row.size()
		var offset := y * width * 4 + 1
		for x in range(width):
			var seen := x < explored_width and bool(explored_row[x])
			lookup_bytes[offset] = 255 if seen else 0
			if seen:
				var i := y * width + x
				near_row[i] = 1
				if x > 0: near_row[i - 1] = 1
				if x + 1 < width: near_row[i + 1] = 1
			offset += 4
	for y in range(dimensions.y):
		for x in range(width):
			var i := y * width + x
			if lookup_bytes[i * 4 + 1] == 255:
				continue
			if near_row[i] == 1 or (y > 0 and near_row[i - width] == 1) or (y + 1 < dimensions.y and near_row[i + width] == 1):
				lookup_bytes[i * 4 + 1] = 128
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
	return {"configured": configured, "decals_configured": decals_configured, "visible": visible, "map_uploads": map_uploads,
		"fog_uploads": fog_uploads, "last_upload_usec": last_upload_usec,
		"missing_terrain_ids": missing_terrain_ids.duplicate(), "terrain_slots": slots.duplicate(),
		"world_origin": material.get_shader_parameter("world_origin"),
		"world_span": material.get_shader_parameter("world_span")}
