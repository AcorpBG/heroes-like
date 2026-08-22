extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const SCENARIO_ID := "ninefold-confluence"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_window_size := get_window().size
	var original_active_session: Dictionary = SessionState.current_payload()
	var rows: Array[Dictionary] = []
	for viewport_size in VIEWPORT_SIZES:
		var row := await _run_case(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			await _finish_failure("Map Editor canvas invalid-audio row failed.", row, original_window_size, original_active_session)
			return
	get_window().size = original_window_size
	await _settle()
	if SessionState.current_payload() != original_active_session:
		await _finish_failure("Map Editor canvas invalid-audio matrix changed the active session.", {}, original_window_size, original_active_session)
		return
	print("MAP_EDITOR_CANVAS_FAILED_ACTION_AUDIO_REPORT %s" % JSON.stringify({
		"ok": true,
		"viewports": [[1280, 720], [1920, 1080]],
		"physical_controller_rows": rows.size(),
		"failed_remove_invalid_audio": true,
		"success_unavailable_validation_silent": true,
		"save_version": SessionDataScript.SAVE_VERSION,
		"rows": rows,
	}))
	get_tree().quit(0)


func _run_case(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await _settle()
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}

	var shell = load("res://scenes/editor/MapEditorShell.tscn").instantiate()
	shell.set("validation_skip_initial_package_index", true)
	add_child(shell)
	await _settle()
	var map_view := shell.get_node_or_null("%Map") as Control
	if map_view == null or not shell.has_method("validation_load_legacy_authored_scenario_for_dev"):
		return await _free_case(shell, {"ok": false, "failure": "editor_surface_missing"})

	UiAudio.validation_reset()
	map_view.grab_focus()
	await _settle()
	await _press_joypad_button(JOY_BUTTON_A)
	var unavailable_silent: bool = UiAudio.validation_records().is_empty() and shell.get("_session") == null
	if not unavailable_silent:
		return await _free_case(shell, {"ok": false, "failure": "unavailable_not_silent", "audio": UiAudio.validation_records()})

	var loaded: Dictionary = shell.call("validation_load_legacy_authored_scenario_for_dev", SCENARIO_ID)
	if not bool(loaded.get("ok", false)):
		return await _free_case(shell, {"ok": false, "failure": "authored_load", "snapshot": loaded})
	var working_session = shell.get("_session")
	var empty_tile := _first_tile_without_family(working_session, "towns")
	if empty_tile.x < 0:
		return await _free_case(shell, {"ok": false, "failure": "empty_town_tile_missing"})

	var working_before_validation: Dictionary = working_session.to_dict()
	UiAudio.validation_reset()
	var validation_failure: Dictionary = shell.call("validation_remove_object", empty_tile.x, empty_tile.y, "town")
	var validation_only_silent: bool = (
		not bool(validation_failure.get("ok", true))
		and UiAudio.validation_records().is_empty()
		and working_session.to_dict() == working_before_validation
	)
	if not validation_only_silent:
		return await _free_case(shell, {
			"ok": false,
			"failure": "validation_only_not_silent",
			"result": validation_failure,
			"audio": UiAudio.validation_records(),
		})

	shell.call("validation_select_tile", empty_tile.x, empty_tile.y)
	shell.call("validation_select_object_family", "town")
	shell.call("validation_set_tool", "remove_object")
	map_view.grab_focus()
	await _settle()
	var selected_before: Dictionary = shell.call("validation_snapshot")
	var expected_message := "No Town placement at %d,%d." % [empty_tile.x, empty_tile.y]
	var working_before_failure: Dictionary = working_session.to_dict()
	var active_before_failure: Dictionary = SessionState.current_payload()
	var settings_before_failure: Dictionary = _canonical_settings_transaction()
	var cache_before_failure: Dictionary = SaveService.validation_summary_cache_snapshot()
	UiAudio.validation_reset()
	await _press_joypad_button(JOY_BUTTON_A)
	var failed_snapshot: Dictionary = shell.call("validation_snapshot")
	var failed_records: Array = UiAudio.validation_records()
	var invalid_record: Dictionary = failed_records[0] if failed_records.size() == 1 and failed_records[0] is Dictionary else {}
	var semantic_pending: Dictionary = (shell.get("_editor_map_cursor_semantic_pending") as Dictionary).duplicate(true)
	var semantic_timer := shell.get("_editor_map_cursor_semantic_timer") as Timer
	var semantic_live := shell.get_node_or_null("%EditorMapCursorLive") as Label
	var failed_exact: bool = (
		failed_records.size() == 1
		and String(invalid_record.get("cue_id", "")) == "ui_invalid"
		and String(invalid_record.get("source", "")) == "MapEditorShell._record_editor_map_action_result"
		and bool(invalid_record.get("played", false))
		and String(invalid_record.get("playback_source", "")) == "imported_wav"
		and String(invalid_record.get("asset_path", "")) == "res://art/audio/runtime/ui/invalid.wav"
		and String(invalid_record.get("role", "")) == "invalid_action"
		and int(invalid_record.get("duration_msec", 0)) == 150
		and int(invalid_record.get("stream_mix_rate", 0)) == 44100
		and bool(invalid_record.get("stream_stereo", false))
		and int(invalid_record.get("stream_loop_mode", -1)) == AudioStreamWAV.LOOP_DISABLED
		and int(invalid_record.get("imported_asset_count", 0)) == 1
		and int(invalid_record.get("generated_fallback_count", -1)) == 0
		and Dictionary(invalid_record.get("metadata", {})) == {
			"lane": "canvas",
			"tool": "remove_object",
			"tile": {"x": empty_tile.x, "y": empty_tile.y},
			"message": expected_message,
		}
		and String(failed_snapshot.get("status_text", "")) == expected_message
		and String(failed_snapshot.get("tool", "")) == "remove_object"
		and failed_snapshot.get("selected_tile", {}) == {"x": empty_tile.x, "y": empty_tile.y}
		and working_session.to_dict() == working_before_failure
		and SessionState.current_payload() == active_before_failure
		and _canonical_settings_transaction() == settings_before_failure
		and SaveService.validation_summary_cache_snapshot() == cache_before_failure
		and get_viewport().gui_get_focus_owner() == map_view
		and semantic_live != null
		and semantic_live.text == "Map action result at %d,%d: %s" % [empty_tile.x, empty_tile.y, expected_message]
		and String(semantic_pending.get("kind", "")) == "result_clear"
		and semantic_timer != null
		and not semantic_timer.is_stopped()
		and is_equal_approx(semantic_timer.wait_time, 1.2)
	)
	if not failed_exact:
		var failed_diagnostics := {
			"audio_count": failed_records.size() == 1,
			"metadata_exact": Dictionary(invalid_record.get("metadata", {})) == {"lane": "canvas", "tool": "remove_object", "tile": {"x": empty_tile.x, "y": empty_tile.y}, "message": expected_message},
			"status_exact": String(failed_snapshot.get("status_text", "")) == expected_message,
			"tool_exact": String(failed_snapshot.get("tool", "")) == "remove_object",
			"tile_exact": failed_snapshot.get("selected_tile", {}) == {"x": empty_tile.x, "y": empty_tile.y},
			"working_authority_exact": working_session.to_dict() == working_before_failure,
			"active_authority_exact": SessionState.current_payload() == active_before_failure,
			"settings_authority_exact": _canonical_settings_transaction() == settings_before_failure,
			"cache_authority_exact": SaveService.validation_summary_cache_snapshot() == cache_before_failure,
			"focus_exact": get_viewport().gui_get_focus_owner() == map_view,
			"semantic_live_exact": semantic_live != null and semantic_live.text == "Map action result at %d,%d: %s" % [empty_tile.x, empty_tile.y, expected_message],
			"semantic_pending_exact": String(semantic_pending.get("kind", "")) == "result_clear",
			"semantic_timer_exact": semantic_timer != null and not semantic_timer.is_stopped() and is_equal_approx(semantic_timer.wait_time, 1.2),
		}
		return await _free_case(shell, {
			"ok": false,
			"failure": "physical_failure_not_exact",
			"selected_before": selected_before,
			"snapshot": failed_snapshot,
			"audio": failed_records,
			"semantic_live": semantic_live.text if semantic_live != null else "",
			"semantic_pending": semantic_pending,
			"checks": failed_diagnostics,
		})

	shell.call("validation_set_tool", "inspect")
	map_view.grab_focus()
	await _settle()
	var working_before_success: Dictionary = working_session.to_dict()
	UiAudio.validation_reset()
	await _press_joypad_button(JOY_BUTTON_A)
	var success_snapshot: Dictionary = shell.call("validation_snapshot")
	var success_silent: bool = (
		UiAudio.validation_records().is_empty()
		and String(success_snapshot.get("tool", "")) == "inspect"
		and String(success_snapshot.get("status_text", "")) == "Inspected tile %d,%d." % [empty_tile.x, empty_tile.y]
		and working_session.to_dict() == working_before_success
		and SessionState.current_payload() == active_before_failure
		and _canonical_settings_transaction() == settings_before_failure
		and SaveService.validation_summary_cache_snapshot() == cache_before_failure
		and get_viewport().gui_get_focus_owner() == map_view
	)
	if not success_silent:
		return await _free_case(shell, {
			"ok": false,
			"failure": "successful_inspect_not_silent",
			"snapshot": success_snapshot,
			"audio": UiAudio.validation_records(),
		})

	return await _free_case(shell, {
		"ok": true,
		"viewport": [viewport_size.x, viewport_size.y],
		"tile": [empty_tile.x, empty_tile.y],
		"failed_remove_invalid_audio": true,
		"successful_inspect_silent": true,
		"unavailable_silent": true,
		"validation_only_silent": true,
		"authority_exact": true,
	})


func _first_tile_without_family(session, array_key: String) -> Vector2i:
	var occupied := {}
	var placements = session.overworld.get(array_key, [])
	if placements is Array:
		for placement_value in placements:
			if not (placement_value is Dictionary):
				continue
			var placement: Dictionary = placement_value
			var position_value = placement.get("position", {})
			var x := int(position_value.get("x", placement.get("x", -1))) if position_value is Dictionary else int(placement.get("x", -1))
			var y := int(position_value.get("y", placement.get("y", -1))) if position_value is Dictionary else int(placement.get("y", -1))
			occupied["%d,%d" % [x, y]] = true
	var map_size := OverworldRules.derive_map_size(session)
	for y in range(map_size.y):
		for x in range(map_size.x):
			if not occupied.has("%d,%d" % [x, y]):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _canonical_settings_transaction() -> Dictionary:
	var transaction: Dictionary = SettingsService.validation_settings_transaction_snapshot()
	transaction["input_map"] = _canonical_input_map(transaction.get("input_map", {}))
	return transaction


func _canonical_input_map(value: Variant) -> Dictionary:
	var input_map: Dictionary = value if value is Dictionary else {}
	var result := {}
	for action_value in input_map:
		var row: Dictionary = input_map.get(action_value, {}) if input_map.get(action_value, {}) is Dictionary else {}
		var events := []
		for event_value in row.get("events", []):
			if event_value is InputEvent:
				events.append(_serialize_input_event(event_value))
		result[String(action_value)] = {
			"exists": bool(row.get("exists", false)),
			"deadzone": float(row.get("deadzone", 0.5)),
			"events": events,
		}
	return result


func _serialize_input_event(input_event: InputEvent) -> Dictionary:
	var properties := {}
	for property_value in input_event.get_property_list():
		var property: Dictionary = property_value
		if (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var property_name := String(property.get("name", ""))
		if property_name == "" or property_name == "script":
			continue
		properties[property_name] = var_to_str(input_event.get(property_name))
	return {
		"class": input_event.get_class(),
		"text": input_event.as_text(),
		"properties": properties,
	}


func _press_joypad_button(button_index: int) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.button_index = button_index
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventJoypadButton.new()
	released.button_index = button_index
	released.pressed = false
	Input.parse_input_event(released)
	await _settle()


func _free_case(shell: Node, result: Dictionary) -> Dictionary:
	if is_instance_valid(shell):
		shell.queue_free()
	await _settle()
	return result


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _finish_failure(message: String, details: Dictionary, original_window_size: Vector2i, original_active_session: Dictionary) -> void:
	get_window().size = original_window_size
	SessionState.restore_session(original_active_session)
	await _settle()
	push_error("%s %s" % [message, JSON.stringify(details)])
	get_tree().quit(1)
