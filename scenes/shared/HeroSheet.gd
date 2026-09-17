extends Control
## Read-only owned-commander dossier. No gameplay intents or save fields.

signal closed

const Visuals = preload("res://scripts/ui/FrontierVisualKit.gd")
const Heroes = preload("res://scripts/core/HeroCommandRules.gd")
const Progression = preload("res://scripts/core/HeroProgressionRules.gd")
const Artifacts = preload("res://scripts/core/ArtifactRules.gd")
const SpellbookViewScript = preload("res://scenes/shared/SpellbookView.gd")
const DecisionDetails = preload("res://scripts/ui/DecisionDetails.gd")
const FRAME := "res://art/ui/runtime/overworld/parchment_panel.png"
const PORTRAIT_FRAME := "res://art/ui/runtime/overworld/hero_frame.png"

var hero: Dictionary = {}
var _panel: PanelContainer
var _body: VBoxContainer
var _tabs: TabContainer
var _close: Button
var _return_focus: WeakRef
var _focusable: Array[Control] = []
var _spellbook_view: VBoxContainer
var _artifact_search: LineEdit
var _artifact_rows: Array[Control] = []
var _artifact_empty_slots: Array[Control] = []
var _artifact_empty: Label

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
	_panel.add_theme_stylebox_override("panel", Visuals.ornate_frame_style(FRAME, "frame", 54, 24))
	add_child(_panel)
	# Wrapped labels settle after container layout. Re-clamp when their minimum
	# changes as well as on viewport resize, including reopening another hero.
	_panel.minimum_size_changed.connect(_layout.call_deferred)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	_panel.add_child(_body)
	resized.connect(_layout)

func open_hero(snapshot: Dictionary, return_control: Control) -> void:
	hero = snapshot.duplicate(true)
	_return_focus = weakref(return_control) if return_control != null else null
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_focusable.clear()
	_artifact_rows.clear()
	_artifact_empty_slots.clear()
	_build()
	show()
	move_to_front()
	set_process_input(true)
	_layout()
	_focus_cycle()
	_close.call_deferred("grab_focus")

func close_sheet() -> void:
	if not visible: return
	hide()
	set_process_input(false)
	var previous = _return_focus.get_ref() if _return_focus != null else null
	if is_instance_valid(previous) and previous.is_visible_in_tree():
		previous.grab_focus()
	closed.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_sheet()
		get_viewport().set_input_as_handled()

func _layout() -> void:
	if _panel == null: return
	_panel.size = Vector2(minf(1120.0, size.x - 32.0), minf(650.0, size.y - 32.0))
	_panel.position = (size - _panel.size) * 0.5

