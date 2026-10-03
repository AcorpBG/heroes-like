extends SceneTree

# Packing changes frame locations. Check imported pixels, not just PNG metadata.
func _initialize() -> void:
	for path in ["res://art/animation/runtime/fluid/unit_sunvault_splitprism_heliograph_ballistae.png", "res://art/overworld/runtime/creature_idle/unit_sunvault_splitprism_heliograph_ballistae.png"]:
		if not verify_texture(path):
			quit(1)
			return
	print("HELIOGRAPH_BALLISTA_IMPORTED_ATLAS_OK exact battle and map RGBA pixels")
	quit(0)

func verify_texture(path: String) -> bool:
	var original := Image.new()
	var source_error := original.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	var texture := load(path) as Texture2D
	if source_error != OK or texture == null:
		push_error("Heliograph Ballista atlas source or imported texture missing")
		return false
	var imported := texture.get_image()
	if imported.is_compressed():
		if imported.decompress() != OK:
			push_error("Heliograph Ballista imported texture cannot be decoded")
			return false
	original.convert(Image.FORMAT_RGBA8)
	imported.convert(Image.FORMAT_RGBA8)
	# Respect each existing lossless import recipe without changing it.
	var recipe := ConfigFile.new()
	if recipe.load(path+".import") != OK or int(recipe.get_value("params", "compress/mode", -1)) != 0:
		push_error("Heliograph texture import recipe missing or not lossless")
		return false
	if bool(recipe.get_value("params", "process/fix_alpha_border", true)):
		original.fix_alpha_edges()
	if original.get_size() != imported.get_size() or original.get_data() != imported.get_data():
		push_error("Heliograph Ballista Godot import cache differs from published atlas; refresh imports")
		return false
	print("HELIOGRAPH_TEXTURE_EXACT ", path, " ", imported.get_size())
	return true
