class_name TownBuildingPanelView
extends VBoxContainer

## Body of the Town building popout. Renders a TownBuildingPanel model:
## painting, description and effects for every building, then the building's
## own orders (dwelling recruitment, guild spell shelves, tavern heroes, the
## market's trading desk, services) and its upgrade line. Emits intents only;
## TownShell runs orders.

signal recruit_requested(unit_id: String, count: int)
signal hire_requested(hero_id: String)
signal build_requested(building_id: String)
## A cost the player wants to cover through the market.
signal trade_requested(need: Dictionary)
signal market_trade_requested(action_id: String)
signal service_requested(action_id: String)
signal controls_changed

const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")
const Board = preload("res://scripts/core/TownConstructionBoard.gd")
const Widgets = preload("res://scenes/town/TownPanelWidgets.gd")
const RecruitCardScript = preload("res://scenes/town/TownRecruitCard.gd")

const STATUS_TONES := {"ready": "green", "trade": "teal", "short": "red", "locked": "muted", "tomorrow": "muted", "complete": "gold"}
const SIDE_WIDTH := 372.0
const SPELL_CARD_HEIGHT := 58.0
const GRID_GAP := 8
const TILE_WIDTH := 132.0

var _model: Dictionary = {}
var _resources: Dictionary = {}
var _guild_level := 0
var _recruit_cards: Dictionary = {}
var _hire_buttons: Dictionary = {}
var _service_buttons: Dictionary = {}
var _spell_cards: Dictionary = {}
var _level_buttons: Array = []
var _upgrade_button: Button
var _trade_button: Button
var _painting: TextureRect
var _description_label: Label
var _effects_box: HFlowContainer
var _subtitle_label: Label
var _columns: HBoxContainer
var _body: VBoxContainer
var _side: VBoxContainer
var _spell_note: Label
var _spell_grid: GridContainer
var _hero_grid: GridContainer
var _market_give := ""
var _market_receive := ""
var _market_amount := 1
var _market_give_tiles: Dictionary = {}
var _market_receive_tiles: Dictionary = {}
var _market_result: HBoxContainer
var _market_rate_label: Label
var _market_limit_label: Label
var _market_slider: HSlider
var _market_less: Button
var _market_more: Button
var _market_max: Button
var _market_trade_button: Button

func _init() -> void:
	name = "BuildingInformation"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	var identity := HBoxContainer.new()
	identity.name = "BuildingIdentity"
	identity.add_theme_constant_override("separation", 18)
	add_child(identity)
	_painting = TextureRect.new()
	_painting.name = "BuildingPainting"
	_painting.custom_minimum_size = Vector2(96, 96)
	_painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_painting.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(_painting)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 4)
	identity.add_child(copy)
	_subtitle_label = _label("", "gold", 13)
	_subtitle_label.name = "BuildingSubtitle"
	copy.add_child(_subtitle_label)
	_description_label = _label("", "body", 14)
	_description_label.name = "BuildingDescription"
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(_description_label)
	_effects_box = HFlowContainer.new()
	_effects_box.name = "BuildingEffects"
	_effects_box.add_theme_constant_override("h_separation", 6)
	_effects_box.add_theme_constant_override("v_separation", 6)
	copy.add_child(_effects_box)
	# The building's own orders take the main column and its upgrade line the
	# side column, so popouts use the screen's width instead of scrolling.
	_columns = HBoxContainer.new()
	_columns.name = "Columns"
	_columns.add_theme_constant_override("separation", 16)
	add_child(_columns)
	_body = VBoxContainer.new()
	_body.name = "BuildingBody"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	_columns.add_child(_body)
	_side = VBoxContainer.new()
	_side.name = "BuildingSide"
	_side.add_theme_constant_override("separation", 8)
	_columns.add_child(_side)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_columns()

## `fresh` starts the popout over (guild level, market pair) even for the
## building already shown; refreshes after an order keep them.
func configure(model: Dictionary, fresh: bool = false) -> void:
	var same_building := String(model.get("building_id", "")) == String(_model.get("building_id", ""))
	_model = model.duplicate(true)
	_resources = model.get("resources", {}) if model.get("resources", {}) is Dictionary else {}
	if not same_building or fresh:
		_guild_level = 0
		_market_give = ""
		_market_receive = ""
		_market_amount = 1
	_painting.texture = _texture(String(model.get("art_path", "")))
	_painting.tooltip_text = "%s — original Town building painting" % String(model.get("name", ""))
	_subtitle_label.text = String(model.get("subtitle", ""))
	_description_label.text = String(model.get("description", ""))
	_clear(_effects_box)
	for line in model.get("effects", []):
		_effects_box.add_child(_chip(String(line), "gold"))
	_effects_box.visible = _effects_box.get_child_count() > 0
	_rebuild_body()

func model() -> Dictionary:
	return _model

func description_text() -> String:
	return _description_label.text

func effects_text() -> String:
	var lines := ["Effects:"]
	for line in _model.get("effects", []):
		lines.append("• %s" % String(line))
	return "\n".join(lines)

func painting_loaded() -> bool:
	return _painting.texture != null

# --- body -----------------------------------------------------------------------

