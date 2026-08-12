extends Node

const REPORT_ID := "OVERWORLD_CONTROLLER_ROUTE_SELECTION_REGRESSION"
const AUTOSAVE_PATH := "user://saves/autosave.json"
const MANUAL_SLOT := 1
const SEMANTIC_DEBOUNCE_SECONDS := 0.42
const SEMANTIC_RESULT_SECONDS := 1.20
const SEMANTIC_MAX_CHARS := 320

var _original_session = null
var _original_files: Dictionary = {}
var _original_summary_cache: Dictionary = {}
var _original_settings_transaction: Dictionary = {}
var _original_settings_canonical: Dictionary = {}
var _original_window_size := Vector2i.ZERO


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_session = SessionState.active_session
	_original_files = _capture_file_states(_authority_paths())
	_original_summary_cache = SaveService.validation_summary_cache_snapshot()
	_original_settings_transaction = SettingsService.validation_settings_transaction_snapshot()
	_original_settings_canonical = _canonical_settings_transaction(_original_settings_transaction)
	_original_window_size = get_window().size
	var preview := await _validate_cursor_preview_and_direction_state()
	if preview.is_empty():
		return
	var actions := await _validate_cancel_accept_left_move_and_boundary()
	if actions.is_empty():
		return
	var blockers := await _validate_interaction_blockers()
	if blockers.is_empty():
		return
	var semantics := await _validate_route_semantic_matrix()
	if semantics.is_empty():
		return
	_cleanup()
	var cleanup_files: Dictionary = _capture_file_states(_authority_paths())
	var cleanup_summary_cache: Dictionary = SaveService.validation_summary_cache_snapshot()
	var cleanup_settings_transaction: Dictionary = SettingsService.validation_settings_transaction_snapshot()
	var cleanup_settings_canonical: Dictionary = _canonical_settings_transaction(cleanup_settings_transaction)
	var cleanup_session_ref = SessionState.active_session
	var cleanup_window_size := get_window().size
	var cleanup_checks := {
		"files_exact": cleanup_files == _original_files,
		"save_cache_exact": cleanup_summary_cache == _original_summary_cache,
		"settings_canonical_exact": cleanup_settings_canonical == _original_settings_canonical,
		"active_session_identity_exact": is_same(cleanup_session_ref, _original_session),
		"window_size_exact": cleanup_window_size == _original_window_size,
	}
	var cleanup_raw_settings_aggregate_diagnostic := cleanup_settings_transaction == _original_settings_transaction
	if not _checks_exact(cleanup_checks):
		var cleanup_failed: Array[String] = []
		for check_value in cleanup_checks.keys():
			if not bool(cleanup_checks.get(check_value, false)):
				cleanup_failed.append(String(check_value))
		push_error("%s failed: focused cleanup did not restore named exact session/window/save/cache/settings authority. %s" % [REPORT_ID, JSON.stringify({
			"checks": cleanup_checks,
			"failed": cleanup_failed,
			"files": {"before": _original_files, "after": cleanup_files} if "files_exact" in cleanup_failed else {},
			"save_cache": {"before": _original_summary_cache, "after": cleanup_summary_cache} if "save_cache_exact" in cleanup_failed else {},
			"settings_canonical": {"before": _original_settings_canonical, "after": cleanup_settings_canonical},
			"settings_raw": {"before": _original_settings_transaction, "after": cleanup_settings_transaction},
			"session_identity": {"before": _original_session, "after": cleanup_session_ref} if "active_session_identity_exact" in cleanup_failed else {},
			"window_size": {"before": _original_window_size, "after": cleanup_window_size} if "window_size_exact" in cleanup_failed else {},
			"raw_settings_aggregate_diagnostic": cleanup_raw_settings_aggregate_diagnostic,
		})])
		get_tree().quit(1)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"preview": preview,
		"actions": actions,
		"blockers": blockers,
		"semantics": semantics,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)


func _validate_route_semantic_matrix() -> Dictionary:
	var rows: Array[Dictionary] = []
	for width in [1280, 1920]:
		var row: Dictionary = await _validate_route_semantic_width(width)
		if row.is_empty():
			return {}
		rows.append(row)
	return {
		"ok": true,
		"widths": [1280, 1920],
		"loaded_inactive_active": true,
		"physical_hold_360_180": true,
		"coalesced_context_420": true,
		"result_immediate_clear_1200": true,
		"identity_fail_closed": true,
		"owner_mouse_modal_controls": true,
		"rows": rows,
	}


