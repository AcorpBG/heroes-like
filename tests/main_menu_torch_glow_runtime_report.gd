extends Node

const REPORT_ID := "MAIN_MENU_TORCH_GLOW_RUNTIME_REPORT"

var _failed := false
var _original_settings: Dictionary = {}
var _authority_before: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	SettingsService.ensure_settings()
	_original_settings = SettingsService.settings.duplicate(true)
	_set_accessibility(false, false)
	var shell: Control = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var glow := shell.get_node_or_null("%TorchGlow") as Control
	if not _require(glow != null, "Main Menu is missing its passive painted-torch glow layer."):
		_finish(shell)
		return
	_authority_before = _authority_snapshot()
	var standard: Dictionary = glow.call("validation_snapshot")
	if not _require(_standard_contract_exact(standard, glow), "Standard torch glow contract is not exact: %s" % standard):
		_finish(shell)
		return
	await get_tree().create_timer(0.12).timeout
	await get_tree().process_frame
	var animated: Dictionary = glow.call("validation_snapshot")
	if not _require(float(animated.get("pulse_phase", 0.0)) > float(standard.get("pulse_phase", -1.0)) and animated.get("centers", []) == standard.get("centers", []), "Standard torch glow did not animate in place: %s" % animated):
		_finish(shell)
		return

	_set_accessibility(true, false)
	var reduced: Dictionary = glow.call("validation_snapshot")
	await get_tree().process_frame
	var reduced_after: Dictionary = glow.call("validation_snapshot")
	if not _require(bool(reduced.get("visible", false)) and not bool(reduced.get("processing", true)) and is_zero_approx(float(reduced.get("pulse_phase", -1.0))) and reduced_after == reduced, "Reduced Motion did not hold one exact static torch glow: %s / %s" % [reduced, reduced_after]):
		_finish(shell)
		return

	_set_accessibility(false, true)
	var high_contrast: Dictionary = glow.call("validation_snapshot")
	if not _require(not bool(high_contrast.get("visible", true)) and not bool(high_contrast.get("processing", true)) and bool(high_contrast.get("high_contrast", false)), "High Contrast did not hide the decorative torch glow: %s" % high_contrast):
		_finish(shell)
		return

	_set_accessibility(false, false)
	var restored: Dictionary = glow.call("validation_snapshot")
	if not _require(_standard_contract_exact(restored, glow) and int(restored.get("signal_connection_count", 0)) == 1, "Standard presentation did not restore one deduplicated torch-glow lifecycle: %s" % restored):
		_finish(shell)
		return
	SettingsService.settings = _original_settings.duplicate(true)
	SettingsService.apply_settings()
	SettingsService.settings_changed.emit(SettingsService.settings.duplicate(true))
	if not _require(_authority_snapshot() == _authority_before, "Torch-glow presentation changed settings, save, campaign, session, route, input, or file authority."):
		_finish(shell)
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "anchors": standard.get("anchors", []), "radius": standard.get("radius", 0.0), "ring_count": standard.get("ring_count", 0), "standard_animated": true, "reduced_motion_static": true, "high_contrast_hidden": true, "authority_exact": true})])
	_finish(shell)


func _standard_contract_exact(snapshot: Dictionary, glow: Control) -> bool:
	var anchors: Array = snapshot.get("anchors", [])
	var centers: Array = snapshot.get("centers", [])
	return bool(snapshot.get("visible", false)) and bool(snapshot.get("processing", false)) and not bool(snapshot.get("reduced_motion", true)) and not bool(snapshot.get("high_contrast", true)) and anchors.size() == 2 and (anchors[0] as Vector2).is_equal_approx(Vector2(0.829, 0.426)) and (anchors[1] as Vector2).is_equal_approx(Vector2(0.996, 0.426)) and centers.size() == 2 and (centers[0] as Vector2).is_equal_approx(Vector2(glow.size.x * 0.829, glow.size.y * 0.426)) and (centers[1] as Vector2).is_equal_approx(Vector2(glow.size.x * 0.996, glow.size.y * 0.426)) and is_equal_approx(float(snapshot.get("radius", 0.0)), 62.0 * glow.size.y / 1080.0) and int(snapshot.get("ring_count", 0)) == 10 and is_equal_approx(float(snapshot.get("pulse_min", 0.0)), 0.82) and is_equal_approx(float(snapshot.get("pulse_max", 0.0)), 1.0) and int(snapshot.get("mouse_filter", -1)) == Control.MOUSE_FILTER_IGNORE and int(snapshot.get("focus_mode", -1)) == Control.FOCUS_NONE and int(snapshot.get("signal_connection_count", 0)) == 1


func _set_accessibility(reduced_motion: bool, high_contrast: bool) -> void:
	var candidate: Dictionary = SettingsService.settings.duplicate(true)
	var accessibility: Dictionary = candidate.get("accessibility", {}).duplicate(true)
	accessibility["reduce_motion"] = reduced_motion
	accessibility["high_contrast_ui"] = high_contrast
	candidate["accessibility"] = accessibility
	SettingsService.settings = candidate
	SettingsService.apply_settings()
	SettingsService.settings_changed.emit(SettingsService.settings.duplicate(true))


func _authority_snapshot() -> Dictionary:
	var settings_snapshot: Dictionary = SettingsService.validation_settings_transaction_snapshot()
	var settings_path := String(settings_snapshot.get("settings_file", ""))
	var active_session = SessionState.active_session
	return {"settings": (settings_snapshot.get("settings", {}) as Dictionary).duplicate(true), "committed": (settings_snapshot.get("committed_settings", {}) as Dictionary).duplicate(true), "input": _canonical_input_map(settings_snapshot.get("input_map", {})), "file": FileAccess.get_file_as_bytes(settings_path) if settings_path != "" and FileAccess.file_exists(settings_path) else PackedByteArray(), "save": SaveService.validation_summary_cache_snapshot(), "campaign": CampaignProgression.storage_state(), "session": active_session.to_dict() if active_session != null else {}, "route": AppRouter.validation_active_play_return_snapshot()}


func _canonical_input_map(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {}
	for key in source:
		var row: Dictionary = source[key] if source[key] is Dictionary else {}
		var events := []
		for event in row.get("events", []):
			if event is InputEvent:
				events.append(event.as_text())
		result[String(key)] = {"exists": bool(row.get("exists", false)), "deadzone": float(row.get("deadzone", 0.5)), "events": events}
	return result


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failed = true
	push_error(message)
	return false


func _finish(shell: Control) -> void:
	SettingsService.settings = _original_settings.duplicate(true)
	SettingsService.apply_settings()
	SettingsService.settings_changed.emit(SettingsService.settings.duplicate(true))
	if is_instance_valid(shell):
		shell.queue_free()
	get_tree().quit(1 if _failed else 0)
