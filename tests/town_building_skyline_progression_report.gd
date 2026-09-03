extends Node

const TownStageViewScript = preload("res://scenes/town/TownStageView.gd")
const TownShellScene = preload("res://scenes/town/TownShell.tscn")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(2048, 1079)]
const CAPTURE_DIR := "res://.artifacts/town_integrated_building_progression/captures"
const LIVE_SCENARIO_ID := "river-pass"
const LIVE_TOWN_ID := "town_riverwatch"
const EXPECTED_FACTIONS := [
	"faction_embercourt",
	"faction_mireclaw",
	"faction_sunvault",
	"faction_thornwake",
	"faction_brasshollow",
	"faction_veilmourn",
]

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
	fixture.position = Vector2(24.0, 24.0)
	fixture.size = Vector2(1232.0, 672.0)
	add_child(fixture)
	await get_tree().process_frame
	var manifest := _validate_layout_manifest()
	var catalog := _validate_all_towns(fixture)
	var live := _validate_live_build_and_save_round_trip(fixture)
	var information := await _validate_building_information(live.get("session"), String(live.get("building_id", "")))
	var captures := await _capture_representative_progression()
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
		"schema": "town_integrated_building_progression_report_v1",
		"manifest": manifest,
		"catalog": catalog,
		"live_build": live_report,
		"building_information": information,
		"captures": captures,
		"save_version": SessionStateStore.SAVE_VERSION,
		"errors": _errors,
	}
	print("TOWN_INTEGRATED_BUILDING_PROGRESSION_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_layout_manifest() -> Dictionary:
	var path := "res://content/town_building_scene_layouts.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_errors.append("Town building scene-layout manifest is missing or invalid")
		return {}
	var manifest: Dictionary = parsed
	var factions: Dictionary = manifest.get("factions", {}) if manifest.get("factions", {}) is Dictionary else {}
	var rows: Array = []
	var total_mapped_ids := 0
	for faction_id_value in EXPECTED_FACTIONS:
		var faction_id := String(faction_id_value)
		var faction: Dictionary = factions.get(faction_id, {}) if factions.get(faction_id, {}) is Dictionary else {}
		var plots: Array = faction.get("plots", []) if faction.get("plots", []) is Array else []
		var mapped_ids: Array = []
		var source_size: Array = faction.get("source_size", []) if faction.get("source_size", []) is Array else []
		var exact: bool = String(faction.get("base_stage", "")) == "village" and source_size.size() == 2 and int(source_size[0]) == 1600 and int(source_size[1]) == 900 and plots.size() >= 20
		for plot_value in plots:
			if not plot_value is Dictionary:
				exact = false
				continue
			var plot: Dictionary = plot_value
			var anchor: Array = plot.get("anchor", []) if plot.get("anchor", []) is Array else []
			var ids: Array = plot.get("building_ids", []) if plot.get("building_ids", []) is Array else []
			exact = exact and String(plot.get("plot_id", "")) != "" and anchor.size() == 2 and float(plot.get("height_ratio", 0.0)) > 0.0 and not ids.is_empty()
			for building_id_value in ids:
				var building_id := String(building_id_value)
				exact = exact and not ContentService.get_building(building_id).is_empty() and building_id not in mapped_ids
				mapped_ids.append(building_id)
		total_mapped_ids += mapped_ids.size()
		if not exact:
			_errors.append("Explicit scene-layout contract failed for %s" % faction_id)
		rows.append({"faction_id": faction_id, "plot_count": plots.size(), "mapped_building_count": mapped_ids.size(), "exact": exact})
	var ok: bool = String(manifest.get("schema_id", "")) == "town_integrated_building_scene_layout_v1" and String(manifest.get("placement_model", "")) == TownStageViewScript.INTEGRATED_BUILDING_MODEL and String(manifest.get("missing_mapping_policy", "")) == "validation_failure_no_runtime_generated_plot" and rows.size() == EXPECTED_FACTIONS.size() and rows.all(func(row): return bool(row.get("exact", false)))
	if not ok:
		_errors.append("Town building scene-layout manifest header or faction coverage failed")
	return {"ok": ok, "faction_count": rows.size(), "total_mapped_ids": total_mapped_ids, "rows": rows}

func _validate_all_towns(fixture: Control) -> Dictionary:
	var town_rows: Array = []
	for town_id_value in ContentService.get_content_ids(ContentService.TOWNS_PATH):
		var town_id := String(town_id_value)
		var town_template := ContentService.get_town(town_id)
		var faction_id := String(town_template.get("faction_id", ""))
		var catalog_ids := _catalog_ids(town_template)
		var starting_ids := _string_array(town_template.get("starting_building_ids", []))
		var starting := _summary_for(fixture, town_template, starting_ids)
		var complete := _summary_for(fixture, town_template, catalog_ids)
		var scenic: Dictionary = fixture.validation_scenic_backdrop_summary()
		var exact: bool = (
			faction_id in EXPECTED_FACTIONS
			and bool(starting.get("manifest_loaded", false))
			and bool(starting.get("mapping_covers_catalog", false))
			and bool(starting.get("all_textures_loaded", false))
			and bool(starting.get("all_source_rects_contained", false))
			and bool(starting.get("all_destination_rects_contained", false))
			and bool(starting.get("all_visible_hotspots_aligned", false))
			and bool(starting.get("visible_covers_authoritative_built", false))
			and bool(starting.get("integrated_building_layers_enabled", false))
			and int(starting.get("visible_building_count", -1)) >= 2
			and bool(complete.get("mapping_covers_catalog", false))
			and bool(complete.get("all_textures_loaded", false))
			and bool(complete.get("all_source_rects_contained", false))
			and bool(complete.get("all_destination_rects_contained", false))
			and bool(complete.get("all_visible_hotspots_aligned", false))
			and int(complete.get("visible_building_count", -1)) == int(complete.get("plot_count", -2))
			and String(starting.get("base_stage_id", "")) == "village"
			and not bool(starting.get("construction_stake_overlay_enabled", true))
			and not bool(starting.get("runtime_generated_plot_fallback_enabled", true))
			and String(scenic.get("development_stage", "")) == "village"
			and String(scenic.get("selection_scope", "")) == "faction_development_scene"
		)
		if not exact:
			_errors.append("%s failed integrated building-scene contract" % town_id)
		town_rows.append({
			"town_id": town_id,
			"faction_id": faction_id,
			"catalog_building_count": catalog_ids.size(),
			"plot_count": int(complete.get("plot_count", 0)),
			"starting_visible_count": int(starting.get("visible_building_count", 0)),
			"complete_visible_count": int(complete.get("visible_building_count", 0)),
			"information_hotspot_count": int(complete.get("visible_information_hotspot_count", 0)),
			"exact": exact,
		})
	return {"ok": town_rows.size() == 32 and town_rows.all(func(row): return bool(row.get("exact", false))), "town_count": town_rows.size(), "rows": town_rows}

func _validate_live_build_and_save_round_trip(fixture: Control) -> Dictionary:
	var session = _session_for_town_progression(LIVE_TOWN_ID, [])
	if session == null:
		_errors.append("Could not create live Town construction fixture")
		return {}
	_force_abundant_resources(session)
	var town_before := TownRules.get_active_town(session)
	var placement_id := String(town_before.get("placement_id", ""))
	var authority_before := _string_array(town_before.get("built_buildings", []))
	var actions := TownRules.get_build_actions(session)
	if actions.is_empty():
		_errors.append("Live town has no construction action")
		return {"session": session}
	var building_id := TownRules.building_id_for_action(String(actions[0].get("id", "")))
	var action_cost: Dictionary = actions[0].get("cost", {}) if actions[0].get("cost", {}) is Dictionary else {}
	var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	fixture.set_town_state(session)
	var before: Dictionary = fixture.validation_town_building_progression_summary()
	var result: Dictionary = TownRules.build_active_town(session, building_id)
	fixture.set_town_state(session)
	var after: Dictionary = fixture.validation_town_building_progression_summary()
	var authority_after := _string_array(TownRules.get_active_town(session).get("built_buildings", []))
	var resources_after: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var restored = SessionStateStore.SessionData.new()
	restored.from_dict(session.to_dict())
	OverworldRules.normalize_overworld_state(restored)
	fixture.set_town_state(restored)
	var restored_summary: Dictionary = fixture.validation_town_building_progression_summary()
	var restored_ids := _string_array(TownRules.get_active_town(restored).get("built_buildings", []))
	var exact_cost := true
	for resource_id_value in action_cost:
		var resource_id := String(resource_id_value)
		exact_cost = exact_cost and int(resources_after.get(resource_id, 0)) == int(resources_before.get(resource_id, 0)) - int(action_cost.get(resource_id, 0))
	var exact: bool = (
		bool(result.get("ok", false))
		and building_id != ""
		and authority_after.size() == authority_before.size() + 1
		and authority_after.count(building_id) == 1
		and building_id in Array(after.get("visible_building_ids", []))
		and building_id not in Array(before.get("visible_building_ids", []))
		and bool(after.get("all_visible_hotspots_aligned", false))
		and bool(restored_summary.get("all_visible_hotspots_aligned", false))
		and Array(after.get("visible_building_ids", [])) == Array(restored_summary.get("visible_building_ids", []))
		and _same_string_set(restored_ids, authority_after)
		and exact_cost
		and int(restored.save_version) == SessionStateStore.SAVE_VERSION
		and String(after.get("base_stage_path", "")) == String(before.get("base_stage_path", ""))
	)
	if not exact:
		_errors.append("Live build/save integrated scene transition failed for %s" % building_id)
	SessionState.set_active_session(session)
	return {
		"ok": exact,
		"session": session,
		"restored_session": restored,
		"town_id": LIVE_TOWN_ID,
		"placement_id": placement_id,
		"building_id": building_id,
		"authority_before_count": authority_before.size(),
		"authority_after_count": authority_after.size(),
		"visible_before_count": int(before.get("visible_building_count", 0)),
		"visible_after_count": int(after.get("visible_building_count", 0)),
		"result_ok": bool(result.get("ok", false)),
		"cost_exact": exact_cost,
		"restored_building_set_exact": _same_string_set(restored_ids, authority_after),
		"restored_visible_set_exact": Array(after.get("visible_building_ids", [])) == Array(restored_summary.get("visible_building_ids", [])),
		"hotspot_aligned": bool(after.get("all_visible_hotspots_aligned", false)),
		"save_version": int(restored.save_version),
	}

func _validate_building_information(session, building_id: String) -> Dictionary:
	if session == null or building_id == "":
		_errors.append("Building information fixture is missing")
		return {}
	SessionState.set_active_session(session)
	var shell = TownShellScene.instantiate()
	shell.size = Vector2(1280.0, 720.0)
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var snapshot: Dictionary = shell.call("validation_activate_building_information", building_id)
	await get_tree().process_frame
	snapshot = shell.call("validation_building_information_snapshot", building_id)
	var hotspot: Dictionary = snapshot.get("hotspot", {}) if snapshot.get("hotspot", {}) is Dictionary else {}
	var exact: bool = (
		bool(snapshot.get("open", false))
		and String(snapshot.get("mode", "")) == "building_info"
		and String(snapshot.get("title", "")) == String(snapshot.get("expected_title", ""))
		and String(snapshot.get("description", "")) == String(snapshot.get("expected_description", ""))
		and String(snapshot.get("description", "")) != ""
		and String(snapshot.get("effects", "")).contains("Effects:")
		and bool(snapshot.get("icon_loaded", false))
		and bool(snapshot.get("surface_visible", false))
		and bool(snapshot.get("read_only", false))
		and bool(hotspot.get("aligned", false))
		and String(hotspot.get("accessibility_name", "")) != ""
	)
	if not exact:
		_errors.append("Building information route failed for %s" % building_id)
	shell.queue_free()
	await get_tree().process_frame
	return {"ok": exact, "building_id": building_id, "snapshot": snapshot}

func _capture_representative_progression() -> Array:
	var town_template := ContentService.get_town(LIVE_TOWN_ID)
	var catalog_ids := _catalog_ids(town_template)
	var starting_ids := _string_array(town_template.get("starting_building_ids", []))
	var built_by_stage := {
		"sparse": starting_ids,
		"developing": catalog_ids.slice(0, maxi(starting_ids.size() + 1, int(catalog_ids.size() * 0.55))),
		"developed": catalog_ids,
	}
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		get_window().content_scale_size = viewport_size
		get_window().size = viewport_size
		for stage_id_value in ["sparse", "developing", "developed"]:
			var stage_id := String(stage_id_value)
			var session = _session_for_town_progression(LIVE_TOWN_ID, built_by_stage[stage_id])
			SessionState.set_active_session(session)
			var shell = TownShellScene.instantiate()
			add_child(shell)
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame
			var capture_path := "%s/%s_%s_%dx%d.png" % [CAPTURE_DIR, LIVE_TOWN_ID, stage_id, viewport_size.x, viewport_size.y]
			var image: Image = get_viewport().get_texture().get_image()
			var capture_ok: bool = image != null and image.save_png(ProjectSettings.globalize_path(capture_path)) == OK
			var stage_view: Control = shell.get_node("%TownStage")
			var summary: Dictionary = stage_view.validation_town_building_progression_summary()
			var backdrop: Dictionary = stage_view.validation_scenic_backdrop_summary()
			var layout: Dictionary = shell.call("validation_owner_town_layout_snapshot")
			var exact: bool = capture_ok and bool(summary.get("mapping_covers_catalog", false)) and bool(summary.get("all_destination_rects_contained", false)) and bool(summary.get("all_visible_hotspots_aligned", false)) and bool(layout.get("sidebar_contained", false)) and bool(layout.get("footer_contained", false)) and bool(layout.get("header_single_row", false))
			if not exact:
				_errors.append("Integrated Town capture failed for %s at %s" % [stage_id, viewport_size])
			rows.append({"stage": stage_id, "viewport": [viewport_size.x, viewport_size.y], "capture_path": capture_path, "capture_ok": capture_ok, "visible_building_count": int(summary.get("visible_building_count", 0)), "backdrop": backdrop, "exact": exact})
			shell.queue_free()
			await get_tree().process_frame
	return rows

func _summary_for(fixture: Control, town_template: Dictionary, built_ids: Array) -> Dictionary:
	var town_id := String(town_template.get("id", ""))
	fixture.set_precomputed_town_state(null, {
		"town": _town_payload(town_id, built_ids),
		"town_template": town_template,
		"faction": ContentService.get_faction(String(town_template.get("faction_id", ""))),
	})
	return fixture.validation_town_building_progression_summary()

func _session_for_town_progression(town_id: String, built_ids: Array):
	var session = ScenarioFactory.create_session(LIVE_SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var placement_id := _make_town_player_owned(session, town_id)
	if placement_id == "":
		return null
	if not built_ids.is_empty():
		_set_town_built_ids(session, placement_id, built_ids)
	var visit: Dictionary = OverworldRules.set_active_town_visit(session, placement_id)
	return session if bool(visit.get("ok", false)) else null

func _catalog_ids(town_template: Dictionary) -> Array:
	var result := _string_array(town_template.get("starting_building_ids", []))
	_append_unique(result, town_template.get("buildable_building_ids", []))
	return result

func _town_payload(town_id: String, built_ids: Array) -> Dictionary:
	return {"placement_id": "integrated_%s" % town_id, "town_id": town_id, "owner": "player", "built_buildings": built_ids.duplicate(), "garrison": [], "available_recruits": {}}

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

func _set_town_built_ids(session, placement_id: String, built_ids: Array) -> void:
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("placement_id", "")) == placement_id:
			var town: Dictionary = towns[index]
			town["built_buildings"] = built_ids.duplicate()
			towns[index] = town
			break
	session.overworld["towns"] = towns

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

func _same_string_set(first: Array, second: Array) -> bool:
	var first_sorted := _string_array(first)
	var second_sorted := _string_array(second)
	first_sorted.sort()
	second_sorted.sort()
	return first_sorted == second_sorted