func _validate_route_semantic_width(width: int) -> Dictionary:
	var opened: Dictionary = await _create_width_shell(Vector2i(8, 5), 30, Vector2i(18, 12), width)
	var shell: Node = opened.get("shell", null)
	var host: Control = opened.get("host", null)
	var session = opened.get("session", null)
	if shell == null or host == null or session == null or not _require_hooks(shell):
		await _discard_width_shell(host, shell)
		return {}
	var live: Label = shell.get_node_or_null("%RouteCursorLive")
	var semantic_timer: Timer = shell.get("_controller_route_semantic_timer")
	var inactive: Dictionary = shell.validation_controller_route_cursor_snapshot()
	if live == null or semantic_timer == null or int(host.size.x) != width \
			or bool(inactive.get("active", true)) or live.text != "" \
			or not (shell.get("_controller_route_semantic_pending") as Dictionary).is_empty():
		_fail("%d loaded inactive route semantics were not exact." % width, {
			"active": inactive.get("active"), "text": live.text if live != null else "missing",
			"pending": shell.get("_controller_route_semantic_pending"),
		})
		await _discard_width_shell(host, shell)
		return {}

	var authority_before: Dictionary = _route_semantic_authority(shell, session)
	var reset: Dictionary = shell.validation_reset_controller_route_cursor()
	var first: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	var first_pending: Dictionary = (shell.get("_controller_route_semantic_pending") as Dictionary).duplicate(true)
	var first_text := String(first_pending.get("text", ""))
	var first_action: Dictionary = first.get("primary_action", {}) if first.get("primary_action", {}) is Dictionary else {}
	var first_decision: Dictionary = first_action.get("route_decision", {}) if first_action.get("route_decision", {}) is Dictionary else {}
	var readiness_text := String(shell.call("_route_decision_status_label", first_decision))
	var destination_text := String(first_decision.get("destination", "")).strip_edges()
	var action_text := String(first_action.get("label", "")).strip_edges()
	var synchronous_checks := {
		"active": bool(first.get("active", false)),
		"current_tile": first.get("selected_tile", {}) == first_pending.get("selected_tile", {}),
		"current_route_generation": int(first_pending.get("route_generation", -1)) >= 0,
		"context_pending": String(first_pending.get("kind", "")) == "context",
		"session_reference": is_same(first_pending.get("session_ref"), session),
		"session_id": String(first_pending.get("session_id", "")) == String(session.session_id),
		"semantic_empty_during_coalesce": live.text == "",
		"semantic_bounded": first_text.length() > 0 and first_text.length() <= SEMANTIC_MAX_CHARS,
		"destination": destination_text != "" and first_text.contains(destination_text) and first_text.contains(" at %d,%d." % [int((first.get("selected_tile", {}) as Dictionary).get("x", -1)), int((first.get("selected_tile", {}) as Dictionary).get("y", -1))]),
		"readiness": readiness_text != "" and first_text.contains(readiness_text),
		"action_ab": action_text != "" and first_text.contains("A: %s" % action_text) and first_text.contains("B: cancel route cursor"),
		"action_cached": not first_action.is_empty() and not first_decision.is_empty(),
	}
	if not _checks_exact(synchronous_checks):
		_fail("%d route semantic synchronous context was not exact." % width, {"checks": synchronous_checks, "pending": _semantic_pending_compact(first_pending), "cursor": _compact_cursor(first)})
		await _discard_width_shell(host, shell)
		return {}

	# Keep the physical stick held through the real 360 ms initial and 180 ms rate
	# timers. Each changed tile replaces the pending context, so only the final
	# refreshed destination may become live after the independent 420 ms quiet gate.
	await get_tree().create_timer(0.38).timeout
	var after_initial: Dictionary = shell.validation_controller_route_cursor_snapshot()
	var initial_pending: Dictionary = (shell.get("_controller_route_semantic_pending") as Dictionary).duplicate(true)
	if int(after_initial.get("step_count", 0)) != int(first.get("step_count", 0)) + 1 or live.text != "" \
			or initial_pending.get("selected_tile", {}) != after_initial.get("selected_tile", {}):
		_fail("%d real 360 ms route repeat did not coalesce the refreshed context." % width, {"cursor": _compact_cursor(after_initial), "pending": _semantic_pending_compact(initial_pending), "live": live.text})
		await _discard_width_shell(host, shell)
		return {}
	await get_tree().create_timer(0.20).timeout
	var after_rate: Dictionary = shell.validation_controller_route_cursor_snapshot()
	var final_pending: Dictionary = (shell.get("_controller_route_semantic_pending") as Dictionary).duplicate(true)
	if int(after_rate.get("step_count", 0)) != int(after_initial.get("step_count", 0)) + 1 or live.text != "" \
			or final_pending.get("selected_tile", {}) != after_rate.get("selected_tile", {}):
		_fail("%d real 180 ms route repeat did not replace the pending context." % width, {"cursor": _compact_cursor(after_rate), "pending": _semantic_pending_compact(final_pending), "live": live.text})
		await _discard_width_shell(host, shell)
		return {}
	await _send_joypad_axis_immediate(JOY_AXIS_RIGHT_X, 0.0)
	await get_tree().create_timer(SEMANTIC_DEBOUNCE_SECONDS + 0.02).timeout
	var published_text := live.text
	if published_text != String(final_pending.get("text", "")) or published_text.length() > SEMANTIC_MAX_CHARS \
			or not (shell.get("_controller_route_semantic_pending") as Dictionary).is_empty():
		_fail("%d 420 ms route context did not publish only the final cached destination." % width, {"expected": final_pending.get("text"), "actual": published_text, "pending": shell.get("_controller_route_semantic_pending")})
		await _discard_width_shell(host, shell)
		return {}

	# A clamped no-op must leave the already-published context and generation alone.
	shell.set("_selected_tile", Vector2i(17, 5))
	shell.call("_refresh_selected_route_preview", "semantic_bounded_fixture")
	shell.call("_schedule_controller_route_semantic_after_refresh")
	await get_tree().create_timer(SEMANTIC_DEBOUNCE_SECONDS + 0.02).timeout
	var bounded_text := live.text
	var bounded_generation := int(shell.get("_controller_route_semantic_generation"))
	var bounded_before: Dictionary = shell.validation_controller_route_cursor_snapshot()
	var bounded_after: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _send_joypad_axis_immediate(JOY_AXIS_RIGHT_X, 0.0)
	if bounded_after.get("selected_tile", {}) != bounded_before.get("selected_tile", {}) \
			or int(bounded_after.get("step_count", -1)) != int(bounded_before.get("step_count", -1)) \
			or live.text != bounded_text or int(shell.get("_controller_route_semantic_generation")) != bounded_generation:
		_fail("%d bounded no-op replaced a valid route announcement." % width, {"before": _compact_cursor(bounded_before), "after": _compact_cursor(bounded_after), "text_before": bounded_text, "text_after": live.text})
		await _discard_width_shell(host, shell)
		return {}

	# Opening another interaction owner must stop announcements without changing the
	# selected tile or already-rendered route preview.
	shell.set("_selected_tile", Vector2i(10, 5))
	shell.call("_refresh_selected_route_preview", "semantic_owner_fixture")
	shell.call("_schedule_controller_route_semantic_after_refresh")
	var owner_before: Dictionary = shell.validation_controller_route_cursor_snapshot()
	shell.validation_open_command_drawer()
	var owner_after: Dictionary = shell.validation_controller_route_cursor_snapshot()
	if bool(owner_after.get("active", true)) or live.text != "" \
			or not (shell.get("_controller_route_semantic_pending") as Dictionary).is_empty() \
			or owner_after.get("selected_tile", {}) != owner_before.get("selected_tile", {}) \
			or owner_after.get("route_preview", {}) != owner_before.get("route_preview", {}):
		_fail("%d owner-open route deactivation changed selection/visual route or retained semantics." % width, {"before": _compact_cursor(owner_before), "after": _compact_cursor(owner_after), "pending": shell.get("_controller_route_semantic_pending")})
		await _discard_width_shell(host, shell)
		return {}
	shell.call("_on_close_drawers_pressed")
	await _settle()
	# A native modal owner follows the same fail-closed lifecycle while retaining
	# the selected tile and already-rendered route preview.
	shell.validation_reset_controller_route_cursor()
	shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	var modal_before: Dictionary = shell.validation_controller_route_cursor_snapshot()
	var modal_opened: Dictionary = shell.validation_open_active_play_settings()
	var modal_after: Dictionary = shell.validation_controller_route_cursor_snapshot()
	if not bool(modal_opened.get("visible", false)) or bool(modal_after.get("active", true)) \
			or live.text != "" or not (shell.get("_controller_route_semantic_pending") as Dictionary).is_empty() \
			or modal_after.get("selected_tile", {}) != modal_before.get("selected_tile", {}) \
			or modal_after.get("route_preview", {}) != modal_before.get("route_preview", {}):
		_fail("%d modal owner did not stop semantics while preserving selection/visual route." % width, {"before": _compact_cursor(modal_before), "after": _compact_cursor(modal_after), "opened": _compact(modal_opened)})
		await _discard_width_shell(host, shell)
		return {}
	var active_settings = shell.validation_active_play_settings_dialog()
	active_settings.close_dialog()
	await _settle()

	# Mouse selection remains the existing owner and synchronously clears controller
	# semantics before applying the selected tile.
	shell.validation_reset_controller_route_cursor()
	shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	var mouse_target := Vector2i(3, 3)
	var mouse_result: Dictionary = shell.validation_click_tile(mouse_target.x, mouse_target.y)
	var mouse_after: Dictionary = shell.validation_controller_route_cursor_snapshot()
	if not bool(mouse_result.get("ok", false)) or bool(mouse_after.get("active", true)) \
			or mouse_after.get("selected_tile", {}) != _tile_payload(mouse_target) or live.text != "":
		_fail("%d mouse selection did not retain ownership over the route cursor." % width, {"cursor": _compact_cursor(mouse_after), "result": _compact(mouse_result)})
		await _discard_width_shell(host, shell)
		return {}

	# Pending identity fails closed for generation, route generation, session id,
	# active-session replacement, and tree exit. These direct timeout calls avoid
	# adding seconds of runtime while exercising the production validation branch.
	if not _validate_route_semantic_identity_guards(shell, session, live):
		await _discard_width_shell(host, shell)
		return {}
	var pre_result_authority: Dictionary = _route_semantic_authority(shell, session)
	var pre_result_authority_checks: Dictionary = _route_semantic_authority_checks(authority_before, pre_result_authority, session)
	var pre_result_whole_object_aggregate_diagnostic := authority_before == pre_result_authority
	if not _checks_exact(pre_result_authority_checks):
		_fail("%d route semantic preview/owner/identity controls changed named session or durable authority." % width, _route_semantic_authority_failure_details(
			pre_result_authority_checks,
			authority_before,
			pre_result_authority,
			session,
			pre_result_whole_object_aggregate_diagnostic
		))
		await _discard_width_shell(host, shell)
		return {}

	# Re-establish the valid loaded route and exercise immediate result feedback.
	shell.validation_reset_controller_route_cursor()
	var action_selected: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	var before_result_authority: Dictionary = _route_semantic_authority(shell, session)
	var action_kind := "cancel" if width == 1280 else "accept"
	var action_surface: Dictionary = action_selected.get("primary_action", {}) if action_selected.get("primary_action", {}) is Dictionary else {}
	var action_id := String(action_surface.get("id", ""))
	var selected_before_action: Dictionary = (action_selected.get("selected_tile", {}) as Dictionary).duplicate(true)
	var direct_control = null
	var direct_result: Dictionary = {}
	var direct_setup_checks := {"not_applicable": true}
	if action_kind == "accept":
		var route_state: Dictionary = (shell.get("_selected_route_state") as Dictionary).duplicate(true)
		var route_tiles: Array = route_state.get("route_tiles", []) if route_state.get("route_tiles", []) is Array else []
		var route_preview: Dictionary = route_state.get("route_preview", {}) if route_state.get("route_preview", {}) is Dictionary else {}
		var destination_descriptor: Dictionary = route_state.get("destination_interaction_descriptor", {}) if route_state.get("destination_interaction_descriptor", {}) is Dictionary else {}
		direct_control = SessionState.new_session_data()
		direct_control.from_dict(session.to_dict())
		direct_result = OverworldRules.execute_prevalidated_route(
			direct_control,
			route_tiles,
			route_preview,
			-1,
			destination_descriptor
		)
		if String(direct_result.get("route", "")) == "battle":
			direct_control.flags["last_action"] = "entered_battle"
		elif String(direct_result.get("route", "")) == "town":
			direct_control.flags["last_action"] = "visited_town"
		elif String(direct_result.get("route", "")) == "rendezvous":
			direct_control.flags["last_action"] = "hero_rendezvous"
		else:
			direct_control.flags["last_action"] = "moved" if bool(direct_result.get("ok", false)) else "blocked_move"
		var direct_recap_value: Variant = direct_result.get("post_action_recap", {})
		var direct_recap: Dictionary = (direct_recap_value as Dictionary).duplicate(true) if direct_recap_value is Dictionary else {}
		var direct_recap_checks := {
			"dictionary": direct_recap_value is Dictionary,
			"nonempty": not direct_recap.is_empty(),
			"happened": String(direct_recap.get("happened", "")).strip_edges() != "",
			"affected": String(direct_recap.get("affected", "")).strip_edges() != "",
			"why_it_matters": String(direct_recap.get("why_it_matters", "")).strip_edges() != "",
			"next_step": String(direct_recap.get("next_step", "")).strip_edges() != "",
			"message_or_cue_feedback": String(direct_result.get("message", "")).strip_edges() != "" or String(direct_recap.get("cue_text", "")).strip_edges() != "",
		}
		if not _checks_exact(direct_recap_checks):
			_fail("%d accept direct-control result did not expose the complete persisted feedback recap contract." % width, {"checks": direct_recap_checks, "result": direct_result, "recap": direct_recap})
			await _discard_width_shell(host, shell)
			return {}
		direct_control.flags["last_overworld_action_recap"] = direct_recap.duplicate(true)
		if direct_control.flags.get("last_overworld_action_recap", {}) != direct_recap:
			_fail("%d accept direct control did not retain the detached feedback recap exactly." % width, {"expected": direct_recap, "actual": direct_control.flags.get("last_overworld_action_recap", {})})
			await _discard_width_shell(host, shell)
			return {}
		var hero_before_action: Vector2i = OverworldRules.hero_position(session)
		direct_setup_checks = {
			"action_id_exact": action_id == "march_selected",
			"selected_adjacent_exact": selected_before_action == _tile_payload(hero_before_action + Vector2i.RIGHT),
			"route_state_valid": bool(route_state.get("valid", false)),
			"route_start_exact": route_tiles.size() == 2 and route_tiles[0] == hero_before_action,
			"route_finish_exact": route_tiles.size() == 2 and route_tiles[1] == hero_before_action + Vector2i.RIGHT,
			"cached_execution_exact": String(shell.call("_selected_cached_route_execution_fallback_reason", route_state, route_tiles, route_preview)) == "",
			"direct_ok": bool(direct_result.get("ok", false)),
			"direct_route_open": String(direct_result.get("route", "")) == "",
		}
		if not _checks_exact(direct_setup_checks):
			_fail("%d accept direct-control fixture was not the exact bounded adjacent cached route." % width, {"checks": direct_setup_checks, "action": action_surface, "route_state": route_state, "direct_result": direct_result})
			await _discard_width_shell(host, shell)
			return {}
	if action_kind == "cancel":
		await _press_joypad_button(JOY_BUTTON_B)
	else:
		await _press_joypad_button(JOY_BUTTON_A)
	var result_snapshot: Dictionary = shell.validation_controller_route_cursor_snapshot()
	var result_text := live.text
	var result_pending: Dictionary = (shell.get("_controller_route_semantic_pending") as Dictionary).duplicate(true)
	var expected_result_message := String(shell.get("_last_message")).strip_edges()
	if expected_result_message == "":
		expected_result_message = "%s committed." % String(action_surface.get("label", "Route order")).strip_edges()
	var expected_result_text := (
		"Route cursor canceled from %d,%d. Selection returned to the active hero." % [int(selected_before_action.get("x", -1)), int(selected_before_action.get("y", -1))]
		if action_kind == "cancel"
		else "Route order result: %s" % expected_result_message
	)
	var immediate_checks := {
		"inactive": not bool(result_snapshot.get("active", true)),
		"result_immediate": result_text != "" and result_text.length() <= SEMANTIC_MAX_CHARS,
		"result_kind": String(result_pending.get("kind", "")) == "result_clear",
		"label_identity": String(result_pending.get("label_text", "")) == result_text,
		"method_matched_result_text": result_text == expected_result_text.left(SEMANTIC_MAX_CHARS),
		"last_message_direct_exact": action_kind == "cancel" or expected_result_message == String(direct_result.get("message", "")).strip_edges(),
		"session_reference": is_same(result_pending.get("session_ref"), session),
		"selected_source_exact": selected_before_action == action_selected.get("selected_tile", {}),
		"action_id_exact": action_id == "march_selected",
		"cancel_once": int(result_snapshot.get("cancel_count", 0)) == (1 if action_kind == "cancel" else 0),
		"accept_once": int(result_snapshot.get("accept_count", 0)) == (1 if action_kind == "accept" else 0),
		"primary_once": int(result_snapshot.get("primary_action_invocation_count", 0)) == (1 if action_kind == "accept" else 0),
	}
	if not _checks_exact(immediate_checks):
		_fail("%d physical %s result was not immediate and exactly once." % [width, action_kind], {"checks": immediate_checks, "cursor": _compact_cursor(result_snapshot), "pending": _semantic_pending_compact(result_pending), "selected": action_selected.get("selected_tile")})
		await _discard_width_shell(host, shell)
		return {}
	await get_tree().create_timer(SEMANTIC_RESULT_SECONDS / 2.0).timeout
	if live.text != result_text:
		_fail("%d route result cleared before 1200 ms." % width, {"expected": result_text, "actual": live.text})
		await _discard_width_shell(host, shell)
		return {}
	await get_tree().create_timer((SEMANTIC_RESULT_SECONDS / 2.0) + 0.05).timeout
	if live.text != "" or not (shell.get("_controller_route_semantic_pending") as Dictionary).is_empty():
		_fail("%d route result did not clear after 1200 ms." % width, {"actual": live.text, "pending": shell.get("_controller_route_semantic_pending")})
		await _discard_width_shell(host, shell)
		return {}

	# Cancel is authority-preserving; accept is consequence-bearing and must change
	# only through the existing primary action. Both retain save/cache/settings/files.
	var after_result_authority: Dictionary = _route_semantic_authority(shell, session)
	var cancel_authority_checks: Dictionary = _route_semantic_authority_checks(before_result_authority, after_result_authority, session)
	var cancel_whole_object_aggregate_diagnostic := before_result_authority == after_result_authority
	var route_consequence_exact: bool = _checks_exact(cancel_authority_checks) if action_kind == "cancel" else (
		direct_control != null
		and session.to_dict() == direct_control.to_dict()
		and _route_semantic_non_session_authority(before_result_authority) == _route_semantic_non_session_authority(after_result_authority)
		and is_same(before_result_authority.get("session_ref"), after_result_authority.get("session_ref"))
		and String(before_result_authority.get("session_id", "")) == String(after_result_authority.get("session_id", ""))
	)
	if not route_consequence_exact:
		var consequence_details: Dictionary = {
			"action_kind": action_kind,
			"direct_session_exact": action_kind == "cancel" or (direct_control != null and session.to_dict() == direct_control.to_dict()),
			"non_session_authority_exact": _route_semantic_non_session_authority(before_result_authority) == _route_semantic_non_session_authority(after_result_authority),
		}
		if action_kind == "cancel":
			consequence_details = _route_semantic_authority_failure_details(
				cancel_authority_checks,
				before_result_authority,
				after_result_authority,
				session,
				cancel_whole_object_aggregate_diagnostic
			)
		_fail("%d physical %s route consequence/authority was not exact." % [width, action_kind], consequence_details)
		await _discard_width_shell(host, shell)
		return {}

	# A new step must invalidate an older result-clear generation and survive the
	# stale clear callback.
	shell.validation_reset_controller_route_cursor()
	shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _press_joypad_button(JOY_BUTTON_B)
	var stale_result: Dictionary = (shell.get("_controller_route_semantic_pending") as Dictionary).duplicate(true)
	shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 0.0)
	shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	var replacement_pending: Dictionary = (shell.get("_controller_route_semantic_pending") as Dictionary).duplicate(true)
	var replacement_cursor_before_release: Dictionary = shell.validation_controller_route_cursor_snapshot()
	await _send_joypad_axis_immediate(JOY_AXIS_RIGHT_X, 0.0)
	var replacement_cursor_after_release: Dictionary = shell.validation_controller_route_cursor_snapshot()
	var replacement_pending_live: Dictionary = shell.get("_controller_route_semantic_pending")
	var replacement_pre_poll_checks := {
		"context_pending": String(replacement_pending.get("kind", "")) == "context",
		"generation_replaced": int(replacement_pending.get("generation", -1)) != int(stale_result.get("generation", -1)),
		"route_direction_zero": replacement_cursor_after_release.get("direction", {}) == _tile_payload(Vector2i.ZERO),
		"repeat_timer_inactive": not bool(replacement_cursor_after_release.get("repeat_timer_active", true)),
		"selected_tile_unchanged": replacement_cursor_after_release.get("selected_tile", {}) == replacement_cursor_before_release.get("selected_tile", {}),
		"step_count_unchanged": int(replacement_cursor_after_release.get("step_count", -1)) == int(replacement_cursor_before_release.get("step_count", -1)),
		"timer_active": not semantic_timer.is_stopped(),
		"timer_wait_exact": is_equal_approx(semantic_timer.wait_time, SEMANTIC_DEBOUNCE_SECONDS),
		"label_empty": live.text == "",
		"pending_values_exact": _semantic_pending_compact(replacement_pending_live) == _semantic_pending_compact(replacement_pending),
		"pending_session_ref_exact": is_same(replacement_pending_live.get("session_ref"), replacement_pending.get("session_ref")),
	}
	if not _checks_exact(replacement_pre_poll_checks):
		_fail("%d physical axis release did not preserve the exact replacement context before its real Timer poll." % width, {"checks": replacement_pre_poll_checks, "stale": _semantic_pending_compact(stale_result), "replacement": _semantic_pending_compact(replacement_pending), "live_pending": _semantic_pending_compact(replacement_pending_live), "cursor_before_release": _compact_cursor(replacement_cursor_before_release), "cursor_after_release": _compact_cursor(replacement_cursor_after_release), "timer_wait": semantic_timer.wait_time, "timer_stopped": semantic_timer.is_stopped(), "live": live.text})
		await _discard_width_shell(host, shell)
		return {}
	var replacement_poll_started_msec := Time.get_ticks_msec()
	var replacement_poll_deadline_msec := replacement_poll_started_msec + 1000
	while Time.get_ticks_msec() <= replacement_poll_deadline_msec:
		var current_pending: Dictionary = shell.get("_controller_route_semantic_pending")
		if current_pending.is_empty() or live.text != "":
			break
		await get_tree().process_frame
	var replacement_elapsed_msec := Time.get_ticks_msec() - replacement_poll_started_msec
	var replacement_text := live.text
	var replacement_after_pending: Dictionary = shell.get("_controller_route_semantic_pending")
	var replacement_publish_checks := {
		"within_deadline": replacement_elapsed_msec <= 1000,
		"pending_empty": replacement_after_pending.is_empty(),
		"replacement_label_exact": replacement_text == String(replacement_pending.get("text", "")),
		"timer_stopped": semantic_timer.is_stopped(),
	}
	if not _checks_exact(replacement_publish_checks):
		_fail("%d replacement route context did not publish through its real Timer within 1000 ms." % width, {"checks": replacement_publish_checks, "elapsed_msec": replacement_elapsed_msec, "replacement": _semantic_pending_compact(replacement_pending), "after_pending": _semantic_pending_compact(replacement_after_pending), "replacement_text": replacement_text, "timer_wait": semantic_timer.wait_time, "timer_stopped": semantic_timer.is_stopped()})
		await _discard_width_shell(host, shell)
		return {}
	shell.call("_clear_controller_route_semantic_result", stale_result)
	var stale_clear_checks := {
		"replacement_label_unchanged": live.text == replacement_text,
		"pending_remains_empty": (shell.get("_controller_route_semantic_pending") as Dictionary).is_empty(),
		"timer_remains_stopped": semantic_timer.is_stopped(),
	}
	if not _checks_exact(stale_clear_checks):
		_fail("%d stale result-clear identity changed the published replacement context." % width, {"checks": stale_clear_checks, "elapsed_msec": replacement_elapsed_msec, "stale": _semantic_pending_compact(stale_result), "replacement": _semantic_pending_compact(replacement_pending), "replacement_text": replacement_text, "current_text": live.text, "current_pending": _semantic_pending_compact(shell.get("_controller_route_semantic_pending"))})
		await _discard_width_shell(host, shell)
		return {}

	if _route_semantic_non_session_authority(authority_before) != _route_semantic_non_session_authority(_route_semantic_authority(shell, session)):
		_fail("%d semantic matrix changed save/cache/settings/file authority." % width)
		await _discard_width_shell(host, shell)
		return {}
	shell.call("_exit_tree")
	if live.text != "" or not semantic_timer.is_stopped() or not (shell.get("_controller_route_semantic_pending") as Dictionary).is_empty():
		_fail("%d route semantic exit did not synchronously clear timer/pending/live state." % width)
		await _discard_width_shell(host, shell)
		return {}
	await _discard_width_shell(host, shell)
	return {"width": width, "result": action_kind, "context_chars": published_text.length(), "authority_exact": true}