func _rebuild_body() -> void:
	_clear(_body)
	_clear(_side)
	_recruit_cards.clear()
	_hire_buttons.clear()
	_service_buttons.clear()
	_spell_cards.clear()
	_level_buttons.clear()
	_upgrade_button = null
	_trade_button = null
	_spell_grid = null
	_hero_grid = null
	_spell_note = null
	_market_give_tiles.clear()
	_market_receive_tiles.clear()
	_market_result = null
	_market_slider = null
	_market_trade_button = null
	match String(_model.get("kind", "")):
		"dwelling":
			_build_recruitment()
		"guild":
			_build_guild()
		"tavern":
			_build_tavern()
		"market":
			_build_market()
	_build_services()
	_build_upgrade()
	var has_body := _body.get_child_count() > 0
	var has_side := _side.get_child_count() > 0
	_body.visible = has_body
	_side.visible = has_side
	_side.size_flags_horizontal = Control.SIZE_FILL if has_body else Control.SIZE_EXPAND_FILL
	_side.custom_minimum_size.x = SIDE_WIDTH if has_body else 0.0
	_apply_columns()
	controls_changed.emit()

func _section(title: String, note: String = "", parent: VBoxContainer = null) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 8)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	section.add_child(header)
	var title_label := _label(title, "title", 17)
	header.add_child(title_label)
	if note != "":
		var note_label := _label(note, "muted", 13)
		note_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		note_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		note_label.tooltip_text = note
		note_label.mouse_filter = Control.MOUSE_FILTER_PASS
		header.add_child(note_label)
	(parent if parent != null else _body).add_child(section)
	return section

# --- dwelling -------------------------------------------------------------------

func _build_recruitment() -> void:
	var recruit: Dictionary = _model.get("recruit", {})
	var section := _section("Recruit", String(recruit.get("destination", "")))
	section.name = "Recruitment"
	var units: Array = recruit.get("units", [])
	if units.is_empty():
		section.add_child(_label("No creatures wait here yet. Weekly growth arrives at the start of each week.", "muted", 14))
	for card_value in units:
		var card := RecruitCardScript.new()
		card.configure(card_value, _resources)
		card.recruit_requested.connect(func(unit_id: String, count: int): recruit_requested.emit(unit_id, count))
		var unit_cost: Dictionary = card_value.get("unit_cost", {}) if card_value.get("unit_cost", {}) is Dictionary else {}
		card.trade_requested.connect(func(): trade_requested.emit(unit_cost))
		section.add_child(card)
		_recruit_cards[card.unit_id] = card
	var upgrades: Array = recruit.get("troop_upgrades", [])
	if not upgrades.is_empty():
		var upgrade_section := _section("Upgrade stationed troops")
		upgrade_section.name = "TroopUpgrades"
		for action in upgrades:
			upgrade_section.add_child(_service_row(action))

# --- magic guild ----------------------------------------------------------------

func _build_guild() -> void:
	var guild: Dictionary = _model.get("guild", {})
	var visitor := String(guild.get("visitor_name", ""))
	var note := "%s learns every spell of the built levels." % visitor if visitor != "" else "Heroes learn every spell of the built levels when they visit."
	var section := _section("Spells", note)
	section.name = "Spells"
	_spell_note = section.get_child(0).get_child(1) as Label
	var levels: Array = guild.get("levels", [])
	if levels.is_empty():
		section.add_child(_label("This town has no spell library.", "muted", 14))
		return
	if _guild_level <= 0:
		_guild_level = max(1, int(guild.get("current_level", 1)))
	var tabs := HBoxContainer.new()
	tabs.name = "Levels"
	tabs.add_theme_constant_override("separation", 6)
	section.add_child(tabs)
	var group := ButtonGroup.new()
	for level_value in levels:
		var level: Dictionary = level_value
		var number := int(level.get("level", 0))
		var button := Button.new()
		button.name = "Level%d" % number
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = number == _guild_level
		button.text = "Level %s · %d%s" % [Board.roman(number), level.get("spells", []).size(), "" if bool(level.get("built", false)) else " · locked"]
		button.tooltip_text = "%s — %s" % [String(level.get("building_name", "")), "built" if bool(level.get("built", false)) else "not built yet"]
		FrontierVisualKit.apply_button(button, "primary" if number == _guild_level else "secondary", 118, 32, 13)
		button.pressed.connect(_on_guild_level_pressed.bind(number))
		tabs.add_child(button)
		_level_buttons.append(button)
	_spell_grid = GridContainer.new()
	_spell_grid.name = "SpellGrid"
	_spell_grid.add_theme_constant_override("h_separation", GRID_GAP)
	_spell_grid.add_theme_constant_override("v_separation", GRID_GAP)
	section.add_child(_spell_grid)
	_show_guild_level()

func _on_guild_level_pressed(level: int) -> void:
	_guild_level = level
	for button in _level_buttons:
		FrontierVisualKit.apply_button(button, "primary" if button.name == "Level%d" % level else "secondary", 118, 32, 13)
	_show_guild_level()
	controls_changed.emit()

func _show_guild_level() -> void:
	if _spell_grid == null:
		return
	_clear(_spell_grid)
	_spell_cards.clear()
	var level := _guild_level_model(_guild_level)
	var built := bool(level.get("built", false))
	if _spell_note != null:
		var guild: Dictionary = _model.get("guild", {})
		var visitor := String(guild.get("visitor_name", ""))
		var taught := ("%s learns every spell of the built levels." % visitor) if visitor != "" else "Heroes learn every spell of the built levels when they visit."
		_spell_note.text = taught if built else "Build %s to teach these spells." % String(level.get("building_name", ""))
		_spell_note.tooltip_text = _spell_note.text
		_spell_note.add_theme_color_override("font_color", FrontierVisualKit.text_color("muted" if built else "gold"))
	for spell in level.get("spells", []):
		var card := _spell_card(spell, built)
		_spell_grid.add_child(card)
		_spell_cards[String(spell.get("id", ""))] = card
	_apply_columns()

