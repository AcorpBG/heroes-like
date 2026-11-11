extends Control
## The hero menu (docs/hero-screen.md): the commander's portrait and command stats
## at the left, and at the right one page at a time: Army, Artifacts (the figure
## with a slot for everything worn), Specialties, Spells. Read-only unless opened
## with `orders`; then it asks its owning screen to cast spells, wear and stow
## artifacts, move stacks, choose specialties and meet heroes. It never changes
## the session itself.

signal closed
signal spell_cast_requested(spell_id: String)
signal artifact_action_requested(action_id: String)
signal specialty_requested(action_id: String)
signal army_operation_requested(source_holder_id: String, source_slot_index: int, target_holder_id: String, target_slot_index: int, amount_token: String)
signal meet_requested(hero_id: String)

const UnitPortraits := preload("res://scripts/ui/UnitPortraitTexture.gd")
const Visuals = preload("res://scripts/ui/FrontierVisualKit.gd")
const Heroes = preload("res://scripts/core/HeroCommandRules.gd")
const Progression = preload("res://scripts/core/HeroProgressionRules.gd")
const Artifacts = preload("res://scripts/core/ArtifactRules.gd")
const Spells = preload("res://scripts/core/SpellRules.gd")
const ArmyStackBarScript = preload("res://scenes/shared/ArmyStackBar.gd")
const SpellGrimoireScript = preload("res://scenes/shared/SpellGrimoire.gd")
const DecisionDetails = preload("res://scripts/ui/DecisionDetails.gd")

const ICON_PATH := "res://art/ui/runtime/hero_menu/%s.png"
const PANEL_SIZE := Vector2(1300.0, 720.0)
const LEFT_WIDTH := 360.0
const PORTRAIT_HEIGHT := 452.0
## The pages, by the names their callers open them with.
const PAGES := [
	{"id": "Army", "caption": "Army", "icon": "page_army"},
	{"id": "Artifacts", "caption": "Artifacts", "icon": "page_artifacts"},
	{"id": "Specializations", "caption": "Specialties", "icon": "page_specialties"},
	{"id": "Spellbook", "caption": "Spells", "icon": "page_spells"},
]
## Where each worn slot stands on the figure, in the figure's own box.
const DOLL_SIZE := Vector2(440.0, 462.0)
const DOLL_BODY := Rect2(98.0, 8.0, 244.0, 448.0)
const DOLL_SLOTS := {
	"banner": Rect2(0.0, 48.0, 76.0, 112.0),
	"head": Rect2(188.0, 0.0, 64.0, 64.0),
	"neck": Rect2(262.0, 58.0, 56.0, 56.0),
	"cloak": Rect2(108.0, 60.0, 64.0, 64.0),
	"armor": Rect2(188.0, 128.0, 64.0, 64.0),
	"hand": Rect2(79.0, 208.0, 64.0, 64.0),
	"hand_2": Rect2(297.0, 208.0, 64.0, 64.0),
	"ring": Rect2(85.0, 282.0, 52.0, 52.0),
	"ring_2": Rect2(303.0, 282.0, 52.0, 52.0),
	"boots": Rect2(188.0, 396.0, 64.0, 64.0),
}
const TRINKET_SLOTS := ["trinket", "trinket_2", "trinket_3", "trinket_4"]
const SLOT_NAMES := {
	"head": "Head", "neck": "Neck", "cloak": "Cloak", "armor": "Chest", "hand": "Hand", "hand_2": "Hand",
	"ring": "Ring", "ring_2": "Ring", "boots": "Feet", "banner": "Banner",
	"trinket": "Trinket", "trinket_2": "Trinket", "trinket_3": "Trinket", "trinket_4": "Trinket",
}
const KIND_NAMES := {
	"head": "headgear", "neck": "neckpiece", "cloak": "cloak", "armor": "armor", "hand": "held item",
	"ring": "ring", "boots": "footgear", "banner": "banner", "trinket": "trinket",
}
const GOLD := Color(0.84, 0.67, 0.31)
const GOLD_DIM := Color(0.55, 0.44, 0.24)
const GOLD_BRIGHT := Color(1.0, 0.93, 0.70)
## An artifact's band (docs/artifact-system.md): its colour on tiles and cards.
const BAND_COLORS := {
	"common": Color(0.66, 0.68, 0.70),
	"uncommon": Color(0.46, 0.76, 0.48),
	"rare": Color(0.38, 0.66, 0.90),
	"epic": Color(0.78, 0.56, 0.94),
}
const HAIRLINE := Color(0.83, 0.68, 0.36, 0.45)
const TILE_FILL := Color(0.075, 0.062, 0.05, 0.96)
const TILE_HOVER := Color(0.14, 0.115, 0.085, 0.98)
const CARD_FILL := Color(0.06, 0.05, 0.04, 0.6)
const DRAG_ARTIFACT := "hero_menu_artifact"

var hero: Dictionary = {}
## Live orders for an interactive menu: spell_actions, artifact_actions,
## specialty_actions (action lists), army_holder (army slot snapshot) and
## meet_partners (heroes on the same tile). Empty keeps the menu read-only.
var orders: Dictionary = {}
## The close button names where the player returns (the Town screen sets its own).
var close_label := "Return to map"
var _panel: PanelContainer
var _body: HBoxContainer
var _close: Button
var _return_focus: WeakRef
var _page_id := "Army"
var _page_buttons := {}
var _page_holder: MarginContainer
# What is picked on each page; kept through a rebuild after an order.
var _picked_stack := -1
var _picked_slot := ""
var _picked_artifact := ""
# What the mouse is over, shown in the page's card until it leaves.
var _hover_stack := -1
# Where the spell book is open: its school, kind (battle or map) and spell.
var _spell_view := {}
var _last_focus: Control
# The worn slots' tiles, and the kind of the artifact being dragged.
var _slot_tiles := {}
var _dragged_kind := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	set_process_input(false)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.023, 0.025, 0.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_panel = PanelContainer.new()
	add_child(_panel)
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 22)
	_panel.add_child(_body)
	resized.connect(_layout)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

## `tab` opens a named page ("Army", "Artifacts", "Specializations", "Spellbook").
func open_hero(snapshot: Dictionary, return_control: Control, live_orders: Dictionary = {}, tab: String = "") -> void:
	_return_focus = weakref(return_control) if return_control != null else null
	if String(snapshot.get("id", "")) != String(hero.get("id", "")):
		_picked_stack = -1
		_picked_slot = ""
		_picked_artifact = ""
		_spell_view["picked"] = ""
	if tab != "":
		_page_id = tab
	_rebuild(snapshot, live_orders)
	show()
	move_to_front()
	set_process_input(true)
	_layout()
	_close.call_deferred("grab_focus")

## Rebuilds after an order, keeping the open page and what was picked on it.
func refresh_hero(snapshot: Dictionary, live_orders: Dictionary) -> void:
	if not visible: return
	_rebuild(snapshot, live_orders)
	_layout()
	if _page_buttons.has(_page_id):
		(_page_buttons[_page_id] as Button).call_deferred("grab_focus")

