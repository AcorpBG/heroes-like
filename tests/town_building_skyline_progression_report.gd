extends Node

const TownStageViewScript = preload("res://scenes/town/TownStageView.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const CAPTURE_DIR := "res://.artifacts/town_development_scene_progression/captures"
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
const EXPECTED_STAGES := ["village", "developing", "fully_built"]

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
	add_child(fixture)
	var manifest := _validate_manifest()
	var catalog := _validate_all_towns(fixture)
	var live := _validate_live_build_and_save_round_trip(fixture)
	var captures := await _capture_representative_progression(fixture)
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
		"schema": "town_seamless_development_scene_progression_report_v1",
		"manifest": manifest,
		"catalog": catalog,
		"live_build": live_report,
		"captures": captures,
		"save_version": SessionStateStore.SAVE_VERSION,
		"errors": _errors,
	}
	print("TOWN_SEAMLESS_DEVELOPMENT_SCENE_PROGRESSION_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_manifest() -> Dictionary:
	var path := "res://content/town_development_scene_manifest.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_errors.append("Town development scene manifest is missing or invalid")
		return {}
	var manifest: Dictionary = parsed
	var factions: Dictionary = manifest.get("factions", {}) if manifest.get("factions", {}) is Dictionary else {}
	var rows: Array = []
	var hashes: Array = []
	for faction_id_value in EXPECTED_FACTIONS:
		var faction_id := String(faction_id_value)
		var faction: Dictionary = factions.get(faction_id, {}) if factions.get(faction_id, {}) is Dictionary else {}
		var stages: Dictionary = faction.get("stages", {}) if faction.get("stages", {}) is Dictionary else {}
		for stage_id_value in EXPECTED_STAGES:
			var stage_id := String(stage_id_value)
			var stage: Dictionary = stages.get(stage_id, {}) if stages.get(stage_id, {}) is Dictionary else {}
			var runtime_path := String(stage.get("runtime_path", ""))
			var source_path := String(stage.get("source_path", ""))
			var texture: Texture2D = load(runtime_path) as Texture2D if ResourceLoader.exists(runtime_path, "Texture2D") else null
			var runtime_bytes := FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(runtime_path))
			var runtime_hash := str(hash(runtime_bytes))
			var exact: bool = (
				texture != null
				and texture.get_size() == Vector2(1600, 900)
				and runtime_bytes.size() > 1000000
				and FileAccess.file_exists(source_path)
				and String(stage.get("source_sha256", "")).length() == 64
				and String(stage.get("runtime_sha256", "")).length() == 64
			)
			if not exact:
				_errors.append("Development scene asset contract failed for %s %s" % [faction_id, stage_id])
			rows.append({"faction_id": faction_id, "stage_id": stage_id, "path": runtime_path, "bytes": runtime_bytes.size(), "hash": runtime_hash, "exact": exact})
			hashes.append(runtime_hash)
	var exact_count := rows.size() == EXPECTED_FACTIONS.size() * EXPECTED_STAGES.size()
	var unique_count := _unique(hashes).size() == rows.size()
	if not exact_count or not unique_count:
		_errors.append("Development scene catalog must contain eighteen unique runtime paintings")
	return {"ok": exact_count and unique_count and rows.all(func(row): return bool(row.get("exact", false))), "scene_count": rows.size(), "unique_scene_count": _unique(hashes).size(), "rows": rows}

func _validate_all_towns(fixture: Control) -> Dictionary:
	fixture.size = Vector2(1180.0, 640.0)
	var town_rows: Array = []
	for town_id_value in ContentService.get_content_ids(ContentService.TOWNS_PATH):
		var town_id := String(town_id_value)
		var town_template := ContentService.get_town(town_id)
		var faction_id := String(town_template.get("faction_id", ""))
		var catalog_ids := _catalog_ids(town_template)
		var developing_count := mini(catalog_ids.size() - 1, maxi(1, ceili(float(catalog_ids.size()) * TownStageViewScript.DEVELOPMENT_SCENE_DEVELOPING_MIN_RATIO)))
		var village := _summary_for(fixture, town_template, _string_array(town_template.get("starting_building_ids", [])))
		var developing := _summary_for(fixture, town_template, catalog_ids.slice(0, developing_count))
		var complete := _summary_for(fixture, town_template, catalog_ids)
		var exact: bool = (
			faction_id in EXPECTED_FACTIONS
			and String(village.get("stage_id", "")) == "village"
			and String(developing.get("stage_id", "")) == "developing"
			and String(complete.get("stage_id", "")) == "fully_built"
			and bool(village.get("all_stage_textures_loaded", false))
			and bool(developing.get("all_stage_textures_loaded", false))
			and bool(complete.get("all_stage_textures_loaded", false))
			and not bool(village.get("isolated_building_overlay_enabled", true))
			and int(village.get("isolated_building_texture_count", -1)) == 0
			and not bool(village.get("construction_stake_overlay_enabled", true))
		)
		if not exact:
			_errors.append("%s failed seamless development-stage contract" % town_id)
		town_rows.append({
			"town_id": town_id,
			"faction_id": faction_id,
			"catalog_building_count": catalog_ids.size(),
			"village_stage": String(village.get("stage_id", "")),
			"developing_stage": String(developing.get("stage_id", "")),
			"complete_stage": String(complete.get("stage_id", "")),
			"exact": exact,
		})
	return {"ok": town_rows.size() == 32 and town_rows.all(func(row): return bool(row.get("exact", false))), "town_count": town_rows.size(), "rows": town_rows}

