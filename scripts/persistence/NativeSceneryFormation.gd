extends RefCounted

# Presentation only: keep the native source record's connected blocked shape.
# Splitting draw calls by cell preserves fog, holes, viewport culling and overlap
# ownership while every slice samples the same full-size original formation.
static func groups(tiles: Array) -> Array:
	var remaining := {}
	for tile in tiles: remaining[tile] = true
	var result: Array = []
	while not remaining.is_empty():
		var ordered: Array = remaining.keys()
		ordered.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y or (a.y == b.y and a.x < b.x))
		var start: Vector2i = ordered[0]
		var members: Array = [start]
		remaining.erase(start)
		var lower := start
		var upper := start
		var index := 0
		while index < members.size():
			var tile: Vector2i = members[index]
			index += 1
			lower = Vector2i(mini(lower.x, tile.x), mini(lower.y, tile.y))
			upper = Vector2i(maxi(upper.x, tile.x), maxi(upper.y, tile.y))
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = tile + offset
				if remaining.has(neighbor):
					remaining.erase(neighbor)
					members.append(neighbor)
		var mass := interior_rect(members)
		result.append({"origin": lower, "size": upper - lower + Vector2i.ONE, "mass_origin": mass.position, "mass_size": mass.size, "tiles": members, "anchor": start})
	return result

static func interior_rect(tiles: Array) -> Rect2i:
	# Find the largest fully blocked rectangle for the dominant silhouette.
	# Fitting inside it avoids chopping artwork at an irregular mask edge.
	var occupied := {}
	for tile in tiles: occupied[tile] = true
	var best := Rect2i()
	for start in tiles:
		var width := 0
		while occupied.has(start + Vector2i(width, 0)): width += 1
		var height := 0
		while occupied.has(start + Vector2i(0, height)):
			var row_width := 0
			while row_width < width and occupied.has(start + Vector2i(row_width, height)): row_width += 1
			width = mini(width, row_width)
			height += 1
			if width * height > best.size.x * best.size.y:
				best = Rect2i(start, Vector2i(width, height))
	return best

static func slice(formation: Dictionary, tile: Vector2i, cell_rect: Rect2, image_size: Vector2) -> Dictionary:
	var origin: Vector2i = formation.get("mass_origin", formation.origin)
	var size: Vector2i = formation.get("mass_size", formation.size)
	var bounds := Rect2(cell_rect.position + Vector2(origin - tile) * cell_rect.size, Vector2(size) * cell_rect.size)
	# Aspect-preserved art spans its native body instead of resetting at each
	# cell. Bottom alignment leaves natural upper silhouette/negative space.
	var scale := minf(bounds.size.x / maxf(image_size.x, 1.0), bounds.size.y / maxf(image_size.y, 1.0))
	var painted_size := image_size * scale
	var painted := Rect2(Vector2(bounds.get_center().x - painted_size.x * 0.5, bounds.end.y - painted_size.y), painted_size)
	return clip(painted, cell_rect, image_size)

static func clip(painted: Rect2, cell_rect: Rect2, image_size: Vector2) -> Dictionary:
	var clipped := painted.intersection(cell_rect)
	if not clipped.has_area(): return {}
	var ratio := image_size / painted.size
	return {"rect": clipped, "source": Rect2((clipped.position - painted.position) * ratio, clipped.size * ratio), "painted_rect": painted}