func show_tab(title: String) -> void:
	for page in PAGES:
		if String(page.id) == title:
			_page_id = title
			_show_page()
			return

func current_tab() -> String:
	return _page_id

func is_interactive() -> bool:
	return not orders.is_empty()

func close_sheet() -> void:
	if not visible: return
	hide()
	set_process_input(false)
	var previous = _return_focus.get_ref() if _return_focus != null else null
	if is_instance_valid(previous) and previous.is_visible_in_tree():
		previous.grab_focus()
	closed.emit()

func _notification(what: int) -> void:
	# A drag ended, dropped or not: the slots stop showing where it could go.
	if what == NOTIFICATION_DRAG_END and _dragged_kind != "":
		_dragged_kind = ""
		_mark_drop_slots()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_sheet()
		get_viewport().set_input_as_handled()

## Arrow keys and Tab never carry the focus to the screen behind the menu.
func _on_focus_changed(control: Control) -> void:
	if not visible or control == null:
		return
	if is_ancestor_of(control):
		_last_focus = control
		return
	# A popup of the menu's own controls (none today) would have another viewport.
	if control.get_viewport() != get_viewport():
		return
	var back: Control = _last_focus if is_instance_valid(_last_focus) and _last_focus.is_visible_in_tree() else _close
	if is_instance_valid(back):
		back.grab_focus.call_deferred()

func _layout() -> void:
	if _panel == null: return
	_panel.size = Vector2(minf(PANEL_SIZE.x, size.x - 32.0), minf(PANEL_SIZE.y, size.y - 32.0))
	_panel.position = (size - _panel.size) * 0.5

func _rebuild(snapshot: Dictionary, live_orders: Dictionary) -> void:
	hero = snapshot.duplicate(true)
	orders = live_orders.duplicate(true)
	_panel.add_theme_stylebox_override("panel", Visuals.info_card_style())
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_page_buttons.clear()
	_last_focus = null
	_build_identity()
	_build_right()
	_show_page()

# --- The left: who the hero is -------------------------------------------------

func _build_identity() -> void:
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = LEFT_WIDTH
	left.add_theme_constant_override("separation", 10)
	_body.add_child(left)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(LEFT_WIDTH, PORTRAIT_HEIGHT)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.clip_contents = true
	var frame_style := _box(Color(0.76, 0.60, 0.30), 1, 5, Color(0.30, 0.27, 0.23))
	frame_style.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", frame_style)
	left.add_child(frame)
	var portrait := _picture(_texture(String(ContentService.get_hero_art(String(hero.get("id", ""))).get("portrait", ""))), true)
	portrait.name = "HeroPortrait"
	frame.add_child(portrait)
	# The name sits on the picture's lower edge, on a shade that fades upward.
	var plate := Control.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(plate)
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.04, 0.03, 0.02, 0.0))
	gradient.set_color(1, Color(0.04, 0.03, 0.02, 0.92))
	var ramp := GradientTexture2D.new()
	ramp.gradient = gradient
	ramp.fill_from = Vector2(0.0, 0.0)
	ramp.fill_to = Vector2(0.0, 1.0)
	ramp.width = 8
	ramp.height = 64
	shade.texture = ramp
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -120.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(shade)
	var names := VBoxContainer.new()
	names.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	names.offset_left = 14.0
	names.offset_right = -14.0
	names.offset_top = -68.0
	names.offset_bottom = -10.0
	names.add_theme_constant_override("separation", 0)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(names)
	var title := _label(names, String(hero.get("name", "Hero")), 26, "gold")
	title.name = "HeroName"
	title.clip_text = true
	var calling := _label(names, _calling_line(), 14, "body")
	calling.clip_text = true
	calling.tooltip_text = Heroes.hero_identity_context_line(hero)

	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 12)
	left.add_child(level_row)
	_label(level_row, "Level %d" % int(hero.get("level", 1)), 18, "gold")
	var experience := ProgressBar.new()
	experience.name = "HeroExperienceProgress"
	experience.custom_minimum_size.y = 22.0
	experience.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	experience.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	experience.show_percentage = false
	experience.max_value = maxi(1, int(hero.get("next_level_experience", 250)))
	experience.value = int(hero.get("experience", 0))
	experience.add_theme_stylebox_override("background", _box(GOLD_DIM, 1, 6, Color(0.05, 0.04, 0.035, 0.9)))
	experience.add_theme_stylebox_override("fill", _box(Color(0, 0, 0, 0), 0, 6, Color(0.62, 0.47, 0.18, 0.95)))
	experience.tooltip_text = "%d experience to level %d" % [maxi(0, int(experience.max_value) - int(experience.value)), int(hero.get("level", 1)) + 1]
	experience.accessibility_name = experience.tooltip_text
	level_row.add_child(experience)
	var amount := _label(experience, "%d / %d" % [int(experience.value), int(experience.max_value)], 13, "body")
	amount.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var stats := HBoxContainer.new()
	stats.name = "CommandStats"
	stats.add_theme_constant_override("separation", 8)
	stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(stats)
	var artifact_bonuses := Artifacts.aggregate_bonuses(hero.duplicate(true))
	var specialty_bonuses := Progression.aggregate_bonuses(hero)
	for stat in ["attack", "defense", "power", "knowledge"]:
		var base := int(hero.get("command", {}).get(stat, 0))
		var bonus := int(artifact_bonuses.get("battle_" + stat, 0)) + int(specialty_bonuses.get("battle_" + stat, 0)) if stat in ["attack", "defense"] else int(specialty_bonuses.get("battle_power" if stat == "power" else "knowledge", 0))
		bonus = maxi(bonus, -base)
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("panel", _card_style())
		tile.tooltip_text = "%s: %d base + %d from artifacts and specialties. Battle conditions may add more." % [String(stat).capitalize(), base, bonus]
		stats.add_child(tile)
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 0)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(column)
		var glyph := _picture(_icon("stat_" + stat), false)
		glyph.custom_minimum_size = Vector2(34.0, 34.0)
		column.add_child(glyph)
		var caption := _label(column, String(stat).capitalize(), 12, "muted")
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var number := _label(column, str(base + bonus), 24, "green" if bonus > 0 else ("red" if bonus < 0 else "body"))
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _calling_line() -> String:
	var template := Heroes.hero_template(hero)
	var parts := PackedStringArray()
	var archetype := String(template.get("archetype", "")).capitalize()
	if archetype != "": parts.append(archetype)
	parts.append("Magic hero" if String(template.get("command_path", hero.get("command_path", "might"))) == "magic" else "Might hero")
	var faction := String(ContentService.get_faction(String(template.get("faction_id", ""))).get("name", ""))
	if faction != "": parts.append(faction)
	return " · ".join(parts)

# --- The right: the page buttons, the meters and the chosen page ----------------

