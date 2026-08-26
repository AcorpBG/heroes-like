extends Node

const REPORT_ID := "MAIN_MENU_STAGE_DOCK_REVEAL_RUNTIME_REPORT"

var _failed := false
var _original_settings: Dictionary = {}
var _authority_before: Dictionary = {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	SettingsService.ensure_settings()
	_original_settings = SettingsService.settings.duplicate(true)
	_set_memory_reduced_motion(false)
	var shell: Control = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	_authority_before = _authority_snapshot()

	shell.call("validation_open_campaign_stage")
	var start: Dictionary = shell.call("validation_stage_dock_reveal_snapshot")
	if not _require(_standard_start_exact(start), "Standard stage-dock reveal did not begin with the exact passive opacity contract: %s" % start):
		_finish(shell)
		return
	await get_tree().create_timer(0.08).timeout
	await get_tree().process_frame
	var middle: Dictionary = shell.call("validation_stage_dock_reveal_snapshot")
	if not _require(bool(middle.get("running", false)) and float(middle.get("alpha", 0.0)) > 0.12 and float(middle.get("alpha", 1.0)) < 1.0, "Stage-dock reveal did not ease through a visible intermediate opacity: %s" % middle):
		_finish(shell)
		return
	await get_tree().create_timer(0.12).timeout
	await get_tree().process_frame
	var completed: Dictionary = shell.call("validation_stage_dock_reveal_snapshot")
	if not _require(bool(completed.get("visible", false)) and not bool(completed.get("running", true)) and is_equal_approx(float(completed.get("alpha", 0.0)), 1.0) and String(completed.get("focus_owner", "")) == "CampaignList", "Stage-dock reveal did not finish opaque with unchanged entry focus: %s" % completed):
		_finish(shell)
		return

	var close_button := shell.get_node_or_null("%CloseStageDock") as Button
	if not _require(close_button != null, "Stage-dock reveal fixture is missing the existing Close command."):
		_finish(shell)
		return
	close_button.pressed.emit()
	await get_tree().process_frame
	var closed: Dictionary = shell.call("validation_stage_dock_reveal_snapshot")
	if not _require(not bool(closed.get("visible", true)) and not bool(closed.get("running", true)) and is_equal_approx(float(closed.get("alpha", 0.0)), 1.0), "Closing the board did not synchronously reset the reveal: %s" % closed):
		_finish(shell)
		return

	_set_memory_reduced_motion(true)
	shell.call("validation_open_settings_stage")
	var reduced: Dictionary = shell.call("validation_stage_dock_reveal_snapshot")
	await get_tree().process_frame
	var reduced_after_frame: Dictionary = shell.call("validation_stage_dock_reveal_snapshot")
	if not _require(
		bool(reduced.get("visible", false))
		and bool(reduced.get("reduced_motion", false))
		and not bool(reduced.get("running", true))
		and is_equal_approx(float(reduced.get("alpha", 0.0)), 1.0)
		and reduced_after_frame.get("alpha", 0.0) == reduced.get("alpha", -1.0)
		and String(reduced_after_frame.get("focus_owner", "")) == "PresentationModePicker",
		"Reduced Motion did not present the Settings board immediately with unchanged focus timing: %s / %s" % [reduced, reduced_after_frame]
	):
		_finish(shell)
		return

	SettingsService.settings = _original_settings.duplicate(true)
	SettingsService.apply_settings()
	var authority_after: Dictionary = _authority_snapshot()
	if not _require(authority_after == _authority_before, "Stage-dock reveal roundtrip changed settings, save, campaign, session, route, input, or file authority."):
		_finish(shell)
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"duration_seconds": start.get("duration_seconds", 0.0),
		"start_alpha": start.get("start_alpha", 0.0),
		"middle_alpha": middle.get("alpha", 0.0),
		"completed_alpha": completed.get("alpha", 0.0),
		"transition": start.get("transition", ""),
		"reduced_motion_immediate": true,
		"close_reset_exact": true,
		"authority_exact": true,
	})])
	_finish(shell)

func _standard_start_exact(snapshot: Dictionary) -> bool:
	return (
		bool(snapshot.get("visible", false))
		and not bool(snapshot.get("reduced_motion", true))
		and bool(snapshot.get("running", false))
		and is_equal_approx(float(snapshot.get("duration_seconds", 0.0)), 0.16)
		and is_equal_approx(float(snapshot.get("start_alpha", 0.0)), 0.12)
		and is_equal_approx(float(snapshot.get("alpha", 0.0)), 0.12)
		and String(snapshot.get("transition", "")) == "quad_out"
		and int(snapshot.get("current_tab", -1)) == 0
	)

func _set_memory_reduced_motion(enabled: bool) -> void:
	var candidate: Dictionary = SettingsService.settings.duplicate(true)
	var accessibility: Dictionary = candidate.get("accessibility", {}).duplicate(true)
	accessibility["reduce_motion"] = enabled
	candidate["accessibility"] = accessibility
	SettingsService.settings = candidate
	SettingsService.apply_settings()

func _authority_snapshot() -> Dictionary:
	var settings_snapshot: Dictionary = SettingsService.validation_settings_transaction_snapshot()
	var settings_path := String(settings_snapshot.get("settings_file", ""))
	var active_session = SessionState.active_session
	return {
		"settings": (settings_snapshot.get("settings", {}) as Dictionary).duplicate(true),
		"committed_settings": (settings_snapshot.get("committed_settings", {}) as Dictionary).duplicate(true),
		"last_result": (settings_snapshot.get("last_result", {}) as Dictionary).duplicate(true),
		"input_map": _canonical_input_map(settings_snapshot.get("input_map", {})),
		"settings_file": FileAccess.get_file_as_bytes(settings_path) if settings_path != "" and FileAccess.file_exists(settings_path) else PackedByteArray(),
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
		"campaign": {
			"storage": CampaignProgression.storage_state(),
			"selected_campaign_id": CampaignProgression.selected_campaign_id(),
			"selected_scenario_id": CampaignProgression.selected_scenario_id(),
			"last_failure": CampaignProgression.last_failure_result(),
		},
		"session": active_session.to_dict() if active_session != null else {},
		"route": AppRouter.validation_active_play_return_snapshot(),
	}

func _canonical_input_map(value: Variant) -> Dictionary:
	var input_map: Dictionary = value if value is Dictionary else {}
	var result := {}
	for action_value in input_map:
		var row_value: Variant = input_map.get(action_value, {})
		var row: Dictionary = row_value if row_value is Dictionary else {}
		var events := []
		for event_value in row.get("events", []):
			if event_value is InputEvent:
				events.append(event_value.as_text())
		result[String(action_value)] = {"exists": bool(row.get("exists", false)), "deadzone": float(row.get("deadzone", 0.5)), "events": events}
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
	if is_instance_valid(shell):
		shell.queue_free()
	get_tree().quit(1 if _failed else 0)
