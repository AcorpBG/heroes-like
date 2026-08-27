extends Control

const FrontierVisualKitScript = preload("res://scripts/ui/FrontierVisualKit.gd")

const STATUS_BACKDROP_PATHS := {
	"victory": "res://art/results/runtime/backdrops/outcome_victory.png",
	"defeat": "res://art/results/runtime/backdrops/outcome_defeat.png",
}
const STATUS_BACKDROPS := {
	"victory": preload("res://art/results/runtime/backdrops/outcome_victory.png"),
	"defeat": preload("res://art/results/runtime/backdrops/outcome_defeat.png"),
}
const DEFAULT_FALLBACK_COLOR := Color(0.07, 0.08, 0.10, 1.0)
const SCENIC_VEIL_COLOR := Color(0.018, 0.024, 0.032, 0.24)
const STATUS_AMBIENT_MODEL := "deterministic_status_epilogue_drift"
const STATUS_AMBIENT_DRAW_ORDER := ["scenic_backdrop", "scenic_veil", "status_ambient", "outcome_content"]
const STATUS_AMBIENT_PHASE_SPEED := 0.36
const STATUS_AMBIENT_STATIC_PHASE := 0.0
const STATUS_AMBIENT_PROFILES := {
	"victory": {"id": "victory_golden_drift", "kind": "golden_mote", "count": 20, "color": Color(1.0, 0.82, 0.34, 1.0), "accent_color": Color(1.0, 0.94, 0.66, 1.0), "alpha": 0.17, "radius_factor": 0.0024, "drift": Vector2(0.008, 0.013), "accent_modulus": 4},
	"defeat": {"id": "defeat_cold_ash", "kind": "ash_fall", "count": 24, "color": Color(0.70, 0.73, 0.76, 1.0), "accent_color": Color(0.88, 0.37, 0.16, 1.0), "alpha": 0.12, "radius_factor": 0.0021, "drift": Vector2(0.012, 0.016), "accent_modulus": 6},
}

var _status := "victory"
var _fallback_color := DEFAULT_FALLBACK_COLOR
var _status_ambient_phase := STATUS_AMBIENT_STATIC_PHASE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not SettingsService.settings_changed.is_connected(_on_settings_changed):
		SettingsService.settings_changed.connect(_on_settings_changed)
	_sync_processing_state()


func _exit_tree() -> void:
	if SettingsService.settings_changed.is_connected(_on_settings_changed):
		SettingsService.settings_changed.disconnect(_on_settings_changed)


func _process(delta: float) -> void:
	if not _status_ambient_should_animate():
		set_process(false)
		return
	_status_ambient_phase = fmod(_status_ambient_phase + delta * STATUS_AMBIENT_PHASE_SPEED, TAU)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func set_outcome(status: String) -> void:
	_status = status.strip_edges().to_lower()
	_sync_processing_state()


func set_fallback_color(color: Color) -> void:
	_fallback_color = color
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var destination_rect := Rect2(Vector2.ZERO, size)
	draw_rect(destination_rect, _fallback_color, true)
	var texture := _status_texture()
	if texture == null:
		return
	draw_texture_rect_region(texture, destination_rect, _cover_crop_source_rect(texture, size))
	draw_rect(destination_rect, SCENIC_VEIL_COLOR, true)
	_draw_status_ambient(destination_rect)


