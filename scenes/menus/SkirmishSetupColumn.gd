extends VBoxContainer
## The new skirmish's setup, as one column (docs/skirmish-setup-screen.md):
## faction crests, the faction's heroes, the chosen hero's card, the map's
## settings as rows of pills, and the launch buttons. A view only: the main menu
## hands it the state (show_setup) and acts on its signals.

signal option_chosen(group: String, id: String)
signal seed_changed(text: String)
signal build_requested
signal built_maps_requested
signal back_requested

const VisualKit := preload("res://scripts/ui/FrontierVisualKit.gd")
const UnitPortraits := preload("res://scripts/ui/UnitPortraitTexture.gd")
const Progression := preload("res://scripts/core/HeroProgressionRules.gd")
const Spells := preload("res://scripts/core/SpellRules.gd")
const HeroCommand := preload("res://scripts/core/HeroCommandRules.gd")

const RANDOM_ID := "random"
const CREST_SIZE := 52.0
const THUMB_SIZE := Vector2(48.0, 60.0)
## The portrait keeps this size for every hero, and so does the card: the tallest
## text (a magic hero: two specialties) is as high as the portrait.
const PORTRAIT_SIZE := Vector2(249.0, 332.0)
const ROW_LABEL_WIDTH := 88.0
const PILL_HEIGHT := 27.0
const GOLD := Color(0.84, 0.67, 0.31)
const GOLD_DIM := Color(0.55, 0.44, 0.24)
const PILL_FILL := Color(0.10, 0.085, 0.07, 0.92)
const PILL_HOVER := Color(0.17, 0.14, 0.10, 0.96)
const INK := Color(0.11, 0.08, 0.04)
const HAIRLINE := Color(0.83, 0.68, 0.36, 0.45)
const TILE_BACKING := Color(0.30, 0.27, 0.23)

var _state := {}
var _faction_row: HBoxContainer
var _faction_name: Label
var _hero_row: HBoxContainer
var _hero_card: HBoxContainer
var _map_status: Label
var _rows_box: VBoxContainer
var _rows := {}
var _seed_edit: LineEdit
var _seed_line: Control
var _progress: ProgressBar
var _build_button: Button
var _built_maps_button: Button
var _back_button: Button
var _faction_ids: Array = []
var _hero_ids: Array = []
var _card_hero_id := "-"

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_label(self, "New skirmish", "gold", 26)

	# Between the title and the launch buttons the setup scrolls when the screen
	# is too low for it (a small window, a larger interface scale).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)

	var faction_head := HBoxContainer.new()
	faction_head.add_theme_constant_override("separation", 8)
	content.add_child(faction_head)
	_label(faction_head, "FACTION", "muted", 12)
	_faction_name = _label(faction_head, "", "body", 13)
	_faction_row = HBoxContainer.new()
	_faction_row.add_theme_constant_override("separation", 10)
	content.add_child(_faction_row)

	_label(content, "HERO", "muted", 12)
	_hero_row = HBoxContainer.new()
	_hero_row.add_theme_constant_override("separation", 6)
	_hero_row.custom_minimum_size.y = THUMB_SIZE.y
	content.add_child(_hero_row)

	_hero_card = HBoxContainer.new()
	_hero_card.add_theme_constant_override("separation", 14)
	_hero_card.custom_minimum_size.y = PORTRAIT_SIZE.y
	content.add_child(_hero_card)

	_hairline(content)
	var map_head := HBoxContainer.new()
	content.add_child(map_head)
	_label(map_head, "The map", "gold", 18)
	_map_status = _label(map_head, "", "muted", 12)
	_map_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_map_status.clip_text = true
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 5)
	content.add_child(_rows_box)

	var seed_row := _row_shell("Seed")
	_seed_line = seed_row.get_parent()
	_seed_edit = LineEdit.new()
	_seed_edit.name = "SetupSeed"
	_seed_edit.placeholder_text = "Auto"
	_seed_edit.custom_minimum_size = Vector2(200.0, PILL_HEIGHT)
	_seed_edit.add_theme_font_size_override("font_size", 13)
	_seed_edit.tooltip_text = "Leave empty for a fresh map each time, or type a seed to build the same map again."
	_seed_edit.text_changed.connect(func(text: String): seed_changed.emit(text))
	seed_row.add_child(_seed_edit)
	var roll := _pill("Roll", false)
	roll.tooltip_text = "Write a random seed here, so this exact map can be built again."
	roll.pressed.connect(_roll_seed)
	seed_row.add_child(roll)

	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 6.0
	_progress.show_percentage = false
	_progress.visible = false
	add_child(_progress)
	var launch := HBoxContainer.new()
	launch.add_theme_constant_override("separation", 10)
	add_child(launch)
	_build_button = Button.new()
	_build_button.name = "SetupBuild"
	_build_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	VisualKit.apply_button(_build_button, "primary", 280, 44, 18)
	_build_button.pressed.connect(func(): build_requested.emit())
	launch.add_child(_build_button)
	_built_maps_button = Button.new()
	_built_maps_button.name = "SetupBuiltMaps"
	_built_maps_button.text = "Built maps"
	VisualKit.apply_button(_built_maps_button, "secondary", 110, 44, 14)
	_built_maps_button.pressed.connect(func(): built_maps_requested.emit())
	launch.add_child(_built_maps_button)
	_back_button = Button.new()
	_back_button.name = "SetupBack"
	_back_button.text = "Back"
	VisualKit.apply_button(_back_button, "secondary", 90, 44, 14)
	_back_button.tooltip_text = "Return to the main menu."
	_back_button.pressed.connect(func(): back_requested.emit())
	launch.add_child(_back_button)