func _validate_cursor_preview_and_direction_state() -> Dictionary:
	_clear_save_files()
	var opened := await _create_shell(Vector2i(12, 8), 30, Vector2i(24, 16))
	var shell: Node = opened.get("shell", null)
	var session = opened.get("session", null)
	if shell == null or session == null or not _require_hooks(shell):
		await _discard_shell(shell)
		return {}
	var save_result: Dictionary = SaveService.save_runtime_autosave_session(session)
	if not bool(save_result.get("ok", false)):
		_fail("Could not seed the autosave mutation boundary.", _compact(save_result))
		await _discard_shell(shell)
		return {}
	var session_before := _canonical(session.to_dict())
	var day_before: int = session.day
	var movement_before := _movement_snapshot(session)
	var autosave_before := _file_state(AUTOSAVE_PATH)
	var reset: Dictionary = shell.validation_reset_controller_route_cursor()
	var hero_tile: Dictionary = reset.get("hero_tile", {})

	var dead: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 0.50)
	if bool(dead.get("active", false)) or int(dead.get("step_count", -1)) != 0 \
			or dead.get("selected_tile", {}) != hero_tile:
		_fail("Sub-dead-zone right-stick input moved or activated the route cursor.", _compact_cursor(dead))
		await _discard_shell(shell)
		return {}

	var cardinal: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	var expected_right := _offset_tile(hero_tile, Vector2i.RIGHT)
	if not bool(cardinal.get("active", false)) or cardinal.get("selected_tile", {}) != expected_right \
			or int(cardinal.get("step_count", 0)) != 1:
		_fail("Cardinal right-stick input did not move the route cursor exactly once.", _compact_cursor(cardinal))
		await _discard_shell(shell)
		return {}
	if (cardinal.get("route_preview", {}) as Dictionary).is_empty() \
			or String((cardinal.get("primary_action", {}) as Dictionary).get("id", "")) == "":
		_fail("Route-cursor selection did not expose the existing preview and primary action.", _compact_cursor(cardinal))
		await _discard_shell(shell)
		return {}
	if cardinal.get("camera_focus_tile", {}) != expected_right:
		_fail("Route-cursor selection did not pan the camera with the selected tile.", _compact_cursor(cardinal))
		await _discard_shell(shell)
		return {}

	var held: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	if int(held.get("step_count", 0)) != 1 or held.get("selected_tile", {}) != expected_right:
		_fail("A held cardinal axis stepped before the repeat gate.", _compact_cursor(held))
		await _discard_shell(shell)
		return {}
	var opposed: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, -1.0)
	if int(opposed.get("step_count", 0)) != 2 or opposed.get("selected_tile", {}) != hero_tile:
		_fail("An opposed axis did not deterministically reverse one tile.", _compact_cursor(opposed))
		await _discard_shell(shell)
		return {}
	var release: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 0.0)
	if release.get("direction", {}) != {"x": 0, "y": 0} or bool(release.get("repeat_timer_active", true)):
		_fail("Right-stick release did not re-arm and stop repeat.", _compact_cursor(release))
		await _discard_shell(shell)
		return {}

	var up: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_Y, -1.0)
	var expected_up := _offset_tile(hero_tile, Vector2i.UP)
	if up.get("selected_tile", {}) != expected_up or int(up.get("step_count", 0)) != 3:
		_fail("Cardinal vertical input did not move one tile.", _compact_cursor(up))
		await _discard_shell(shell)
		return {}
	var vertical_release: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_Y, 0.0)
	var right_again: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	var dominated: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_Y, -0.80)
	if dominated.get("selected_tile", {}) != right_again.get("selected_tile", {}) \
			or int(dominated.get("step_count", 0)) != int(right_again.get("step_count", 0)):
		_fail("A weaker opposed cardinal axis overrode the dominant held axis.", _compact_cursor(dominated))
		await _discard_shell(shell)
		return {}
	var tie_opposed: Dictionary = shell.validation_controller_route_axis(JOY_AXIS_RIGHT_Y, -1.0)
	if tie_opposed.get("selected_tile", {}) != _offset_tile(right_again.get("selected_tile", {}), Vector2i.UP):
		_fail("Equal opposed axes did not resolve deterministically to the newly dominant vertical axis.", _compact_cursor(tie_opposed))
		await _discard_shell(shell)
		return {}
	var repeated: Dictionary = shell.validation_controller_route_repeat()
	if int(repeated.get("repeat_count", 0)) != 1 \
			or int(repeated.get("step_count", 0)) != int(tie_opposed.get("step_count", 0)) + 1 \
			or not bool((repeated.get("last_step", {}) as Dictionary).get("repeat", false)):
		_fail("Deterministic repeat did not add exactly one held-direction step.", _compact_cursor(repeated))
		await _discard_shell(shell)
		return {}

	if _canonical(session.to_dict()) != session_before or session.day != day_before \
			or _movement_snapshot(session) != movement_before or _file_state(AUTOSAVE_PATH) != autosave_before:
		_fail("Route preview changed the session, day, movement, or autosave bytes before confirmation.", {
			"session_equal": _canonical(session.to_dict()) == session_before,
			"day": session.day,
			"movement": _movement_snapshot(session),
			"autosave_equal": _file_state(AUTOSAVE_PATH) == autosave_before,
		})
		await _discard_shell(shell)
		return {}
	await _discard_shell(shell)
	return {
		"dead_zone": true,
		"cardinal": true,
		"opposed": true,
		"release": true,
		"repeat": true,
		"session_unchanged": true,
		"autosave_unchanged": true,
	}