func _guild_level_model(level: int) -> Dictionary:
	for entry in _model.get("guild", {}).get("levels", []):
		if int(entry.get("level", 0)) == level:
			return entry
	return {}

func _spell_card(spell: Dictionary, built: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = String(spell.get("id", "Spell"))
	_apply_card(card, "ink" if built else "earth")
	card.modulate = Color(1, 1, 1, 1) if built else Color(1, 1, 1, 0.6)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = SPELL_CARD_HEIGHT
	card.tooltip_text = "%s — %s\n%s\n%s · %s · level %d · %d mana" % [String(spell.get("name", "")), String(spell.get("summary", "")), String(spell.get("description", "")), String(spell.get("school_name", "")), String(spell.get("context", "")), int(spell.get("tier", 0)), int(spell.get("mana", 0))]
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(38, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture = _texture(String(spell.get("icon_path", "")))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	var title := _label(String(spell.get("name", "")), "title", 13)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(title)
	var meta := _label("%d mana · %s · %s%s" % [int(spell.get("mana", 0)), String(spell.get("context", "")), String(spell.get("school_name", "")), " · known" if bool(spell.get("known", false)) else ""], "gold", 12)
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(meta)
	var summary := _label(String(spell.get("summary", "")), "muted", 12)
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(summary)
	return card

# --- tavern ---------------------------------------------------------------------

func _build_tavern() -> void:
	var tavern: Dictionary = _model.get("tavern", {})
	var heroes: Array = tavern.get("heroes", [])
	var days := int(tavern.get("days_until_rotation", 7))
	var arrival := "tomorrow" if days == 1 else "in %d days" % days
	var section := _section("This week's heroes", "Command %d of %d · new heroes arrive %s (day %d)." % [int(tavern.get("hero_count", 0)), int(tavern.get("hero_limit", 0)), arrival, int(tavern.get("next_rotation_day", 0))])
	section.name = "Heroes"
	_hero_grid = GridContainer.new()
	_hero_grid.name = "HeroGrid"
	_hero_grid.add_theme_constant_override("h_separation", 10)
	_hero_grid.add_theme_constant_override("v_separation", 10)
	section.add_child(_hero_grid)
	for hero in heroes:
		_hero_grid.add_child(_hero_card(hero))
	# Keep the weekly slots visible: a hired hero's place waits for next week.
	for _slot in range(maxi(0, int(tavern.get("offer_size", 2)) - heroes.size())):
		var empty := PanelContainer.new()
		empty.name = "EmptySlot"
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.custom_minimum_size.y = 152
		_apply_card(empty, "earth")
		var note := _label("No hero waits here this week.\nThe next hero arrives on day %d." % int(tavern.get("next_rotation_day", 0)), "muted", 14)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_child(note)
		_hero_grid.add_child(empty)

func _hero_card(hero: Dictionary) -> PanelContainer:
	var hero_id := String(hero.get("hero_id", ""))
	var panel := PanelContainer.new()
	panel.name = "Hero_%s" % hero_id
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_card(panel, "ink")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(96, 128)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = _texture(String(hero.get("portrait_path", "")))
	portrait.tooltip_text = String(hero.get("identity", ""))
	portrait.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	info.add_child(_label(String(hero.get("name", hero_id)), "title", 16))
	var role := _label("%s · %s" % [String(hero.get("class_name", "")), String(hero.get("summary", ""))], "gold", 13)
	role.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	role.tooltip_text = String(hero.get("identity", ""))
	role.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_child(role)
	var stats := HBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 12)
	info.add_child(stats)
	for entry in [["ATK", "attack", "Attack"], ["DEF", "defense", "Defense"], ["POW", "power", "Spell power"], ["KNW", "knowledge", "Knowledge"], ["MOV", "movement", "Movement points"]]:
		var cell := HBoxContainer.new()
		cell.name = String(entry[2])
		cell.add_theme_constant_override("separation", 4)
		cell.tooltip_text = String(entry[2])
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.add_child(_label(String(entry[0]), "muted", 12))
		cell.add_child(_label(str(int(hero.get(String(entry[1]), 0))), "title", 14))
		stats.add_child(cell)
	var specialties: Array = hero.get("specialties", [])
	if not specialties.is_empty():
		info.add_child(_wrapped("Specialty: %s" % ", ".join(specialties), "body", 12))
	var traits: Array = hero.get("traits", [])
	if not traits.is_empty():
		info.add_child(_wrapped("Battle traits: %s" % ", ".join(traits), "muted", 12))
	var spells: Array = hero.get("spells", [])
	if not spells.is_empty():
		var spell_row := HBoxContainer.new()
		spell_row.name = "Spells"
		spell_row.add_theme_constant_override("separation", 4)
		spell_row.add_child(_label("Spells", "muted", 12))
		for spell in spells:
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(24, 24)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture = _texture(String(spell.get("icon_path", "")))
			icon.tooltip_text = String(spell.get("name", ""))
			icon.mouse_filter = Control.MOUSE_FILTER_PASS
			spell_row.add_child(icon)
		info.add_child(spell_row)
	var buy := HBoxContainer.new()
	buy.add_theme_constant_override("separation", 10)
	info.add_child(buy)
	buy.add_child(_cost_row(hero.get("cost", {}), 1))
	var hire := Button.new()
	hire.name = "Hire"
	hire.text = "Hire"
	hire.disabled = bool(hero.get("disabled", true))
	hire.tooltip_text = String(hero.get("disabled_reason", "")) if hire.disabled else "Hire %s for %s." % [String(hero.get("name", "")), _cost_text(hero.get("cost", {}))]
	hire.size_flags_horizontal = Control.SIZE_SHRINK_END
	FrontierVisualKit.apply_button(hire, "primary", 96, 32, 14)
	hire.pressed.connect(func(): hire_requested.emit(hero_id))
	buy.add_child(hire)
	_hire_buttons[hero_id] = hire
	if hire.disabled and String(hero.get("disabled_reason", "")) != "":
		info.add_child(_wrapped(String(hero.get("disabled_reason", "")), "muted", 12))
	return panel

# --- market ---------------------------------------------------------------------

## The market's trading desk, HoMM style: pick what to give and what to get,
## set the amount, read the rate and the result, then trade. Gold for a
## resource buys, a resource for gold sells, and one resource for another
## converts directly. Every number comes from the model's per-pair quotes.
func _build_market() -> void:
	var desk: Dictionary = _model.get("market", {})
	var active := bool(desk.get("active", false))
	var section := _section("Trade", "Weekly limits reset on day %d." % int(desk.get("reset_day", 0)) if active else "")
	section.name = "Market"
	if not active:
		section.add_child(_label("This market does not trade for you.", "muted", 14))
		return
	var give_ids: Array = desk.get("give_ids", [])
	var receive_ids: Array = desk.get("receive_ids", [])
	if _market_give not in give_ids or _market_receive not in receive_ids or _market_give == _market_receive:
		_market_give = String(desk.get("suggested_give", give_ids[0] if not give_ids.is_empty() else ""))
		_market_receive = String(desk.get("suggested_receive", ""))
		_market_amount = 1
	section.add_child(_market_tile_row("You give", "Give", give_ids, _market_give_tiles))
	section.add_child(_market_tile_row("You get", "Get", receive_ids, _market_receive_tiles))
	var card := PanelContainer.new()
	card.name = "Quote"
	_apply_card(card, "ink")
	section.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	_market_result = HBoxContainer.new()
	_market_result.name = "Result"
	_market_result.add_theme_constant_override("separation", 8)
	box.add_child(_market_result)
	_market_rate_label = _label("", "gold", 13)
	_market_rate_label.name = "Rate"
	box.add_child(_market_rate_label)
	# This week's limits, or why nothing can trade: one line either way, so
	# switching pairs never resizes the popout.
	_market_limit_label = _label("", "muted", 12)
	_market_limit_label.name = "Limit"
	_market_limit_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_market_limit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_market_limit_label.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_market_limit_label)
	var amount_row := HBoxContainer.new()
	amount_row.name = "Amount"
	amount_row.add_theme_constant_override("separation", 6)
	box.add_child(amount_row)
	_market_less = _market_step_button("Less", "−", "One less.", -1)
	amount_row.add_child(_market_less)
	_market_slider = HSlider.new()
	_market_slider.name = "AmountSlider"
	_market_slider.step = 1
	_market_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_market_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_market_slider.custom_minimum_size = Vector2(120, 22)
	_market_slider.accessibility_name = "Trade amount"
	FrontierVisualKit.apply_range(_market_slider, "gold")
	amount_row.add_child(_market_slider)
	_market_more = _market_step_button("More", "+", "One more.", 1)
	amount_row.add_child(_market_more)
	_market_max = Button.new()
	_market_max.name = "Max"
	_market_max.text = "Max"
	_market_max.tooltip_text = "Set the most the stores and this week's limits allow."
	FrontierVisualKit.apply_button(_market_max, "secondary", 52, 30, 13)
	_market_max.pressed.connect(func(): _market_slider.value = _market_slider.max_value)
	amount_row.add_child(_market_max)
	_market_trade_button = Button.new()
	_market_trade_button.name = "TradeButton"
	_market_trade_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	FrontierVisualKit.apply_button(_market_trade_button, "primary", 270, 34, 14)
	_market_trade_button.pressed.connect(press_market_trade)
	amount_row.add_child(_market_trade_button)
	_market_slider.value_changed.connect(func(value: float):
		_market_amount = int(value)
		_update_market_quote())
	_show_market_pair()

