class_name SystemSaveWrittenCuePresenter
extends Node

const AnimationCueCatalogScript = preload("res://scripts/core/AnimationCueCatalog.gd")
const SystemFeedbackVfxIconScript = preload("res://scenes/shared/SystemFeedbackVfxIcon.gd")

const EVENT_ID := "system_save_written"
const CUE_ID := "cue_system_save_written"
const NORMAL_STATE := "save_confirm"
const REDUCED_STATE := "save_icon_static"
const NORMAL_ACCENT := Color(1.0, 0.88, 0.42, 1.0)
const REDUCED_ACCENT := Color(0.78, 1.0, 0.78, 1.0)

var _save_button: Button
var _status_control: Control
var _surface := ""
var _active := false
var _started_msec := 0
var _duration_msec := 0
var _activation_count := 0
var _last_policy: Dictionary = {}
var _last_result: Dictionary = {}
var _button_base_modulate := Color.WHITE
var _status_base_modulate := Color.WHITE
var _button_text_at_publish := ""
var _status_text_at_publish := ""
var _status_tooltip_at_publish := ""
var _vfx_icon: SystemFeedbackVfxIcon


func configure(save_button: Button, status_control: Control, surface: String) -> bool:
	if save_button == null or status_control == null or String(surface).strip_edges() == "":
		return false
	_save_button = save_button
	_status_control = status_control
	_surface = String(surface).strip_edges()
	_vfx_icon = SystemFeedbackVfxIconScript.new()
	if not _vfx_icon.configure(_save_button):
		_vfx_icon = null
		return false
	set_process(false)
	return true


func present(save_result: Dictionary, manual_slot: int) -> Dictionary:
	if not _configured() or not _valid_success(save_result, manual_slot):
		return {}
	var policy: Dictionary = AnimationCueCatalogScript.cue_playback_policy_for_event(
		EVENT_ID,
		SettingsService.animation_preferences()
	)
	if not _valid_policy(policy):
		return {}
	if _active:
		_restore_visuals()
	_button_base_modulate = _save_button.modulate
	_status_base_modulate = _status_control.modulate
	_button_text_at_publish = _save_button.text
	_status_text_at_publish = String(_status_control.get("text"))
	_status_tooltip_at_publish = _status_control.tooltip_text
	_activation_count += 1
	_started_msec = Time.get_ticks_msec()
	_duration_msec = maxi(1, int(policy.get("max_duration_ms", 700)))
	_last_policy = policy.duplicate(true)
	_last_result = {
		"event_id": EVENT_ID,
		"cue_id": CUE_ID,
		"surface": _surface,
		"manual_slot": manual_slot,
		"path": String(save_result.get("path", "")),
		"message": String(save_result.get("message", "")),
		"summary": (save_result.get("summary", {}) as Dictionary).duplicate(true),
	}.duplicate(true)
	_vfx_icon.present(
		EVENT_ID,
		policy.get("selected_vfx_cue_ids", []) if policy.get("selected_vfx_cue_ids", []) is Array else [],
		bool(policy.get("allows_large_motion", true))
	)
	_active = true
	_apply_visuals(0.0)
	set_process(true)
	return validation_snapshot()


func _process(_delta: float) -> void:
	if not _active:
		set_process(false)
		return
	var elapsed := maxi(0, Time.get_ticks_msec() - _started_msec)
	if elapsed >= _duration_msec:
		_active = false
		_restore_visuals()
		set_process(false)
		return
	_apply_visuals(float(elapsed) / float(_duration_msec))


func _configured() -> bool:
	return is_instance_valid(_save_button) and is_instance_valid(_status_control) and _surface != ""


func _valid_success(save_result: Dictionary, manual_slot: int) -> bool:
	if not SaveService.get_manual_slot_ids().has(manual_slot):
		return false
	if not bool(save_result.get("ok", false)) or String(save_result.get("path", "")) == "":
		return false
	var summary_value: Variant = save_result.get("summary", {})
	if not (summary_value is Dictionary):
		return false
	var summary: Dictionary = summary_value
	return (
		String(summary.get("slot_type", "")) == SaveService.SLOT_TYPE_MANUAL
		and String(summary.get("slot_id", "")) == str(manual_slot)
	)


func _valid_policy(policy: Dictionary) -> bool:
	var selected_state := String(policy.get("selected_animation_state", ""))
	return (
		String(policy.get("event_id", "")) == EVENT_ID
		and String(policy.get("cue_id", "")) == CUE_ID
		and String(policy.get("selected_playback_policy", "")) in ["instant", "fast_resolve"]
		and String(policy.get("selected_blocking_policy", "")) == "never_blocks_input"
		and selected_state in [NORMAL_STATE, REDUCED_STATE, "save_icon_instant"]
	)


func _apply_visuals(progress: float) -> void:
	if not _configured():
		return
	var allows_large_motion := bool(_last_policy.get("allows_large_motion", true))
	var accent := NORMAL_ACCENT if allows_large_motion else REDUCED_ACCENT
	var amount := 0.72 if not allows_large_motion else (0.34 + 0.38 * sin(clampf(progress, 0.0, 1.0) * PI))
	_save_button.modulate = _button_base_modulate.lerp(accent, amount)
	_status_control.modulate = _status_base_modulate.lerp(accent, amount)
	if is_instance_valid(_vfx_icon):
		_vfx_icon.apply_progress(progress)


func _restore_visuals() -> void:
	if is_instance_valid(_save_button):
		_save_button.modulate = _button_base_modulate
	if is_instance_valid(_status_control):
		_status_control.modulate = _status_base_modulate
	if is_instance_valid(_vfx_icon):
		_vfx_icon.clear()


func validation_snapshot() -> Dictionary:
	return {
		"configured": _configured(),
		"active": _active,
		"activation_count": _activation_count,
		"surface": _surface,
		"duration_msec": _duration_msec,
		"event_id": String(_last_result.get("event_id", "")),
		"cue_id": String(_last_result.get("cue_id", "")),
		"manual_slot": int(_last_result.get("manual_slot", 0)),
		"path": String(_last_result.get("path", "")),
		"message": String(_last_result.get("message", "")),
		"summary": (_last_result.get("summary", {}) as Dictionary).duplicate(true),
		"policy": _last_policy.duplicate(true),
		"button_text_unchanged": is_instance_valid(_save_button) and _save_button.text == _button_text_at_publish,
		"status_text_unchanged": is_instance_valid(_status_control) and String(_status_control.get("text")) == _status_text_at_publish,
		"status_tooltip_unchanged": is_instance_valid(_status_control) and _status_control.tooltip_text == _status_tooltip_at_publish,
		"button_modulate": _save_button.modulate if is_instance_valid(_save_button) else Color.TRANSPARENT,
		"status_modulate": _status_control.modulate if is_instance_valid(_status_control) else Color.TRANSPARENT,
		"button_base_modulate": _button_base_modulate,
		"status_base_modulate": _status_base_modulate,
		"vfx_asset": _vfx_icon.validation_snapshot() if is_instance_valid(_vfx_icon) else {},
	}
