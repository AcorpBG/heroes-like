class_name TownBuildingPanelView
extends VBoxContainer

## Body of the Town building popout. Renders a TownBuildingPanel model:
## painting, description and effects for every building, then the building's
## own orders (dwelling recruitment, guild spell shelves, tavern heroes,
## services) and its upgrade line. Emits intents only; TownShell runs orders.

signal recruit_requested(unit_id: String, count: int)
signal hire_requested(hero_id: String)
signal build_requested(building_id: String)
signal trade_requested
signal service_requested(action_id: String)
signal controls_changed

const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const Board = preload("res://scripts/core/TownConstructionBoard.gd")
const ConstructionScreenScript = preload("res://scenes/town/TownConstructionScreen.gd")

const ROLE_STYLES := {
	"ranged": [Color(0.07, 0.15, 0.20, 0.94), Color(0.40, 0.72, 0.88), Color(0.76, 0.91, 1.0)],
	"melee": [Color(0.22, 0.12, 0.07, 0.94), Color(0.88, 0.58, 0.34), Color(1.0, 0.86, 0.70)],
}
const STATUS_TONES := {"ready": "green", "trade": "teal", "short": "red", "locked": "muted", "tomorrow": "muted", "complete": "gold"}
const SHORT_AMOUNT := Color(1.0, 0.56, 0.46)
const ASSISTED_SHORT_AMOUNT := Color(1.0, 0.68, 0.28)
const BETTER_STAT := Color(0.62, 0.90, 0.45)
const ASSISTED_BETTER_STAT := Color(0.45, 0.80, 1.0)
const SIDE_WIDTH := 372.0
const SPELL_CARD_HEIGHT := 58.0
const GRID_GAP := 8

var _model: Dictionary = {}
var _resources: Dictionary = {}
var _texture_cache: Dictionary = {}
var _guild_level := 0
var _recruit_sliders: Dictionary = {}
var _recruit_buttons: Dictionary = {}
var _recruit_counts: Dictionary = {}
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

func configure(model: Dictionary) -> void:
	var same_building := String(model.get("building_id", "")) == String(_model.get("building_id", ""))
	_model = model.duplicate(true)
	_resources = model.get("resources", {}) if model.get("resources", {}) is Dictionary else {}
	if not same_building:
		_guild_level = 0
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
	_recruit_sliders.clear()
	_recruit_buttons.clear()
	_recruit_counts.clear()
	_hire_buttons.clear()
	_service_buttons.clear()
	_spell_cards.clear()
	_level_buttons.clear()
	_upgrade_button = null
	_trade_button = null
	_spell_grid = null
	_hero_grid = null
	_spell_note = null
	match String(_model.get("kind", "")):
		"dwelling":
			_build_recruitment()
		"guild":
			_build_guild()
		"tavern":
			_build_tavern()
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
		section.add_child(_recruit_card(card_value))
	var upgrades: Array = recruit.get("troop_upgrades", [])
	if not upgrades.is_empty():
		var upgrade_section := _section("Upgrade stationed troops")
		upgrade_section.name = "TroopUpgrades"
		for action in upgrades:
			upgrade_section.add_child(_service_row(action))

func _recruit_card(card: Dictionary) -> PanelContainer:
	var unit_id := String(card.get("unit_id", ""))
	var panel := PanelContainer.new()
	panel.name = "Recruit_%s" % unit_id
	_apply_card(panel, "green" if not bool(card.get("disabled", true)) else "ink")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(80, 104)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = _texture(String(card.get("portrait_path", "")))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	info.add_child(name_row)
	name_row.add_child(_label(String(card.get("name", unit_id)), "title", 16))
	name_row.add_child(_chip("Tier %s" % Board.roman(int(card.get("tier", 0))), "gold"))
	name_row.add_child(_role_chip(String(card.get("role", "melee"))))
	info.add_child(_unit_stat_grid(card, {}))
	var abilities := _ability_text(card)
	if abilities != "":
		var ability_label := _label(abilities, "muted", 13)
		ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ability_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ability_label.tooltip_text = _ability_tooltip(card)
		ability_label.mouse_filter = Control.MOUSE_FILTER_PASS
		info.add_child(ability_label)
	var order := VBoxContainer.new()
	order.name = "Order"
	order.custom_minimum_size = Vector2(230, 0)
	order.add_theme_constant_override("separation", 6)
	row.add_child(order)
	order.add_child(_label("%d available · +%d per week" % [int(card.get("available", 0)), int(card.get("weekly_growth", 0))], "body", 14))
	var each := HBoxContainer.new()
	each.add_theme_constant_override("separation", 6)
	each.add_child(_label("Each", "muted", 13))
	each.add_child(_cost_row(card.get("unit_cost", {}), 1))
	order.add_child(each)
	var max_now := int(card.get("max_now", 0))
	var amount_row := HBoxContainer.new()
	amount_row.add_theme_constant_override("separation", 6)
	order.add_child(amount_row)
	var slider := HSlider.new()
	slider.name = "Amount"
	slider.min_value = 0
	slider.max_value = max(max_now, 0)
	slider.step = 1
	slider.value = max_now
	slider.editable = max_now > 0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(120, 24)
	slider.accessibility_name = "Recruit amount for %s" % String(card.get("name", unit_id))
	FrontierVisualKit.apply_range(slider, "gold")
	amount_row.add_child(slider)
	var max_button := Button.new()
	max_button.name = "Max"
	max_button.text = "Max"
	max_button.disabled = max_now <= 0
	max_button.tooltip_text = "Set the most this town's stores can pay for now."
	FrontierVisualKit.apply_button(max_button, "secondary", 56, 30, 13)
	max_button.pressed.connect(func(): slider.value = slider.max_value)
	amount_row.add_child(max_button)
	var recruit_button := Button.new()
	recruit_button.name = "RecruitButton"
	recruit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FrontierVisualKit.apply_button(recruit_button, "primary", 220, 36, 14)
	recruit_button.pressed.connect(_on_recruit_pressed.bind(unit_id))
	order.add_child(recruit_button)
	_recruit_sliders[unit_id] = slider
	_recruit_buttons[unit_id] = recruit_button
	slider.value_changed.connect(func(_value): _sync_recruit_button(unit_id))
	_recruit_counts[unit_id] = max_now
	_sync_recruit_button(unit_id)
	if max_now <= 0:
		var reason := _label(String(card.get("status_detail", "")), "muted", 12)
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason.custom_minimum_size = Vector2(230, 0)
		order.add_child(reason)
		if int(card.get("market_max", 0)) > 0:
			order.add_child(_trade_link("Trade for it"))
	return panel

