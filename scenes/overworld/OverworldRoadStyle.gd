extends RefCounted
## Original dirt painting clipped to soft shoulders; road connectivity is external.
const TEXTURE_PATH := "res://art/overworld/runtime/terrain_tiles/base_generated_v2/dirt.png"
const WIDTH_FACTOR := 0.24

static func strips(path: PackedVector2Array, width: float, tile: Vector2i, rect: Rect2) -> Array:
	if path.size() < 2: return []
	# Legacy line connectors overlap beyond their cell. Alpha-blended raster
	# shoulders meet at the exact edge instead, avoiding a dark seam every tile.
	path = path.duplicate()
	for i in range(path.size()): path[i] = path[i].clamp(rect.position,rect.end)
	var normals := PackedVector2Array()
	var widths := PackedFloat32Array()
	for i in range(path.size()):
		var tangent := path[mini(i+1,path.size()-1)] - path[maxi(i-1,0)]
		normals.append(Vector2(-tangent.y, tangent.x).normalized())
		var world := Vector2(tile) + (path[i] - rect.position) / rect.size
		widths.append(width * (1.0 + 0.08 * sin(world.x * 6.1 + world.y * 4.7)))
	var bands := []
	# Alpha tapers out into the underlying biome; no dark outline or parallel rails.
	for span in [Vector4(-0.72,-0.37,0.0,0.92), Vector4(-0.37,0.37,0.92,0.92), Vector4(0.37,0.72,0.92,0.0)]:
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		for i in range(path.size()):
			points.append(path[i] + normals[i] * widths[i] * span.x)
			colors.append(Color(1.0,1.0,1.0,span.z))
		for i in range(path.size()-1,-1,-1):
			points.append(path[i] + normals[i] * widths[i] * span.y)
			colors.append(Color(1.0,1.0,1.0,span.w))
		bands.append({"points":points,"colors":colors,"uvs":uvs(points,tile,rect)})
	return bands

static func uvs(points: PackedVector2Array, tile: Vector2i, rect: Rect2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		var local := (point-rect.position)/rect.size
		var uv := (Vector2(posmod(tile.x,4),posmod(tile.y,4)) + local)/4.0
		# Alternate sampling direction at repeat boundaries so the original
		# painting's opposite edges never form a hard stripe across the road.
		if posmod(tile.x,8) >= 4: uv.x = 1.0-uv.x
		if posmod(tile.y,8) >= 4: uv.y = 1.0-uv.y
		result.append(uv)
	return result

static func cap(center: Vector2, width: float, tile: Vector2i, rect: Rect2) -> Array:
	var triangles := []
	for i in range(16):
		var a := TAU * float(i)/16.0
		var b := TAU * float(i+1)/16.0
		var points := PackedVector2Array([center, center+Vector2(cos(a),sin(a))*width*0.70, center+Vector2(cos(b),sin(b))*width*0.70])
		triangles.append({"points":points,"colors":PackedColorArray([Color(1,1,1,0.92),Color(1,1,1,0),Color(1,1,1,0)]),"uvs":uvs(points,tile,rect)})
	return triangles