func _build_right() -> void:
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	_body.add_child(right)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	right.add_child(top)
	for page in PAGES:
		top.add_child(_page_button(page))
	var divider := ColorRect.new()
	divider.color = HAIRLINE
	divider.custom_minimum_size.x = 1.0
	top.add_child(divider)
	var meters := VBoxContainer.new()
	meters.add_theme_constant_override("separation", 3)
	meters.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(meters)
	var movement: Dictionary = hero.get("movement", {})
	var mana: Dictionary = hero.get("spellbook", {}).get("mana", {})
	_meter(meters, "meter_movement", "Movement", "%d / %d" % [int(movement.get("current", 0)), int(movement.get("max", 0))], "Movement left today, and what a full day gives.")
	_meter(meters, "meter_mana", "Mana", "%d / %d" % [int(mana.get("current", 0)), int(mana.get("max", 0))], "Mana for spells, and the most the hero holds.")
	_meter(meters, "meter_scouting", "Scouting", str(Heroes.scouting_radius_for_hero(hero)), "How many tiles around it the hero reveals.")
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 6)
	top.add_child(buttons)
	_close = _button(buttons, close_label, "Close the hero menu · Escape", "primary", Vector2(190.0, 40.0))
	_close.name = "CloseHeroSheet"
	_close.pressed.connect(close_sheet)
	for partner in orders.get("meet_partners", []):
		var partner_id := String(partner.get("id", ""))
		var partner_name := String(partner.get("name", "Commander"))
		var meet := _button(buttons, "Meet %s" % partner_name.get_slice(" ", 0), "Meet %s to exchange troops, artifacts and spells." % partner_name, "secondary", Vector2(190.0, 34.0))
		meet.name = "Meet_%s" % partner_id
		meet.icon = _texture(String(ContentService.get_hero_art(partner_id).get("portrait", "")))
		meet.expand_icon = true
		meet.add_theme_constant_override("icon_max_width", 24)
		meet.pressed.connect(func(): meet_requested.emit(partner_id))
	_hairline(right)
	_page_holder = MarginContainer.new()
	_page_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_page_holder)

