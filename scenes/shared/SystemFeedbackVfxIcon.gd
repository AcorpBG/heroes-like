class_name SystemFeedbackVfxIcon
extends TextureRect

const MANIFEST_PATH := "res://content/system_feedback_vfx_manifest.json"
const SCHEMA_ID := "system_feedback_vfx_manifest_v1"
const RENDER_MODE := "system_feedback_icon"
const ICON_SIZE := Vector2(14.0, 14.0)

var _host: Control
var _state: Dictionary = {}


func configure(host: Control) -> bool:
	if host == null:
		return false
	_host = host
	name = "SystemFeedbackVfxIcon"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	custom_minimum_size = Vector2.ZERO
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -4.0 - ICON_SIZE.x
	offset_top = 2.0
	offset_right = -4.0
	offset_bottom = 2.0 + ICON_SIZE.y
	visible = false
	_host.add_child(self)
	return true


func present(event_id: String, selected_vfx_cue_ids: Array, allows_large_motion: bool) -> Dictionary:
	clear()
	var cue_id := String(selected_vfx_cue_ids[0]) if selected_vfx_cue_ids.size() == 1 else ""
	_state = {
		"manifest_path": MANIFEST_PATH,
		"event_id": event_id,
		"cue_id": cue_id,
		"texture_path": "",
		"render_mode": "",
		"imported": false,
		"fallback": "reduced_motion_text_tint_only" if not allows_large_motion else "text_tint_only",
	}
	if not allows_large_motion or event_id.strip_edges() == "" or cue_id == "":
		return validation_snapshot()
	var manifest := ContentService.load_json(MANIFEST_PATH)
	if String(manifest.get("schema_id", "")) != SCHEMA_ID:
		return validation_snapshot()
	var cues: Dictionary = manifest.get("cues", {}) if manifest.get("cues", {}) is Dictionary else {}
	var spec: Dictionary = cues.get(cue_id, {}) if cues.get(cue_id, {}) is Dictionary else {}
	_state["texture_path"] = String(spec.get("texture_path", ""))
	_state["render_mode"] = String(spec.get("render_mode", ""))
	if String(spec.get("event_id", "")) != event_id or String(spec.get("render_mode", "")) != RENDER_MODE:
		return validation_snapshot()
	var loaded = load(String(spec.get("texture_path", "")))
	if not (loaded is Texture2D):
		return validation_snapshot()
	texture = loaded
	visible = true
	_state["imported"] = true
	_state["fallback"] = ""
	_state["texture_size"] = {"x": int(loaded.get_size().x), "y": int(loaded.get_size().y)}
	return validation_snapshot()


func apply_progress(progress: float) -> void:
	if visible and texture != null:
		modulate = Color(1.0, 1.0, 1.0, 0.76 + 0.24 * sin(clampf(progress, 0.0, 1.0) * PI))


func clear() -> void:
	texture = null
	visible = false
	modulate = Color.WHITE
	_state = {}


func validation_snapshot() -> Dictionary:
	var snapshot := _state.duplicate(true)
	snapshot["configured"] = is_instance_valid(_host) and get_parent() == _host
	snapshot["icon_visible"] = visible and texture != null
	snapshot["icon_custom_minimum_size"] = custom_minimum_size
	snapshot["icon_size"] = size
	snapshot["icon_global_rect"] = get_global_rect()
	snapshot["host_global_rect"] = _host.get_global_rect() if is_instance_valid(_host) else Rect2()
	snapshot["mouse_filter_ignore"] = mouse_filter == Control.MOUSE_FILTER_IGNORE
	snapshot["focus_none"] = focus_mode == Control.FOCUS_NONE
	return snapshot
