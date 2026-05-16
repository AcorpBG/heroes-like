extends Node

const REPORT_ID := "RANDOM_MAP_SKIRMISH_MENU_BUTTON_2P_RETRY_REPORT"
const SEED := "client-menu-small-2p-10184"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	SessionState.reset_session()
	ContentService.clear_generated_scenario_drafts()
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	if shell.has_method("validation_open_skirmish_stage"):
		shell.call("validation_open_skirmish_stage")
	await get_tree().process_frame

	_set_line_edit(shell, "%GeneratedSeed", SEED)
	_select_option_metadata(shell, "%GeneratedSizePicker", "homm3_small")
	_select_option_metadata(shell, "%GeneratedPlayerCountPicker", 2)
	_select_option_metadata(shell, "%GeneratedWaterPicker", "land")
	_select_option_metadata(shell, "%GeneratedUndergroundToggle", "surface")
	await get_tree().process_frame
	await get_tree().process_frame

	var button: Button = shell.get_node("%StartGeneratedSkirmish")
	var before := _snapshot(shell, button)
	if button.disabled:
		_fail("StartGeneratedSkirmish was disabled before pressing.", before)
		return

	button.pressed.emit()
	var started := false
	var active_session = null
	for _frame in range(900):
		await get_tree().process_frame
		active_session = SessionState.ensure_active_session()
		if active_session != null and active_session.scenario_id != "" and bool(active_session.flags.get("generated_random_map", false)):
			started = true
			break

	var after := _snapshot(shell, button)
	active_session = SessionState.ensure_active_session()
	if not started:
		_fail("Pressed StartGeneratedSkirmish, but no generated skirmish session became active.", {"before": before, "after": after})
		return

	var retry_status: Dictionary = active_session.flags.get("generated_random_map_retry_status", {}) if active_session.flags.get("generated_random_map_retry_status", {}) is Dictionary else {}
	if int(retry_status.get("attempt_count", 0)) < 3:
		_fail("Regression seed should exercise post-second-attempt retry coverage.", {"before": before, "after": after, "retry_status": retry_status})
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"pressed_real_button_signal": true,
		"seed": SEED,
		"before": before,
		"after": after,
		"active_scenario_id": active_session.scenario_id,
		"active_launch_mode": active_session.launch_mode,
		"active_generated_random_map": bool(active_session.flags.get("generated_random_map", false)),
		"retry_status": retry_status,
		"provenance_schema": String(active_session.flags.get("generated_random_map_provenance", {}).get("schema_id", "")),
	})])
	get_tree().quit(0)

func _set_line_edit(root: Node, path: String, text: String) -> void:
	var edit: LineEdit = root.get_node(path)
	edit.text = text
	edit.text_changed.emit(text)

func _select_option_metadata(root: Node, path: String, target: Variant) -> void:
	var picker: OptionButton = root.get_node(path)
	for index in range(picker.item_count):
		var metadata: Variant = picker.get_item_metadata(index)
		if str(metadata) == str(target):
			picker.select(index)
			picker.item_selected.emit(index)
			return

func _snapshot(shell: Node, button: Button) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot") if shell.has_method("validation_generated_random_map_snapshot") else {}
	var setup: Dictionary = snapshot.get("setup", {}) if snapshot.get("setup", {}) is Dictionary else {}
	var controls: Dictionary = snapshot.get("controls", {}) if snapshot.get("controls", {}) is Dictionary else {}
	return {
		"button_disabled": button.disabled,
		"button_text": button.text,
		"button_tooltip": button.tooltip_text,
		"controls": {
			"seed": String(controls.get("seed", "")),
			"size_class_id": String(controls.get("size_class_id", "")),
			"player_count": int(controls.get("player_count", 0)),
			"water_mode": String(controls.get("water_mode", "")),
			"underground": bool(controls.get("underground", false)),
			"start_enabled": bool(controls.get("start_generated_skirmish_enabled", false)),
		},
		"setup": {
			"ok": bool(setup.get("ok", false)),
			"normalized_seed": String(setup.get("normalized_seed", "")),
			"template_id": String(setup.get("template_id", "")),
			"profile_id": String(setup.get("profile_id", "")),
			"failure_handoff": String(setup.get("failure_handoff", "")),
			"retry_status": setup.get("retry_status", {}),
		},
	}

func _fail(message: String, detail: Dictionary) -> void:
	push_error("%s failed: %s %s" % [REPORT_ID, message, JSON.stringify(detail)])
	get_tree().quit(1)
