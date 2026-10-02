extends SceneTree

# Packing changes frame locations. Check imported pixels, not just PNG metadata.
func _initialize() -> void:
	var path := "res://art/animation/runtime/fluid/unit_neutral_quenchbell_ironbacks.png"
	var original := Image.new()
	var source_error := original.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	var texture := load(path) as Texture2D
	if source_error != OK or texture == null:
		push_error("Quenchbell Ironback atlas source or imported texture missing")
		quit(1)
		return
	var imported := texture.get_image()
	if imported.is_compressed():
		if imported.decompress() != OK:
			push_error("Quenchbell Ironback imported texture cannot be decoded")
			quit(1)
			return
	original.convert(Image.FORMAT_RGBA8)
	imported.convert(Image.FORMAT_RGBA8)
	# This atlas uses Godot's lossless import with fix_alpha_border=true.
	# Reproduce that documented transparent-border processing before comparison.
	original.fix_alpha_edges()
	if original.get_size() != imported.get_size() or original.get_data() != imported.get_data():
		push_error("Quenchbell Ironback Godot import cache differs from published atlas; refresh imports")
		quit(1)
		return
	print("QUENCHBELL_IRONBACK_IMPORTED_ATLAS_OK ", imported.get_size(), " exact RGBA pixels")
	quit(0)
