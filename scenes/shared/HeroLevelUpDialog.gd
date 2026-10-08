extends ConfirmationDialog
## Presentation only. The overworld validates each choice against the live hero.

signal specialty_selected(specialty_id: String)
signal review_dismissed

const Visuals = preload("res://scripts/ui/FrontierVisualKit.gd")
const Progression = preload("res://scripts/core/HeroProgressionRules.gd")
const STAT_LABELS := [["attack", "Attack"], ["defense", "Defense"], ["power", "Spell power"], ["knowledge", "Knowledge"]]
var context: Dictionary = {}
var _rolled_tiles: Array[Control] = []

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		review_dismissed.emit()
		get_viewport().set_input_as_handled()

func open_level_up(prompt: Dictionary) -> void:
	context = prompt["context"].duplicate(true)
	name = "HeroLevelUp"
	title = "Hero Level Up"
	exclusive = true
	Visuals.apply_confirmation_dialog(self)
	var hero: Dictionary = prompt["hero"]
	var body := VBoxContainer.new()
	body.custom_minimum_size.x = 600
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 24)
	body.add_child(heading)
	var portrait := TextureRect.new()
	portrait.name = "HeroPortrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(144, 172)
	var art_path := String(ContentService.get_hero_art(String(hero.get("id", ""))).get("portrait", ""))
	if ResourceLoader.exists(art_path): portrait.texture = load(art_path)
	heading.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 10)
	heading.add_child(identity)
	_label(identity, String(hero.get("name", "Hero")), "gold", 24)
	_label(identity, "Level %d → %d" % [int(prompt["previous_level"]), int(prompt["level"])], "title", 22)
	_label(identity, "+%d daily movement" % int(prompt["movement_gain"]), "gold", 17)
	_label(identity, "Experience %d / %d" % [int(hero.get("experience", 0)), int(hero.get("next_level_experience", 250))], "muted", 15)
	_add_command_rolls(body, prompt, hero)
	var choice: Dictionary = prompt.get("choice", {})
	var first_button: Button
	if not choice.is_empty():
		_label(body, "Choose a specialty for level %d  ·  %d remaining" % [int(choice["level"]), int(prompt["choices_remaining"])], "title", 17)
		for option in choice.get("options", []):
			var id := String(option)
			var definition := Progression.specialty_definition(id)
			var button := Button.new()
			button.name = "Specialty_" + id
			var next_rank := Progression.specialty_rank(hero, id) + 1
			button.text = "%s %s\n%s" % [String(definition.get("name", id)), Progression.rank_label(next_rank), Progression.rank_text(id, next_rank)]
			button.icon = Progression.specialty_insignia_texture(id)
			button.add_theme_constant_override("icon_max_width", 36)
			button.accessibility_name = button.text.replace("\n", ". ")
			Visuals.apply_button(button, "primary", 600, 64, 16)
			button.pressed.connect(func(): specialty_selected.emit(id))
			body.add_child(button)
			if first_button == null: first_button = button
		get_ok_button().hide()
		cancel_button_text = "Choose later"
	else:
		_label(body, "Your command has grown stronger.", "body", 18)
		ok_button_text = "Continue"
		get_cancel_button().hide()
		first_button = get_ok_button()
	confirmed.connect(func(): review_dismissed.emit())
	canceled.connect(func(): review_dismissed.emit())
	popup_centered(Vector2i(680, 660 if not choice.is_empty() else 460))
	if first_button != null: first_button.grab_focus()
	_pulse_rolled_tiles()

## What the level-up rolled: a headline, the four command stats with their
## new values (rolled ones lit gold with their gain), the path's odds and,
## for several levels at once, which level rolled what.
func _add_command_rolls(body: VBoxContainer, prompt: Dictionary, hero: Dictionary) -> void:
	var gains: Dictionary = prompt.get("command_gains", {})
	var command: Dictionary = hero.get("command", {})
	var rolled: Array[String] = []
	for entry in STAT_LABELS:
		var amount := int(gains.get(entry[0], 0))
		if amount > 0: rolled.append("+%d %s" % [amount, entry[1]])
	var section := VBoxContainer.new()
	section.name = "CommandRolls"
	section.add_theme_constant_override("separation", 8)
	body.add_child(section)
	_label(section, "Rolled  %s" % "  ·  ".join(rolled), "gold", 22).name = "RolledHeadline"
	var tiles := HBoxContainer.new()
	tiles.name = "StatTiles"
	tiles.add_theme_constant_override("separation", 10)
	section.add_child(tiles)
	_rolled_tiles.clear()
	for entry in STAT_LABELS:
		var stat := String(entry[0])
		var amount := int(gains.get(stat, 0))
		var tile := PanelContainer.new()
		tile.name = "Stat_" + stat
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size = Vector2(0, 78)
		var style := Visuals.panel_style("gold" if amount > 0 else "ink", 10)
		style.set_border_width_all(3 if amount > 0 else 1)
		style.set_content_margin_all(8)
		tile.add_theme_stylebox_override("panel", style)
		tile.tooltip_text = "%s %d%s" % [entry[1], int(command.get(stat, 0)), (" (rolled +%d)" % amount) if amount > 0 else ""]
		tile.mouse_filter = Control.MOUSE_FILTER_PASS
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 2)
		tile.add_child(column)
		_label(column, String(entry[1]), "gold" if amount > 0 else "muted", 15).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var value_row := HBoxContainer.new()
		value_row.alignment = BoxContainer.ALIGNMENT_CENTER
		value_row.add_theme_constant_override("separation", 6)
		column.add_child(value_row)
		_label(value_row, str(int(command.get(stat, 0))), "title" if amount > 0 else "body", 26).name = "Value"
		if amount > 0:
			_label(value_row, "+%d" % amount, "green", 20).name = "Gain"
			_rolled_tiles.append(tile)
		tiles.add_child(tile)
	var odds: Dictionary = prompt.get("command_odds", {})
	if not odds.is_empty():
		var parts: Array[String] = []
		for entry in STAT_LABELS:
			parts.append("%s %d%%" % [entry[1], int(odds.get(entry[0], 0))])
		_label(section, "%s path odds per level: %s" % [String(prompt.get("command_path", "")).capitalize(), "  ·  ".join(parts)], "muted", 14).name = "Odds"
	var rolls: Array = prompt.get("command_rolls", [])
	if rolls.size() > 1:
		var steps: Array[String] = []
		for roll in rolls:
			var stat_name := String(roll.get("stat", ""))
			for entry in STAT_LABELS:
				if entry[0] == stat_name: stat_name = entry[1]
			steps.append("Level %d: %s" % [int(roll.get("level", 0)), stat_name])
		_label(section, "  ·  ".join(steps), "muted", 14).name = "RollsByLevel"

func _pulse_rolled_tiles() -> void:
	if SettingsService.reduced_motion_enabled():
		return
	for tile in _rolled_tiles:
		tile.modulate = Color(1.55, 1.4, 1.0, 1.0)
		create_tween().tween_property(tile, "modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _label(parent: Node, text: String, tone: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	Visuals.apply_label(label, tone, font_size)
	parent.add_child(label)
	return label
