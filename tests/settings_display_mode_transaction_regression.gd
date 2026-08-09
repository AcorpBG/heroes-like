extends Node

const REPORT_ID := "SETTINGS_DISPLAY_MODE_TRANSACTION_REGRESSION"
const SAVE_FAILURE_ENV := "HEROES_LIKE_DISPLAY_CHANGE_FORCE_SAVE_FAILURE"

var _original_settings := {}
var _original_file := {}
var _original_failure_env := ""

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_original_settings = SettingsService.ensure_settings().duplicate(true)
	_original_file = _file_state(SettingsService.SETTINGS_FILE)
	_original_failure_env = OS.get_environment(SAVE_FAILURE_ENV)
	OS.unset_environment(SAVE_FAILURE_ENV)
	SettingsService.revert_display_change("test_setup")

	var fixture := SettingsService.ensure_settings().duplicate(true)
	fixture["presentation"]["mode"] = SettingsService.PRESENTATION_WINDOWED
	fixture["presentation"]["resolution"] = "1280x720"
	SettingsService.settings = fixture
	SettingsService.apply_settings()
	if SettingsService.save_settings() != SettingsService.SETTINGS_FILE:
		_fail("Could not persist the committed display fixture.")
		return
	await _settle()

	var committed := SettingsService.settings.duplicate(true)
	var committed_file := _file_state(SettingsService.SETTINGS_FILE)
	var committed_runtime := _current_runtime_snapshot()
	var preview: Dictionary = SettingsService.preview_display_change(
		SettingsService.PRESENTATION_BORDERLESS,
		"2560x1440",
		2.0
	)
	if not _expect(bool(preview.get("ok", false)) and SettingsService.display_change_pending(), "Preview did not enter pending state", preview):
		return
	var preview_snapshot: Dictionary = SettingsService.display_change_snapshot()
	if not _expect(SettingsService.settings == committed, "Preview mutated committed settings", preview_snapshot):
		return
	if not _expect(_file_state(SettingsService.SETTINGS_FILE) == committed_file, "Preview changed config bytes before Keep", preview_snapshot):
		return
	if not _expect(String(preview_snapshot.get("prior_mode", "")) == SettingsService.PRESENTATION_WINDOWED, "Preview lost prior mode", preview_snapshot):
		return
	if not _expect(String(preview_snapshot.get("prior_resolution", "")) == "1280x720", "Preview lost prior resolution", preview_snapshot):
		return
	if not _assert_clamped_preview(preview_snapshot):
		return

	var reverted: Dictionary = SettingsService.revert_display_change("explicit_test_revert")
	await _settle()
	if not _expect(bool(reverted.get("ok", false)) and bool(reverted.get("reverted", false)), "Explicit Revert did not report rollback", reverted):
		return
	if not _expect(not SettingsService.display_change_pending(), "Explicit Revert left a pending transaction", SettingsService.display_change_snapshot()):
		return
	if not _expect(SettingsService.settings == committed and _file_state(SettingsService.SETTINGS_FILE) == committed_file, "Explicit Revert changed committed settings or config bytes", reverted):
		return
	if not _expect(_current_runtime_snapshot() == committed_runtime, "Explicit Revert did not restore the exact runtime display state", {"expected": committed_runtime, "actual": _current_runtime_snapshot()}):
		return

	var first_preview: Dictionary = SettingsService.preview_display_change(
		SettingsService.PRESENTATION_BORDERLESS,
		"1600x900",
		2.0
	)
	if not _expect(bool(first_preview.get("ok", false)), "First replacement preview failed", first_preview):
		return
	var replaced: Dictionary = SettingsService.preview_display_change(
		SettingsService.PRESENTATION_WINDOWED,
		"2560x1440",
		2.0
	)
	if not _expect(bool(replaced.get("ok", false)) and bool(replaced.get("replaced", false)), "Second preview did not safely replace the first", replaced):
		return
	var replacement_snapshot: Dictionary = SettingsService.display_change_snapshot()
	if not _expect(SettingsService.display_change_pending() and replacement_snapshot.get("prior_runtime", {}) == committed_runtime, "Second preview did not retain the original committed runtime baseline", replacement_snapshot):
		return
	if not _expect(SettingsService.settings == committed and _file_state(SettingsService.SETTINGS_FILE) == committed_file, "Second preview mutated committed state", replacement_snapshot):
		return
	SettingsService.revert_display_change("second_preview_test_revert")
	await _settle()
	if not _expect(_current_runtime_snapshot() == committed_runtime, "Second-preview Revert did not restore the original runtime", SettingsService.display_change_snapshot()):
		return

	var keep_preview: Dictionary = SettingsService.preview_display_change(
		SettingsService.PRESENTATION_BORDERLESS,
		"1600x900",
		2.0
	)
	if not _expect(bool(keep_preview.get("ok", false)), "Keep preview failed", keep_preview):
		return
	var kept: Dictionary = SettingsService.confirm_display_change()
	await _settle()
	if not _expect(bool(kept.get("ok", false)) and bool(kept.get("confirmed", false)), "Keep did not commit the candidate", kept):
		return
	if not _expect(not SettingsService.display_change_pending(), "Keep left a pending transaction", SettingsService.display_change_snapshot()):
		return
	if not _expect(SettingsService.presentation_mode_id() == SettingsService.PRESENTATION_BORDERLESS and SettingsService.presentation_resolution_id() == "1600x900", "Keep committed the wrong display candidate", kept):
		return
	var kept_file := _file_state(SettingsService.SETTINGS_FILE)
	if not _expect(kept_file != committed_file, "Keep did not persist changed config bytes", kept):
		return
	SettingsService.settings = {}
	SettingsService.load_settings()
	await _settle()
	if not _expect(SettingsService.presentation_mode_id() == SettingsService.PRESENTATION_BORDERLESS and SettingsService.presentation_resolution_id() == "1600x900", "Kept display candidate did not survive reload", SettingsService.settings):
		return

	var kept_settings := SettingsService.settings.duplicate(true)
	kept_file = _file_state(SettingsService.SETTINGS_FILE)
	var kept_runtime := _current_runtime_snapshot()
	var timeout_preview: Dictionary = SettingsService.preview_display_change(
		SettingsService.PRESENTATION_WINDOWED,
		"1280x720",
		0.1
	)
	if not _expect(bool(timeout_preview.get("ok", false)) and SettingsService.display_change_countdown_seconds() == 1, "Short timeout preview did not expose its countdown", timeout_preview):
		return
	await get_tree().create_timer(0.3).timeout
	await _settle()
	if not _expect(not SettingsService.display_change_pending(), "Expired preview did not time out", SettingsService.display_change_snapshot()):
		return
	if not _expect(SettingsService.settings == kept_settings and _file_state(SettingsService.SETTINGS_FILE) == kept_file, "Timeout changed committed settings or config bytes", SettingsService.display_change_snapshot()):
		return
	if not _expect(_current_runtime_snapshot() == kept_runtime, "Timeout did not restore the exact runtime display state", {"expected": kept_runtime, "actual": _current_runtime_snapshot()}):
		return

	OS.set_environment(SAVE_FAILURE_ENV, "1")
	var failure_preview: Dictionary = SettingsService.preview_display_change(
		SettingsService.PRESENTATION_WINDOWED,
		"1280x720",
		2.0
	)
	if not _expect(bool(failure_preview.get("ok", false)), "Save-failure preview could not start", failure_preview):
		return
	var failed_keep: Dictionary = SettingsService.confirm_display_change()
	OS.unset_environment(SAVE_FAILURE_ENV)
	await _settle()
	if not _expect(not bool(failed_keep.get("ok", true)) and not SettingsService.display_change_pending(), "Injected save failure did not fail closed", failed_keep):
		return
	if not _expect(SettingsService.settings == kept_settings and _file_state(SettingsService.SETTINGS_FILE) == kept_file, "Injected save failure changed committed settings or config bytes", failed_keep):
		return
	if not _expect(_current_runtime_snapshot() == kept_runtime, "Injected save failure did not restore the exact runtime display state", {"expected": kept_runtime, "actual": _current_runtime_snapshot()}):
		return

	_restore_original_settings()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"preview_preserved_committed_state": true,
		"keep_persisted_reload": true,
		"revert_restored_exact_runtime": true,
		"timeout_restored_exact_runtime": true,
		"second_preview_safe": true,
		"usable_size_clamped": true,
		"aspect_preserved": true,
		"save_failure_restored_exact": true,
	})])
	get_tree().quit(0)