func validation_summary() -> Dictionary:
	var texture := _status_texture()
	var texture_size := Vector2.ZERO
	var source_rect := Rect2()
	if texture != null:
		texture_size = Vector2(texture.get_width(), texture.get_height())
		source_rect = _cover_crop_source_rect(texture, size)
	var destination_rect := Rect2(Vector2.ZERO, size)
	var ambient_profile := _status_ambient_profile()
	var ambient_enabled := _status_ambient_available()
	var reduced_motion := SettingsService.reduced_motion_enabled()
	var ambient_phase := STATUS_AMBIENT_STATIC_PHASE if reduced_motion else _status_ambient_phase
	var ambient_entries: Array = _status_ambient_entries(destination_rect, ambient_phase) if ambient_enabled else []
	var ambient_all_contained := ambient_enabled and not ambient_entries.is_empty()
	var ambient_identities: Array = []
	for entry_value in ambient_entries:
		if not entry_value is Dictionary:
			ambient_all_contained = false
			continue
		var entry: Dictionary = entry_value
		if not bool(entry.get("contained", false)):
			ambient_all_contained = false
		ambient_identities.append({
			"index": int(entry.get("index", -1)),
			"profile_id": String(entry.get("profile_id", "")),
			"kind": String(entry.get("kind", "")),
			"base_normalized": entry.get("base_normalized", Vector2(-1.0, -1.0)),
			"accent": bool(entry.get("accent", false)),
		})
	return {
		"status": _status,
		"expected_path": String(STATUS_BACKDROP_PATHS.get(_status, "")),
		"texture_path": String(texture.resource_path) if texture != null else "",
		"texture_loaded": texture != null,
		"texture_size": texture_size,
		"destination_rect": destination_rect,
		"source_rect": source_rect,
		"rendering_mode": "cover_crop_scenic_epilogue" if texture != null else "flat_palette_fallback",
		"cover_crop": texture != null,
		"stretched": false,
		"fallback": texture == null,
		"mouse_filter_ignore": mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"veil_color": SCENIC_VEIL_COLOR,
		"source_contained": _rect_contained(source_rect, Rect2(Vector2.ZERO, texture_size)) if texture != null else true,
		"destination_contained": _rect_contained(destination_rect, Rect2(Vector2.ZERO, size)),
		"ambient_model": STATUS_AMBIENT_MODEL,
		"ambient_draw_order": STATUS_AMBIENT_DRAW_ORDER.duplicate(),
		"ambient_profile_id": String(ambient_profile.get("id", "")),
		"ambient_kind": String(ambient_profile.get("kind", "")),
		"ambient_profile_count": int(ambient_profile.get("count", 0)),
		"ambient_enabled": ambient_enabled,
		"ambient_reduced_motion": reduced_motion,
		"ambient_high_contrast": FrontierVisualKitScript.high_contrast_enabled(),
		"ambient_animating": _status_ambient_should_animate(),
		"ambient_phase": ambient_phase,
		"ambient_phase_speed": STATUS_AMBIENT_PHASE_SPEED,
		"ambient_static_phase": STATUS_AMBIENT_STATIC_PHASE,
		"ambient_entry_count": ambient_entries.size(),
		"ambient_entries": ambient_entries.duplicate(true),
		"ambient_identities": ambient_identities,
		"ambient_all_contained": ambient_all_contained,
		"ambient_authority": "presentation_only_no_session_state",
	}


func _status_ambient_profile() -> Dictionary:
	var profile_value: Variant = STATUS_AMBIENT_PROFILES.get(_status, {})
	return profile_value if profile_value is Dictionary else {}


func _status_ambient_available() -> bool:
	return _status_texture() != null \
		and not _status_ambient_profile().is_empty() \
		and not FrontierVisualKitScript.high_contrast_enabled()


func _status_ambient_should_animate() -> bool:
	return _status_ambient_available() and not SettingsService.reduced_motion_enabled()


