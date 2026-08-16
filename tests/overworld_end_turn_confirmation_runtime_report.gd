extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const OverworldShellScene = preload("res://scenes/overworld/OverworldShell.tscn")

const REPORT_ID := "OVERWORLD_END_TURN_CONFIRMATION_RUNTIME_REPORT"
const AUTOSAVE_PATH := "user://saves/autosave.json"

var _original_active_session = null
var _original_autosave_states := {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_active_session = SessionState.active_session
	_original_autosave_states = _capture_file_states(_autosave_paths())
	var warned_and_stale := await _validate_warn_cancel_and_stale_boundaries()
	if warned_and_stale.is_empty():
		return
	var confirmed := await _validate_core_risk_confirm_parity()
	if confirmed.is_empty():
		return
	var same_stack_detach := await _validate_same_stack_confirm_detach_focus_safety()
	if same_stack_detach.is_empty():
		return
	var low_risk := await _validate_exhausted_low_risk_one_click()
	if low_risk.is_empty():
		return
	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"warn_cancel_and_stale": warned_and_stale,
		"confirmed_core_risk": confirmed,
		"same_stack_confirm_detach": same_stack_detach,
		"exhausted_low_risk": low_risk,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)


func _validate_warn_cancel_and_stale_boundaries() -> Dictionary:
	_clear_autosave()
	var shell = await _create_shell(_movement_order_fixture(2))
	if shell == null:
		return {}
	if not _require_hooks(shell):
		await _discard_shell(shell)
		return {}
	var session: SessionStateStoreScript.SessionData = SessionState.ensure_active_session()
	var before_request := _canonical_dictionary(session.to_dict())
	var request: Dictionary = shell.validation_request_end_turn()
	var requested: Dictionary = shell.validation_end_turn_confirmation_snapshot()
	if not bool(request.get("ok", false)) or not bool(request.get("confirmation_required", false)) \
			or not bool(requested.get("pending", false)) or not bool(requested.get("dialog_visible", false)):
		_fail("Warned first press did not open confirmation: %s" % JSON.stringify(_compact_snapshot(requested)))
		await _discard_shell(shell)
		return {}
	var reasons: Array = requested.get("warning_reasons", []) if requested.get("warning_reasons", []) is Array else []
	if not _has_reason_fragment(reasons, "movement") or not _has_reason_fragment(reasons, "order"):
		_fail("Movement/order fixture did not expose both warning families: %s" % JSON.stringify(reasons))
		await _discard_shell(shell)
		return {}
	if _canonical_dictionary(session.to_dict()) != before_request or not _zero_commit_counts(requested):
		_fail("Warned first press mutated session or called rules/autosave: %s" % JSON.stringify(_compact_snapshot(requested)))
		await _discard_shell(shell)
		return {}
	var cancel: Dictionary = shell.validation_cancel_end_turn_confirmation()
	var canceled: Dictionary = shell.validation_end_turn_confirmation_snapshot()
	if not bool(cancel.get("ok", false)) or not bool(cancel.get("canceled", false)) \
			or bool(canceled.get("pending", true)) or bool(canceled.get("dialog_visible", true)) \
			or _canonical_dictionary(session.to_dict()) != before_request or not _zero_commit_counts(canceled):
		_fail("Cancel did not preserve exact state with zero rules/autosave: %s" % JSON.stringify(_compact_snapshot(canceled)))
		await _discard_shell(shell)
		return {}

	var stale_rows := {}
	for stale_field in ["day", "status", "warning_signature"]:
		shell.validation_reset_end_turn_confirmation_state()
		var stale_request: Dictionary = shell.validation_request_end_turn()
		var stale_requested: Dictionary = shell.validation_end_turn_confirmation_snapshot()
		if not bool(stale_request.get("confirmation_required", false)) or not bool(stale_requested.get("pending", false)):
			_fail("Could not stage %s stale request." % stale_field)
			await _discard_shell(shell)
			return {}
		var original_day: int = session.day
		var original_status: String = session.scenario_status
		var original_movement: Dictionary = session.overworld.get("movement", {}).duplicate(true)
		match stale_field:
			"day":
				session.day += 1
			"status":
				session.scenario_status = "defeat"
			_:
				var movement: Dictionary = session.overworld.get("movement", {})
				movement["current"] = 0
				session.overworld["movement"] = movement
				OverworldRules.consume_command_risk_forecast(session)
		var before_confirm := _canonical_dictionary(session.to_dict())
		var stale_result: Dictionary = shell.validation_confirm_end_turn()
		var stale_snapshot: Dictionary = shell.validation_end_turn_confirmation_snapshot()
		var after_confirm := _canonical_dictionary(session.to_dict())
		var stale_fields: Array = stale_result.get("stale_fields", []) if stale_result.get("stale_fields", []) is Array else []
		var expected_stale_field: String = "warning_signature" if stale_field == "warning_signature" else stale_field
		if bool(stale_result.get("ok", true)) or bool(stale_result.get("committed", true)) \
				or String(stale_result.get("reason", "")) != "stale_request" \
				or not stale_fields.has(expected_stale_field) \
				or after_confirm != before_confirm \
				or not _zero_commit_counts(stale_snapshot):
			_fail("%s stale confirmation did not fail closed exactly: %s" % [stale_field, JSON.stringify({
					"result": _compact_result(stale_result),
					"stale_fields": stale_fields,
					"snapshot": _compact_snapshot(stale_snapshot),
					"state_difference": _first_difference(before_confirm, after_confirm),
				})])
			await _discard_shell(shell)
			return {}
		stale_rows[stale_field] = {"rejected": true, "rules_calls": 0, "autosaves": 0}
		session.day = original_day
		session.scenario_status = original_status
		session.overworld["movement"] = original_movement
		OverworldRules.normalize_overworld_state(session)

	await _discard_shell(shell)
	return {
		"warning_reasons": reasons,
		"first_press_no_mutation": true,
		"cancel_exact": true,
		"rules_calls": 0,
		"autosaves": 0,
		"stale": stale_rows,
	}


