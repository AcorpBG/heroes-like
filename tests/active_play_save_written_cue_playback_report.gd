extends Node

const REPORT_ID := "ACTIVE_PLAY_SAVE_WRITTEN_CUE_PLAYBACK_REPORT"
const SLOT := 1

var _original_file_states: Dictionary = {}
var _original_active_session = null
var _original_settings: Dictionary = {}
var _original_window_size := Vector2i.ZERO


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_file_states = _capture_file_states(_tracked_paths())
	_original_active_session = SessionState.active_session
	_original_settings = SettingsService.ensure_settings().duplicate(true)
	_original_window_size = get_window().size
	var routes := [
		{"id": "overworld", "scene": "res://scenes/overworld/OverworldShell.tscn", "status": "SaveStatus"},
		{"id": "town", "scene": "res://scenes/town/TownShell.tscn", "status": "SaveStatus"},
		{"id": "battle", "scene": "res://scenes/battle/BattleShell.tscn", "status": "SystemBody"},
		{"id": "scenario_outcome", "scene": "res://scenes/results/ScenarioOutcomeShell.tscn", "status": "SaveStatus"},
	]
	var rows := []
	for route_value in routes:
		var route: Dictionary = route_value
		for mode in [
			{"width": 1280, "reduced_motion": false},
			{"width": 1280, "reduced_motion": true},
			{"width": 1920, "reduced_motion": false},
			{"width": 1920, "reduced_motion": true},
		]:
			var row := await _exercise_route(route, int(mode.get("width", 0)), bool(mode.get("reduced_motion", false)))
			if row.is_empty():
				_restore_original_state()
				return
			rows.append(row)
	_restore_original_state()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"surface_count": routes.size(),
		"case_count": rows.size(),
		"viewports": [[1280, 720], [1920, 1080]],
		"normal_state": "save_confirm",
		"reduced_motion_state": "save_icon_static",
		"blocking_policy": "never_blocks_input",
		"overwrite_cancel_publishes_nothing": true,
		"overwrite_confirm_publishes_once": true,
		"save_authority_exact": true,
		"refresh_stable": true,
		"focus_nonblocking": true,
		"layout_unchanged_by_presenter": true,
		"expiry_restores_visuals": true,
		"rows": rows,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)


