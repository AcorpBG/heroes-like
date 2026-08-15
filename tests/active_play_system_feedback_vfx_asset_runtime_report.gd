extends Node

const REPORT_ID := "ACTIVE_PLAY_SYSTEM_FEEDBACK_VFX_ASSET_RUNTIME_REPORT"
const MANIFEST_PATH := "res://content/system_feedback_vfx_manifest.json"
const SOURCE_PATH := "res://art/ui/source/system_feedback_vfx_source.png"
const VfxIconScript = preload("res://scenes/shared/SystemFeedbackVfxIcon.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const EXPECTED_ASSETS := {
	"system_save_written": {
		"cue_id": "vfx_placeholder_save_confirm",
		"fallback_id": "save_icon_static",
		"texture_path": "res://art/ui/runtime/system_feedback/save_confirm.png",
	},
	"system_load_resumed": {
		"cue_id": "vfx_placeholder_load_resume",
		"fallback_id": "load_icon_static",
		"texture_path": "res://art/ui/runtime/system_feedback/load_resume.png",
	},
}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_window_size := get_window().size
	var asset_contract := _asset_contract()
	if not bool(asset_contract.get("ok", false)):
		return _fail("System-feedback asset contract failed: %s" % JSON.stringify(asset_contract), original_window_size)
	var rows := []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_viewport(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			return _fail("System-feedback VFX failed at %s: %s" % [viewport_size, JSON.stringify(row)], original_window_size)
	get_window().size = original_window_size
	await get_tree().process_frame
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "asset_contract": asset_contract, "rows": rows})])
	get_tree().quit(0)


func _run_viewport(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}
	var host := Button.new()
	host.name = "SystemFeedbackVfxHost"
	host.position = Vector2(36.0, 28.0)
	host.size = Vector2(220.0, 44.0)
	host.text = "Authority text"
	host.tooltip_text = "Authority tooltip"
	add_child(host)
	await get_tree().process_frame
	var authority := {"text": host.text, "tooltip": host.tooltip_text, "rect": host.get_global_rect(), "minimum": host.custom_minimum_size}
	var cases := []
	for event_id_value in EXPECTED_ASSETS:
		var event_id := String(event_id_value)
		var expected: Dictionary = EXPECTED_ASSETS[event_id]
		var icon: SystemFeedbackVfxIcon = VfxIconScript.new()
		if not icon.configure(host):
			return await _finish(host, {"ok": false, "failure": "configure", "event_id": event_id})
		await get_tree().process_frame
		var normal: Dictionary = icon.present(event_id, [String(expected.get("cue_id", ""))], true)
		await get_tree().process_frame
		normal = icon.validation_snapshot()
		var normal_exact := _normal_exact(normal, authority, host, String(expected.get("texture_path", "")))
		var reduced: Dictionary = icon.present(event_id, [String(expected.get("fallback_id", ""))], false)
		await get_tree().process_frame
		reduced = icon.validation_snapshot()
		var reduced_exact := _fallback_exact(reduced, authority, host, "reduced_motion_text_tint_only")
		var missing: Dictionary = icon.present(event_id, ["vfx_missing_system_feedback"], true)
		await get_tree().process_frame
		missing = icon.validation_snapshot()
		var missing_exact := _fallback_exact(missing, authority, host, "text_tint_only")
		cases.append({"event_id": event_id, "normal": normal, "reduced": reduced, "missing": missing, "normal_exact": normal_exact, "reduced_exact": reduced_exact, "missing_exact": missing_exact})
		icon.queue_free()
		await get_tree().process_frame
		if not normal_exact or not reduced_exact or not missing_exact:
			return await _finish(host, {"ok": false, "failure": "presentation", "cases": cases})
	return await _finish(host, {"ok": true, "viewport": viewport_size, "cases": cases, "host_authority_exact": _host_authority_exact(authority, host)})


