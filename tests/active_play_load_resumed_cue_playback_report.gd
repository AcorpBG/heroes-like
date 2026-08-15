extends Node

const REPORT_ID := "ACTIVE_PLAY_LOAD_RESUMED_CUE_PLAYBACK_REPORT"
const SLOT := 1
const MAIN_MENU_SCENE := "res://scenes/menus/MainMenu.tscn"

var _original_file_states: Dictionary = {}
var _original_active_session = null
var _original_settings: Dictionary = {}
var _original_window_size := Vector2i.ZERO


func _ready() -> void:
	call_deferred("_bootstrap")


func _bootstrap() -> void:
	_detach_for_scene_transitions()
	call_deferred("_run")


func _detach_for_scene_transitions() -> void:
	var tree := get_tree()
	if tree.current_scene != self:
		return
	var parent := get_parent()
	if parent != null:
		parent.remove_child(self)
	tree.root.add_child(self)
	var anchor := Node.new()
	anchor.name = "ActivePlayLoadResumedCueSceneAnchor"
	tree.root.add_child(anchor)
	tree.current_scene = anchor


func _run() -> void:
	_stage("run_start")
	_original_file_states = _capture_file_states(_tracked_paths())
	_original_active_session = SessionState.active_session
	_original_settings = SettingsService.ensure_settings().duplicate(true)
	_original_window_size = get_window().size
	var routes := [
		{"id": "overworld", "target": "overworld", "scene": "res://scenes/overworld/OverworldShell.tscn", "status": "SaveStatus"},
		{"id": "town", "target": "town", "scene": "res://scenes/town/TownShell.tscn", "status": "SaveStatus"},
		{"id": "battle", "target": "battle", "scene": "res://scenes/battle/BattleShell.tscn", "status": "SystemBody"},
		{"id": "scenario_outcome", "target": "outcome", "scene": "res://scenes/results/ScenarioOutcomeShell.tscn", "status": "SaveStatus"},
	]
	var rows := []
	for route_value in routes:
		var route: Dictionary = route_value
		for mode in [
			{"width": 1280, "height": 720, "reduced_motion": false},
			{"width": 1280, "height": 720, "reduced_motion": true},
			{"width": 1920, "height": 1080, "reduced_motion": false},
			{"width": 1920, "height": 1080, "reduced_motion": true},
		]:
			_stage("route_start_%s_%d" % [String(route.get("id", "")), int(mode.get("width", 0))])
			var row := await _exercise_route(route, mode)
			if row.is_empty():
				return
			rows.append(row)
			_stage("route_done_%s_%d" % [String(route.get("id", "")), int(mode.get("width", 0))])
	_stage("stale_start")
	if not await _exercise_stale_selected_save_failure():
		return
	_stage("stale_done")
	_restore_original_state()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"surface_count": routes.size(),
		"case_count": rows.size(),
		"viewports": [[1280, 720], [1920, 1080]],
		"normal_state": "load_resume",
		"reduced_motion_state": "load_icon_static",
		"blocking_policy": "never_blocks_input",
		"real_main_menu_selected_load": true,
		"cross_scene_handoff_once": true,
		"stale_selected_save_publishes_nothing": true,
		"save_bytes_unchanged": true,
		"refresh_stable": true,
		"focus_nonblocking": true,
		"layout_unchanged_by_presenter": true,
		"expiry_restores_visuals": true,
		"rows": rows,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)


func _stage(stage: String) -> void:
	print("ACTIVE_PLAY_LOAD_RESUMED_CUE_STAGE %s" % JSON.stringify({
		"stage": stage,
		"ticks_msec": Time.get_ticks_msec(),
	}))


