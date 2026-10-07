extends RefCounted

## Small shared widgets for the Town building popouts and the Muster Hall:
## labels, chips, the drawn melee/ranged badge, cost rows and unit stat grids.

const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const Board = preload("res://scripts/core/TownConstructionBoard.gd")
const ConstructionScreenScript = preload("res://scenes/town/TownConstructionScreen.gd")

const ROLE_STYLES := {
	"ranged": [Color(0.07, 0.15, 0.20, 0.94), Color(0.40, 0.72, 0.88), Color(0.76, 0.91, 1.0)],
	"melee": [Color(0.22, 0.12, 0.07, 0.94), Color(0.88, 0.58, 0.34), Color(1.0, 0.86, 0.70)],
}
const SHORT_AMOUNT := Color(1.0, 0.56, 0.46)
const ASSISTED_SHORT_AMOUNT := Color(1.0, 0.68, 0.28)
const BETTER_STAT := Color(0.62, 0.90, 0.45)
const ASSISTED_BETTER_STAT := Color(0.45, 0.80, 1.0)
const STAT_NAMES := {"Attack": "ATK", "Defense": "DEF", "Damage": "DMG", "Health": "HP", "Speed": "SPD", "Initiative": "INI", "Shots": "Shots"}

static var _textures := {}

static func label(text: String, tone: String, font_size: int) -> Label:
	var result := Label.new()
	result.text = text
	FrontierVisualKit.apply_label(result, tone, font_size)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return result

static func wrapped(text: String, tone: String, font_size: int) -> Label:
	var result := label(text, tone, font_size)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result

static func texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _textures.has(path):
		return _textures[path]
	var loaded: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null
	_textures[path] = loaded
	return loaded

static func apply_card(panel: PanelContainer, tone: String, margin: int = 12) -> void:
	var style := FrontierVisualKit.panel_style(tone, 10)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin - 2
	style.content_margin_bottom = margin - 2
	panel.add_theme_stylebox_override("panel", style)

static func chip(text: String, tone: String) -> PanelContainer:
	var result := PanelContainer.new()
	var style := FrontierVisualKit.badge_style("ink")
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	style.shadow_size = 0
	style.set_border_width_all(1)
	style.border_color = FrontierVisualKit.text_color(tone)
	result.add_theme_stylebox_override("panel", style)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	result.add_child(label(text, tone, 12))
	return result

## Drawn sword/bow badge with text, matching the construction board.
static func role_chip(role: String) -> PanelContainer:
	var palette: Array = ROLE_STYLES.get(role, ROLE_STYLES["melee"])
	var result := PanelContainer.new()
	result.name = "Role_%s" % role
	result.set_meta("role", role)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = palette[0]
	style.border_color = palette[1]
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	result.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_child(row)
	var glyph := ConstructionScreenScript.ConstructionRoleGlyph.new()
	glyph.role = role
	glyph.color = palette[2]
	glyph.custom_minimum_size = Vector2(15, 15)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	var text := label(role.to_upper(), "body", 12)
	text.add_theme_color_override("font_color", palette[2])
	row.add_child(text)
	return result

## Resource icons with amounts; amounts the stores cannot pay turn red and
## show what the town has.
static func cost_row(cost: Dictionary, resources: Dictionary, multiplier: int = 1, font_size: int = 14) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Cost"
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for resource_id in Board.RESOURCE_ORDER:
		if not cost.has(resource_id):
			continue
		var need := int(cost[resource_id]) * multiplier
		var short := int(resources.get(resource_id, 0)) < need
		var cell := HBoxContainer.new()
		cell.name = String(resource_id)
		cell.add_theme_constant_override("separation", 3)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.custom_minimum_size = Vector2(font_size + 4, font_size + 4)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.texture = texture(OverworldRulesScript.resource_icon_path(resource_id))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
		var amount := label(Board.format_amount(need), "body", font_size)
		if short:
			amount.add_theme_color_override("font_color", ASSISTED_SHORT_AMOUNT if FrontierVisualKit.color_cue_assist_enabled() else SHORT_AMOUNT)
			amount.text += " (have %s)" % Board.format_amount(int(resources.get(resource_id, 0)))
		cell.add_child(amount)
		row.add_child(cell)
	if row.get_child_count() == 0:
		row.add_child(label("Free", "body", font_size))
	return row

static func cost_text(cost: Dictionary) -> String:
	var parts := []
	for resource_id in Board.RESOURCE_ORDER:
		if cost.has(resource_id):
			parts.append("%s %s" % [Board.format_amount(int(cost[resource_id])), Board.resource_name(resource_id)])
	return ", ".join(parts) if not parts.is_empty() else "free"

## Battle stats of a creature card. With `compare`, stats that improve on it
## turn green and show the gain. `short_names` uses ATK/DEF style labels.
static func stat_grid(card: Dictionary, compare: Dictionary = {}, short_names: bool = false) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "Stats"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12 if short_names else 18)
	grid.add_theme_constant_override("v_separation", 2)
	var stats := [
		["Attack", int(card.get("attack", 0)), ""],
		["Defense", int(card.get("defense", 0)), ""],
		["Damage", int(card.get("min_damage", 0)) + int(card.get("max_damage", 0)), "%d-%d" % [int(card.get("min_damage", 0)), int(card.get("max_damage", 0))]],
		["Health", int(card.get("hp", 0)), ""],
		["Speed", int(card.get("speed", 0)), ""],
		["Initiative", int(card.get("initiative", 0)), ""],
	]
	if int(card.get("shots", 0)) > 0:
		stats.append(["Shots", int(card.get("shots", 0)), ""])
	for entry in stats:
		var stat := String(entry[0])
		var cell := HBoxContainer.new()
		cell.name = stat
		cell.add_theme_constant_override("separation", 5)
		cell.tooltip_text = stat
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.add_child(label(String(STAT_NAMES.get(stat, stat)) if short_names else stat, "muted", 12 if short_names else 13))
		var value := label(String(entry[2]) if String(entry[2]) != "" else str(int(entry[1])), "title", 13 if short_names else 14)
		value.name = "Value"
		if not compare.is_empty():
			var before := compare_value(compare, stat)
			if int(entry[1]) > before:
				value.add_theme_color_override("font_color", ASSISTED_BETTER_STAT if FrontierVisualKit.color_cue_assist_enabled() else BETTER_STAT)
				value.text += " (+%d)" % (int(entry[1]) - before)
		cell.add_child(value)
		grid.add_child(cell)
	return grid

static func compare_value(card: Dictionary, stat: String) -> int:
	match stat:
		"Attack": return int(card.get("attack", 0))
		"Defense": return int(card.get("defense", 0))
		"Damage": return int(card.get("min_damage", 0)) + int(card.get("max_damage", 0))
		"Health": return int(card.get("hp", 0))
		"Speed": return int(card.get("speed", 0))
		"Initiative": return int(card.get("initiative", 0))
		"Shots": return int(card.get("shots", 0))
	return 0
