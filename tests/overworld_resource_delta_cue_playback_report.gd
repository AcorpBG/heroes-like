extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "OVERWORLD_RESOURCE_DELTA_CUE_PLAYBACK_REPORT"
const PLACEMENT_ID := "north_wood"
const RESOURCE_IDS := [
	"gold", "wood", "ore", "aetherglass", "embergrain", "peatwax",
	"verdant_grafts", "brass_scrip", "memory_salt",
]
const RESOURCE_REGISTRY_PATH := "res://content/resources.json"
const RESOURCE_FIXTURE_PATH := "res://tests/fixtures/economy_resource_schema/resource_registry.json"
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
	var registry_contract := _resource_registry_contract()
	if not bool(registry_contract.get("ok", false)):
		return _fail("Production resource registry contract failed: %s" % JSON.stringify(registry_contract), original_window_size, original_reduced_motion)
	var rows := []
	for viewport_size in VIEWPORT_SIZES:
		for mode in MODES:
			var preference_result: Dictionary = SettingsService.set_reduced_motion_enabled(bool(mode.get("reduced_motion", false)))
			if not bool(preference_result.get("ok", false)):
				return _fail("Could not set motion preference: %s" % preference_result, original_window_size, original_reduced_motion)
			var row: Dictionary = await _run_case(viewport_size, mode)
			rows.append(row)
			if not bool(row.get("ok", false)):
				return _fail("Resource-delta cue failed at %s/%s: %s" % [viewport_size, mode.get("id", ""), JSON.stringify(row)], original_window_size, original_reduced_motion)
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	await get_tree().process_frame
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "resource_registry": registry_contract, "rows": rows})])
	get_tree().quit(0)

func _fail(message: String, original_window_size: Vector2i, original_reduced_motion: bool) -> void:
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	push_error(message)
	get_tree().quit(1)