func _sync_recruit_button(unit_id: String) -> void:
	var slider: HSlider = _recruit_sliders.get(unit_id)
	var button: Button = _recruit_buttons.get(unit_id)
	if slider == null or button == null:
		return
	var count := int(slider.value)
	_recruit_counts[unit_id] = count
	var card := _recruit_card_model(unit_id)
	var total := {}
	for resource_id in card.get("unit_cost", {}):
		total[resource_id] = int(card.unit_cost[resource_id]) * count
	button.text = "Recruit %d · %s" % [count, _cost_text(total)] if count > 0 else "Recruit"
	button.disabled = count <= 0
	button.tooltip_text = "Recruit %d %s for %s." % [count, String(card.get("name", unit_id)), _cost_text(total)] if count > 0 else String(card.get("status_detail", "Nothing to recruit."))

func _recruit_card_model(unit_id: String) -> Dictionary:
	for card in _model.get("recruit", {}).get("units", []):
		if String(card.get("unit_id", "")) == unit_id:
			return card
	return {}

func _on_recruit_pressed(unit_id: String) -> void:
	var count := int(_recruit_counts.get(unit_id, 0))
	if count > 0:
		recruit_requested.emit(unit_id, count)

func _unit_stat_grid(card: Dictionary, compare: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "Stats"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 2)
	var stats := [
		["Attack", int(card.get("attack", 0)), "%d"],
		["Defense", int(card.get("defense", 0)), "%d"],
		["Damage", int(card.get("min_damage", 0)) + int(card.get("max_damage", 0)), "%d-%d" % [int(card.get("min_damage", 0)), int(card.get("max_damage", 0))]],
		["Health", int(card.get("hp", 0)), "%d"],
		["Speed", int(card.get("speed", 0)), "%d"],
		["Initiative", int(card.get("initiative", 0)), "%d"],
	]
	if int(card.get("shots", 0)) > 0:
		stats.append(["Shots", int(card.get("shots", 0)), "%d"])
	for entry in stats:
		var cell := HBoxContainer.new()
		cell.name = String(entry[0])
		cell.add_theme_constant_override("separation", 6)
		cell.add_child(_label(String(entry[0]), "muted", 13))
		var value_text := String(entry[2]) if String(entry[2]).contains("-") else String(entry[2]) % int(entry[1])
		var value := _label(value_text, "title", 14)
		value.name = "Value"
		if not compare.is_empty():
			var before := _compare_value(compare, String(entry[0]))
			if int(entry[1]) > before:
				value.add_theme_color_override("font_color", ASSISTED_BETTER_STAT if FrontierVisualKit.color_cue_assist_enabled() else BETTER_STAT)
				value.text += " (+%d)" % (int(entry[1]) - before)
		cell.add_child(value)
		grid.add_child(cell)
	return grid

func _compare_value(card: Dictionary, stat: String) -> int:
	match stat:
		"Attack": return int(card.get("attack", 0))
		"Defense": return int(card.get("defense", 0))
		"Damage": return int(card.get("min_damage", 0)) + int(card.get("max_damage", 0))
		"Health": return int(card.get("hp", 0))
		"Speed": return int(card.get("speed", 0))
		"Initiative": return int(card.get("initiative", 0))
		"Shots": return int(card.get("shots", 0))
	return 0

func _ability_text(card: Dictionary) -> String:
	var names := []
	for ability in card.get("abilities", []):
		names.append(String(ability.get("name", "")))
	return "Abilities: %s" % ", ".join(names) if not names.is_empty() else ""

