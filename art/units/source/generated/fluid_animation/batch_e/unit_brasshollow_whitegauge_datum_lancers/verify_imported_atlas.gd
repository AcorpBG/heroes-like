extends SceneTree

# Compare actual lossless texture import, including Godot transparent-edge processing.
func _initialize() -> void:
	var paths := [
		"res://art/animation/runtime/fluid/unit_brasshollow_whitegauge_datum_lancers.png",
		"res://art/overworld/runtime/creature_idle/unit_brasshollow_whitegauge_datum_lancers.png",
	]
	for path in paths:
		var original := Image.new()
		var source_error := original.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
		var texture := load(path) as Texture2D
		if source_error != OK or texture == null:
			push_error("Datum Lancer source/imported texture missing: " + path)
			quit(1)
			return
		var imported := texture.get_image()
		if imported.is_compressed() and imported.decompress() != OK:
			push_error("Datum Lancer imported texture cannot be decoded: " + path)
			quit(1)
			return
		original.convert(Image.FORMAT_RGBA8)
		imported.convert(Image.FORMAT_RGBA8)
		# Both source .import files use lossless import and fix_alpha_border=true.
		original.fix_alpha_edges()
		if original.get_size() != imported.get_size() or original.get_data() != imported.get_data():
			push_error("Datum Lancer actual import differs from published pixels: " + path)
			quit(1)
			return
		print("DATUM_LANCER_TEXTURE_IMPORTED_RGBA_OK ", path, " ", imported.get_size())
	print("DATUM_LANCER_IMPORTED_ATLAS_OK two actual textures, exact normalized RGBA pixels")
	quit(0)
