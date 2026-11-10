extends TextureRect
## The open spell book (docs/hero-screen.md, Spells): the hero menu's spell page
## and the battle's spell book. The left page lists the spells of one school by
## tier; the right page writes out the spell under the mouse or the focus, else
## the chosen one. A view only: it is handed what to show (show_book) and says
## what was asked for (cast_requested).

## Cast this spell: its Cast button, or a click on it where a click casts.
signal cast_requested(spell_id: String)

const Spells = preload("res://scripts/core/SpellRules.gd")
const Visuals = preload("res://scripts/ui/FrontierVisualKit.gd")

const ICON_PATH := "res://art/ui/runtime/hero_menu/%s.png"
## Where the two pages lie in the book's picture, as fractions of it.
const LEFT_PAGE := Rect2(0.062, 0.070, 0.412, 0.805)
const RIGHT_PAGE := Rect2(0.530, 0.070, 0.412, 0.805)
## The picture's own shape, for whoever sizes the book.
const ASPECT := 1296.0 / 840.0
const SCHOOLS := ["basic", "beacon", "furnace", "root", "veil"]
const INK := Color(0.21, 0.13, 0.07)
const INK_SOFT := Color(0.36, 0.25, 0.15)
const INK_RED := Color(0.47, 0.10, 0.06)
const INK_LINE := Color(0.33, 0.22, 0.12, 0.55)
const GOLD := Color(0.84, 0.67, 0.31)
const GOLD_DIM := Color(0.55, 0.44, 0.24)
const GOLD_BRIGHT := Color(1.0, 0.93, 0.70)
const TILE_FILL := Color(0.075, 0.062, 0.05, 0.96)
const TILE_HOVER := Color(0.14, 0.115, 0.085, 0.98)
const MANA := Color(0.72, 0.84, 1.0)

## Where the book is open: {school, context, picked}. The owner may hand its own
## dictionary (show_book "view") to keep the place through a rebuild of the page.
var view := {}
var _state := {}
var _hover := ""
# The spell the right page shows now.
var _shown := ""
var _left: VBoxContainer
var _right: VBoxContainer
var _tiles := {}
var _k := 1.0

func _ready() -> void:
	texture = _texture(ICON_PATH % "spell_book")
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_PASS
	_left = VBoxContainer.new()
	_left.name = "SpellList"
	_left.clip_contents = true
	add_child(_left)
	_right = VBoxContainer.new()
	_right.name = "SpellEntry"
	_right.clip_contents = true
	add_child(_right)
	resized.connect(_place)
	# A wrapped line is tall until it is given its width, and a leaf grows with
	# it; the leaf is put back once the lines have settled.
	for leaf in [_left, _right]:
		leaf.minimum_size_changed.connect(func(): _place.call_deferred())
	if not _state.is_empty():
		_rebuild()

## state: hero (whose mana and bonuses price and describe the spells); spells
## (the spells to list, as content rows); contexts ([[id, label]]: the kinds the
## book can be switched between; one hides the switch); availability
## ({spell_id: {enabled, message}} for the spells that can be cast from here);
## click_casts (a click on a spell that can be cast casts it: the battle; else a
## click chooses and the right page offers a Cast button); notes ({context: what
## the right page says of a spell that is not cast from here}); status and
## status_blocked (a line at the foot of the left page), facts (a line above
## it); empty_text (said when no spell is known); scale (sizes for a smaller
## interface); view (see above).
func show_book(state: Dictionary) -> void:
	_state = state
	if state.get("view") is Dictionary:
		view = state.view
	_k = maxf(0.5, float(state.get("scale", 1.0)))
	if is_node_ready():
		_rebuild()

## The spells' buttons on the open page, each with its spell_id and
## blocked_reason ("" when it can be cast).
func spell_buttons() -> Array:
	return _tiles.values()

func _place() -> void:
	if _left == null:
		return
	# The picture keeps its shape inside the control, so the leaves follow it.
	var texture_size := Vector2(texture.get_size()) if texture != null else size
	var fit := minf(size.x / texture_size.x, size.y / texture_size.y)
	var drawn := texture_size * fit
	var origin := (size - drawn) * 0.5
	for entry in [[_left, LEFT_PAGE], [_right, RIGHT_PAGE]]:
		var leaf: Control = entry[0]
		var rect: Rect2 = entry[1]
		leaf.position = origin + rect.position * drawn
		leaf.size = rect.size * drawn

