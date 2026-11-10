extends TextureRect
## The open spell book (docs/hero-screen.md, Spells): the hero menu's spell page,
## the battle's spell book and the town's magic guild. The left page lists
## spells; the right page writes out the spell under the mouse or the focus,
## else the chosen one. A view only: it is handed what to show (show_book) and
## says what was asked for (cast_requested).

## Cast this spell: its Cast button, or a click on it where a click casts.
signal cast_requested(spell_id: String)
## The book was turned to another bookmark, school or kind.
signal page_turned

const Spells = preload("res://scripts/core/SpellRules.gd")
const Visuals = preload("res://scripts/ui/FrontierVisualKit.gd")

const ICON_PATH := "res://art/ui/runtime/hero_menu/%s.png"
## Where the two pages lie in the book's picture, as fractions of it.
const LEFT_PAGE := Rect2(0.062, 0.070, 0.412, 0.805)
const RIGHT_PAGE := Rect2(0.530, 0.070, 0.412, 0.805)
## The picture's own shape, for whoever sizes the book.
const ASPECT := 1296.0 / 840.0
## How far the bookmarks rise above the book, as a fraction of its height: the
## owner leaves that much room above a book that has them.
const BOOKMARK_RISE := 0.045
const SCHOOLS := ["basic", "beacon", "furnace", "root", "veil"]
const INK := Color(0.21, 0.13, 0.07)
const INK_SOFT := Color(0.36, 0.25, 0.15)
const INK_RED := Color(0.47, 0.10, 0.06)
const INK_GREEN := Color(0.13, 0.33, 0.12)
const INK_LINE := Color(0.33, 0.22, 0.12, 0.55)
const GOLD := Color(0.84, 0.67, 0.31)
const GOLD_DIM := Color(0.55, 0.44, 0.24)
const GOLD_BRIGHT := Color(1.0, 0.93, 0.70)
const TILE_FILL := Color(0.075, 0.062, 0.05, 0.96)
const TILE_HOVER := Color(0.14, 0.115, 0.085, 0.98)
const MANA := Color(0.72, 0.84, 1.0)

## Where the book is open: {school, context, picked, bookmark}. The owner may
## hand its own dictionary (show_book "view") to keep the place through a
## rebuild of the page.
var view := {}
var _state := {}
var _hover := ""
# The spell the right page shows now.
var _shown := ""
var _left: VBoxContainer
var _right: VBoxContainer
var _bookmarks: HBoxContainer
# Keeps the head of the left page clear of the ribbons.
var _head: Control
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
	_bookmarks = HBoxContainer.new()
	_bookmarks.name = "Bookmarks"
	_bookmarks.alignment = BoxContainer.ALIGNMENT_CENTER
	_bookmarks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bookmarks)
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
##
## A book with bookmarks (the magic guild) lists by bookmark instead of by
## school and kind: bookmarks ([{id, text, tooltip, locked, heading, status,
## spells: [content rows]}]: ribbons along the top of the left page, the page
## showing the open one's spells; a locked one's are pale); details ({spell_id:
## {cost, effect}}: what to print instead of pricing and describing for the
## hero); marks ({spell_id: true}: a tick on the spell); entry_notes ({spell_id:
## {text, tone}}: the foot of the right page, tone "good" or "").
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

## Opens a bookmark by its id; false when the book has none of that id.
func open_bookmark(bookmark_id: String) -> bool:
	for bookmark in _state.get("bookmarks", []):
		if String(bookmark.get("id", "")) == bookmark_id:
			view["bookmark"] = bookmark_id
			_rebuild()
			page_turned.emit()
			return true
	return false

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
	# The ribbons hang over the top edge of the left page.
	var ribbon_height := _bookmark_size().y
	_bookmarks.size = Vector2(LEFT_PAGE.size.x * drawn.x, ribbon_height)
	_bookmarks.position = origin + Vector2(LEFT_PAGE.position.x * drawn.x, -BOOKMARK_RISE * drawn.y)
	if is_instance_valid(_head):
		_head.custom_minimum_size.y = maxf(0.0, roundf(ribbon_height - (BOOKMARK_RISE + LEFT_PAGE.position.y) * drawn.y + 4.0 * _k))

func _bookmark_size() -> Vector2:
	return Vector2(roundf(54.0 * _k), roundf(98.0 * _k))