func _exercise_route(route: Dictionary, width: int, reduced_motion: bool) -> Dictionary:
	var route_id := String(route.get("id", ""))
	var old_session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	old_session.day = 2
	if SaveService.save_manual_session(old_session.to_dict(), SLOT) == "":
		return _fail_row("Could not seed occupied Manual Slot 1 for %s." % route_id)
	SaveService.validation_clear_summary_cache()
	var occupied_before := _file_state(_manual_slot_path(SLOT))
	var session = _session_for_route(route_id, 20 + width / 100 + (1 if reduced_motion else 0))
	if session == null:
		return _fail_row("Could not create %s save cue fixture." % route_id)
	SessionState.set_active_session(session)
	SaveService.set_selected_manual_slot(SLOT)
	SettingsService.settings = _original_settings.duplicate(true)
	SettingsService.settings["accessibility"]["reduce_motion"] = reduced_motion
	get_window().size = Vector2i(width, 720 if width == 1280 else 1080)
	await _settle()
	var host := Control.new()
	host.name = "SaveWrittenCueHost_%s_%d" % [route_id, width]
	host.size = Vector2(float(width), 720.0 if width == 1280 else 1080.0)
	add_child(host)
	var shell = load(String(route.get("scene", ""))).instantiate()
	host.add_child(shell)
	await _settle()
	var presenter: Node = shell.get_node_or_null("SystemSaveWrittenCuePresenter")
	var save_button: Button = shell.get_node("%Save")
	var status_control: Control = shell.get_node("%%%s" % String(route.get("status", "")))
	if presenter == null:
		return _fail_shell(host, "Missing shared save-written presenter on %s." % route_id)
	var button_rect_before_cue := save_button.get_global_rect()
	var status_rect_before_cue := status_control.get_global_rect()
	var session_before: Dictionary = session.to_dict()
	var settings_before: Dictionary = SettingsService.settings.duplicate(true)
	var initial_cue: Dictionary = shell.call("validation_save_written_cue_snapshot")
	var request: Dictionary = shell.call("validation_request_manual_save")
	await _settle()
	var pending_cue: Dictionary = shell.call("validation_save_written_cue_snapshot")
	if (
		not bool(request.get("visible", false))
		or int(request.get("pending_slot", 0)) != SLOT
		or bool(pending_cue.get("active", true))
		or int(pending_cue.get("activation_count", -1)) != 0
		or _file_state(_manual_slot_path(SLOT)) != occupied_before
	):
		return _fail_shell(host, "%s confirmation-pending save cue did not fail closed: request=%s cue=%s." % [route_id, JSON.stringify(request), JSON.stringify(pending_cue)])
	shell.call("validation_cancel_manual_save_overwrite")
	await _settle()
	var canceled_cue: Dictionary = shell.call("validation_save_written_cue_snapshot")
	if int(canceled_cue.get("activation_count", -1)) != 0 or _file_state(_manual_slot_path(SLOT)) != occupied_before:
		return _fail_shell(host, "%s canceled overwrite published or changed bytes." % route_id)
	request = shell.call("validation_request_manual_save")
	await _settle()
	if not bool(request.get("visible", false)) or int(request.get("pending_slot", 0)) != SLOT:
		return _fail_shell(host, "%s could not reopen exact overwrite confirmation." % route_id)
	var confirm_result: Dictionary = shell.call("validation_confirm_manual_save_overwrite")
	var cue: Dictionary = shell.call("validation_save_written_cue_snapshot")
	var summary: Dictionary = SaveService.inspect_manual_slot(SLOT)
	var policy: Dictionary = cue.get("policy", {}) if cue.get("policy", {}) is Dictionary else {}
	var vfx: Dictionary = cue.get("vfx_asset", {}) if cue.get("vfx_asset", {}) is Dictionary else {}
	var expected_state := "save_icon_static" if reduced_motion else "save_confirm"
	var expected_size := Vector2i(width, 720 if width == 1280 else 1080)
	var checks := {
		"initial_configured": bool(initial_cue.get("configured", false)),
		"confirm_slot": int(confirm_result.get("pending_slot", 0)) == SLOT,
		"summary_loadable": SaveService.can_load_summary(summary),
		"summary_day_exact": int(summary.get("day", -1)) == session.day,
		"summary_slot_exact": String(summary.get("slot_type", "")) == SaveService.SLOT_TYPE_MANUAL and String(summary.get("slot_id", "")) == str(SLOT),
		"cue_active": bool(cue.get("active", false)),
		"cue_once": int(cue.get("activation_count", 0)) == 1,
		"cue_surface": String(cue.get("surface", "")) == route_id,
		"cue_event": String(cue.get("event_id", "")) == "system_save_written" and String(cue.get("cue_id", "")) == "cue_system_save_written",
		"cue_slot": int(cue.get("manual_slot", 0)) == SLOT,
		"cue_path": String(cue.get("path", "")) == String(summary.get("path", "")),
		"cue_policy": String(policy.get("selected_animation_state", "")) == expected_state and String(policy.get("selected_playback_policy", "")) == "instant" and String(policy.get("selected_blocking_policy", "")) == "never_blocks_input",
		"copy_unchanged": bool(cue.get("button_text_unchanged", false)) and bool(cue.get("status_text_unchanged", false)) and bool(cue.get("status_tooltip_unchanged", false)),
		"button_highlighted": cue.get("button_modulate") != cue.get("button_base_modulate"),
		"status_highlighted": cue.get("status_modulate") != cue.get("status_base_modulate"),
		"vfx_exact": _vfx_exact(vfx, save_button, not reduced_motion, "system_save_written", "vfx_placeholder_save_confirm", "res://art/ui/runtime/system_feedback/save_confirm.png"),
		"layout_exact": save_button.get_global_rect() == button_rect_before_cue and status_control.get_global_rect() == status_rect_before_cue,
		"session_exact": session.to_dict() == session_before,
		"settings_exact": SettingsService.settings == settings_before,
		"selection_exact": SaveService.get_selected_manual_slot() == SLOT,
		"window_requested": get_window().size == expected_size,
		"host_exact": host.size == Vector2(expected_size),
		"save_version": SessionState.SAVE_VERSION == 9,
	}
	if not _checks_exact(checks):
		return _fail_shell(host, "%s %d reduced=%s save cue authority failed: checks=%s cue=%s summary=%s." % [route_id, width, reduced_motion, JSON.stringify(checks), JSON.stringify(cue), JSON.stringify(summary)])
	var button_rect_after_save := save_button.get_global_rect()
	var status_rect_after_save := status_control.get_global_rect()
	shell.call("_refresh")
	var refreshed_cue: Dictionary = shell.call("validation_save_written_cue_snapshot")
	var refresh_checks := {
		"still_active": bool(refreshed_cue.get("active", false)),
		"no_replay": int(refreshed_cue.get("activation_count", 0)) == 1,
		"button_rect": save_button.get_global_rect() == button_rect_after_save,
		"status_rect": status_control.get_global_rect() == status_rect_after_save,
		"session_exact": session.to_dict() == session_before,
	}
	if not _checks_exact(refresh_checks):
		return _fail_shell(host, "%s refresh changed or replayed save cue: %s." % [route_id, JSON.stringify(refresh_checks)])
	save_button.grab_focus()
	if save_button.get_viewport().gui_get_focus_owner() != save_button:
		return _fail_shell(host, "%s cue blocked save-button focus." % route_id)
	await get_tree().process_frame
	var invalid_result: Dictionary = presenter.call("present", {"ok": false, "path": "", "summary": {}}, SLOT)
	if not invalid_result.is_empty() or int(shell.call("validation_save_written_cue_snapshot").get("activation_count", 0)) != 1:
		return _fail_shell(host, "%s malformed failure published a save cue." % route_id)
	await get_tree().create_timer(0.8).timeout
	await get_tree().process_frame
	var expired: Dictionary = shell.call("validation_save_written_cue_snapshot")
	var expiry_checks := {
		"inactive": not bool(expired.get("active", true)),
		"count_stable": int(expired.get("activation_count", 0)) == 1,
		"button_restored": expired.get("button_modulate") == expired.get("button_base_modulate"),
		"status_restored": expired.get("status_modulate") == expired.get("status_base_modulate"),
		"vfx_cleared": not bool((expired.get("vfx_asset", {}) as Dictionary).get("icon_visible", true)),
		"session_exact": session.to_dict() == session_before,
	}
	if not _checks_exact(expiry_checks):
		return _fail_shell(host, "%s save cue did not expire cleanly: %s snapshot=%s." % [route_id, JSON.stringify(expiry_checks), JSON.stringify(expired)])
	var row := {
		"surface": route_id,
		"viewport": [width, expected_size.y],
		"reduced_motion": reduced_motion,
		"state": expected_state,
		"activation_count": 1,
		"day": session.day,
		"summary_signature": String(summary.get("integrity_signature", summary.get("session_signature", ""))),
	}
	host.queue_free()
	await _settle()
	return row


