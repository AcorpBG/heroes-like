extends RefCounted

# Composition only. Existing MainMenu actions retain launch/save/input ownership.
const PANORAMA := "res://art/results/runtime/backdrops/outcome_victory.png"

static func configure(menu: Control) -> void:
	menu.get_node("HeroStage").texture = load(PANORAMA)
	menu.get_node("TorchGlow").presentation_enabled = false
	var shade := TextureRect.new()
	shade.name = "NavigationShade"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.30, 0.56, 1.0])
	gradient.colors = PackedColorArray([Color(0.025,0.04,0.045,0.96), Color(0.025,0.04,0.045,0.85), Color(0.025,0.04,0.045,0.12), Color(0,0,0,0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 1
	shade.texture = texture
	menu.add_child(shade)
	menu.move_child(shade, menu.get_node("HeroStage").get_index()+1)
	menu.get_node("BackdropCommandHotspots/OpenSaves").text = "Saved games"
	menu.get_node("BackdropCommandHotspots/OpenSkirmish").text = "New skirmish"
	menu.get_node("BackdropCommandHotspots/OpenEditor").text = "Map editor"
	layout(menu)

static func place(control: Control, rect: Rect2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size

static func layout(menu: Control) -> void:
	if not menu.has_node("NavigationShade"): return
	var viewport := menu.size
	var open: bool = menu.get_node("StageDockPanel").visible
	var left := viewport.x * 0.055
	var width := minf(viewport.x * 0.32, 520.0)
	var commands := menu.get_node("BackdropCommandHotspots") as Control
	commands.visible = not open
	var logo := menu.get_node("LogoPocketPanel") as Control
	place(logo,Rect2(Vector2(left,viewport.y*(0.025 if open else 0.10)),Vector2(width+70,viewport.y*0.20)))
	var title := menu.get_node("%Title") as Label
	title.text = "AURELION REACH" if open else "AURELION\nREACH"
	title.add_theme_font_size_override("font_size", 30 if open else int(clampf(viewport.y*0.063,42,68)))
	title.add_theme_color_override("font_color",Color(0.98,0.89,0.67))
	var eyebrow := menu.get_node("%Eyebrow") as Label
	eyebrow.visible = not open
	eyebrow.text = "A REALM WORTH FIGHTING FOR"
	eyebrow.add_theme_font_size_override("font_size",12)
	var crest := menu.get_node("LogoPocketPanel/LogoPocketPad/LogoPocketBox/LogoHeader/WarGlyph") as Control
	crest.custom_minimum_size = Vector2(48,48) if open else Vector2(64,84)
	var names := ["OpenCampaign","OpenSkirmish","OpenSaves","OpenSettings","OpenEditor","Quit"]
	# Auto-wrapped notice minimum sizes are provisional until the container
	# sort. Reserve two lines explicitly; never use that provisional height to
	# push the entire command column off-screen.
	var first_y := viewport.y*0.37 + (56.0 if menu.get_node("%Summary").visible else 0.0)
	for index in range(names.size()):
		var button := commands.get_node(names[index]) as Button
		place(button,Rect2(Vector2(left+14,first_y+viewport.y*index*0.075),Vector2(width,viewport.y*0.063)))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size",int(clampf(viewport.y*0.030,21,30)))
		button.add_theme_constant_override("outline_size",0)
		var plain := StyleBoxFlat.new()
		plain.bg_color = Color(0,0,0,0)
		plain.content_margin_left = 20
		plain.border_width_left = 2
		plain.border_color = Color(0.75,0.61,0.33,0.28)
		button.add_theme_stylebox_override("normal",plain)
		var hover := plain.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.77,0.61,0.31,0.14)
		hover.border_color = Color(0.97,0.83,0.48)
		button.add_theme_stylebox_override("hover",hover)
		button.add_theme_stylebox_override("pressed",hover)
		button.add_theme_stylebox_override("focus",hover)
	var footer := menu.get_node("FooterPocketPanel") as Control
	place(footer,Rect2(Vector2(left,viewport.y*0.91),Vector2(viewport.x*0.55,viewport.y*0.08)))