func _build() -> void:
	var header := HBoxContainer.new()
	_body.add_child(header)
	var title := _label(header, String(hero.get("name", "Hero")), 26, "gold")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close = _button(header, "Return to map", "Close hero sheet · Escape / controller Back", Vector2(160, 38))
	_close.name = "CloseHeroSheet"
	_close.pressed.connect(close_sheet)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 26)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(content)
	var identity := VBoxContainer.new()
	identity.custom_minimum_size.x = 260
	identity.add_theme_constant_override("separation", 12)
	content.add_child(identity)
	var portrait_frame := PanelContainer.new()
	portrait_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_frame.add_theme_stylebox_override("panel", Visuals.ornate_frame_style(PORTRAIT_FRAME, "frame", 26, 8))
	identity.add_child(portrait_frame)
	var portrait := TextureRect.new()
	portrait.name = "HeroPortrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = _texture(String(ContentService.get_hero_art(String(hero.id)).get("portrait", "")))
	portrait_frame.add_child(portrait)
	_label(identity, Heroes.hero_identity_context_line(hero), 17, "gold")
	_label(identity, "Level %d  ·  Experience %d / %d" % [int(hero.get("level", 1)), int(hero.get("experience", 0)), int(hero.get("next_level_experience", 250))], 15)
	var experience := ProgressBar.new()
	experience.name = "HeroExperienceProgress"
	experience.custom_minimum_size.y = 12
	experience.show_percentage = false
	experience.max_value = maxi(1, int(hero.get("next_level_experience", 250)))
	experience.value = int(hero.get("experience", 0))
	experience.tooltip_text = "%d experience remaining to level %d" % [maxi(0, int(experience.max_value) - int(experience.value)), int(hero.get("level", 1)) + 1]
	experience.accessibility_name = experience.tooltip_text
	identity.add_child(experience)
	_label(identity, "Movement %d / %d\nMana %d / %d\nScouting radius %d" % [int(hero.get("movement", {}).get("current", 0)), int(hero.get("movement", {}).get("max", 0)), int(hero.get("spellbook", {}).get("mana", {}).get("current", 0)), int(hero.get("spellbook", {}).get("mana", {}).get("max", 0)), Heroes.scouting_radius_for_hero(hero)], 16)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(right)
	var stats := HBoxContainer.new()
	stats.name = "CommandStats"
	right.add_child(stats)
	var artifact_bonuses := Artifacts.aggregate_bonuses(hero.duplicate(true))
	var specialty_bonuses := Progression.aggregate_bonuses(hero)
	for stat in ["attack", "defense", "power", "knowledge"]:
		var base := int(hero.get("command", {}).get(stat, 0))
		var bonus := int(artifact_bonuses.get("battle_" + stat, 0)) + int(specialty_bonuses.get("battle_" + stat, 0)) if stat in ["attack", "defense"] else 0
		var field := _label(stats, "%s\n%d" % [String(stat).capitalize(), base + bonus], 20, "gold")
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		field.tooltip_text = "%s: %d base + %d equipped artifact/specialization bonus. Battle conditions may add further modifiers." % [String(stat).capitalize(), base, bonus]
	_tabs = TabContainer.new()
	_tabs.name = "HeroTabs"
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.set_tab_alignment(TabBar.ALIGNMENT_CENTER)
	_tabs.add_theme_font_size_override("font_size", 18)
	right.add_child(_tabs)
	_build_army(_tab("Army"))
	_build_artifacts(_tab("Artifacts"))
	_build_specializations(_tab("Specializations"))
	_spellbook_view = SpellbookViewScript.new()
	_tabs.add_child(_spellbook_view)
	_spellbook_view.configure(hero, hero.get("spellbook", {}).get("known_spell_ids", []))
	_spellbook_view.controls_changed.connect(_focus_cycle)
	_tabs.get_tab_bar().focus_mode = Control.FOCUS_ALL
	_tabs.get_tab_bar().accessibility_name = "Hero information tabs"
	_tabs.tab_changed.connect(func(_index: int): _focus_cycle())
	_focusable.append(_tabs.get_tab_bar())
	_focus_cycle()

func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.accessibility_name = title + " details; scroll to read more"
	_focusable.append(scroll)
	_tabs.add_child(scroll)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(box)
	return box

func _build_army(box: VBoxContainer) -> void:
	_label(box, "Field army  ·  Select a stack to inspect", 16, "gold")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var details := _label(box, "No troops in this army.", 16)
	details.name = "UnitDetails"
	var slots: Array = hero.get("inspection_army_slots", [])
	for index in range(Heroes.ARMY_SLOT_COUNT):
		var stack := {}
		for candidate in slots:
			if int(candidate.get("slot_index", -1)) == index: stack = candidate
		var unit_id := String(stack.get("unit_id", ""))
		var unit := ContentService.get_unit(unit_id) if unit_id != "" else {}
		var count := int(stack.get("count", 0))
		var button := _button(row, str(count) if count > 0 else "—", "%s · %d troops" % [String(unit.get("name", "Empty slot")), count], Vector2(72, 104))
		button.name = "ArmySlot%d" % index
		button.set_meta("unit_id", unit_id)
		button.set_meta("count", count)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.icon = _texture(String(ContentService.get_unit_art(unit_id).get("portrait", ""))) if unit_id != "" else null
		button.disabled = unit_id == ""
		if unit_id != "":
			var description := _unit_description(unit, count)
			button.pressed.connect(func(): details.text = description)
			if details.text == "No troops in this army.": details.text = description
	for stack in hero.get("inspection_overflow_stacks", []):
		var unit := ContentService.get_unit(String(stack.get("unit_id", "")))
		_label(box, "Legacy overflow · %s × %d\n%s" % [String(unit.get("name", "Unit")), int(stack.get("count", 0)), _unit_description(unit, int(stack.get("count", 0)))], 15)
	_label(box, "Troop statistics are base values; command bonuses and battlefield effects apply in combat. Manage stacks from the Overworld command drawer or Town.", 14, "muted")