func _exercise_route(route: Dictionary, mode: Dictionary) -> Dictionary:
	PresentationAudio.validation_reset()
	AppRouter.validation_clear_pending_load_resumed_presentation()
	var route_id := String(route.get("id", ""))
	var expected_target := String(route.get("target", ""))
	var width := int(mode.get("width", 0))
	var height := int(mode.get("height", 0))
	var reduced_motion := bool(mode.get("reduced_motion", false))
	var session = _session_for_route(route_id, 30 + width / 100 + (1 if reduced_motion else 0))
	if session == null:
		return _fail_row("Could not create %s load-resume fixture." % route_id)
	var save_path := SaveService.save_manual_session(session.to_dict(), SLOT)
	if save_path == "":
		return _fail_row("Could not seed Manual Slot 1 for %s." % route_id)
	SaveService.validation_clear_summary_cache()
	var summary: Dictionary = SaveService.inspect_manual_slot(SLOT)
	if not SaveService.can_load_summary(summary):
		return _fail_row("Seeded %s summary is not loadable: %s." % [route_id, JSON.stringify(summary)])
	var expected_continuity := SaveService.describe_slot_continuity_cue(summary)
	var save_state_before := _file_state(save_path)
	var summaries_before := _summary_authority()
	SettingsService.settings = _original_settings.duplicate(true)
	SettingsService.settings["accessibility"]["reduce_motion"] = reduced_motion
	var settings_before: Dictionary = SettingsService.settings.duplicate(true)
	SaveService.set_selected_manual_slot(SLOT)
	get_window().size = Vector2i(width, height)
	await _settle()
	SessionState.reset_session()
	var menu = await _install_scene(MAIN_MENU_SCENE)
	if menu == null or not menu.has_method("validation_select_save_summary") or not menu.has_method("validation_resume_selected_save"):
		return _fail_row("Main Menu validation route is unavailable for %s." % route_id)
	if not bool(menu.call("validation_select_save_summary", SaveService.SLOT_TYPE_MANUAL, str(SLOT))):
		return _fail_row("Main Menu could not select Manual Slot 1 for %s." % route_id)
	await _settle()
	var menu_snapshot: Dictionary = menu.call("validation_snapshot")
	var selected_summary: Dictionary = menu_snapshot.get("selected_save_summary", {}) if menu_snapshot.get("selected_save_summary", {}) is Dictionary else {}
	var action_result: Dictionary = menu.call("validation_resume_selected_save")
	await _settle()
	var shell = get_tree().current_scene
	var shell_path := String(shell.scene_file_path) if shell != null else ""
	if shell == null or shell_path != String(route.get("scene", "")) or not shell.has_method("validation_load_resumed_cue_snapshot"):
		return _fail_row("%s routed to %s instead of %s." % [route_id, shell_path, String(route.get("scene", ""))])
	var status_control: Control = shell.get_node("%%%s" % String(route.get("status", "")))
	var save_button: Button = shell.get_node("%Save")
	var presenter: Node = shell.get_node_or_null("SystemLoadResumedCuePresenter")
	var cue: Dictionary = shell.call("validation_load_resumed_cue_snapshot")
	var policy: Dictionary = cue.get("policy", {}) if cue.get("policy", {}) is Dictionary else {}
	var vfx: Dictionary = cue.get("vfx_asset", {}) if cue.get("vfx_asset", {}) is Dictionary else {}
	var audio: Dictionary = cue.get("audio_playback_record", {}) if cue.get("audio_playback_record", {}) is Dictionary else {}
	var identity: Dictionary = cue.get("summary_identity", {}) if cue.get("summary_identity", {}) is Dictionary else {}
	var expected_state := "load_icon_static" if reduced_motion else "load_resume"
	var active_session := SessionState.ensure_active_session()
	var session_after_route: Dictionary = active_session.to_dict()
	var status_rect := status_control.get_global_rect()
	var checks := {
		"action_ok": bool(action_result.get("ok", false)),
		"action_target": String(action_result.get("active_resume_target", "")) == expected_target,
		"action_game_state": String(action_result.get("active_game_state", "")) == session.game_state,
		"selected_summary_exact": String(selected_summary.get("path", "")) == save_path and String(selected_summary.get("resume_target", "")) == expected_target,
		"active_scenario": active_session.scenario_id == session.scenario_id,
		"active_day": active_session.day == session.day,
		"active_status": active_session.scenario_status == session.scenario_status,
		"active_target": SaveService.resume_target_for_session(active_session) == expected_target,
		"active_game_state": active_session.game_state == session.game_state,
		"presenter_exists": presenter != null,
		"cue_active": bool(cue.get("active", false)),
		"cue_once": int(cue.get("activation_count", 0)) == 1,
		"cue_surface": String(cue.get("surface", "")) == route_id,
		"cue_event": String(cue.get("event_id", "")) == "system_load_resumed" and String(cue.get("cue_id", "")) == "cue_system_load_resumed",
		"cue_sequence": int(cue.get("sequence", 0)) > 0,
		"cue_scenario": String(cue.get("scenario_id", "")) == session.scenario_id and int(cue.get("day", -1)) == session.day,
		"cue_target": String(cue.get("resume_target", "")) == expected_target,
		"cue_continuity": String(cue.get("continuity_cue", "")) == expected_continuity,
		"cue_identity": String(identity.get("slot_type", "")) == SaveService.SLOT_TYPE_MANUAL and String(identity.get("slot_id", "")) == str(SLOT) and String(identity.get("path", "")) == save_path,
		"cue_policy": String(policy.get("selected_animation_state", "")) == expected_state and String(policy.get("selected_playback_policy", "")) == "instant" and String(policy.get("selected_blocking_policy", "")) == "never_blocks_input",
		"copy_unchanged": bool(cue.get("status_text_unchanged", false)) and bool(cue.get("status_tooltip_unchanged", false)),
		"status_highlighted": cue.get("status_modulate") != cue.get("status_base_modulate"),
		"vfx_exact": _vfx_exact(vfx, save_button, not reduced_motion, "system_load_resumed", "vfx_placeholder_load_resume", "res://art/ui/runtime/system_feedback/load_resume.png"),
		"audio_exact": _audio_exact(audio, "audio_placeholder_load_resume", "res://art/audio/runtime/presentation/load_resume.wav", "SystemLoadResumedCuePresenter", "system_load_resumed") and PresentationAudio.validation_records().size() == 1,
		"pending_consumed": AppRouter.validation_pending_load_resumed_presentation().is_empty(),
		"save_bytes_exact": _file_state(save_path) == save_state_before,
		"summary_authority_exact": _summary_authority() == summaries_before,
		"settings_exact": SettingsService.settings == settings_before,
		"selection_exact": SaveService.get_selected_manual_slot() == SLOT,
		"window_exact": get_window().size == Vector2i(width, height),
		"save_version": SessionState.SAVE_VERSION == 9,
	}
	if not _checks_exact(checks):
		return _fail_row("%s %dx%d reduced=%s load cue authority failed: checks=%s cue=%s." % [route_id, width, height, reduced_motion, JSON.stringify(checks), JSON.stringify(cue)])
	shell.call("_refresh")
	var refreshed: Dictionary = shell.call("validation_load_resumed_cue_snapshot")
	var second_consume: Dictionary = AppRouter.consume_load_resumed_presentation(route_id)
	if (
		not second_consume.is_empty()
		or not bool(refreshed.get("active", false))
		or int(refreshed.get("activation_count", 0)) != 1
		or status_control.get_global_rect() != status_rect
		or active_session.to_dict() != session_after_route
		or PresentationAudio.validation_records().size() != 1
	):
		return _fail_row("%s refresh replayed or changed the load cue." % route_id)
	save_button.grab_focus()
	if save_button.get_viewport().gui_get_focus_owner() != save_button:
		return _fail_row("%s load cue blocked active-play focus." % route_id)
	if presenter != null:
		var malformed: Dictionary = presenter.call("present", {"event_id": "system_load_resumed"})
		if not malformed.is_empty() or int(shell.call("validation_load_resumed_cue_snapshot").get("activation_count", 0)) != 1 or PresentationAudio.validation_records().size() != 1:
			return _fail_row("%s malformed payload replayed the load cue." % route_id)
	await get_tree().create_timer(0.8).timeout
	await get_tree().process_frame
	var expired: Dictionary = shell.call("validation_load_resumed_cue_snapshot")
	if (
		bool(expired.get("active", true))
		or int(expired.get("activation_count", 0)) != 1
		or expired.get("status_modulate") != expired.get("status_base_modulate")
		or bool((expired.get("vfx_asset", {}) as Dictionary).get("icon_visible", true))
		or active_session.to_dict() != session_after_route
		or _file_state(save_path) != save_state_before
		or PresentationAudio.validation_records().size() != 1
	):
		return _fail_row("%s load cue did not expire cleanly: %s." % [route_id, JSON.stringify(expired)])
	return {
		"surface": route_id,
		"viewport": [width, height],
		"reduced_motion": reduced_motion,
		"state": expected_state,
		"activation_count": 1,
		"day": session.day,
		"resume_target": expected_target,
	}


