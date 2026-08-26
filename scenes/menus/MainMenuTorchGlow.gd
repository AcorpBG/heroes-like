extends Control

const LEFT_FLAME_ANCHOR := Vector2(0.829, 0.426)
const RIGHT_FLAME_ANCHOR := Vector2(0.996, 0.426)
const BASE_RADIUS_AT_1080 := 62.0
const PULSE_SPEED := 2.2
const PULSE_MIN := 0.82
const PULSE_MAX := 1.0
const RING_COUNT := 10

var _pulse_phase := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	if not SettingsService.settings_changed.is_connected(_on_settings_changed):
		SettingsService.settings_changed.connect(_on_settings_changed)
	_sync_presentation()


func _process(delta: float) -> void:
	_pulse_phase = fmod(_pulse_phase + delta * PULSE_SPEED, TAU)
	queue_redraw()


func _draw() -> void:
	if not visible or size.x <= 0.0 or size.y <= 0.0:
		return
	var radius := BASE_RADIUS_AT_1080 * size.y / 1080.0
	var pulse := lerpf(PULSE_MIN, PULSE_MAX, 0.5 + 0.5 * sin(_pulse_phase)) if is_processing() else PULSE_MIN
	for anchor in [LEFT_FLAME_ANCHOR, RIGHT_FLAME_ANCHOR]:
		var center := Vector2(size.x * anchor.x, size.y * anchor.y)
		for ring_index in range(RING_COUNT, 0, -1):
			var ring_ratio := float(ring_index) / float(RING_COUNT)
			var ring_alpha := lerpf(0.020, 0.004, ring_ratio) * pulse
			draw_circle(center, radius * ring_ratio, Color(1.0, 0.43, 0.10, ring_alpha), true, -1.0, true)


func _on_settings_changed(_settings: Dictionary) -> void:
	_sync_presentation()


func _sync_presentation() -> void:
	visible = not SettingsService.high_contrast_ui_enabled()
	set_process(visible and not SettingsService.reduced_motion_enabled())
	if not is_processing():
		_pulse_phase = 0.0
	queue_redraw()


func validation_snapshot() -> Dictionary:
	var radius := BASE_RADIUS_AT_1080 * size.y / 1080.0
	var signal_connection_count := 0
	for connection_value in SettingsService.settings_changed.get_connections():
		var connection: Dictionary = connection_value
		var callable_value: Callable = connection.get("callable", Callable())
		if callable_value.get_object() == self:
			signal_connection_count += 1
	return {
		"visible": visible,
		"processing": is_processing(),
		"pulse_phase": _pulse_phase,
		"anchors": [LEFT_FLAME_ANCHOR, RIGHT_FLAME_ANCHOR],
		"centers": [Vector2(size.x * LEFT_FLAME_ANCHOR.x, size.y * LEFT_FLAME_ANCHOR.y), Vector2(size.x * RIGHT_FLAME_ANCHOR.x, size.y * RIGHT_FLAME_ANCHOR.y)],
		"radius": radius,
		"pulse_min": PULSE_MIN,
		"pulse_max": PULSE_MAX,
		"ring_count": RING_COUNT,
		"mouse_filter": mouse_filter,
		"focus_mode": focus_mode,
		"signal_connection_count": signal_connection_count,
		"reduced_motion": SettingsService.reduced_motion_enabled(),
		"high_contrast": SettingsService.high_contrast_ui_enabled(),
	}
