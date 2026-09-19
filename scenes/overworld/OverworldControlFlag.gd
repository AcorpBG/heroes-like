extends RefCounted
## Small ground-mounted control flags share the original neutral cloth painting.
const FlagShader = preload("res://scenes/overworld/OverworldControlFlag.gdshader")
const TEXTURE_PATH := "res://art/overworld/runtime/objects/ownership_pennants/neutral_pennant.png"
const NEUTRAL := Color(0.62, 0.64, 0.67, 1.0)
const SLOT_COLORS := [
	Color("d84b40"), Color("4484df"), Color("bd9a70"), Color("42a563"),
	Color("ee8b32"), Color("a769cd"), Color("39b6b8"), Color("df82b3"),
]
var _texture: Texture2D
var _materials: Dictionary = {}

func texture() -> Texture2D:
	if _texture == null:
		_texture = load(TEXTURE_PATH) as Texture2D
	return _texture

func material(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if not _materials.has(key):
		var shader_material := ShaderMaterial.new()
		shader_material.shader = FlagShader
		shader_material.set_shader_parameter("owner_color", color)
		_materials[key] = shader_material
	return _materials[key]

static func profile(pole_base: Vector2, tile_size: float, color: Color, mine: bool = false) -> Dictionary:
	var size := Vector2.ONE * tile_size * (0.82 if mine else 1.06)
	# The painted pole's ground contact is at (44, 110) on the 128px canvas.
	var rect := Rect2(pole_base - size * Vector2(44.0 / 128.0, 110.0 / 128.0), size)
	return {"rect": rect, "pole_base": pole_base, "color": color,
		"mark_center": rect.position + size * Vector2(0.57, 0.29)}
