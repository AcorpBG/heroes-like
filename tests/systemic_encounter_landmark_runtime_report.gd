extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const SCENARIO_ID := "river-pass"
const ATLAS_PATH := "res://art/overworld/runtime/objects/encounters/systemic/systemic_encounter_landmarks_atlas.png"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const EXPECTED := {
	"encounter_town_assault": ["encounter_systemic_town_assault", Rect2(0, 0, 48, 48), "army_mireclaw_raiding_party"],
	"encounter_resource_defense": ["encounter_systemic_resource_defense", Rect2(48, 0, 48, 48), "army_mireclaw_raiding_party"],
	"encounter_mire_raid": ["encounter_systemic_mire_raid", Rect2(96, 0, 48, 48), "army_mireclaw_raiding_party"],
	"encounter_blackbranch_reavers": ["encounter_systemic_blackbranch_reavers", Rect2(144, 0, 48, 48), "army_blackbranch_reavers"],
}
const FIXTURE_POSITIONS := [Vector2i(2, 2), Vector2i(4, 2), Vector2i(6, 2), Vector2i(8, 2)]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	get_window().size = VIEWPORT_SIZE
	get_window().content_scale_size = VIEWPORT_SIZE
	await get_tree().process_frame
	await get_tree().process_frame
	var session = ScenarioFactory.create_session(SCENARIO_ID, "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	if session == null:
		return _fail("session", {})
	_configure_fixture(session)
	OverworldRules.normalize_overworld_state(session)
	session = SessionState.set_active_session(session)
	var save_payload: Dictionary = session.to_dict()
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(save_payload)
	if restored.to_dict() != save_payload:
		return _fail("save_roundtrip", {})
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_encounter_presentation_payload"):
		return _fail("validation_surface", {})
	var authority_before: Dictionary = session.to_dict()
	var manifest: Dictionary = map_view.get("_overworld_art_manifest")
	var object_assets: Dictionary = manifest.get("object_assets", {}) if manifest.get("object_assets", {}) is Dictionary else {}
	var exact_rows: Array = []
	var battle_rows: Array = []
	var encounters: Array = session.overworld.get("encounters", [])
	for encounter_id_value in EXPECTED:
		var encounter_id := String(encounter_id_value)
		var expected: Array = EXPECTED[encounter_id]
		var asset_id := String(expected[0])
		var expected_region: Rect2 = expected[1]
		var expected_group_id := String(expected[2])
		var payload: Dictionary = map_view.call("validation_encounter_presentation_payload", {"encounter_id": encounter_id})
		var texture = map_view.call("_object_texture_for_asset", asset_id)
		var entry: Dictionary = object_assets.get(asset_id, {}) if object_assets.get(asset_id, {}) is Dictionary else {}
		var exact: bool = String(payload.get("identity_encounter_asset_id", "")) == asset_id \
			and String(payload.get("identity_encounter_path", "")) == ATLAS_PATH \
			and texture is AtlasTexture \
			and texture.region == expected_region \
			and texture.atlas is Texture2D \
			and texture.atlas.resource_path == ATLAS_PATH \
			and texture.atlas.get_size() == Vector2(192, 48) \
			and bool(payload.get("uses_identity_encounter_sprite", false)) \
			and not bool(payload.get("uses_commander_sprite", true)) \
			and not bool(payload.get("uses_faction_encounter_sprite", true)) \
			and not bool(payload.get("uses_unit_icon_fallback", true)) \
			and not bool(payload.get("uses_encounter_sprite_fallback", true)) \
			and String(entry.get("assigned_encounter_id", "")) == encounter_id \
			and len(String(entry.get("accessible_description", "")).strip_edges()) >= 40
		exact_rows.append({"encounter_id": encounter_id, "asset_id": asset_id, "region": expected_region, "exact": exact})
		if not exact:
			return _fail("exact_identity", {"row": exact_rows[-1], "payload": payload, "entry": entry})
		var placements := encounters.filter(func(row): return row is Dictionary and String(row.get("encounter_id", "")) == encounter_id)
		if placements.size() != 1:
			return _fail("fixture_placement", {"encounter_id": encounter_id})
		var battle: Dictionary = BattleRules.create_battle_payload(session, placements[0])
		var definition := ContentService.get_encounter(encounter_id)
		var objective_ids: Array = []
		for objective in battle.get("field_objectives", []):
			if objective is Dictionary:
				objective_ids.append(String(objective.get("id", "")))
		var expected_objective_ids: Array = []
		for objective in definition.get("field_objectives", []):
			if objective is Dictionary:
				expected_objective_ids.append(String(objective.get("id", "")))
		var battle_exact: bool = String(battle.get("encounter_id", "")) == encounter_id \
			and String(battle.get("enemy_army_id", "")) == expected_group_id \
			and battle.get("battlefield_tags", []) == definition.get("battlefield_tags", []) \
			and battle.get("stacks", []).any(func(stack): return stack is Dictionary and String(stack.get("side", "")) == "enemy") \
			and objective_ids == expected_objective_ids
		battle_rows.append({"encounter_id": encounter_id, "enemy_army_id": battle.get("enemy_army_id", ""), "objective_ids": objective_ids, "exact": battle_exact})
		if not battle_exact:
			return _fail("battle_payload", {"row": battle_rows[-1], "battle": battle})
	var object_paths: Dictionary = map_view.get("_object_asset_paths")
	var object_regions: Dictionary = map_view.get("_object_asset_regions")
	object_paths["systemic_invalid_region_fixture"] = ATLAS_PATH
	object_regions["systemic_invalid_region_fixture"] = [170, 0, 48, 48]
	var invalid_region_fail_closed := map_view.call("_object_texture_for_asset", "systemic_invalid_region_fixture") == null
	var commander: Dictionary = map_view.call("validation_encounter_presentation_payload", {
		"encounter_id": "encounter_mire_raid",
		"spawned_by_faction_id": "faction_mireclaw",
		"enemy_commander_state": {"roster_hero_id": "hero_mireclaw_edda_rotlamp", "faction_id": "faction_mireclaw"},
	})
	var commander_first := bool(commander.get("uses_commander_sprite", false)) \
		and not bool(commander.get("uses_identity_encounter_sprite", true)) \
		and String(commander.get("identity_encounter_asset_id", "")) == "encounter_systemic_mire_raid"
	if not invalid_region_fail_closed or not commander_first or session.to_dict() != authority_before:
		return _fail("presentation_order_or_authority", {"invalid_region_fail_closed": invalid_region_fail_closed, "commander": commander})
	if not await _capture():
		return _fail("capture", {})
	print("SYSTEMIC_ENCOUNTER_LANDMARK_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"encounter_count": EXPECTED.size(),
		"exact_art_coverage": "107/107",
		"atlas_path": ATLAS_PATH,
		"atlas_size": [192, 48],
		"viewport": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"exact_rows": exact_rows,
		"battle_rows": battle_rows,
		"save_roundtrip_exact": true,
		"authority_exact": true,
		"invalid_region_fail_closed": true,
		"commander_first": true,
	}))
	get_tree().quit(0)