func _ability_tooltip(card: Dictionary) -> String:
	var lines := []
	for ability in card.get("abilities", []):
		lines.append("%s — %s" % [String(ability.get("name", "")), String(ability.get("description", ""))])
	return "\n".join(lines)

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
	FrontierVisualKit.apply_button(button, "primary" if action_id == "open:trade" else "secondary", 260, 34, 14)
	if action_id == "open:trade":
		button.pressed.connect(func(): trade_requested.emit())
	else:
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
	var cost_line := HBoxContainer.new()
	cost_line.name = "CostLine"
	cost_line.add_theme_constant_override("separation", 10)
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
	if String(upgrade.get("status", "")) == "trade":
		_trade_button = _trade_link("Trade for it")
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
	var stats := _unit_stat_grid(after, before)
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

func _trade_link(text: String) -> Button:
	var button := Button.new()
	button.name = "TradeButton"
	button.text = text
	button.tooltip_text = "Open the market to exchange for the missing resources."
	FrontierVisualKit.apply_button(button, "secondary", 140, 34, 14)
	button.pressed.connect(func(): trade_requested.emit())
	return button

func _cost_row(cost: Dictionary, multiplier: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Cost"
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for resource_id in Board.RESOURCE_ORDER:
		if not cost.has(resource_id):
			continue
		var need := int(cost[resource_id]) * multiplier
		var short := int(_resources.get(resource_id, 0)) < need
		var cell := HBoxContainer.new()
		cell.name = String(resource_id)
		cell.add_theme_constant_override("separation", 3)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(18, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.texture = _texture(OverworldRulesScript.resource_icon_path(resource_id))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
		var amount := _label(Board.format_amount(need), "body", 14)
		if short:
			amount.add_theme_color_override("font_color", ASSISTED_SHORT_AMOUNT if FrontierVisualKit.color_cue_assist_enabled() else SHORT_AMOUNT)
			amount.text += " (have %s)" % Board.format_amount(int(_resources.get(resource_id, 0)))
		cell.add_child(amount)
		row.add_child(cell)
	if row.get_child_count() == 0:
		row.add_child(_label("Free", "body", 14))
	return row

func _cost_text(cost: Dictionary) -> String:
	var parts := []
	for resource_id in Board.RESOURCE_ORDER:
		if cost.has(resource_id):
			parts.append("%s %s" % [Board.format_amount(int(cost[resource_id])), Board.resource_name(resource_id)])
	return ", ".join(parts) if not parts.is_empty() else "free"

func _apply_card(panel: PanelContainer, tone: String) -> void:
	var style := FrontierVisualKit.panel_style(tone, 10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

func _chip(text: String, tone: String) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := FrontierVisualKit.badge_style("ink")
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	style.shadow_size = 0
	style.set_border_width_all(1)
	style.border_color = FrontierVisualKit.text_color(tone)
	chip.add_theme_stylebox_override("panel", style)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(_label(text, tone, 12))
	return chip

## Drawn sword/bow badge with text, matching the construction board.
func _role_chip(role: String) -> PanelContainer:
	var palette: Array = ROLE_STYLES.get(role, ROLE_STYLES["melee"])
	var chip := PanelContainer.new()
	chip.name = "Role_%s" % role
	chip.set_meta("role", role)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = palette[0]
	style.border_color = palette[1]
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	var glyph := ConstructionScreenScript.ConstructionRoleGlyph.new()
	glyph.role = role
	glyph.color = palette[2]
	glyph.custom_minimum_size = Vector2(15, 15)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	var text := _label(role.to_upper(), "body", 12)
	text.add_theme_color_override("font_color", palette[2])
	row.add_child(text)
	return chip

func _label(text: String, tone: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	FrontierVisualKit.apply_label(label, tone, font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _wrapped(text: String, tone: String, font_size: int) -> Label:
	var label := _label(text, tone, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null
	_texture_cache[path] = texture
	return texture

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
	for unit_id in _recruit_buttons:
		var slider: HSlider = _recruit_sliders[unit_id]
		var button: Button = _recruit_buttons[unit_id]
		recruit.append({"unit_id": unit_id, "max": int(slider.max_value), "amount": int(slider.value), "button_enabled": not button.disabled, "button_text": button.text, "visible": button.is_visible_in_tree()})
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
	}

func validation_set_recruit_amount(unit_id: String, count: int) -> bool:
	var slider: HSlider = _recruit_sliders.get(unit_id)
	if slider == null:
		return false
	slider.value = count
	return int(slider.value) == count

func validation_press_recruit(unit_id: String) -> bool:
	var button: Button = _recruit_buttons.get(unit_id)
	if button == null or button.disabled:
		return false
	button.pressed.emit()
	return true

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

func validation_show_guild_level(level: int) -> bool:
	for button in _level_buttons:
		if button.name == "Level%d" % level:
			button.button_pressed = true
			_on_guild_level_pressed(level)
			return true
	return false