## The control a newly opened setup focuses.
func entry_control() -> Control:
	return _build_button

## state: factions and heroes ([{id, label}]) with faction_id and hero_id; rows
## ([{key, label, options: [{id, label, tooltip}], selected}]); seed; status;
## build_label, build_disabled, build_tooltip; busy; progress (-1 for none);
## built_maps (how many earlier maps there are).
func show_setup(state: Dictionary) -> void:
	_state = state
	var busy := bool(state.get("busy", false))
	_sync_factions(state.get("factions", []), String(state.get("faction_id", "")), busy)
	_sync_heroes(state.get("heroes", []), String(state.get("hero_id", "")), busy)
	_sync_hero_card(String(state.get("faction_id", "")), String(state.get("hero_id", "")))
	for row in state.get("rows", []):
		_sync_row(row, busy)
	if _seed_edit.text != String(state.get("seed", "")) and not _seed_edit.has_focus():
		_seed_edit.text = String(state.get("seed", ""))
	_seed_edit.editable = not busy
	_map_status.text = String(state.get("status", ""))
	_map_status.tooltip_text = String(state.get("detail", ""))
	var progress := float(state.get("progress", -1.0))
	_progress.visible = progress >= 0.0
	_progress.value = maxf(progress, 0.0)
	_build_button.text = String(state.get("build_label", "Build & Play"))
	_build_button.disabled = bool(state.get("build_disabled", false))
	_build_button.tooltip_text = String(state.get("build_tooltip", ""))
	var built := int(state.get("built_maps", 0))
	_built_maps_button.disabled = busy or built == 0
	_built_maps_button.tooltip_text = "Play one of the %d maps built earlier." % built if built > 0 else "No map has been built yet."
	_back_button.disabled = busy

func _sync_factions(factions: Array, selected: String, busy: bool) -> void:
	var ids := factions.map(func(option): return String(option.get("id", "")))
	if ids != _faction_ids:
		_faction_ids = ids
		_clear(_faction_row)
		for option in factions:
			_faction_row.add_child(_crest_button(String(option.get("id", "")), String(option.get("label", ""))))
	for button in _faction_row.get_children():
		var faction_id := String(button.get_meta("id"))
		button.set_pressed_no_signal(faction_id == selected)
		button.disabled = busy
		if faction_id == selected:
			_faction_name.text = String(button.get_meta("label"))

func _sync_heroes(heroes: Array, selected: String, busy: bool) -> void:
	var ids := heroes.map(func(option): return String(option.get("id", "")))
	if ids != _hero_ids:
		_hero_ids = ids
		_clear(_hero_row)
		for option in heroes:
			if String(option.get("id", "")) != "":
				_hero_row.add_child(_hero_thumb(String(option.get("id", "")), String(option.get("label", ""))))
		if _hero_row.get_child_count() == 0:
			_label(_hero_row, "The map's seed draws your faction and its commander.", "muted", 13)
	for button in _hero_row.get_children():
		if button is Button:
			button.set_pressed_no_signal(String(button.get_meta("id")) == selected)
			button.disabled = busy

