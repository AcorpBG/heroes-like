extends Node

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "BATTLE_WITHDRAWAL_CONFIRMATION_RUNTIME_REPORT"
const SCENARIO_ID := "river-pass"
const ENCOUNTER_PLACEMENT_ID := "river_pass_hollow_mire"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var cancel_case: Dictionary = await _validate_request_and_cancel()
	if cancel_case.is_empty():
		return
	var stale_case: Dictionary = await _validate_stale_disabled_confirmation()
	if stale_case.is_empty():
		return
	var retreat_case: Dictionary = await _validate_confirmed_withdrawal("retreat")
	if retreat_case.is_empty():
		return
	var surrender_case: Dictionary = await _validate_confirmed_withdrawal("surrender")
	if surrender_case.is_empty():
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"report_id": REPORT_ID,
		"request_cancel": cancel_case,
		"stale_disabled": stale_case,
		"retreat": retreat_case,
		"surrender": surrender_case,
	})])
	get_tree().quit(0)


func _validate_request_and_cancel() -> Dictionary:
	var fixture: Dictionary = await _shell_fixture()
	if fixture.is_empty():
		return {}
	var shell: Node = fixture.get("shell")
	var session = fixture.get("session")
	var before := JSON.stringify(session.to_dict())
	var before_snapshot: Dictionary = shell.call("validation_snapshot")
	var perform_before := _action_perform_count(before_snapshot, "retreat")
	var route_before := int(before_snapshot.get("validation_battle_resolution_attempt_count", 0))
	var request: Dictionary = shell.call("validation_request_withdrawal", "retreat")
	var requested_snapshot: Dictionary = shell.call("validation_snapshot")
	if not bool(request.get("ok", false)) \
			or not bool(request.get("pending", false)) \
			or String(request.get("action_id", "")) != "retreat" \
			or not bool(request.get("dialog_visible", false)):
		_fail("First Retreat press did not open a pending confirmation: %s" % JSON.stringify(request))
		return {}
	if String(request.get("confirm_text", "")) != "Confirm Retreat" \
			or String(request.get("cancel_text", "")) != "Keep Fighting":
		_fail("Retreat confirmation actions were not explicit and cancel-safe: %s" % JSON.stringify(request))
		return {}
	if String(requested_snapshot.get("withdrawal_pending_action", "")) != "retreat" \
			or not bool(requested_snapshot.get("withdrawal_confirmation_visible", false)):
		_fail("Retreat confirmation snapshot did not expose its pending modal state: %s" % JSON.stringify(_withdrawal_snapshot(requested_snapshot)))
		return {}
	if JSON.stringify(session.to_dict()) != before \
			or _action_perform_count(requested_snapshot, "retreat") != perform_before \
			or int(requested_snapshot.get("validation_battle_resolution_attempt_count", 0)) != route_before:
		_fail("First Retreat press resolved or mutated the battle before confirmation.")
		return {}
	var canceled: Dictionary = shell.call("validation_cancel_withdrawal")
	var canceled_snapshot: Dictionary = shell.call("validation_snapshot")
	if not bool(canceled.get("ok", false)) \
			or not bool(canceled.get("canceled", false)) \
			or bool(canceled.get("pending", true)) \
			or bool(canceled.get("performed", true)):
		_fail("Cancel did not close the pending withdrawal without performing it: %s" % JSON.stringify(canceled))
		return {}
	if String(canceled_snapshot.get("withdrawal_pending_action", "")) != "" \
			or bool(canceled_snapshot.get("withdrawal_confirmation_visible", true)) \
			or JSON.stringify(session.to_dict()) != before \
			or _action_perform_count(canceled_snapshot, "retreat") != perform_before \
			or int(canceled_snapshot.get("validation_battle_resolution_attempt_count", 0)) != route_before:
		_fail("Cancel changed battle state, performed an order, or attempted a route: %s" % JSON.stringify(_withdrawal_snapshot(canceled_snapshot)))
		return {}
	await _discard_shell(shell)
	return {
		"first_press_no_resolution": true,
		"cancel_exact_session": true,
		"cancel_perform_delta": 0,
		"cancel_route_delta": 0,
		"confirm_text": String(request.get("confirm_text", "")),
		"cancel_text": String(request.get("cancel_text", "")),
	}


