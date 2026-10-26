class_name TownRecruitCard
extends PanelContainer

const UnitPortraits := preload("res://scripts/ui/UnitPortraitTexture.gd")

## One creature's recruitment card, shared by the dwelling popouts and the
## Muster Hall: portrait, tier and melee/ranged badge, battle stats and
## abilities, reserve and weekly growth, cost, an amount slider with Max and a
## Recruit button showing the total. Emits intents only; TownShell recruits.

signal recruit_requested(unit_id: String, count: int)
signal trade_requested

const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")
const Widgets = preload("res://scenes/town/TownPanelWidgets.gd")
const Board = preload("res://scripts/core/TownConstructionBoard.gd")

var unit_id := ""
var slider: HSlider
var recruit_button: Button
var max_button: Button
var _title: Label
var _card: Dictionary = {}
var _resources: Dictionary = {}
var _compact := false
var _portrait: TextureRect
var _order: VBoxContainer
var _growth: Label
var _each: HBoxContainer
var _cost: HBoxContainer
var _reason: Label
var _trade: Button

## `card` is a TownBuildingPanel recruit card. Compact cards (Muster Hall) use
## a smaller portrait and short stat names so two fit side by side.
func configure(card: Dictionary, resources: Dictionary, compact: bool = false, portrait_tooltip: String = "") -> void:
	_card = card.duplicate(true)
	_resources = resources.duplicate(true)
	_compact = compact
	unit_id = String(card.get("unit_id", ""))
	name = "Recruit_%s" % unit_id
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_reason = null
	_trade = null
	var max_now := int(card.get("max_now", 0))
	Widgets.apply_card(self, "green" if max_now > 0 else "ink", 10 if compact else 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10 if compact else 14)
	add_child(row)
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(72, 96) if compact else Vector2(80, 104)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = UnitPortraits.for_unit(unit_id, "portrait")
	portrait.tooltip_text = portrait_tooltip
	portrait.mouse_filter = Control.MOUSE_FILTER_PASS if portrait_tooltip != "" else Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	_portrait = portrait

	var info := VBoxContainer.new()
	info.name = "Info"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	info.add_child(name_row)
	var title := Widgets.label(String(card.get("name", unit_id)), "title", 15 if compact else 16)
	title.name = "UnitName"
	_title = title
	if compact:
		# A trimmed label has no minimum width; it must expand to stay visible.
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.tooltip_text = title.text
		title.mouse_filter = Control.MOUSE_FILTER_PASS
	name_row.add_child(title)
	# Compact cards give the name its own line so long names stay readable.
	var badge_row := name_row
	if compact:
		badge_row = HBoxContainer.new()
		badge_row.add_theme_constant_override("separation", 6)
		info.add_child(badge_row)
	badge_row.add_child(Widgets.chip("Tier %s" % Board.roman(int(card.get("tier", 0))), "gold"))
	badge_row.add_child(Widgets.role_chip(String(card.get("role", "melee"))))
	info.add_child(Widgets.stat_grid(card, {}, compact))
	var ability_names := []
	var ability_lines := []
	for ability in card.get("abilities", []):
		ability_names.append(String(ability.get("name", "")))
		ability_lines.append("%s — %s" % [String(ability.get("name", "")), String(ability.get("description", ""))])
	if not ability_names.is_empty():
		var abilities := Widgets.label("Abilities: %s" % ", ".join(ability_names), "muted", 12 if compact else 13)
		abilities.name = "Abilities"
		abilities.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if compact:
			abilities.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			abilities.clip_text = true
		else:
			abilities.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		abilities.tooltip_text = "\n".join(ability_lines)
		abilities.mouse_filter = Control.MOUSE_FILTER_PASS
		info.add_child(abilities)

	var order := VBoxContainer.new()
	order.name = "Order"
	order.custom_minimum_size = Vector2(200 if compact else 230, 0)
	order.add_theme_constant_override("separation", 4 if compact else 6)
	row.add_child(order)
	_order = order
	_growth = Widgets.label(_growth_text(card), "body", 13 if compact else 14)
	order.add_child(_growth)
	var each := HBoxContainer.new()
	each.name = "Each"
	each.add_theme_constant_override("separation", 6)
	each.add_child(Widgets.label("Each", "muted", 12 if compact else 13))
	_cost = Widgets.cost_row(card.get("unit_cost", {}), _resources, 1, 13 if compact else 14)
	each.add_child(_cost)
	order.add_child(each)
	_each = each
	var amount_row := HBoxContainer.new()
	amount_row.add_theme_constant_override("separation", 6)
	order.add_child(amount_row)
	slider = HSlider.new()
	slider.name = "Amount"
	slider.min_value = 0
	slider.max_value = max(max_now, 0)
	slider.step = 1
	slider.value = max_now
	slider.editable = max_now > 0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(100, 22)
	slider.accessibility_name = "Recruit amount for %s" % String(card.get("name", unit_id))
	FrontierVisualKit.apply_range(slider, "gold")
	amount_row.add_child(slider)
	max_button = Button.new()
	max_button.name = "Max"
	max_button.text = "Max"
	max_button.disabled = max_now <= 0
	max_button.tooltip_text = "Set the most this town's stores can pay for now."
	FrontierVisualKit.apply_button(max_button, "secondary", 52, 28, 13)
	max_button.pressed.connect(func(): slider.value = slider.max_value)
	amount_row.add_child(max_button)
	recruit_button = Button.new()
	recruit_button.name = "RecruitButton"
	recruit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recruit_button.set_meta("catalog_entry_id", "recruit:%s" % unit_id)
	recruit_button.set_meta("catalog_status", String(card.get("status", "")))
	FrontierVisualKit.apply_button(recruit_button, "primary", 180 if compact else 220, 32 if compact else 36, 13 if compact else 14)
	recruit_button.pressed.connect(press_recruit)
	order.add_child(recruit_button)
	slider.value_changed.connect(func(_value): _sync_button())
	_sync_button()
	_add_blocked_rows()

