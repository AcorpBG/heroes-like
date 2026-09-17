extends VBoxContainer
## Shared, read-only spell catalogue. Only the owning screen can issue orders.

signal spell_requested(spell_id: String)
signal controls_changed

const Spells = preload("res://scripts/core/SpellRules.gd")
const Visuals = preload("res://scripts/ui/FrontierVisualKit.gd")
const CONTEXTS := ["", "battle", "overworld"]
const ROLES := ["", "damage", "buff", "debuff"]

var _hero: Dictionary = {}
var _spells: Array = []
var _availability: Dictionary = {}
var _mode := "inspect"
var _selected_id := ""
var _context: OptionButton
var _role: OptionButton
var _count: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _details: RichTextLabel
var _prepare: Button
var _empty: Label

func _ready() -> void:
	name = "Spellbook"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 12)
	add_child(filters)
	_context = _filter(filters, "SpellContext", "Spell context", ["All spells", "Battle spells", "Overworld spells"])
	_role = _filter(filters, "SpellRole", "Spell effect", ["All effects", "Damage", "Buff", "Debuff"])
	_context.item_selected.connect(func(_index: int): _rebuild())
	_role.item_selected.connect(func(_index: int): _rebuild())
	_count = Label.new()
	Visuals.apply_label(_count, "gold", 15)
	add_child(_count)
	_scroll = ScrollContainer.new()
	_scroll.name = "SpellPages"
	_scroll.custom_minimum_size.y = 180
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_scroll.add_child(_grid)
	_empty = Label.new()
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Visuals.apply_label(_empty, "body", 17)
	add_child(_empty)
	_details = RichTextLabel.new()
	_details.name = "SpellDescription"
	_details.custom_minimum_size.y = 92
	_details.add_theme_font_size_override("normal_font_size", 16)
	_details.add_theme_color_override("default_color", Color("e4d8bd"))
	_details.focus_mode = Control.FOCUS_ALL
	_details.accessibility_name = "Selected spell description"
	add_child(_details)
	_prepare = Button.new()
	_prepare.name = "PrepareSpell"
	_prepare.text = "Prepare spell"
	_prepare.accessibility_name = "Prepare selected spell; choose and confirm a battlefield target next"
	Visuals.apply_button(_prepare, "primary", 160, 38, 17)
	_prepare.pressed.connect(func():
		if not _prepare.disabled and _selected_id != "": spell_requested.emit(_selected_id))
	add_child(_prepare)
	resized.connect(_layout_columns)
	_rebuild()

func _filter(parent: Control, control_name: String, label: String, options: Array) -> OptionButton:
	var filter := OptionButton.new()
	filter.name = control_name
	filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter.accessibility_name = label
	filter.tooltip_text = label + "; combines with the other filter. All effects includes utility, healing and control."
	for option in options: filter.add_item(option)
	Visuals.apply_button(filter, "secondary", 160, 38, 16)
	parent.add_child(filter)
	return filter

func configure(hero: Dictionary, spell_ids: Array, mode: String = "inspect", availability: Dictionary = {}) -> void:
	_hero = hero.duplicate(true)
	_mode = mode
	_availability = availability.duplicate(true)
	_spells.clear()
	var seen := {}
	for spell_id in spell_ids:
		var spell := ContentService.get_spell(String(spell_id))
		if spell.is_empty() or seen.has(spell_id): continue
		seen[spell_id] = true
		_spells.append(spell)
	_spells.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	if is_node_ready():
		_context.select(1 if mode == "battle" else 0)
		_role.select(0)
		_rebuild()

func visible_spell_ids() -> Array:
	var ids := []
	for spell in _spells:
		if _context != null and CONTEXTS[_context.selected] != "" and String(spell.get("context", "")) != CONTEXTS[_context.selected]: continue
		if _role != null and ROLES[_role.selected] != "" and ROLES[_role.selected] not in Spells.spell_role_categories(spell): continue
		ids.append(String(spell.id))
	return ids

