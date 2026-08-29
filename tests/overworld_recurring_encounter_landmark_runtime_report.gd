extends Node

const SCENARIO_ID := "river-pass"
const ATLAS_PATH := "res://art/overworld/runtime/objects/encounters/recurring/recurring_encounter_landmarks_atlas.png"
const EXPECTED := {
	"encounter_beacon_wardens": ["encounter_recurring_beacon_wardens", Rect2(0, 0, 48, 48)],
	"encounter_bridgeward_levies": ["encounter_recurring_bridgeward_levies", Rect2(48, 0, 48, 48)],
	"encounter_aurora_battery": ["encounter_recurring_aurora_battery", Rect2(96, 0, 48, 48)],
	"encounter_bone_ferry_watch": ["encounter_recurring_bone_ferry_watch", Rect2(144, 0, 48, 48)],
	"encounter_charter_guard": ["encounter_recurring_charter_guard", Rect2(192, 0, 48, 48)],
	"encounter_mirror_lancers": ["encounter_recurring_mirror_lancers", Rect2(240, 0, 48, 48)],
}
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const FIXTURE_POSITIONS := [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var original_content_scale_size := get_window().content_scale_size
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var row := await _run_viewport(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			get_window().size = original_window_size
			get_window().content_scale_size = original_content_scale_size
			push_error("Recurring encounter landmark runtime failed: %s" % row)
			get_tree().quit(1)
			return
	get_window().size = original_window_size
	get_window().content_scale_size = original_content_scale_size
	print("OVERWORLD_RECURRING_ENCOUNTER_LANDMARK_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"encounter_count": EXPECTED.size(),
		"atlas_path": ATLAS_PATH,
		"atlas_size": [288, 48],
		"fallback_order": ["commander", "exact_encounter", "faction", "unit", "generic"],
		"viewports": [[1280, 720], [1920, 1080]],
		"rows": rows,
		"save_version": SessionStateStore.SAVE_VERSION,
	}))
	get_tree().quit(0)