func _rebuild() -> void:
	# The pages are written anew; the keyboard's place on them is kept.
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focus_name := String(focused.name) if focused != null and is_ancestor_of(focused) else ""
	_clear(_left)
	_clear(_right)
	_clear(_bookmarks)
	_tiles.clear()
	_shown = ""
	var pointed := _hover
	_hover = ""
	_left.add_theme_constant_override("separation", int(round(6.0 * _k)))
	_right.add_theme_constant_override("separation", int(round(6.0 * _k)))
	_bookmarks.add_theme_constant_override("separation", int(round(18.0 * _k)))
	var fallback_focus := ""
	if _state.get("bookmarks", []) is Array and not (_state.get("bookmarks", []) as Array).is_empty():
		fallback_focus = _write_bookmarked()
	else:
		fallback_focus = _write_by_school()

	for spell_id in _tiles:
		var tile := _tiles[spell_id] as Button
		tile.pressed.connect(func():
			if bool(_state.get("click_casts", false)):
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
		if (again == null or again.focus_mode == Control.FOCUS_NONE) and fallback_focus != "":
			again = find_child(fallback_focus, true, false) as Control
		if again != null:
			again.grab_focus()
	_place.call_deferred()

## The left page by school and kind: the hero's own book. Returns the name of
## the control the keyboard falls back to.
func _write_by_school() -> String:
	var hero: Dictionary = _state.get("hero", {})
	var known: Array = _state.get("spells", [])
	var contexts: Array = _state.get("contexts", [["battle", "Battle"], ["overworld", "Map"]])
	if known.is_empty():
		var none := _ink(_left, String(_state.get("empty_text", "No spell is written here yet.")), 15, INK_SOFT, true)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return ""
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
			_rebuild()
			page_turned.emit())
		tabs.add_child(tab)
	var school_name := _ink(_left, Spells._school_label(open_school), 13, INK_SOFT)
	school_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var tiers := _spell_scroll()
	var listed := known.filter(func(spell): return String(spell.get("school_id", "")) == open_school and String(spell.get("context", "")) == context)
	listed.sort_custom(func(a, b): return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0)
	for tier in range(1, 8):
		var members := listed.filter(func(spell): return Spells.spell_tier(spell) == tier)
		if members.is_empty(): continue
		_ink_heading(tiers, "Tier %d" % tier)
		_spell_flow(tiers, members, 62.0, false)
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
	_status_line(String(_state.get("status", "")), bool(_state.get("status_blocked", false)))
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
				_rebuild()
				page_turned.emit())
			switch.add_child(tab)
	return "School_%s" % open_school

## The left page by bookmark: the magic guild's levels. Returns the name of the
## control the keyboard falls back to.
func _write_bookmarked() -> String:
	var bookmarks: Array = _state.get("bookmarks", [])
	var ids := bookmarks.map(func(bookmark): return String(bookmark.get("id", "")))
	if String(view.get("bookmark", "")) not in ids:
		view["bookmark"] = String(ids[0])
	var open_id := String(view.bookmark)
	var open: Dictionary = {}
	var ribbon := _bookmark_size()
	for bookmark in bookmarks:
		var bookmark_id := String(bookmark.get("id", ""))
		var chosen := bookmark_id == open_id
		if chosen:
			open = bookmark
		var locked := bool(bookmark.get("locked", false))
		var tab := Button.new()
		tab.name = "Bookmark_%s" % bookmark_id
		tab.custom_minimum_size = ribbon
		tab.tooltip_text = String(bookmark.get("tooltip", ""))
		tab.accessibility_name = tab.tooltip_text
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			tab.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
		var text := String(bookmark.get("text", ""))
		tab.draw.connect(func(): _draw_bookmark(tab, text, chosen, locked))
		for signal_name in ["mouse_entered", "mouse_exited", "focus_entered", "focus_exited"]:
			tab.connect(signal_name, tab.queue_redraw)
		tab.pressed.connect(func(): open_bookmark(bookmark_id))
		_bookmarks.add_child(tab)
	# The ribbons lie over the head of the page.
	_head = Control.new()
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left.add_child(_head)
	var spells: Array = open.get("spells", [])
	var pages := _spell_scroll()
	var heading := String(open.get("heading", ""))
	if heading != "":
		_ink_heading(pages, heading)
	if spells.is_empty():
		var none := _ink(pages, String(_state.get("empty_text", "No spell is written here.")), 14, INK_SOFT, true)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		_spell_flow(pages, spells, float(_state.get("tile_edge", 78.0)), bool(open.get("locked", false)))
	if String(view.get("picked", "")) not in _tiles:
		view["picked"] = String(_tiles.keys()[0]) if not _tiles.is_empty() else ""
	_status_line(String(open.get("status", "")), false)
	return "Bookmark_%s" % open_id

