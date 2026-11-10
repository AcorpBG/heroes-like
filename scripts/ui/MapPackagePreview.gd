extends RefCounted
## What a built map looks like (docs/skirmish-setup-screen.md): one picture per
## level, a texel per tile in the minimap's colours with obstacles darkened and
## roads drawn, and where its towns stand. Read from the map package and kept
## for the session, as loading a large package takes a third of a second.

const Minimap := preload("res://scenes/overworld/OverworldMinimap.gd")

const FALLBACK_GROUND := Color("59634e")
const ROAD_COLOR := Color("c7ab76")
const OBSTACLE_SHADE := 0.30

static var _cache := {}
static var _service: Object = null

## The same file gives the same picture; a rebuilt one has another time or size.
static func cache_key(entry: Dictionary) -> String:
	var identity: Dictionary = entry.get("map_file_identity", {})
	return "%s|%s|%s" % [String(entry.get("map_path", "")), str(identity.get("size", 0)), str(identity.get("modified_time", 0))]

static func has_preview(entry: Dictionary) -> bool:
	return _cache.has(cache_key(entry))

## {levels: [Texture2D], towns: [{tile, level, slot, start}], size}; empty when
## the picture is not built yet.
static func cached(entry: Dictionary) -> Dictionary:
	return _cache.get(cache_key(entry), {})

static func build(entry: Dictionary) -> Dictionary:
	var key := cache_key(entry)
	if _cache.has(key):
		return _cache[key]
	var preview := {"levels": [], "towns": [], "size": Vector2i.ONE}
	_cache[key] = preview
	if _service == null and ClassDB.class_exists(&"MapPackageService"):
		_service = ClassDB.instantiate(&"MapPackageService")
	if _service == null:
		return preview
	var loaded: Dictionary = _service.load_map_package(String(entry.get("map_path", "")))
	var document = loaded.get("map_document")
	if document == null:
		return preview
	var width := int(document.get_width())
	var height := int(document.get_height())
	var level_count := maxi(int(document.get_level_count()), 1)
	if width <= 0 or height <= 0:
		return preview
	preview.size = Vector2i(width, height)
	var palette: Array[Color] = []
	for terrain_id in document.get_terrain_layers().get("terrain_id_by_code", []):
		palette.append(Minimap.TERRAIN_COLORS.get(String(terrain_id), FALLBACK_GROUND))
	var blocked: Array = []
	for level in range(level_count):
		var cells := PackedByteArray()
		cells.resize(width * height)
		blocked.append(cells)
	for object in document.get_objects():
		var kind := String(object.get("kind", ""))
		var level := int(object.get("level", 0))
		if level < 0 or level >= level_count:
			continue
		if kind == "town":
			preview.towns.append({
				"tile": Vector2i(int(object.get("x", 0)), int(object.get("y", 0))),
				"level": level,
				"slot": int(object.get("owner_slot", 0)),
				"start": bool(object.get("is_start_town", false)),
			})
		elif kind == "decorative_obstacle":
			for tile in object.get("body_tiles", []):
				var x := int(tile.get("x", -1))
				var y := int(tile.get("y", -1))
				if x >= 0 and y >= 0 and x < width and y < height:
					blocked[level][y * width + x] = 1
	for level in range(level_count):
		var terrain = document.get_tile_layer_u16("terrain", level)
		var roads = document.get_tile_layer_u16("road_type", level)
		var pixels := PackedByteArray()
		pixels.resize(width * height * 4)
		for index in range(mini(terrain.size(), width * height)):
			var code := int(terrain[index])
			var color: Color = palette[code] if code >= 0 and code < palette.size() else FALLBACK_GROUND
			if blocked[level][index] == 1:
				color = color.darkened(OBSTACLE_SHADE)
			elif index < roads.size() and int(roads[index]) != 0:
				color = ROAD_COLOR
			pixels[index * 4] = color.r8
			pixels[index * 4 + 1] = color.g8
			pixels[index * 4 + 2] = color.b8
			pixels[index * 4 + 3] = 255
		preview.levels.append(ImageTexture.create_from_image(Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, pixels)))
	return preview
