extends TextureRect

const DEFAULT_BACKDROP_PATH := "res://art/ui/main_menu_nano_banana_backdrop.png"
const TOP_WASH := Color(0.95, 0.76, 0.43, 0.10)
const LOWER_SHADE := Color(0.03, 0.04, 0.06, 0.26)
const EDGE_SHADE := Color(0.02, 0.03, 0.05, 0.18)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if texture == null:
		_load_backdrop()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	draw_rect(Rect2(0.0, 0.0, size.x, size.y * 0.34), TOP_WASH)
	draw_rect(Rect2(0.0, size.y * 0.58, size.x, size.y * 0.42), LOWER_SHADE)
	draw_rect(Rect2(0.0, 0.0, size.x * 0.08, size.y), EDGE_SHADE)

func _load_backdrop() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(DEFAULT_BACKDROP_PATH))
	if image == null or image.is_empty():
		return
	texture = ImageTexture.create_from_image(image)