func _market_tile_row(caption: String, prefix: String, ids: Array, tiles: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "%sTiles" % prefix
	row.add_theme_constant_override("separation", 8)
	var title := _label(caption, "muted", 13)
	title.custom_minimum_size.x = 64
	row.add_child(title)
	var resources: Dictionary = _model.get("market", {}).get("resources", {})
	for id_value in ids:
		var resource_id := String(id_value)
		var entry: Dictionary = resources.get(resource_id, {})
		var tile := Button.new()
		tile.name = "%s_%s" % [prefix, resource_id]
		tile.custom_minimum_size = Vector2(TILE_WIDTH, 50)
		tile.focus_mode = Control.FOCUS_ALL
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var content := HBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 8
		content.offset_right = -6
		content.add_theme_constant_override("separation", 6)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(content)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(26, 26)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.texture = _texture(String(entry.get("icon_path", "")))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.alignment = BoxContainer.ALIGNMENT_CENTER
		copy.add_theme_constant_override("separation", 0)
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(copy)
		var name_label := _label(String(entry.get("name", resource_id)), "title", 13)
		name_label.name = "Name"
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		copy.add_child(name_label)
		var value_label := _label("", "body", 12)
		value_label.name = "Value"
		value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		copy.add_child(value_label)
		if prefix == "Give":
			tile.pressed.connect(_on_market_give_pressed.bind(resource_id))
		else:
			tile.pressed.connect(_on_market_receive_pressed.bind(resource_id))
		row.add_child(tile)
		tiles[resource_id] = tile
	return row

func _market_step_button(button_name: String, text: String, tip: String, step: int) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.tooltip_text = tip
	FrontierVisualKit.apply_button(button, "secondary", 32, 30, 15)
	button.pressed.connect(func(): _market_slider.value = clampf(_market_slider.value + step, _market_slider.min_value, _market_slider.max_value))
	return button

func _on_market_give_pressed(resource_id: String) -> void:
	_market_give = resource_id
	if _market_pair().get("mode", "") == "":
		# Keep the get side on a resource this give can trade for.
		for receive_id in _model.get("market", {}).get("receive_ids", []):
			if String(_market_pair_for(resource_id, String(receive_id)).get("mode", "")) != "":
				_market_receive = String(receive_id)
				break
	_market_amount = 1
	_show_market_pair()
	controls_changed.emit()

func _on_market_receive_pressed(resource_id: String) -> void:
	if String(_market_pair_for(_market_give, resource_id).get("mode", "")) == "":
		return
	_market_receive = resource_id
	_market_amount = 1
	_show_market_pair()
	controls_changed.emit()

func _market_pair() -> Dictionary:
	return _market_pair_for(_market_give, _market_receive)

func _market_pair_for(give_id: String, receive_id: String) -> Dictionary:
	var pairs: Dictionary = _model.get("market", {}).get("pairs", {})
	return pairs.get("%s>%s" % [give_id, receive_id], {})

## Restyles the tiles for the chosen pair and sets the amount range.
func _show_market_pair() -> void:
	if _market_slider == null:
		return
	var resources: Dictionary = _model.get("market", {}).get("resources", {})
	for resource_id in _market_give_tiles:
		var tile: Button = _market_give_tiles[resource_id]
		FrontierVisualKit.apply_button(tile, "primary" if resource_id == _market_give else "secondary", TILE_WIDTH, 50, 13)
		_market_tile_value(tile, "Have %s" % Board.format_amount(int(resources.get(resource_id, {}).get("stock", 0))), "body")
		tile.tooltip_text = "Give %s. You have %s." % [String(resources.get(resource_id, {}).get("name", resource_id)), Board.format_amount(int(resources.get(resource_id, {}).get("stock", 0)))]
	for resource_id in _market_receive_tiles:
		var tile: Button = _market_receive_tiles[resource_id]
		var pair := _market_pair_for(_market_give, resource_id)
		var tradable := String(pair.get("mode", "")) != ""
		tile.disabled = not tradable
		FrontierVisualKit.apply_button(tile, "primary" if resource_id == _market_receive else "secondary", TILE_WIDTH, 50, 13)
		_market_tile_value(tile, String(pair.get("unit_text", "")) if tradable else "—", "gold" if tradable else "muted")
		tile.tooltip_text = ("%s · %s" % [String(pair.get("rate_text", "")), String(pair.get("limit_text", ""))]) if tradable else String(pair.get("reason", "This market does not trade that pair."))
	var max_amount := int(_market_pair().get("max_amount", 0))
	_market_slider.set_value_no_signal(1)
	_market_slider.min_value = 1
	_market_slider.max_value = maxi(1, max_amount)
	_market_amount = clampi(_market_amount, 1, maxi(1, max_amount))
	_market_slider.set_value_no_signal(_market_amount)
	_market_slider.editable = max_amount > 1
	_market_less.disabled = max_amount <= 1
	_market_more.disabled = max_amount <= 1
	_market_max.disabled = max_amount <= 1
	_update_market_quote()

func _market_tile_value(tile: Button, text: String, tone: String) -> void:
	var value := tile.find_child("Value", true, false) as Label
	if value == null:
		return
	value.text = text
	value.add_theme_color_override("font_color", FrontierVisualKit.text_color(tone))

func _market_quote() -> Dictionary:
	var quotes: Array = _market_pair().get("quotes", [])
	return quotes[_market_amount - 1] if _market_amount >= 1 and _market_amount <= quotes.size() else {}

## Shows the result of the chosen amount and arms the Trade button.
func _update_market_quote() -> void:
	if _market_result == null:
		return
	var pair := _market_pair()
	var quote := _market_quote()
	_clear(_market_result)
	if quote.is_empty():
		_market_result.add_child(_label("Nothing to trade", "muted", 16))
	else:
		_market_result.add_child(_label("Give", "muted", 14))
		_market_result.add_child(_market_amount_cell(_market_give, int(quote.get("give_amount", 0))))
		_market_result.add_child(_label("→", "gold", 16))
		_market_result.add_child(_market_amount_cell(_market_receive, int(quote.get("receive_amount", 0))))
	_market_rate_label.text = "Rate: %s" % String(pair.get("rate_text", "")) if String(pair.get("rate_text", "")) != "" else ""
	var reason := String(pair.get("reason", ""))
	_market_limit_label.text = reason if reason != "" else String(pair.get("limit_text", ""))
	_market_limit_label.tooltip_text = _market_limit_label.text
	_market_limit_label.add_theme_color_override("font_color", FrontierVisualKit.text_color("red" if reason != "" else "muted"))
	_market_trade_button.disabled = quote.is_empty()
	_market_trade_button.text = String(quote.get("label", "Trade")) if not quote.is_empty() else "Trade"
	_market_trade_button.tooltip_text = "%s at %s." % [String(quote.get("label", "")), String(pair.get("rate_text", ""))] if not quote.is_empty() else String(pair.get("reason", ""))

func _market_amount_cell(resource_id: String, amount: int) -> HBoxContainer:
	var entry: Dictionary = _model.get("market", {}).get("resources", {}).get(resource_id, {})
	var cell := HBoxContainer.new()
	cell.name = "Amount_%s" % resource_id
	cell.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture = _texture(String(entry.get("icon_path", "")))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)
	cell.add_child(_label("%s %s" % [Board.format_amount(amount), String(entry.get("name", resource_id)).to_lower()], "title", 16))
	return cell