func _validate_core_risk_confirm_parity() -> Dictionary:
	_clear_autosave()
	var shell = await _create_shell(_core_risk_fixture(2))
	if shell == null or not _require_hooks(shell):
		if shell != null:
			await _discard_shell(shell)
		return {}
	var request: Dictionary = shell.validation_request_end_turn()
	var requested: Dictionary = shell.validation_end_turn_confirmation_snapshot()
	var reasons: Array = requested.get("warning_reasons", []) if requested.get("warning_reasons", []) is Array else []
	if not bool(request.get("confirmation_required", false)) or not _has_reason_fragment(reasons, "risk"):
		_fail("Unconsumed core command risk did not gate End Turn: %s" % JSON.stringify({
			"request": _compact_result(request),
			"reasons": reasons,
			"snapshot": _compact_snapshot(requested),
		}))
		await _discard_shell(shell)
		return {}
	var shell_session = SessionState.ensure_active_session()
	var control = _duplicate_session(shell_session)
	OverworldRules.consume_command_risk_forecast(control)
	var direct_result: Dictionary = OverworldRules.end_turn(control)
	var confirmed: Dictionary = shell.validation_confirm_end_turn()
	var snapshot: Dictionary = shell.validation_end_turn_confirmation_snapshot()
	var shell_rule_result: Dictionary = snapshot.get("last_rule_result", {}) if snapshot.get("last_rule_result", {}) is Dictionary else {}
	if not bool(confirmed.get("ok", false)) or not bool(confirmed.get("committed", false)) \
			or int(snapshot.get("commit_count", -1)) != 1 \
			or int(snapshot.get("rules_end_turn_call_count", -1)) != 1 \
			or int(snapshot.get("autosave_call_count", -1)) != 1:
		_fail("Valid confirmation did not commit exactly one rules call/autosave: %s" % JSON.stringify(_compact_snapshot(snapshot)))
		await _discard_shell(shell)
		return {}
	if _canonical_dictionary(shell_rule_result) != _canonical_dictionary(direct_result):
		_fail("Confirmed shell result diverged from direct OverworldRules.end_turn: %s" % JSON.stringify({
			"shell": _result_signature(shell_rule_result),
			"direct": _result_signature(direct_result),
		}))
		await _discard_shell(shell)
		return {}
	var shell_payload := _gameplay_payload(SessionState.ensure_active_session())
	var control_payload := _gameplay_payload(control)
	if shell_payload != control_payload:
		_fail("Confirmed shell gameplay state diverged from direct control: %s" % JSON.stringify({
			"shell": _session_signature(shell_payload),
			"direct": _session_signature(control_payload),
			"difference": _first_difference(control_payload, shell_payload),
		}))
		await _discard_shell(shell)
		return {}
	var saved_payload := _gameplay_payload_dictionary(SessionStateStoreScript.normalize_payload(_read_dictionary(AUTOSAVE_PATH)))
	var restored = SaveService.restore_autosave_session()
	var restored_payload := _gameplay_payload(restored) if restored != null else {}
	if saved_payload != shell_payload \
			or restored == null \
			or _session_signature(restored_payload) != _session_signature(shell_payload) \
			or SaveService.resume_target_for_session(restored) != "overworld":
		_fail("Confirmed End Turn autosave payload/restore boundary diverged: %s" % JSON.stringify({
			"restored": restored != null,
			"shell": _session_signature(shell_payload),
			"saved": _session_signature(saved_payload),
			"restored_signature": _session_signature(restored_payload),
			"saved_difference": _first_difference(shell_payload, saved_payload),
			"resume_target": SaveService.resume_target_for_session(restored) if restored != null else "",
		}))
		await _discard_shell(shell)
		return {}
	await _discard_shell(shell)
	return {
		"warning_reasons": reasons,
		"direct_result_match": true,
		"direct_gameplay_state_match": true,
		"rules_calls": 1,
		"autosaves": 1,
		"autosave_payload_exact": true,
		"autosave_restored_route_exact": true,
	}


