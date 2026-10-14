extends ColorRect
## Soft fog of war above the map objects (docs/overworld-soft-fog-and-shadows.md). It reads
## the ground surface's per-tile lookup and layout, so it never needs its own
## upload and moves with the ground when the camera pans.

const FOG_SHADER = preload("res://scenes/overworld/overworld_fog.gdshader")

func _init() -> void:
	name = "SoftFogSurface"
	color = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false
	var shader_material := ShaderMaterial.new()
	shader_material.shader = FOG_SHADER
	material = shader_material

func configure(veil: Texture2D, underlay: Color, veil_base: Color, veil_modulate: Color) -> void:
	material.set_shader_parameter("veil", veil)
	material.set_shader_parameter("has_veil", veil != null)
	material.set_shader_parameter("underlay", underlay)
	material.set_shader_parameter("veil_base", veil_base)
	material.set_shader_parameter("veil_modulate", veil_modulate)

## Follows the ground surface: same rectangle, same world mapping, same lookup.
func sync(ground: TextureRect) -> void:
	visible = ground != null and ground.visible and ground.data_texture != null
	if not visible:
		return
	position = ground.position
	size = ground.size
	material.set_shader_parameter("terrain_data", ground.data_texture)
	for parameter in ["map_size", "world_origin", "world_span"]:
		material.set_shader_parameter(parameter, ground.material.get_shader_parameter(parameter))