func _validate_cancel_accept_left_move_and_boundary() -> Dictionary:
	var cancel_opened := await _create_shell(Vector2i(6, 4), 20, Vector2i(14, 9))
	var cancel_shell: Node = cancel_opened.get("shell", null)
	var cancel_session = cancel_opened.get("session", null)
	if cancel_shell == null or cancel_session == null or not _require_hooks(cancel_shell):
		await _discard_shell(cancel_shell)
		return {}
	var before_cancel := _canonical(cancel_session.to_dict())
	var before_cancel_save := _file_state(AUTOSAVE_PATH)
	cancel_shell.validation_reset_controller_route_cursor()
	cancel_shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _press_joypad_button(JOY_BUTTON_B)
	var canceled: Dictionary = cancel_shell.validation_controller_route_cursor_snapshot()
	if bool(canceled.get("active", true)) or int(canceled.get("cancel_count", 0)) != 1 \
			or canceled.get("selected_tile", {}) != canceled.get("hero_tile", {}) \
			or canceled.get("camera_focus_tile", {}) != canceled.get("hero_tile", {}):
		_fail("Controller B did not reset route selection and camera exactly to the hero.", _compact_cursor(canceled))
		await _discard_shell(cancel_shell)
		return {}
	if _canonical(cancel_session.to_dict()) != before_cancel or _file_state(AUTOSAVE_PATH) != before_cancel_save:
		_fail("Controller B reset mutated gameplay state or autosave bytes.")
		await _discard_shell(cancel_shell)
		return {}
	await _discard_shell(cancel_shell)

	var accept_opened := await _create_shell(Vector2i(4, 3), 20, Vector2i(12, 8))
	var accept_shell: Node = accept_opened.get("shell", null)
	var accept_session = accept_opened.get("session", null)
	if accept_shell == null or accept_session == null or not _require_hooks(accept_shell):
		await _discard_shell(accept_shell)
		return {}
	accept_shell.validation_reset_controller_route_cursor()
	var hero_before_accept := OverworldRules.hero_position(accept_session)
	var movement_before_accept := _movement_snapshot(accept_session)
	var selected: Dictionary = accept_shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _press_joypad_button(JOY_BUTTON_A)
	var accepted: Dictionary = accept_shell.validation_controller_route_cursor_snapshot()
	var last_accept: Dictionary = accepted.get("last_accept", {}) if accepted.get("last_accept", {}) is Dictionary else {}
	if int(accepted.get("accept_count", 0)) != 1 or int(accepted.get("primary_action_invocation_count", 0)) != 1 \
			or int(last_accept.get("invocation_count_delta", 0)) != 1 or not bool(last_accept.get("activated", false)) \
			or bool(accepted.get("active", true)):
		_fail("Controller A did not invoke the existing selected primary action exactly once.", _compact_cursor(accepted))
		await _discard_shell(accept_shell)
		return {}
	if OverworldRules.hero_position(accept_session) == hero_before_accept \
			or _movement_snapshot(accept_session) == movement_before_accept \
			or last_accept.get("selected_tile_before", {}) != selected.get("selected_tile", {}):
		_fail("Controller A did not commit the selected route through gameplay movement.", {
			"last_accept": last_accept,
			"hero_before": _tile_payload(hero_before_accept),
			"hero_after": _tile_payload(OverworldRules.hero_position(accept_session)),
			"movement_before": movement_before_accept,
			"movement_after": _movement_snapshot(accept_session),
		})
		await _discard_shell(accept_shell)
		return {}
	await _discard_shell(accept_shell)

	var left_opened := await _create_shell(Vector2i(4, 3), 20, Vector2i(12, 8))
	var left_shell: Node = left_opened.get("shell", null)
	var left_session = left_opened.get("session", null)
	if left_shell == null or left_session == null or not _require_hooks(left_shell):
		await _discard_shell(left_shell)
		return {}
	left_shell.validation_reset_controller_route_cursor()
	var left_hero_before := OverworldRules.hero_position(left_session)
	var left_movement_before := _movement_snapshot(left_session)
	await _send_joypad_axis(JOY_AXIS_LEFT_X, 1.0)
	await _send_joypad_axis(JOY_AXIS_LEFT_X, 0.0)
	var left_snapshot: Dictionary = left_shell.validation_controller_route_cursor_snapshot()
	if OverworldRules.hero_position(left_session) != left_hero_before + Vector2i.RIGHT \
			or _movement_snapshot(left_session) == left_movement_before \
			or int(left_snapshot.get("left_move_count", 0)) != 1 \
			or int(left_snapshot.get("step_count", 0)) != 0:
		_fail("Left-stick immediate movement changed or was replaced by route-cursor behavior.", {
			"cursor": _compact_cursor(left_snapshot),
			"hero_before": _tile_payload(left_hero_before),
			"hero_after": _tile_payload(OverworldRules.hero_position(left_session)),
			"movement_before": left_movement_before,
			"movement_after": _movement_snapshot(left_session),
		})
		await _discard_shell(left_shell)
		return {}
	await _discard_shell(left_shell)

	var boundary_opened := await _create_shell(Vector2i.ZERO, 20, Vector2i(8, 6))
	var boundary_shell: Node = boundary_opened.get("shell", null)
	var boundary_session = boundary_opened.get("session", null)
	if boundary_shell == null or boundary_session == null or not _require_hooks(boundary_shell):
		await _discard_shell(boundary_shell)
		return {}
	boundary_shell.validation_reset_controller_route_cursor()
	var boundary_before := _canonical(boundary_session.to_dict())
	var bounded: Dictionary = boundary_shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, -1.0)
	var bounded_step: Dictionary = bounded.get("last_step", {}) if bounded.get("last_step", {}) is Dictionary else {}
	if bounded.get("selected_tile", {}) != {"x": 0, "y": 0} or int(bounded.get("step_count", -1)) != 0 \
			or bool(bounded_step.get("changed", true)) or not bool(bounded_step.get("bounded", false)):
		_fail("Right-stick route cursor crossed or wrapped the map boundary.", _compact_cursor(bounded))
		await _discard_shell(boundary_shell)
		return {}
	if _canonical(boundary_session.to_dict()) != boundary_before:
		_fail("A bounded route-cursor step mutated the session.")
		await _discard_shell(boundary_shell)
		return {}
	await _discard_shell(boundary_shell)
	return {"cancel": true, "accept_once": true, "left_stick_move": true, "boundary": true}


func _validate_interaction_blockers() -> Dictionary:
	var opened := await _create_shell(Vector2i(6, 4), 20, Vector2i(14, 9))
	var shell: Node = opened.get("shell", null)
	var session = opened.get("session", null)
	if shell == null or session == null or not _require_hooks(shell):
		await _discard_shell(shell)
		return {}
	var session_before := _canonical(session.to_dict())
	var autosave_before := _file_state(AUTOSAVE_PATH)
	var blockers := {}

	shell.validation_reset_controller_route_cursor()
	var drawer: Dictionary = shell.validation_open_command_drawer()
	if String(drawer.get("active_drawer", "")) != "command" or not await _assert_right_input_blocked(shell, "drawer_open"):
		await _discard_shell(shell)
		return {}
	blockers["drawer"] = true
	shell.call("_on_close_drawers_pressed")
	await _settle()

	var settings: Dictionary = shell.validation_open_active_play_settings()
	if not bool(settings.get("visible", false)) or not await _assert_right_input_blocked(shell, "settings_open"):
		await _discard_shell(shell)
		return {}
	blockers["settings"] = true
	var settings_dialog = shell.validation_active_play_settings_dialog()
	settings_dialog.close_dialog()
	await _settle()

	var save_picker: OptionButton = shell.get_node_or_null("%SaveSlot")
	if save_picker == null:
		_fail("Overworld shell is missing its save-slot picker.")
		await _discard_shell(shell)
		return {}
	save_picker.get_popup().popup(Rect2i(20, 20, 180, 120))
	await _settle()
	if not save_picker.get_popup().visible or not await _assert_right_input_blocked(shell, "save_popup_open"):
		await _discard_shell(shell)
		return {}
	blockers["save_popup"] = true
	save_picker.get_popup().hide()
	await _settle()

	if SaveService.save_manual_session(session.to_dict(), MANUAL_SLOT) == "":
		_fail("Could not seed the occupied manual-save confirmation fixture.")
		await _discard_shell(shell)
		return {}
	SaveService.set_selected_manual_slot(MANUAL_SLOT)
	var overwrite: Dictionary = shell.validation_request_manual_save()
	if not bool(overwrite.get("visible", false)) or not await _assert_right_input_blocked(shell, "save_confirmation_open"):
		await _discard_shell(shell)
		return {}
	blockers["manual_overwrite"] = true
	shell.validation_cancel_manual_save_overwrite()
	await _settle()

	var end_turn: Dictionary = shell.validation_request_end_turn()
	var end_turn_snapshot: Dictionary = shell.validation_end_turn_confirmation_snapshot()
	if not bool(end_turn.get("confirmation_required", false)) or not bool(end_turn_snapshot.get("dialog_visible", false)) \
			or not await _assert_right_input_blocked(shell, "end_turn_confirmation_open"):
		_fail("Could not establish the warned End Turn confirmation blocker.", _compact(end_turn_snapshot))
		await _discard_shell(shell)
		return {}
	blockers["end_turn_confirmation"] = true
	shell.validation_cancel_end_turn_confirmation()

	if _canonical(session.to_dict()) != session_before or _file_state(AUTOSAVE_PATH) != autosave_before:
		_fail("Blocked right-stick input changed the session or autosave bytes.", {
			"session_equal": _canonical(session.to_dict()) == session_before,
			"autosave_equal": _file_state(AUTOSAVE_PATH) == autosave_before,
		})
		await _discard_shell(shell)
		return {}
	await _discard_shell(shell)
	return blockers


