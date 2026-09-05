class_name SystemLoadResumedCuePresenter
extends Node

const AnimationCueCatalogScript = preload("res://scripts/core/AnimationCueCatalog.gd")
const SystemFeedbackVfxIconScript = preload("res://scenes/shared/SystemFeedbackVfxIcon.gd")

const EVENT_ID := "system_load_resumed"
const CUE_ID := "cue_system_load_resumed"
const AUDIO_CUE_ID := "audio_placeholder_load_resume"
const NORMAL_STATE := "load_resume"
const REDUCED_STATE := "load_icon_static"
const NORMAL_ACCENT := Color(0.48, 0.86, 1.0, 1.0)
const REDUCED_ACCENT := Color(0.78, 0.92, 1.0, 1.0)

var _status_control: Control
var _icon_host: Control
var _surface := ""
var _active := false
var _started_msec := 0
var _duration_msec := 0
var _activation_count := 0
var _last_policy: Dictionary = {}
var _last_result: Dictionary = {}
var _audio_playback_record: Dictionary = {}
var _status_base_modulate := Color.WHITE
var _status_text_at_publish := ""
var _status_tooltip_at_publish := ""
var _vfx_icon: SystemFeedbackVfxIcon


func configure(status_control: Control, icon_host: Control, surface: String) -> bool:
	if status_control == null or icon_host == null or surface.strip_edges() == "":
		return false
	_status_control = status_control
	_icon_host = icon_host
	_surface = surface.strip_edges()
	_vfx_icon = SystemFeedbackVfxIconScript.new()
	if not _vfx_icon.configure(_icon_host):
		_vfx_icon = null
		return false
	set_process(false)
	return true


func present(load_result: Dictionary) -> Dictionary:
	if not _configured() or not _valid_result(load_result):
		return {}
	var policy: Dictionary = AnimationCueCatalogScript.cue_playback_policy_for_event(
		EVENT_ID,
		SettingsService.animation_preferences()
	)
	if not _valid_policy(policy):
		return {}
	if _active:
		_restore_visuals()
	_status_base_modulate = _status_control.modulate
	_status_text_at_publish = String(_status_control.get("text"))
	_status_tooltip_at_publish = _status_control.tooltip_text
	_activation_count += 1
	_started_msec = Time.get_ticks_msec()
	_duration_msec = maxi(1, int(policy.get("max_duration_ms", 700)))
	_last_policy = policy.duplicate(true)
	_last_result = load_result.duplicate(true)
	_audio_playback_record = PresentationAudio.play_cue(AUDIO_CUE_ID, "SystemLoadResumedCuePresenter", {
		"event_id": EVENT_ID,
		"sequence": int(load_result.get("sequence", 0)),
		"surface": _surface,
	})
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
	return is_instance_valid(_status_control) and is_instance_valid(_icon_host) and _surface != ""


func _valid_result(load_result: Dictionary) -> bool:
	var summary_identity: Dictionary = load_result.get("summary_identity", {}) if load_result.get("summary_identity", {}) is Dictionary else {}
	return (
		String(load_result.get("event_id", "")) == EVENT_ID
		and String(load_result.get("cue_id", "")) == CUE_ID
		and String(load_result.get("surface", "")) == _surface
		and String(load_result.get("consumed_surface", "")) == _surface
		and bool(load_result.get("consumed", false))
		and int(load_result.get("sequence", 0)) > 0
		and String(load_result.get("scenario_id", "")) != ""
		and int(load_result.get("day", 0)) > 0
		and String(load_result.get("continuity_cue", "")) != ""
		and String(summary_identity.get("slot_type", "")) in [SaveService.SLOT_TYPE_MANUAL, SaveService.SLOT_TYPE_AUTOSAVE, SaveService.SLOT_TYPE_FILE]
		and String(summary_identity.get("slot_id", "")) != ""
		and String(summary_identity.get("path", "")) != ""
	)


func _valid_policy(policy: Dictionary) -> bool:
	var selected_state := String(policy.get("selected_animation_state", ""))
	return (
		String(policy.get("event_id", "")) == EVENT_ID
		and String(policy.get("cue_id", "")) == CUE_ID
		and String(policy.get("selected_playback_policy", "")) in ["instant", "fast_resolve"]
		and String(policy.get("selected_blocking_policy", "")) == "never_blocks_input"
		and selected_state in [NORMAL_STATE, REDUCED_STATE, "load_icon_instant"]
		and policy.get("selected_audio_cue_ids", []) == [AUDIO_CUE_ID]
	)


func _apply_visuals(progress: float) -> void:
	if not _configured():
		return
	var allows_large_motion := bool(_last_policy.get("allows_large_motion", true))
	var accent := NORMAL_ACCENT if allows_large_motion else REDUCED_ACCENT
	var amount := 0.72 if not allows_large_motion else (0.34 + 0.38 * sin(clampf(progress, 0.0, 1.0) * PI))
	_status_control.modulate = _status_base_modulate.lerp(accent, amount)
	if is_instance_valid(_vfx_icon):
		_vfx_icon.apply_progress(progress)


func _restore_visuals() -> void:
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
		"sequence": int(_last_result.get("sequence", 0)),
		"scenario_id": String(_last_result.get("scenario_id", "")),
		"day": int(_last_result.get("day", 0)),
		"resume_target": String(_last_result.get("resume_target", "")),
		"continuity_cue": String(_last_result.get("continuity_cue", "")),
		"summary_identity": (_last_result.get("summary_identity", {}) as Dictionary).duplicate(true),
		"policy": _last_policy.duplicate(true),
		"audio_playback_record": _audio_playback_record.duplicate(true),
		"status_text_unchanged": is_instance_valid(_status_control) and String(_status_control.get("text")) == _status_text_at_publish,
		"status_tooltip_unchanged": is_instance_valid(_status_control) and _status_control.tooltip_text == _status_tooltip_at_publish,
		"status_modulate": _status_control.modulate if is_instance_valid(_status_control) else Color.TRANSPARENT,
		"status_base_modulate": _status_base_modulate,
		"vfx_asset": _vfx_icon.validation_snapshot() if is_instance_valid(_vfx_icon) else {},
	}
