class_name UnitPortraitTexture
extends Texture2D
## UI-only composition. Both layers keep their shared imported textures;
## world creatures and battle standees continue to use the transparent art.

const BACKGROUND_TINT := Color(0.84, 0.84, 0.84, 1.0)
var foreground: Texture2D
var background: Texture2D
var round_background := false

static func for_unit(unit_id: String, surface: String = "battle_icon", round_backdrop: bool = false) -> Texture2D:
	var art := ContentService.get_unit_art(unit_id)
	var path := String(art.get(surface, ""))
	if path == "" or not ResourceLoader.exists(path, "Texture2D"):
		return null
	var figure := load(path) as Texture2D
	var backdrop_path := background_path(unit_id)
	if backdrop_path == "" or not ResourceLoader.exists(backdrop_path, "Texture2D"):
		return figure
	var layered := UnitPortraitTexture.new()
	layered.foreground = figure
	layered.background = load(backdrop_path) as Texture2D
	layered.round_background = round_backdrop
	return layered

static func background_path(unit_id: String) -> String:
	var art := ContentService.get_unit_art(unit_id)
	var backgrounds: Dictionary = ContentService.load_json(ContentService.UNIT_ART_PATH).get("ui_faction_backgrounds", {})
	return String(backgrounds.get(String(art.get("faction_id", "")), ""))

func _get_width() -> int:
	return foreground.get_width() if foreground != null else 1

func _get_height() -> int:
	return foreground.get_height() if foreground != null else 1

func _has_alpha() -> bool:
	return true

func _draw(canvas: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	_draw_rect(canvas, Rect2(pos, get_size()), false, modulate, transpose)

func _draw_rect(canvas: RID, rect: Rect2, _tile: bool, modulate: Color, transpose: bool) -> void:
	_draw_rect_region(canvas, rect, Rect2(Vector2.ZERO, get_size()), modulate, transpose, true)

func _draw_rect_region(canvas: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
	if foreground == null:
		return
	if background != null:
		# Cover the portrait's aspect ratio, then follow the same source crop as
		# the creature (TextureRect cover modes and region draws stay aligned).
		var scale := maxf(float(_get_width()) / background.get_width(), float(_get_height()) / background.get_height())
		var region_size := get_size() / scale
		var region := Rect2((background.get_size() - region_size) * 0.5, region_size)
		region.position += src_rect.position / get_size() * region_size
		region.size *= src_rect.size / get_size()
		if round_background:
			_draw_round_background(canvas, rect, region, modulate * BACKGROUND_TINT)
		else:
			background.draw_rect_region(canvas, rect, region, modulate * BACKGROUND_TINT, transpose, clip_uv)
	foreground.draw_rect_region(canvas, rect, src_rect, modulate, transpose, clip_uv)

func _draw_round_background(canvas: RID, rect: Rect2, region: Rect2, tint: Color) -> void:
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for index in range(48):
		var uv := Vector2(0.5, 0.5) + Vector2.from_angle(TAU * float(index) / 48.0) * 0.5
		points.append(rect.position + uv * rect.size)
		uvs.append((region.position + uv * region.size) / background.get_size())
	RenderingServer.canvas_item_add_polygon(canvas, points, PackedColorArray([tint]), uvs, background.get_rid())