func _assert_clamped_preview(snapshot: Dictionary) -> bool:
	var requested: Vector2i = snapshot.get("requested_size", Vector2i.ZERO)
	var applied: Vector2i = snapshot.get("applied_size", Vector2i.ZERO)
	if not _expect(requested == Vector2i(2560, 1440), "Preview snapshot lost the authored requested size", snapshot):
		return false
	if not _expect(applied.x > 0 and applied.y > 0 and applied.x <= requested.x and applied.y <= requested.y, "Preview applied an unusable or oversized window", snapshot):
		return false
	var screen := int(snapshot.get("current_runtime", {}).get("screen", DisplayServer.window_get_current_screen()))
	var usable := DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x > 0 and usable.size.y > 0:
		var uniform_scale := minf(1.0, minf(
			float(usable.size.x) / float(requested.x),
			float(usable.size.y) / float(requested.y)
		))
		var expected := Vector2i(
			maxi(1, int(floor(float(requested.x) * uniform_scale))),
			maxi(1, int(floor(float(requested.y) * uniform_scale)))
		)
		if not _expect(applied == expected, "Windowed/borderless preview did not uniformly clamp to the usable monitor rectangle", {"requested": requested, "applied": applied, "usable": usable, "expected": expected}):
			return false
	return true

func _current_runtime_snapshot() -> Dictionary:
	return SettingsService.display_change_snapshot().get("current_runtime", {}).duplicate(true)

func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _expect(condition: bool, message: String, details: Variant = {}) -> bool:
	if condition:
		return true
	_fail("%s: %s" % [message, JSON.stringify(details)])
	return false

func _restore_original_settings() -> void:
	SettingsService.revert_display_change("test_cleanup")
	if bool(_original_file.get("exists", false)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SettingsService.SETTINGS_DIR))
		var file := FileAccess.open(SettingsService.SETTINGS_FILE, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_original_file.get("bytes", PackedByteArray()))
			file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SettingsService.SETTINGS_FILE))
	SettingsService.settings = _original_settings.duplicate(true)
	SettingsService.apply_settings()
	if _original_failure_env == "":
		OS.unset_environment(SAVE_FAILURE_ENV)
	else:
		OS.set_environment(SAVE_FAILURE_ENV, _original_failure_env)

func _fail(message: String) -> void:
	_restore_original_settings()
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