func _page_button(page: Dictionary) -> Control:
	var page_id := String(page.id)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	var button := Button.new()
	button.name = "Page_%s" % page_id
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(64.0, 64.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = String(page.caption)
	button.accessibility_name = String(page.caption)
	button.add_theme_stylebox_override("normal", _box(GOLD_DIM, 1, 32, TILE_FILL))
	button.add_theme_stylebox_override("hover", _box(GOLD, 1, 32, TILE_HOVER))
	for state in ["pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, _box(GOLD, 3, 32, TILE_HOVER))
	button.add_theme_stylebox_override("focus", _box(GOLD_BRIGHT, 2, 32, Color(0, 0, 0, 0)))
	var glyph := _picture(_icon(String(page.icon)), false)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 13)
	button.add_child(glyph)
	button.pressed.connect(func():
		_page_id = page_id
		_show_page())
	column.add_child(button)
	var caption := _label(column, String(page.caption), 14, "body")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.custom_minimum_size.x = 84.0
	_page_buttons[page_id] = button
	return column

func _meter(parent: Node, icon_name: String, caption: String, value: String, tooltip: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.tooltip_text = tooltip
	parent.add_child(row)
	var glyph := _picture(_icon(icon_name), false)
	glyph.custom_minimum_size = Vector2(22.0, 22.0)
	row.add_child(glyph)
	var name_label := _label(row, caption, 14, "muted")
	name_label.custom_minimum_size.x = 82.0
	_label(row, value, 15, "body")

func _show_page() -> void:
	if _page_holder == null or not is_instance_valid(_page_holder): return
	if not _page_buttons.has(_page_id):
		_page_id = "Army"
	for page_id in _page_buttons:
		(_page_buttons[page_id] as Button).set_pressed_no_signal(page_id == _page_id)
	for child in _page_holder.get_children():
		_page_holder.remove_child(child)
		child.queue_free()
	var page := VBoxContainer.new()
	page.name = _page_id
	page.add_theme_constant_override("separation", 10)
	_page_holder.add_child(page)
	match _page_id:
		"Artifacts": _build_artifacts(page)
		"Specializations": _build_specialties(page)
		"Spellbook": _build_spells(page)
		_: _build_army(page)

# --- Army ---------------------------------------------------------------------

func _build_army(page: VBoxContainer) -> void:
	var holder: Dictionary = orders.get("army_holder", {})
	var managed := not holder.is_empty()
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 14)
	page.add_child(heading)
	_label(heading, "Army", 22, "gold")
	var hint := _label(heading, "Click a stack, then another slot, or drag it: move, merge or split." if managed else "Choose a stack to see what it is.", 13, "muted")
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	var detail := _card()
	if managed:
		var bar := ArmyStackBarScript.new()
		bar.name = "HeroArmyStacks"
		page.add_child(bar)
		bar.set_large_tiles(true)
		bar.configure([holder], true)
		bar.operation_requested.connect(func(source_holder_id: String, source_slot_index: int, target_holder_id: String, target_slot_index: int, amount_token: String):
			army_operation_requested.emit(source_holder_id, source_slot_index, target_holder_id, target_slot_index, amount_token))
		bar.selection_changed.connect(func(snapshot: Dictionary):
			var slot_index := int(snapshot.get("selected_slot_index", -1))
			if slot_index >= 0:
				_picked_stack = slot_index
				_show_stack(detail))
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		page.add_child(row)
		for index in range(Heroes.ARMY_SLOT_COUNT):
			var stack := _stack(index)
			var unit_id := String(stack.get("unit_id", ""))
			var count := int(stack.get("count", 0))
			var tile := _tile(Vector2(104.0, 132.0), UnitPortraits.bust_for_unit(unit_id) if unit_id != "" else null, null)
			tile.name = "ArmySlot%d" % index
			tile.set_meta("unit_id", unit_id)
			tile.set_meta("count", count)
			tile.disabled = unit_id == ""
			tile.tooltip_text = "%s · %d" % [String(ContentService.get_unit(unit_id).get("name", "Unit")), count] if unit_id != "" else "Empty slot"
			if unit_id != "":
				var number := _label(tile, str(count), 20, "body")
				number.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
				number.offset_top = -30.0
				number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				number.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tile.set_pressed_no_signal(index == _picked_stack)
				tile.pressed.connect(func():
					_picked_stack = index
					for other in row.get_children():
						if other is Button: other.set_pressed_no_signal(other == tile)
					_show_stack(detail))
				tile.mouse_entered.connect(func():
					_hover_stack = index
					_show_stack(detail))
				tile.mouse_exited.connect(func():
					_hover_stack = -1
					_show_stack(detail))
			row.add_child(tile)
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(detail)
	_hover_stack = -1
	if _stack(_picked_stack).is_empty():
		_picked_stack = -1
		for stack in hero.get("inspection_army_slots", []):
			_picked_stack = int(stack.get("slot_index", -1))
			break
	_show_stack(detail)
	for stack in hero.get("inspection_overflow_stacks", []):
		var unit := ContentService.get_unit(String(stack.get("unit_id", "")))
		_label(page, "Over the seven stacks: %s × %d" % [String(unit.get("name", "Unit")), int(stack.get("count", 0))], 13, "muted")

func _stack(slot_index: int) -> Dictionary:
	for stack in hero.get("inspection_army_slots", []):
		if int(stack.get("slot_index", -1)) == slot_index:
			return stack
	return {}

func _show_stack(detail: PanelContainer) -> void:
	if not is_instance_valid(detail):
		return
	_clear(detail)
	var stack := _stack(_hover_stack if _hover_stack >= 0 else _picked_stack)
	if stack.is_empty():
		_label(detail, "No troops in this army.", 15, "muted")
		return
	var unit := ContentService.get_unit(String(stack.get("unit_id", "")))
	var count := int(stack.get("count", 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	detail.add_child(row)
	var picture := _frame(UnitPortraits.for_unit(String(unit.get("id", "")), "portrait"), Vector2(150.0, 200.0), false)
	picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(picture)
	var text := VBoxContainer.new()
	text.name = "UnitDetails"
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 6)
	row.add_child(text)
	_label(text, "%s  × %d" % [String(unit.get("name", "Unit")), count], 22, "gold")
	var body: Dictionary = ContentService.load_json("res://content/unit_battle_size_manifest.json").get("units", {}).get(String(unit.get("id", "")), {})
	var width := 2 if int(body.get("footprint", 1)) == 2 else 1
	var facts := PackedStringArray(["Tier %d" % int(unit.get("tier", 1))])
	var role := String(unit.get("role", "")).capitalize()
	if role != "" and role not in ["Melee", "Ranged"]:
		facts.append(role)
	facts.append("Ranged, %d shots" % int(unit.get("shots", 0)) if bool(unit.get("ranged", false)) else "Melee")
	facts.append("%d hex%s" % [width, "es" if width == 2 else ""])
	_label(text, " · ".join(facts), 14, "muted")
	var numbers := HFlowContainer.new()
	numbers.add_theme_constant_override("h_separation", 8)
	numbers.add_theme_constant_override("v_separation", 6)
	text.add_child(numbers)
	for entry in [
		["Attack", str(int(unit.get("attack", 0)))], ["Defense", str(int(unit.get("defense", 0)))], ["Health", str(int(unit.get("hp", 0)))],
		["Damage", "%d–%d" % [int(unit.get("min_damage", 0)), int(unit.get("max_damage", 0))]], ["Speed", str(int(unit.get("speed", 0)))], ["Initiative", str(int(unit.get("initiative", 0)))],
	]:
		_chip(numbers, "%s %s" % [entry[0], entry[1]])
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	text.add_child(scroll)
	var abilities := VBoxContainer.new()
	abilities.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abilities.add_theme_constant_override("separation", 6)
	scroll.add_child(abilities)
	for ability in unit.get("abilities", []):
		if ability is Dictionary:
			var line := _label(abilities, "%s · %s" % [String(ability.get("name", "Ability")), String(ability.get("description", ""))], 14, "body")
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var note := _label(abilities, "Base values; the hero's command and the battlefield add to them in combat.", 12, "muted")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# --- Artifacts ------------------------------------------------------------------

func _build_artifacts(page: VBoxContainer) -> void:
	var equipped: Dictionary = hero.get("artifacts", {}).get("equipped", {})
	var inventory: Array = hero.get("artifacts", {}).get("inventory", [])
	# What was picked follows its artifact to wherever the order put it.
	if _picked_artifact != "":
		_picked_slot = ""
		for slot in Artifacts.EQUIPMENT_SLOTS:
			if String(equipped.get(slot, "")) == _picked_artifact:
				_picked_slot = String(slot)
		if _picked_slot == "" and _picked_artifact not in inventory:
			_picked_artifact = ""
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(row)
	var detail := _card()
	var tiles := {}

	var doll := Control.new()
	doll.name = "ArtifactFigure"
	doll.custom_minimum_size = DOLL_SIZE
	doll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(doll)
	var heading := _label(doll, "Artifacts", 22, "gold")
	heading.position = Vector2(0.0, 0.0)
	var figure := _picture(_icon("body"), false)
	figure.modulate = Color(1.0, 1.0, 1.0, 0.5)
	figure.position = DOLL_BODY.position
	figure.size = DOLL_BODY.size
	doll.add_child(figure)
	for slot in DOLL_SLOTS:
		var rect: Rect2 = DOLL_SLOTS[slot]
		var tile := _slot_tile(String(slot), String(equipped.get(slot, "")), rect.size)
		tile.position = rect.position
		tile.size = rect.size
		doll.add_child(tile)
		tiles[String(slot)] = tile

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(side)
	_label(side, "Trinkets", 16, "gold")
	var trinkets := GridContainer.new()
	trinkets.columns = 2
	trinkets.add_theme_constant_override("h_separation", 8)
	trinkets.add_theme_constant_override("v_separation", 8)
	side.add_child(trinkets)
	for slot in TRINKET_SLOTS:
		var tile := _slot_tile(slot, String(equipped.get(slot, "")), Vector2(64.0, 64.0))
		trinkets.add_child(tile)
		tiles[slot] = tile
	_build_artifact_sets(side)

	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)

	_hairline(page)
	var pack_row := HBoxContainer.new()
	pack_row.add_theme_constant_override("separation", 14)
	page.add_child(pack_row)
	var pack_caption := _label(pack_row, "Backpack", 16, "gold")
	pack_caption.custom_minimum_size.x = 86.0
	var pack_scroll := ScrollContainer.new()
	pack_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pack_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pack_scroll.custom_minimum_size.y = 66.0
	pack_scroll.follow_focus = true
	pack_row.add_child(pack_scroll)
	var pack := HBoxContainer.new()
	pack.add_theme_constant_override("separation", 8)
	pack_scroll.add_child(pack)
	var pack_tiles := {}
	for artifact_id_value in inventory:
		var artifact_id := String(artifact_id_value)
		var tile := _tile(Vector2(56.0, 56.0), _texture(Artifacts.artifact_icon_path(artifact_id)), null)
		_band_pip(tile, artifact_id)
		tile.name = "Pack_%s" % artifact_id
		tile.set_meta("artifact_id", artifact_id)
		tile.tooltip_text = _artifact_tooltip(artifact_id)
		pack.add_child(tile)
		pack_tiles[artifact_id] = tile
	var pack_drops: Array[Control] = [pack_scroll]
	for index in range(maxi(0, 10 - inventory.size())):
		var blank := _tile(Vector2(56.0, 56.0), null, null)
		blank.disabled = true
		blank.focus_mode = Control.FOCUS_NONE
		pack.add_child(blank)
		pack_drops.append(blank)

	var show := func():
		for slot in tiles:
			(tiles[slot] as Button).set_pressed_no_signal(slot == _picked_slot)
		# An empty slot rings what in the backpack would fit it.
		var wanted_kind := _slot_kind(_picked_slot) if _picked_slot != "" and _picked_artifact == "" else ""
		for artifact_id in pack_tiles:
			var pack_tile := pack_tiles[artifact_id] as Button
			pack_tile.set_pressed_no_signal(artifact_id == _picked_artifact and _picked_slot == "")
			pack_tile.modulate = Color(1.0, 1.0, 1.0, 1.0) if wanted_kind == "" or Artifacts.artifact_slot(artifact_id) == wanted_kind else Color(0.55, 0.55, 0.55, 0.8)
		_show_artifact(detail)
	_slot_tiles = tiles
	# The card reads what the mouse is over, and what is picked once it leaves.
	var read_picked := func(): _show_artifact(detail)
	for slot in tiles:
		var tile := tiles[slot] as Button
		var worn_id := String(equipped.get(slot, ""))
		tile.pressed.connect(func():
			_picked_slot = slot
			_picked_artifact = worn_id
			show.call())
		tile.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
				_request_artifact_order("unequip_artifact:%s" % slot))
		tile.mouse_entered.connect(func(): _show_artifact(detail, slot, worn_id))
		tile.mouse_exited.connect(read_picked)
		# Drag a worn artifact to another slot of its kind or to the backpack; a
		# slot takes what fits it, from the backpack or from another slot.
		tile.set_drag_forwarding(
			func(_at: Vector2): return _artifact_drag(tile, slot, worn_id),
			func(_at: Vector2, data: Variant): return _slot_takes(slot, data),
			func(_at: Vector2, data: Variant): _drop_on_slot(slot, data))
	for artifact_id in pack_tiles:
		var tile := pack_tiles[artifact_id] as Button
		tile.pressed.connect(func():
			_picked_slot = ""
			_picked_artifact = artifact_id
			show.call())
		tile.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
				_request_artifact_order("equip_artifact:%s" % artifact_id))
		tile.mouse_entered.connect(func(): _show_artifact(detail, "", artifact_id))
		tile.mouse_exited.connect(read_picked)
		pack_drops.append(tile)
	for target in pack_drops:
		var own_id := String(target.get_meta("artifact_id", ""))
		target.set_drag_forwarding(
			func(_at: Vector2): return _artifact_drag(target, "", own_id),
			func(_at: Vector2, data: Variant): return _pack_takes(data),
			func(_at: Vector2, data: Variant): _drop_on_pack(data))
	show.call()