func _validate_stale_disabled_confirmation() -> Dictionary:
	var fixture: Dictionary = await _shell_fixture()
	if fixture.is_empty():
		return {}
	var shell: Node = fixture.get("shell")
	var session = fixture.get("session")
	var request: Dictionary = shell.call("validation_request_withdrawal", "surrender")
	if not bool(request.get("ok", false)) or not bool(request.get("pending", false)):
		_fail("Stale-order fixture could not request Surrender confirmation: %s" % JSON.stringify(request))
		return {}
	session.battle["surrender_allowed"] = false
	var stale_surface: Dictionary = BattleRulesScript.get_action_surface(session)
	if not bool(stale_surface.get("surrender", {}).get("disabled", false)):
		_fail("Stale-order fixture did not make Surrender unavailable before confirm.")
		return {}
	var before := JSON.stringify(session.to_dict())
	var before_snapshot: Dictionary = shell.call("validation_snapshot")
	var perform_before := _action_perform_count(before_snapshot, "surrender")
	var route_before := int(before_snapshot.get("validation_battle_resolution_attempt_count", 0))
	var confirmed: Dictionary = shell.call("validation_confirm_withdrawal")
	var after_snapshot: Dictionary = shell.call("validation_snapshot")
	if bool(confirmed.get("ok", true)) \
			or bool(confirmed.get("performed", true)) \
			or bool(confirmed.get("pending", true)):
		_fail("Stale disabled Surrender confirmation was not rejected: %s" % JSON.stringify(confirmed))
		return {}
	if JSON.stringify(session.to_dict()) != before \
			or _action_perform_count(after_snapshot, "surrender") != perform_before \
			or int(after_snapshot.get("validation_battle_resolution_attempt_count", 0)) != route_before:
		_fail("Stale disabled confirmation mutated the session, performed an order, or routed: %s" % JSON.stringify({
			"confirm": confirmed,
			"snapshot": _withdrawal_snapshot(after_snapshot),
		}))
		return {}
	if String(after_snapshot.get("withdrawal_pending_action", "")) != "" \
			or bool(after_snapshot.get("withdrawal_confirmation_visible", true)):
		_fail("Rejected stale confirmation left the destructive action pending: %s" % JSON.stringify(_withdrawal_snapshot(after_snapshot)))
		return {}
	await _discard_shell(shell)
	return {
		"rejected": true,
		"reason": String(confirmed.get("reason", "")),
		"session_exact": true,
		"perform_delta": 0,
		"route_delta": 0,
	}