func _validate_live_build_and_save_round_trip(fixture: Control) -> Dictionary:
	var session = ScenarioFactory.create_session(LIVE_SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var placement_id := _make_town_player_owned(session, LIVE_TOWN_ID)
	if placement_id == "":
		_errors.append("Live town placement is missing")
		return {}
	var visit: Dictionary = OverworldRules.set_active_town_visit(session, placement_id)
	if not bool(visit.get("ok", false)):
		_errors.append("Could not enter live town: %s" % visit)
		return {}
	_force_abundant_resources(session)
	var town_template := ContentService.get_town(LIVE_TOWN_ID)
	var catalog_ids := _catalog_ids(town_template)
	var developing_count := maxi(1, ceili(float(catalog_ids.size()) * TownStageViewScript.DEVELOPMENT_SCENE_DEVELOPING_MIN_RATIO))
	while _constructed_catalog_count(session, catalog_ids) < developing_count - 1:
		_reset_town_build_day(session, placement_id)
		var preparation_actions := TownRules.get_build_actions(session)
		if preparation_actions.is_empty():
			_errors.append("Could not prepare a valid live construction chain before the developing threshold")
			return {}
		var preparation_id := TownRules.building_id_for_action(String(preparation_actions[0].get("id", "")))
		var preparation_result: Dictionary = TownRules.build_active_town(session, preparation_id)
		if not bool(preparation_result.get("ok", false)):
			_errors.append("Live construction-chain preparation failed for %s: %s" % [preparation_id, preparation_result])
			return {}
	_reset_town_build_day(session, placement_id)
	var actions := TownRules.get_build_actions(session)
	if actions.is_empty():
		_errors.append("Live town has no construction action at the developing threshold")
		return {}
	var building_id := TownRules.building_id_for_action(String(actions[0].get("id", "")))
	fixture.set_town_state(session)
	var before: Dictionary = fixture.validation_town_building_progression_summary()
	var authority_before := _string_array(TownRules.get_active_town(session).get("built_buildings", []))
	var result: Dictionary = TownRules.build_active_town(session, building_id)
	fixture.set_town_state(session)
	var after: Dictionary = fixture.validation_town_building_progression_summary()
	var authority_after := _string_array(TownRules.get_active_town(session).get("built_buildings", []))
	var restored = SessionStateStore.SessionData.new()
	restored.from_dict(session.to_dict())
	OverworldRules.normalize_overworld_state(restored)
	fixture.set_town_state(restored)
	var restored_summary: Dictionary = fixture.validation_town_building_progression_summary()
	var restored_ids := _string_array(TownRules.get_active_town(restored).get("built_buildings", []))
	var exact: bool = (
		bool(result.get("ok", false))
		and building_id != ""
		and String(before.get("stage_id", "")) == "village"
		and String(after.get("stage_id", "")) == "developing"
		and String(restored_summary.get("stage_id", "")) == "developing"
		and String(after.get("stage_path", "")) == String(restored_summary.get("stage_path", ""))
		and authority_after.size() == authority_before.size() + 1
		and authority_after.count(building_id) == 1
		and _same_string_set(restored_ids, authority_after)
		and int(restored.save_version) == SessionStateStore.SAVE_VERSION
		and not bool(after.get("isolated_building_overlay_enabled", true))
	)
	if not exact:
		_errors.append("Live build/save seamless scene transition failed for %s" % building_id)
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
		"stage_before": String(before.get("stage_id", "")),
		"stage_after": String(after.get("stage_id", "")),
		"stage_after_restore": String(restored_summary.get("stage_id", "")),
		"result_ok": bool(result.get("ok", false)),
		"building_id_valid": building_id != "",
		"stage_path_restored_exact": String(after.get("stage_path", "")) == String(restored_summary.get("stage_path", "")),
		"authority_increment_exact": authority_after.size() == authority_before.size() + 1,
		"building_occurrence_count": authority_after.count(building_id),
		"restored_building_set_exact": _same_string_set(restored_ids, authority_after),
		"overlay_disabled": not bool(after.get("isolated_building_overlay_enabled", true)),
		"save_version": int(restored.save_version),
	}