func _can_order_artifacts() -> bool:
	return orders.has("artifact_actions")

func _artifact_drag(source: Control, slot: String, artifact_id: String) -> Variant:
	if artifact_id == "" or not _can_order_artifacts():
		return null
	var preview := _frame(_texture(Artifacts.artifact_icon_path(artifact_id)), Vector2(58.0, 58.0), false)
	preview.modulate = Color(1.0, 1.0, 1.0, 0.92)
	source.set_drag_preview(preview)
	_dragged_kind = Artifacts.artifact_slot(artifact_id)
	_mark_drop_slots()
	return {"type": DRAG_ARTIFACT, "artifact_id": artifact_id, "slot": slot}

func _slot_takes(slot: String, data: Variant) -> bool:
	return (
		data is Dictionary and String(data.get("type", "")) == DRAG_ARTIFACT and _can_order_artifacts()
		and String(data.get("slot", "")) != slot
		and Artifacts.artifact_slot(String(data.get("artifact_id", ""))) == _slot_kind(slot)
	)

func _drop_on_slot(slot: String, data: Variant) -> void:
	if not _slot_takes(slot, data):
		return
	_picked_artifact = String(data.artifact_id)
	_picked_slot = slot
	artifact_action_requested.emit("wear_artifact:%s:%s" % [slot, String(data.artifact_id)])

func _pack_takes(data: Variant) -> bool:
	return data is Dictionary and String(data.get("type", "")) == DRAG_ARTIFACT and _can_order_artifacts() and String(data.get("slot", "")) != ""

func _drop_on_pack(data: Variant) -> void:
	if not _pack_takes(data):
		return
	_picked_artifact = String(data.artifact_id)
	_picked_slot = ""
	artifact_action_requested.emit("unequip_artifact:%s" % String(data.slot))

## While an artifact is dragged the slots it fits stay lit and the rest dim.
func _mark_drop_slots() -> void:
	for slot in _slot_tiles:
		var tile = _slot_tiles[slot]
		if is_instance_valid(tile):
			(tile as Control).modulate = Color(1.0, 1.0, 1.0, 1.0) if _dragged_kind == "" or _slot_kind(String(slot)) == _dragged_kind else Color(0.45, 0.45, 0.45, 0.75)

## What an artifact gives and its story: the hover text of its tile.
func _artifact_tooltip(artifact_id: String) -> String:
	var artifact := ContentService.get_artifact(artifact_id)
	var ui: Dictionary = artifact.get("ui", {}) if artifact.get("ui", {}) is Dictionary else {}
	if ui.get("effect_lines", []) is Array and not (ui.get("effect_lines", []) as Array).is_empty():
		var lines := PackedStringArray([Artifacts.artifact_name(artifact_id), "%s · %s" % [String(KIND_NAMES.get(Artifacts.artifact_slot(artifact_id), "item")).capitalize(), String(artifact.get("rarity", "common")).capitalize()]])
		lines.append_array(PackedStringArray(ui.effect_lines))
		for price in ui.get("price_lines", []):
			lines.append("Price: %s" % String(price))
		if _is_home(artifact):
			lines.append("At home: %s" % "; ".join(PackedStringArray(ui.get("home_lines", []))))
		if bool(ui.get("special_live", false)):
			lines.append(String(ui.get("special_text", "")))
		var artifact_set := _artifact_set(String(artifact.get("set_id", "")))
		if not artifact_set.is_empty():
			lines.append("Set: %s" % String(artifact_set.get("name", "")))
		return "\n".join(lines)
	var parts := Artifacts.describe_artifact(artifact_id).split(" | ")
	if parts.size() >= 4:
		return "%s\n%s\n%s" % [Artifacts.artifact_name(artifact_id), parts[parts.size() - 1], parts[parts.size() - 2]]
	return "%s\n%s" % [Artifacts.artifact_name(artifact_id), Artifacts.describe_artifact_short(artifact_id)]

func _slot_kind(slot: String) -> String:
	for kind in Artifacts.SLOTS_BY_KIND:
		if slot in Artifacts.SLOTS_BY_KIND[kind]:
			return String(kind)
	return ""

## A worn slot: the artifact in it, or the outline of what it takes.
func _slot_tile(slot: String, artifact_id: String, tile_size: Vector2) -> Button:
	var ghost := _icon("slot_" + _slot_kind(slot))
	var tile := _tile(tile_size, _texture(Artifacts.artifact_icon_path(artifact_id)) if artifact_id != "" else null, ghost if artifact_id == "" else null)
	if artifact_id != "":
		_band_pip(tile, artifact_id)
	tile.name = "Slot_%s" % slot
	tile.set_meta("slot", slot)
	tile.set_meta("artifact_id", artifact_id)
	var slot_name := String(SLOT_NAMES.get(slot, slot.capitalize()))
	tile.tooltip_text = "%s: %s" % [slot_name, _artifact_tooltip(artifact_id)] if artifact_id != "" else "%s: empty. Takes a %s." % [slot_name, String(KIND_NAMES.get(_slot_kind(slot), "trinket"))]
	tile.accessibility_name = tile.tooltip_text
	return tile