func focus_controls() -> Array[Control]:
	var controls: Array[Control] = [_context, _role]
	for child in _grid.get_children():
		if child is Button: controls.append(child)
	controls.append(_details)
	if _prepare.visible and not _prepare.disabled: controls.append(_prepare)
	return controls

func _layout_columns() -> void:
	if _grid != null: _grid.columns = maxi(1, mini(4, int((_scroll.size.x - 16.0) / 238.0)))

func _rebuild() -> void:
	if _grid == null: return
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var ids := visible_spell_ids()
	_scroll.scroll_vertical = 0
	for spell_id in ids:
		var spell := ContentService.get_spell(spell_id)
		var button := Button.new()
		button.name = spell_id
		button.set_meta("spell_id", spell_id)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s\n%d mana · %s" % [String(spell.name), Spells.adjusted_spell_mana_cost(_hero, spell), String(spell.get("context", "")).capitalize()]
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = true
		var icon_path := Spells.spell_icon_path(spell_id)
		button.icon = load(icon_path) as Texture2D if icon_path != "" else null
		Visuals.apply_button(button, "secondary", 222, 76, 16)
		button.add_theme_constant_override("icon_max_width", 48)
		button.add_theme_constant_override("h_separation", 12)
		button.tooltip_text = _description(spell)
		button.accessibility_name = "%s, %s, %d mana" % [String(spell.name), String(spell.get("context", "")), Spells.adjusted_spell_mana_cost(_hero, spell)]
		button.accessibility_description = button.tooltip_text
		button.pressed.connect(_select.bind(spell_id))
		button.focus_entered.connect(_select.bind(spell_id))
		_grid.add_child(button)
	_count.text = "%d / %d spells%s" % [ids.size(), _spells.size(), " · Mana %d / %d" % [int(_hero.get("spellbook", {}).get("mana", {}).get("current", 0)), int(_hero.get("spellbook", {}).get("mana", {}).get("max", 0))] if not _hero.is_empty() else " · Town archives"]
	_empty.visible = ids.is_empty()
	_empty.text = "No spells match these filters." if not _spells.is_empty() else ("Build the town's spell archives to unlock its library. Visiting heroes learn available spells automatically." if _mode == "town" else "This hero has not learned any spells. Visit an owned town with spell archives.")
	_scroll.visible = not ids.is_empty()
	_prepare.visible = _mode == "battle"
	_selected_id = _selected_id if _selected_id in ids else (String(ids[0]) if not ids.is_empty() else "")
	_select(_selected_id)
	_layout_columns()
	controls_changed.emit()

func _description(spell: Dictionary) -> String:
	# Actual effect comes first so the bounded hover card describes what it does,
	# rather than truncating after name/cost or showing only flavour text.
	return "%s — %s\n%s\n%s · Tier %d · %d mana" % [String(spell.get("name", "Spell")), Spells._spell_effect_summary(spell, _hero), String(spell.get("description", "")), Spells.spell_category_label(spell), int(spell.get("tier", 1)), Spells.adjusted_spell_mana_cost(_hero, spell)]

func _select(spell_id: String) -> void:
	_selected_id = spell_id
	var spell := ContentService.get_spell(spell_id) if spell_id != "" else {}
	var state: Dictionary = _availability.get(spell_id, {})
	_details.text = _description(spell) if not spell.is_empty() else ""
	if not state.is_empty(): _details.text += "\n" + String(state.get("message", ""))
	var was_disabled := _prepare.disabled
	_prepare.disabled = not bool(state.get("enabled", false)) or spell_id == ""
	_prepare.tooltip_text = String(state.get("message", "Select a learned battle spell with a legal target."))
	for button in _grid.get_children():
		button.self_modulate = Color("ffe3a1") if String(button.get_meta("spell_id", "")) == spell_id else Color.WHITE
	if was_disabled != _prepare.disabled: controls_changed.emit()
