extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "FACTION_ARTIFACT_SET_RUNTIME_REPORT"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const CASES := {
	"set_lockward_charter": {
		"faction_id": "faction_embercourt",
		"scenario_id": "causeway-stand",
		"placements": {
			"causeway_boots": "artifact_lockward_beacon_key",
			"causeway_pennon": "artifact_lockflame_writ_banner",
			"blackfen_gorget": "artifact_tollstone_ring",
		},
		"bonuses": {"overworld_movement": 2, "scouting_radius": 1, "battle_defense": 3, "battle_initiative": 1},
		"atlas_x": 0,
	},
	"set_fenhound_pursuit": {
		"faction_id": "faction_mireclaw",
		"scenario_id": "bogbound-oath",
		"placements": {
			"bogbound_boots": "artifact_reedshadow_waders",
			"bogbound_pennon": "artifact_mirechain_hunt_totem",
			"riverwatch_gorget": "artifact_fenhound_scent_bell",
		},
		"bonuses": {"overworld_movement": 1, "scouting_radius": 2, "battle_attack": 3, "battle_initiative": 3},
		"atlas_x": 64,
	},
	"set_meridian_relay": {
		"faction_id": "faction_sunvault",
		"scenario_id": "prismhearth-watch",
		"placements": {
			"relay_boots": "artifact_meridian_relay_lens",
			"halo_pennon": "artifact_zenith_prism_pennon",
			"spire_gorget": "artifact_prismward_mantle",
		},
		"bonuses": {"scouting_radius": 1, "battle_defense": 1, "battle_initiative": 3, "battle_spell_resistance_pct": 21},
		"atlas_x": 128,
	},
	"set_rootpath_covenant": {
		"faction_id": "faction_thornwake",
		"scenario_id": "mireford-skirmish",
		"placements": {
			"bridge_boots": "artifact_rootpath_seed_compass",
			"bridge_pennon": "artifact_briarcrown_covenant_standard",
			"ford_gorget": "artifact_graftbark_cuirass",
		},
		"bonuses": {"overworld_movement": 3, "scouting_radius": 2, "battle_defense": 3},
		"atlas_x": 192,
	},
	"set_redline_survey_warrant": {
		"faction_id": "faction_brasshollow",
		"scenario_id": "orevein-contract",
		"placements": {
			"orevein_trailsinger_boots": "artifact_redline_survey_dial",
			"orevein_bastion_gorget": "artifact_quenchplate_vambrace",
			"riverwatch_warcrest_pennon": "artifact_redline_warrant_gonfalon",
		},
		"bonuses": {"overworld_movement": 1, "battle_attack": 2, "battle_defense": 4, "battle_initiative": 1},
		"atlas_x": 256,
	},
	"set_drowned_wake_chart": {
		"faction_id": "faction_veilmourn",
		"scenario_id": "bellwake-wreck-claim",
		"placements": {
			"bellwake_waymark_compass": "artifact_wakebell_mourning_ensign",
			"bellwake_trailsinger_boots": "artifact_fogwake_deckboots",
			"prismhearth_black_sail_compass": "artifact_black_sail_compass",
		},
		"bonuses": {"overworld_movement": 2, "scouting_radius": 5, "battle_initiative": 2},
		"atlas_x": 320,
	},
}

var _original_ui_scale_percent := 100

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	_original_ui_scale_percent = SettingsService.ui_scale_percent()
	SettingsService.set_ui_scale_percent(100)
	await get_tree().process_frame
	if not _atlas_has_transparency():
		_fail("Faction-set insignia atlas must retain both transparent and painted pixels.", original_window_size)
		return
	var rows: Array = []
	var presentation_session = null
	for set_id in CASES:
		var result := _validate_case(set_id, CASES[set_id])
		rows.append(result.get("row", {}))
		if not bool(result.get("ok", false)):
			_fail("Faction set runtime failed: %s" % JSON.stringify(result), original_window_size)
			return
		if set_id == "set_lockward_charter":
			presentation_session = result.get("session")
	if presentation_session == null:
		_fail("Faction set runtime did not retain a presentation session.", original_window_size)
		return

	var presentation_rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var row := await _validate_presentation(presentation_session, viewport_size)
		presentation_rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Faction set presentation failed: %s" % JSON.stringify(row), original_window_size)
			return

	get_window().size = original_window_size
	SettingsService.set_ui_scale_percent(_original_ui_scale_percent)
	await get_tree().process_frame
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"set_count": rows.size(),
		"rows": rows,
		"presentation_rows": presentation_rows,
		"save_version": SessionDataScript.SAVE_VERSION,
		"unknown_insignia_fails_closed": ArtifactRules.artifact_set_insignia_state("set_missing").is_empty(),
	})])
	get_tree().quit(0)

