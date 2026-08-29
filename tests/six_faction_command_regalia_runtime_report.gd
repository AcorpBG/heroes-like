extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "SIX_FACTION_COMMAND_REGALIA_RUNTIME_REPORT"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const CASES := {
	"artifact_lockflame_writ_banner": {"faction_id": "faction_embercourt", "scenario_id": "causeway-stand", "placement_id": "causeway_pennon", "x": 5, "y": 3, "bonuses": {"battle_defense": 1, "battle_initiative": 1}},
	"artifact_mirechain_hunt_totem": {"faction_id": "faction_mireclaw", "scenario_id": "bogbound-oath", "placement_id": "bogbound_pennon", "x": 5, "y": 3, "bonuses": {"battle_attack": 1, "battle_initiative": 1}},
	"artifact_zenith_prism_pennon": {"faction_id": "faction_sunvault", "scenario_id": "prismhearth-watch", "placement_id": "halo_pennon", "x": 5, "y": 3, "bonuses": {"battle_initiative": 1, "battle_spell_resistance_pct": 5}},
	"artifact_briarcrown_covenant_standard": {"faction_id": "faction_thornwake", "scenario_id": "mireford-skirmish", "placement_id": "bridge_pennon", "x": 5, "y": 3, "bonuses": {"battle_defense": 1, "overworld_movement": 1}},
	"artifact_redline_warrant_gonfalon": {"faction_id": "faction_brasshollow", "scenario_id": "orevein-contract", "placement_id": "riverwatch_warcrest_pennon", "x": 9, "y": 4, "bonuses": {"battle_attack": 1, "battle_defense": 1}},
	"artifact_wakebell_mourning_ensign": {"faction_id": "faction_veilmourn", "scenario_id": "bellwake-wreck-claim", "placement_id": "bellwake_waymark_compass", "x": 3, "y": 1, "bonuses": {"battle_initiative": 1, "scouting_radius": 1}},
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var content_rows: Array = []
	for artifact_id in CASES:
		var row := _runtime_case(artifact_id, CASES[artifact_id])
		content_rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Command-regalia runtime case failed: %s" % JSON.stringify(row), original_window_size)
			return
	if ArtifactRules.artifact_icon_path("artifact_missing_command_regalia") != "":
		_fail("Unknown command-regalia inventory art did not fail closed.", original_window_size)
		return

	var town_rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _town_management_case(viewport_size)
		town_rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Command-regalia Town management case failed: %s" % JSON.stringify(row), original_window_size)
			return

	get_window().size = original_window_size
	await get_tree().process_frame
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"artifact_count": CASES.size(),
		"distinct_faction_count": 6,
		"save_version": SessionDataScript.SAVE_VERSION,
		"content_rows": content_rows,
		"town_rows": town_rows,
		"unknown_inventory_art_fails_closed": true,
	})])
	get_tree().quit(0)

