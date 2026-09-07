extends Button
## Pointer ownership follows painted pixels; keyboard focus retains the full bounds.

var painted_mask: BitMap
var texture_region_ratio := Rect2(Vector2.ZERO, Vector2.ONE)

func _has_point(point: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	if painted_mask == null:
		return true
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	var uv := texture_region_ratio.position + point / size * texture_region_ratio.size
	var mask_size := painted_mask.get_size()
	var pixel := Vector2i(floori(uv.x * mask_size.x), floori(uv.y * mask_size.y))
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= mask_size.x or pixel.y >= mask_size.y:
		return false
	return painted_mask.get_bitv(pixel)