func _rebuild() -> void:
	# The pages are written anew; the keyboard's place on them is kept.
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focus_name := String(focused.name) if focused != null and is_ancestor_of(focused) else ""
	_clear(_left)
	_clear(_right)
	_tiles.clear()
	_shown = ""
	var pointed := _hover
	_hover = ""
	_left.add_theme_constant_override("separation", int(round(6.0 * _k)))
	_right.add_theme_constant_override("separation", int(round(6.0 * _k)))
	var hero: Dictionary = _state.get("hero", {})
	var known: Array = _state.get("spells", [])
	var contexts: Array = _state.get("contexts", [["battle", "Battle"], ["overworld", "Map"]])
	if known.is_empty():
		var none := _ink(_left, String(_state.get("empty_text", "No spell is written here yet.")), 15, INK_SOFT, true)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_place.call_deferred()
		return
	var context_ids := contexts.map(func(entry): return String(entry[0]))
	var ids := known.map(func(spell): return String(spell.get("id", "")))
	if String(view.get("picked", "")) not in ids:
		view["picked"] = ""
	# The book opens where it was left; first at the map spells, if it has any.
	if String(view.get("context", "")) not in context_ids:
		view["context"] = String(context_ids[0])
		if "overworld" in context_ids and known.any(func(spell): return String(spell.get("context", "")) == "overworld"):
			view["context"] = "overworld"
	var context := String(view.context)
	var schools := SCHOOLS.filter(func(school): return known.any(func(spell): return String(spell.get("school_id", "")) == school))
	for spell in known:
		var school := String(spell.get("school_id", ""))
		if school not in schools: schools.append(school)
	if String(view.get("school", "")) not in schools:
		view["school"] = ""
		for spell in known:
			if String(spell.get("context", "")) == context:
				view["school"] = String(spell.get("school_id", ""))
				break
		if String(view.school) == "":
			view["school"] = String(schools[0])
	var open_school := String(view.school)

	var tabs := HBoxContainer.new()
	tabs.name = "SpellSchools"
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", int(round(10.0 * _k)))
	_left.add_child(tabs)
	var badge := roundf(44.0 * _k)
	for school in schools:
		var count := known.filter(func(spell): return String(spell.get("school_id", "")) == school and String(spell.get("context", "")) == context).size()
		var tab := Button.new()
		tab.name = "School_%s" % school
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(badge, badge)
		tab.tooltip_text = "%s · %d spell%s" % [Spells._school_label(String(school)), count, "" if count == 1 else "s"]
		tab.accessibility_name = tab.tooltip_text
		# The school's badge is the button; the open school's has a ring.
		var radius := int(badge * 0.5)
		for state_name in ["normal", "hover", "disabled"]:
			tab.add_theme_stylebox_override(state_name, _box(Color(0, 0, 0, 0), 0, radius, Color(0, 0, 0, 0)))
		for state_name in ["pressed", "hover_pressed"]:
			tab.add_theme_stylebox_override(state_name, _box(INK_RED, 3, radius, Color(0, 0, 0, 0)))
		tab.add_theme_stylebox_override("focus", _box(INK, 2, radius, Color(0, 0, 0, 0)))
		var sigil := _picture(_texture(ICON_PATH % ("school_%s" % String(school))))
		sigil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
		sigil.modulate = Color(1.0, 1.0, 1.0, 1.0) if school == open_school else Color(0.78, 0.74, 0.68, 0.72)
		tab.add_child(sigil)
		tab.set_pressed_no_signal(school == open_school)
		tab.pressed.connect(func():
			view["school"] = String(school)
			_rebuild())
		tabs.add_child(tab)
	var school_name := _ink(_left, Spells._school_label(open_school), 13, INK_SOFT)
	school_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var scroll := ScrollContainer.new()
	scroll.name = "SpellPages"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_left.add_child(scroll)
	var tiers := VBoxContainer.new()
	tiers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiers.add_theme_constant_override("separation", int(round(6.0 * _k)))
	scroll.add_child(tiers)
	var listed := known.filter(func(spell): return String(spell.get("school_id", "")) == open_school and String(spell.get("context", "")) == context)
	listed.sort_custom(func(a, b): return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0)
	var mana := int(hero.get("spellbook", {}).get("mana", {}).get("current", 0))
	var availability: Dictionary = _state.get("availability", {})
	var click_casts := bool(_state.get("click_casts", false))
	var edge := roundf(62.0 * _k)
	for tier in range(1, 8):
		var members := listed.filter(func(spell): return Spells.spell_tier(spell) == tier)
		if members.is_empty(): continue
		_ink_heading(tiers, "Tier %d" % tier)
		var flow := HFlowContainer.new()
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.add_theme_constant_override("h_separation", int(round(6.0 * _k)))
		flow.add_theme_constant_override("v_separation", int(round(6.0 * _k)))
		tiers.add_child(flow)
		for spell in members:
			var spell_id := String(spell.get("id", ""))
			var cost := Spells.adjusted_spell_mana_cost(hero, spell)
			var can: Dictionary = availability.get(spell_id, {})
			var reason := "" if can.is_empty() or bool(can.get("enabled", false)) else String(can.get("message", ""))
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 0)
			flow.add_child(cell)
			var tile := _tile(Vector2(edge, edge), _texture(Spells.spell_icon_path(spell_id)))
			tile.name = "Spell_%s" % spell_id
			tile.set_meta("spell_id", spell_id)
			tile.set_meta("blocked_reason", reason)
			tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			tile.tooltip_text = "%s · %d mana\n%s%s" % [String(spell.get("name", "Spell")), cost, Spells._spell_effect_summary(spell, hero), "\n" + reason if reason != "" else ""]
			tile.accessibility_name = "%s, %d mana" % [String(spell.get("name", "Spell")), cost]
			# A spell that cannot be cast now, or that the hero has not the mana for,
			# is paler; where a click casts, it cannot be clicked.
			if reason != "" or (can.is_empty() and cost > mana):
				tile.modulate = Color(1.0, 1.0, 1.0, 0.5)
			if click_casts:
				tile.toggle_mode = false
				tile.disabled = reason != ""
				tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if reason == "" else Control.CURSOR_ARROW
			var price := Label.new()
			price.text = str(cost)
			price.mouse_filter = Control.MOUSE_FILTER_IGNORE
			price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			price.add_theme_font_size_override("font_size", int(round(12.0 * _k)))
			price.add_theme_color_override("font_color", MANA)
			var price_style := _box(GOLD_DIM, 1, 4, Color(0.05, 0.06, 0.09, 0.92))
			price_style.content_margin_left = 4.0 * _k
			price_style.content_margin_right = 4.0 * _k
			price.add_theme_stylebox_override("normal", price_style)
			price.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 2)
			price.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			price.grow_vertical = Control.GROW_DIRECTION_BEGIN
			tile.add_child(price)
			cell.add_child(tile)
			var caption := _ink(cell, String(spell.get("name", "Spell")), 12, INK)
			caption.custom_minimum_size.x = roundf(84.0 * _k)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.clip_text = true
			caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			_tiles[spell_id] = tile
	if _tiles.is_empty():
		var kind := "map" if context == "overworld" else "battle"
		var empty := _ink(tiers, "No %s spells of this school." % kind, 14, INK_SOFT, true)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif String(view.get("picked", "")) not in _tiles:
		view["picked"] = String(_tiles.keys()[0])

	var facts_text := String(_state.get("facts", ""))
	if facts_text != "":
		var facts_line := _ink(_left, facts_text, 14, INK, true)
		facts_line.name = "SpellFacts"
		facts_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var status := String(_state.get("status", ""))
	if status != "":
		var status_line := _ink(_left, status, 13, INK_RED if bool(_state.get("status_blocked", false)) else INK_SOFT, true)
		status_line.name = "SpellStatus"
		status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if contexts.size() > 1:
		var switch := HBoxContainer.new()
		switch.name = "SpellContexts"
		switch.alignment = BoxContainer.ALIGNMENT_CENTER
		switch.add_theme_constant_override("separation", int(round(26.0 * _k)))
		_left.add_child(switch)
		for entry in contexts:
			var context_id := String(entry[0])
			var count := known.filter(func(spell): return String(spell.get("context", "")) == context_id).size()
			var chosen := context_id == context
			var tab := Button.new()
			tab.name = "Context_%s" % context_id
			tab.text = String(entry[1])
			tab.tooltip_text = "%d %s spell%s known" % [count, String(entry[1]).to_lower(), "" if count == 1 else "s"]
			tab.add_theme_font_size_override("font_size", int(round(17.0 * _k)))
			for color_name in ["font_color", "font_focus_color", "font_pressed_color"]:
				tab.add_theme_color_override(color_name, INK if chosen else INK_SOFT)
			tab.add_theme_color_override("font_hover_color", INK_RED)
			var underline := StyleBoxFlat.new()
			underline.bg_color = Color(0, 0, 0, 0)
			underline.border_color = INK if chosen else Color(0, 0, 0, 0)
			underline.border_width_bottom = 2
			underline.content_margin_left = 6.0
			underline.content_margin_right = 6.0
			for state_name in ["normal", "hover", "pressed", "focus"]:
				tab.add_theme_stylebox_override(state_name, underline)
			tab.pressed.connect(func():
				view["context"] = context_id
				view["school"] = ""
				_rebuild())
			switch.add_child(tab)

	for spell_id in _tiles:
		var tile := _tiles[spell_id] as Button
		tile.pressed.connect(func():
			if click_casts:
				cast_requested.emit(spell_id)
				return
			view["picked"] = spell_id
			_show_picked())
		for signal_name in ["mouse_entered", "focus_entered"]:
			tile.connect(signal_name, func():
				_hover = spell_id
				_show_entry())
		for signal_name in ["mouse_exited", "focus_exited"]:
			tile.connect(signal_name, func():
				if _hover == spell_id:
					_hover = ""
					_show_entry())
	# A book rebuilt under the mouse still reads the spell it points at.
	if pointed in _tiles:
		_hover = pointed
	_show_picked()
	if focus_name != "":
		var again := find_child(focus_name, true, false) as Control
		if again == null or again.focus_mode == Control.FOCUS_NONE:
			again = find_child("School_%s" % open_school, true, false) as Control
		if again != null:
			again.grab_focus()
	_place.call_deferred()

