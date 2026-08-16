extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const MODES := [
	{"id": "normal", "reduced_motion": false, "missing_asset": false},
	{"id": "missing_asset", "reduced_motion": false, "missing_asset": true},
	{"id": "reduced_motion", "reduced_motion": true, "missing_asset": false},
]
const TEXTURE_PATH := "res://art/town/runtime/vfx/spell_study.png"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var original_reduced_motion := SettingsService.reduced_motion_enabled()
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		for mode_value in MODES:
			var mode: Dictionary = mode_value
			var settings_result := SettingsService.set_reduced_motion_enabled(bool(mode.get("reduced_motion", false)))
			if not bool(settings_result.get("ok", false)):
				_fail("Could not set focused motion preference.", {"mode": mode, "settings_result": settings_result}, original_window_size, original_reduced_motion)
				return
			var row: Dictionary = await _run_case(viewport_size, mode)
			rows.append(row)
			if not bool(row.get("ok", false)):
				_fail("Town spell-study completion feedback row failed.", {"row": row}, original_window_size, original_reduced_motion)
				return
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	await get_tree().process_frame
	print("TOWN_SPELL_STUDY_COMPLETION_FEEDBACK_REPORT %s" % JSON.stringify({
		"ok": true,
		"viewports": [[1280, 720], [1920, 1080]],
		"normal_imported_rows": 2,
		"missing_asset_fallback_rows": 2,
		"reduced_motion_rows": 2,
		"public_handler_rows": 6,
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

	var authored_session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(authored_session)
	var authored_town := _first_player_town(authored_session)
	if authored_town.is_empty():
		return {"ok": false, "failure": "player_town_missing"}
	_seed_study_fixture(authored_session, authored_town)
	SessionState.set_active_session(authored_session)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var live_session = SessionState.ensure_active_session()
	var live_town: Dictionary = TownRules.get_active_town(live_session)
	var stage = shell.get_node_or_null("%TownStage")
	var blocker := shell.get_node_or_null("%TownActionInputBlocker") as Control
	if stage == null or blocker == null:
		return await _finish_case(shell, {"ok": false, "failure": "live_surface_missing"})
	var malformed_before: Dictionary = stage.validation_town_action_presentation_snapshot()
	var malformed_after: Dictionary = stage.present_town_action({"event_id": "town_spell_studied"})
	var malformed_fail_closed: bool = malformed_after == malformed_before and not blocker.visible and PresentationAudio.validation_records().is_empty()

	var selected_action := _enabled_study_action(live_session)
	if selected_action.is_empty():
		return await _finish_case(shell, {"ok": false, "failure": "enabled_study_action_missing", "actions": TownRules.get_spell_learning_actions(live_session)})
	var action_id := String(selected_action.get("id", ""))
	var spell_id := SpellRules.spell_id_for_action(action_id)
	var spell := ContentService.get_spell(spell_id)
	if spell_id == "" or spell.is_empty():
		return await _finish_case(shell, {"ok": false, "failure": "spell_contract_missing", "action": selected_action})
	if bool(mode.get("missing_asset", false)):
		stage.set("_town_vfx_texture_missing", {TEXTURE_PATH: true})

	var live_before: Dictionary = live_session.to_dict()
	var before_hero := _active_hero_snapshot(live_before)
	var before_spellbook: Dictionary = before_hero.get("spellbook", {}) if before_hero.get("spellbook", {}) is Dictionary else {}
	var before_known: Array = before_spellbook.get("known_spell_ids", []) if before_spellbook.get("known_spell_ids", []) is Array else []
	var before_mana: Dictionary = before_spellbook.get("mana", {}) if before_spellbook.get("mana", {}) is Dictionary else {}
	var control = SessionDataScript.SessionData.new()
	control.from_dict(live_before.duplicate(true))
	var control_before := TownRules.town_action_consequence_signature(control)
	var control_result: Dictionary = TownRules.learn_spell_at_active_town(control, spell_id)
	var control_recap := TownRules.build_town_action_recap(control, "order", action_id, selected_action, control_result, control_before)
	if bool(control_recap.get("active", false)):
		control.flags["last_town_action_recap"] = control_recap.duplicate(true)

	var public_result: Dictionary = shell.validation_perform_town_action(action_id)
	await get_tree().process_frame
	await get_tree().process_frame
	var active: Dictionary = stage.validation_town_action_presentation_snapshot()
	var live_after: Dictionary = live_session.to_dict()
	var after_hero := _active_hero_snapshot(live_after)
	var after_spellbook: Dictionary = after_hero.get("spellbook", {}) if after_hero.get("spellbook", {}) is Dictionary else {}
	var after_known: Array = after_spellbook.get("known_spell_ids", []) if after_spellbook.get("known_spell_ids", []) is Array else []
	var after_mana: Dictionary = after_spellbook.get("mana", {}) if after_spellbook.get("mana", {}) is Dictionary else {}
	var mirrored_hero := _player_hero_snapshot(live_after, String(after_hero.get("id", "")))
	var audio_records: Array = PresentationAudio.validation_records()

	var spellbook_exact: bool = (
		spell_id not in before_known
		and spell_id in after_known
		and after_known.size() == before_known.size() + 1
		and after_mana == before_mana
		and mirrored_hero == after_hero
	)
	var reduced_motion := bool(mode.get("reduced_motion", false))
	var missing_asset := bool(mode.get("missing_asset", false))
	var expected_vfx := ["archive_inscribed_badge"] if reduced_motion else ["vfx_placeholder_town_spell_study"]
	var expected_draw_entries := ["archive_inscribed_badge"] if reduced_motion else ["spell_study_art", "archive_inscribed_badge"]
	var expected_draw_mode := "archive_inscribed_badge" if reduced_motion else ("procedural_spell_study" if missing_asset else "imported_texture")
	var asset: Dictionary = active.get("vfx_asset", {}) if active.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = active.get("vfx_draw", {}) if active.get("vfx_draw", {}) is Dictionary else {}
	var audio_record: Dictionary = audio_records[0] if audio_records.size() == 1 and audio_records[0] is Dictionary else {}
	var audio_exact: bool = (
		audio_records.size() == 1
		and Array(active.get("audio_playback_records", [])) == audio_records
		and String(audio_record.get("cue_id", "")) == "audio_placeholder_town_spell_study"
		and String(audio_record.get("source", "")) == "TownStageView.present_town_action"
		and String(Dictionary(audio_record.get("metadata", {})).get("event_id", "")) == "town_spell_studied"
		and int(Dictionary(audio_record.get("metadata", {})).get("presentation_serial", 0)) == 1
		and String(Dictionary(audio_record.get("metadata", {})).get("town_placement_id", "")) == String(live_town.get("placement_id", ""))
		and bool(audio_record.get("played", false))
		and String(audio_record.get("playback_source", "")) == "imported_wav"
		and String(audio_record.get("asset_path", "")) == "res://art/audio/runtime/presentation/town_spell_study.wav"
		and String(audio_record.get("role", "")) == "town_spell_studied"
		and int(audio_record.get("duration_msec", 0)) == 400
		and int(audio_record.get("stream_mix_rate", 0)) == 44100
		and bool(audio_record.get("stream_stereo", false))
		and int(audio_record.get("stream_loop_mode", -1)) == AudioStreamWAV.LOOP_DISABLED
	)
	var consequence_exact: bool = (
		bool(control_result.get("ok", false))
		and bool(public_result.get("ok", false))
		and String(public_result.get("lane", "")) == "study"
		and String(public_result.get("action_id", "")) == action_id
		and String(Dictionary(public_result.get("town_action_recap", {})).get("kind", "")) == "order"
		and live_after == control.to_dict()
		and spellbook_exact
	)
	var presentation_exact: bool = (
		bool(active.get("active", false))
		and int(active.get("serial", 0)) == 1
		and String(active.get("event_id", "")) == "town_spell_studied"
		and String(active.get("cue_id", "")) == "cue_town_spell_studied"
		and String(active.get("town_placement_id", "")) == String(live_town.get("placement_id", ""))
		and String(active.get("spell_id", "")) == spell_id
		and String(active.get("spell_name", "")) == String(spell.get("name", ""))
		and String(active.get("spell_school_id", "")) == String(spell.get("school_id", ""))
		and String(active.get("spell_context", "")) == String(spell.get("context", ""))
		and int(active.get("spell_tier", 0)) == int(spell.get("tier", 0))
		and int(active.get("known_spell_count", 0)) == after_known.size()
		and String(active.get("result_message", "")) == String(control_result.get("message", ""))
		and String(active.get("selected_mode", "")) == ("reduced_motion" if reduced_motion else "normal")
		and String(active.get("selected_animation_state", "")) == ("archive_inscribed_badge" if reduced_motion else "archive_inscribed")
		and String(active.get("selected_blocking_policy", "")) == "nonblocking"
		and Array(active.get("selected_vfx_cue_ids", [])) == expected_vfx
		and Array(active.get("selected_audio_cue_ids", [])) == ["audio_placeholder_town_spell_study"]
		and Array(active.get("draw_entries", [])) == expected_draw_entries
		and not bool(active.get("blocks_input", true))
		and not blocker.visible
		and bool(active.get("draw_rect_contained", false))
		and String(draw.get("mode", "")) == expected_draw_mode
		and bool(asset.get("uses_imported_asset", false)) == (not reduced_motion and not missing_asset)
		and bool(asset.get("uses_procedural_fallback", false)) == (reduced_motion or missing_asset)
		and audio_exact
	)

	var serial := int(active.get("serial", 0))
	var authority_before_refresh: Dictionary = live_session.to_dict()
	var refresh_result: Dictionary = shell.validation_force_refresh()
	await get_tree().process_frame
	var after_refresh: Dictionary = stage.validation_town_action_presentation_snapshot()
	var refresh_silent: bool = not refresh_result.is_empty() and int(after_refresh.get("serial", 0)) == serial and live_session.to_dict() == authority_before_refresh and PresentationAudio.validation_records() == audio_records
	var authority_before_invalid: Dictionary = live_session.to_dict()
	var invalid_result: Dictionary = shell.validation_perform_town_action(action_id)
	await get_tree().process_frame
	var after_invalid: Dictionary = stage.validation_town_action_presentation_snapshot()
	var invalid_silent: bool = not bool(invalid_result.get("ok", true)) and int(after_invalid.get("serial", 0)) == serial and live_session.to_dict() == authority_before_invalid and PresentationAudio.validation_records() == audio_records
	var row := {
		"ok": malformed_fail_closed and consequence_exact and presentation_exact and refresh_silent and invalid_silent and SessionDataScript.SAVE_VERSION == 9,
		"viewport": [viewport_size.x, viewport_size.y],
		"mode": String(mode.get("id", "")),
		"action_id": action_id,
		"spell_id": spell_id,
		"known_spell_count": after_known.size(),
		"malformed_fail_closed": malformed_fail_closed,
		"spellbook_exact": spellbook_exact,
		"consequence_exact": consequence_exact,
		"presentation_exact": presentation_exact,
		"audio_exact": audio_exact,
		"refresh_silent": refresh_silent,
		"invalid_silent": invalid_silent,
	}
	if not bool(row.get("ok", false)):
		row["active"] = active
		row["asset"] = asset
		row["draw"] = draw
		row["audio_records"] = audio_records
		row["public_result"] = public_result
		row["control_result"] = control_result
		row["invalid_result"] = invalid_result
		row["refresh_result"] = refresh_result
		row["session_differences"] = _recursive_exact_differences(control.to_dict(), live_after)
	return await _finish_case(shell, row)

func _enabled_study_action(session) -> Dictionary:
	for action_value in TownRules.get_spell_learning_actions(session):
		if action_value is Dictionary and String(action_value.get("id", "")).begins_with("learn_spell:") and not bool(action_value.get("disabled", true)):
			return action_value.duplicate(true)
	return {}

func _first_player_town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}

func _seed_study_fixture(session, town: Dictionary) -> void:
	var buildings: Array = town.get("built_buildings", []).duplicate()
	if "building_lantern_archive" not in buildings:
		buildings.append("building_lantern_archive")
	town["built_buildings"] = buildings
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("placement_id", "")) == String(town.get("placement_id", "")):
			towns[index] = town
	session.overworld["towns"] = towns
	_move_active_hero_to_town(session, town)
	_set_active_hero_spellbook(session, [])

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

func _set_active_hero_spellbook(session, spell_ids: Array) -> void:
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero = SpellRules.ensure_hero_spellbook(hero)
	var spellbook: Dictionary = hero.get("spellbook", {}) if hero.get("spellbook", {}) is Dictionary else {}
	spellbook["known_spell_ids"] = spell_ids.duplicate()
	spellbook["mana"] = {"current": 40, "max": 40}
	hero["spellbook"] = spellbook
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_hero_id:
			heroes[index] = hero.duplicate(true)
	session.overworld["player_heroes"] = heroes

func _active_hero_snapshot(session_dict: Dictionary) -> Dictionary:
	var overworld: Dictionary = session_dict.get("overworld", {}) if session_dict.get("overworld", {}) is Dictionary else {}
	return Dictionary(overworld.get("hero", {})).duplicate(true) if overworld.get("hero", {}) is Dictionary else {}

func _player_hero_snapshot(session_dict: Dictionary, hero_id: String) -> Dictionary:
	var overworld: Dictionary = session_dict.get("overworld", {}) if session_dict.get("overworld", {}) is Dictionary else {}
	for hero_value in overworld.get("player_heroes", []):
		if hero_value is Dictionary and String(hero_value.get("id", "")) == hero_id:
			return hero_value.duplicate(true)
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
	push_error("TOWN_SPELL_STUDY_COMPLETION_FEEDBACK_REPORT failed: %s payload=%s" % [message, JSON.stringify(payload)])
	get_tree().quit(1)
