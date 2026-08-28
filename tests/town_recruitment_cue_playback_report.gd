extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const MODES := [
	{"id": "normal", "reduced_motion": false},
	{"id": "reduced_motion", "reduced_motion": true},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var original_reduced_motion := SettingsService.reduced_motion_enabled()
	var rows := []
	for viewport_size in VIEWPORT_SIZES:
		for mode in MODES:
			var settings_result: Dictionary = SettingsService.set_reduced_motion_enabled(bool(mode.get("reduced_motion", false)))
			if not bool(settings_result.get("ok", false)):
				SettingsService.set_reduced_motion_enabled(original_reduced_motion)
				get_window().size = original_window_size
				push_error("Town recruitment cue could not set the focused motion preference: %s" % settings_result)
				get_tree().quit(1)
				return
			var row: Dictionary = await _run_case(viewport_size, mode)
			rows.append(row)
			if not bool(row.get("ok", false)):
				SettingsService.set_reduced_motion_enabled(original_reduced_motion)
				get_window().size = original_window_size
				push_error("Town recruitment cue failed at %s/%s: %s" % [viewport_size, mode.get("id", ""), JSON.stringify(row)])
				get_tree().quit(1)
				return
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	await get_tree().process_frame
	print("TOWN_RECRUITMENT_CUE_PLAYBACK_REPORT %s" % JSON.stringify({
		"ok": true,
		"viewport_sizes": VIEWPORT_SIZES,
		"modes": ["normal", "reduced_motion"],
		"rows": rows,
	}))
	get_tree().quit(0)

func _run_case(viewport_size: Vector2i, mode: Dictionary) -> Dictionary:
	PresentationAudio.validation_reset()
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}

	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var active_town := _first_player_town(session)
	if active_town.is_empty():
		return {"ok": false, "failure": "player_town_missing"}
	_move_active_hero_to_town(session, active_town)
	SessionState.set_active_session(session)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var live_session = SessionState.ensure_active_session()
	var live_town: Dictionary = TownRules.get_active_town(live_session)

	var stage = shell.get_node_or_null("%TownStage")
	var management_tabs := shell.get_node_or_null("%ManagementTabs") as TabContainer
	var recruit_actions = shell.get_node_or_null("%RecruitActions")
	if stage == null or management_tabs == null or recruit_actions == null or not stage.has_method("validation_town_action_presentation_snapshot"):
		shell.queue_free()
		await get_tree().process_frame
		return {"ok": false, "failure": "live_surface_missing"}
	management_tabs.current_tab = 1
	await get_tree().process_frame
	await get_tree().process_frame
	shell.call("validation_open_town_catalog", "muster")
	await get_tree().process_frame
	await get_tree().process_frame
	var initial_presentation: Dictionary = stage.validation_town_action_presentation_snapshot()
	var malformed_result: Dictionary = stage.present_town_action({"event_id": "town_units_recruited"})
	var malformed_fail_closed := not bool(malformed_result.get("active", true)) and int(malformed_result.get("serial", -1)) == 0 and PresentationAudio.validation_records().is_empty()

	var actions: Array = TownRules.get_recruit_actions(live_session)
	var selected_index := -1
	var selected_action := {}
	for index in range(actions.size()):
		var action = actions[index]
		if action is Dictionary and not bool(action.get("disabled", true)) and int(action.get("direct_affordable_count", 0)) > 0:
			selected_index = index
			selected_action = action.duplicate(true)
			break
	if selected_index < 0:
		shell.queue_free()
		await get_tree().process_frame
		return {"ok": false, "failure": "enabled_recruit_action_missing", "actions": actions}
	var recruit_button := _catalog_button(recruit_actions, String(selected_action.get("id", "")))
	if recruit_button == null or recruit_button.disabled:
		shell.queue_free()
		await get_tree().process_frame
		return {"ok": false, "failure": "enabled_recruit_button_missing"}

	var unit_id := String(selected_action.get("id", "")).trim_prefix("recruit:")
	var live_before: Dictionary = live_session.to_dict()
	var control = SessionStateStoreScript.SessionData.new()
	control.from_dict(live_before.duplicate(true))
	var control_before := TownRules.town_action_consequence_signature(control)
	var control_result: Dictionary = TownRules.recruit_active_town(control, unit_id)
	var control_recap := TownRules.build_town_action_recap(
		control,
		"recruit",
		"recruit:%s" % unit_id,
		selected_action,
		control_result,
		control_before
	)
	if bool(control_recap.get("active", false)):
		control.flags["last_town_action_recap"] = control_recap.duplicate(true)

	recruit_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	var active_presentation: Dictionary = stage.validation_town_action_presentation_snapshot()
	var audio_records: Array = PresentationAudio.validation_records()
	var live_after: Dictionary = live_session.to_dict()
	var layout_after_action := _stage_layout_snapshot(shell)
	var expected_count := (
		int(Dictionary(TownRules.town_action_consequence_signature(control).get("army_counts", {})).get(unit_id, 0))
		- int(Dictionary(control_before.get("army_counts", {})).get(unit_id, 0))
	)
	var reduced_motion := bool(mode.get("reduced_motion", false))
	var expected_animation_state := "recruit_count_badge" if reduced_motion else "recruit_confirmed"
	var expected_vfx := ["recruit_count_badge"] if reduced_motion else ["vfx_placeholder_recruit_muster"]
	var expected_draw_entries := ["recruit_count_badge"] if reduced_motion else ["recruit_muster_rings", "recruit_count_badge"]
	var audio_record: Dictionary = audio_records[0] if audio_records.size() == 1 and audio_records[0] is Dictionary else {}
	var audio_exact := (
		audio_records.size() == 1
		and Array(active_presentation.get("audio_playback_records", [])) == audio_records
		and String(audio_record.get("cue_id", "")) == "audio_placeholder_recruit"
		and String(audio_record.get("source", "")) == "TownStageView.present_town_action"
		and String(Dictionary(audio_record.get("metadata", {})).get("event_id", "")) == "town_units_recruited"
		and int(Dictionary(audio_record.get("metadata", {})).get("presentation_serial", 0)) == 1
		and String(Dictionary(audio_record.get("metadata", {})).get("town_placement_id", "")) == String(live_town.get("placement_id", ""))
		and bool(audio_record.get("played", false))
		and String(audio_record.get("playback_source", "")) == "imported_wav"
		and String(audio_record.get("asset_path", "")) == "res://art/audio/runtime/presentation/town_recruit.wav"
		and String(audio_record.get("role", "")) == "town_recruitment_muster"
		and int(audio_record.get("duration_msec", 0)) == 360
		and int(audio_record.get("stream_mix_rate", 0)) == 44100
		and bool(audio_record.get("stream_stereo", false))
		and int(audio_record.get("stream_loop_mode", -1)) == AudioStreamWAV.LOOP_DISABLED
		and int(audio_record.get("imported_asset_count", 0)) == 1
		and int(audio_record.get("generated_fallback_count", -1)) == 0
	)
	var presentation_exact := (
		bool(control_result.get("ok", false))
		and live_after == control.to_dict()
		and bool(active_presentation.get("active", false))
		and int(active_presentation.get("serial", 0)) == 1
		and String(active_presentation.get("event_id", "")) == "town_units_recruited"
		and String(active_presentation.get("cue_id", "")) == "cue_town_units_recruited"
		and String(active_presentation.get("town_placement_id", "")) == String(live_town.get("placement_id", ""))
		and String(active_presentation.get("unit_id", "")) == unit_id
		and int(active_presentation.get("recruited_count", 0)) == expected_count
		and expected_count > 0
		and String(active_presentation.get("result_message", "")) == String(control_result.get("message", ""))
		and String(active_presentation.get("selected_mode", "")) == String(mode.get("id", ""))
		and String(active_presentation.get("selected_animation_state", "")) == expected_animation_state
		and String(active_presentation.get("selected_fallback_tag", "")) == ("recruit_count_badge" if reduced_motion else "")
		and Array(active_presentation.get("selected_vfx_cue_ids", [])) == expected_vfx
		and Array(active_presentation.get("selected_audio_cue_ids", [])) == ["audio_placeholder_recruit"]
		and String(active_presentation.get("selected_playback_policy", "")) == "queue_resolved"
		and String(active_presentation.get("selected_blocking_policy", "")) == "nonblocking"
		and bool(active_presentation.get("allows_large_motion", true)) == not reduced_motion
		and bool(active_presentation.get("reduced_motion", false)) == reduced_motion
		and int(active_presentation.get("duration_ms", 0)) == (260 if reduced_motion else 700)
		and bool(active_presentation.get("process_active", false))
		and bool(active_presentation.get("draw_rect_contained", false))
		and Array(active_presentation.get("draw_entries", [])) == expected_draw_entries
		and _stage_layout_valid(shell)
		and audio_exact
	)

	var active_serial := int(active_presentation.get("serial", 0))
	shell.validation_force_refresh()
	shell.validation_force_minimal_refresh()
	await get_tree().process_frame
	var refreshed_presentation: Dictionary = stage.validation_town_action_presentation_snapshot()
	var refresh_cue_state_exact := (
		(
			bool(refreshed_presentation.get("active", false))
			and String(refreshed_presentation.get("event_id", "")) == "town_units_recruited"
			and String(refreshed_presentation.get("unit_id", "")) == unit_id
			and int(refreshed_presentation.get("started_msec", 0)) == int(active_presentation.get("started_msec", -1))
			and int(refreshed_presentation.get("expires_msec", 0)) == int(active_presentation.get("expires_msec", -1))
		)
		or (
			not bool(refreshed_presentation.get("active", true))
			and Time.get_ticks_msec() >= int(active_presentation.get("expires_msec", Time.get_ticks_msec() + 1))
			and not bool(refreshed_presentation.get("process_active", true))
		)
	)
	var refresh_stable := (
		int(refreshed_presentation.get("serial", 0)) == active_serial
		and refresh_cue_state_exact
		and live_after == live_session.to_dict()
		and _stage_layout_snapshot(shell) == layout_after_action
		and PresentationAudio.validation_records() == audio_records
	)

	var expiry_deadline := Time.get_ticks_msec() + 1600
	while bool(stage.validation_town_action_presentation_snapshot().get("active", false)) and Time.get_ticks_msec() < expiry_deadline:
		await get_tree().process_frame
	var expired_presentation: Dictionary = stage.validation_town_action_presentation_snapshot()
	shell.validation_force_refresh()
	await get_tree().process_frame
	var post_expiry_presentation: Dictionary = stage.validation_town_action_presentation_snapshot()
	var expiry_exact := (
		not bool(expired_presentation.get("active", true))
		and int(expired_presentation.get("serial", 0)) == active_serial
		and not bool(post_expiry_presentation.get("active", true))
		and int(post_expiry_presentation.get("serial", 0)) == active_serial
		and live_after == live_session.to_dict()
		and _stage_layout_snapshot(shell) == layout_after_action
		and PresentationAudio.validation_records() == audio_records
	)

	var row := {
		"ok": malformed_fail_closed and presentation_exact and refresh_stable and expiry_exact,
		"viewport_size": viewport_size,
		"mode": String(mode.get("id", "")),
		"malformed_fail_closed": malformed_fail_closed,
		"presentation_exact": presentation_exact,
		"audio_exact": audio_exact,
		"audio_record": audio_record,
		"refresh_stable": refresh_stable,
		"expiry_exact": expiry_exact,
		"unit_id": unit_id,
		"recruited_count": expected_count,
		"serial": active_serial,
		"draw_entries": active_presentation.get("draw_entries", []),
		"session_matches_independent_control": live_after == control.to_dict(),
	}
	if not bool(row.get("ok", false)):
		row["session_differences"] = _recursive_exact_differences(control.to_dict(), live_after)
		row["active_presentation"] = active_presentation
		row["refreshed_presentation"] = refreshed_presentation
		row["expired_presentation"] = expired_presentation
		row["post_expiry_presentation"] = post_expiry_presentation
		row["refresh_cue_state_exact"] = refresh_cue_state_exact
		row["layout_after_action"] = _stage_layout_snapshot(shell)
	shell.queue_free()
	await get_tree().process_frame
	PresentationAudio.validation_reset()
	return row

