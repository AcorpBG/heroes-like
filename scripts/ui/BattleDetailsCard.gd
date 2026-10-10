extends PanelContainer
## The card the battle screen shows while the right button is held on a
## stack, its ribbon chip, a hero or a hero's plate (docs/battle-rework.md,
## D7). It shows what BattleRules.stack_details or hero_details report, sized
## for the HUD's scale, and lets the pointer through; the screen places it
## beside what it describes.

const BattleGlyphsScript = preload("res://scripts/ui/BattleGlyphs.gd")

const GOLD := Color(0.878, 0.722, 0.4)
const GOLD_DIM := Color(0.878, 0.722, 0.4, 0.45)
const GOLD_FAINT := Color(0.878, 0.722, 0.4, 0.15)
const GOLD_HI := Color(0.965, 0.863, 0.604)
const CREAM := Color(0.953, 0.918, 0.831)
const MUTED := Color(0.737, 0.682, 0.561)
const DIM := Color(0.561, 0.514, 0.420)
const TEXT := Color(0.863, 0.82, 0.722)
const GLYPH := Color(0.941, 0.863, 0.682)
const GOOD := Color(0.624, 0.863, 0.573)
const BAD := Color(0.957, 0.6, 0.53)
const PLAYER := Color(0.42, 0.659, 0.902)
const ENEMY := Color(0.839, 0.38, 0.329)
const MANA := Color(0.812, 0.890, 1.0)
const MANA_FILL := Color(0.373, 0.627, 0.941)
const HEALTH_FILL := Color(0.871, 0.384, 0.302)
const FILL := Color(0.106, 0.086, 0.059, 0.97)
const SEGMENT_ON := Color(0.953, 0.831, 0.557)
const SEGMENT_OFF := Color(1.0, 1.0, 1.0, 0.12)
const WIDTH := 380.0

## What the card shows now: {"kind": "stack" or "hero", "id", "texts": each
## value as written on the card}, or {} while it is empty. For checks.
var shown: Dictionary = {}
var _k := 1.0
var _title_font: Font = null
var _bold_font: FontVariation = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(title_font: Font) -> void:
	_title_font = title_font


## A stack's card from BattleRules.stack_details: its medallion, name, role
## and count; its top creature's and whole stack's health; its numbers with
## what changed them; cohesion and momentum; abilities; the effects on it
## (each row may carry the "icon" path it shows) and its stance.
func show_stack(details: Dictionary, unit_icon: Texture2D, k: float) -> void:
	var side := String(details.get("side", ""))
	var box := _begin(k)
	var texts := {}
	var ranged := bool(details.get("ranged", false))
	var header := _row(12.0)
	header.add_child(_medallion(unit_icon, PLAYER if side == "player" else ENEMY))
	var titles := _column(3.0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	texts["name"] = String(details.get("name", ""))
	titles.add_child(_label(texts["name"], 18.0, GOLD_HI, _title_font))
	var parts := PackedStringArray([String(details.get("faction", "")), "Tier %d" % int(details.get("tier", 1)), "Ranged" if ranged else "Melee"])
	if bool(details.get("large", false)):
		parts.append("Large")
	texts["subtitle"] = " · ".join(parts)
	var subtitle := _row(5.0)
	subtitle.add_child(_glyph("ranged" if ranged else "melee", 14.0, GLYPH))
	subtitle.add_child(_label(texts["subtitle"], 13.5, MUTED))
	titles.add_child(subtitle)
	header.add_child(titles)
	texts["count"] = str(int(details.get("count", 0)))
	var count := _label(texts["count"], 32.0, Color.WHITE, _bold())
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(count)
	box.add_child(header)

	var unit_health := maxi(1, int(details.get("unit_health", 1)))
	var top_health := int(details.get("top_health", 0))
	texts["top_health"] = "Top creature %d/%d HP" % [top_health, unit_health]
	texts["stack_health"] = "Stack %d HP" % int(details.get("stack_health", 0))
	var health := _column(4.0)
	health.add_child(_bar(float(top_health) / float(unit_health), HEALTH_FILL, Color(1.0, 1.0, 1.0, 0.12), 8.0))
	var health_text := _row(8.0)
	var top_label := _label(texts["top_health"], 12.5, MUTED)
	top_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_text.add_child(top_label)
	health_text.add_child(_label(texts["stack_health"], 12.5, MUTED))
	health.add_child(health_text)
	box.add_child(health)

	var grid := _grid(4)
	for stat in ["attack", "defense"]:
		grid.add_child(_stat_tile(stat, details.get(stat, {}), texts))
	var damage: Dictionary = details.get("damage", {})
	texts["damage"] = _range_text(int(damage.get("min", 0)), int(damage.get("max", 0)))
	grid.add_child(_tile("Damage", texts["damage"], 0))
	for stat in ["health", "speed", "initiative"]:
		grid.add_child(_stat_tile(stat, details.get(stat, {}), texts))
	var shots: Dictionary = details.get("shots", {})
	texts["shots"] = "%d/%d" % [int(shots.get("left", 0)), int(shots.get("max", 0))] if ranged else "—"
	grid.add_child(_tile("Shots", texts["shots"], 0))
	var strike_backs: Dictionary = details.get("strike_backs", {})
	texts["strike_backs"] = "%d/%d" % [int(strike_backs.get("left", 0)), int(strike_backs.get("max", 0))]
	grid.add_child(_tile("Strike back", texts["strike_backs"], 0))
	box.add_child(grid)

	var meters := _row(10.0)
	var cohesion: Dictionary = details.get("cohesion", {})
	var momentum: Dictionary = details.get("momentum", {})
	texts["cohesion"] = str(int(cohesion.get("value", 0)))
	texts["momentum"] = str(int(momentum.get("value", 0)))
	var cohesion_meter := _meter("Cohesion", int(cohesion.get("value", 0)), int(cohesion.get("max", 10)))
	cohesion_meter.size_flags_stretch_ratio = 1.6
	meters.add_child(cohesion_meter)
	meters.add_child(_meter("Momentum", int(momentum.get("value", 0)), int(momentum.get("max", 4))))
	box.add_child(meters)

	var abilities: Array = []
	for ability in details.get("abilities", []):
		var line := "%s. %s" % [String(ability.get("name", "")), String(ability.get("description", ""))]
		abilities.append(line.strip_edges())
		box.add_child(_rich("[color=#%s]%s.[/color] %s" % [GOLD_HI.to_html(false), _bb(String(ability.get("name", ""))), _bb(String(ability.get("description", "")))], 13.5, TEXT))
	texts["abilities"] = abilities

	var rows: Array = []
	for effect in details.get("effects", []):
		var said := String(effect.get("text", ""))
		var when := _duration_text(effect)
		rows.append({
			"icon": String(effect.get("icon", "")),
			"glyph": "spark",
			"name": String(effect.get("name", "")),
			"note": "%s · %s" % [said, when] if said != "" else when,
			"tone": GOOD if String(effect.get("polarity", "")) == "beneficial" else BAD,
		})
	if bool(details.get("defending", false)):
		rows.append({"glyph": "shield", "name": "Defending", "note": "+%d defense until the round ends" % int(details.get("defend_bonus", 0)), "tone": CREAM})
	if bool(details.get("waiting", false)):
		rows.append({"glyph": "hourglass", "name": "Waiting", "note": "acts at the end of this round, slowest first", "tone": CREAM})
	texts["effects"] = rows.map(func(row: Dictionary) -> String: return "%s %s" % [String(row.get("name", "")), String(row.get("note", ""))])
	if not rows.is_empty():
		box.add_child(_effect_list(rows))

	var hero_name := String(details.get("hero_name", ""))
	var hero_attack := int(details.get("hero_attack", 0))
	var hero_defense := int(details.get("hero_defense", 0))
	texts["footer"] = ""
	if hero_name != "" and (hero_attack != 0 or hero_defense != 0):
		texts["footer"] = "Includes %s's %s attack, %s defense." % [hero_name, _signed(hero_attack), _signed(hero_defense)]
		box.add_child(_label(texts["footer"], 11.5, DIM, null, true))
	_finish("stack", String(details.get("battle_id", "")), texts)


## A hero's card from BattleRules.hero_details: its portrait, name, faction
## and class, mana; attack, defense, power and knowledge; its specialties;
## its battle spells at what they cost it; and whether it may still cast.
func show_hero(details: Dictionary, portrait: Texture2D, k: float) -> void:
	var box := _begin(k)
	var texts := {}
	var header := _row(12.0)
	header.add_child(_portrait(portrait))
	var titles := _column(3.0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	texts["name"] = String(details.get("name", ""))
	titles.add_child(_label(texts["name"], 18.0, GOLD_HI, _title_font))
	var parts := PackedStringArray([String(details.get("faction", ""))])
	if String(details.get("class", "")).strip_edges() != "":
		parts.append(String(details.get("class", "")).strip_edges())
	texts["subtitle"] = " · ".join(parts)
	titles.add_child(_label(texts["subtitle"], 13.5, MUTED, null, true))
	var mana_current := int(details.get("mana_current", 0))
	var mana_max := int(details.get("mana_max", 0))
	texts["mana"] = "%d/%d" % [mana_current, mana_max]
	var mana := _row(8.0)
	mana.add_child(_label("Mana", 13.0, MANA, _bold()))
	var mana_bar := _bar(float(mana_current) / float(maxi(1, mana_max)), MANA_FILL, Color(0.51, 0.725, 1.0, 0.35), 7.0)
	mana_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mana_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mana.add_child(mana_bar)
	mana.add_child(_label(texts["mana"], 13.0, MANA, _bold()))
	titles.add_child(mana)
	header.add_child(titles)
	box.add_child(header)

	var grid := _grid(4)
	for stat in ["attack", "defense", "power", "knowledge"]:
		texts[stat] = str(int(details.get(stat, 0)))
		grid.add_child(_tile(stat.capitalize(), texts[stat], 0))
	box.add_child(grid)

	var specialties: Array = []
	for specialty in details.get("specialties", []):
		var title := "%s (%s)" % [String(specialty.get("name", "")), String(specialty.get("rank_label", ""))]
		var text := String(specialty.get("text", "")).strip_edges()
		specialties.append("%s. %s" % [title, text] if text != "" else "%s." % title)
		box.add_child(_rich("[color=#%s]%s.[/color] %s" % [GOLD_HI.to_html(false), _bb(title), _bb(text)], 13.5, TEXT))
	texts["specialties"] = specialties

	var spells: Array = []
	if not (details.get("spells", []) as Array).is_empty():
		var spell_grid := _grid(2)
		for spell in details.get("spells", []):
			var cost := int(spell.get("cost", 0))
			spells.append("%s %d" % [String(spell.get("name", "")), cost])
			spell_grid.add_child(_spell_cell(spell, cost <= mana_current))
		box.add_child(spell_grid)
	texts["spells"] = spells

	if bool(details.get("cast_this_round", false)):
		texts["footer"] = "Has cast a spell this round."
	elif int(details.get("battle_spell_count", 0)) <= 0:
		texts["footer"] = "Knows no battle spells."
	else:
		texts["footer"] = "Can cast one spell this round, on any of its side's turns."
	box.add_child(_label(texts["footer"], 11.5, DIM, null, true))
	_finish("hero", String(details.get("side", "")), texts)


# --- Building blocks ------------------------------------------------------------

## Empties the card and styles it for scale k; returns the column to fill.
func _begin(k: float) -> VBoxContainer:
	_k = maxf(0.3, k)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var style := StyleBoxFlat.new()
	style.bg_color = FILL
	style.border_color = GOLD_DIM
	style.set_border_width_all(maxi(1, int(round(_k))))
	style.set_corner_radius_all(int(round(12.0 * _k)))
	style.content_margin_left = 16.0 * _k
	style.content_margin_right = 16.0 * _k
	style.content_margin_top = 14.0 * _k
	style.content_margin_bottom = 12.0 * _k
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	style.shadow_size = int(round(17.0 * _k))
	style.shadow_offset = Vector2(0.0, 7.0 * _k)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(WIDTH * _k, 0.0)
	var box := _column(8.0)
	add_child(box)
	return box


## Lets the pointer through every part and records what the card shows.
func _finish(kind: String, id: String, texts: Dictionary) -> void:
	_ignore_mouse(self)
	shown = {"kind": kind, "id": id, "texts": texts}
	reset_size()


func clear() -> void:
	shown = {}
	hide()


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _px(base: float) -> int:
	return maxi(8, int(round(base * _k)))


func _bold() -> Font:
	var base := get_theme_default_font()
	if _bold_font == null or _bold_font.base_font != base:
		_bold_font = FontVariation.new()
		_bold_font.base_font = base
		_bold_font.variation_embolden = 0.7
	return _bold_font


func _label(text: String, size: float, color: Color, font: Font = null, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", _px(size))
	label.add_theme_color_override("font_color", color)
	if font != null:
		label.add_theme_font_override("font", font)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _rich(bbcode: String, size: float, color: Color) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich.add_theme_font_size_override("normal_font_size", _px(size))
	rich.add_theme_color_override("default_color", color)
	rich.text = bbcode
	return rich


func _row(separation: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(round(separation * _k)))
	return row


func _column(separation: float) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(round(separation * _k)))
	return column


func _grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", int(round(6.0 * _k)))
	grid.add_theme_constant_override("v_separation", int(round(6.0 * _k)))
	return grid


func _flat_style(fill: Color, border: Color, radius: float, border_width: float = 1.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	if border_width > 0.0:
		style.set_border_width_all(maxi(1, int(round(border_width * _k))))
	style.set_corner_radius_all(int(round(radius * _k)))
	return style


## A unit's round medallion in a ring of its side's colour.
func _medallion(texture: Texture2D, ring: Color) -> Control:
	var holder := Panel.new()
	holder.custom_minimum_size = Vector2(64.0, 64.0) * _k
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_theme_stylebox_override("panel", _flat_style(Color(0.086, 0.071, 0.047), ring, 32.0, 2.0))
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 3.0 * _k
	icon.offset_top = 3.0 * _k
	icon.offset_right = -3.0 * _k
	icon.offset_bottom = -3.0 * _k
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = texture
	holder.add_child(icon)
	return holder


## A hero's portrait in a gold frame.
func _portrait(texture: Texture2D) -> Control:
	var holder := Panel.new()
	holder.custom_minimum_size = Vector2(66.0, 88.0) * _k
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_theme_stylebox_override("panel", _flat_style(Color(0.086, 0.071, 0.047), GOLD_DIM, 8.0))
	var picture := TextureRect.new()
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.offset_left = 2.0 * _k
	picture.offset_top = 2.0 * _k
	picture.offset_right = -2.0 * _k
	picture.offset_bottom = -2.0 * _k
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.texture = texture
	holder.add_child(picture)
	return holder


func _bar(ratio: float, fill: Color, border: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1000.0
	bar.value = round(clampf(ratio, 0.0, 1.0) * 1000.0)
	bar.custom_minimum_size = Vector2(0.0, height * _k)
	bar.add_theme_stylebox_override("background", _flat_style(Color(0.0, 0.0, 0.0, 0.45), border, height * 0.5))
	bar.add_theme_stylebox_override("fill", _flat_style(fill, fill, height * 0.5, 0.0))
	return bar


## A number in a small tile: its caption above, its value and, beside it,
## how far it is from the unit's own value.
func _tile(caption: String, value: String, delta: int) -> PanelContainer:
	var tile := PanelContainer.new()
	var style := _flat_style(Color(0.0, 0.0, 0.0, 0.25), Color(GOLD, 0.14), 7.0)
	style.content_margin_left = 7.0 * _k
	style.content_margin_right = 7.0 * _k
	style.content_margin_top = 4.0 * _k
	style.content_margin_bottom = 4.0 * _k
	tile.add_theme_stylebox_override("panel", style)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := _column(0.0)
	column.add_child(_label(caption.to_upper(), 10.0, DIM, _bold()))
	var line := _row(4.0)
	line.add_child(_label(value, 16.0, CREAM, _bold()))
	if delta != 0:
		var shift := _label(_signed(delta), 12.0, GOOD if delta > 0 else BAD, _bold())
		shift.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(shift)
	column.add_child(line)
	tile.add_child(column)
	return tile


func _stat_tile(stat: String, value: Dictionary, texts: Dictionary) -> PanelContainer:
	var number := int(value.get("value", 0))
	var delta := number - int(value.get("base", number))
	texts[stat] = str(number)
	texts["%s_delta" % stat] = _signed(delta) if delta != 0 else ""
	return _tile(stat.capitalize(), texts[stat], delta)


## Cohesion or momentum: its caption, a segment per point it may reach (lit up
## to its value) and the value.
func _meter(caption: String, value: int, maximum: int) -> HBoxContainer:
	var row := _row(6.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label(caption, 12.0, MUTED))
	var segments := _row(2.0)
	segments.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in range(maxi(1, maximum)):
		var segment := Panel.new()
		segment.custom_minimum_size = Vector2(0.0, 7.0 * _k)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		segment.add_theme_stylebox_override("panel", _flat_style(SEGMENT_ON if index < value else SEGMENT_OFF, SEGMENT_OFF, 2.0, 0.0))
		segments.add_child(segment)
	row.add_child(segments)
	row.add_child(_label(str(value), 13.0, CREAM, _bold()))
	return row


## The effects and the stance, under a faint rule: an icon, the name in the
## colour of its polarity and what it does for how long.
func _effect_list(rows: Array) -> PanelContainer:
	var block := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = GOLD_FAINT
	style.border_width_top = maxi(1, int(round(_k)))
	style.content_margin_top = 8.0 * _k
	block.add_theme_stylebox_override("panel", style)
	var list := _column(5.0)
	for row in rows:
		var line := _row(7.0)
		var icon_path := String(row.get("icon", ""))
		if icon_path != "" and ResourceLoader.exists(icon_path):
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(22.0, 22.0) * _k
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon.texture = load(icon_path) as Texture2D
			line.add_child(icon)
		else:
			line.add_child(_glyph(String(row.get("glyph", "spark")), 22.0, GLYPH))
		var tone: Color = row.get("tone", CREAM)
		line.add_child(_rich("[color=#%s]%s[/color] [color=#%s]%s[/color]" % [tone.to_html(false), _bb(String(row.get("name", ""))), MUTED.to_html(false), _bb(String(row.get("note", "")))], 13.5, CREAM))
		list.add_child(line)
	block.add_child(list)
	return block


func _spell_cell(spell: Dictionary, affordable: bool) -> HBoxContainer:
	var cell := _row(7.0)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.modulate = Color.WHITE if affordable else Color(1.0, 1.0, 1.0, 0.55)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(30.0, 30.0) * _k
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path := String(spell.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path) as Texture2D
	cell.add_child(icon)
	var name_label := _label(String(spell.get("name", "")), 13.0, Color(0.91, 0.863, 0.753))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cell.add_child(name_label)
	cell.add_child(_label(str(int(spell.get("cost", 0))), 12.0, MANA, _bold()))
	return cell


func _glyph(kind: String, size: float, tint: Color) -> Control:
	var glyph := Glyph.new()
	glyph.kind = kind
	glyph.tint = tint
	glyph.custom_minimum_size = Vector2(size, size) * _k
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return glyph


# --- Words ---------------------------------------------------------------------

## How long an effect lasts: "2 turns after this one", "until the round
## ends", "3 rounds" or "for the battle".
static func _duration_text(effect: Dictionary) -> String:
	var turns := int(effect.get("turns", 1))
	match String(effect.get("unit", "round")):
		"turn":
			return "%d turn%s%s" % [turns, "" if turns == 1 else "s", " after this one" if bool(effect.get("after_this", false)) else ""]
		"battle":
			return "for the battle"
	return "until the round ends" if turns <= 1 else "%d rounds" % turns


static func _range_text(low: int, high: int) -> String:
	return str(low) if low == high else "%d–%d" % [low, high]


static func _signed(amount: int) -> String:
	return "+%d" % amount if amount > 0 else str(amount)


## Text shown as it is inside BBCode.
static func _bb(text: String) -> String:
	return text.replace("[", "[lb]")


## A small drawn glyph: a bow or sword, a shield, an hourglass or a spark.
class Glyph extends Control:
	const Glyphs = preload("res://scripts/ui/BattleGlyphs.gd")
	var kind := ""
	var tint := Color.WHITE

	func _draw() -> void:
		var center := size * 0.5
		var extent := minf(size.x, size.y)
		match kind:
			"melee", "ranged":
				Glyphs.draw_role(self, center, extent * 0.9, kind == "ranged", tint)
			"shield":
				Glyphs.draw_shield(self, center, extent * 0.9, tint)
			"hourglass":
				Glyphs.draw_hourglass(self, center, extent * 0.85, tint)
			_:
				var points := PackedVector2Array()
				for index in range(8):
					var reach := extent * (0.42 if index % 2 == 0 else 0.13)
					points.append(center + Vector2.from_angle(-PI * 0.5 + PI * 0.25 * float(index)) * reach)
				draw_colored_polygon(points, tint)
