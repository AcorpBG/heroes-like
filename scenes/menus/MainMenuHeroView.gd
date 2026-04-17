extends TextureRect

const DEFAULT_BACKDROP_PATH := "res://art/ui/main_menu_nano_banana_backdrop.png"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if texture == null:
		_load_backdrop()

func _load_backdrop() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(DEFAULT_BACKDROP_PATH))
	if image == null or image.is_empty():
		return
	texture = ImageTexture.create_from_image(image)