func _assert_right_input_blocked(shell: Node, expected_reason: String) -> bool:
	await _send_joypad_axis(JOY_AXIS_RIGHT_X, 0.0)
	var before: Dictionary = shell.validation_controller_route_cursor_snapshot()
	await _send_joypad_axis(JOY_AXIS_RIGHT_X, 1.0)
	var after: Dictionary = shell.validation_controller_route_cursor_snapshot()
	await _send_joypad_axis(JOY_AXIS_RIGHT_X, 0.0)
	if String(after.get("blocked_reason", "")) != expected_reason \
			or after.get("selected_tile", {}) != before.get("selected_tile", {}) \
			or int(after.get("step_count", 0)) != int(before.get("step_count", 0)) \
			or bool(after.get("active", false)):
		return _fail("Right-stick input was not blocked by %s." % expected_reason, {
			"before": _compact_cursor(before),
			"after": _compact_cursor(after),
		})
	return true


func _validate_route_semantic_identity_guards(shell: Node, session, live: Label) -> bool:
	# A stale generation is ignored rather than published.
	shell.validation_reset_controller_route_cursor()
	shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	var generation_pending: Dictionary = (shell.get("_controller_route_semantic_pending") as Dictionary).duplicate(true)
	generation_pending["generation"] = int(generation_pending.get("generation", 0)) - 1
	shell.set("_controller_route_semantic_pending", generation_pending)
	shell.call("_on_controller_route_semantic_timeout")
	if live.text != "":
		return _fail("Stale semantic generation published route context.", _semantic_pending_compact(generation_pending))
	shell.call("_cancel_controller_route_semantic")

	# A refreshed route generation invalidates the cached route/action description.
	shell.validation_reset_controller_route_cursor()
	shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	var route_state: Dictionary = (shell.get("_selected_route_state") as Dictionary).duplicate(true)
	route_state["generation"] = int(route_state.get("generation", 0)) + 1
	shell.set("_selected_route_state", route_state)
	shell.call("_on_controller_route_semantic_timeout")
	if live.text != "" or not (shell.get("_controller_route_semantic_pending") as Dictionary).is_empty():
		return _fail("Stale route generation published route context.", shell.get("_controller_route_semantic_pending"))

	# Session-id drift invalidates the pending context even on the same object.
	shell.validation_reset_controller_route_cursor()
	shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	var original_session_id := String(session.session_id)
	session.session_id = "%s-stale" % original_session_id
	shell.call("_on_controller_route_semantic_timeout")
	session.session_id = original_session_id
	if live.text != "" or not (shell.get("_controller_route_semantic_pending") as Dictionary).is_empty():
		return _fail("Changed session id published stale route context.")

	# A different active session must reject both the cached reference and id.
	shell.validation_reset_controller_route_cursor()
	shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	var replacement = _session_with_map(18, 12)
	SessionState.set_active_session(replacement)
	shell.call("_on_controller_route_semantic_timeout")
	SessionState.active_session = session
	if live.text != "" or not (shell.get("_controller_route_semantic_pending") as Dictionary).is_empty():
		return _fail("Active-session replacement published stale route context.")

	# Even with the correct active session, a mismatched cached object reference fails.
	shell.validation_reset_controller_route_cursor()
	shell.validation_controller_route_axis(JOY_AXIS_RIGHT_X, 1.0)
	var reference_pending: Dictionary = (shell.get("_controller_route_semantic_pending") as Dictionary).duplicate(true)
	reference_pending["session_ref"] = replacement
	shell.set("_controller_route_semantic_pending", reference_pending)
	shell.call("_on_controller_route_semantic_timeout")
	if live.text != "" or not (shell.get("_controller_route_semantic_pending") as Dictionary).is_empty():
		return _fail("Mismatched pending session reference published route context.")
	return true


