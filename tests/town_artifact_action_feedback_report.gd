extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const MODES := [
	{"id": "normal", "reduced_motion": false, "missing_asset": false},
	{"id": "missing_icon", "reduced_motion": false, "missing_asset": true},
	{"id": "reduced_motion", "reduced_motion": true, "missing_asset": false},
]
const PLACEMENT_ID := "riverwatch_hold"
const BUILDING_ID := "building_embercourt_lockhouse_tally"
const ARTIFACT_ID := "artifact_tollstone_ring"
const TABLE_ID := "artifact_source_town_landmark_services"

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
				_fail("Could not set focused motion preference.", {"mode": mode, "settings_result": settings_result}, original_window_size, original_reduced_motion)
				return
			var row: Dictionary = await _run_case(viewport_size, mode)
			rows.append(row)
			if not bool(row.get("ok", false)):
				_fail("Town artifact action feedback row failed.", {"row": row}, original_window_size, original_reduced_motion)
				return
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	await get_tree().process_frame
	print("TOWN_ARTIFACT_ACTION_FEEDBACK_REPORT %s" % JSON.stringify({
		"ok": true,
		"viewports": [[1280, 720], [1920, 1080]],
		"normal_imported_rows": 2,
		"missing_icon_fallback_rows": 2,
		"reduced_motion_rows": 2,
		"public_commission_rows": 6,
		"public_stow_rows": 6,
		"public_equip_rows": 6,
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
	var authored_town := _town(authored_session, PLACEMENT_ID)
	if authored_town.is_empty():
		return {"ok": false, "failure": "player_town_missing"}
	_seed_artifact_service_fixture(authored_session, authored_town)
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
	var malformed_after: Dictionary = stage.present_town_action({"event_id": "artifact_acquired"})
	var malformed_fail_closed: bool = malformed_after == malformed_before and not blocker.visible and PresentationAudio.validation_records().is_empty()

	var commission_action := _enabled_action(live_session, "commission_artifact:%s" % BUILDING_ID)
	if commission_action.is_empty() or String(commission_action.get("artifact_id", "")) != ARTIFACT_ID:
		return await _finish_case(shell, {"ok": false, "failure": "commission_action_missing", "actions": TownRules.get_artifact_actions(live_session)})
	var cost: Dictionary = commission_action.get("cost", {}).duplicate(true) if commission_action.get("cost", {}) is Dictionary else {}
	var fixture_resources: Dictionary = live_session.overworld.get("resources", {}).duplicate(true)
	var unavailable_resources := fixture_resources.duplicate(true)
	for resource_id_value in cost:
		unavailable_resources[String(resource_id_value)] = 0
	live_session.overworld["resources"] = unavailable_resources
	shell.validation_force_refresh()
	await get_tree().process_frame
	var unavailable_before: Dictionary = live_session.to_dict()
	var unavailable_result: Dictionary = shell.validation_perform_town_action("commission_artifact:%s" % BUILDING_ID)
	await get_tree().process_frame
	var unavailable_silent: bool = not bool(unavailable_result.get("ok", true)) and live_session.to_dict() == unavailable_before and stage.validation_town_action_presentation_snapshot() == malformed_before and PresentationAudio.validation_records().is_empty()
	live_session.overworld["resources"] = fixture_resources
	shell.validation_force_refresh()
	await get_tree().process_frame

	if bool(mode.get("missing_asset", false)):
		stage.set("_town_vfx_texture_missing", {ArtifactRules.artifact_icon_path(ARTIFACT_ID): true})
	var control = SessionDataScript.SessionData.new()
	control.from_dict(live_session.to_dict().duplicate(true))
	var live_before: Dictionary = live_session.to_dict()
	var commission_control := _apply_control_action(control, "commission_artifact:%s" % BUILDING_ID)
	var commission_result: Dictionary = shell.validation_perform_town_action("commission_artifact:%s" % BUILDING_ID)
	await get_tree().process_frame
	await get_tree().process_frame
	var commission_snapshot: Dictionary = stage.validation_town_action_presentation_snapshot()
	var after_commission: Dictionary = live_session.to_dict()
	var commission_location := ArtifactRules.locate_artifact(live_session.overworld.get("hero", {}), ARTIFACT_ID)
	var artifact_slot := String(commission_location.get("slot", ""))
	var expected_deltas := _resource_deltas(live_before, control.to_dict())
	var commission_exact: bool = (
		bool(commission_control.get("ok", false))
		and bool(commission_result.get("ok", false))
		and String(commission_result.get("lane", "")) == "artifact"
		and after_commission == control.to_dict()
		and _cost_deltas_exact(expected_deltas, cost)
		and String(commission_location.get("location", "")) == "equipped"
		and artifact_slot in ArtifactRules.EQUIPMENT_SLOTS
		and _provenance_exact(TownRules.get_active_town(live_session), commission_action)
		and _presentation_exact(commission_snapshot, mode, live_town, "commission", "artifact_acquired", ARTIFACT_ID, artifact_slot, 1, cost, expected_deltas)
	)
	if not bool(mode.get("reduced_motion", false)) and bool(commission_snapshot.get("active", false)):
		await _press_action("ui_cancel")
	var commission_released: bool = not blocker.visible and not bool(stage.validation_town_action_presentation_snapshot().get("active", false)) if not bool(mode.get("reduced_motion", false)) else not blocker.visible

	var stow_action_id := "unequip_artifact:%s" % artifact_slot
	var stow_action := _enabled_action(live_session, stow_action_id)
	var stow_control := _apply_control_action(control, stow_action_id)
	var stow_result: Dictionary = shell.validation_perform_town_action(stow_action_id)
	await get_tree().process_frame
	await get_tree().process_frame
	var stow_snapshot: Dictionary = stage.validation_town_action_presentation_snapshot()
	var after_stow: Dictionary = live_session.to_dict()
	var stow_exact: bool = (
		not stow_action.is_empty()
		and bool(stow_control.get("ok", false))
		and bool(stow_result.get("ok", false))
		and after_stow == control.to_dict()
		and String(ArtifactRules.locate_artifact(live_session.overworld.get("hero", {}), ARTIFACT_ID).get("location", "")) == "inventory"
		and _presentation_exact(stow_snapshot, mode, live_town, "stow", "artifact_unequipped", ARTIFACT_ID, artifact_slot, 2, {}, [])
	)
	var stale_before: Dictionary = live_session.to_dict()
	var stale_result: Dictionary = shell.validation_perform_town_action(stow_action_id)
	await get_tree().process_frame
	var stale_silent: bool = not bool(stale_result.get("ok", true)) and live_session.to_dict() == stale_before and int(stage.validation_town_action_presentation_snapshot().get("serial", 0)) == 2 and PresentationAudio.validation_records().size() == 2

	var equip_action_id := "equip_artifact:%s" % ARTIFACT_ID
	var equip_action := _enabled_action(live_session, equip_action_id)
	var equip_control := _apply_control_action(control, equip_action_id)
	var equip_result: Dictionary = shell.validation_perform_town_action(equip_action_id)
	await get_tree().process_frame
	await get_tree().process_frame
	var equip_snapshot: Dictionary = stage.validation_town_action_presentation_snapshot()
	var after_equip: Dictionary = live_session.to_dict()
	var audio_records: Array = PresentationAudio.validation_records()
	var equip_exact: bool = (
		not equip_action.is_empty()
		and bool(equip_control.get("ok", false))
		and bool(equip_result.get("ok", false))
		and after_equip == control.to_dict()
		and String(ArtifactRules.locate_artifact(live_session.overworld.get("hero", {}), ARTIFACT_ID).get("location", "")) == "equipped"
		and _presentation_exact(equip_snapshot, mode, live_town, "equip", "artifact_equipped", ARTIFACT_ID, artifact_slot, 3, {}, [])
		and _audio_records_exact(audio_records, live_town)
	)

	var serial := int(equip_snapshot.get("serial", 0))
	var authority_before_refresh: Dictionary = live_session.to_dict()
	var refresh_result: Dictionary = shell.validation_force_refresh()
	await get_tree().process_frame
	var after_refresh: Dictionary = stage.validation_town_action_presentation_snapshot()
	var refresh_silent: bool = not refresh_result.is_empty() and int(after_refresh.get("serial", 0)) == serial and live_session.to_dict() == authority_before_refresh and PresentationAudio.validation_records() == audio_records
	var repeat_before: Dictionary = live_session.to_dict()
	var repeat_result: Dictionary = shell.validation_perform_town_action("commission_artifact:%s" % BUILDING_ID)
	await get_tree().process_frame
	var repeat_silent: bool = not bool(repeat_result.get("ok", true)) and live_session.to_dict() == repeat_before and int(stage.validation_town_action_presentation_snapshot().get("serial", 0)) == serial and PresentationAudio.validation_records() == audio_records
	var row := {
		"ok": malformed_fail_closed and unavailable_silent and commission_exact and commission_released and stow_exact and stale_silent and equip_exact and refresh_silent and repeat_silent and SessionDataScript.SAVE_VERSION == 9,
		"viewport": [viewport_size.x, viewport_size.y],
		"mode": String(mode.get("id", "")),
		"artifact_id": ARTIFACT_ID,
		"artifact_slot": artifact_slot,
		"malformed_fail_closed": malformed_fail_closed,
		"unavailable_silent": unavailable_silent,
		"commission_exact": commission_exact,
		"commission_released": commission_released,
		"stow_exact": stow_exact,
		"stale_silent": stale_silent,
		"equip_exact": equip_exact,
		"refresh_silent": refresh_silent,
		"repeat_silent": repeat_silent,
		"audio_exact": _audio_records_exact(audio_records, live_town),
	}
	if not bool(row.get("ok", false)):
		row["commission_snapshot"] = commission_snapshot
		row["stow_snapshot"] = stow_snapshot
		row["equip_snapshot"] = equip_snapshot
		row["audio_records"] = audio_records
		row["commission_result"] = commission_result
		row["stow_result"] = stow_result
		row["equip_result"] = equip_result
		row["stale_result"] = stale_result
		row["repeat_result"] = repeat_result
		row["session_differences"] = _recursive_exact_differences(control.to_dict(), live_session.to_dict())
	return await _finish_case(shell, row)

func _apply_control_action(session, action_id: String) -> Dictionary:
	var action := _enabled_action(session, action_id)
	var before := TownRules.town_action_consequence_signature(session)
	var result: Dictionary = TownRules.manage_artifact_at_active_town(session, action_id)
	var recap: Dictionary = TownRules.build_town_action_recap(session, "order", action_id, action, result, before)
	if bool(recap.get("active", false)):
		session.flags["last_town_action_recap"] = recap.duplicate(true)
	return result

func _presentation_exact(snapshot: Dictionary, mode: Dictionary, town: Dictionary, action_kind: String, event_id: String, artifact_id: String, slot: String, serial: int, cost: Dictionary, resource_deltas: Array) -> bool:
	var reduced_motion := bool(mode.get("reduced_motion", false))
	var missing_asset := bool(mode.get("missing_asset", false))
	var expected_cue := "cue_artifact_acquired" if event_id == "artifact_acquired" else ("cue_artifact_equipped" if event_id == "artifact_equipped" else "cue_artifact_unequipped")
	var expected_state := ("artifact_badge_added" if reduced_motion else "artifact_claim") if event_id == "artifact_acquired" else (("slot_badge_added" if reduced_motion else "slot_equip_pulse") if event_id == "artifact_equipped" else ("slot_badge_removed" if reduced_motion else "slot_unequip_pulse"))
	var expected_vfx := (["artifact_badge_added"] if reduced_motion else ["vfx_placeholder_artifact_claim"]) if event_id == "artifact_acquired" else ((["slot_badge_added"] if reduced_motion else ["vfx_placeholder_slot_equip"]) if event_id == "artifact_equipped" else (["slot_badge_removed"] if reduced_motion else ["vfx_placeholder_slot_unequip"]))
	var expected_audio := "audio_placeholder_artifact_claim" if event_id == "artifact_acquired" else ("audio_placeholder_artifact_equip" if event_id == "artifact_equipped" else "audio_placeholder_artifact_stow")
	var expected_blocking := ("nonblocking_reduced_motion" if reduced_motion else "input_blocking_timeout") if event_id == "artifact_acquired" else "nonblocking"
	var expected_entries := (["artifact_badge_added"] if reduced_motion else ["artifact_icon_claim", "artifact_badge_added"]) if event_id == "artifact_acquired" else ((["slot_badge_added"] if reduced_motion else ["artifact_icon_equip", "slot_badge_added"]) if event_id == "artifact_equipped" else (["slot_badge_removed"] if reduced_motion else ["artifact_icon_stow", "slot_badge_removed"]))
	var asset: Dictionary = snapshot.get("vfx_asset", {}) if snapshot.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = snapshot.get("vfx_draw", {}) if snapshot.get("vfx_draw", {}) is Dictionary else {}
	var expected_draw_mode := String(asset.get("fallback_mode", "")) if reduced_motion or missing_asset else "imported_texture"
	return (
		bool(snapshot.get("active", false))
		and int(snapshot.get("serial", 0)) == serial
		and String(snapshot.get("event_id", "")) == event_id
		and String(snapshot.get("cue_id", "")) == expected_cue
		and String(snapshot.get("town_placement_id", "")) == String(town.get("placement_id", ""))
		and String(snapshot.get("artifact_action_kind", "")) == action_kind
		and String(snapshot.get("artifact_id", "")) == artifact_id
		and String(snapshot.get("artifact_name", "")) == ArtifactRules.artifact_name(artifact_id)
		and String(snapshot.get("artifact_icon_path", "")) == ArtifactRules.artifact_icon_path(artifact_id)
		and String(snapshot.get("artifact_location", "")) == ("inventory" if event_id == "artifact_unequipped" else "equipped")
		and String(snapshot.get("artifact_slot", "")) == slot
		and Dictionary(snapshot.get("artifact_cost", {})) == cost
		and Array(snapshot.get("resource_deltas", [])) == resource_deltas
		and String(snapshot.get("selected_mode", "")) == ("reduced_motion" if reduced_motion else "normal")
		and String(snapshot.get("selected_animation_state", "")) == expected_state
		and String(snapshot.get("selected_playback_policy", "")) == "queue_resolved"
		and String(snapshot.get("selected_blocking_policy", "")) == expected_blocking
		and Array(snapshot.get("selected_vfx_cue_ids", [])) == expected_vfx
		and Array(snapshot.get("selected_audio_cue_ids", [])) == [expected_audio]
		and Array(snapshot.get("draw_entries", [])) == expected_entries
		and bool(snapshot.get("blocks_input", false)) == (event_id == "artifact_acquired" and not reduced_motion)
		and bool(snapshot.get("draw_rect_contained", false))
		and String(draw.get("mode", "")) == expected_draw_mode
		and bool(asset.get("uses_imported_asset", false)) == (not reduced_motion and not missing_asset)
		and bool(asset.get("uses_procedural_fallback", false)) == (reduced_motion or missing_asset)
	)

func _audio_records_exact(records: Array, town: Dictionary) -> bool:
	var expected := [
		{"cue": "audio_placeholder_artifact_claim", "event": "artifact_acquired", "path": "res://art/audio/runtime/presentation/artifact_claim.wav", "role": "overworld_artifact_recovered", "duration": 420},
		{"cue": "audio_placeholder_artifact_stow", "event": "artifact_unequipped", "path": "res://art/audio/runtime/presentation/artifact_stow.wav", "role": "overworld_artifact_stowed", "duration": 280},
		{"cue": "audio_placeholder_artifact_equip", "event": "artifact_equipped", "path": "res://art/audio/runtime/presentation/artifact_equip.wav", "role": "overworld_artifact_equipped", "duration": 260},
	]
	if records.size() != expected.size():
		return false
	for index in range(expected.size()):
		var record: Dictionary = records[index] if records[index] is Dictionary else {}
		var spec: Dictionary = expected[index]
		var metadata: Dictionary = record.get("metadata", {}) if record.get("metadata", {}) is Dictionary else {}
		if (
			String(record.get("cue_id", "")) != String(spec.get("cue", ""))
			or String(record.get("source", "")) != "TownStageView.present_town_action"
			or String(metadata.get("event_id", "")) != String(spec.get("event", ""))
			or int(metadata.get("presentation_serial", 0)) != index + 1
			or String(metadata.get("town_placement_id", "")) != String(town.get("placement_id", ""))
			or not bool(record.get("played", false))
			or String(record.get("playback_source", "")) != "imported_wav"
			or String(record.get("asset_path", "")) != String(spec.get("path", ""))
			or String(record.get("role", "")) != String(spec.get("role", ""))
			or int(record.get("duration_msec", 0)) != int(spec.get("duration", 0))
			or int(record.get("stream_mix_rate", 0)) != 44100
			or not bool(record.get("stream_stereo", false))
			or int(record.get("stream_loop_mode", -1)) != AudioStreamWAV.LOOP_DISABLED
		):
			return false
	return true

func _enabled_action(session, action_id: String) -> Dictionary:
	for action_value in TownRules.get_artifact_actions(session):
		if action_value is Dictionary and String(action_value.get("id", "")) == action_id and not bool(action_value.get("disabled", false)):
			return action_value.duplicate(true)
	return {}

func _provenance_exact(town: Dictionary, action: Dictionary) -> bool:
	return (
		String(town.get("artifact_reward_id", "")) == ARTIFACT_ID
		and String(town.get("artifact_reward_table_id", "")) == TABLE_ID
		and String(town.get("artifact_reward_table_id", "")) == String(action.get("artifact_reward_table_id", ""))
		and String(town.get("artifact_reward_source_key", "")) == String(action.get("source_key", ""))
		and String(town.get("artifact_reward_claimed_by_owner", "")) == "player"
		and String(town.get("artifact_reward_service_building_id", "")) == BUILDING_ID
	)

func _seed_artifact_service_fixture(session, town: Dictionary) -> void:
	var buildings: Array = town.get("built_buildings", []).duplicate()
	if BUILDING_ID not in buildings:
		buildings.append(BUILDING_ID)
	town["built_buildings"] = buildings
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("placement_id", "")) == PLACEMENT_ID:
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
	var visit_result: Dictionary = OverworldRules.set_active_town_visit(session, PLACEMENT_ID)
	if not bool(visit_result.get("ok", false)):
		push_error("Could not activate Town artifact fixture: %s" % JSON.stringify(visit_result))

func _town(session, placement_id: String) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("placement_id", "")) == placement_id:
			return town_value
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

func _press_action(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame

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
	push_error("TOWN_ARTIFACT_ACTION_FEEDBACK_REPORT failed: %s payload=%s" % [message, JSON.stringify(payload)])
	get_tree().quit(1)