func _run_case(viewport_size: Vector2i, mode: Dictionary) -> Dictionary:
	PresentationAudio.validation_reset()
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	var authored_session = _resource_session()
	if authored_session == null:
		return {"ok": false, "failure": "fixture_missing"}
	var active_session = SessionState.set_active_session(authored_session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var live_session = shell.get("_session")
	if live_session == null:
		live_session = active_session
	var primary_action := shell.get_node_or_null("%PrimaryAction") as Button
	var cue_row := shell.get_node_or_null("%ResourceDeltaCueRow") as Control
	var cue_icon := shell.get_node_or_null("%ResourceDeltaCueIcon") as TextureRect
	var cue := shell.get_node_or_null("%ResourceDeltaCue") as Label
	var open_command := shell.get_node_or_null("%OpenCommand") as Button
	if primary_action == null or cue_row == null or cue_icon == null or cue == null or open_command == null:
		return await _finish_case(shell, {"ok": false, "failure": "live_surface_missing"})
	var initial: Dictionary = shell.validation_snapshot()
	var primary_payload: Dictionary = initial.get("primary_action", {}) if initial.get("primary_action", {}) is Dictionary else {}
	var expected_icon_path := "res://art/economy/runtime/resources/wood.png"
	var primary_icon: Texture2D = primary_action.icon
	var primary_exact := (
		String(initial.get("primary_action_id", "")) == "collect_resource"
		and String(primary_payload.get("resource_id", "")) == "wood"
		and String(primary_payload.get("resource_icon_path", "")) == expected_icon_path
		and String(initial.get("primary_action_button_icon_path", "")) == expected_icon_path
		and int(initial.get("primary_action_button_icon_max_width", 0)) == 24
		and primary_icon != null
		and primary_icon.get_size() == Vector2(128.0, 128.0)
		and not primary_action.disabled
		and primary_action.is_visible_in_tree()
	)
	var malformed_before := _presentation(shell)
	var malformed_after: Dictionary = shell.present_resource_delta_presentation({
		"serial": 991,
		"event_id": "ui_resource_delta",
		"cue_id": "cue_ui_resource_delta",
		"action_id": "collect_resource",
	})
	var malformed_fail_closed := malformed_after == malformed_before and not cue_row.visible and not cue_icon.visible and not cue.visible and PresentationAudio.validation_records().is_empty()

	var live_before: Dictionary = live_session.to_dict()
	var resources_before: Dictionary = (live_session.overworld.get("resources", {}) as Dictionary).duplicate(true)
	var control = SessionDataScript.SessionData.new()
	control.from_dict(live_before.duplicate(true))
	var control_result: Dictionary = OverworldRules.perform_context_action(control, "collect_resource")
	var control_recap: Dictionary = (control_result.get("post_action_recap", {}) as Dictionary).duplicate(true) if control_result.get("post_action_recap", {}) is Dictionary else {}
	if String(control_recap.get("kind", "")) != "resource_site":
		return await _finish_case(shell, {"ok": false, "failure": "control_recap_missing", "control": control_result})
	control.flags["last_overworld_action_recap"] = control_recap.duplicate(true)
	primary_action.emit_signal("pressed")
	var active := _presentation(shell)
	var audio_records: Array = PresentationAudio.validation_records()
	var audio_record: Dictionary = audio_records[0] if audio_records.size() == 1 and audio_records[0] is Dictionary else {}
	var audio_exact := _audio_record_exact(active, audio_record, "audio_placeholder_resource_tick", "res://art/audio/runtime/presentation/resource_tick.wav", "overworld_resource_collected", "OverworldShell.resource_delta", 240)
	var object_resolution := _object_resolution(shell)
	var live_after: Dictionary = live_session.to_dict()
	var expected_deltas := _resource_deltas(resources_before, control.overworld.get("resources", {}), Array(active.get("deltas", [])))
	var reduced_motion := bool(mode.get("reduced_motion", false))
	var vfx_asset: Dictionary = active.get("vfx_asset", {}) if active.get("vfx_asset", {}) is Dictionary else {}
	var vfx_asset_exact := (
		bool(vfx_asset.get("imported", false)) == not reduced_motion
		and bool(vfx_asset.get("icon_visible", false)) == not reduced_motion
		and String(vfx_asset.get("cue_id", "")) == ("resource_delta_static" if reduced_motion else "vfx_placeholder_resource_delta")
		and String(vfx_asset.get("texture_path", "")) == ("" if reduced_motion else "res://art/overworld/runtime/vfx/resource_delta.png")
		and String(vfx_asset.get("render_mode", "")) == ("" if reduced_motion else "action_feedback_icon")
		and String(vfx_asset.get("fallback", "")) == ("text_only_feedback" if reduced_motion else "")
		and cue_row.is_visible_in_tree()
		and cue.is_visible_in_tree()
		and cue_icon.is_visible_in_tree() == not reduced_motion
	)
	var presentation_exact: bool = (
		primary_exact
		and bool(control_result.get("ok", false))
		and live_after == control.to_dict()
		and bool(active.get("active", false))
		and bool(active.get("visible", false))
		and int(active.get("serial", 0)) == 1
		and String(active.get("event_id", "")) == "ui_resource_delta"
		and String(active.get("cue_id", "")) == "cue_ui_resource_delta"
		and String(active.get("action_id", "")) == "collect_resource"
		and String(active.get("placement_id", "")) == PLACEMENT_ID
		and active.get("deltas", []) == expected_deltas
		and not expected_deltas.is_empty()
		and String(active.get("result_message", "")) == String(control_result.get("message", ""))
		and active.get("post_action_recap", {}) == control_recap
		and String(active.get("selected_animation_state", "")) == ("resource_delta_static" if reduced_motion else "resource_delta_tick")
		and String(active.get("selected_fallback_tag", "")) == ("resource_delta_static" if reduced_motion else "")
		and String(active.get("selected_playback_policy", "")) == "queue_resolved"
		and String(active.get("selected_blocking_policy", "")) == "nonblocking"
		and Array(active.get("selected_vfx_cue_ids", [])) == (["resource_delta_static"] if reduced_motion else ["vfx_placeholder_resource_delta"])
		and Array(active.get("selected_audio_cue_ids", [])) == ["audio_placeholder_resource_tick"]
		and bool(active.get("allows_large_motion", true)) == not reduced_motion
		and int(active.get("duration_ms", 0)) == (260 if reduced_motion else 520)
		and cue.visible
		and String(active.get("text", "")) != ""
		and String(active.get("tooltip_text", "")) == String(control_result.get("message", ""))
		and vfx_asset_exact
		and audio_records.size() == 1
		and audio_exact
	)
	var object_resolution_exact := (
		String(object_resolution.get("event_id", "")) == "overworld_object_captured"
		and String(object_resolution.get("family", "")) == "resource_site"
		and String(object_resolution.get("placement_id", "")) == PLACEMENT_ID
	)
	var serial := int(active.get("serial", 0))
	var progress_before := float(active.get("progress", 0.0))
	shell.call("_refresh")
	var refreshed := _presentation(shell)
	var refresh_exact: bool = int(refreshed.get("serial", 0)) == serial and bool(refreshed.get("active", false)) and float(refreshed.get("progress", -1.0)) >= progress_before and live_session.to_dict() == live_after and PresentationAudio.validation_records() == audio_records
	open_command.emit_signal("pressed")
	var after_command := _presentation(shell)
	var nonblocking_exact: bool = String(shell.get("_active_drawer")) == "command" and bool(after_command.get("active", false)) and live_session.to_dict() == live_after
	var settle_frames := 0
	while bool(_presentation(shell).get("active", false)) and settle_frames < 120:
		await get_tree().process_frame
		settle_frames += 1
	var settled := _presentation(shell)
	var completion_exact: bool = not bool(settled.get("active", true)) and int(settled.get("serial", 0)) == serial and not cue_row.visible and not cue_icon.visible and not cue.visible and live_session.to_dict() == live_after and PresentationAudio.validation_records() == audio_records
	var failed_before: Dictionary = live_session.to_dict()
	var failed_result: Dictionary = shell.validation_perform_context_action("collect_resource")
	var failed_after := _presentation(shell)
	var failed_exact: bool = not bool(failed_result.get("ok", true)) and int(failed_after.get("serial", 0)) == serial and not bool(failed_after.get("active", true)) and live_session.to_dict() == failed_before and PresentationAudio.validation_records() == audio_records
	var row := {
		"ok": malformed_fail_closed and presentation_exact and object_resolution_exact and refresh_exact and nonblocking_exact and completion_exact and failed_exact,
		"viewport_size": viewport_size,
		"mode": String(mode.get("id", "")),
		"presentation_exact": presentation_exact,
		"audio_exact": audio_exact,
		"audio_record": audio_record,
		"vfx_asset_exact": vfx_asset_exact,
		"object_resolution_exact": object_resolution_exact,
		"refresh_exact": refresh_exact,
		"nonblocking_exact": nonblocking_exact,
		"completion_exact": completion_exact,
		"failed_exact": failed_exact,
		"settle_frames": settle_frames,
	}
	if not bool(row.get("ok", false)):
		row["active"] = active
		row["refreshed"] = refreshed
		row["object_resolution"] = object_resolution
		row["expected_deltas"] = expected_deltas
		row["session_equal"] = live_after == control.to_dict()
	return await _finish_case(shell, row)

func _resource_registry_contract() -> Dictionary:
	var production := _load_json(RESOURCE_REGISTRY_PATH)
	var fixture := _load_json(RESOURCE_FIXTURE_PATH)
	var production_items: Array = production.get("items", []) if production.get("items", []) is Array else []
	var fixture_items: Array = fixture.get("items", []) if fixture.get("items", []) is Array else []
	var fixture_by_id := {}
	for fixture_value in fixture_items:
		if fixture_value is Dictionary:
			fixture_by_id[String(fixture_value.get("id", ""))] = fixture_value
	var ordered_ids := []
	var icon_ids := []
	var icon_paths := []
	var fixture_fields := [
		"display_name", "category", "market_tier", "default_visible", "legacy_aliases",
		"canonical_status", "activation_status", "source_readiness", "source_site_family",
		"intended_source_paths", "faction_affinity", "ui_sort", "material_cue", "stockpile",
	]
	var rows := []
	for production_value in production_items:
		if not (production_value is Dictionary):
			return {"ok": false, "failure": "production_row_not_dictionary"}
		var resource: Dictionary = production_value
		var resource_id := String(resource.get("id", ""))
		ordered_ids.append(resource_id)
		var fixture_resource: Dictionary = fixture_by_id.get(resource_id, {})
		var metadata_exact := not fixture_resource.is_empty()
		for field in fixture_fields:
			metadata_exact = metadata_exact and resource.get(field, null) == fixture_resource.get(field, null)
		var expected_icon_id := "resource_icon_%s" % resource_id
		var expected_icon_path := "res://art/economy/runtime/resources/%s.png" % resource_id
		var icon_id := String(resource.get("icon_id", ""))
		var icon_path := String(resource.get("icon_path", ""))
		var icon_image := Image.new()
		var image_error := icon_image.load(icon_path)
		var definition: Dictionary = OverworldRules.resource_definition(resource_id)
		var row := {
			"resource_id": resource_id,
			"ok": (
				metadata_exact
				and icon_id == expected_icon_id
				and icon_path == expected_icon_path
				and image_error == OK
				and icon_image.get_size() == Vector2i(128, 128)
				and icon_image.detect_alpha()
				and definition == resource
				and OverworldRules.resource_icon_path(resource_id) == icon_path
			),
			"metadata_exact": metadata_exact,
			"icon_id": icon_id,
			"icon_path": icon_path,
			"icon_size": icon_image.get_size(),
		}
		rows.append(row)
		icon_ids.append(icon_id)
		icon_paths.append(icon_path)
	var unique_icon_ids := {}
	var unique_icon_paths := {}
	for icon_id in icon_ids:
		unique_icon_ids[String(icon_id)] = true
	for icon_path in icon_paths:
		unique_icon_paths[String(icon_path)] = true
	var all_rows_exact := true
	for row_value in rows:
		all_rows_exact = all_rows_exact and row_value is Dictionary and bool(row_value.get("ok", false))
	return {
		"ok": (
			String(production.get("schema", "")) == "resource_registry_v1"
			and ordered_ids == RESOURCE_IDS
			and all_rows_exact
			and unique_icon_ids.size() == RESOURCE_IDS.size()
			and unique_icon_paths.size() == RESOURCE_IDS.size()
			and OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS == RESOURCE_IDS
			and FileAccess.file_exists("res://art/economy/source/resource_icon_atlas.png")
		),
		"resource_ids": ordered_ids,
		"resource_count": ordered_ids.size(),
		"unique_icon_count": unique_icon_paths.size(),
		"rows": rows,
	}

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func _resource_session():
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var node: Dictionary = {}
	for value in session.overworld.get("resource_nodes", []):
		if value is Dictionary and String(value.get("placement_id", "")) == PLACEMENT_ID:
			node = value
			break
	if node.is_empty():
		return null
	var position := {"x": int(node.get("x", 0)), "y": int(node.get("y", 0))}
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_hero_id:
			heroes[index] = hero.duplicate(true)
	session.overworld["player_heroes"] = heroes
	OverworldRules.refresh_fog_of_war(session)
	return session

func _resource_deltas(before: Dictionary, after_value: Variant, ordered_rows: Array) -> Array:
	var after: Dictionary = after_value if after_value is Dictionary else {}
	var result := []
	for row_value in ordered_rows:
		if not (row_value is Dictionary):
			continue
		var resource_id := String(row_value.get("resource_id", ""))
		var delta := int(after.get(resource_id, 0)) - int(before.get(resource_id, 0))
		if resource_id != "" and delta != 0:
			result.append({"resource_id": resource_id, "before": int(before.get(resource_id, 0)), "after": int(after.get(resource_id, 0)), "delta": delta})
	return result

func _presentation(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.validation_snapshot()
	return (snapshot.get("resource_delta_presentation", {}) as Dictionary).duplicate(true) if snapshot.get("resource_delta_presentation", {}) is Dictionary else {}

func _object_resolution(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.validation_snapshot()
	var viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	return (viewport.get("object_resolution_presentation", {}) as Dictionary).duplicate(true) if viewport.get("object_resolution_presentation", {}) is Dictionary else {}

func _finish_case(shell: Node, result: Dictionary) -> Dictionary:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame
	PresentationAudio.validation_reset()
	return result

func _audio_record_exact(snapshot: Dictionary, record: Dictionary, cue_id: String, asset_path: String, role: String, source: String, duration_msec: int) -> bool:
	return Array(snapshot.get("audio_playback_records", [])) == [record] and String(record.get("cue_id", "")) == cue_id and String(record.get("source", "")) == source and bool(record.get("played", false)) and String(record.get("playback_source", "")) == "imported_wav" and String(record.get("asset_path", "")) == asset_path and String(record.get("role", "")) == role and int(record.get("duration_msec", 0)) == duration_msec and int(record.get("stream_mix_rate", 0)) == 44100 and bool(record.get("stream_stereo", false)) and int(record.get("stream_loop_mode", -1)) == AudioStreamWAV.LOOP_DISABLED and int(record.get("imported_asset_count", 0)) == 1 and int(record.get("generated_fallback_count", -1)) == 0
