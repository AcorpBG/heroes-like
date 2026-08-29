extends Node

const SCENARIO_ID := "river-pass"
const EXPECTED := {
	"encounter_reed_totemists": ["encounter_signature_reed_totemists", "res://art/overworld/runtime/objects/encounters/signatures/reed_totemists.png"],
	"encounter_archive_wardens": ["encounter_signature_archive_wardens", "res://art/overworld/runtime/objects/encounters/signatures/archive_wardens.png"],
	"encounter_relay_pickets": ["encounter_signature_relay_pickets", "res://art/overworld/runtime/objects/encounters/signatures/relay_pickets.png"],
	"encounter_graftroot_wardens": ["encounter_signature_graftroot_wardens", "res://art/overworld/runtime/objects/encounters/signatures/graftroot_wardens.png"],
	"encounter_orevein_exactors": ["encounter_signature_orevein_exactors", "res://art/overworld/runtime/objects/encounters/signatures/orevein_exactors.png"],
	"encounter_bellwake_privateers": ["encounter_signature_bellwake_privateers", "res://art/overworld/runtime/objects/encounters/signatures/bellwake_privateers.png"],
}
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const FIXTURE_POSITIONS := [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var row := await _run_viewport(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			get_window().size = original_window_size
			push_error("Signature encounter landmark runtime failed: %s" % row)
			get_tree().quit(1)
			return
	get_window().size = original_window_size
	print("OVERWORLD_SIGNATURE_ENCOUNTER_LANDMARK_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"encounter_count": EXPECTED.size(),
		"fallback_order": ["commander", "exact_encounter", "faction", "unit", "generic"],
		"viewports": [[1280, 720], [1920, 1080]],
		"rows": rows,
		"save_version": SessionStateStore.SAVE_VERSION,
	}))
	get_tree().quit(0)

func _run_viewport(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
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

	var exact_rows: Array = []
	for encounter_id_value in EXPECTED:
		var encounter_id := String(encounter_id_value)
		var expected: Array = EXPECTED[encounter_id]
		var payload: Dictionary = map_view.call("validation_encounter_presentation_payload", {"encounter_id": encounter_id})
		var exact := String(payload.get("identity_encounter_asset_id", "")) == String(expected[0]) \
			and String(payload.get("identity_encounter_path", "")) == String(expected[1]) \
			and load(String(expected[1])) is Texture2D \
			and bool(payload.get("uses_identity_encounter_sprite", false)) \
			and not bool(payload.get("uses_commander_sprite", true)) \
			and not bool(payload.get("uses_faction_encounter_sprite", true)) \
			and not bool(payload.get("uses_unit_icon_fallback", true)) \
			and not bool(payload.get("uses_encounter_sprite_fallback", true)) \
			and is_equal_approx(float(payload.get("faction_landmark_visible_extent_tiles", 0.0)), 0.82)
		exact_rows.append({"encounter_id": encounter_id, "asset_id": expected[0], "exact": exact})
		if not exact:
			return await _finish(shell, {"ok": false, "failure": "identity", "payload": payload})

	var commander: Dictionary = map_view.call("validation_encounter_presentation_payload", {
		"encounter_id": "encounter_archive_wardens",
		"spawned_by_faction_id": "faction_embercourt",
		"enemy_commander_state": {"roster_hero_id": "hero_embercourt_jorun_beaconscribe", "faction_id": "faction_embercourt"},
	})
	var commander_first := bool(commander.get("uses_commander_sprite", false)) \
		and not bool(commander.get("uses_identity_encounter_sprite", true)) \
		and String(commander.get("identity_encounter_asset_id", "")) == "encounter_signature_archive_wardens"
	var faction: Dictionary = map_view.call("validation_encounter_presentation_payload", {"encounter_id": "encounter_mire_raid"})
	var faction_fallback := String(faction.get("identity_encounter_asset_id", "")) == "" \
		and bool(faction.get("uses_faction_encounter_sprite", false)) \
		and String(faction.get("faction_encounter_asset_id", "")) == "encounter_faction_mireclaw"
	var neutral: Dictionary = map_view.call("validation_encounter_presentation_payload", {"encounter_id": "encounter_roadward_lodge_watch"})
	var neutral_fallback := String(neutral.get("identity_encounter_asset_id", "")) == "" \
		and not bool(neutral.get("uses_faction_encounter_sprite", true)) \
		and bool(neutral.get("uses_unit_icon_fallback", false))
	var unknown: Dictionary = map_view.call("validation_encounter_presentation_payload", {"encounter_id": "encounter_missing_signature_fixture"})
	var generic_fallback := String(unknown.get("identity_encounter_asset_id", "")) == "" \
		and bool(unknown.get("uses_encounter_sprite_fallback", false)) \
		and String(unknown.get("encounter_asset_id", "")) == "hostile_camp"
	if not (commander_first and faction_fallback and neutral_fallback and generic_fallback):
		return await _finish(shell, {"ok": false, "failure": "fallback_order", "commander": commander, "faction": faction, "neutral": neutral, "unknown": unknown})
	if session.to_dict() != authority_before:
		return await _finish(shell, {"ok": false, "failure": "authority_mutated"})
	if not await _capture(viewport_size):
		return await _finish(shell, {"ok": false, "failure": "capture"})
	return await _finish(shell, {
		"ok": true,
		"viewport": [viewport_size.x, viewport_size.y],
		"exact_rows": exact_rows,
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
			"placement_id": "signature_fixture:%s" % encounter_id,
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
	if OS.get_environment("SIGNATURE_ENCOUNTER_CAPTURE") != "1":
		return true
	if DisplayServer.get_name() == "headless":
		return false
	await RenderingServer.frame_post_draw
	var output_dir := ProjectSettings.globalize_path("res://.artifacts/signature_encounter_landmarks/captures")
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		return false
	var path := "%s/signature_encounters_%dx%d.png" % [output_dir, viewport_size.x, viewport_size.y]
	return get_viewport().get_texture().get_image().save_png(path) == OK

func _finish(shell: Node, result: Dictionary) -> Dictionary:
	shell.queue_free()
	await get_tree().process_frame
	return result
