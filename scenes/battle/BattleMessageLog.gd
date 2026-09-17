extends PanelContainer

signal expanded_changed(expanded: bool)
# Battle-local presentation history, deliberately not part of session saves.
const MAX_ENTRIES := 200
const VisualKit := preload("res://scripts/ui/FrontierVisualKit.gd")
var entries: Array[String] = []
var history: RichTextLabel
var toggle: Button
var latest: Label
var expanded := false
var _refresh_pending := false
var search: LineEdit
var jump_latest: Button
var unread := 0

func _ready() -> void:
	custom_minimum_size.y = 36
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.045, 0.96)
	style.border_color = Color(0.52, 0.42, 0.23)
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	toggle = Button.new()
	toggle.name = "ToggleBattleHistory"
	toggle.toggle_mode = true
	toggle.text = "Log ▸"
	toggle.tooltip_text = "Expand or collapse the battle log. All recent messages are retained."
	toggle.accessibility_name = "Expand battle message history"
	VisualKit.apply_button(toggle, "secondary", 80, 24, 12)
	toggle.toggled.connect(set_expanded)
	row.add_child(toggle)
	latest = Label.new()
	latest.name = "LatestBattleMessage"
	latest.text = "Recent actions appear here"
	latest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	latest.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	VisualKit.apply_label(latest, "body", 13)
	row.add_child(latest)
	search = LineEdit.new()
	search.name = "SearchBattleHistory"
	search.placeholder_text = "Find in log…"
	search.clear_button_enabled = true
	search.custom_minimum_size.x = 160
	search.accessibility_name = "Search retained battle messages"
	search.text_changed.connect(func(_text): _refresh_history())
	search.hide()
	row.add_child(search)
	jump_latest = Button.new()
	jump_latest.name = "JumpToLatest"
	jump_latest.text = "Latest"
	jump_latest.tooltip_text = "Clear search and jump to the newest battle message."
	VisualKit.apply_button(jump_latest, "secondary", 80, 24, 12)
	jump_latest.pressed.connect(show_latest)
	jump_latest.hide()
	row.add_child(jump_latest)
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
	history.custom_minimum_size.y = 88
	history.visible = false
	column.add_child(history)
	SettingsService.settings_changed.connect(func(_settings): VisualKit.apply_button(toggle, "secondary", 80, 24, VisualKit.FONT_CAPTION))

func set_expanded(value: bool) -> void:
	expanded = value
	toggle.set_pressed_no_signal(value)
	toggle.text = "Log ▾" if value else "Log ▸"
	toggle.accessibility_name = "Collapse battle message history" if value else "Expand battle message history"
	history.visible = value
	search.visible = value
	jump_latest.visible = value
	custom_minimum_size.y = 128 if value else 36
	if not value and (history.has_focus() or search.has_focus() or jump_latest.has_focus()): toggle.grab_focus()
	if value and _following_latest(): unread = 0
	_sync_unread()
	expanded_changed.emit(value)

func append_message(message: String) -> void:
	if message.strip_edges().is_empty(): return
	if not expanded or not _following_latest(): unread = mini(MAX_ENTRIES, unread + 1)
	entries.append(message)
	if entries.size() > MAX_ENTRIES: entries.pop_front()
	if not _refresh_pending:
		_refresh_pending = true
		call_deferred("_refresh_history")

func _refresh_history() -> void:
	_refresh_pending = false
	if history == null: return
	latest.text = entries.back() if not entries.is_empty() else "Recent actions appear here"
	latest.tooltip_text = latest.text
	toggle.tooltip_text = "%d recent messages. Expand or collapse; history is retained." % entries.size()
	var bar := history.get_v_scroll_bar()
	var follow := bar.value >= bar.max_value - bar.page - 2
	var previous_scroll := bar.value
	history.scroll_following = follow
	history.text = "\n".join(filtered_entries())
	_sync_unread()
	# Let text wrapping finish before moving the scrollbar. Do not pull a
	# reader away from older messages whenever another unit acts.
	if not follow: call_deferred("_restore_scroll", previous_scroll)

func filtered_entries() -> Array[String]:
	var result: Array[String] = []
	var query := search.text.strip_edges().to_lower() if search != null else ""
	for entry in entries:
		if query.is_empty() or entry.to_lower().contains(query): result.append(entry)
	return result

func _following_latest() -> bool:
	if history == null or (search != null and not search.text.is_empty()): return false
	var bar := history.get_v_scroll_bar()
	return bar.value >= bar.max_value - bar.page - 2

func _sync_unread() -> void:
	toggle.custom_minimum_size.x = 104 if unread > 0 else 80
	toggle.text = "Log %s%s" % ["▾" if expanded else "▸", " · %d" % unread if unread > 0 else ""]
	jump_latest.text = "Latest (%d)" % unread if unread > 0 else "Latest"
	jump_latest.accessibility_name = "Jump to latest; %d unread messages" % unread

func show_latest() -> void:
	search.text = ""
	unread = 0
	history.scroll_following = true
	_refresh_history()
	call_deferred("_scroll_to_latest")

func _scroll_to_latest() -> void:
	if not is_inside_tree(): return
	history.get_v_scroll_bar().value = history.get_v_scroll_bar().max_value
	_sync_unread()

func _restore_scroll(previous: float) -> void:
	if not is_inside_tree(): return
	var bar := history.get_v_scroll_bar()
	bar.value = previous