func _validate_same_stack_confirm_detach_focus_safety() -> Dictionary:
	_clear_autosave()
	var shell = await _create_shell(_core_risk_fixture(2))
	if shell == null or not _require_hooks(shell):
		if shell != null:
			await _discard_shell(shell)
		return {}
	var shell_session = SessionState.ensure_active_session()
	var control = _duplicate_session(shell_session)
	OverworldRules.consume_command_risk_forecast(control)
	var direct_result: Dictionary = OverworldRules.end_turn(control)
	var request: Dictionary = shell.validation_request_end_turn()
	var confirmed: Dictionary = shell.validation_confirm_end_turn()
	var snapshot: Dictionary = shell.validation_end_turn_confirmation_snapshot()
	var shell_rule_result: Dictionary = snapshot.get("last_rule_result", {}) if snapshot.get("last_rule_result", {}) is Dictionary else {}
	var shell_payload := _gameplay_payload(SessionState.ensure_active_session())
	var control_payload := _gameplay_payload(control)
	if not bool(request.get("confirmation_required", false)) \
			or not bool(confirmed.get("ok", false)) \
			or not bool(confirmed.get("committed", false)) \
			or int(snapshot.get("commit_count", -1)) != 1 \
			or int(snapshot.get("rules_end_turn_call_count", -1)) != 1 \
			or int(snapshot.get("autosave_call_count", -1)) != 1 \
			or _canonical_dictionary(shell_rule_result) != _canonical_dictionary(direct_result) \
			or shell_payload != control_payload:
		_fail("Same-stack confirmation did not preserve exact End Turn authority before detach: %s" % JSON.stringify({
			"request": _compact_result(request),
			"confirmed": _compact_result(confirmed),
			"snapshot": _compact_snapshot(snapshot),
			"rule_difference": _first_difference(_canonical_dictionary(direct_result), _canonical_dictionary(shell_rule_result)),
			"session_difference": _first_difference(control_payload, shell_payload),
		}))
		await _discard_shell(shell)
		return {}
	var shell_parent: Node = shell.get_parent()
	if shell_parent == null:
		_fail("Same-stack confirmation Shell had no live parent before the detach control.")
		await _discard_shell(shell)
		return {}
	shell_parent.remove_child(shell)
	if shell.is_inside_tree():
		_fail("Same-stack confirmation Shell remained inside the tree after the detach control.")
		shell.queue_free()
		await get_tree().process_frame
		return {}
	shell.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return {
		"confirmation_required": true,
		"committed": true,
		"rules_calls": 1,
		"autosaves": 1,
		"detached_before_deferred_focus": true,
		"direct_rule_and_session_authority_exact": true,
	}