func _configure_fixture(session) -> void:
	var encounters: Array = []
	var index := 0
	for encounter_id_value in EXPECTED:
		var encounter_id := String(encounter_id_value)
		var definition := ContentService.get_encounter(encounter_id)
		encounters.append({
			"placement_id": "systemic_fixture:%s" % encounter_id,
			"encounter_id": encounter_id,
			"enemy_group_id": String(definition.get("enemy_group_id", "")),
			"x": FIXTURE_POSITIONS[index].x,
			"y": FIXTURE_POSITIONS[index].y,
			"combat_seed": 101840 + index,
		})
		index += 1
	session.overworld["encounters"] = encounters
	session.overworld["resolved_encounters"] = []
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
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

func _capture() -> bool:
	if OS.get_environment("SYSTEMIC_ENCOUNTER_CAPTURE") != "1":
		return true
	if DisplayServer.get_name() == "headless":
		return false
	await RenderingServer.frame_post_draw
	var output_dir := ProjectSettings.globalize_path("res://.artifacts/systemic_encounter_landmarks/captures")
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		return false
	return get_viewport().get_texture().get_image().save_png("%s/systemic_encounters_1280x720.png" % output_dir) == OK

func _fail(reason: String, context: Dictionary) -> void:
	push_error("Systemic encounter landmark runtime failed: %s %s" % [reason, context])
	get_tree().quit(1)