func _run_viewport(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	get_window().content_scale_size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	var session = ScenarioFactory.create_session(SCENARIO_ID, "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	_configure_fixture(session)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_encounter_presentation_payload"):
		return await _finish(shell, {"ok": false, "failure": "validation_surface_missing"})
	var authority_before: Dictionary = session.to_dict()
	var manifest: Dictionary = map_view.get("_overworld_art_manifest")
	var object_assets: Dictionary = manifest.get("object_assets", {}) if manifest.get("object_assets", {}) is Dictionary else {}

	var exact_rows: Array = []
	var unique_regions: Array = []
	for encounter_id_value in EXPECTED:
		var encounter_id := String(encounter_id_value)
		var expected: Array = EXPECTED[encounter_id]
		var asset_id := String(expected[0])
		var expected_region: Rect2 = expected[1]
		var payload: Dictionary = map_view.call("validation_encounter_presentation_payload", {"encounter_id": encounter_id})
		var texture = map_view.call("_object_texture_for_asset", asset_id)
		var entry: Dictionary = object_assets.get(asset_id, {}) if object_assets.get(asset_id, {}) is Dictionary else {}
		var exact: bool = String(payload.get("identity_encounter_asset_id", "")) == asset_id \
			and String(payload.get("identity_encounter_path", "")) == ATLAS_PATH \
			and texture is AtlasTexture \
			and texture.region == expected_region \
			and texture.atlas is Texture2D \
			and texture.atlas.resource_path == ATLAS_PATH \
			and texture.atlas.get_size() == Vector2(288, 48) \
			and bool(payload.get("uses_identity_encounter_sprite", false)) \
			and not bool(payload.get("uses_commander_sprite", true)) \
			and not bool(payload.get("uses_faction_encounter_sprite", true)) \
			and not bool(payload.get("uses_unit_icon_fallback", true)) \
			and not bool(payload.get("uses_encounter_sprite_fallback", true)) \
			and not String(entry.get("accessible_description", "")).strip_edges().is_empty() \
			and is_equal_approx(float(payload.get("faction_landmark_visible_extent_tiles", 0.0)), 0.82)
		exact_rows.append({"encounter_id": encounter_id, "asset_id": asset_id, "region": expected_region, "exact": exact})
		if expected_region not in unique_regions:
			unique_regions.append(expected_region)
		if not exact:
			return await _finish(shell, {"ok": false, "failure": "identity", "encounter_id": encounter_id, "payload": payload, "entry": entry})
	if unique_regions.size() != EXPECTED.size():
		return await _finish(shell, {"ok": false, "failure": "duplicate_region", "regions": unique_regions})

	var object_paths: Dictionary = map_view.get("_object_asset_paths")
	var object_regions: Dictionary = map_view.get("_object_asset_regions")
	object_paths["recurring_invalid_region_fixture"] = ATLAS_PATH
	object_regions["recurring_invalid_region_fixture"] = [280, 0, 48, 48]
	var invalid_region_fail_closed := map_view.call("_object_texture_for_asset", "recurring_invalid_region_fixture") == null
	var missing_asset_fail_closed := map_view.call("_object_texture_for_asset", "recurring_missing_asset_fixture") == null
	var commander: Dictionary = map_view.call("validation_encounter_presentation_payload", {
		"encounter_id": "encounter_beacon_wardens",
		"spawned_by_faction_id": "faction_embercourt",
		"enemy_commander_state": {"roster_hero_id": "hero_embercourt_jorun_beaconscribe", "faction_id": "faction_embercourt"},
	})
	var commander_first := bool(commander.get("uses_commander_sprite", false)) \
		and not bool(commander.get("uses_identity_encounter_sprite", true)) \
		and String(commander.get("identity_encounter_asset_id", "")) == "encounter_recurring_beacon_wardens"
	var faction: Dictionary = map_view.call("validation_encounter_presentation_payload", {"encounter_id": "encounter_gate_marshals"})
	var faction_fallback := String(faction.get("identity_encounter_asset_id", "")) == "" \
		and bool(faction.get("uses_faction_encounter_sprite", false)) \
		and String(faction.get("faction_encounter_asset_id", "")) == "encounter_faction_mireclaw"
	var neutral: Dictionary = map_view.call("validation_encounter_presentation_payload", {"encounter_id": "encounter_roadward_lodge_watch"})
	var neutral_fallback := String(neutral.get("identity_encounter_asset_id", "")) == "" \
		and not bool(neutral.get("uses_faction_encounter_sprite", true)) \
		and bool(neutral.get("uses_unit_icon_fallback", false))
	var unknown: Dictionary = map_view.call("validation_encounter_presentation_payload", {"encounter_id": "encounter_missing_recurring_fixture"})
	var generic_fallback := String(unknown.get("identity_encounter_asset_id", "")) == "" \
		and bool(unknown.get("uses_encounter_sprite_fallback", false)) \
		and String(unknown.get("encounter_asset_id", "")) == "hostile_camp"
	if not (invalid_region_fail_closed and missing_asset_fail_closed and commander_first and faction_fallback and neutral_fallback and generic_fallback):
		return await _finish(shell, {"ok": false, "failure": "fallback_order_or_fail_closed", "invalid_region": invalid_region_fail_closed, "missing_asset": missing_asset_fail_closed, "commander": commander, "faction": faction, "neutral": neutral, "unknown": unknown})
	if session.to_dict() != authority_before:
		return await _finish(shell, {"ok": false, "failure": "authority_mutated"})
	if not await _capture(viewport_size):
		return await _finish(shell, {"ok": false, "failure": "capture"})
	return await _finish(shell, {
		"ok": true,
		"viewport": [viewport_size.x, viewport_size.y],
		"exact_rows": exact_rows,
		"invalid_region_fail_closed": invalid_region_fail_closed,
		"missing_asset_fail_closed": missing_asset_fail_closed,
		"commander_first": commander_first,
		"faction_fallback": faction_fallback,
		"neutral_unit_fallback": neutral_fallback,
		"unknown_generic_fallback": generic_fallback,
		"authority_exact": true,
	})

func _configure_fixture(session) -> void:
	var encounters: Array = []
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	var encounter_ids: Array = EXPECTED.keys()
	for index in range(encounter_ids.size()):
		var encounter_id := String(encounter_ids[index])
		var definition := ContentService.get_encounter(encounter_id)
		encounters.append({
			"placement_id": "recurring_fixture:%s" % encounter_id,
			"encounter_id": encounter_id,
			"enemy_group_id": String(definition.get("enemy_group_id", "")),
			"x": FIXTURE_POSITIONS[index].x,
			"y": FIXTURE_POSITIONS[index].y,
		})
	session.overworld["encounters"] = encounters
	session.overworld["resolved_encounters"] = []
	var map_size := OverworldRules.derive_map_size(session)
	var visible_tiles: Array = []
	var explored_tiles: Array = []
	for y in range(map_size.y):
		var visible_row: Array = []
		var explored_row: Array = []
		for _x in range(map_size.x):
			visible_row.append(false)
			explored_row.append(false)
		visible_tiles.append(visible_row)
		explored_tiles.append(explored_row)
	for encounter in encounters:
		visible_tiles[int(encounter.y)][int(encounter.x)] = true
		explored_tiles[int(encounter.y)][int(encounter.x)] = true
	session.overworld["fog"] = {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": encounters.size(),
		"explored_count": encounters.size(),
		"total_tiles": map_size.x * map_size.y,
	}

func _capture(viewport_size: Vector2i) -> bool:
	if OS.get_environment("RECURRING_ENCOUNTER_CAPTURE") != "1":
		return true
	if DisplayServer.get_name() == "headless":
		return false
	await RenderingServer.frame_post_draw
	var output_dir := ProjectSettings.globalize_path("res://.artifacts/recurring_encounter_landmarks/captures")
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		return false
	var path := "%s/recurring_encounters_%dx%d.png" % [output_dir, viewport_size.x, viewport_size.y]
	return get_viewport().get_texture().get_image().save_png(path) == OK

func _finish(shell: Node, result: Dictionary) -> Dictionary:
	shell.queue_free()
	await get_tree().process_frame
	return result
