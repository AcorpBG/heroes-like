extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "OVERWORLD_ARTIFACT_SLOT_CUE_PLAYBACK_REPORT"
const ARTIFACT_ID := "artifact_trailsinger_boots"
const ARTIFACT_SLOT := "boots"
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
				_fail("Could not set the focused motion preference: %s" % settings_result, original_window_size, original_reduced_motion)
				return
			var row: Dictionary = await _run_case(viewport_size, mode)
			rows.append(row)
			if not bool(row.get("ok", false)):
				_fail("Artifact-slot cue failed at %s/%s: %s" % [viewport_size, mode.get("id", ""), JSON.stringify(row)], original_window_size, original_reduced_motion)
				return
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	await get_tree().process_frame
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "rows": rows})])
	get_tree().quit(0)

func _fail(message: String, original_window_size: Vector2i, original_reduced_motion: bool) -> void:
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	push_error(message)
	get_tree().quit(1)

func _run_case(viewport_size: Vector2i, mode: Dictionary) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}

	var authored_session = _artifact_session()
	var active_session = SessionState.set_active_session(authored_session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var live_session = shell.get("_session")
	if live_session == null:
		live_session = active_session
	var artifact_actions := shell.get_node_or_null("%ArtifactActions") as Container
	var artifact_cue := shell.get_node_or_null("%ArtifactActionCue") as Label
	var spell_blocker := shell.get_node_or_null("%SpellCastInputBlocker") as Control
	if artifact_actions == null or artifact_cue == null or spell_blocker == null:
		return await _finish_case(shell, {"ok": false, "failure": "live_surface_missing"})

	var malformed_before := _artifact_presentation(shell)
	var malformed_after: Dictionary = shell.present_artifact_slot_presentation({
		"serial": 991,
		"event_id": "artifact_equipped",
		"cue_id": "cue_artifact_equipped",
		"artifact_id": ARTIFACT_ID,
	})
	var malformed_fail_closed: bool = malformed_after == malformed_before and not artifact_cue.visible and not spell_blocker.visible

	var live_before: Dictionary = live_session.to_dict()
	var control = SessionDataScript.SessionData.new()
	control.from_dict(live_before.duplicate(true))
	var equip_action_id := "equip_artifact:%s" % ARTIFACT_ID
	var equip_control_result: Dictionary = OverworldRules.perform_artifact_action(control, equip_action_id)
	var equip_button := _enabled_artifact_button(artifact_actions, live_session, equip_action_id)
	if equip_button == null:
		return await _finish_case(shell, {"ok": false, "failure": "equip_button_missing"})
	equip_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	var equip_presentation := _artifact_presentation(shell)
	var equip_live_after: Dictionary = live_session.to_dict()
	var equip_exact := _presentation_exact(
		equip_presentation,
		"artifact_equipped",
		"cue_artifact_equipped",
		equip_action_id,
		String(equip_control_result.get("message", "")),
		mode,
		1
	) and bool(equip_control_result.get("ok", false)) and equip_live_after == control.to_dict()

	var stow_action_id := "unequip_artifact:%s" % ARTIFACT_SLOT
	var stow_control_result: Dictionary = OverworldRules.perform_artifact_action(control, stow_action_id)
	var stow_button := _enabled_artifact_button(artifact_actions, live_session, stow_action_id)
	if stow_button == null:
		return await _finish_case(shell, {"ok": false, "failure": "stow_button_missing", "equip_presentation": equip_presentation})
	var equip_was_still_active := bool(equip_presentation.get("active", false))
	stow_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	var stow_presentation := _artifact_presentation(shell)
	var live_after: Dictionary = live_session.to_dict()
	var stow_exact := _presentation_exact(
		stow_presentation,
		"artifact_unequipped",
		"cue_artifact_unequipped",
		stow_action_id,
		String(stow_control_result.get("message", "")),
		mode,
		2
	) and bool(stow_control_result.get("ok", false)) and live_after == control.to_dict()
	var nonblocking_exact: bool = equip_was_still_active and stow_exact and not spell_blocker.visible

	var serial := int(stow_presentation.get("serial", 0))
	var progress_before_refresh := float(stow_presentation.get("progress", 0.0))
	shell.call("_refresh")
	await get_tree().process_frame
	var refreshed := _artifact_presentation(shell)
	var refresh_exact: bool = (
		int(refreshed.get("serial", 0)) == serial
		and String(refreshed.get("event_id", "")) == "artifact_unequipped"
		and float(refreshed.get("progress", -1.0)) >= progress_before_refresh
		and live_session.to_dict() == live_after
		and not spell_blocker.visible
	)

	var settle_frames := 0
	while bool(_artifact_presentation(shell).get("active", false)) and settle_frames < 90:
		await get_tree().process_frame
		settle_frames += 1
	var settled := _artifact_presentation(shell)
	var completion_exact: bool = (
		not bool(settled.get("active", true))
		and int(settled.get("serial", 0)) == serial
		and not bool(settled.get("visible", true))
		and not artifact_cue.visible
		and live_session.to_dict() == live_after
	)

	var failed_authority_before: Dictionary = live_session.to_dict()
	var failed_result: Dictionary = shell.validation_perform_artifact_action("equip_artifact:artifact_missing")
	await get_tree().process_frame
	var failed_presentation := _artifact_presentation(shell)
	var failed_published_nothing: bool = (
		not bool(failed_result.get("ok", true))
		and int(failed_presentation.get("serial", 0)) == serial
		and not bool(failed_presentation.get("active", true))
		and live_session.to_dict() == failed_authority_before
	)

	var row := {
		"ok": malformed_fail_closed and equip_exact and stow_exact and nonblocking_exact and refresh_exact and completion_exact and failed_published_nothing,
		"viewport_size": viewport_size,
		"mode": String(mode.get("id", "")),
		"malformed_fail_closed": malformed_fail_closed,
		"equip_exact": equip_exact,
		"stow_exact": stow_exact,
		"nonblocking_exact": nonblocking_exact,
		"refresh_exact": refresh_exact,
		"completion_exact": completion_exact,
		"failed_published_nothing": failed_published_nothing,
		"session_matches_independent_control": live_after == control.to_dict(),
		"settle_frames": settle_frames,
	}
	if not bool(row.get("ok", false)):
		row["equip_presentation"] = equip_presentation
		row["stow_presentation"] = stow_presentation
		row["refreshed"] = refreshed
		row["settled"] = settled
		row["failed_result"] = failed_result
		row["failed_presentation"] = failed_presentation
		row["session_differences"] = _recursive_exact_differences(control.to_dict(), live_after)
	return await _finish_case(shell, row)

func _artifact_session():
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["artifacts"] = ArtifactRules.normalize_hero_artifacts({"equipped": {}, "inventory": [ARTIFACT_ID]})
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var player_heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(player_heroes.size()):
		if player_heroes[index] is Dictionary and String(player_heroes[index].get("id", "")) == active_hero_id:
			player_heroes[index] = hero.duplicate(true)
			break
	session.overworld["player_heroes"] = player_heroes
	return session

func _enabled_artifact_button(container: Container, session, action_id: String) -> Button:
	var expected_label := ""
	for action_value in OverworldRules.get_artifact_actions(session):
		if action_value is Dictionary and String(action_value.get("id", "")) == action_id:
			if bool(action_value.get("disabled", false)):
				return null
			expected_label = String(action_value.get("label", ""))
			break
	for child in container.get_children():
		if child is Button and not child.disabled and child.text == expected_label:
			return child
	return null

func _artifact_presentation(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.validation_snapshot()
	return snapshot.get("artifact_slot_presentation", {}).duplicate(true) if snapshot.get("artifact_slot_presentation", {}) is Dictionary else {}

func _presentation_exact(presentation: Dictionary, event_id: String, cue_id: String, action_id: String, result_message: String, mode: Dictionary, serial: int) -> bool:
	var reduced_motion := bool(mode.get("reduced_motion", false))
	var equip := event_id == "artifact_equipped"
	var expected_state := ("slot_badge_added" if equip else "slot_badge_removed") if reduced_motion else ("slot_equip_pulse" if equip else "slot_unequip_pulse")
	var expected_visual := "reduced_motion_fallback" if reduced_motion else "authored_animation_state"
	var expected_fallback := ("slot_badge_added" if equip else "slot_badge_removed") if reduced_motion else ""
	var expected_vfx := [expected_fallback] if reduced_motion else (["vfx_placeholder_slot_equip"] if equip else ["vfx_placeholder_slot_unequip"])
	var expected_audio := ["audio_placeholder_artifact_equip"] if equip else ["audio_placeholder_artifact_stow"]
	var expected_verb := "Equipped" if equip else "Stowed"
	return (
		bool(presentation.get("active", false))
		and bool(presentation.get("visible", false))
		and int(presentation.get("serial", 0)) == serial
		and String(presentation.get("event_id", "")) == event_id
		and String(presentation.get("cue_id", "")) == cue_id
		and String(presentation.get("action_id", "")) == action_id
		and String(presentation.get("artifact_id", "")) == ARTIFACT_ID
		and String(presentation.get("artifact_name", "")) == "Trailsinger Boots"
		and String(presentation.get("slot", "")) == ARTIFACT_SLOT
		and String(presentation.get("result_message", "")) == result_message
		and String(presentation.get("selected_animation_state", "")) == expected_state
		and String(presentation.get("selected_visual_policy", "")) == expected_visual
		and String(presentation.get("selected_fallback_tag", "")) == expected_fallback
		and String(presentation.get("selected_playback_policy", "")) == "queue_resolved"
		and String(presentation.get("selected_blocking_policy", "")) == "nonblocking"
		and Array(presentation.get("selected_vfx_cue_ids", [])) == expected_vfx
		and Array(presentation.get("selected_audio_cue_ids", [])) == expected_audio
		and bool(presentation.get("allows_large_motion", true)) == not reduced_motion
		and int(presentation.get("duration_ms", 0)) == (260 if reduced_motion else 520)
		and float(presentation.get("progress", -1.0)) >= 0.0
		and float(presentation.get("progress", -1.0)) < 1.0
		and String(presentation.get("text", "")) == "%s: Trailsinger Boots • Boots" % expected_verb
		and String(presentation.get("tooltip_text", "")) == result_message
	)

func _finish_case(shell: Node, result: Dictionary) -> Dictionary:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame
	return result

func _recursive_exact_differences(expected: Variant, actual: Variant, path: String = "$") -> Array:
	var differences := []
	if typeof(expected) != typeof(actual):
		return [{"path": path, "expected_type": typeof(expected), "actual_type": typeof(actual)}]
	if expected is Dictionary:
		var keys: Array = expected.keys()
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
