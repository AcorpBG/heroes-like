extends PanelContainer

# Battle-local presentation history, deliberately not part of session saves.
const MAX_ENTRIES := 200
var entries: Array[String] = []
var history: RichTextLabel
var _refresh_pending := false

func _ready() -> void:
	custom_minimum_size.y = 88
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.045, 0.96)
	style.border_color = Color(0.52, 0.42, 0.23)
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	var title := Label.new()
	title.text = "Battle log"
	title.add_theme_color_override("font_color", Color(0.94, 0.82, 0.56))
	row.add_child(title)
	history = RichTextLabel.new()
	history.name = "BattleHistory"
	history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history.focus_mode = Control.FOCUS_ALL
	history.selection_enabled = true
	history.bbcode_enabled = false
	history.add_theme_font_size_override("normal_font_size", 14)
	history.add_theme_color_override("default_color", Color(0.94, 0.92, 0.85))
	history.accessibility_name = "Battle message history"
	history.tooltip_text = "Recent actions remain here. Scroll to review earlier messages (up to 200)."
	# This scrollbar advances automatically during combat, not as a settings
	# adjustment. Do not emit the generic Range adjustment sound per message.
	history.get_v_scroll_bar().set_meta("silent_ui_audio", true)
	row.add_child(history)

func append_message(message: String) -> void:
	if message.strip_edges().is_empty(): return
	entries.append(message)
	if entries.size() > MAX_ENTRIES: entries.pop_front()
	if not _refresh_pending:
		_refresh_pending = true
		call_deferred("_refresh_history")

func _refresh_history() -> void:
	_refresh_pending = false
	var bar := history.get_v_scroll_bar()
	var follow := bar.value >= bar.max_value - bar.page - 2
	var previous_scroll := bar.value
	history.scroll_following = follow
	history.text = "\n".join(entries)
	# Let text wrapping finish before moving the scrollbar. Do not pull a
	# reader away from older messages whenever another unit acts.
	if not follow: call_deferred("_restore_scroll", previous_scroll)

func _restore_scroll(previous: float) -> void:
	if not is_inside_tree(): return
	var bar := history.get_v_scroll_bar()
	bar.value = previous