func _request_artifact_order(order_id: String) -> void:
	var order := _action("artifact_actions", order_id)
	if not order.is_empty() and not bool(order.get("disabled", false)):
		artifact_action_requested.emit(order_id)

## The card of the artifact page: the hovered slot or item when one is given,
## else what is picked.
func _show_artifact(detail: PanelContainer, hovered_slot: String = "?", hovered_artifact: String = "") -> void:
	if not is_instance_valid(detail):
		return
	var hovering := hovered_slot != "?"
	var at_slot := hovered_slot if hovering else _picked_slot
	var item_id := hovered_artifact if hovering else _picked_artifact
	_clear(detail)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	detail.add_child(column)
	var equipped: Dictionary = hero.get("artifacts", {}).get("equipped", {})
	if item_id == "":
		if at_slot != "":
			_label(column, String(SLOT_NAMES.get(at_slot, "Slot")), 20, "gold")
			var kind := _slot_kind(at_slot)
			var fitting := 0
			for artifact_id in hero.get("artifacts", {}).get("inventory", []):
				if Artifacts.artifact_slot(String(artifact_id)) == kind: fitting += 1
			var note := _label(column, "Empty. It takes a %s.\n%s" % [String(KIND_NAMES.get(kind, "trinket")), "%d in the backpack fit%s: pick one to wear it." % [fitting, "s" if fitting == 1 else ""] if fitting > 0 else "Nothing in the backpack fits it."], 14, "body")
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			return
		var worn := 0
		for slot in Artifacts.EQUIPMENT_SLOTS:
			if String(equipped.get(slot, "")) != "": worn += 1
		_label(column, "%d worn · %d carried" % [worn, (hero.get("artifacts", {}).get("inventory", []) as Array).size()], 18, "gold")
		var summary := _label(column, Artifacts.describe_impact_summary(hero.duplicate(true)), 14, "body")
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var hint := _label(column, "Point at a slot or an item to read it%s." % (". Drag it to wear, move or stow it; a double click or its button does the same" if _can_order_artifacts() else ""), 13, "muted")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	var artifact := ContentService.get_artifact(item_id)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	column.add_child(head)
	head.add_child(_frame(_texture(Artifacts.artifact_icon_path(item_id)), Vector2(84.0, 84.0), false))
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	head.add_child(titles)
	var title := _label(titles, Artifacts.artifact_name(item_id), 19, "gold")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var band := _label(titles, "%s · %s" % [String(KIND_NAMES.get(Artifacts.artifact_slot(item_id), "item")).capitalize(), String(artifact.get("rarity", "common")).capitalize()], 13, "muted")
	band.add_theme_color_override("font_color", BAND_COLORS.get(String(artifact.get("rarity", "")), Visuals.text_color("muted")))
	_label(titles, "Worn: %s" % String(SLOT_NAMES.get(at_slot, "")) if at_slot != "" else "In the backpack", 13, "body")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var lines := VBoxContainer.new()
	lines.name = "ArtifactDetails"
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", 8)
	scroll.add_child(lines)
	var ui: Dictionary = artifact.get("ui", {}) if artifact.get("ui", {}) is Dictionary else {}
	# The rules' line reads "name | rarity and family | roles | story | what it gives".
	var parts := Artifacts.describe_artifact(item_id).split(" | ")
	if ui.get("effect_lines", []) is Array and not (ui.get("effect_lines", []) as Array).is_empty():
		_show_artifact_lines(lines, artifact, ui)
	elif parts.size() >= 4:
		_wrapped(lines, parts[parts.size() - 1], 15, "gold")
		_wrapped(lines, parts[parts.size() - 2], 14, "body")
		_wrapped(lines, " · ".join(parts.slice(1, parts.size() - 2)), 12, "muted")
	else:
		_wrapped(lines, " | ".join(parts), 14, "body")
	# For an item in the backpack: what wearing it would change.
	if at_slot == "":
		_wrapped(lines, DecisionDetails.artifact_comparison(hero, item_id), 13, "muted")
	# Its story comes last: the lines a choice is made on stay above it.
	if not ui.get("effect_lines", []).is_empty() and String(artifact.get("description", "")) != "":
		_wrapped(lines, String(artifact.get("description", "")), 13, "muted").name = "ArtifactStory"
	var order_id := "unequip_artifact:%s" % at_slot if at_slot != "" else "equip_artifact:%s" % item_id
	var order := _action("artifact_actions", order_id)
	# The button belongs to what is picked; a hovered item only reads.
	if hovering and (item_id != _picked_artifact or at_slot != _picked_slot):
		if _can_order_artifacts():
			_wrapped(column, "Drag it, or click to pick it.", 12, "muted")
	elif not order.is_empty():
		var label := String(order.get("label", ""))
		var verb := "Stow" if at_slot != "" else ("Swap in" if label.begins_with("Swap In") else "Wear")
		var order_button := _button(column, verb, String(order.get("summary", label)), "primary", Vector2(150.0, 36.0))
		order_button.name = "ArtifactOrder_%s" % order_id.replace(":", "_")
		order_button.accessibility_name = label
		order_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		order_button.disabled = bool(order.get("disabled", false))
		order_button.pressed.connect(func(): artifact_action_requested.emit(order_id))
	elif not is_interactive():
		var note := _label(column, "Artifacts are worn and stowed from the hero menu on the map.", 12, "muted")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

## What an artifact gives, line by line: its bonuses, its price in red, its
## home line (green for a hero of its faction), a special effect that is in the
## game, its set and how far the hero is with it. Its story follows in _show_artifact.
func _show_artifact_lines(lines: VBoxContainer, artifact: Dictionary, ui: Dictionary) -> void:
	_wrapped(lines, "\n".join(PackedStringArray(ui.effect_lines)), 15, "gold").name = "ArtifactGives"
	for price in ui.get("price_lines", []):
		_wrapped(lines, "Price: %s" % String(price), 14, "red").name = "ArtifactPrice"
	if ui.get("home_lines", []) is Array and not (ui.get("home_lines", []) as Array).is_empty():
		var factions: Array = artifact.get("faction_affinity", [])
		var faction_name := String(ContentService.get_faction(String(factions[0])).get("name", "Its faction")) if not factions.is_empty() else "Its faction"
		var at_home := _is_home(artifact)
		_wrapped(lines, "%s: %s" % ["At home with this hero" if at_home else "For heroes of the %s" % faction_name, "; ".join(PackedStringArray(ui.home_lines))], 14, "green" if at_home else "muted").name = "ArtifactHome"
	if bool(ui.get("special_live", false)):
		_wrapped(lines, String(ui.get("special_text", "")), 14, "body").name = "ArtifactSpecial"
	var artifact_set := _artifact_set(String(artifact.get("set_id", "")))
	if not artifact_set.is_empty():
		var worn := _set_pieces_worn(artifact_set)
		var pieces: Array = artifact_set.get("piece_ids", [])
		_wrapped(lines, "%s · %d of %d worn" % [String(artifact_set.get("name", "Set")), worn, pieces.size()], 14, "green" if worn >= pieces.size() else "gold").name = "ArtifactSet"
		var steps := _set_steps_text(artifact_set, worn)
		if steps != "":
			_wrapped(lines, steps, 13, "muted")

