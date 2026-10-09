extends RefCounted
## Edge-mounted UI meters; never replace the original portrait/town painting.
static func meter(parent: Control, key: String, current: int, maximum: int, color: Color, bottom: float) -> ProgressBar:
	var bar := parent.get_node_or_null(NodePath(key)) as ProgressBar
	if bar == null:
		bar = ProgressBar.new()
		bar.name = key
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.show_percentage = false
		parent.add_child(bar)
		bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		bar.offset_left = 10
		bar.offset_right = -10
		bar.offset_top = -bottom - 4
		bar.offset_bottom = -bottom
		var background := StyleBoxFlat.new()
		background.bg_color = Color(0.025, 0.03, 0.025, 0.95)
		var fill := StyleBoxFlat.new()
		fill.bg_color = color
		bar.add_theme_stylebox_override("background", background)
		bar.add_theme_stylebox_override("fill", fill)
	bar.max_value = maxi(1, maximum)
	bar.value = clampi(current, 0, maximum)
	bar.accessibility_name = "%s: %d / %d" % [key, current, maximum]
	return bar

static func town_badge(parent: Control, troops: int) -> void:
	var label := parent.get_node_or_null("DefenderCount") as Label
	if label == null:
		label = Label.new()
		label.name = "DefenderCount"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		parent.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		label.offset_left = 5
		label.offset_right = -7
		label.offset_top = -21
		label.offset_bottom = -4
	label.text = str(troops) if troops > 0 else "0 !"
	label.add_theme_color_override("font_color", Color("ffe3a1") if troops > 0 else Color("ff9c80"))
	label.accessibility_name = "%d defending troops%s" % [troops, "; undefended" if troops == 0 else ""]

## A small painted status medallion in the top-right corner; hidden when not shown.
static func status_badge(parent: Control, key: String, texture: Texture2D, shown: bool, description: String) -> void:
	var badge := parent.get_node_or_null(NodePath(key)) as TextureRect
	if badge == null:
		if not shown: return
		badge = TextureRect.new()
		badge.name = key
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		parent.add_child(badge)
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -24
		badge.offset_right = -3
		badge.offset_top = 3
		badge.offset_bottom = 24
	badge.texture = texture
	badge.visible = shown
	badge.accessibility_name = description if shown else ""
