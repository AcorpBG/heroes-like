extends RefCounted

# A local Vector2i is meaningful only together with a level. Keep world records
# global; callers select a level for terrain, occupancy and presentation queries.
# Missing level fields in authored content / legacy saves mean surface (zero).
static var _terrain_rows: Dictionary = {}

static func level_of(value: Variant) -> int:
	if value is Dictionary:
		# Hero.level is experience rank; its spatial level lives in position.
		if value.get("position") is Dictionary:
			return level_of(value["position"])
		if value.has("level"):
			return int(value["level"])
		for key in ["visit_tile", "primary_tile"]:
			if value.get(key) is Dictionary and value[key].has("level"):
				return int(value[key]["level"])
	if value is Vector3i:
		return value.z
	return 0

static func hero_level(session) -> int:
	return level_of(session.overworld.get("hero_position", {})) if session != null else 0

static func level_count(session) -> int:
	if session == null:
		return 1
	return maxi(1, int(session.overworld.get("map_size", {}).get("level_count", 1)))

static func view_level(session) -> int:
	if session == null:
		return 0
	return clampi(int(session.overworld.get("view_level", hero_level(session))), 0, level_count(session) - 1)

static func query_level(session, requested: int = -1) -> int:
	return hero_level(session) if requested < 0 else requested

static func same_level(a: Variant, b: Variant) -> bool:
	return level_of(a) == level_of(b)

static func on_level(value: Variant, level: int) -> bool:
	return level_of(value) == level

static func position(value: Variant) -> Dictionary:
	if value is Dictionary:
		var result := {"x": int(value.get("x", 0)), "y": int(value.get("y", 0))}
		if int(value.get("level", 0)) != 0:
			result["level"] = int(value["level"])
		return result
	if value is Vector3i:
		return position({"x": value.x, "y": value.y, "level": value.z})
	if value is Vector2i:
		return {"x": value.x, "y": value.y}
	return {"x": 0, "y": 0}

static func moved_position(previous: Variant, tile: Vector2i, level: int = -1) -> Dictionary:
	var result := position(previous)
	result["x"] = tile.x
	result["y"] = tile.y
	if level >= 0:
		if level == 0:
			result.erase("level")
		else:
			result["level"] = level
	return result

static func canonical_spatial_records(owned_records: Array) -> Array:
	# Only detached spatial records, never hero/commander progression records.
	# Surface keeps the legacy representation; nonzero layers remain explicit.
	for record in owned_records:
		if record is Dictionary and record.has("level") and int(record.level) == 0:
			record.erase("level")
	return owned_records

static func town_entrance(town: Dictionary) -> Dictionary:
	var tile: Dictionary = town.get("visit_tile", {}) if town.get("visit_tile") is Dictionary else {}
	if tile.is_empty():
		var visits: Array = town.get("package_visit_tiles", [])
		tile = visits[0] if not visits.is_empty() and visits[0] is Dictionary else town
	var result := position(tile)
	if not tile.has("level") and level_of(town) != 0:
		result["level"] = level_of(town)
	return result

static func terrain_rows(session, requested: int = -1) -> Array:
	if session == null:
		return []
	var level := query_level(session, requested)
	if level < 0 or level >= level_count(session):
		return []
	# The legacy map field remains the surface map. Never swap it when a hero or
	# camera changes level; immutable package layers remain the terrain authority.
	if level == 0:
		return session.overworld.get("map", [])
	var layers: Dictionary = session.overworld.get("terrain_layers", {})
	var levels: Array = layers.get("terrain", {}).get("levels", [])
	if level >= levels.size():
		return []
	var codes: Variant = levels[level]
	var ids: Variant = layers.get("terrain_id_by_code", [])
	if not (codes is Array or codes is PackedInt32Array) or not (ids is Array or ids is PackedStringArray):
		return []
	var size: Dictionary = session.overworld.get("map_size", {})
	var width := int(size.get("width", size.get("x", 0)))
	var height := int(size.get("height", size.get("y", 0)))
	if width <= 0 or height <= 0 or codes.size() != width * height:
		return []
	var key := "%s|%d" % [String(session.session_id), level]
	var cached: Dictionary = _terrain_rows.get(key, {})
	if is_same(cached.get("codes"), codes) and is_same(cached.get("ids"), ids) and cached.get("size") == Vector2i(width, height):
		return cached.rows
	var rows := []
	for y in range(height):
		var row := []
		for x in range(width):
			var code := int(codes[y * width + x])
			row.append(String(ids[code]) if code >= 0 and code < ids.size() else "rock")
		rows.append(row)
	if _terrain_rows.size() >= 16:
		_terrain_rows.clear()
	_terrain_rows[key] = {"codes": codes, "ids": ids, "size": Vector2i(width, height), "rows": rows}
	return rows

static func terrain_id_at(session, x: int, y: int, requested: int = -1) -> String:
	var rows := terrain_rows(session, requested)
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].size():
		return "rock"
	return String(rows[y][x])