func _normal_exact(snapshot: Dictionary, authority: Dictionary, host: Control, texture_path: String) -> bool:
	var icon_rect: Rect2 = snapshot.get("icon_global_rect", Rect2())
	var host_rect: Rect2 = snapshot.get("host_global_rect", Rect2())
	return (
		bool(snapshot.get("configured", false))
		and bool(snapshot.get("imported", false))
		and bool(snapshot.get("icon_visible", false))
		and String(snapshot.get("texture_path", "")) == texture_path
		and String(snapshot.get("render_mode", "")) == "system_feedback_icon"
		and String(snapshot.get("fallback", "")) == ""
		and snapshot.get("texture_size", {}) == {"x": 512, "y": 512}
		and snapshot.get("icon_custom_minimum_size") == Vector2.ZERO
		and bool(snapshot.get("mouse_filter_ignore", false))
		and bool(snapshot.get("focus_none", false))
		and icon_rect.size == Vector2(14.0, 14.0)
		and host_rect.grow(0.5).encloses(icon_rect)
		and _host_authority_exact(authority, host)
	)


func _fallback_exact(snapshot: Dictionary, authority: Dictionary, host: Control, fallback: String) -> bool:
	return (
		bool(snapshot.get("configured", false))
		and not bool(snapshot.get("imported", false))
		and not bool(snapshot.get("icon_visible", true))
		and String(snapshot.get("fallback", "")) == fallback
		and _host_authority_exact(authority, host)
	)


func _host_authority_exact(authority: Dictionary, host: Control) -> bool:
	return host.text == String(authority.get("text", "")) and host.tooltip_text == String(authority.get("tooltip", "")) and host.get_global_rect() == authority.get("rect") and host.custom_minimum_size == authority.get("minimum")


func _asset_contract() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	var cues: Dictionary = parsed.get("cues", {}) if parsed is Dictionary and parsed.get("cues", {}) is Dictionary else {}
	var source := _load_png_image(SOURCE_PATH)
	var hashes := []
	var rows := []
	for event_id_value in EXPECTED_ASSETS:
		var event_id := String(event_id_value)
		var expected: Dictionary = EXPECTED_ASSETS[event_id]
		var cue_id := String(expected.get("cue_id", ""))
		var texture_path := String(expected.get("texture_path", ""))
		var spec: Dictionary = cues.get(cue_id, {}) if cues.get(cue_id, {}) is Dictionary else {}
		var image := _load_png_image(texture_path)
		var hash := FileAccess.get_sha256(texture_path)
		hashes.append(hash)
		rows.append({"event_id": event_id, "cue_id": cue_id, "texture_path": texture_path, "sha256": hash, "ok": String(spec.get("event_id", "")) == event_id and String(spec.get("texture_path", "")) == texture_path and String(spec.get("render_mode", "")) == "system_feedback_icon" and float(spec.get("scale", 0.0)) == 1.0 and image != null and image.get_size() == Vector2i(512, 512) and image.detect_alpha() != Image.ALPHA_NONE and hash != ""})
	var distinct_hash_count: int = hashes.duplicate().reduce(func(unique, hash): return unique + ([] if hash in unique else [hash]), []).size()
	return {"ok": source != null and source.get_size() == Vector2i(1672, 941) and source.detect_alpha() != Image.ALPHA_NONE and rows.all(func(row): return bool(row.get("ok", false))) and distinct_hash_count == 2, "source_size": source.get_size() if source != null else Vector2i.ZERO, "source_alpha": source.detect_alpha() if source != null else Image.ALPHA_NONE, "rows": rows, "distinct_hash_count": distinct_hash_count}


func _load_png_image(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return image


func _finish(host: Control, result: Dictionary) -> Dictionary:
	if host != null and is_instance_valid(host):
		host.queue_free()
		await get_tree().process_frame
	return result


func _fail(message: String, original_window_size: Vector2i) -> void:
	get_window().size = original_window_size
	push_error(message)
	get_tree().quit(1)