func _validate_exhausted_low_risk_one_click() -> Dictionary:
	_clear_autosave()
	var shell = await _create_shell(_exhausted_low_risk_fixture(2))
	if shell == null or not _require_hooks(shell):
		if shell != null:
			await _discard_shell(shell)
		return {}
	var result: Dictionary = shell.validation_request_end_turn()
	var snapshot: Dictionary = shell.validation_end_turn_confirmation_snapshot()
	if not bool(result.get("ok", false)) or bool(result.get("confirmation_required", true)) \
			or not bool(result.get("committed", false)) or bool(snapshot.get("pending", true)) \
			or int(snapshot.get("commit_count", -1)) != 1 \
			or int(snapshot.get("rules_end_turn_call_count", -1)) != 1 \
			or int(snapshot.get("autosave_call_count", -1)) != 1:
		_fail("Exhausted low-risk End Turn was not one-click direct: %s" % JSON.stringify({
			"result": _compact_result(result),
			"snapshot": _compact_snapshot(snapshot),
		}))
		await _discard_shell(shell)
		return {}
	await _discard_shell(shell)
	return {"confirmation_required": false, "committed": true, "rules_calls": 1, "autosaves": 1}


func _create_shell(session):
	SessionState.set_active_session(session)
	var shell = OverworldShellScene.instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	if not shell.has_method("validation_request_end_turn"):
		_fail("OverworldShell is missing validation_request_end_turn.")
		shell.queue_free()
		await get_tree().process_frame
		return null
	shell.validation_reset_end_turn_confirmation_state()
	return shell


func _discard_shell(shell) -> void:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame


func _require_hooks(shell) -> bool:
	for method_name in [
		"validation_request_end_turn",
		"validation_cancel_end_turn_confirmation",
		"validation_confirm_end_turn",
		"validation_end_turn_confirmation_snapshot",
		"validation_reset_end_turn_confirmation_state",
	]:
		if not shell.has_method(method_name):
			return _fail_bool("OverworldShell is missing confirmation hook %s." % method_name)
	return true


func _movement_order_fixture(day: int) -> SessionStateStoreScript.SessionData:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.day = day
	session.game_state = "overworld"
	session.flags["end_turn_confirmation_marker"] = "movement_order"
	_set_enemy_pressure(session, 0, "probing")
	_set_active_hero_position(session, Vector2i(1, 0))
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	return session


func _core_risk_fixture(day: int) -> SessionStateStoreScript.SessionData:
	var session = _movement_order_fixture(day)
	session.flags["end_turn_confirmation_marker"] = "core_risk"
	_set_enemy_pressure(session, 0, "probing")
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	for index in range(encounters.size()):
		var encounter = encounters[index]
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == "river_pass_reed_totemists":
			encounter["contested_by_faction_id"] = "faction_mireclaw"
			encounters[index] = encounter
	session.overworld["encounters"] = encounters
	session.overworld.erase("command_risk_forecast")
	OverworldRules.normalize_overworld_state(session)
	return session


