extends Node

const TownStageViewScript = preload("res://scenes/town/TownStageView.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const CAPTURE_DIR := "res://.artifacts/town_building_skyline_progression/captures"
const LIVE_SCENARIO_ID := "river-pass"
const LIVE_TOWN_ID := "town_riverwatch"

var _errors: Array = []
var _original_window_size := Vector2i.ZERO
var _original_content_scale_size := Vector2i.ZERO

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_original_window_size = get_window().size
	_original_content_scale_size = get_window().content_scale_size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	var fixture = TownStageViewScript.new()
	fixture.position = Vector2(40.0, 40.0)
	add_child(fixture)
	var catalog := _validate_all_towns(fixture)
	var live := _validate_live_build_and_save_round_trip(fixture)
	var captures := await _capture_representative_progression(fixture, live)
	var live_report := live.duplicate(true)
	live_report.erase("session")
	live_report.erase("restored_session")
	fixture.queue_free()
	await get_tree().process_frame
	get_window().size = _original_window_size
	get_window().content_scale_size = _original_content_scale_size
	SessionState.reset_session()
	var report := {
		"ok": _errors.is_empty(),
		"schema": "town_building_skyline_progression_report_v1",
		"catalog": catalog,
		"live_build": live_report,
		"captures": captures,
		"save_version": SessionStateStore.SAVE_VERSION,
		"errors": _errors,
	}
	print("TOWN_BUILDING_SKYLINE_PROGRESSION_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_all_towns(fixture: Control) -> Dictionary:
	fixture.size = Vector2(1180.0, 640.0)
	var town_rows: Array = []
	var individual_visibility_count := 0
	var authored_town_ids := ContentService.get_content_ids(ContentService.TOWNS_PATH)
	for town_id_value in authored_town_ids:
		var town_id := String(town_id_value)
		var town_template := ContentService.get_town(town_id)
		var faction_id := String(town_template.get("faction_id", ""))
		var starting_ids := _string_array(town_template.get("starting_building_ids", []))
		var catalog_ids := starting_ids.duplicate()
		_append_unique(catalog_ids, town_template.get("buildable_building_ids", []))
		var initial := _summary_for(fixture, town_template, starting_ids)
		var complete := _summary_for(fixture, town_template, catalog_ids)
		var individual_exact := true
		for building_id_value in catalog_ids:
			var building_id := String(building_id_value)
			var individual := _summary_for(fixture, town_template, [building_id])
			if building_id not in Array(individual.get("visible_building_ids", [])):
				individual_exact = false
				_errors.append("%s does not show completed %s in its stable plot" % [town_id, building_id])
			else:
				individual_visibility_count += 1
		var exact := (
			not town_template.is_empty()
			and int(initial.get("catalog_building_count", 0)) == catalog_ids.size()
			and int(initial.get("plot_count", 0)) > 0
			and int(initial.get("unbuilt_plot_count", 0)) > 0
			and int(complete.get("unbuilt_plot_count", -1)) == 0
			and int(complete.get("visible_building_count", 0)) == int(complete.get("plot_count", -1))
			and bool(initial.get("all_textures_loaded", false))
			and bool(complete.get("all_textures_loaded", false))
			and bool(initial.get("all_contained", false))
			and bool(complete.get("all_contained", false))
			and bool(initial.get("visible_covers_authoritative_built", false))
			and bool(complete.get("visible_covers_authoritative_built", false))
			and individual_exact
		)
		if not exact:
			_errors.append("%s failed initial/complete skyline contract" % town_id)
		town_rows.append({
			"town_id": town_id,
			"faction_id": faction_id,
			"catalog_building_count": catalog_ids.size(),
			"plot_count": int(complete.get("plot_count", 0)),
			"initial_visible_count": int(initial.get("visible_building_count", 0)),
			"initial_unbuilt_count": int(initial.get("unbuilt_plot_count", 0)),
			"complete_visible_count": int(complete.get("visible_building_count", 0)),
			"individual_exact": individual_exact,
			"exact": exact,
		})
	return {
		"ok": town_rows.size() == 32 and town_rows.all(func(row): return bool(row.get("exact", false))),
		"town_count": town_rows.size(),
		"individual_building_visibility_count": individual_visibility_count,
		"rows": town_rows,
	}

func _validate_live_build_and_save_round_trip(fixture: Control) -> Dictionary:
	var session = ScenarioFactory.create_session(LIVE_SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var placement_id := _make_town_player_owned(session, LIVE_TOWN_ID)
	if placement_id == "":
		_errors.append("Live skyline town placement is missing")
		return {}
	var visit: Dictionary = OverworldRules.set_active_town_visit(session, placement_id)
	if not bool(visit.get("ok", false)):
		_errors.append("Could not enter live skyline town: %s" % visit)
		return {}
	_force_abundant_resources(session)
	fixture.set_town_state(session)
	var before: Dictionary = fixture.validation_town_building_progression_summary()
	var actions := TownRules.get_build_actions(session)
	if actions.is_empty():
		_errors.append("Live skyline town has no affordable construction action")
		return {}
	var action: Dictionary = actions[0]
	var building_id := TownRules.building_id_for_action(String(action.get("id", "")))
	var before_plot := _plot_for_building(before, building_id)
	var before_visible := building_id in Array(before.get("visible_building_ids", []))
	var authority_before := _string_array(TownRules.get_active_town(session).get("built_buildings", []))
	var result: Dictionary = TownRules.build_active_town(session, building_id)
	fixture.set_town_state(session)
	var after: Dictionary = fixture.validation_town_building_progression_summary()
	var after_plot := _plot_for_building(after, building_id)
	var authority_after := _string_array(TownRules.get_active_town(session).get("built_buildings", []))
	var restored = SessionStateStore.SessionData.new()
	restored.from_dict(session.to_dict())
	OverworldRules.normalize_overworld_state(restored)
	fixture.set_town_state(restored)
	var restored_summary: Dictionary = fixture.validation_town_building_progression_summary()
	var restored_ids := _string_array(TownRules.get_active_town(restored).get("built_buildings", []))
	var exact := (
		bool(result.get("ok", false))
		and building_id != ""
		and not before_visible
		and building_id in Array(after.get("visible_building_ids", []))
		and building_id in Array(restored_summary.get("visible_building_ids", []))
		and authority_after.size() == authority_before.size() + 1
		and authority_after.count(building_id) == 1
		and restored_ids == authority_after
		and before_plot != ""
		and before_plot == after_plot
		and int(restored.save_version) == SessionStateStore.SAVE_VERSION
		and bool(after.get("all_contained", false))
		and bool(restored_summary.get("all_contained", false))
	)
	if not exact:
		_errors.append("Live build/save skyline contract failed for %s" % building_id)
	SessionState.set_active_session(session)
	return {
		"ok": exact,
		"session": session,
		"restored_session": restored,
		"town_id": LIVE_TOWN_ID,
		"placement_id": placement_id,
		"building_id": building_id,
		"building_name": String(ContentService.get_building(building_id).get("name", building_id)),
		"plot_id": after_plot,
		"authority_before_count": authority_before.size(),
		"authority_after_count": authority_after.size(),
		"visible_before": before_visible,
		"visible_after": building_id in Array(after.get("visible_building_ids", [])),
		"visible_after_restore": building_id in Array(restored_summary.get("visible_building_ids", [])),
		"save_version": int(restored.save_version),
	}

func _capture_representative_progression(fixture: Control, live: Dictionary) -> Array:
	var session = live.get("session")
	if session == null:
		return []
	var town_template := ContentService.get_town(LIVE_TOWN_ID)
	var starting_ids := _string_array(town_template.get("starting_building_ids", []))
	var complete_ids := starting_ids.duplicate()
	_append_unique(complete_ids, town_template.get("buildable_building_ids", []))
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		get_window().content_scale_size = viewport_size
		get_window().size = viewport_size
		fixture.position = Vector2(24.0, 24.0)
		fixture.size = Vector2(viewport_size) - Vector2(48.0, 48.0)
		for state_id in ["unbuilt", "built", "complete"]:
			var built_ids := starting_ids
			if state_id == "built":
				built_ids = _string_array(TownRules.get_active_town(session).get("built_buildings", []))
			elif state_id == "complete":
				built_ids = complete_ids
			fixture.set_precomputed_town_state(null, {
				"town": _town_payload(LIVE_TOWN_ID, built_ids),
				"town_template": town_template,
				"faction": ContentService.get_faction(String(town_template.get("faction_id", ""))),
			})
			await get_tree().process_frame
			await get_tree().process_frame
			var capture_path := "%s/%s_%s_%dx%d.png" % [CAPTURE_DIR, LIVE_TOWN_ID, state_id, viewport_size.x, viewport_size.y]
			var image: Image = get_viewport().get_texture().get_image()
			var capture_ok := image != null and image.save_png(ProjectSettings.globalize_path(capture_path)) == OK
			var summary: Dictionary = fixture.validation_town_building_progression_summary()
			var exact := capture_ok and bool(summary.get("all_contained", false)) and bool(summary.get("all_textures_loaded", false))
			if not exact:
				_errors.append("Skyline capture failed for %s at %s" % [state_id, viewport_size])
			rows.append({
				"state": state_id,
				"viewport": [viewport_size.x, viewport_size.y],
				"capture_path": capture_path,
				"capture_ok": capture_ok,
				"visible_count": int(summary.get("visible_building_count", 0)),
				"unbuilt_count": int(summary.get("unbuilt_plot_count", 0)),
				"exact": exact,
			})
	return rows

func _summary_for(fixture: Control, town_template: Dictionary, built_ids: Array) -> Dictionary:
	var town_id := String(town_template.get("id", ""))
	fixture.set_precomputed_town_state(null, {
		"town": _town_payload(town_id, built_ids),
		"town_template": town_template,
		"faction": ContentService.get_faction(String(town_template.get("faction_id", ""))),
	})
	return fixture.validation_town_building_progression_summary()

func _town_payload(town_id: String, built_ids: Array) -> Dictionary:
	return {
		"placement_id": "skyline_%s" % town_id,
		"town_id": town_id,
		"owner": "player",
		"built_buildings": built_ids.duplicate(),
		"garrison": [],
		"available_recruits": {},
	}

func _plot_for_building(summary: Dictionary, building_id: String) -> String:
	for entry_value in Array(summary.get("entries", [])):
		if entry_value is Dictionary and building_id in Array(entry_value.get("variant_ids", [])):
			return String(entry_value.get("plot_id", ""))
	return ""

func _make_town_player_owned(session, town_id: String) -> String:
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("town_id", "")) == town_id:
			var town: Dictionary = towns[index]
			town["owner"] = "player"
			town["last_build_day"] = 0
			towns[index] = town
			session.overworld["towns"] = towns
			return String(town.get("placement_id", ""))
	return ""

func _force_abundant_resources(session) -> void:
	var resources: Dictionary = session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}
	for resource_id in ContentService.get_content_ids(ContentService.RESOURCES_PATH):
		resources[String(resource_id)] = 999999
	session.overworld["resources"] = resources

func _string_array(values: Variant) -> Array:
	var result: Array = []
	if values is Array:
		for value in values:
			var normalized := String(value).strip_edges()
			if normalized != "" and normalized not in result:
				result.append(normalized)
	return result

func _append_unique(target: Array, values: Variant) -> void:
	if not values is Array:
		return
	for value in values:
		var normalized := String(value).strip_edges()
		if normalized != "" and normalized not in target:
			target.append(normalized)