func _runtime_case(artifact_id: String, expected: Dictionary) -> Dictionary:
	var artifact := ContentService.get_artifact(artifact_id)
	var short_id := artifact_id.trim_prefix("artifact_")
	var icon_path := "res://art/artifacts/runtime/%s.png" % short_id
	var field_path := "res://art/overworld/runtime/objects/artifacts/%s.png" % short_id
	var icon := load(icon_path) as Texture2D if ResourceLoader.exists(icon_path, "Texture2D") else null
	var field := load(field_path) as Texture2D if ResourceLoader.exists(field_path, "Texture2D") else null
	var field_image := field.get_image() if field != null else null
	var art_exact: bool = icon != null and icon.get_size() == Vector2(128, 128) \
		and field != null and field.get_size() == Vector2(512, 512) \
		and field_image != null and field_image.detect_alpha() != Image.ALPHA_NONE \
		and field_image.get_pixel(0, 0).a <= 0.01 and field_image.get_pixel(511, 0).a <= 0.01 \
		and field_image.get_pixel(0, 511).a <= 0.01 and field_image.get_pixel(511, 511).a <= 0.01
	var artifact_bonuses: Dictionary = artifact.get("bonuses", {}) if artifact.get("bonuses", {}) is Dictionary else {}
	var expected_bonuses: Dictionary = expected.get("bonuses", {}) if expected.get("bonuses", {}) is Dictionary else {}
	var authored_bonuses_exact: bool = artifact_bonuses.size() == expected_bonuses.size()
	for bonus_key in expected_bonuses:
		authored_bonuses_exact = authored_bonuses_exact and int(artifact_bonuses.get(bonus_key, 0)) == int(expected_bonuses.get(bonus_key, 0))
	var taxonomy_exact: bool = not artifact.is_empty() \
		and String(artifact.get("slot", "")) == "banner" \
		and String(artifact.get("rarity", "")) == "uncommon" \
		and artifact.get("faction_affinity", []) == [String(expected.get("faction_id", ""))] \
		and authored_bonuses_exact \
		and String(artifact.get("ui", {}).get("icon_path", "")) == icon_path

	var session = ScenarioFactory.create_session(String(expected.get("scenario_id", "")), "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var node := _artifact_node(session, String(expected.get("placement_id", "")))
	var placement_exact: bool = String(node.get("placement_id", "")) == String(expected.get("placement_id", "")) \
		and String(node.get("artifact_id", "")) == artifact_id \
		and int(node.get("x", -1)) == int(expected.get("x", -1)) \
		and int(node.get("y", -1)) == int(expected.get("y", -1)) \
		and not bool(node.get("collected", true))
	if not placement_exact:
		return {"ok": false, "artifact_id": artifact_id, "failure": "placement", "node": node}

	var ai_breakdown := EnemyAdventureRules.artifact_target_valuation_breakdown(
		session,
		{"faction_id": expected.get("faction_id", "")},
		node,
		Vector2i(int(expected.get("x", 0)), int(expected.get("y", 0))),
		String(expected.get("faction_id", "")),
		0
	)
	var ai_exact: bool = int(ai_breakdown.get("final_priority", 0)) > 0 \
		and bool(ai_breakdown.get("faction_affinity_match", false)) \
		and not (ai_breakdown.get("runtime_surfaces", []) as Array).is_empty()

	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	hero["artifacts"] = ArtifactRules.normalize_hero_artifacts({})
	session.overworld["hero"] = hero
	_sync_player_hero(session, hero)
	_set_active_hero_position(session, Vector2i(int(expected.get("x", 0)), int(expected.get("y", 0))))
	var collect := OverworldRules.collect_active_artifact(session)
	var collected_node := _artifact_node(session, String(expected.get("placement_id", "")))
	var equipped_hero: Dictionary = session.overworld.get("hero", {})
	var location := ArtifactRules.locate_artifact(equipped_hero, artifact_id)
	var aggregate := ArtifactRules.aggregate_bonuses(equipped_hero)
	var bonuses_exact: bool = true
	for bonus_key in expected.get("bonuses", {}):
		bonuses_exact = bonuses_exact and int(aggregate.get(bonus_key, 0)) == int(expected.get("bonuses", {}).get(bonus_key, 0))
	var collect_exact: bool = bool(collect.get("ok", false)) \
		and String(location.get("location", "")) == "equipped" \
		and String(location.get("slot", "")) == "banner" \
		and bool(collected_node.get("collected", false)) \
		and bonuses_exact

	var payload: Dictionary = session.to_dict()
	var restored = SessionDataScript.SessionData.new()
	restored.from_dict(payload.duplicate(true))
	var save_exact: bool = int(payload.get("save_version", -1)) == 9 \
		and restored.to_dict() == payload \
		and String(ArtifactRules.locate_artifact(restored.overworld.get("hero", {}), artifact_id).get("location", "")) == "equipped"
	return {
		"ok": art_exact and taxonomy_exact and placement_exact and ai_exact and collect_exact and save_exact,
		"artifact_id": artifact_id,
		"faction_id": expected.get("faction_id", ""),
		"scenario_id": expected.get("scenario_id", ""),
		"placement_id": expected.get("placement_id", ""),
		"art_exact": art_exact,
		"taxonomy_exact": taxonomy_exact,
		"authored_bonuses_exact": authored_bonuses_exact,
		"ai_priority_positive": ai_exact,
		"collected_and_equipped": collect_exact,
		"collect_message": collect.get("message", ""),
		"equipped_location": location,
		"aggregate_bonuses": aggregate,
		"save_round_trip_exact": save_exact,
	}

func _artifact_node(session, placement_id: String) -> Dictionary:
	for node_value in session.overworld.get("artifact_nodes", []):
		if node_value is Dictionary and String(node_value.get("placement_id", "")) == placement_id:
			return node_value.duplicate(true)
	return {}

func _town_management_case(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	hero["artifacts"] = ArtifactRules.normalize_hero_artifacts({"inventory": CASES.keys()})
	session.overworld["hero"] = hero
	_sync_player_hero(session, hero)
	_move_to_first_player_town(session)
	SessionState.set_active_session(session)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var tabs := shell.get_node_or_null("%ManagementTabs") as TabContainer
	var container := shell.get_node_or_null("%ArtifactActions") as Container
	if tabs == null or container == null:
		return await _finish_town_case(shell, {"ok": false, "failure": "management_surface_missing"})
	var narrow_toggle: Dictionary = shell.call("validation_toggle_narrow_town_orders") if shell.has_method("validation_toggle_narrow_town_orders") else {}
	tabs.current_tab = 4
	await get_tree().process_frame
	await get_tree().process_frame
	var icon_paths: Array = []
	var focusable_count := 0
	var contained_count := 0
	var viewport_rect := get_viewport().get_visible_rect()
	for child in container.get_children():
		if child is Button and child.icon != null:
			icon_paths.append(child.icon.resource_path)
			if child.focus_mode != Control.FOCUS_NONE and child.tooltip_text.strip_edges() != "":
				focusable_count += 1
			if child.is_visible_in_tree() and viewport_rect.encloses(child.get_global_rect()):
				contained_count += 1
	icon_paths.sort()
	var expected_paths: Array = []
	for artifact_id in CASES:
		expected_paths.append("res://art/artifacts/runtime/%s.png" % String(artifact_id).trim_prefix("artifact_"))
	expected_paths.sort()
	var capture_path := await _capture_if_requested(viewport_size)
	var row := {
		"ok": icon_paths == expected_paths and focusable_count == CASES.size() and contained_count > 0 and capture_path != "capture_failed",
		"viewport": [viewport_size.x, viewport_size.y],
		"icon_paths": icon_paths,
		"focusable_with_tooltip_count": focusable_count,
		"contained_count": contained_count,
		"narrow_toggle": narrow_toggle,
		"capture_path": capture_path,
	}
	return await _finish_town_case(shell, row)

func _sync_player_hero(session, hero: Dictionary) -> void:
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_hero_id:
			heroes[index] = hero.duplicate(true)
			break
	session.overworld["player_heroes"] = heroes

func _move_to_first_player_town(session) -> void:
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary) or String(town_value.get("owner", "")) != "player":
			continue
		var position := {"x": int(town_value.get("x", 0)), "y": int(town_value.get("y", 0))}
		session.overworld["hero_position"] = position.duplicate(true)
		var hero: Dictionary = session.overworld.get("hero", {})
		hero["position"] = position.duplicate(true)
		session.overworld["hero"] = hero
		_sync_player_hero(session, hero)
		return

func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	_sync_player_hero(session, hero)

func _capture_if_requested(viewport_size: Vector2i) -> String:
	var requested_dir := OS.get_environment("COMMAND_REGALIA_CAPTURE_DIR").strip_edges()
	if requested_dir == "":
		return ""
	var absolute_dir := ProjectSettings.globalize_path(requested_dir) if requested_dir.begins_with("res://") or requested_dir.begins_with("user://") else requested_dir
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return "capture_failed"
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return "capture_failed"
	var path := "%s/command-regalia-town-%dx%d.png" % [absolute_dir.trim_suffix("/"), viewport_size.x, viewport_size.y]
	return path if image.save_png(path) == OK else "capture_failed"

func _finish_town_case(shell: Node, result: Dictionary) -> Dictionary:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame
	return result

func _fail(message: String, original_window_size: Vector2i) -> void:
	get_window().size = original_window_size
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
