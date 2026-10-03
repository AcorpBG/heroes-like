extends SceneTree

# Exact changed battle texture after Godot's transparent-edge normalization.
func _initialize() -> void:
	var path := "res://art/animation/runtime/fluid/unit_neutral_cliffhawk_wardens.png"
	var original := Image.new()
	var source_error := original.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	var texture := load(path) as Texture2D
	if source_error != OK or texture == null:
		push_error("Cliffhawk source/imported texture missing")
		quit(1)
		return
	var imported := texture.get_image()
	if imported.is_compressed() and imported.decompress() != OK:
		push_error("Cliffhawk imported texture cannot be decoded")
		quit(1)
		return
	original.convert(Image.FORMAT_RGBA8)
	imported.convert(Image.FORMAT_RGBA8)
	original.fix_alpha_edges()
	if original.get_size() != imported.get_size() or original.get_data() != imported.get_data():
		push_error("Cliffhawk actual import differs from published pixels")
		quit(1)
		return
	print("CLIFFHAWK_IMPORTED_ATLAS_OK exact normalized RGBA ", imported.get_size())
	quit(0)
