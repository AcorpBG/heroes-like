extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const MODES := [
	{"id": "normal", "reduced_motion": false},
	{"id": "reduced_motion", "reduced_motion": true},
]
const PLACEMENT_ID := "riverwatch_hold"
const SPECIALTY_ID := "spellwright"
const ACTION_ID := "choose_specialty:spellwright"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var original_reduced_motion := SettingsService.reduced_motion_enabled()
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		for mode_value in MODES:
			var mode: Dictionary = mode_value
			var settings_result: Dictionary = SettingsService.set_reduced_motion_enabled(bool(mode.get("reduced_motion", false)))
			if not bool(settings_result.get("ok", false)):
				_fail("Could not set focused motion preference.", {"mode": mode}, original_window_size, original_reduced_motion)
				return
			var row := await _run_case(viewport_size, mode)
			rows.append(row)
			if not bool(row.get("ok", false)):
				_fail("Town specialty selection feedback row failed.", {"row": row}, original_window_size, original_reduced_motion)
				return
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	await get_tree().process_frame
	print("TOWN_SPECIALTY_SELECTION_FEEDBACK_REPORT %s" % JSON.stringify({
		"ok": true,
		"viewports": [[1280, 720], [1920, 1080]],
		"normal_rows": 2,
		"reduced_motion_rows": 2,
		"public_specialty_rows": 4,
		"save_version": SessionDataScript.SAVE_VERSION,
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
	OverworldRules.normalize_overworld_state(session)
	var town := _town(session, PLACEMENT_ID)
	if town.is_empty():
		return {"ok": false, "failure": "player_town_missing"}
	_move_active_hero_to_town(session, town)
	_seed_specialty_choice(session)
	SessionState.set_active_session(session)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var live_session = SessionState.ensure_active_session()
	var stage = shell.get_node_or_null("%TownStage")
	if stage == null:
		return await _finish_case(shell, {"ok": false, "failure": "town_stage_missing"})
	var empty_snapshot: Dictionary = stage.validation_town_action_presentation_snapshot()
	var malformed_snapshot: Dictionary = stage.present_town_action({"event_id": "town_specialty_selected"})
	var malformed_fail_closed := malformed_snapshot == empty_snapshot and PresentationAudio.validation_records().is_empty()
	var action := _enabled_specialty_action(live_session, ACTION_ID)
	if action.is_empty():
		return await _finish_case(shell, {"ok": false, "failure": "specialty_action_missing", "actions": TownRules.get_specialty_actions(live_session)})

	var control = SessionDataScript.SessionData.new()
	control.from_dict(live_session.to_dict().duplicate(true))
	var before_live: Dictionary = live_session.to_dict()
	var before_hero := HeroProgressionRules.ensure_hero_progression(live_session.overworld.get("hero", {}).duplicate(true))
	var control_action := _enabled_specialty_action(control, ACTION_ID)
	var control_before := TownRules.town_action_consequence_signature(control)
	var control_result: Dictionary = TownRules.choose_specialty_at_active_town(control, SPECIALTY_ID)
	var control_recap: Dictionary = TownRules.build_town_action_recap(control, "order", ACTION_ID, control_action, control_result, control_before)
	if bool(control_recap.get("active", false)):
		control.flags["last_town_action_recap"] = control_recap.duplicate(true)
	var public_result: Dictionary = shell.validation_perform_town_action(ACTION_ID)
	await get_tree().process_frame
	await get_tree().process_frame
	var snapshot: Dictionary = stage.validation_town_action_presentation_snapshot()
	var after_hero := HeroProgressionRules.ensure_hero_progression(live_session.overworld.get("hero", {}).duplicate(true))
	var authority_exact := bool(control_result.get("ok", false)) and bool(public_result.get("ok", false)) and live_session.to_dict() == control.to_dict()
	var transition_exact := (
		String(after_hero.get("id", "")) == String(before_hero.get("id", ""))
		and HeroProgressionRules.specialty_rank(after_hero, SPECIALTY_ID) == HeroProgressionRules.specialty_rank(before_hero, SPECIALTY_ID) + 1
		and HeroProgressionRules.pending_choices_remaining(after_hero) == HeroProgressionRules.pending_choices_remaining(before_hero) - 1
		and String(live_session.overworld.get("active_hero_id", "")) == String(after_hero.get("id", ""))
	)
	var presentation_exact := _presentation_exact(snapshot, mode, town, after_hero, control_recap)
	var audio_records: Array = PresentationAudio.validation_records()
	var audio_exact := _audio_exact(audio_records, town)

	var serial := int(snapshot.get("serial", 0))
	var authority_before_refresh: Dictionary = live_session.to_dict()
	shell.validation_force_refresh()
	await get_tree().process_frame
	var refresh_silent := int(stage.validation_town_action_presentation_snapshot().get("serial", 0)) == serial and live_session.to_dict() == authority_before_refresh and PresentationAudio.validation_records() == audio_records
	var stale_before: Dictionary = live_session.to_dict()
	var stale_result: Dictionary = shell.validation_perform_town_action(ACTION_ID)
	await get_tree().process_frame
	var stale_silent := not bool(stale_result.get("ok", true)) and live_session.to_dict() == stale_before and int(stage.validation_town_action_presentation_snapshot().get("serial", 0)) == serial and PresentationAudio.validation_records() == audio_records
	var invalid_result: Dictionary = shell.validation_perform_town_action("choose_specialty:not_a_specialty")
	await get_tree().process_frame
	var invalid_silent := not bool(invalid_result.get("ok", true)) and int(stage.validation_town_action_presentation_snapshot().get("serial", 0)) == serial and PresentationAudio.validation_records() == audio_records
	var row := {
		"ok": malformed_fail_closed and authority_exact and transition_exact and presentation_exact and audio_exact and refresh_silent and stale_silent and invalid_silent and SessionDataScript.SAVE_VERSION == 9,
		"viewport": [viewport_size.x, viewport_size.y],
		"mode": String(mode.get("id", "")),
		"malformed_fail_closed": malformed_fail_closed,
		"authority_exact": authority_exact,
		"transition_exact": transition_exact,
		"presentation_exact": presentation_exact,
		"audio_exact": audio_exact,
		"refresh_silent": refresh_silent,
		"stale_silent": stale_silent,
		"invalid_silent": invalid_silent,
	}
	if not bool(row.get("ok", false)):
		row["snapshot"] = snapshot
		row["audio_records"] = audio_records
		row["public_result"] = public_result
		row["stale_result"] = stale_result
		row["session_differences"] = _recursive_exact_differences(control.to_dict(), live_session.to_dict())
		row["before_live"] = before_live
	return await _finish_case(shell, row)

func _presentation_exact(snapshot: Dictionary, mode: Dictionary, town: Dictionary, hero: Dictionary, recap: Dictionary) -> bool:
	var reduced_motion := bool(mode.get("reduced_motion", false))
	var draw: Dictionary = snapshot.get("vfx_draw", {}) if snapshot.get("vfx_draw", {}) is Dictionary else {}
	var asset: Dictionary = snapshot.get("vfx_asset", {}) if snapshot.get("vfx_asset", {}) is Dictionary else {}
	return (
		bool(snapshot.get("active", false))
		and int(snapshot.get("serial", 0)) == 1
		and String(snapshot.get("event_id", "")) == "town_specialty_selected"
		and String(snapshot.get("cue_id", "")) == "cue_town_specialty_selected"
		and String(snapshot.get("town_placement_id", "")) == String(town.get("placement_id", ""))
		and String(snapshot.get("hero_id", "")) == String(hero.get("id", ""))
		and String(snapshot.get("hero_name", "")) == String(hero.get("name", ""))
		and String(snapshot.get("specialty_id", "")) == SPECIALTY_ID
		and String(snapshot.get("specialty_name", "")) == String(HeroProgressionRules.specialty_definition(SPECIALTY_ID).get("name", ""))
		and int(snapshot.get("specialty_rank", 0)) == 1
		and int(snapshot.get("pending_specialty_choice_count", -1)) == 0
		and Dictionary(snapshot.get("town_action_recap", {})) == recap
		and String(snapshot.get("selected_mode", "")) == ("reduced_motion" if reduced_motion else "normal")
		and String(snapshot.get("selected_animation_state", "")) == ("specialty_rank_badge" if reduced_motion else "specialty_adopted")
		and String(snapshot.get("selected_playback_policy", "")) == "queue_resolved"
		and String(snapshot.get("selected_blocking_policy", "")) == "nonblocking"
		and Array(snapshot.get("selected_vfx_cue_ids", [])) == (["specialty_rank_badge"] if reduced_motion else ["vfx_placeholder_button_confirm"])
		and Array(snapshot.get("selected_audio_cue_ids", [])) == ["audio_placeholder_ui_confirm"]
		and Array(snapshot.get("draw_entries", [])) == (["specialty_rank_badge"] if reduced_motion else ["specialty_rank_sigil", "specialty_rank_badge"])
		and not bool(snapshot.get("blocks_input", true))
		and bool(snapshot.get("draw_rect_contained", false))
		and String(draw.get("mode", "")) == ("specialty_rank_badge" if reduced_motion else "procedural_specialty_rank")
		and int(draw.get("ray_count", -1)) == (0 if reduced_motion else 8)
		and String(asset.get("cue_id", "")) == ("specialty_rank_badge" if reduced_motion else "vfx_placeholder_button_confirm")
		and bool(asset.get("uses_procedural_fallback", false))
	)

func _audio_exact(records: Array, town: Dictionary) -> bool:
	if records.size() != 1 or not (records[0] is Dictionary):
		return false
	var record: Dictionary = records[0]
	var metadata: Dictionary = record.get("metadata", {}) if record.get("metadata", {}) is Dictionary else {}
	return (
		String(record.get("cue_id", "")) == "audio_placeholder_ui_confirm"
		and String(record.get("source", "")) == "TownStageView.present_town_action"
		and String(metadata.get("event_id", "")) == "town_specialty_selected"
		and int(metadata.get("presentation_serial", 0)) == 1
		and String(metadata.get("town_placement_id", "")) == String(town.get("placement_id", ""))
		and bool(record.get("played", false))
		and String(record.get("playback_source", "")) == "imported_wav"
		and String(record.get("asset_path", "")) == "res://art/audio/runtime/ui/confirm.wav"
		and String(record.get("role", "")) == "confirm_action"
		and int(record.get("duration_msec", 0)) == 120
		and int(record.get("stream_mix_rate", 0)) == 44100
		and bool(record.get("stream_stereo", false))
		and int(record.get("stream_loop_mode", -1)) == AudioStreamWAV.LOOP_DISABLED
	)

func _seed_specialty_choice(session) -> void:
	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	hero["level"] = 2
	hero["specialties"] = []
	hero["pending_specialty_choices"] = [{"level": 2, "options": [SPECIALTY_ID, "wayfinder", "drillmaster"]}]
	hero = HeroProgressionRules.ensure_hero_progression(hero)
	session.overworld["hero"] = hero.duplicate(true)
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(hero.get("id", "")):
			heroes[index] = hero.duplicate(true)
	session.overworld["player_heroes"] = heroes

func _enabled_specialty_action(session, action_id: String) -> Dictionary:
	for action_value in TownRules.get_specialty_actions(session):
		if action_value is Dictionary and String(action_value.get("id", "")) == action_id and not bool(action_value.get("disabled", false)):
			return action_value.duplicate(true)
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			heroes[index] = hero.duplicate(true)
	session.overworld["player_heroes"] = heroes
	var visit_result: Dictionary = OverworldRules.set_active_town_visit(session, PLACEMENT_ID)
	if not bool(visit_result.get("ok", false)):
		push_error("Could not activate Town specialty fixture: %s" % JSON.stringify(visit_result))

func _town(session, placement_id: String) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("placement_id", "")) == placement_id:
			return town_value
	return {}

func _finish_case(shell: Node, result: Dictionary) -> Dictionary:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame
	PresentationAudio.validation_reset()
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
	elif expected is Array:
		if expected.size() != actual.size():
			differences.append({"path": path, "expected_size": expected.size(), "actual_size": actual.size()})
		for index in range(mini(expected.size(), actual.size())):
			differences.append_array(_recursive_exact_differences(expected[index], actual[index], "%s[%d]" % [path, index]))
	elif expected != actual:
		differences.append({"path": path, "expected": expected, "actual": actual})
	return differences

func _fail(message: String, payload: Dictionary, original_window_size: Vector2i, original_reduced_motion: bool) -> void:
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	push_error("TOWN_SPECIALTY_SELECTION_FEEDBACK_REPORT failed: %s payload=%s" % [message, JSON.stringify(payload)])
	get_tree().quit(1)