func _validate_confirmed_withdrawal(action_id: String) -> Dictionary:
	var fixture: Dictionary = await _shell_fixture()
	if fixture.is_empty():
		return {}
	var shell: Node = fixture.get("shell")
	var session = fixture.get("session")
	var direct_control := _clone_session(session)
	var direct_result: Dictionary = BattleRulesScript.perform_player_action(direct_control, action_id)
	if not bool(direct_result.get("ok", false)) or String(direct_result.get("state", "")) != action_id:
		_fail("Direct %s control did not resolve the expected withdrawal: %s" % [action_id, JSON.stringify(direct_result)])
		return {}
	var before := JSON.stringify(session.to_dict())
	var before_snapshot: Dictionary = shell.call("validation_snapshot")
	var perform_before := _action_perform_count(before_snapshot, action_id)
	var route_before := int(before_snapshot.get("validation_battle_resolution_attempt_count", 0))
	var request: Dictionary = shell.call("validation_request_withdrawal", action_id)
	if not bool(request.get("ok", false)) or JSON.stringify(session.to_dict()) != before:
		_fail("%s request mutated the battle before confirmation: %s" % [action_id.capitalize(), JSON.stringify(request)])
		return {}
	var confirmed: Dictionary = shell.call("validation_confirm_withdrawal")
	var after_snapshot: Dictionary = shell.call("validation_snapshot")
	var shell_result_value: Variant = confirmed.get("result", {})
	var shell_result: Dictionary = shell_result_value if shell_result_value is Dictionary else {}
	var perform_delta := _action_perform_count(after_snapshot, action_id) - perform_before
	var route_delta := int(after_snapshot.get("validation_battle_resolution_attempt_count", 0)) - route_before
	var last_route_value: Variant = after_snapshot.get("validation_last_battle_resolution_route", {})
	var last_route: Dictionary = last_route_value if last_route_value is Dictionary else {}
	if not bool(confirmed.get("ok", false)) \
			or not bool(confirmed.get("performed", false)) \
			or bool(confirmed.get("pending", true)) \
			or String(confirmed.get("action_id", "")) != action_id:
		_fail("Confirmed %s did not perform its pending order: %s" % [action_id, JSON.stringify(confirmed)])
		return {}
	if perform_delta != 1 \
			or int(confirmed.get("routing_attempt_delta", -1)) != 1 \
			or route_delta != 1 \
			or not bool(confirmed.get("routed", false)) \
			or String(confirmed.get("route_target", "")) != "overworld":
		_fail("Confirmed %s did not perform and route exactly once: %s" % [action_id, JSON.stringify({
			"confirm": confirmed,
			"perform_delta": perform_delta,
			"route_delta": route_delta,
			"last_route": last_route,
		})])
		return {}
	if String(last_route.get("target", "")) != "overworld" \
			or String(last_route.get("state", "")) != action_id:
		_fail("Confirmed %s recorded the wrong terminal route: %s" % [action_id, JSON.stringify(last_route)])
		return {}
	if shell_result != direct_result:
		_fail("Shell %s result diverged from direct BattleRules control: %s" % [action_id, JSON.stringify({
			"shell": shell_result,
			"direct": direct_result,
		})])
		return {}
	var shell_payload := _gameplay_payload_without_shell_presentation(session)
	var direct_payload := _gameplay_payload_without_shell_presentation(direct_control)
	if JSON.stringify(shell_payload) != JSON.stringify(direct_payload):
		_fail("Shell %s gameplay session diverged from direct BattleRules control: %s" % [action_id, JSON.stringify({
			"different_keys": _different_dictionary_keys(shell_payload, direct_payload),
			"different_paths": _different_value_paths(shell_payload, direct_payload),
		})])
		return {}
	var recap_value: Variant = session.flags.get("last_battle_action_recap", {})
	var recap: Dictionary = recap_value if recap_value is Dictionary else {}
	if String(recap.get("action_id", "")) != action_id or String(recap.get("state", "")) != action_id:
		_fail("Shell %s did not retain its expected presentation-only action recap: %s" % [action_id, JSON.stringify(recap)])
		return {}
	if not session.battle.is_empty() or String(session.flags.get("last_battle_outcome", "")) != action_id:
		_fail("Confirmed %s did not commit its terminal battle aftermath." % action_id)
		return {}
	await _discard_shell(shell)
	return {
		"state": String(shell_result.get("state", "")),
		"direct_result_match": true,
		"direct_gameplay_session_match": true,
		"shell_presentation_metadata_only": true,
		"perform_delta": perform_delta,
		"route_delta": route_delta,
		"route_target": String(last_route.get("target", "")),
	}


func _shell_fixture() -> Dictionary:
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	var encounter := _encounter(session, ENCOUNTER_PLACEMENT_ID)
	if encounter.is_empty():
		_fail("Withdrawal fixture is missing authored encounter %s." % ENCOUNTER_PLACEMENT_ID)
		return {}
	session.battle = BattleRulesScript.create_battle_payload(session, encounter)
	session.game_state = "battle"
	if session.battle.is_empty():
		_fail("Withdrawal fixture could not create an active battle payload.")
		return {}
	session.battle["retreat_allowed"] = true
	session.battle["surrender_allowed"] = true
	var guard := 0
	while String(BattleRulesScript.get_active_stack(session.battle).get("side", "")) != "player" and guard < 12:
		BattleRulesScript.advance_turn(session.battle)
		guard += 1
	if String(BattleRulesScript.get_active_stack(session.battle).get("side", "")) != "player":
		_fail("Withdrawal fixture could not reach a player turn.")
		return {}
	session = SessionState.set_active_session(session)
	var shell: Node = load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	for method_name in [
		"validation_request_withdrawal",
		"validation_cancel_withdrawal",
		"validation_confirm_withdrawal",
		"validation_set_battle_resolution_routing_enabled",
		"validation_snapshot",
	]:
		if not shell.has_method(method_name):
			_fail("BattleShell is missing withdrawal validation hook %s." % method_name)
			return {}
	if not bool(shell.call("validation_set_battle_resolution_routing_enabled", false)):
		_fail("Withdrawal fixture could not suppress real scene changes while observing routes.")
		return {}
	return {"shell": shell, "session": session}