## A dot in the artifact's band colour, in the tile's corner.
func _band_pip(tile: Button, artifact_id: String) -> void:
	var color: Color = BAND_COLORS.get(String(ContentService.get_artifact(artifact_id).get("rarity", "")), Color(0, 0, 0, 0))
	if color.a <= 0.0:
		return
	var pip := Panel.new()
	pip.name = "BandPip"
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.add_theme_stylebox_override("panel", _box(Color(0.05, 0.04, 0.03), 1, 5, color))
	pip.position = Vector2(4.0, 4.0)
	pip.size = Vector2(10.0, 10.0)
	tile.add_child(pip)

## Whether the hero's faction is the artifact's own.
func _is_home(artifact: Dictionary) -> bool:
	var factions: Array = artifact.get("faction_affinity", []) if artifact.get("faction_affinity", []) is Array else []
	if factions.is_empty() or not artifact.has("home_bonuses"):
		return false
	var faction_id := String(hero.get("faction_id", ""))
	if faction_id == "":
		faction_id = String(Heroes.hero_template(hero).get("faction_id", ""))
	return faction_id != "" and faction_id in factions

## A set's row in the artifact content, or {}.
func _artifact_set(set_id: String) -> Dictionary:
	if set_id == "":
		return {}
	for artifact_set in ContentService.load_json(ContentService.ARTIFACTS_PATH).get("sets", []):
		if artifact_set is Dictionary and String(artifact_set.get("id", "")) == set_id:
			return artifact_set
	return {}

func _set_pieces_worn(artifact_set: Dictionary) -> int:
	var equipped: Dictionary = hero.get("artifacts", {}).get("equipped", {})
	var worn := 0
	for piece_id in artifact_set.get("piece_ids", []):
		if String(piece_id) in equipped.values():
			worn += 1
	return worn

## A set's steps, one a line; the ones the hero has reached are ticked.
func _set_steps_text(artifact_set: Dictionary, worn: int) -> String:
	var steps := PackedStringArray()
	for step in artifact_set.get("piece_thresholds", []):
		steps.append("%s %d pieces: %s" % ["✓" if worn >= int(step.get("count", 0)) else "·", int(step.get("count", 0)), String(step.get("summary", ""))])
	return "\n".join(steps)

## One row per artifact set the hero wears pieces of: its name and how many.
func _build_artifact_sets(box: VBoxContainer) -> void:
	for set_state in Artifacts.artifact_set_runtime_state(hero):
		if not (set_state is Dictionary): continue
		var texture := _insignia_texture(set_state.insignia) if set_state.get("insignia", {}) is Dictionary else null
		if texture == null:
			var artifact_set := _artifact_set(String(set_state.get("set_id", "")))
			var worn := int(set_state.get("equipped_piece_count", 0))
			var line := _label(box, "%s %d/%d" % [String(set_state.get("name", "Set")), worn, int(set_state.get("piece_count", 0))], 13, "green" if bool(set_state.get("complete", false)) else "gold")
			line.name = "ArtifactSet_%s" % String(set_state.get("set_id", "set"))
			line.custom_minimum_size.x = 136.0
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.mouse_filter = Control.MOUSE_FILTER_STOP
			line.tooltip_text = "%s\n%s" % [String(artifact_set.get("identity", "")), _set_steps_text(artifact_set, worn)]
			continue
		var row := HBoxContainer.new()
		row.name = "ArtifactSetInsignia_%s" % String(set_state.get("set_id", "set"))
		row.set_meta("artifact_set_id", String(set_state.get("set_id", "")))
		row.set_meta("artifact_set_complete", bool(set_state.get("complete", false)))
		row.tooltip_text = "%s\n%s" % [String(set_state.get("name", "Artifact Set")), String(set_state.insignia.get("alt_text", ""))]
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		var glyph := _picture(texture, false)
		glyph.name = "SetInsignia"
		glyph.custom_minimum_size = Vector2(28.0, 28.0)
		row.add_child(glyph)
		var progress := _label(row, "%d/%d" % [int(set_state.get("equipped_piece_count", 0)), int(set_state.get("piece_count", 0))], 14, "green" if bool(set_state.get("complete", false)) else "gold")
		progress.name = "SetProgress"
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _insignia_texture(insignia: Dictionary) -> Texture2D:
	var region: Dictionary = insignia.get("atlas_region", {}) if insignia.get("atlas_region", {}) is Dictionary else {}
	var atlas := _texture(String(insignia.get("atlas_path", "")).strip_edges())
	if atlas == null or region.is_empty(): return null
	var rect := Rect2(float(region.get("x", -1)), float(region.get("y", -1)), float(region.get("width", 0)), float(region.get("height", 0)))
	if rect.position.x < 0.0 or rect.position.y < 0.0 or not rect.has_area() or not Rect2(Vector2.ZERO, atlas.get_size()).encloses(rect): return null
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = rect
	return texture

# --- Specialties ----------------------------------------------------------------