func _capture_representative_progression(fixture: Control) -> Array:
	var town_template := ContentService.get_town(LIVE_TOWN_ID)
	var catalog_ids := _catalog_ids(town_template)
	var developing_count := mini(catalog_ids.size() - 1, maxi(1, ceili(float(catalog_ids.size()) * TownStageViewScript.DEVELOPMENT_SCENE_DEVELOPING_MIN_RATIO)))
	var built_by_stage := {
		"village": _string_array(town_template.get("starting_building_ids", [])),
		"developing": catalog_ids.slice(0, developing_count),
		"fully_built": catalog_ids,
	}
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		get_window().content_scale_size = viewport_size
		get_window().size = viewport_size
		fixture.position = Vector2(24.0, 24.0)
		fixture.size = Vector2(viewport_size) - Vector2(48.0, 48.0)
		for stage_id_value in EXPECTED_STAGES:
			var stage_id := String(stage_id_value)
			fixture.set_precomputed_town_state(null, {
				"town": _town_payload(LIVE_TOWN_ID, built_by_stage[stage_id]),
				"town_template": town_template,
				"faction": ContentService.get_faction(String(town_template.get("faction_id", ""))),
			})
			await get_tree().process_frame
			await get_tree().process_frame
			var capture_path := "%s/%s_%s_%dx%d.png" % [CAPTURE_DIR, LIVE_TOWN_ID, stage_id, viewport_size.x, viewport_size.y]
			var image: Image = get_viewport().get_texture().get_image()
			var capture_ok: bool = image != null and image.save_png(ProjectSettings.globalize_path(capture_path)) == OK
			var summary: Dictionary = fixture.validation_town_building_progression_summary()
			var scenic: Dictionary = fixture.validation_scenic_backdrop_summary()
			var exact: bool = (
				capture_ok
				and String(summary.get("stage_id", "")) == stage_id
				and String(scenic.get("development_stage", "")) == stage_id
				and String(scenic.get("selection_scope", "")) == "faction_development_scene"
				and bool(scenic.get("texture_loaded", false))
				and scenic.get("texture_size", Vector2.ZERO) == Vector2(1600, 900)
			)
			if not exact:
				_errors.append("Development scene capture failed for %s at %s" % [stage_id, viewport_size])
			rows.append({"stage": stage_id, "viewport": [viewport_size.x, viewport_size.y], "capture_path": capture_path, "capture_ok": capture_ok, "exact": exact})
	return rows

func _summary_for(fixture: Control, town_template: Dictionary, built_ids: Array) -> Dictionary:
	var town_id := String(town_template.get("id", ""))
	fixture.set_precomputed_town_state(null, {
		"town": _town_payload(town_id, built_ids),
		"town_template": town_template,
		"faction": ContentService.get_faction(String(town_template.get("faction_id", ""))),
	})
	return fixture.validation_town_building_progression_summary()

func _catalog_ids(town_template: Dictionary) -> Array:
	var result := _string_array(town_template.get("starting_building_ids", []))
	_append_unique(result, town_template.get("buildable_building_ids", []))
	return result

func _town_payload(town_id: String, built_ids: Array) -> Dictionary:
	return {"placement_id": "development_%s" % town_id, "town_id": town_id, "owner": "player", "built_buildings": built_ids.duplicate(), "garrison": [], "available_recruits": {}}

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

func _reset_town_build_day(session, placement_id: String) -> void:
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("placement_id", "")) == placement_id:
			var town: Dictionary = towns[index]
			town["last_build_day"] = 0
			towns[index] = town
			break
	session.overworld["towns"] = towns

func _constructed_catalog_count(session, catalog_ids: Array) -> int:
	var built_ids := _string_array(TownRules.get_active_town(session).get("built_buildings", []))
	var count := 0
	for building_id_value in catalog_ids:
		if String(building_id_value) in built_ids:
			count += 1
	return count

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

func _unique(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if value not in result:
			result.append(value)
	return result

func _same_string_set(first: Array, second: Array) -> bool:
	var first_sorted := _string_array(first)
	var second_sorted := _string_array(second)
	first_sorted.sort()
	second_sorted.sort()
	return first_sorted == second_sorted