## Applies a new reserve, price and stores to this card after an order, in
## place: the portrait, stats and abilities stay; the reserve line, cost row,
## amount slider, Recruit button and blocked reason update exactly as
## configure() would draw them. Returns false for another creature or an
## unconfigured card, which then needs configure().
func update_state(card: Dictionary, resources: Dictionary, portrait_tooltip: String = "") -> bool:
	if _order == null or String(card.get("unit_id", "")) != unit_id:
		return false
	_card = card.duplicate(true)
	_resources = resources.duplicate(true)
	var max_now := int(card.get("max_now", 0))
	Widgets.apply_card(self, "green" if max_now > 0 else "ink", 10 if _compact else 12)
	_portrait.tooltip_text = portrait_tooltip
	_portrait.mouse_filter = Control.MOUSE_FILTER_PASS if portrait_tooltip != "" else Control.MOUSE_FILTER_IGNORE
	_growth.text = _growth_text(card)
	var cost := Widgets.cost_row(card.get("unit_cost", {}), _resources, 1, 13 if _compact else 14)
	_each.remove_child(_cost)
	_cost.queue_free()
	_each.add_child(cost)
	_cost = cost
	slider.max_value = max(max_now, 0)
	slider.value = max_now
	slider.editable = max_now > 0
	max_button.disabled = max_now <= 0
	recruit_button.set_meta("catalog_status", String(card.get("status", "")))
	_sync_button()
	for node in [_reason, _trade]:
		if node != null:
			_order.remove_child(node)
			node.queue_free()
	_reason = null
	_trade = null
	_add_blocked_rows()
	return true

func _growth_text(card: Dictionary) -> String:
	return "%d available · +%d per week" % [int(card.get("available", 0)), int(card.get("weekly_growth", 0))]

func _add_blocked_rows() -> void:
	if int(_card.get("max_now", 0)) > 0:
		return
	var reason := Widgets.label(String(_card.get("status_detail", "")), "muted", 12)
	reason.name = "Reason"
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.custom_minimum_size = Vector2(_order.custom_minimum_size.x, 0)
	reason.max_lines_visible = 2 if _compact else -1
	reason.tooltip_text = reason.text
	reason.mouse_filter = Control.MOUSE_FILTER_PASS
	_order.add_child(reason)
	_reason = reason
	if int(_card.get("market_max", 0)) > 0:
		var trade := Button.new()
		trade.name = "TradeButton"
		trade.text = "Trade for it"
		trade.tooltip_text = "Open the market to exchange for the missing resources."
		FrontierVisualKit.apply_button(trade, "secondary", 140, 30, 13)
		trade.pressed.connect(func(): trade_requested.emit())
		_order.add_child(trade)
		_trade = trade

func card_model() -> Dictionary:
	return _card

func amount() -> int:
	return int(slider.value) if slider != null else 0

func set_amount(count: int) -> bool:
	if slider == null:
		return false
	slider.value = count
	return int(slider.value) == count

func press_recruit() -> bool:
	var count := amount()
	if count <= 0 or recruit_button == null or recruit_button.disabled:
		return false
	recruit_requested.emit(unit_id, count)
	return true

func snapshot() -> Dictionary:
	return {
		"unit_id": unit_id,
		"max": int(slider.max_value) if slider != null else 0,
		"amount": amount(),
		"button_enabled": recruit_button != null and not recruit_button.disabled,
		"button_text": recruit_button.text if recruit_button != null else "",
		"visible": recruit_button != null and recruit_button.is_visible_in_tree(),
		"status": String(_card.get("status", "")),
		"name_width": _title.size.x if _title != null else 0.0,
	}

func _sync_button() -> void:
	var count := amount()
	var total := {}
	var unit_cost: Dictionary = _card.get("unit_cost", {}) if _card.get("unit_cost", {}) is Dictionary else {}
	for resource_id in unit_cost:
		total[resource_id] = int(unit_cost[resource_id]) * count
	recruit_button.text = "Recruit %d · %s" % [count, Widgets.cost_text(total)] if count > 0 else String(_card.get("status", "Recruit"))
	recruit_button.disabled = count <= 0
	recruit_button.tooltip_text = "Recruit %d %s for %s." % [count, String(_card.get("name", unit_id)), Widgets.cost_text(total)] if count > 0 else String(_card.get("status_detail", "Nothing to recruit."))