func _unit_description(unit: Dictionary, count: int) -> String:
	var text := "%s  × %d\nTier %d · %s\n\nAttack %d   Defense %d   Health %d\nDamage %d–%d   Speed %d   Initiative %d" % [String(unit.get("name", "Unit")), count, int(unit.get("tier", 1)), String(unit.get("role", "")).capitalize(), int(unit.get("attack", 0)), int(unit.get("defense", 0)), int(unit.get("hp", 0)), int(unit.get("min_damage", 0)), int(unit.get("max_damage", 0)), int(unit.get("speed", 0)), int(unit.get("initiative", 0))]
	var body: Dictionary = ContentService.load_json("res://content/unit_battle_size_manifest.json").get("units", {}).get(String(unit.get("id", "")), {})
	var width := 2 if int(body.get("footprint", 1)) == 2 else 1
	text += "\n%s · Occupies %d hex%s" % ["Ranged · %d shots" % int(unit.get("shots", 0)) if bool(unit.get("ranged", false)) else "Melee", width, "es" if width == 2 else ""]
	for ability in unit.get("abilities", []):
		if ability is Dictionary: text += "\n\n%s · %s" % [String(ability.get("name", "Ability")), String(ability.get("description", ""))]
	return text

func _build_artifacts(box: VBoxContainer) -> void:
	_artifact_search = LineEdit.new()
	_artifact_search.name = "FindHeroArtifact"
	_artifact_search.placeholder_text = "Find artifact…"
	_artifact_search.clear_button_enabled = true
	_artifact_search.accessibility_name = "Search equipped and backpack artifacts"
	_artifact_search.text_changed.connect(func(_text): _filter_artifacts())
	box.add_child(_artifact_search)
	_focusable.append(_artifact_search)
	_label(box, "Equipped", 18, "gold")
	var equipped: Dictionary = hero.get("artifacts", {}).get("equipped", {})
	for slot in Artifacts.EQUIPMENT_SLOTS:
		_artifact_row(box, String(equipped.get(slot, "")), String(slot).replace("_2", " II").capitalize())
	_label(box, "Backpack", 18, "gold")
	var inventory: Array = hero.get("artifacts", {}).get("inventory", [])
	if inventory.is_empty(): _label(box, "No carried artifacts.", 15, "muted")
	for artifact_id in inventory: _artifact_row(box, String(artifact_id), "Carried")
	_artifact_empty = _label(box, "No artifacts match this search.", 15, "muted")
	_artifact_empty.hide()
	_label(box, Artifacts.describe_impact_summary(hero.duplicate(true)), 15)
	_label(box, "Equipment changes remain in the Overworld command drawer. Inspecting an artifact does not equip it.", 14, "muted")

func _artifact_row(box: VBoxContainer, artifact_id: String, slot: String) -> void:
	if artifact_id == "":
		_artifact_empty_slots.append(_label(box, "%s · Empty" % slot, 15, "muted"))
		return
	var entry := VBoxContainer.new()
	entry.set_meta("artifact_name", Artifacts.artifact_name(artifact_id))
	_artifact_rows.append(entry)
	box.add_child(entry)
	var button := _button(entry, "%s · %s" % [slot, Artifacts.artifact_name(artifact_id)], "Show artifact effects", Vector2(0, 48))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon = _texture(Artifacts.artifact_icon_path(artifact_id))
	button.set_meta("artifact_id", artifact_id)
	button.accessibility_name = button.text
	var detail := _label(entry, DecisionDetails.artifact_comparison(hero, artifact_id) + "\n\n" + Artifacts.describe_artifact(artifact_id), 15)
	detail.hide()
	button.pressed.connect(func():
		detail.visible = not detail.visible
		if detail.visible: call_deferred("_reveal_artifact_entry", entry))

