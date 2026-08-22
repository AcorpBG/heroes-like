extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const MODES := [
	{"id": "normal", "reduced_motion": false, "missing_asset": false},
	{"id": "missing_asset", "reduced_motion": false, "missing_asset": true},
	{"id": "reduced_motion", "reduced_motion": true, "missing_asset": false},
]
const TEXTURE_PATH := "res://art/town/runtime/vfx/hero_hire.png"

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
				_fail("Town hero-hire completion feedback row failed.", {"row": row}, original_window_size, original_reduced_motion)
				return
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	await get_tree().process_frame
	print("TOWN_HERO_HIRE_COMPLETION_FEEDBACK_REPORT %s" % JSON.stringify({
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
	UiAudio.validation_reset()
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
	_seed_tavern_fixture(authored_session, authored_town)
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
	var management_tabs := shell.get_node_or_null("%ManagementTabs") as TabContainer
	var tavern_actions := shell.get_node_or_null("%TavernActions") as Container
	if stage == null or blocker == null or management_tabs == null or tavern_actions == null:
		return await _finish_case(shell, {"ok": false, "failure": "live_surface_missing"})
	management_tabs.current_tab = 4
	await get_tree().process_frame
	await get_tree().process_frame
	if management_tabs.current_tab != 4:
		return await _finish_case(shell, {"ok": false, "failure": "logistics_tab_unavailable"})
	var malformed_before: Dictionary = stage.validation_town_action_presentation_snapshot()
	var malformed_after: Dictionary = stage.present_town_action({"event_id": "town_hero_hired"})
	var malformed_fail_closed: bool = malformed_after == malformed_before and not blocker.visible and PresentationAudio.validation_records().is_empty()

	var selected_action := _enabled_tavern_action(live_session)
	if selected_action.is_empty():
		return await _finish_case(shell, {"ok": false, "failure": "enabled_tavern_action_missing", "actions": TownRules.get_tavern_actions(live_session)})
	var action_id := String(selected_action.get("id", ""))
	var hero_id := action_id.trim_prefix("hire_hero:")
	var hero_template := ContentService.get_hero(hero_id)
	var recruit_cost := HeroCommandRules.hero_recruit_cost(hero_template)
	if hero_id == "" or hero_id == action_id or hero_template.is_empty() or recruit_cost.is_empty():
		return await _finish_case(shell, {"ok": false, "failure": "hero_contract_missing", "action": selected_action})
	var stale_button := _button_for_label(tavern_actions, String(selected_action.get("label", "")))
	if stale_button == null or stale_button.disabled:
		return await _finish_case(shell, {"ok": false, "failure": "enabled_tavern_button_missing", "action": selected_action})
	if bool(mode.get("missing_asset", false)):
		stage.set("_town_vfx_texture_missing", {TEXTURE_PATH: true})

	var fixture_resources: Dictionary = live_session.overworld.get("resources", {}).duplicate(true)
	var unavailable_resources := fixture_resources.duplicate(true)
	for resource_id_value in recruit_cost:
		unavailable_resources[String(resource_id_value)] = 0
	live_session.overworld["resources"] = unavailable_resources
	var stale_authority_before: Dictionary = live_session.to_dict()
	var stale_control = SessionDataScript.SessionData.new()
	stale_control.from_dict(stale_authority_before.duplicate(true))
	var stale_control_result: Dictionary = TownRules.hire_hero_at_active_town(stale_control, hero_id)
	var stale_presentation_before: Dictionary = stage.validation_town_action_presentation_snapshot()
	UiAudio.validation_reset()
	stale_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	var stale_audio_records: Array = UiAudio.validation_records()
	var stale_invalid_record: Dictionary = stale_audio_records[0] if stale_audio_records.size() == 2 and stale_audio_records[0] is Dictionary else {}
	var stale_click_record: Dictionary = stale_audio_records[1] if stale_audio_records.size() == 2 and stale_audio_records[1] is Dictionary else {}
	var stale_snapshot: Dictionary = shell.validation_snapshot()
	var stale_recap: Dictionary = stale_snapshot.get("town_action_recap", {}) if stale_snapshot.get("town_action_recap", {}) is Dictionary else {}
	var stale_presentation_after: Dictionary = stage.validation_town_action_presentation_snapshot()
	var stale_invalid_audio_exact: bool = (
		stale_audio_records.size() == 2
		and String(stale_invalid_record.get("cue_id", "")) == "ui_invalid"
		and String(stale_invalid_record.get("source", "")) == "TownShell._record_town_action_result"
		and bool(stale_invalid_record.get("played", false))
		and String(stale_invalid_record.get("playback_source", "")) == "imported_wav"
		and String(stale_invalid_record.get("asset_path", "")) == "res://art/audio/runtime/ui/invalid.wav"
		and String(stale_invalid_record.get("role", "")) == "invalid_action"
		and int(stale_invalid_record.get("duration_msec", 0)) == 150
		and int(stale_invalid_record.get("stream_mix_rate", 0)) == 44100
		and bool(stale_invalid_record.get("stream_stereo", false))
		and int(stale_invalid_record.get("stream_loop_mode", -1)) == AudioStreamWAV.LOOP_DISABLED
		and int(stale_invalid_record.get("imported_asset_count", 0)) == 1
		and int(stale_invalid_record.get("generated_fallback_count", -1)) == 0
		and Dictionary(stale_invalid_record.get("metadata", {})) == {
			"lane": "order",
			"action_id": action_id,
			"message": String(stale_control_result.get("message", "")),
		}
		and String(stale_click_record.get("cue_id", "")) == "ui_click"
		and bool(stale_click_record.get("played", false))
		and String(stale_click_record.get("playback_source", "")) == "imported_wav"
		and String(stale_click_record.get("asset_path", "")) == "res://art/audio/runtime/ui/click.wav"
		and String(stale_click_record.get("role", "")) == "button_click"
		and String(Dictionary(stale_click_record.get("metadata", {})).get("class", "")) == "Button"
		and not bool(Dictionary(stale_click_record.get("metadata", {})).get("disabled", true))
		and String(Dictionary(stale_click_record.get("metadata", {})).get("name", "")) != ""
		and String(stale_click_record.get("source", "")).contains("/TavernActions/")
		and String(stale_click_record.get("source", "")).ends_with("/%s" % String(Dictionary(stale_click_record.get("metadata", {})).get("name", "")))
	)
	var stale_failure_exact: bool = (
		not bool(stale_control_result.get("ok", true))
		and stale_control.to_dict() == stale_authority_before
		and live_session.to_dict() == stale_authority_before
		and stale_presentation_after == stale_presentation_before
		and PresentationAudio.validation_records().is_empty()
		and String(stale_snapshot.get("return_to_menu_visible_message", "")) == String(stale_control_result.get("message", ""))
		and not bool(stale_recap.get("active", true))
		and String(stale_recap.get("kind", "")) == "order"
		and String(stale_recap.get("action_id", "")) == action_id
		and String(stale_recap.get("message", "")) == String(stale_control_result.get("message", ""))
		and stale_invalid_audio_exact
	)
	var stale_failure_diagnostics := {
		"audio_record_count_exact": stale_audio_records.size() == 2,
		"invalid_metadata_exact": Dictionary(stale_invalid_record.get("metadata", {})) == {"lane": "order", "action_id": action_id, "message": String(stale_control_result.get("message", ""))},
		"click_metadata_exact": String(Dictionary(stale_click_record.get("metadata", {})).get("class", "")) == "Button" and not bool(Dictionary(stale_click_record.get("metadata", {})).get("disabled", true)) and String(Dictionary(stale_click_record.get("metadata", {})).get("name", "")) != "",
		"click_source_exact": String(stale_click_record.get("source", "")).contains("/TavernActions/") and String(stale_click_record.get("source", "")).ends_with("/%s" % String(Dictionary(stale_click_record.get("metadata", {})).get("name", ""))),
		"control_unchanged": stale_control.to_dict() == stale_authority_before,
		"session_unchanged": live_session.to_dict() == stale_authority_before,
		"session_differences": _recursive_exact_differences(stale_authority_before, live_session.to_dict()),
		"presentation_unchanged": stale_presentation_after == stale_presentation_before,
		"presentation_audio_empty": PresentationAudio.validation_records().is_empty(),
		"visible_message_exact": String(stale_snapshot.get("return_to_menu_visible_message", "")) == String(stale_control_result.get("message", "")),
		"recap_exact": not bool(stale_recap.get("active", true)) and String(stale_recap.get("kind", "")) == "order" and String(stale_recap.get("action_id", "")) == action_id and String(stale_recap.get("message", "")) == String(stale_control_result.get("message", "")),
	}
	var disabled_button := _button_for_label(shell.get_node_or_null("%TavernActions") as Container, String(selected_action.get("label", "")))
	var unavailable_before: Dictionary = live_session.to_dict()
	var unavailable_audio_before: Array = UiAudio.validation_records()
	var unavailable_result: Dictionary = shell.validation_perform_town_action(action_id)
	await get_tree().process_frame
	var unavailable_after: Dictionary = stage.validation_town_action_presentation_snapshot()
	var unavailable_silent: bool = (
		disabled_button != null
		and disabled_button.disabled
		and not bool(unavailable_result.get("ok", true))
		and unavailable_after == stale_presentation_after
		and live_session.to_dict() == unavailable_before
		and PresentationAudio.validation_records().is_empty()
		and UiAudio.validation_records() == unavailable_audio_before
	)
	live_session.overworld["resources"] = fixture_resources
	shell.validation_force_refresh()
	await get_tree().process_frame

	var live_before: Dictionary = live_session.to_dict()
	var before_hero_ids := _player_hero_ids(live_before)
	var before_active_hero := _active_hero_snapshot(live_before)
	var control = SessionDataScript.SessionData.new()
	control.from_dict(live_before.duplicate(true))
	var control_before := TownRules.town_action_consequence_signature(control)
	var control_result: Dictionary = TownRules.hire_hero_at_active_town(control, hero_id)
	var control_recap := TownRules.build_town_action_recap(control, "order", action_id, selected_action, control_result, control_before)
	if bool(control_recap.get("active", false)):
		control.flags["last_town_action_recap"] = control_recap.duplicate(true)
	var expected_deltas := _resource_deltas(live_before, control.to_dict())

	var public_result: Dictionary = shell.validation_perform_town_action(action_id)
	await get_tree().process_frame
	await get_tree().process_frame
	var active: Dictionary = stage.validation_town_action_presentation_snapshot()
	var live_after: Dictionary = live_session.to_dict()
	var after_hero_ids := _player_hero_ids(live_after)
	var recruited_hero := _player_hero_snapshot(live_after, hero_id)
	var control_hero := _player_hero_snapshot(control.to_dict(), hero_id)
	var audio_records: Array = PresentationAudio.validation_records()
	var ui_audio_after_success: Array = UiAudio.validation_records()

	var roster_exact: bool = (
		hero_id not in before_hero_ids
		and hero_id in after_hero_ids
		and after_hero_ids.size() == before_hero_ids.size() + 1
		and not recruited_hero.is_empty()
		and recruited_hero == control_hero
		and _active_hero_snapshot(live_after) == before_active_hero
		and _cost_deltas_exact(expected_deltas, recruit_cost)
	)
	var reduced_motion := bool(mode.get("reduced_motion", false))
	var missing_asset := bool(mode.get("missing_asset", false))
	var expected_vfx := ["commander_arrived_badge"] if reduced_motion else ["vfx_placeholder_town_hero_hire"]
	var expected_draw_entries := ["commander_arrived_badge"] if reduced_motion else ["hero_hire_art", "commander_arrived_badge"]
	var expected_draw_mode := "commander_arrived_badge" if reduced_motion else ("procedural_hero_hire" if missing_asset else "imported_texture")
	var asset: Dictionary = active.get("vfx_asset", {}) if active.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = active.get("vfx_draw", {}) if active.get("vfx_draw", {}) is Dictionary else {}
	var audio_record: Dictionary = audio_records[0] if audio_records.size() == 1 and audio_records[0] is Dictionary else {}
	var audio_exact: bool = (
		audio_records.size() == 1
		and Array(active.get("audio_playback_records", [])) == audio_records
		and String(audio_record.get("cue_id", "")) == "audio_placeholder_town_hero_hire"
		and String(audio_record.get("source", "")) == "TownStageView.present_town_action"
		and String(Dictionary(audio_record.get("metadata", {})).get("event_id", "")) == "town_hero_hired"
		and int(Dictionary(audio_record.get("metadata", {})).get("presentation_serial", 0)) == 1
		and String(Dictionary(audio_record.get("metadata", {})).get("town_placement_id", "")) == String(live_town.get("placement_id", ""))
		and bool(audio_record.get("played", false))
		and String(audio_record.get("playback_source", "")) == "imported_wav"
		and String(audio_record.get("asset_path", "")) == "res://art/audio/runtime/presentation/town_hero_hire.wav"
		and String(audio_record.get("role", "")) == "town_hero_hired"
		and int(audio_record.get("duration_msec", 0)) == 420
		and int(audio_record.get("stream_mix_rate", 0)) == 44100
		and bool(audio_record.get("stream_stereo", false))
		and int(audio_record.get("stream_loop_mode", -1)) == AudioStreamWAV.LOOP_DISABLED
	)
	var consequence_exact: bool = (
		bool(control_result.get("ok", false))
		and bool(public_result.get("ok", false))
		and String(public_result.get("lane", "")) == "tavern"
		and String(public_result.get("action_id", "")) == action_id
		and String(Dictionary(public_result.get("town_action_recap", {})).get("kind", "")) == "order"
		and live_after == control.to_dict()
		and roster_exact
		and ui_audio_after_success == stale_audio_records
	)
	var presentation_exact: bool = (
		bool(active.get("active", false))
		and int(active.get("serial", 0)) == 1
		and String(active.get("event_id", "")) == "town_hero_hired"
		and String(active.get("cue_id", "")) == "cue_town_hero_hired"
		and String(active.get("town_placement_id", "")) == String(live_town.get("placement_id", ""))
		and String(active.get("hero_id", "")) == hero_id
		and String(active.get("hero_name", "")) == String(hero_template.get("name", ""))
		and String(active.get("hero_faction_id", "")) == String(hero_template.get("faction_id", ""))
		and Dictionary(active.get("hero_recruit_cost", {})) == recruit_cost
		and Array(active.get("resource_deltas", [])) == expected_deltas
		and int(active.get("player_hero_count", 0)) == after_hero_ids.size()
		and String(active.get("result_message", "")) == String(control_result.get("message", ""))
		and String(active.get("selected_mode", "")) == ("reduced_motion" if reduced_motion else "normal")
		and String(active.get("selected_animation_state", "")) == ("commander_arrived_badge" if reduced_motion else "commander_arrived")
		and String(active.get("selected_blocking_policy", "")) == "nonblocking"
		and Array(active.get("selected_vfx_cue_ids", [])) == expected_vfx
		and Array(active.get("selected_audio_cue_ids", [])) == ["audio_placeholder_town_hero_hire"]
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
	var refresh_silent: bool = not refresh_result.is_empty() and int(after_refresh.get("serial", 0)) == serial and live_session.to_dict() == authority_before_refresh and PresentationAudio.validation_records() == audio_records and UiAudio.validation_records() == stale_audio_records
	var authority_before_invalid: Dictionary = live_session.to_dict()
	var invalid_result: Dictionary = shell.validation_perform_town_action(action_id)
	await get_tree().process_frame
	var after_invalid: Dictionary = stage.validation_town_action_presentation_snapshot()
	var invalid_silent: bool = not bool(invalid_result.get("ok", true)) and int(after_invalid.get("serial", 0)) == serial and live_session.to_dict() == authority_before_invalid and PresentationAudio.validation_records() == audio_records and UiAudio.validation_records() == stale_audio_records
	var row := {
		"ok": malformed_fail_closed and stale_failure_exact and unavailable_silent and consequence_exact and presentation_exact and refresh_silent and invalid_silent and SessionDataScript.SAVE_VERSION == 9,
		"viewport": [viewport_size.x, viewport_size.y],
		"mode": String(mode.get("id", "")),
		"action_id": action_id,
		"hero_id": hero_id,
		"player_hero_count": after_hero_ids.size(),
		"malformed_fail_closed": malformed_fail_closed,
		"stale_failure_exact": stale_failure_exact,
		"stale_invalid_audio_exact": stale_invalid_audio_exact,
		"stale_invalid_audio_record": stale_invalid_record,
		"stale_click_audio_record": stale_click_record,
		"stale_failure_diagnostics": stale_failure_diagnostics,
		"unavailable_silent": unavailable_silent,
		"roster_exact": roster_exact,
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
		row["unavailable_result"] = unavailable_result
		row["session_differences"] = _recursive_exact_differences(control.to_dict(), live_after)
	return await _finish_case(shell, row)

func _enabled_tavern_action(session) -> Dictionary:
	for action_value in TownRules.get_tavern_actions(session):
		if action_value is Dictionary and String(action_value.get("id", "")).begins_with("hire_hero:") and not bool(action_value.get("disabled", true)):
			return action_value.duplicate(true)
	return {}

func _button_for_label(container: Container, label: String) -> Button:
	if container == null:
		return null
	for child in container.get_children():
		if child is Button and (child as Button).text == label:
			return child as Button
	return null

func _first_player_town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}

func _seed_tavern_fixture(session, town: Dictionary) -> void:
	var buildings: Array = town.get("built_buildings", []).duplicate()
	if "building_wayfarers_hall" not in buildings:
		buildings.append("building_wayfarers_hall")
	town["built_buildings"] = buildings
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("placement_id", "")) == String(town.get("placement_id", "")):
			towns[index] = town
	session.overworld["towns"] = towns
	_move_active_hero_to_town(session, town)
	var resources: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	for resource_id in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		resources[resource_id] = maxi(9999, int(resources.get(resource_id, 0)))
	session.overworld["resources"] = resources

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

func _player_hero_ids(session_dict: Dictionary) -> Array:
	var overworld: Dictionary = session_dict.get("overworld", {}) if session_dict.get("overworld", {}) is Dictionary else {}
	var ids := []
	for hero_value in overworld.get("player_heroes", []):
		if hero_value is Dictionary:
			var hero_id := String(hero_value.get("id", ""))
			if hero_id != "" and hero_id not in ids:
				ids.append(hero_id)
	ids.sort()
	return ids

func _active_hero_snapshot(session_dict: Dictionary) -> Dictionary:
	var overworld: Dictionary = session_dict.get("overworld", {}) if session_dict.get("overworld", {}) is Dictionary else {}
	return Dictionary(overworld.get("hero", {})).duplicate(true) if overworld.get("hero", {}) is Dictionary else {}

func _player_hero_snapshot(session_dict: Dictionary, hero_id: String) -> Dictionary:
	var overworld: Dictionary = session_dict.get("overworld", {}) if session_dict.get("overworld", {}) is Dictionary else {}
	for hero_value in overworld.get("player_heroes", []):
		if hero_value is Dictionary and String(hero_value.get("id", "")) == hero_id:
			return hero_value.duplicate(true)
	return {}

func _resource_deltas(before: Dictionary, after: Dictionary) -> Array:
	var before_overworld: Dictionary = before.get("overworld", {}) if before.get("overworld", {}) is Dictionary else {}
	var after_overworld: Dictionary = after.get("overworld", {}) if after.get("overworld", {}) is Dictionary else {}
	var before_resources: Dictionary = before_overworld.get("resources", {}) if before_overworld.get("resources", {}) is Dictionary else {}
	var after_resources: Dictionary = after_overworld.get("resources", {}) if after_overworld.get("resources", {}) is Dictionary else {}
	var deltas := []
	for resource_id in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		var before_value := int(before_resources.get(resource_id, 0))
		var after_value := int(after_resources.get(resource_id, 0))
		if before_value != after_value:
			deltas.append({"resource_id": resource_id, "before": before_value, "after": after_value, "delta": after_value - before_value})
	return deltas

func _cost_deltas_exact(deltas: Array, cost: Dictionary) -> bool:
	if deltas.size() != cost.size():
		return false
	for resource_id_value in cost:
		var resource_id := String(resource_id_value)
		var matched := false
		for delta_value in deltas:
			if delta_value is Dictionary and String(delta_value.get("resource_id", "")) == resource_id and int(delta_value.get("delta", 0)) == -int(cost.get(resource_id, 0)):
				matched = true
		if not matched:
			return false
	return true

func _finish_case(shell: Node, result: Dictionary) -> Dictionary:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame
	PresentationAudio.validation_reset()
	UiAudio.validation_reset()
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
	push_error("TOWN_HERO_HIRE_COMPLETION_FEEDBACK_REPORT failed: %s payload=%s" % [message, JSON.stringify(payload)])
	get_tree().quit(1)