func _show_picked() -> void:
	if not bool(_state.get("click_casts", false)):
		for spell_id in _tiles:
			(_tiles[spell_id] as Button).set_pressed_no_signal(spell_id == String(view.get("picked", "")))
	_show_entry(true)

## The right page: the spell under the mouse or the focus, else the chosen one.
## It is written again only for another spell (or when `again`): the focus may
## be on its Cast button.
func _show_entry(again: bool = false) -> void:
	var hero: Dictionary = _state.get("hero", {})
	var picked := String(view.get("picked", ""))
	var spell_id := _hover if _hover != "" else picked
	if spell_id == _shown and not again:
		return
	_shown = spell_id
	_clear(_right)
	var spell := ContentService.get_spell(spell_id) if spell_id != "" else {}
	if spell.is_empty():
		return
	var picture_edge := roundf(148.0 * _k)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(picture_edge, picture_edge)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var frame_style := _box(Color(0.76, 0.60, 0.30), 1, 5, Color(0.16, 0.14, 0.115))
	frame_style.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.add_child(_picture(_texture(Spells.spell_icon_path(spell_id))))
	_right.add_child(frame)
	var title := _ink(_right, String(spell.get("name", "Spell")).to_upper(), 24, INK_RED, true)
	title.name = "SpellTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cost := Spells.adjusted_spell_mana_cost(hero, spell)
	var facts := _ink(_right, "%s · Tier %d · %d mana" % [Spells._school_label(String(spell.get("school_id", ""))), Spells.spell_tier(spell), cost], 15, INK)
	facts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rule := ColorRect.new()
	rule.color = INK_LINE
	rule.custom_minimum_size.y = 1.0
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right.add_child(scroll)
	var lines := VBoxContainer.new()
	lines.name = "SpellDescription"
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", int(round(8.0 * _k)))
	scroll.add_child(lines)
	var effect := _ink(lines, Spells._spell_effect_summary(spell, hero), 16, INK, true)
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var story := _ink(lines, String(spell.get("description", "")), 14, INK_SOFT, true)
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", int(round(14.0 * _k)))
	_right.add_child(foot)
	var availability: Dictionary = _state.get("availability", {})
	var can: Dictionary = availability.get(spell_id, {})
	if can.is_empty():
		var notes: Dictionary = _state.get("notes", {})
		var note := _ink(foot, String(notes.get(String(spell.get("context", "")), "")), 13, INK_SOFT, true)
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		var blocked := not bool(can.get("enabled", false))
		var message := String(can.get("message", ""))
		if bool(_state.get("click_casts", false)):
			# What holds every spell back is said once, at the foot of the left page.
			if blocked and message == String(_state.get("status", "")):
				message = ""
			var line := _ink(foot, message if blocked else "Click the spell to cast it.", 14, INK_RED if blocked else INK, true)
			line.name = "SpellReadiness"
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			var state_line := _ink(foot, message, 13, INK_RED if blocked else INK, true)
			state_line.name = "SpellReadiness"
			state_line.custom_minimum_size.x = roundf(150.0 * _k)
			state_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			state_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			var cast := Button.new()
			cast.name = "PrepareSpell"
			cast.text = String(_state.get("cast_text", "Cast"))
			cast.tooltip_text = message if message != "" else "Cast this spell."
			cast.accessibility_name = cast.tooltip_text
			Visuals.apply_button(cast, "primary", 130.0 * _k, 40.0 * _k, int(round(15.0 * _k)))
			cast.disabled = blocked
			# The button casts what is chosen; a spell only pointed at is read.
			cast.visible = spell_id == picked
			cast.pressed.connect(func(): cast_requested.emit(spell_id))
			foot.add_child(cast)
	_place.call_deferred()