func _validate_case(set_id: String, spec: Dictionary) -> Dictionary:
	var session = ScenarioFactory.create_session(String(spec.get("scenario_id", "")), "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	hero["artifacts"] = ArtifactRules.normalize_hero_artifacts({})
	session.overworld["hero"] = hero
	_sync_player_hero(session, hero)
	var placements: Dictionary = spec.get("placements", {})
	var placement_rows: Array = []
	var first_node := {}
	for placement_id in placements:
		var node_result := _artifact_node_result(session, placement_id)
		var node: Dictionary = node_result.get("node", {})
		if first_node.is_empty():
			first_node = node.duplicate(true)
		if int(node_result.get("index", -1)) < 0 or String(node.get("artifact_id", "")) != String(placements[placement_id]):
			return {"ok": false, "failure": "placement", "set_id": set_id, "placement_id": placement_id, "node": node}
		var collect := OverworldRules._collect_artifact_node_result(session, node_result, false)
		if not bool(collect.get("ok", false)) or not bool(_artifact_node_result(session, placement_id).get("node", {}).get("collected", false)):
			return {"ok": false, "failure": "collection", "set_id": set_id, "placement_id": placement_id, "collect": collect}
		placement_rows.append({"placement_id": placement_id, "artifact_id": placements[placement_id], "collected": true})

	var equipped_hero: Dictionary = session.overworld.get("hero", {})
	var bonuses := ArtifactRules.aggregate_bonuses(equipped_hero)
	for bonus_key in spec.get("bonuses", {}):
		if int(bonuses.get(bonus_key, 0)) != int(spec.get("bonuses", {}).get(bonus_key, 0)):
			return {"ok": false, "failure": "bonus", "set_id": set_id, "bonus_key": bonus_key, "bonuses": bonuses}
	var active_set := _active_set(equipped_hero, set_id)
	if not bool(active_set.get("complete", false)) or int(active_set.get("equipped_piece_count", 0)) != 3 or active_set.get("active_thresholds", []).size() != 2:
		return {"ok": false, "failure": "active_set", "set_id": set_id, "active_set": active_set}
	var insignia: Dictionary = active_set.get("insignia", {})
	var region: Dictionary = insignia.get("atlas_region", {}) if insignia.get("atlas_region", {}) is Dictionary else {}
	if String(insignia.get("atlas_path", "")) != "res://art/artifacts/runtime/faction_set_insignia_atlas.png" \
			or int(region.get("x", -1)) != int(spec.get("atlas_x", -1)) \
			or int(region.get("width", 0)) != 64 \
			or String(insignia.get("alt_text", "")).strip_edges() == "":
		return {"ok": false, "failure": "insignia", "set_id": set_id, "insignia": insignia}

	var ai := EnemyAdventureRules.artifact_target_valuation_breakdown(
		session,
		{"faction_id": spec.get("faction_id", "")},
		first_node,
		Vector2i(int(first_node.get("x", 0)), int(first_node.get("y", 0))),
		String(spec.get("faction_id", "")),
		0
	)
	if int(ai.get("final_priority", 0)) <= 0 or String(ai.get("set_id", "")) != set_id or not bool(ai.get("faction_affinity_match", false)) or "set_progress" not in ai.get("reason_codes", []):
		return {"ok": false, "failure": "ai", "set_id": set_id, "ai": ai}

	var payload: Dictionary = session.to_dict()
	var restored = SessionDataScript.SessionData.new()
	restored.from_dict(payload.duplicate(true))
	var restored_set := _active_set(restored.overworld.get("hero", {}), set_id)
	if restored.save_version != SessionDataScript.SAVE_VERSION or restored.to_dict() != payload or not bool(restored_set.get("complete", false)):
		return {"ok": false, "failure": "save", "set_id": set_id, "restored_set": restored_set}
	return {
		"ok": true,
		"session": session,
		"row": {
			"ok": true,
			"set_id": set_id,
			"faction_id": spec.get("faction_id", ""),
			"scenario_id": spec.get("scenario_id", ""),
			"placements": placement_rows,
			"bonuses": spec.get("bonuses", {}),
			"full_set_complete": true,
			"active_threshold_count": 2,
			"ai_set_progress_positive": true,
			"save_round_trip_exact": true,
			"insignia_region_x": int(region.get("x", -1)),
		},
	}

func _validate_presentation(session, viewport_size: Vector2i) -> Dictionary:
	get_window().content_scale_size = viewport_size
	get_window().size = viewport_size
	await get_tree().process_frame
	var presentation_session = SessionDataScript.SessionData.new()
	presentation_session.from_dict(session.to_dict().duplicate(true))
	_move_to_first_player_town(presentation_session)
	SessionState.set_active_session(presentation_session)
	var town = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(town)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if town.has_method("validation_toggle_narrow_town_orders"):
		town.call("validation_toggle_narrow_town_orders")
	var town_tabs := town.get_node_or_null("%ManagementTabs") as TabContainer
	if town_tabs != null:
		town_tabs.current_tab = 4
	town.call("_rebuild_artifact_actions")
	await get_tree().process_frame
	await get_tree().process_frame
	var town_rows: Array = town.call("validation_artifact_set_insignia_rows")
	var town_valid := _presentation_row_exact(town_rows, "set_lockward_charter", 0)
	var town_invalid_fails_closed: bool = town.call("_artifact_set_insignia_texture", {
		"atlas_path": "res://art/artifacts/runtime/faction_set_insignia_atlas.png",
		"atlas_region": {"x": 380, "y": 0, "width": 64, "height": 64},
	}) == null
	var town_capture := await _capture_if_requested("town", viewport_size)
	town.queue_free()
	await get_tree().process_frame

	SessionState.set_active_session(presentation_session)
	var overworld = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(overworld)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	overworld.call("_apply_responsive_layout")
	var drawer_state: Dictionary = overworld.call("validation_open_command_drawer")
	for unused in range(3):
		await get_tree().process_frame
	drawer_state = overworld.call("validation_open_command_drawer")
	overworld.call("_rebuild_artifact_actions")
	await get_tree().process_frame
	await get_tree().process_frame
	var overworld_rows: Array = overworld.call("validation_artifact_set_insignia_rows")
	var overworld_valid := bool(drawer_state.get("command_drawer_visible", false)) \
		and bool(drawer_state.get("command_spine_visible", false)) \
		and _presentation_row_exact(overworld_rows, "set_lockward_charter", 0)
	var overworld_invalid_fails_closed: bool = overworld.call("_artifact_set_insignia_texture", {
		"atlas_path": "res://art/artifacts/runtime/faction_set_insignia_atlas.png",
		"atlas_region": {"x": -1, "y": 0, "width": 64, "height": 64},
	}) == null
	var overworld_capture := await _capture_if_requested("overworld", viewport_size)
	overworld.queue_free()
	await get_tree().process_frame
	return {
		"ok": town_valid and overworld_valid and town_invalid_fails_closed and overworld_invalid_fails_closed and town_capture != "capture_failed" and overworld_capture != "capture_failed",
		"viewport": [viewport_size.x, viewport_size.y],
		"town_rows": town_rows,
		"overworld_rows": overworld_rows,
		"overworld_drawer_state": drawer_state,
		"town_invalid_region_fails_closed": town_invalid_fails_closed,
		"overworld_invalid_region_fails_closed": overworld_invalid_fails_closed,
		"town_capture": town_capture,
		"overworld_capture": overworld_capture,
	}

func _presentation_row_exact(rows: Array, set_id: String, x: int) -> bool:
	for row_value in rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		var region: Rect2 = row.get("atlas_region", Rect2())
		if String(row.get("set_id", "")) == set_id:
			return bool(row.get("visible", false)) \
				and bool(row.get("complete", false)) \
				and String(row.get("label", "")).contains("3/3") \
				and String(row.get("tooltip", "")).strip_edges() != "" \
				and String(row.get("atlas_path", "")) == "res://art/artifacts/runtime/faction_set_insignia_atlas.png" \
				and int(region.position.x) == x and int(region.size.x) == 64
	return false

func _active_set(hero: Dictionary, set_id: String) -> Dictionary:
	for state_value in ArtifactRules.artifact_set_runtime_state(hero):
		if state_value is Dictionary and String(state_value.get("set_id", "")) == set_id:
			return state_value
	return {}

func _artifact_node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("artifact_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index": index, "node": nodes[index]}
	return {"index": -1, "node": {}}

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

func _capture_if_requested(surface: String, viewport_size: Vector2i) -> String:
	var requested_dir := OS.get_environment("FACTION_SET_CAPTURE_DIR").strip_edges()
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
	var path := "%s/faction-set-%s-%dx%d.png" % [absolute_dir.trim_suffix("/"), surface, viewport_size.x, viewport_size.y]
	return path if image.save_png(path) == OK else "capture_failed"

func _atlas_has_transparency() -> bool:
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://art/artifacts/runtime/faction_set_insignia_atlas.png"))
	if image == null or image.is_empty() or image.get_size() != Vector2i(384, 64):
		return false
	var minimum_alpha := 1.0
	var maximum_alpha := 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a
			minimum_alpha = minf(minimum_alpha, alpha)
			maximum_alpha = maxf(maximum_alpha, alpha)
	return minimum_alpha <= 0.01 and maximum_alpha >= 0.95

func _fail(message: String, original_window_size: Vector2i) -> void:
	get_window().size = original_window_size
	SettingsService.set_ui_scale_percent(_original_ui_scale_percent)
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
