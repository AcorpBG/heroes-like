extends ConfirmationDialog
## Presentation only. The overworld validates each choice against the live hero.

signal specialty_selected(specialty_id: String)
signal review_dismissed

const Visuals = preload("res://scripts/ui/FrontierVisualKit.gd")
const Progression = preload("res://scripts/core/HeroProgressionRules.gd")
var context: Dictionary = {}

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
	var gains: Array[String] = []
	for stat in ["attack", "defense", "power", "knowledge"]:
		var amount := int(prompt["command_gains"].get(stat, 0))
		if amount > 0: gains.append("+%d %s" % [amount, stat.capitalize()])
	_label(identity, "Command gained\n%s" % "  ·  ".join(gains), "gold", 18)
	_label(identity, "+%d daily movement" % int(prompt["movement_gain"]), "gold", 17)
	_label(identity, "Experience %d / %d" % [int(hero.get("experience", 0)), int(hero.get("next_level_experience", 250))], "muted", 15)
	var choice: Dictionary = prompt.get("choice", {})
	var first_button: Button
	if not choice.is_empty():
		_label(body, "Choose a specialty for level %d  ·  %d remaining" % [int(choice["level"]), int(prompt["choices_remaining"])], "title", 17)
		for option in choice.get("options", []):
			var id := String(option)
			var definition := Progression.specialty_definition(id)
			var button := Button.new()
			button.name = "Specialty_" + id
			button.text = "%s %s\n%s" % [String(definition.get("name", id)), Progression.rank_label(Progression.specialty_rank(hero, id) + 1), String(definition.get("summary", ""))]
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
	popup_centered(Vector2i(680, 500 if not choice.is_empty() else 300))
	if first_button != null: first_button.grab_focus()

func _label(parent: Node, text: String, tone: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	Visuals.apply_label(label, tone, font_size)
	parent.add_child(label)
	return label