func _vfx_exact(vfx: Dictionary, host: Control, expects_imported: bool, event_id: String, cue_id: String, texture_path: String) -> bool:
	var icon_rect: Rect2 = vfx.get("icon_global_rect", Rect2())
	var host_rect := host.get_global_rect()
	if expects_imported:
		return (
			bool(vfx.get("configured", false))
			and bool(vfx.get("imported", false))
			and bool(vfx.get("icon_visible", false))
			and String(vfx.get("event_id", "")) == event_id
			and String(vfx.get("cue_id", "")) == cue_id
			and String(vfx.get("texture_path", "")) == texture_path
			and String(vfx.get("render_mode", "")) == "system_feedback_icon"
			and vfx.get("texture_size", {}) == {"x": 512, "y": 512}
			and bool(vfx.get("mouse_filter_ignore", false))
			and bool(vfx.get("focus_none", false))
			and host_rect.grow(0.5).encloses(icon_rect)
		)
	return bool(vfx.get("configured", false)) and not bool(vfx.get("imported", false)) and not bool(vfx.get("icon_visible", true)) and String(vfx.get("fallback", "")) == "reduced_motion_text_tint_only"


func _session_for_route(route_id: String, day: int):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.day = day
	match route_id:
		"town":
			var town := _first_player_town(session)
			if town.is_empty():
				return null
			_move_active_hero_to_town(session, town)
			session.game_state = "town"
		"battle":
			var encounter := _first_encounter(session)
			if encounter.is_empty():
				return null
			session.battle = BattleRules.create_battle_payload(session, encounter)
			session.game_state = "battle"
		"scenario_outcome":
			session.scenario_status = "victory"
			session.scenario_summary = "Save-written cue outcome fixture."
			session.game_state = "outcome"
	return session


func _first_player_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return town
	return {}


func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["position"] = position.duplicate(true)
		session.overworld["hero"] = hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var candidate = heroes[index]
		if candidate is Dictionary and String(candidate.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			candidate["position"] = position.duplicate(true)
			heroes[index] = candidate
	session.overworld["player_heroes"] = heroes


func _first_encounter(session) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary:
			return encounter
	return {}


func _checks_exact(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _tracked_paths() -> Array:
	return [
		_manual_slot_path(1),
		_manual_slot_path(2),
		_manual_slot_path(3),
		"%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE],
		String(SettingsService.SETTINGS_FILE),
		"%s/%s" % [SaveService.SAVE_DIR, SaveService.PROGRESSION_FILE],
	]


func _manual_slot_path(slot: int) -> String:
	return "%s/%s%d.json" % [SaveService.SAVE_DIR, SaveService.SAVE_PREFIX, slot]


func _capture_file_states(paths: Array) -> Dictionary:
	var states := {}
	for path_value in paths:
		var path := String(path_value)
		states[path] = _file_state(path)
	return states


func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}


func _restore_original_state() -> void:
	for path_value in _original_file_states.keys():
		var path := String(path_value)
		var state: Dictionary = _original_file_states.get(path, {})
		if bool(state.get("exists", false)):
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(state.get("bytes", PackedByteArray()))
				file.close()
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SessionState.active_session = _original_active_session
	SettingsService.settings = _original_settings.duplicate(true)
	get_window().size = _original_window_size


func _fail_shell(host: Node, message: String) -> Dictionary:
	if host != null:
		host.queue_free()
	return _fail_row(message)


func _fail_row(message: String) -> Dictionary:
	push_error(message)
	_restore_original_state()
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
	return {}