# --- Pieces ----------------------------------------------------------------------

## Dark ink on the parchment. A line that may be long is told to wrap before it
## is added, or its full length would widen the page it lies on.
func _ink(parent: Node, text: String, font_size: int, color: Color, wraps: bool = false) -> Label:
	var label := Label.new()
	if wraps:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.add_theme_font_size_override("font_size", int(round(font_size * _k)))
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

## A heading between two ink lines.
func _ink_heading(parent: Node, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(round(10.0 * _k)))
	parent.add_child(row)
	for index in range(3):
		if index == 1:
			_ink(row, text, 16, INK)
			continue
		var line := ColorRect.new()
		line.color = INK_LINE
		line.custom_minimum_size.y = 1.0
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(line)

func _tile(tile_size: Vector2, picture: Texture2D) -> Button:
	var tile := Button.new()
	tile.toggle_mode = true
	tile.custom_minimum_size = tile_size
	tile.focus_mode = Control.FOCUS_ALL
	tile.clip_contents = true
	tile.add_theme_stylebox_override("normal", _box(GOLD_DIM, 1, 5, TILE_FILL))
	tile.add_theme_stylebox_override("disabled", _box(GOLD_DIM, 1, 5, TILE_FILL))
	tile.add_theme_stylebox_override("hover", _box(GOLD, 2, 5, TILE_HOVER))
	for state_name in ["pressed", "hover_pressed"]:
		tile.add_theme_stylebox_override(state_name, _box(GOLD_BRIGHT, 3, 5, TILE_HOVER))
	tile.add_theme_stylebox_override("focus", _box(INK_RED, 2, 5, Color(0, 0, 0, 0)))
	var art := _picture(picture)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	tile.add_child(art)
	return tile

func _box(border: Color, width: int, radius: int, fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style

func _picture(picture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = picture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _texture(path: String) -> Texture2D:
	return ResourceLoader.load(path, "Texture2D") as Texture2D if path != "" and ResourceLoader.exists(path, "Texture2D") else null