## A ribbon bookmark: red, gold for the open one, grey with a lock for a locked.
func _draw_bookmark(tab: Button, text: String, chosen: bool, locked: bool) -> void:
	var w := tab.size.x
	var h := tab.size.y
	# The open ribbon hangs lower; the others are tucked a little into the book.
	var top := 0.0 if chosen else h * 0.12
	var bottom := h if chosen else h * 0.90
	var notch := w * 0.30
	var lit := tab.is_hovered() or tab.has_focus()
	var face := Color(0.56, 0.11, 0.08)
	if locked:
		face = Color(0.38, 0.35, 0.31)
	if chosen:
		face = Color(0.80, 0.58, 0.16) if not locked else Color(0.52, 0.48, 0.42)
	if lit and not chosen:
		face = face.lightened(0.16)
	var shade := face.darkened(0.38)
	var points := PackedVector2Array([Vector2(0, top), Vector2(w, top), Vector2(w, bottom), Vector2(w * 0.5, bottom - notch), Vector2(0, bottom)])
	# A soft shadow on the page, then the ribbon, darker toward its tail.
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(3.0, 3.0) * _k)
	tab.draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.28))
	tab.draw_polygon(points, PackedColorArray([face.lightened(0.10), face.lightened(0.10), shade, shade, shade]))
	var hem := GOLD_BRIGHT if chosen else Color(GOLD, 0.75)
	var edge := points.duplicate()
	edge.append(points[0])
	tab.draw_polyline(edge, Color(0.10, 0.05, 0.03, 0.85), maxf(1.0, 1.5 * _k), true)
	var inset := 4.0 * _k
	tab.draw_polyline(PackedVector2Array([Vector2(inset, top + inset), Vector2(inset, bottom - inset * 2.2), Vector2(w * 0.5, bottom - notch - inset * 1.2), Vector2(w - inset, bottom - inset * 2.2), Vector2(w - inset, top + inset)]), Color(hem, 0.55), 1.0, true)
	var font := tab.get_theme_default_font()
	var font_size := int(round((22.0 if chosen else 19.0) * _k))
	var ink := Color(0.26, 0.13, 0.03) if chosen and not locked else Color(1.0, 0.93, 0.78, 0.95 if not locked else 0.70)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var baseline := top + (bottom - notch - top) * (0.50 if not locked else 0.40) + text_size.y * 0.30
	tab.draw_string(font, Vector2((w - text_size.x) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	if locked:
		# A small padlock under the numeral.
		var lock := Vector2(w * 0.5, baseline + 13.0 * _k)
		var body := Rect2(lock + Vector2(-5.5, -3.0) * _k, Vector2(11.0, 8.5) * _k)
		tab.draw_arc(lock + Vector2(0.0, -3.0 * _k), 3.6 * _k, PI, TAU, 10, ink, maxf(1.0, 1.6 * _k), true)
		tab.draw_rect(body, ink)
	if tab.has_focus():
		tab.draw_polyline(edge, GOLD_BRIGHT, maxf(2.0, 2.0 * _k), true)

func _spell_scroll() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "SpellPages"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_left.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", int(round(6.0 * _k)))
	scroll.add_child(rows)
	return rows

func _status_line(text: String, blocked: bool) -> void:
	if text == "":
		return
	var status_line := _ink(_left, text, 13, INK_RED if blocked else INK_SOFT, true)
	status_line.name = "SpellStatus"
	status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

## What a spell costs and does: as handed (details), else for the hero.
func _cost_of(spell: Dictionary) -> int:
	var detail: Dictionary = _state.get("details", {}).get(String(spell.get("id", "")), {})
	return int(detail.cost) if detail.has("cost") else Spells.adjusted_spell_mana_cost(_state.get("hero", {}), spell)

func _effect_of(spell: Dictionary) -> String:
	var detail: Dictionary = _state.get("details", {}).get(String(spell.get("id", "")), {})
	return String(detail.effect) if detail.has("effect") else Spells._spell_effect_summary(spell, _state.get("hero", {}))

## A row of spell tiles with their names; `dim` pales them all.
func _spell_flow(parent: Node, spells: Array, tile_edge: float, dim: bool) -> void:
	var hero: Dictionary = _state.get("hero", {})
	var mana := int(hero.get("spellbook", {}).get("mana", {}).get("current", 0))
	var availability: Dictionary = _state.get("availability", {})
	var marks: Dictionary = _state.get("marks", {})
	var click_casts := bool(_state.get("click_casts", false))
	var priced_for_hero := not _state.has("details")
	var edge := roundf(tile_edge * _k)
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", int(round(6.0 * _k)))
	flow.add_theme_constant_override("v_separation", int(round(6.0 * _k)))
	parent.add_child(flow)
	for spell in spells:
		var spell_id := String(spell.get("id", ""))
		var cost := _cost_of(spell)
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
		tile.tooltip_text = "%s · %d mana\n%s%s" % [String(spell.get("name", "Spell")), cost, _effect_of(spell), "\n" + reason if reason != "" else ""]
		tile.accessibility_name = "%s, %d mana" % [String(spell.get("name", "Spell")), cost]
		# A spell that cannot be cast now, or that the hero has not the mana for,
		# is paler; where a click casts, it cannot be clicked.
		if dim or reason != "" or (priced_for_hero and can.is_empty() and cost > mana):
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
		if bool(marks.get(spell_id, false)):
			tile.add_child(_tick())
		cell.add_child(tile)
		var caption := _ink(cell, String(spell.get("name", "Spell")), 12, INK)
		caption.custom_minimum_size.x = roundf(maxf(84.0, tile_edge + 18.0) * _k)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.clip_text = true
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_tiles[spell_id] = tile

## A green tick in a tile's corner.
func _tick() -> Control:
	var tick := Control.new()
	tick.name = "Tick"
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge := roundf(20.0 * _k)
	tick.custom_minimum_size = Vector2(edge, edge)
	tick.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 2)
	tick.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tick.draw.connect(func():
		var centre := tick.size * 0.5
		tick.draw_circle(centre, tick.size.x * 0.5, Color(0.07, 0.13, 0.06, 0.95))
		tick.draw_arc(centre, tick.size.x * 0.5 - 0.5, 0.0, TAU, 24, Color(0.50, 0.86, 0.36), 1.0, true)
		var s := tick.size.x
		tick.draw_polyline(PackedVector2Array([Vector2(0.26, 0.52) * s, Vector2(0.44, 0.70) * s, Vector2(0.76, 0.32) * s]), Color(0.56, 0.95, 0.40), maxf(2.0, 2.4 * _k), true))
	return tick

func _show_picked() -> void:
	if not bool(_state.get("click_casts", false)):
		for spell_id in _tiles:
			(_tiles[spell_id] as Button).set_pressed_no_signal(spell_id == String(view.get("picked", "")))
	_show_entry(true)

## The right page: the spell under the mouse or the focus, else the chosen one.
## It is written again only for another spell (or when `again`): the focus may
## be on its Cast button.
func _show_entry(again: bool = false) -> void:
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
	var facts_text := "%s · Tier %d · %d mana" % [Spells._school_label(String(spell.get("school_id", ""))), Spells.spell_tier(spell), _cost_of(spell)]
	# A book that does not sort battle from map spells says which a spell is.
	if _state.has("bookmarks"):
		facts_text += " · %s" % ("Map" if String(spell.get("context", "")) == "overworld" else "Battle")
	var facts := _ink(_right, facts_text, 15, INK)
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
	var effect := _ink(lines, _effect_of(spell), 16, INK, true)
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var story := _ink(lines, String(spell.get("description", "")), 14, INK_SOFT, true)
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", int(round(14.0 * _k)))
	_right.add_child(foot)
	var availability: Dictionary = _state.get("availability", {})
	var can: Dictionary = availability.get(spell_id, {})
	var entry_notes: Dictionary = _state.get("entry_notes", {})
	if entry_notes.has(spell_id):
		var entry_note: Dictionary = entry_notes[spell_id]
		var said := _ink(foot, String(entry_note.get("text", "")), 14, INK_GREEN if String(entry_note.get("tone", "")) == "good" else INK_SOFT, true)
		said.name = "SpellNote"
		said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif can.is_empty():
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