func _sync_row(row: Dictionary, busy: bool) -> void:
	var key := String(row.get("key", ""))
	var options: Array = row.get("options", [])
	var ids := options.map(func(option): return String(option.get("id", "")))
	if not _rows.has(key):
		var shell := _row_shell(String(row.get("label", key)), true)
		_rows[key] = {"shell": shell, "ids": []}
		_rows_box.move_child(_seed_line, -1)
	var entry: Dictionary = _rows[key]
	var flow: Container = entry.shell
	if ids != entry.ids:
		entry.ids = ids
		_clear(flow)
		for option in options:
			var pill := _pill(String(option.get("label", "")), true)
			pill.set_meta("id", String(option.get("id", "")))
			pill.tooltip_text = String(option.get("tooltip", ""))
			pill.pressed.connect(_on_pill_pressed.bind(key, pill))
			flow.add_child(pill)
	# One option is no choice: the row hides, as the old picker did.
	flow.get_parent().visible = options.size() > 1
	for pill in flow.get_children():
		pill.set_pressed_no_signal(String(pill.get_meta("id")) == String(row.get("selected", "")))
		pill.disabled = busy

func _on_pill_pressed(key: String, pill: Button) -> void:
	# A chosen pill stays chosen when pressed again.
	pill.set_pressed_no_signal(true)
	option_chosen.emit(key, String(pill.get_meta("id")))

func _roll_seed() -> void:
	_seed_edit.text = str(randi_range(100000, 999999))
	seed_changed.emit(_seed_edit.text)

# --- The hero card -------------------------------------------------------------

func _sync_hero_card(faction_id: String, hero_id: String) -> void:
	var card_key := hero_id if hero_id != "" else "?" + faction_id
	if card_key == _card_hero_id:
		return
	_card_hero_id = card_key
	_clear(_hero_card)
	var hero := ContentService.get_hero(hero_id) if hero_id != "" else {}
	var frame := PanelContainer.new()
	frame.custom_minimum_size = PORTRAIT_SIZE
	frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.add_theme_stylebox_override("panel", _tile_style(1, 4, 2))
	_hero_card.add_child(frame)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 5)
	_hero_card.add_child(text)
	if hero.is_empty():
		frame.add_theme_stylebox_override("panel", _outline(GOLD_DIM, 1, 4, Color(0.06, 0.05, 0.04, 0.85)))
		var mark := _label(frame, "?", "gold", 96)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label(text, "Random commander", "gold", 22)
		_wrapped(text, "The map's seed draws your faction, and one of its commanders leads your first army.", "muted", 13)
		return
	frame.add_child(_picture(_texture(String(ContentService.get_hero_art(hero_id).get("portrait", ""))), true))
	_label(text, String(hero.get("name", hero_id)), "gold", 22)
	var path := "Magic hero" if String(hero.get("command_path", "might")) == "magic" else "Might hero"
	_label(text, "%s · %s" % [String(hero.get("archetype", "")).capitalize(), path], "muted", 13)
	var summary := _label(text, String(hero.get("identity_summary", "")), "body", 12)
	summary.clip_text = true
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.tooltip_text = summary.text

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 0)
	text.add_child(stats)
	var command: Dictionary = hero.get("command", {})
	for stat in ["attack", "defense", "power", "knowledge"]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", -2)
		stats.add_child(cell)
		_label(cell, stat.capitalize(), "muted", 11).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label(cell, str(int(command.get(stat, 0))), "body", 20).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell_tooltips(stats)

	for specialty_id in hero.get("starting_specialties", []):
		# The catalog row; specialty_definition cannot be the first call of a session.
		var definition := Progression._specialty_row(String(specialty_id))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		text.add_child(line)
		var insignia := _picture(Progression.specialty_insignia_texture(String(specialty_id)), false)
		insignia.custom_minimum_size = Vector2(26.0, 26.0)
		line.add_child(insignia)
		var gives := _label(line, "%s · %s" % [String(definition.get("short_name", definition.get("name", specialty_id))), Progression.rank_text(String(specialty_id), 1)], "body", 13)
		gives.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gives.clip_text = true
		gives.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		gives.tooltip_text = "%s\n%s" % [String(definition.get("name", specialty_id)), Progression.rank_text(String(specialty_id), 1)]

	var spell_ids: Array = hero.get("starting_spell_ids", [])
	if not spell_ids.is_empty():
		_label(text, "Spells", "gold", 13)
		var spells := HBoxContainer.new()
		spells.add_theme_constant_override("separation", 5)
		text.add_child(spells)
		var names := PackedStringArray()
		for spell_id in spell_ids:
			var spell := ContentService.get_spell(String(spell_id))
			names.append(String(spell.get("name", spell_id)))
			var tile := _tile(_texture(Spells.spell_icon_path(String(spell_id))), 30.0)
			tile.tooltip_text = "%s\n%s" % [String(spell.get("name", spell_id)), String(spell.get("description", spell.get("summary", "")))]
			spells.add_child(tile)
		var listed := _label(spells, ", ".join(names), "muted", 12)
		listed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		listed.clip_text = true
		listed.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	var pool := HeroCommand.starting_army_pool(hero)
	var first: Array = pool.get("first_company", [])
	var second: Array = pool.get("second_company", [])
	if not first.is_empty():
		_label(text, "Starting troops", "gold", 13)
		var troops := HBoxContainer.new()
		troops.add_theme_constant_override("separation", 5)
		text.add_child(troops)
		for unit_id in first:
			troops.add_child(_unit_tile(String(unit_id), "Can be the first company"))
		if not second.is_empty():
			var gap := Control.new()
			gap.custom_minimum_size.x = 6.0
			troops.add_child(gap)
			for unit_id in second:
				troops.add_child(_unit_tile(String(unit_id), "Can be the second company"))
		var percent := int(pool.get("second_company_percent", 0))
		var note := "Starts with one company."
		if percent > 0:
			note = "Starts with one company; %d%% of the time a second joins." % percent
		_wrapped(text, note, "muted", 11)