func _create_width_shell(hero_tile: Vector2i, movement_points: int, map_size: Vector2i, width: int) -> Dictionary:
	var session = _session_with_map(map_size.x, map_size.y)
	_set_active_hero_position(session, hero_tile)
	_set_active_hero_movement(session, movement_points)
	session.overworld["fog"] = {}
	OverworldRules.refresh_fog_of_war(session)
	var active_session = SessionState.set_active_session(session)
	get_window().size = Vector2i(width, 720)
	var host := Control.new()
	host.name = "RouteSemanticHost%d" % width
	host.size = Vector2(float(width), 720.0)
	add_child(host)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	host.add_child(shell)
	for _frame in range(4):
		await get_tree().process_frame
	var shell_session = shell.get("_session")
	if shell_session != null:
		active_session = shell_session
	shell.call("_set_selected_tile", hero_tile)
	shell.call("_refresh")
	await _settle()
	return {"host": host, "shell": shell, "session": active_session}


func _discard_width_shell(host: Control, shell: Node) -> void:
	if host != null and is_instance_valid(host):
		host.queue_free()
	elif shell != null and is_instance_valid(shell):
		shell.queue_free()
	await get_tree().process_frame


func _route_semantic_authority(shell: Node, session) -> Dictionary:
	var settings_transaction: Dictionary = SettingsService.validation_settings_transaction_snapshot()
	return {
		"session": session.to_dict().duplicate(true),
		"files": _capture_file_states(_authority_paths()),
		"save_cache": SaveService.validation_summary_cache_snapshot(),
		# Keep the raw Object-bearing transaction for whole-snapshot diagnostics.
		# Authority compares the full transaction with only InputEvent instances
		# represented by their method-matched stored-property payload.
		"settings": settings_transaction,
		"settings_canonical": _canonical_settings_transaction(settings_transaction),
		"session_ref": session,
		"session_id": String(session.session_id),
		"game_state": String(session.game_state),
		"scenario_status": String(session.scenario_status),
		"shell_session_ref": shell.get("_session"),
	}


func _route_semantic_non_session_authority(authority: Dictionary) -> Dictionary:
	return {
		"files": authority.get("files", {}),
		"save_cache": authority.get("save_cache", {}),
		"settings": authority.get("settings_canonical", {}),
	}


func _route_semantic_authority_checks(before: Dictionary, after: Dictionary, session) -> Dictionary:
	return {
		"session_payload_exact": before.get("session", {}) == after.get("session", {}),
		"files_exact": before.get("files", {}) == after.get("files", {}),
		"save_cache_exact": before.get("save_cache", {}) == after.get("save_cache", {}),
		"settings_exact": before.get("settings_canonical", {}) == after.get("settings_canonical", {}),
		"session_id_exact": String(before.get("session_id", "")) == String(after.get("session_id", "")),
		"game_state_exact": String(before.get("game_state", "")) == String(after.get("game_state", "")),
		"scenario_status_exact": String(before.get("scenario_status", "")) == String(after.get("scenario_status", "")),
		"before_session_ref_is_session": is_same(before.get("session_ref"), session),
		"after_session_ref_is_session": is_same(after.get("session_ref"), session),
		"session_ref_identity_exact": is_same(before.get("session_ref"), after.get("session_ref")),
		"before_shell_session_ref_is_session": is_same(before.get("shell_session_ref"), session),
		"after_shell_session_ref_is_session": is_same(after.get("shell_session_ref"), session),
		"shell_session_ref_identity_exact": is_same(before.get("shell_session_ref"), after.get("shell_session_ref")),
	}


func _route_semantic_authority_failure_details(
	checks: Dictionary,
	before: Dictionary,
	after: Dictionary,
	session,
	whole_object_aggregate_diagnostic: bool
) -> Dictionary:
	var failed: Array[String] = []
	for key_value in checks.keys():
		var key := String(key_value)
		if not bool(checks.get(key_value, false)):
			failed.append(key)
	var differing_values := {}
	var value_keys := {
		"session_payload_exact": "session",
		"files_exact": "files",
		"save_cache_exact": "save_cache",
		"settings_exact": "settings_canonical",
		"session_id_exact": "session_id",
		"game_state_exact": "game_state",
		"scenario_status_exact": "scenario_status",
	}
	for check_name in value_keys.keys():
		if check_name in failed:
			var authority_key := String(value_keys[check_name])
			differing_values[authority_key] = {
				"before": before.get(authority_key),
				"after": after.get(authority_key),
			}
	var identity_values := {}
	for identity_name in [
		"before_session_ref_is_session",
		"after_session_ref_is_session",
		"session_ref_identity_exact",
		"before_shell_session_ref_is_session",
		"after_shell_session_ref_is_session",
		"shell_session_ref_identity_exact",
	]:
		if identity_name in failed:
			identity_values[identity_name] = {
				"session": session,
				"before_session_ref": before.get("session_ref"),
				"after_session_ref": after.get("session_ref"),
				"before_shell_session_ref": before.get("shell_session_ref"),
				"after_shell_session_ref": after.get("shell_session_ref"),
			}
	return {
		"checks": checks,
		"failed": failed,
		"differing_values": differing_values,
		"identity_values": identity_values,
		"whole_object_aggregate_diagnostic": whole_object_aggregate_diagnostic,
	}


func _canonical_settings_transaction(transaction: Dictionary) -> Dictionary:
	var canonical: Dictionary = transaction.duplicate(true)
	var canonical_input_map := {}
	var input_map: Dictionary = transaction.get("input_map", {}) if transaction.get("input_map", {}) is Dictionary else {}
	for action_value in input_map.keys():
		var action := String(action_value)
		var action_state: Dictionary = input_map.get(action_value, {}) if input_map.get(action_value, {}) is Dictionary else {}
		var canonical_events: Array = []
		var events: Array = action_state.get("events", []) if action_state.get("events", []) is Array else []
		for event_value in events:
			if event_value is InputEvent:
				canonical_events.append(_canonical_stored_input_event(event_value as InputEvent))
			else:
				canonical_events.append({
					"class": "",
					"as_text": var_to_str(event_value),
					"stored_properties": [],
				})
		canonical_input_map[action] = {
			"action": action,
			"exists": bool(action_state.get("exists", false)),
			"deadzone": float(action_state.get("deadzone", 0.5)),
			"events": canonical_events,
		}
	canonical["input_map"] = canonical_input_map
	return canonical