func _encounter(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _clone_session(source) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.new_session_data()
	clone.from_dict(source.to_dict())
	return clone


func _action_perform_count(snapshot: Dictionary, action_id: String) -> int:
	var counts_value: Variant = snapshot.get("validation_perform_action_counts", {})
	var counts: Dictionary = counts_value if counts_value is Dictionary else {}
	return int(counts.get(action_id, 0))


func _withdrawal_snapshot(snapshot: Dictionary) -> Dictionary:
	return {
		"pending_action": snapshot.get("withdrawal_pending_action", ""),
		"dialog_visible": snapshot.get("withdrawal_confirmation_visible", false),
		"title": snapshot.get("withdrawal_confirmation_title", ""),
		"confirm_text": snapshot.get("withdrawal_confirmation_ok_text", ""),
		"cancel_text": snapshot.get("withdrawal_confirmation_cancel_text", ""),
		"perform_counts": snapshot.get("validation_perform_action_counts", {}),
		"route_count": snapshot.get("validation_battle_resolution_attempt_count", 0),
		"last_route": snapshot.get("validation_last_battle_resolution_route", {}),
	}


func _gameplay_payload_without_shell_presentation(session) -> Dictionary:
	var payload: Dictionary = session.to_dict()
	var flags_value: Variant = payload.get("flags", {})
	var flags: Dictionary = flags_value if flags_value is Dictionary else {}
	flags.erase("last_battle_action_recap")
	payload["flags"] = flags
	var overworld_value: Variant = payload.get("overworld", {})
	var overworld: Dictionary = overworld_value if overworld_value is Dictionary else {}
	overworld.erase("command_risk_forecast")
	payload["overworld"] = overworld
	return payload


func _different_dictionary_keys(left: Dictionary, right: Dictionary) -> Array[String]:
	var different: Array[String] = []
	var keys := left.keys()
	for key in right.keys():
		if not keys.has(key):
			keys.append(key)
	for key in keys:
		if not left.has(key) or not right.has(key) or left.get(key) != right.get(key):
			different.append(String(key))
	different.sort()
	return different


func _different_value_paths(left: Variant, right: Variant, prefix: String = "", limit: int = 12) -> Array[String]:
	var different: Array[String] = []
	if typeof(left) != typeof(right):
		return [prefix]
	if left is Dictionary and right is Dictionary:
		var left_dictionary: Dictionary = left
		var right_dictionary: Dictionary = right
		var keys: Array = left_dictionary.keys()
		for key in right_dictionary.keys():
			if not keys.has(key):
				keys.append(key)
		for key in keys:
			var path := "%s.%s" % [prefix, key] if prefix != "" else String(key)
			if not left_dictionary.has(key) or not right_dictionary.has(key):
				different.append(path)
			elif left_dictionary.get(key) != right_dictionary.get(key):
				different.append_array(_different_value_paths(left_dictionary.get(key), right_dictionary.get(key), path, limit - different.size()))
			if different.size() >= limit:
				break
		return different.slice(0, limit)
	if left is Array and right is Array:
		var left_array: Array = left
		var right_array: Array = right
		if left_array.size() != right_array.size():
			different.append("%s.size" % prefix)
		var count: int = min(left_array.size(), right_array.size())
		for index in count:
			if left_array[index] != right_array[index]:
				different.append_array(_different_value_paths(left_array[index], right_array[index], "%s[%d]" % [prefix, index], limit - different.size()))
			if different.size() >= limit:
				break
		return different.slice(0, limit)
	if left != right:
		different.append(prefix)
	return different


func _discard_shell(shell: Node) -> void:
	if is_instance_valid(shell):
		shell.queue_free()
	await get_tree().process_frame


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