func market_result_text() -> String:
	var quote := _market_quote()
	if quote.is_empty():
		return ""
	return "Give %s %s → Get %s %s" % [Board.format_amount(int(quote.get("give_amount", 0))), _market_give, Board.format_amount(int(quote.get("receive_amount", 0))), _market_receive]

func press_market_trade() -> bool:
	var action_id := String(_market_quote().get("action_id", ""))
	if action_id == "" or _market_trade_button == null or _market_trade_button.disabled:
		return false
	market_trade_requested.emit(action_id)
	return true

# --- services -------------------------------------------------------------------

func _build_services() -> void:
	var services: Array = _model.get("services", [])
	var kind := String(_model.get("kind", ""))
	if services.is_empty() and kind not in ["training", "artifact_exchange"]:
		return
	var title := "Artifact exchange" if kind == "artifact_exchange" else ("Market" if kind == "market" else "Visit")
	var section := _section(title)
	section.name = "Services"
	if services.is_empty():
		section.add_child(_label("Bring a hero into town to use this building.", "muted", 14))
		return
	for action in services:
		section.add_child(_service_row(action))

func _service_row(action: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var action_id := String(action.get("id", ""))
	var button := Button.new()
	button.name = action_id.replace(":", "_")
	button.text = String(action.get("label", action_id))
	button.disabled = bool(action.get("disabled", false))
	button.tooltip_text = String(action.get("summary", ""))
	FrontierVisualKit.apply_button(button, "secondary", 260, 34, 14)
	button.pressed.connect(func(): service_requested.emit(action_id))
	row.add_child(button)
	var summary := _label(String(action.get("summary", "")), "muted", 13)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(summary)
	_service_buttons[action_id] = button
	return row

# --- upgrade --------------------------------------------------------------------

func _build_upgrade() -> void:
	var upgrade: Dictionary = _model.get("upgrade", {})
	if not bool(upgrade.get("has_line", false)):
		if String(_model.get("kind", "")) != "tavern":
			_body.add_child(_label("This building has no upgrades.", "muted", 13))
		return
	var section := _section("Upgrade", "", _side)
	section.name = "Upgrade"
	section.add_child(_stage_strip(upgrade))
	var forgone: Array = upgrade.get("forgone_unit_names", [])
	if not forgone.is_empty():
		section.add_child(_label("Chosen over %s for this tier." % " and ".join(forgone), "muted", 13))
	if bool(upgrade.get("complete", false)):
		section.add_child(_label("Every stage of this line is built.", "gold", 14))
		return
	var panel := PanelContainer.new()
	panel.name = "NextStage"
	_apply_card(panel, String(STATUS_TONES.get(String(upgrade.get("status", "")), "ink")) if String(upgrade.get("status", "")) in ["ready", "trade"] else "ink")
	section.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_label(String(upgrade.get("next_name", "")), "title", 16))
	var description := _wrapped(String(upgrade.get("next_description", "")), "body", 13)
	description.max_lines_visible = 3
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.tooltip_text = description.text
	description.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(description)
	var current_unit := String(upgrade.get("current_unit_id", ""))
	var next_unit := String(upgrade.get("next_unit_id", ""))
	if next_unit != "" and current_unit != "" and next_unit != current_unit:
		box.add_child(_unit_upgrade_compare(current_unit, next_unit))
	# A long shortfall wraps under the cost instead of widening the side column.
	var cost_line := HFlowContainer.new()
	cost_line.name = "CostLine"
	cost_line.add_theme_constant_override("h_separation", 10)
	cost_line.add_theme_constant_override("v_separation", 4)
	box.add_child(cost_line)
	cost_line.add_child(_label("Cost", "muted", 13))
	cost_line.add_child(_cost_row(upgrade.get("cost", {}), 1))
	var status := _label(String(upgrade.get("status_text", "")), String(STATUS_TONES.get(String(upgrade.get("status", "")), "muted")), 14)
	status.name = "UpgradeStatus"
	status.visible = String(upgrade.get("status", "")) != "ready"
	status.tooltip_text = String(upgrade.get("status_detail", ""))
	status.mouse_filter = Control.MOUSE_FILTER_PASS
	cost_line.add_child(status)
	var missing: Array = upgrade.get("missing_requirements", [])
	if not missing.is_empty():
		box.add_child(_wrapped("Requires %s." % ", ".join(missing), "muted", 13))
	elif String(upgrade.get("status", "")) in ["short", "tomorrow"]:
		box.add_child(_wrapped(String(upgrade.get("status_detail", "")), "muted", 13))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	_upgrade_button = Button.new()
	_upgrade_button.name = "UpgradeButton"
	_upgrade_button.text = "%s to %s" % [String(upgrade.get("verb", "Upgrade")), String(upgrade.get("next_name", ""))]
	_upgrade_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_upgrade_button.disabled = String(upgrade.get("status", "")) != "ready"
	_upgrade_button.tooltip_text = String(upgrade.get("status_detail", ""))
	_upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FrontierVisualKit.apply_button(_upgrade_button, "primary", 220, 36, 14)
	var next_id := String(upgrade.get("next_id", ""))
	_upgrade_button.pressed.connect(func(): build_requested.emit(next_id))
	buttons.add_child(_upgrade_button)
	# The market's own desk sits beside its upgrade; elsewhere a link opens it.
	if String(upgrade.get("status", "")) == "trade" and String(_model.get("kind", "")) != "market":
		_trade_button = _trade_link("Trade for it", upgrade.get("cost", {}))
		buttons.add_child(_trade_button)