func _status_ambient_entries(destination_rect: Rect2, phase: float) -> Array:
	var profile := _status_ambient_profile()
	if profile.is_empty() or destination_rect.size.x <= 0.0 or destination_rect.size.y <= 0.0:
		return []
	var radius := clampf(minf(destination_rect.size.x, destination_rect.size.y) * float(profile.get("radius_factor", 0.0022)), 1.15, 3.0)
	var outer_radius := radius * 3.0
	var safe_inset := maxf(12.0, outer_radius + 2.0)
	var safe_rect := destination_rect.grow(-safe_inset)
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return []
	var drift: Vector2 = profile.get("drift", Vector2.ZERO)
	var accent_modulus := maxi(1, int(profile.get("accent_modulus", 4)))
	var entries: Array = []
	for index in range(int(profile.get("count", 0))):
		var base_normalized := Vector2(
			0.05 + fmod(0.131 + float(index) * 0.379, 1.0) * 0.90,
			0.05 + fmod(0.257 + float(index) * 0.587, 1.0) * 0.90
		)
		var local_phase := phase + float(index) * 1.487
		var motion_normalized := Vector2(
			sin(local_phase * 0.91 + float(index) * 0.27) * drift.x,
			cos(local_phase * 0.67 + float(index) * 0.39) * drift.y
		)
		var center := safe_rect.position + (base_normalized + motion_normalized) * safe_rect.size
		var pulse := 0.74 + 0.26 * sin(local_phase * 1.13 + 0.8)
		var accent := index % accent_modulus == 0
		var color: Color = profile.get("accent_color", Color.WHITE) if accent else profile.get("color", Color.WHITE)
		var bounds := Rect2(center - Vector2(outer_radius, outer_radius), Vector2(outer_radius * 2.0, outer_radius * 2.0))
		entries.append({
			"index": index,
			"profile_id": String(profile.get("id", "")),
			"kind": String(profile.get("kind", "")),
			"base_normalized": base_normalized,
			"center": center,
			"radius": radius,
			"outer_radius": outer_radius,
			"alpha": float(profile.get("alpha", 0.0)) * pulse,
			"color": color,
			"accent": accent,
			"bounds": bounds,
			"contained": destination_rect.encloses(bounds),
		})
	return entries


func _draw_status_ambient(destination_rect: Rect2) -> void:
	if not _status_ambient_available():
		return
	var phase := STATUS_AMBIENT_STATIC_PHASE if SettingsService.reduced_motion_enabled() else _status_ambient_phase
	for entry_value in _status_ambient_entries(destination_rect, phase):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var center: Vector2 = entry.get("center", Vector2.ZERO)
		var radius := float(entry.get("radius", 0.0))
		var alpha := float(entry.get("alpha", 0.0))
		var color: Color = entry.get("color", Color.TRANSPARENT)
		var halo_color := Color(color.r, color.g, color.b, alpha * 0.16)
		var soft_color := Color(color.r, color.g, color.b, alpha * 0.42)
		var core_color := Color(color.r, color.g, color.b, alpha)
		if String(entry.get("kind", "")) == "ash_fall":
			var fall_direction := Vector2(-0.24, 1.0).normalized()
			draw_line(center - fall_direction * radius * 1.7, center + fall_direction * radius * 1.7, soft_color, maxf(0.75, radius * 0.68), true)
			if bool(entry.get("accent", false)):
				draw_circle(center, radius * 0.62, core_color)
		else:
			draw_circle(center, radius * 3.0, halo_color)
			draw_circle(center, radius * 1.35, soft_color)
			draw_circle(center, radius * 0.50, core_color)
			if bool(entry.get("accent", false)):
				draw_line(center - Vector2(radius * 1.8, 0.0), center + Vector2(radius * 1.8, 0.0), soft_color, maxf(0.7, radius * 0.42), true)
				draw_line(center - Vector2(0.0, radius * 1.8), center + Vector2(0.0, radius * 1.8), soft_color, maxf(0.7, radius * 0.42), true)


func _sync_processing_state() -> void:
	if not _status_ambient_should_animate():
		_status_ambient_phase = STATUS_AMBIENT_STATIC_PHASE
	set_process(_status_ambient_should_animate())
	queue_redraw()


func _on_settings_changed(_settings: Dictionary) -> void:
	_sync_processing_state()


func _status_texture() -> Texture2D:
	return STATUS_BACKDROPS.get(_status, null) as Texture2D


func _cover_crop_source_rect(texture: Texture2D, destination_size: Vector2) -> Rect2:
	var texture_size := Vector2(texture.get_width(), texture.get_height())
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or destination_size.x <= 0.0 or destination_size.y <= 0.0:
		return Rect2(Vector2.ZERO, texture_size)
	var cover_scale := maxf(destination_size.x / texture_size.x, destination_size.y / texture_size.y)
	var visible_size := destination_size / cover_scale
	return Rect2((texture_size - visible_size) * 0.5, visible_size)


func _rect_contained(inner: Rect2, outer: Rect2) -> bool:
	return (
		inner.position.x >= outer.position.x - 0.01
		and inner.position.y >= outer.position.y - 0.01
		and inner.end.x <= outer.end.x + 0.01
		and inner.end.y <= outer.end.y + 0.01
	)