func _exhausted_low_risk_fixture(day: int) -> SessionStateStoreScript.SessionData:
	var session = _movement_order_fixture(day)
	session.flags["end_turn_confirmation_marker"] = "exhausted_low_risk"
	var movement: Dictionary = session.overworld.get("movement", {})
	movement["current"] = 0
	session.overworld["movement"] = movement
	OverworldRules.consume_command_risk_forecast(session)
	OverworldRules.mark_runtime_normalized_transition_state(session)
	return session


func _set_enemy_pressure(session, pressure: int, posture: String) -> void:
	var states: Array = session.overworld.get("enemy_states", []) if session.overworld.get("enemy_states", []) is Array else []
	if states.is_empty():
		return
	var state: Dictionary = states[0] if states[0] is Dictionary else {}
	state["pressure"] = pressure
	state["posture"] = posture
	states[0] = state
	session.overworld["enemy_states"] = states


func _set_active_hero_position(session, position: Vector2i) -> void:
	var position_payload := {"x": position.x, "y": position.y}
	session.overworld["hero_position"] = position_payload.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position_payload.duplicate(true)
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		var candidate = heroes[index]
		if candidate is Dictionary and String(candidate.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			candidate["position"] = position_payload.duplicate(true)
			heroes[index] = candidate
	session.overworld["player_heroes"] = heroes


func _duplicate_session(session) -> SessionStateStoreScript.SessionData:
	var duplicate := SessionStateStoreScript.new_session_data()
	duplicate.from_dict(session.to_dict())
	return duplicate


func _gameplay_payload(session) -> Dictionary:
	if session == null:
		return {}
	return _gameplay_payload_dictionary(session.to_dict())


func _gameplay_payload_dictionary(value: Dictionary) -> Dictionary:
	var payload := _canonical_dictionary(value)
	var flags: Dictionary = payload.get("flags", {}) if payload.get("flags", {}) is Dictionary else {}
	flags.erase("last_action")
	payload["flags"] = flags
	var overworld: Dictionary = payload.get("overworld", {}) if payload.get("overworld", {}) is Dictionary else {}
	overworld.erase("command_briefing")
	payload["overworld"] = overworld
	return payload


func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _zero_commit_counts(snapshot: Dictionary) -> bool:
	return int(snapshot.get("commit_count", -1)) == 0 \
		and int(snapshot.get("rules_end_turn_call_count", -1)) == 0 \
		and int(snapshot.get("autosave_call_count", -1)) == 0


func _has_reason_fragment(reasons: Array, fragment: String) -> bool:
	for reason in reasons:
		if String(reason).to_lower().contains(fragment.to_lower()):
			return true
	return false


func _autosave_paths() -> Array:
	return [AUTOSAVE_PATH, "%s.candidate" % AUTOSAVE_PATH, "%s.backup" % AUTOSAVE_PATH]


func _capture_file_states(paths: Array) -> Dictionary:
	var states := {}
	for path_value in paths:
		states[String(path_value)] = _file_state(String(path_value))
	return states


func _file_state(path: String) -> Dictionary:
	return {"exists": FileAccess.file_exists(path), "bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()}


func _clear_autosave() -> void:
	for path in _autosave_paths():
		_remove_path(String(path))
	SaveService.validation_clear_summary_cache()


func _remove_path(path: String) -> void:
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true


func _canonical_dictionary(value: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	return parsed if parsed is Dictionary else {}


func _compact_snapshot(snapshot: Dictionary) -> Dictionary:
	return {
		"pending": snapshot.get("pending", false),
		"dialog_visible": snapshot.get("dialog_visible", false),
		"warning_reasons": snapshot.get("warning_reasons", []),
		"requested_day": snapshot.get("requested_day", -1),
		"requested_status": snapshot.get("requested_status", ""),
		"requested_warning_signature": snapshot.get("requested_warning_signature", ""),
		"current_warning_signature": snapshot.get("current_warning_signature", ""),
		"request_count": snapshot.get("request_count", -1),
		"cancel_count": snapshot.get("cancel_count", -1),
		"confirm_count": snapshot.get("confirm_count", -1),
		"commit_count": snapshot.get("commit_count", -1),
		"rules_end_turn_call_count": snapshot.get("rules_end_turn_call_count", -1),
		"autosave_call_count": snapshot.get("autosave_call_count", -1),
	}


func _compact_result(result: Dictionary) -> Dictionary:
	return {
		"ok": result.get("ok", false),
		"confirmation_required": result.get("confirmation_required", false),
		"committed": result.get("committed", false),
		"reason": result.get("reason", ""),
		"stale_fields": result.get("stale_fields", []),
	}


func _result_signature(result: Dictionary) -> Dictionary:
	return {
		"ok": result.get("ok", false),
		"message": result.get("message", ""),
		"day": result.get("day", result.get("day_after", 0)),
		"enemy_activity_summary": result.get("enemy_activity_summary", ""),
		"turn_resolution_summary": result.get("turn_resolution_summary", ""),
	}


func _session_signature(payload: Dictionary) -> Dictionary:
	var overworld: Dictionary = payload.get("overworld", {}) if payload.get("overworld", {}) is Dictionary else {}
	var movement: Dictionary = overworld.get("movement", {}) if overworld.get("movement", {}) is Dictionary else {}
	var flags: Dictionary = payload.get("flags", {}) if payload.get("flags", {}) is Dictionary else {}
	return {
		"session_id": payload.get("session_id", ""),
		"day": payload.get("day", 0),
		"status": payload.get("scenario_status", ""),
		"movement": movement.get("current", -1),
		"marker": flags.get("end_turn_confirmation_marker", ""),
		"battle_active": not (payload.get("battle", {}) as Dictionary).is_empty() if payload.get("battle", {}) is Dictionary else false,
	}


func _first_difference(expected: Variant, actual: Variant, path: String = "$") -> Dictionary:
	if typeof(expected) != typeof(actual):
		return {"path": path, "expected_type": type_string(typeof(expected)), "actual_type": type_string(typeof(actual))}
	if expected is Dictionary:
		var expected_dictionary: Dictionary = expected
		var actual_dictionary: Dictionary = actual
		var expected_keys: Array = expected_dictionary.keys()
		expected_keys.sort()
		var actual_keys: Array = actual_dictionary.keys()
		actual_keys.sort()
		if expected_keys != actual_keys:
			return {"path": path, "expected_keys": expected_keys, "actual_keys": actual_keys}
		for key in expected_keys:
			var nested := _first_difference(expected_dictionary.get(key), actual_dictionary.get(key), "%s.%s" % [path, key])
			if not nested.is_empty():
				return nested
		return {}
	if expected is Array:
		var expected_array: Array = expected
		var actual_array: Array = actual
		if expected_array.size() != actual_array.size():
			return {"path": path, "expected_size": expected_array.size(), "actual_size": actual_array.size()}
		for index in range(expected_array.size()):
			var nested := _first_difference(expected_array[index], actual_array[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
		return {}
	if expected != actual:
		return {"path": path, "expected": expected, "actual": actual}
	return {}


func _cleanup() -> void:
	for path in _autosave_paths():
		_remove_path(String(path))
	for path in _original_autosave_states.keys():
		var state: Dictionary = _original_autosave_states.get(path, {})
		if bool(state.get("exists", false)):
			_write_bytes(String(path), state.get("bytes", PackedByteArray()))
	SaveService.validation_clear_summary_cache()
	SessionState.active_session = _original_active_session


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	_cleanup()
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