func _build_specialties(page: VBoxContainer) -> void:
	_label(page, "Specialties", 22, "gold")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	page.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	var pending := Progression.pending_choices_remaining(hero)
	if pending > 0:
		var choice_card := _card()
		box.add_child(choice_card)
		var choices_box := VBoxContainer.new()
		choices_box.add_theme_constant_override("separation", 8)
		choice_card.add_child(choices_box)
		_label(choices_box, "%d choice%s to make" % [pending, "" if pending == 1 else "s"], 17, "gold")
		var choices: Array = orders.get("specialty_actions", [])
		if choices.is_empty():
			var waiting := _label(choices_box, "Choose from the hero menu on the map.\n" + Progression.pending_choice_summary(Progression.current_pending_choice(hero)), 14, "body")
			waiting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		for choice in choices:
			var action_id := String(choice.get("id", ""))
			var specialty_id := Progression.specialty_id_for_action(action_id)
			var tooltip := String(choice.get("summary", ""))
			var insignia := Progression.specialty_insignia_description(specialty_id)
			if insignia != "": tooltip += "\nInsignia: " + insignia
			var choose := _button(choices_box, String(choice.get("label", "Choose specialty")), tooltip, "secondary", Vector2(0.0, 46.0))
			choose.name = "Specialty_%s" % action_id.replace(":", "_")
			choose.alignment = HORIZONTAL_ALIGNMENT_LEFT
			choose.disabled = bool(choice.get("disabled", false))
			choose.icon = Progression.specialty_insignia_texture(specialty_id)
			choose.expand_icon = true
			choose.add_theme_constant_override("icon_max_width", 34)
			choose.pressed.connect(func(): specialty_requested.emit(action_id))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	var learned := 0
	for specialty in Progression.specialties():
		var specialty_id := String(specialty.id)
		var rank := Progression.specialty_rank(hero, specialty_id)
		if rank <= 0: continue
		learned += 1
		var card := _card()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var glyph := _picture(Progression.specialty_insignia_texture(specialty_id), false)
		glyph.custom_minimum_size = Vector2(52.0, 52.0)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(glyph)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 2)
		row.add_child(text)
		_label(text, "%s · %s" % [String(specialty.name), Progression.rank_label(rank)], 17, "gold")
		var gives := _label(text, Progression.rank_text(specialty_id, rank), 14, "body")
		gives.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if learned == 0:
		_label(box, "No specialties learned yet.", 15, "muted")
	var template := Heroes.hero_template(hero)
	var lines := PackedStringArray()
	if String(template.get("identity_summary", "")) != "":
		lines.append(String(template.get("identity_summary", "")))
	var home_terrains: Array = ContentService.get_faction(String(template.get("faction_id", ""))).get("home_terrain_ids", [])
	if not home_terrains.is_empty():
		lines.append("Home ground: %s %s the hero's army no more than grass." % [_terrain_names(home_terrains), "costs" if home_terrains.size() == 1 else "cost"])
	var focus := Progression.summarize_specialty_ids(template.get("specialty_focus_ids", []))
	if focus != "":
		lines.append("Leans toward (not learned yet): " + focus)
	if not lines.is_empty():
		var about := _label(box, "\n".join(lines), 13, "muted")
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# "sand", "swamp and mire"; three or more as "snow, frost and ice".
func _terrain_names(terrain_ids: Array) -> String:
	var names := ""
	for index in range(terrain_ids.size()):
		if index > 0: names += " and " if index == terrain_ids.size() - 1 else ", "
		names += String(terrain_ids[index])
	return names

# --- Spells -----------------------------------------------------------------------

## The spell page is the open spell book (SpellGrimoire): every spell the hero
## knows, battle or map; a map spell is cast from its page.
func _build_spells(page: VBoxContainer) -> void:
	var book: TextureRect = SpellGrimoireScript.new()
	book.name = "SpellBook"
	book.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(book)
	# What the map lets the hero cast now, and why not.
	var availability := {}
	for action in orders.get("spell_actions", []):
		var action_id := String(action.get("id", ""))
		if not action_id.begins_with("cast_spell:"):
			continue
		var spell_id := action_id.trim_prefix("cast_spell:")
		if String(ContentService.get_spell(spell_id).get("context", "")) != "overworld":
			continue
		var reason := String(action.get("invalid_reason", ""))
		availability[spell_id] = {
			"enabled": not bool(action.get("disabled", false)),
			"message": reason if reason != "" else String(action.get("readiness", "")),
		}
	book.cast_requested.connect(func(spell_id: String): spell_cast_requested.emit(spell_id))
	book.show_book({
		"hero": hero,
		"spells": Spells.known_spells(hero),
		"availability": availability,
		"notes": {"battle": "Cast in battle, from the battle's spell book.", "overworld": "Cast from the hero menu on the map."},
		"empty_text": "No spell is written here yet. A town of yours with spell archives teaches its visitors.",
		"view": _spell_view,
	})

# --- Pieces -------------------------------------------------------------------------

func _action(list_key: String, action_id: String) -> Dictionary:
	for action in orders.get(list_key, []):
		if action is Dictionary and String(action.get("id", "")) == action_id: return action
	return {}

## A square picture button: a gold ring when chosen. `ghost` is the faint outline
## an empty one shows.
func _tile(tile_size: Vector2, texture: Texture2D, ghost: Texture2D) -> Button:
	var tile := Button.new()
	tile.toggle_mode = true
	tile.custom_minimum_size = tile_size
	tile.focus_mode = Control.FOCUS_ALL
	tile.clip_contents = true
	tile.add_theme_stylebox_override("normal", _box(GOLD_DIM, 1, 5, TILE_FILL))
	tile.add_theme_stylebox_override("disabled", _box(Color(0.33, 0.27, 0.17), 1, 5, Color(0.05, 0.042, 0.035, 0.9)))
	tile.add_theme_stylebox_override("hover", _box(GOLD, 1, 5, TILE_HOVER))
	for state in ["pressed", "hover_pressed"]:
		tile.add_theme_stylebox_override(state, _box(GOLD, 3, 5, TILE_HOVER))
	tile.add_theme_stylebox_override("focus", _box(GOLD_BRIGHT, 2, 5, Color(0, 0, 0, 0)))
	if texture != null or ghost != null:
		var picture := _picture(texture if texture != null else ghost, false)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4 if texture != null else 10)
		if texture == null:
			picture.modulate = Color(1.0, 1.0, 1.0, 0.5)
		tile.add_child(picture)
	return tile

## A framed picture that is not a button.
func _frame(texture: Texture2D, frame_size: Vector2, cover: bool) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = frame_size
	frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style := _box(Color(0.76, 0.60, 0.30), 1, 5, Color(0.16, 0.14, 0.115))
	style.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel", style)
	frame.add_child(_picture(texture, cover))
	return frame

func _card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	return card

func _card_style() -> StyleBoxFlat:
	var style := _box(GOLD_DIM, 1, 6, CARD_FILL)
	style.set_content_margin_all(12)
	return style

func _chip(parent: Node, text: String) -> void:
	var chip := PanelContainer.new()
	var style := _box(GOLD_DIM, 1, 7, TILE_FILL)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	chip.add_theme_stylebox_override("panel", style)
	_label(chip, text, 14, "body")
	parent.add_child(chip)

func _box(border: Color, width: int, radius: int, fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style

func _hairline(parent: Node) -> void:
	var line := ColorRect.new()
	line.color = HAIRLINE
	line.custom_minimum_size.y = 1.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

func _picture(texture: Texture2D, cover: bool) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture

func _label(parent: Node, text: String, font_size: int, tone: String = "body") -> Label:
	var label := Label.new()
	label.text = text
	Visuals.apply_label(label, tone, font_size)
	parent.add_child(label)
	return label

func _wrapped(parent: Node, text: String, font_size: int, tone: String) -> Label:
	var label := _label(parent, text, font_size, tone)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(parent: Node, text: String, tooltip: String, role: String, minimum: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.accessibility_name = tooltip
	button.focus_mode = Control.FOCUS_ALL
	Visuals.apply_button(button, role, minimum.x, minimum.y, 15)
	parent.add_child(button)
	return button

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _icon(icon_name: String) -> Texture2D:
	return _texture(ICON_PATH % icon_name)

func _texture(path: String) -> Texture2D:
	return ResourceLoader.load(path, "Texture2D") as Texture2D if path != "" and ResourceLoader.exists(path, "Texture2D") else null