func _canonical_stored_input_event(event: InputEvent) -> Dictionary:
	var stored_properties: Array = []
	for property_value in event.get_property_list():
		if not (property_value is Dictionary):
			continue
		var property: Dictionary = property_value
		var property_name := String(property.get("name", ""))
		var property_usage := int(property.get("usage", 0))
		if property_name == "script" or (property_usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		stored_properties.append({
			"name": property_name,
			"value": var_to_str(event.get(property_name)),
		})
	return {
		"class": event.get_class(),
		"as_text": event.as_text(),
		"stored_properties": stored_properties,
	}


func _semantic_pending_compact(pending: Dictionary) -> Dictionary:
	return {
		"kind": String(pending.get("kind", "")),
		"generation": int(pending.get("generation", -1)),
		"session_id": String(pending.get("session_id", "")),
		"selected_tile": pending.get("selected_tile", {}),
		"route_generation": int(pending.get("route_generation", -1)),
		"text": String(pending.get("text", pending.get("label_text", ""))),
	}


func _checks_exact(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true


func _create_shell(hero_tile: Vector2i, movement_points: int, map_size: Vector2i) -> Dictionary:
	var session = _session_with_map(map_size.x, map_size.y)
	_set_active_hero_position(session, hero_tile)
	_set_active_hero_movement(session, movement_points)
	session.overworld["fog"] = {}
	OverworldRules.refresh_fog_of_war(session)
	var active_session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	for _frame in range(4):
		await get_tree().process_frame
	var shell_session = shell.get("_session")
	if shell_session != null:
		active_session = shell_session
	shell.call("_set_selected_tile", hero_tile)
	shell.call("_refresh")
	await _settle()
	return {"shell": shell, "session": active_session}


func _session_with_map(width: int, height: int):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var rows := []
	for _y in range(height):
		var row := []
		for _x in range(width):
			row.append("grass")
		rows.append(row)
	session.overworld["map"] = rows
	session.overworld["map_size"] = {"width": width, "height": height, "x": width, "y": height}
	session.overworld["terrain_layers"] = {}
	session.overworld["towns"] = [{
		"placement_id": "riverwatch_hold",
		"town_id": "town_riverwatch",
		"x": 0,
		"y": 0,
		"owner": "player",
	}]
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	session.overworld["enemy_heroes"] = []
	OverworldRules.refresh_fog_of_war(session)
	return session


func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_hero_id:
			var entry: Dictionary = heroes[index]
			entry["position"] = position.duplicate(true)
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes


func _set_active_hero_movement(session, movement_points: int) -> void:
	var movement := {"current": movement_points, "max": movement_points}
	session.overworld["movement"] = movement.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["base_movement"] = movement_points
	hero["movement"] = movement.duplicate(true)
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_hero_id:
			var entry: Dictionary = heroes[index]
			entry["base_movement"] = movement_points
			entry["movement"] = movement.duplicate(true)
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes


func _require_hooks(shell: Node) -> bool:
	for method_name in [
		"validation_reset_controller_route_cursor",
		"validation_controller_route_axis",
		"validation_controller_route_repeat",
		"validation_controller_route_accept",
		"validation_controller_route_cancel",
		"validation_controller_route_cursor_snapshot",
	]:
		if not shell.has_method(method_name):
			return _fail("OverworldShell is missing controller route hook %s." % method_name)
	return true


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


func _send_joypad_axis(axis: int, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis as JoyAxis
	motion.axis_value = value
	Input.parse_input_event(motion)
	await _settle()


func _send_joypad_axis_immediate(axis: int, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis as JoyAxis
	motion.axis_value = value
	Input.parse_input_event(motion)
	await get_tree().process_frame


func _movement_snapshot(session) -> Dictionary:
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	var movement: Dictionary = hero.get("movement", {}) if hero.get("movement", {}) is Dictionary else {}
	return {
		"current": int(movement.get("current", session.overworld.get("movement", {}).get("current", 0))),
		"max": int(movement.get("max", session.overworld.get("movement", {}).get("max", 0))),
	}


func _compact_cursor(snapshot: Dictionary) -> Dictionary:
	return {
		"active": bool(snapshot.get("active", false)),
		"axis": snapshot.get("axis", {}),
		"direction": snapshot.get("direction", {}),
		"selected": snapshot.get("selected_tile", {}),
		"hero": snapshot.get("hero_tile", {}),
		"camera": snapshot.get("camera_focus_tile", {}),
		"primary_action_id": String((snapshot.get("primary_action", {}) as Dictionary).get("id", "")),
		"route_preview_empty": (snapshot.get("route_preview", {}) as Dictionary).is_empty(),
		"steps": int(snapshot.get("step_count", 0)),
		"repeats": int(snapshot.get("repeat_count", 0)),
		"accepts": int(snapshot.get("accept_count", 0)),
		"cancels": int(snapshot.get("cancel_count", 0)),
		"blocked": int(snapshot.get("blocked_count", 0)),
		"blocked_reason": String(snapshot.get("blocked_reason", "")),
		"last_step": snapshot.get("last_step", {}),
		"last_accept": snapshot.get("last_accept", {}),
	}


func _compact(value: Dictionary) -> Dictionary:
	var compact := {}
	for key in ["ok", "reason", "message", "path", "pending", "dialog_visible", "confirmation_required"]:
		if value.has(key):
			compact[key] = value[key]
	return compact


func _offset_tile(tile: Dictionary, delta: Vector2i) -> Dictionary:
	return {"x": int(tile.get("x", 0)) + delta.x, "y": int(tile.get("y", 0)) + delta.y}


func _tile_payload(tile: Vector2i) -> Dictionary:
	return {"x": tile.x, "y": tile.y}


func _canonical(value: Variant) -> String:
	return JSON.stringify(value)


func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}


func _capture_file_states(paths: Array) -> Dictionary:
	var states := {}
	for path_value in paths:
		var path := String(path_value)
		states[path] = _file_state(path)
	return states


func _restore_file_states(states: Dictionary) -> void:
	for path_value in states.keys():
		var path := String(path_value)
		var state: Dictionary = states[path]
		if not bool(state.get("exists", false)):
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(state.get("bytes", PackedByteArray()))
			file.close()


func _clear_save_files() -> void:
	for path in [AUTOSAVE_PATH, _manual_slot_path(MANUAL_SLOT)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _manual_slot_path(slot: int) -> String:
	return "%s/%s%d.json" % [SaveService.SAVE_DIR, SaveService.SAVE_PREFIX, slot]


func _authority_paths() -> Array:
	var paths: Array = [
		AUTOSAVE_PATH,
		"%s/%s" % [SaveService.SAVE_DIR, SaveService.PROGRESSION_FILE],
		SettingsService.SETTINGS_FILE,
		SettingsService.SETTINGS_CANDIDATE_FILE,
		SettingsService.SETTINGS_BACKUP_FILE,
	]
	for durable_path in [AUTOSAVE_PATH, "%s/%s" % [SaveService.SAVE_DIR, SaveService.PROGRESSION_FILE]]:
		var durable_artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(durable_path)
		paths.append(String(durable_artifacts.get("candidate", "%s.candidate" % durable_path)))
		paths.append(String(durable_artifacts.get("backup", "%s.backup" % durable_path)))
	for slot in SaveService.MANUAL_SLOT_IDS:
		var slot_path := _manual_slot_path(int(slot))
		paths.append(slot_path)
		var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(slot_path)
		paths.append(String(artifacts.get("candidate", "%s.candidate" % slot_path)))
		paths.append(String(artifacts.get("backup", "%s.backup" % slot_path)))
	return paths


func _cleanup() -> void:
	_restore_file_states(_original_files)
	SaveService._slot_summary_cache = _original_summary_cache.duplicate(true)
	SessionState.active_session = _original_session
	if _original_window_size != Vector2i.ZERO:
		get_window().size = _original_window_size


func _discard_shell(shell: Node) -> void:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
	await get_tree().process_frame


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _fail(message: String, payload: Variant = {}) -> bool:
	_cleanup()
	push_error("%s failed: %s %s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
	return false