func _catalog_button(node: Node, action_id: String) -> Button:
	if node is Button and String(node.get_meta("catalog_entry_id", "")) == action_id:
		return node
	for child in node.get_children():
		var match := _catalog_button(child, action_id)
		if match != null:
			return match
	return null

func _stage_layout_snapshot(shell: Node) -> Dictionary:
	var snapshot := {}
	for node_name in ["TownStagePanel", "TownStage"]:
		var control := shell.get_node_or_null("%%%s" % node_name) as Control
		snapshot[node_name] = control.get_global_rect() if control != null else Rect2()
	return snapshot

func _stage_layout_valid(shell: Node) -> bool:
	var stage_panel := shell.get_node_or_null("%TownStagePanel") as Control
	var stage := shell.get_node_or_null("%TownStage") as Control
	return (
		stage_panel != null
		and stage != null
		and stage_panel.get_global_rect().has_area()
		and stage.get_global_rect().has_area()
		and stage_panel.get_global_rect().encloses(stage.get_global_rect())
	)

func _recursive_exact_differences(expected: Variant, actual: Variant, path: String = "$") -> Array:
	var differences := []
	if typeof(expected) != typeof(actual):
		return [{"path": path, "expected_type": typeof(expected), "actual_type": typeof(actual)}]
	if expected is Dictionary:
		var keys := []
		for key in expected.keys():
			if key not in keys:
				keys.append(key)
		for key in actual.keys():
			if key not in keys:
				keys.append(key)
		keys.sort_custom(func(left, right): return String(left) < String(right))
		for key in keys:
			if not expected.has(key) or not actual.has(key):
				differences.append({"path": "%s[%s]" % [path, JSON.stringify(key)], "expected_present": expected.has(key), "actual_present": actual.has(key)})
			else:
				differences.append_array(_recursive_exact_differences(expected.get(key), actual.get(key), "%s[%s]" % [path, JSON.stringify(key)]))
		return differences
	if expected is Array:
		if expected.size() != actual.size():
			differences.append({"path": path, "expected_size": expected.size(), "actual_size": actual.size()})
		for index in range(min(expected.size(), actual.size())):
			differences.append_array(_recursive_exact_differences(expected[index], actual[index], "%s[%d]" % [path, index]))
		return differences
	if expected != actual:
		differences.append({"path": path, "expected": expected, "actual": actual})
	return differences

func _first_player_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return town
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes
