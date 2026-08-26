extends Node

const REPORT_ID := "CUSTOM_MOUSE_CURSOR_RUNTIME_REPORT"
const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")

var _failed := false
var _original_settings: Dictionary = {}
var _original_transaction: Dictionary = {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	SettingsService.ensure_settings()
	_original_settings = SettingsService.settings.duplicate(true)
	_original_transaction = _transaction_authority()
	var expected_texture := ResourceLoader.load(FrontierVisualKit.POINTER_CURSOR_PATH, "Texture2D") as Texture2D
	if not _require(expected_texture != null and expected_texture.get_size() == FrontierVisualKit.POINTER_CURSOR_SIZE, "The authored pointer texture did not import at the exact hardware-cursor size."):
		_finish()
		return

	_apply_memory_high_contrast(false)
	var standard_before: Dictionary = FrontierVisualKit.validation_pointer_cursor_snapshot()
	if not _require(_standard_cursor_exact(standard_before, expected_texture), "Standard contrast did not install the exact authored hardware pointer: %s" % standard_before):
		_finish()
		return

	_apply_memory_high_contrast(true)
	var high_contrast: Dictionary = FrontierVisualKit.validation_pointer_cursor_snapshot()
	if not _require(
		String(high_contrast.get("mode", "")) == "system_high_contrast"
		and not bool(high_contrast.get("custom_active", true))
		and bool(high_contrast.get("high_contrast", false))
		and int(high_contrast.get("apply_count", 0)) == int(standard_before.get("apply_count", 0)) + 1,
		"High contrast did not restore the platform arrow exactly: %s" % high_contrast
	):
		_finish()
		return

	_apply_memory_high_contrast(false)
	var restored_standard: Dictionary = FrontierVisualKit.validation_pointer_cursor_snapshot()
	if not _require(
		_standard_cursor_exact(restored_standard, expected_texture)
		and int(restored_standard.get("apply_count", 0)) == int(high_contrast.get("apply_count", 0)) + 1
		and int(restored_standard.get("texture_instance_id", 0)) == int(standard_before.get("texture_instance_id", -1)),
		"Returning to standard contrast did not restore the same cached hardware pointer: %s" % restored_standard
	):
		_finish()
		return

	SettingsService.settings = _original_settings.duplicate(true)
	SettingsService.apply_settings()
	var final_transaction: Dictionary = _transaction_authority()
	if not _require(final_transaction == _original_transaction, "Pointer contrast roundtrip changed settings, input-map, display, or settings-file authority."):
		_finish()
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"asset_path": FrontierVisualKit.POINTER_CURSOR_PATH,
		"texture_size": standard_before.get("texture_size", Vector2.ZERO),
		"hotspot": standard_before.get("hotspot", Vector2.ZERO),
		"standard_mode": standard_before.get("mode", ""),
		"high_contrast_mode": high_contrast.get("mode", ""),
		"restored_mode": restored_standard.get("mode", ""),
		"settings_input_file_authority_exact": true,
	})])
	_finish()

func _apply_memory_high_contrast(enabled: bool) -> void:
	var candidate: Dictionary = SettingsService.settings.duplicate(true)
	var accessibility: Dictionary = candidate.get("accessibility", {}).duplicate(true)
	accessibility["high_contrast_ui"] = enabled
	candidate["accessibility"] = accessibility
	SettingsService.settings = candidate
	SettingsService.apply_settings()

func _standard_cursor_exact(snapshot: Dictionary, expected_texture: Texture2D) -> bool:
	return (
		String(snapshot.get("asset_path", "")) == FrontierVisualKit.POINTER_CURSOR_PATH
		and bool(snapshot.get("asset_exists", false))
		and bool(snapshot.get("texture_loaded", false))
		and snapshot.get("texture_size", Vector2.ZERO) == FrontierVisualKit.POINTER_CURSOR_SIZE
		and int(snapshot.get("texture_instance_id", 0)) == expected_texture.get_instance_id()
		and snapshot.get("hotspot", Vector2.ZERO) == FrontierVisualKit.POINTER_CURSOR_HOTSPOT
		and int(snapshot.get("shape", -1)) == int(Input.CURSOR_ARROW)
		and String(snapshot.get("mode", "")) == "custom_standard"
		and bool(snapshot.get("custom_active", false))
		and not bool(snapshot.get("high_contrast", true))
	)

func _transaction_authority() -> Dictionary:
	var snapshot: Dictionary = SettingsService.validation_settings_transaction_snapshot()
	var settings_path := String(snapshot.get("settings_file", ""))
	return {
		"settings": (snapshot.get("settings", {}) as Dictionary).duplicate(true),
		"committed_settings": (snapshot.get("committed_settings", {}) as Dictionary).duplicate(true),
		"last_result": (snapshot.get("last_result", {}) as Dictionary).duplicate(true),
		"runtime_display": (snapshot.get("runtime_display", {}) as Dictionary).duplicate(true),
		"input_map": _canonical_input_map(snapshot.get("input_map", {})),
		"live_exists": bool(snapshot.get("live_exists", false)),
		"candidate_exists": bool(snapshot.get("candidate_exists", false)),
		"backup_exists": bool(snapshot.get("backup_exists", false)),
		"settings_bytes": FileAccess.get_file_as_bytes(settings_path) if settings_path != "" and FileAccess.file_exists(settings_path) else PackedByteArray(),
	}

func _canonical_input_map(value: Variant) -> Dictionary:
	var input_map: Dictionary = value if value is Dictionary else {}
	var result := {}
	for action_value in input_map:
		var action_id := String(action_value)
		var row_value: Variant = input_map.get(action_value, {})
		var row: Dictionary = row_value if row_value is Dictionary else {}
		var serialized_events := []
		var events_value: Variant = row.get("events", [])
		if events_value is Array:
			for event_value in events_value:
				if event_value is InputEvent:
					serialized_events.append(event_value.as_text())
		result[action_id] = {
			"exists": bool(row.get("exists", false)),
			"deadzone": float(row.get("deadzone", 0.5)),
			"events": serialized_events,
		}
	return result

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failed = true
	push_error(message)
	return false

func _finish() -> void:
	SettingsService.settings = _original_settings.duplicate(true)
	SettingsService.apply_settings()
	get_tree().quit(1 if _failed else 0)