func _audio_exact(audio: Dictionary, cue_id: String, asset_path: String, source: String, role: String) -> bool:
	return (
		bool(audio.get("played", false))
		and bool(audio.get("supported", false))
		and bool(audio.get("player_created", false))
		and String(audio.get("cue_id", "")) == cue_id
		and String(audio.get("asset_path", "")) == asset_path
		and String(audio.get("source", "")) == source
		and String(audio.get("role", "")) == role
		and String(audio.get("playback_source", "")) == "imported_wav"
		and int(audio.get("imported_asset_count", 0)) == 1
		and int(audio.get("generated_fallback_count", -1)) == 0
		and int(audio.get("stream_mix_rate", 0)) == 44100
		and bool(audio.get("stream_stereo", false))
		and int(audio.get("stream_loop_mode", -1)) == AudioStreamWAV.LOOP_DISABLED
	)


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


func _exercise_stale_selected_save_failure() -> bool:
	AppRouter.validation_clear_pending_load_resumed_presentation()
	var session = _session_for_route("overworld", 48)
	var save_path := SaveService.save_manual_session(session.to_dict(), SLOT)
	SaveService.validation_clear_summary_cache()
	var saved_state := _file_state(save_path)
	var menu = await _install_scene(MAIN_MENU_SCENE)
	if menu == null or not bool(menu.call("validation_select_save_summary", SaveService.SLOT_TYPE_MANUAL, str(SLOT))):
		return not _fail_row("Stale selected-save control could not select its fixture.").is_empty()
	var remove_result := DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	SaveService.validation_clear_summary_cache()
	var result: Dictionary = menu.call("validation_resume_selected_save")
	await _settle()
	var passed := (
		remove_result == OK
		and not bool(result.get("ok", true))
		and String(get_tree().current_scene.scene_file_path) == MAIN_MENU_SCENE
		and AppRouter.validation_pending_load_resumed_presentation().is_empty()
	)
	_restore_file_state(save_path, saved_state)
	SaveService.validation_clear_summary_cache()
	if not passed:
		_fail_row("A removed selected save routed or published a pending load cue: %s." % JSON.stringify(result))
	return passed