func _stage_strip(upgrade: Dictionary) -> HFlowContainer:
	var strip := HFlowContainer.new()
	strip.name = "Stages"
	strip.add_theme_constant_override("h_separation", 6)
	strip.add_theme_constant_override("v_separation", 4)
	var stages: Array = upgrade.get("stages", [])
	for index in range(stages.size()):
		var stage: Dictionary = stages[index]
		# Each arrow travels with the stage it points to when the strip wraps.
		var step := HBoxContainer.new()
		step.add_theme_constant_override("separation", 6)
		if index > 0:
			step.add_child(_label("→", "muted", 14))
		var done := bool(stage.get("done", false))
		var chip := _chip(String(stage.get("name", "")) + (" · built" if done else (" · next" if bool(stage.get("next", false)) else "")), "gold" if done else ("teal" if bool(stage.get("next", false)) else "muted"))
		chip.name = "Stage%d" % (index + 1)
		step.add_child(chip)
		strip.add_child(step)
	return strip

func _unit_upgrade_compare(from_id: String, to_id: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "UnitUpgrade"
	box.add_theme_constant_override("separation", 4)
	var from_unit := ContentService.get_unit(from_id)
	var to_unit := ContentService.get_unit(to_id)
	box.add_child(_label("%s → %s" % [String(from_unit.get("name", from_id)), String(to_unit.get("name", to_id))], "gold", 14))
	var before := {"attack": from_unit.get("attack", 0), "defense": from_unit.get("defense", 0), "min_damage": from_unit.get("min_damage", 0), "max_damage": from_unit.get("max_damage", 0), "hp": from_unit.get("hp", 0), "speed": from_unit.get("speed", 0), "initiative": from_unit.get("initiative", 0), "shots": from_unit.get("shots", 0)}
	var after := {"attack": to_unit.get("attack", 0), "defense": to_unit.get("defense", 0), "min_damage": to_unit.get("min_damage", 0), "max_damage": to_unit.get("max_damage", 0), "hp": to_unit.get("hp", 0), "speed": to_unit.get("speed", 0), "initiative": to_unit.get("initiative", 0), "shots": to_unit.get("shots", 0) if bool(to_unit.get("ranged", false)) else 0}
	var gains := HFlowContainer.new()
	gains.name = "Gains"
	gains.add_theme_constant_override("h_separation", 12)
	gains.add_theme_constant_override("v_separation", 2)
	var stats := Widgets.stat_grid(after, before)
	for cell in stats.get_children():
		var value := cell.get_node("Value") as Label
		if value != null and value.text.contains("(+"):
			stats.remove_child(cell)
			gains.add_child(cell)
	stats.queue_free()
	if gains.get_child_count() == 0:
		gains.add_child(_label("Same battle profile; new abilities.", "muted", 13))
	box.add_child(gains)
	return box

# --- shared widgets -------------------------------------------------------------

func _trade_link(text: String, need: Dictionary) -> Button:
	var button := Button.new()
	button.name = "TradeButton"
	button.text = text
	button.tooltip_text = "Open the market to exchange for the missing resources."
	FrontierVisualKit.apply_button(button, "secondary", 140, 34, 14)
	button.pressed.connect(func(): trade_requested.emit(need))
	return button

func _cost_row(cost: Dictionary, multiplier: int) -> HBoxContainer:
	return Widgets.cost_row(cost, _resources, multiplier)

func _cost_text(cost: Dictionary) -> String:
	return Widgets.cost_text(cost)

func _apply_card(panel: PanelContainer, tone: String) -> void:
	Widgets.apply_card(panel, tone)

func _chip(text: String, tone: String) -> PanelContainer:
	return Widgets.chip(text, tone)

func _label(text: String, tone: String, font_size: int) -> Label:
	return Widgets.label(text, tone, font_size)

func _wrapped(text: String, tone: String, font_size: int) -> Label:
	return Widgets.wrapped(text, tone, font_size)

func _texture(path: String) -> Texture2D:
	return Widgets.texture(path)

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _apply_columns() -> void:
	var width := _body.size.x if _body.size.x > 0.0 else 800.0
	if _spell_grid != null:
		_spell_grid.columns = 3 if width >= 640.0 else 2
		# Reserve the tallest level so switching levels never resizes the popout.
		var most := 0
		for level in _model.get("guild", {}).get("levels", []):
			most = maxi(most, level.get("spells", []).size())
		var rows := ceili(float(most) / float(_spell_grid.columns))
		_spell_grid.custom_minimum_size.y = rows * SPELL_CARD_HEIGHT + maxi(0, rows - 1) * GRID_GAP
	if _hero_grid != null:
		_hero_grid.columns = 2 if width >= 640.0 else 1

# --- validation -----------------------------------------------------------------

func validation_snapshot() -> Dictionary:
	var recruit := []
	for unit_id in _recruit_cards:
		recruit.append(_recruit_cards[unit_id].snapshot())
	var heroes := []
	for hero_id in _hire_buttons:
		var hire: Button = _hire_buttons[hero_id]
		heroes.append({"hero_id": hero_id, "enabled": not hire.disabled, "visible": hire.is_visible_in_tree()})
	var levels := []
	for entry in _model.get("guild", {}).get("levels", []):
		var spell_ids := []
		for spell in entry.get("spells", []):
			spell_ids.append(String(spell.get("id", "")))
		levels.append({"level": int(entry.get("level", 0)), "built": bool(entry.get("built", false)), "spell_ids": spell_ids})
	var services := []
	for action_id in _service_buttons:
		services.append({"id": action_id, "enabled": not (_service_buttons[action_id] as Button).disabled})
	var upgrade: Dictionary = _model.get("upgrade", {})
	return {
		"kind": String(_model.get("kind", "")),
		"building_id": String(_model.get("building_id", "")),
		"subtitle": String(_model.get("subtitle", "")),
		"painting_loaded": painting_loaded(),
		"effects": effects_text(),
		"recruit": recruit,
		"heroes": heroes,
		"guild_levels": levels,
		"guild_level_shown": _guild_level,
		"spell_cards_shown": _spell_cards.keys(),
		"services": services,
		"upgrade": {
			"has_line": bool(upgrade.get("has_line", false)),
			"complete": bool(upgrade.get("complete", false)),
			"next_id": String(upgrade.get("next_id", "")),
			"status": String(upgrade.get("status", "")),
			"button_visible": _upgrade_button != null and _upgrade_button.is_visible_in_tree(),
			"button_enabled": _upgrade_button != null and not _upgrade_button.disabled,
			"trade_visible": _trade_button != null,
		},
		"market": _market_snapshot(),
	}

func _market_snapshot() -> Dictionary:
	if _market_slider == null:
		return {}
	var pair := _market_pair()
	var quote := _market_quote()
	var stock := {}
	for resource_id in _model.get("market", {}).get("resources", {}):
		stock[resource_id] = int(_model.get("market", {}).get("resources", {}).get(resource_id, {}).get("stock", 0))
	var receive_tiles := {}
	for resource_id in _market_receive_tiles:
		var tile: Button = _market_receive_tiles[resource_id]
		receive_tiles[resource_id] = {"enabled": not tile.disabled, "visible": tile.is_visible_in_tree()}
	return {
		"give_id": _market_give,
		"receive_id": _market_receive,
		"mode": String(pair.get("mode", "")),
		"amount": _market_amount,
		"max_amount": int(pair.get("max_amount", 0)),
		"slider_max": int(_market_slider.max_value),
		"give_amount": int(quote.get("give_amount", 0)),
		"receive_amount": int(quote.get("receive_amount", 0)),
		"action_id": String(quote.get("action_id", "")),
		"rate_text": String(pair.get("rate_text", "")),
		"limit_text": String(pair.get("limit_text", "")),
		"reason": String(pair.get("reason", "")),
		"result_text": market_result_text(),
		"trade_enabled": _market_trade_button != null and not _market_trade_button.disabled and _market_trade_button.is_visible_in_tree(),
		"trade_text": _market_trade_button.text if _market_trade_button != null else "",
		"give_tiles": _market_give_tiles.keys(),
		"receive_tiles": receive_tiles,
		"stock": stock,
	}

func validation_set_recruit_amount(unit_id: String, count: int) -> bool:
	return _recruit_cards.has(unit_id) and _recruit_cards[unit_id].set_amount(count)

func validation_press_recruit(unit_id: String) -> bool:
	return _recruit_cards.has(unit_id) and _recruit_cards[unit_id].press_recruit()

func validation_press_hire(hero_id: String) -> bool:
	var button: Button = _hire_buttons.get(hero_id)
	if button == null or button.disabled:
		return false
	button.pressed.emit()
	return true

func validation_press_upgrade() -> bool:
	if _upgrade_button == null or _upgrade_button.disabled:
		return false
	_upgrade_button.pressed.emit()
	return true

func validation_select_market_pair(give_id: String, receive_id: String) -> bool:
	var give_tile: Button = _market_give_tiles.get(give_id)
	if give_tile == null:
		return false
	give_tile.pressed.emit()
	var receive_tile: Button = _market_receive_tiles.get(receive_id)
	if receive_tile == null or receive_tile.disabled:
		return false
	receive_tile.pressed.emit()
	return _market_give == give_id and _market_receive == receive_id

func validation_set_market_amount(count: int) -> bool:
	if _market_slider == null:
		return false
	_market_slider.value = count
	return _market_amount == count

func validation_press_market_trade() -> bool:
	if _market_trade_button == null or _market_trade_button.disabled:
		return false
	_market_trade_button.pressed.emit()
	return true

func validation_press_recruit_trade(unit_id: String) -> bool:
	var card = _recruit_cards.get(unit_id)
	var button := card.find_child("TradeButton", true, false) as Button if card != null else null
	if button == null or button.disabled:
		return false
	button.pressed.emit()
	return true

func validation_show_guild_level(level: int) -> bool:
	for button in _level_buttons:
		if button.name == "Level%d" % level:
			button.button_pressed = true
			_on_guild_level_pressed(level)
			return true
	return false
