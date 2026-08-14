extends Control

const STATUS_BACKDROP_PATHS := {
	"victory": "res://art/results/runtime/backdrops/outcome_victory.png",
	"defeat": "res://art/results/runtime/backdrops/outcome_defeat.png",
}
const STATUS_BACKDROPS := {
	"victory": preload("res://art/results/runtime/backdrops/outcome_victory.png"),
	"defeat": preload("res://art/results/runtime/backdrops/outcome_defeat.png"),
}
const DEFAULT_FALLBACK_COLOR := Color(0.07, 0.08, 0.10, 1.0)
const SCENIC_VEIL_COLOR := Color(0.018, 0.024, 0.032, 0.24)

var _status := "victory"
var _fallback_color := DEFAULT_FALLBACK_COLOR


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func set_outcome(status: String) -> void:
	_status = status.strip_edges().to_lower()
	queue_redraw()


func set_fallback_color(color: Color) -> void:
	_fallback_color = color
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var destination_rect := Rect2(Vector2.ZERO, size)
	draw_rect(destination_rect, _fallback_color, true)
	var texture := _status_texture()
	if texture == null:
		return
	draw_texture_rect_region(texture, destination_rect, _cover_crop_source_rect(texture, size))
	draw_rect(destination_rect, SCENIC_VEIL_COLOR, true)


func validation_summary() -> Dictionary:
	var texture := _status_texture()
	var texture_size := Vector2.ZERO
	var source_rect := Rect2()
	if texture != null:
		texture_size = Vector2(texture.get_width(), texture.get_height())
		source_rect = _cover_crop_source_rect(texture, size)
	var destination_rect := Rect2(Vector2.ZERO, size)
	return {
		"status": _status,
		"expected_path": String(STATUS_BACKDROP_PATHS.get(_status, "")),
		"texture_path": String(texture.resource_path) if texture != null else "",
		"texture_loaded": texture != null,
		"texture_size": texture_size,
		"destination_rect": destination_rect,
		"source_rect": source_rect,
		"rendering_mode": "cover_crop_scenic_epilogue" if texture != null else "flat_palette_fallback",
		"cover_crop": texture != null,
		"stretched": false,
		"fallback": texture == null,
		"mouse_filter_ignore": mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"veil_color": SCENIC_VEIL_COLOR,
		"source_contained": _rect_contained(source_rect, Rect2(Vector2.ZERO, texture_size)) if texture != null else true,
		"destination_contained": _rect_contained(destination_rect, Rect2(Vector2.ZERO, size)),
	}


func _status_texture() -> Texture2D:
	return STATUS_BACKDROPS.get(_status, null) as Texture2D


func _cover_crop_source_rect(texture: Texture2D, destination_size: Vector2) -> Rect2:
	var texture_size := Vector2(texture.get_width(), texture.get_height())
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or destination_size.x <= 0.0 or destination_size.y <= 0.0:
		return Rect2(Vector2.ZERO, texture_size)
	var cover_scale := maxf(destination_size.x / texture_size.x, destination_size.y / texture_size.y)
	var visible_size := destination_size / cover_scale
	return Rect2((texture_size - visible_size) * 0.5, visible_size)


func _rect_contained(inner: Rect2, outer: Rect2) -> bool:
	return (
		inner.position.x >= outer.position.x - 0.01
		and inner.position.y >= outer.position.y - 0.01
		and inner.end.x <= outer.end.x + 0.01
		and inner.end.y <= outer.end.y + 0.01
	)