func _install_scene(path: String):
	var tree := get_tree()
	var current = tree.current_scene
	if current != null:
		tree.current_scene = null
		current.queue_free()
		await tree.process_frame
	var scene = load(path).instantiate()
	tree.root.add_child(scene)
	tree.current_scene = scene
	await _settle()
	return scene


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
			session.scenario_summary = "Load-resumed cue outcome fixture."
			session.game_state = "outcome"
		_:
			session.game_state = "overworld"
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


func _summary_authority() -> Array:
	var authority := []
	for summary_value in SaveService.list_session_summaries():
		var summary: Dictionary = summary_value if summary_value is Dictionary else {}
		authority.append({
			"slot_type": String(summary.get("slot_type", "")),
			"slot_id": String(summary.get("slot_id", "")),
			"path": String(summary.get("path", "")),
			"modified_timestamp": int(summary.get("modified_timestamp", 0)),
			"payload_bytes": int(summary.get("payload_bytes", 0)),
			"valid": bool(summary.get("valid", false)),
			"loadable": bool(summary.get("loadable", false)),
			"scenario_id": String(summary.get("scenario_id", "")),
			"day": int(summary.get("day", 0)),
			"scenario_status": String(summary.get("scenario_status", "")),
			"resume_target": String(summary.get("resume_target", "")),
		})
	return authority


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


func _restore_file_state(path: String, state: Dictionary) -> void:
	if bool(state.get("exists", false)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(state.get("bytes", PackedByteArray()))
			file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _restore_original_state() -> void:
	for path_value in _original_file_states.keys():
		var path := String(path_value)
		_restore_file_state(path, _original_file_states.get(path, {}))
	SaveService.validation_clear_summary_cache()
	AppRouter.validation_clear_pending_load_resumed_presentation()
	SessionState.active_session = _original_active_session
	SettingsService.settings = _original_settings.duplicate(true)
	get_window().size = _original_window_size


func _fail_row(message: String) -> Dictionary:
	push_error(message)
	_restore_original_state()
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
	return {}
