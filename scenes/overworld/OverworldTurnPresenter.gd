extends Control

signal completed
var _map_view: Control
var _events: Array = []
var _elapsed := 0.0
var _duration := 0.0
var _skip := false
var _banner: PanelContainer
var _caption: Label
var _progress: ProgressBar
var current_event: Dictionary = {}
var played_events: Array = []
var _turn_caption := ""

func start(map_view: Control, encounters: Array, events: Array) -> void:
	_map_view = map_view
	_events = events.duplicate()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	_banner = PanelContainer.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_banner.position = Vector2(size.x*0.5-280,16)
	_banner.size = Vector2(560,76)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.055,0.065,0.96)
	style.border_color = Color(0.75,0.60,0.30)
	style.set_border_width_all(1)
	style.content_margin_left=18
	style.content_margin_right=18
	style.content_margin_top=12
	style.content_margin_bottom=12
	_banner.add_theme_stylebox_override("panel",style)
	add_child(_banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	_banner.add_child(row)
	var box := VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(box)
	_caption=Label.new()
	_caption.add_theme_font_size_override("font_size",18)
	_caption.add_theme_color_override("font_color",Color(1,0.91,0.70))
	_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_caption)
	_progress=ProgressBar.new()
	_progress.custom_minimum_size.y=4
	_progress.show_percentage=false
	box.add_child(_progress)
	var skip:=Button.new()
	skip.text="»"
	skip.tooltip_text="Skip remaining turn animations (Esc / Confirm)"
	skip.custom_minimum_size=Vector2(42,40)
	skip.add_theme_font_size_override("font_size",26)
	skip.accessibility_name="Skip remaining turn animations"
	skip.pressed.connect(skip_playback)
	row.add_child(skip)
	skip.grab_focus()
	_map_view.begin_turn_playback(encounters)
	_next()

func skip_playback() -> void:
	_skip=true

func _process(delta: float) -> void:
	if _map_view==null: return
	_elapsed+=delta
	var fraction:=clampf(_elapsed/maxf(_duration,0.01),0,1)
	_map_view.advance_turn_playback(fraction)
	_progress.value=fraction*100
	_banner.modulate.a=1.0 if SettingsService.reduced_motion_enabled() else clampf(fraction*5,0.25,1)
	if _skip or _elapsed>=_duration: _next()

func _next() -> void:
	if _events.is_empty() or _skip:
		_map_view.end_turn_playback()
		_map_view=null
		set_process(false)
		completed.emit()
		queue_free()
		return
	current_event=_events.pop_front()
	played_events.append(current_event.duplicate(true))
	if current_event.get("kind")=="turn": _turn_caption=String(current_event.get("caption",""))
	_caption.text=_turn_caption if current_event.get("kind")=="turn" else _turn_caption+"\n"+String(current_event.get("caption",""))
	_caption.accessibility_name=_caption.text
	_elapsed=0
	_duration=0.30 if current_event.get("kind")=="move" else 0.85
	_map_view.show_turn_playback_event(current_event)