func _reveal_artifact_entry(entry: Control) -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_instance_valid(entry) or not entry.is_inside_tree(): return
	var ancestor := entry.get_parent()
	while ancestor != null and ancestor != self:
		if ancestor is ScrollContainer:
			ancestor.scroll_vertical += int(entry.global_position.y - ancestor.global_position.y - 12)
			return
		ancestor = ancestor.get_parent()

func _filter_artifacts() -> void:
	var query := _artifact_search.text.strip_edges().to_lower()
	for row in _artifact_empty_slots: row.visible = query.is_empty()
	for row in _artifact_rows:
		row.visible = query.is_empty() or String(row.get_meta("artifact_name", "")).to_lower().contains(query)
	_artifact_empty.visible = not query.is_empty() and not _artifact_rows.any(func(row): return row.visible)
	_focus_cycle()

func _build_specializations(box: VBoxContainer) -> void:
	_label(box, "Learned specializations", 18, "gold")
	var learned := 0
	for specialty in Progression.SPECIALTIES:
		var specialty_id := String(specialty.id)
		var rank := Progression.specialty_rank(hero, specialty_id)
		if rank <= 0: continue
		learned += 1
		var row := HBoxContainer.new()
		box.add_child(row)
		var icon := TextureRect.new()
		icon.texture = Progression.specialty_insignia_texture(specialty_id)
		icon.custom_minimum_size = Vector2(38, 38)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		_label(row, "%s · %s\n%s" % [String(specialty.name), Progression.rank_label(rank), String(specialty.summary)], 16)
	if learned == 0: _label(box, "No specializations learned yet.", 16)
	var pending := Progression.pending_choices_remaining(hero)
	_label(box, "%d pending specialization choice%s" % [pending, "" if pending == 1 else "s"], 17, "gold")
	if pending > 0:
		_label(box, "Choose upgrades from the Overworld command drawer after returning to the map.\n" + Progression.pending_choice_summary(Progression.current_pending_choice(hero)), 15)
	var template := Heroes.hero_template(hero)
	_label(box, String(template.get("identity_summary", "")), 16)
	var focus := Progression.summarize_specialty_ids(template.get("specialty_focus_ids", []))
	if focus != "": _label(box, "Development focus (not learned bonuses): " + focus, 14, "muted")

func _label(parent: Node, text: String, font_size: int, tone: String = "body") -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Visuals.apply_label(label, tone, font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, tooltip: String, minimum: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.accessibility_name = tooltip
	button.focus_mode = Control.FOCUS_ALL
	button.expand_icon = true
	Visuals.apply_button(button, "secondary", minimum.x, minimum.y, 16)
	button.add_theme_constant_override("icon_max_width", 54)
	parent.add_child(button)
	_focusable.append(button)
	button.focus_entered.connect(func():
		var ancestor := button.get_parent()
		while ancestor != null and ancestor != self:
			if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
			ancestor = ancestor.get_parent())
	return button

func _focus_cycle() -> void:
	var controls: Array[Control] = []
	for control in _focusable:
		if control.is_visible_in_tree() and not (control is Button and control.disabled): controls.append(control)
	if is_instance_valid(_spellbook_view) and _spellbook_view.is_visible_in_tree():
		controls.append_array(_spellbook_view.focus_controls())
	for index in range(controls.size()):
		controls[index].focus_next = controls[index].get_path_to(controls[(index + 1) % controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(controls[(index - 1 + controls.size()) % controls.size()])
		controls[index].focus_neighbor_top = controls[index].focus_previous
		controls[index].focus_neighbor_bottom = controls[index].focus_next
		if controls[index] is Button:
			controls[index].focus_neighbor_left = controls[index].focus_previous
			controls[index].focus_neighbor_right = controls[index].focus_next

func _texture(path: String) -> Texture2D:
	return ResourceLoader.load(path, "Texture2D") as Texture2D if path != "" and ResourceLoader.exists(path, "Texture2D") else null