func cell_tooltips(stats: HBoxContainer) -> void:
	var texts := {
		"Attack": "Attack: raises the damage the hero's troops deal.",
		"Defense": "Defense: lowers the damage the hero's troops take.",
		"Power": "Power: how strong the hero's spells are.",
		"Knowledge": "Knowledge: how much mana the hero holds.",
	}
	for cell in stats.get_children():
		var title := String((cell.get_child(0) as Label).text)
		cell.tooltip_text = String(texts.get(title, title))
		cell.mouse_filter = Control.MOUSE_FILTER_STOP

func _unit_tile(unit_id: String, company: String) -> Control:
	var unit := ContentService.get_unit(unit_id)
	var tile := _tile(UnitPortraits.bust_for_unit(unit_id), 40.0)
	tile.tooltip_text = "%s\n%s · tier %d" % [String(unit.get("name", unit_id)), company, int(unit.get("tier", 0))]
	return tile

# --- Pieces ----------------------------------------------------------------------

func _crest_button(faction_id: String, label: String) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(CREST_SIZE, CREST_SIZE)
	button.set_meta("id", faction_id)
	button.set_meta("label", label)
	button.tooltip_text = label if faction_id != RANDOM_ID else "Random: the map's seed draws your faction."
	_ring_styles(button, int(CREST_SIZE / 2.0))
	if faction_id == RANDOM_ID:
		button.text = "?"
		button.add_theme_font_size_override("font_size", 26)
		button.add_theme_color_override("font_color", VisualKit.text_color("gold"))
		button.add_theme_color_override("font_pressed_color", VisualKit.text_color("gold"))
	else:
		var crest := _picture(_texture(String(ContentService.get_faction_crest(faction_id).get("icon_path", ""))), false)
		crest.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
		button.add_child(crest)
	button.pressed.connect(func():
		button.set_pressed_no_signal(true)
		option_chosen.emit("faction", faction_id))
	return button

