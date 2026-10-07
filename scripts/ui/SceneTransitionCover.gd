extends CanvasLayer
## Keeps the last presented frame on screen across a scene change.
##
## SceneTree removes the outgoing scene at once but adds the incoming scene only
## at the next frame's scene flush. A change requested from a timer, tween or
## deferred callback runs after that flush, so one frame renders with no scene:
## the gray clear color. AppRouter arms this cover before every change. It shows
## a snapshot of the last frame until the incoming scene has been drawn under it
## once, then fades out (instantly with reduced motion). The fade runs on wall
## time from the first frame after that draw, so a long first frame of the new
## scene does not swallow it.

signal released(scene_path: String)

const COVER_LAYER := 120
const FADE_MSEC := 120
const NOMINAL_FRAME_MSEC := 16
const MAX_HOLD_MSEC := 10000
const BACKDROP_COLOR := Color(0.008, 0.016, 0.027, 1.0)

const STATE_IDLE := "idle"
const STATE_HOLDING := "holding"
const STATE_AWAITING_DRAW := "awaiting_draw"
const STATE_FADING := "fading"

var _root: Control
var _backdrop: ColorRect
var _snapshot_rect: TextureRect
var _state := STATE_IDLE
var _target_scene_path := ""
var _armed_msec := 0
var _fade_started_msec := -1
var _forced_mode := ""
var _arm_count := 0
var _release_count := 0
var _cancel_count := 0
var _timeout_count := 0
var _last_capture_ok := false
var _last_capture_msec := 0.0
var _last_hold_msec := 0
var _last_released_scene_path := ""


func _ready() -> void:
	layer = COVER_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "CoverRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = BACKDROP_COLOR
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_backdrop)
	_snapshot_rect = TextureRect.new()
	_snapshot_rect.name = "LastFrame"
	_snapshot_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_snapshot_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_snapshot_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_snapshot_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_snapshot_rect)
	_hide_cover()
	set_process(false)


## Covers the screen before AppRouter changes to scene_path. Returns false when
## no cover is shown (headless runs, or disabled for validation).
func arm(scene_path: String) -> bool:
	if not _enabled():
		return false
	_arm_count += 1
	_target_scene_path = scene_path
	if _state in [STATE_HOLDING, STATE_AWAITING_DRAW]:
		# A redirect while covered: the screen already shows the snapshot.
		_state = STATE_HOLDING
		return true
	_capture_last_frame()
	_state = STATE_HOLDING
	_armed_msec = Time.get_ticks_msec()
	_root.modulate = Color.WHITE
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	var tree := get_tree()
	if not tree.scene_changed.is_connected(_on_scene_changed):
		tree.scene_changed.connect(_on_scene_changed)
	set_process(true)
	return true


## Drops the cover at once, for a scene change that failed to start.
func cancel() -> void:
	if _state == STATE_IDLE:
		return
	_cancel_count += 1
	_finish()


func is_covering() -> bool:
	return _state != STATE_IDLE


func validation_set_mode(mode: String) -> void:
	_forced_mode = mode if mode in ["enabled", "disabled"] else ""
	if _forced_mode == "disabled":
		cancel()


func validation_snapshot() -> Dictionary:
	return {
		"state": _state,
		"visible": visible,
		"alpha": _root.modulate.a if _root != null else 0.0,
		"target_scene_path": _target_scene_path,
		"forced_mode": _forced_mode,
		"enabled": _enabled(),
		"arm_count": _arm_count,
		"release_count": _release_count,
		"cancel_count": _cancel_count,
		"timeout_count": _timeout_count,
		"last_capture_ok": _last_capture_ok,
		"last_capture_msec": _last_capture_msec,
		"last_hold_msec": _last_hold_msec,
		"last_released_scene_path": _last_released_scene_path,
	}


func _enabled() -> bool:
	if _forced_mode != "":
		return _forced_mode == "enabled"
	return DisplayServer.get_name() != "headless"


func _capture_last_frame() -> void:
	_last_capture_ok = false
	_snapshot_rect.texture = null
	if DisplayServer.get_name() == "headless":
		return
	var started := Time.get_ticks_usec()
	# Until the next draw the root texture still holds the last presented frame.
	var image := get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		_snapshot_rect.texture = ImageTexture.create_from_image(image)
		_last_capture_ok = true
	_last_capture_msec = (Time.get_ticks_usec() - started) / 1000.0


func _on_scene_changed() -> void:
	if _state != STATE_HOLDING:
		return
	var scene := get_tree().current_scene
	if scene == null or (_target_scene_path != "" and String(scene.scene_file_path) != _target_scene_path):
		return
	_state = STATE_AWAITING_DRAW
	# The incoming scene draws under the cover in this frame; reveal it after.
	if DisplayServer.get_name() == "headless":
		get_tree().process_frame.connect(_begin_fade, CONNECT_ONE_SHOT)
	else:
		RenderingServer.frame_post_draw.connect(_begin_fade, CONNECT_ONE_SHOT)


func _process(_delta: float) -> void:
	if _state == STATE_IDLE:
		set_process(false)
		return
	var now := Time.get_ticks_msec()
	if _state == STATE_FADING:
		if _fade_started_msec < 0:
			# This frame is the first to show the new scene through the cover.
			_fade_started_msec = now - NOMINAL_FRAME_MSEC
		var progress := float(now - _fade_started_msec) / float(FADE_MSEC)
		if progress >= 1.0:
			_finish()
		else:
			_root.modulate.a = 1.0 - progress
		return
	if now - _armed_msec > MAX_HOLD_MSEC:
		_timeout_count += 1
		_finish()


func _begin_fade() -> void:
	if _state != STATE_AWAITING_DRAW:
		return
	_last_hold_msec = Time.get_ticks_msec() - _armed_msec
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if FADE_MSEC <= 0 or SettingsService.reduced_motion_enabled():
		_finish()
		return
	_state = STATE_FADING
	_fade_started_msec = -1


func _finish() -> void:
	var released_path := _target_scene_path
	_state = STATE_IDLE
	_hide_cover()
	_target_scene_path = ""
	_last_released_scene_path = released_path
	_release_count += 1
	set_process(false)
	var tree := get_tree()
	if tree != null and tree.scene_changed.is_connected(_on_scene_changed):
		tree.scene_changed.disconnect(_on_scene_changed)
	if RenderingServer.frame_post_draw.is_connected(_begin_fade):
		RenderingServer.frame_post_draw.disconnect(_begin_fade)
	if tree != null and tree.process_frame.is_connected(_begin_fade):
		tree.process_frame.disconnect(_begin_fade)
	released.emit(released_path)


func _hide_cover() -> void:
	visible = false
	if _root != null:
		_root.modulate = Color.WHITE
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _snapshot_rect != null:
		_snapshot_rect.texture = null
