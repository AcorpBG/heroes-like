extends RefCounted
## Presentation only: painted silhouettes share a ground anchor, never a hitbox.
## Masks are derived from real sprite alpha once per view, not read back per frame.

const MODEL := "painted_bounds_grounded_actor_dual_alpha_edge"
const DIRECTIONS := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN,
	Vector2(-0.7071, -0.7071), Vector2(0.7071, -0.7071),
	Vector2(-0.7071, 0.7071), Vector2(0.7071, 0.7071)]
var _alpha_masks: Dictionary = {}

func clear() -> void:
	_alpha_masks.clear()

static func layout(region: Dictionary, ground: Vector2, visible_extent: float) -> Dictionary:
	var texture: Texture2D = region.get("draw_texture")
	var source_size := texture.get_size() if texture != null else Vector2.ONE
	var draw_size := source_size * (visible_extent / maxf(source_size.x, source_size.y))
	return {
		"draw_texture": texture,
		"draw_rect": Rect2(ground - Vector2(draw_size.x * 0.5, draw_size.y), draw_size),
		"source_aspect": source_size.x / maxf(source_size.y, 0.0001),
		"visible_extent_px": visible_extent,
		"ground_center": ground,
		"model": MODEL,
	}

static func edge_width(visible_extent: float) -> float:
	# Screen-sized, restrained at both strategic zoom and close map inspection.
	return clampf(visible_extent * 0.020, 1.15, 2.0)

func alpha_mask(texture: Texture2D) -> Texture2D:
	var key := texture.get_instance_id()
	if _alpha_masks.has(key):
		return _alpha_masks[key]
	var source := texture.get_image()
	if source == null or source.is_empty():
		push_error("Actor outline requires the original raster alpha.")
		return null
	if source.is_compressed() and source.decompress() != OK:
		push_error("Unable to read actor alpha.")
		return null
	source.clear_mipmaps()
	source.convert(Image.FORMAT_RGBA8)
	var pixels := source.get_data()
	for offset in range(0, pixels.size(), 4):
		pixels[offset] = 255
		pixels[offset + 1] = 255
		pixels[offset + 2] = 255
	var mask := ImageTexture.create_from_image(Image.create_from_data(
		source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8, pixels))
	_alpha_masks[key] = mask
	return mask