func _hero_thumb(hero_id: String, label: String) -> Button:
	var hero := ContentService.get_hero(hero_id)
	var button := Button.new()
	button.toggle_mode = true
	button.custom_minimum_size = THUMB_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.clip_contents = true
	button.set_meta("id", hero_id)
	button.tooltip_text = "%s\n%s" % [label, String(hero.get("roster_summary", ""))]
	_ring_styles(button, 4)
	var face := _picture(_texture(String(ContentService.get_hero_art(hero_id).get("portrait", ""))), true)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
	button.add_child(face)
	button.pressed.connect(func():
		button.set_pressed_no_signal(true)
		option_chosen.emit("hero", hero_id))
	return button

## A dim outline that turns to a gold ring for the chosen one.
func _ring_styles(button: Button, radius: int) -> void:
	var idle := _outline(GOLD_DIM, 1, radius, Color(0.06, 0.05, 0.04, 0.85))
	var hover := _outline(GOLD, 1, radius, Color(0.12, 0.10, 0.08, 0.9))
	var chosen := _outline(GOLD, 3, radius, Color(0.12, 0.10, 0.08, 0.9))
	for state in ["normal", "disabled"]:
		button.add_theme_stylebox_override(state, idle)
	button.add_theme_stylebox_override("hover", hover)
	for state in ["pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, chosen)
	button.add_theme_stylebox_override("focus", _outline(Color(1.0, 0.93, 0.70), 2, radius, Color(0, 0, 0, 0)))

func _pill(text: String, toggles: bool) -> Button:
	var pill := Button.new()
	pill.text = text
	pill.toggle_mode = toggles
	pill.custom_minimum_size.y = PILL_HEIGHT
	pill.add_theme_font_size_override("font_size", 13)
	var idle := _outline(GOLD_DIM, 1, 7, PILL_FILL)
	var hover := _outline(GOLD, 1, 7, PILL_HOVER)
	var chosen := _outline(GOLD, 1, 7, GOLD)
	for style in [idle, hover, chosen]:
		style.content_margin_left = 11.0
		style.content_margin_right = 11.0
		style.content_margin_top = 2.0
		style.content_margin_bottom = 2.0
	pill.add_theme_stylebox_override("normal", idle)
	pill.add_theme_stylebox_override("hover", hover)
	pill.add_theme_stylebox_override("disabled", idle)
	for state in ["pressed", "hover_pressed"]:
		pill.add_theme_stylebox_override(state, chosen if toggles else hover)
	pill.add_theme_stylebox_override("focus", _outline(Color(1.0, 0.93, 0.70), 2, 7, Color(0, 0, 0, 0)))
	pill.add_theme_color_override("font_color", VisualKit.text_color("body"))
	pill.add_theme_color_override("font_hover_color", VisualKit.text_color("gold"))
	pill.add_theme_color_override("font_disabled_color", VisualKit.text_color("muted"))
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		pill.add_theme_color_override(state, INK if toggles else VisualKit.text_color("gold"))
	return pill

## A labelled row; returns the container its choices go into.
func _row_shell(title: String, wraps: bool = false) -> Container:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_rows_box.add_child(row)
	var label := _label(row, title, "muted", 13)
	label.custom_minimum_size = Vector2(ROW_LABEL_WIDTH, PILL_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var choices: Container = HFlowContainer.new() if wraps else HBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("h_separation" if wraps else "separation", 6)
	if wraps:
		choices.add_theme_constant_override("v_separation", 5)
	row.add_child(choices)
	return choices

func _tile(texture: Texture2D, edge: float) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(edge, edge)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.add_theme_stylebox_override("panel", _tile_style(1, 4, 2))
	tile.add_child(_picture(texture, true))
	return tile

func _tile_style(border: int, radius: int, margin: int) -> StyleBoxFlat:
	var style := _outline(Color(0.76, 0.60, 0.30), border, radius, TILE_BACKING)
	style.set_content_margin_all(margin)
	return style

func _outline(border: Color, width: int, radius: int, fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style

func _picture(texture: Texture2D, cover: bool) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture

func _texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D

func _label(parent: Node, text: String, tone: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	VisualKit.apply_label(label, tone, font_size)
	parent.add_child(label)
	return label

func _wrapped(parent: Node, text: String, tone: String, font_size: int) -> Label:
	var label := _label(parent, text, tone, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 120.0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _hairline(parent: Node) -> void:
	var line := ColorRect.new()
	line.color = HAIRLINE
	line.custom_minimum_size = Vector2(0.0, 1.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
