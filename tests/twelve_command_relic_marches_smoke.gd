extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "TWELVE_COMMAND_RELIC_MARCHES_SMOKE"
const OUTPUT_DIR := "res://.artifacts/twelve_command_relic_marches_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const CONTACT_SHEET_PATH := OUTPUT_DIR + "/command_relic_contact_sheet.png"
const FIELD_ATLAS_PATH := "res://art/overworld/runtime/objects/artifacts/command_relic_marches/command_relic_marches_atlas.png"
const BATCH_ID := "content-twelve-command-relic-marches-10184"
const CASES := [
	{"prefix":"blackgauge","scenario_id":"blackgauge-muster-bell-march","hero_id":"hero_brasshollow_kestra_blackgauge","faction_id":"faction_brasshollow","artifact_id":"artifact_blackgauge_muster_bell","bonuses":{"battle_defense":1,"battle_initiative":1},"atlas_x":0},
	{"prefix":"switchrail","scenario_id":"varn-switchrail-compass-march","hero_id":"hero_brasshollow_kuld_varn","faction_id":"faction_brasshollow","artifact_id":"artifact_varn_switchrail_compass","bonuses":{"overworld_movement":1,"scouting_radius":1},"atlas_x":48},
	{"prefix":"valechant","scenario_id":"valechant-star-cadence-march","hero_id":"hero_seren","faction_id":"faction_embercourt","artifact_id":"artifact_valechant_star_cadence_astrolabe","bonuses":{"battle_initiative":1,"scouting_radius":1},"atlas_x":96},
	{"prefix":"millward","scenario_id":"ashgrove-millward-march","hero_id":"hero_caelen","faction_id":"faction_embercourt","artifact_id":"artifact_ashgrove_millward_lantern","bonuses":{"battle_defense":1,"overworld_movement":1},"atlas_x":144},
	{"prefix":"reedcaller","scenario_id":"reedcaller-circle-horn-march","hero_id":"hero_mireclaw_rhask_reedcaller","faction_id":"faction_mireclaw","artifact_id":"artifact_reedcaller_circle_horn","bonuses":{"battle_attack":1,"overworld_movement":1},"atlas_x":192},
	{"prefix":"muckscribe","scenario_id":"muckscribe-fen-ink-march","hero_id":"hero_sable","faction_id":"faction_mireclaw","artifact_id":"artifact_muckscribe_fen_ink_reliquary","bonuses":{"battle_spell_resistance_pct":8,"scouting_radius":1},"atlas_x":240},
	{"prefix":"sevenfold","scenario_id":"sevenfold-reserve-prism-march","hero_id":"hero_sunvault_aven_sevenfold","faction_id":"faction_sunvault","artifact_id":"artifact_sevenfold_reserve_prism","bonuses":{"battle_defense":1,"battle_initiative":1},"atlas_x":288},
	{"prefix":"glasswind","scenario_id":"glasswind-sightline-march","hero_id":"hero_neral","faction_id":"faction_sunvault","artifact_id":"artifact_glasswind_sightline_fan","bonuses":{"battle_attack":1,"scouting_radius":1},"atlas_x":336},
	{"prefix":"boltroot","scenario_id":"boltroot-quiver-loom-march","hero_id":"hero_thornwake_bryn_boltroot","faction_id":"faction_thornwake","artifact_id":"artifact_boltroot_quiver_loom","bonuses":{"battle_attack":1,"scouting_radius":1},"atlas_x":384},
	{"prefix":"pollenglass","scenario_id":"pollenglass-spore-ampoule-march","hero_id":"hero_thornwake_osmund_pollenglass","faction_id":"faction_thornwake","artifact_id":"artifact_pollenglass_spore_ampoule","bonuses":{"battle_defense":1,"battle_spell_resistance_pct":8},"atlas_x":432},
	{"prefix":"oriflag","scenario_id":"oriflag-stolen-signal-march","hero_id":"hero_veilmourn_damar_oriflag","faction_id":"faction_veilmourn","artifact_id":"artifact_oriflag_stolen_signal_pennon","bonuses":{"overworld_movement":1,"scouting_radius":1},"atlas_x":480},
	{"prefix":"tidehook","scenario_id":"tidehook-memory-bosun-march","hero_id":"hero_veilmourn_olan_tidehook","faction_id":"faction_veilmourn","artifact_id":"artifact_tidehook_memory_bosun_bell","bonuses":{"battle_defense":1,"overworld_movement":1},"atlas_x":528},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1280, 720)
	ContentService.clear_cache()
	var atlas := load(FIELD_ATLAS_PATH) as Texture2D
	_expect(atlas != null and atlas.get_size() == Vector2(576, 48), "The command relic field atlas must remain exactly 576x48.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _run_case(view, case_value)
	var contact_sheet_exact := _write_contact_sheet(ProjectSettings.globalize_path(CONTACT_SHEET_PATH))
	_expect(contact_sheet_exact, "The command relic inventory/field contact sheet could not be written.")
	var report := {
		"ok":_errors.is_empty(), "case_count":CASES.size(),
		"exact_launch_count":_count_rows("exact_launch"),
		"battle_victory_count":_sum_rows("battle_victories"),
		"artifact_collection_count":_count_rows("artifact_collection"),
		"artifact_auto_equip_count":_count_rows("artifact_auto_equip"),
		"artifact_bonus_exact_count":_count_rows("artifact_bonus_exact"),
		"exact_inventory_art_count":_count_rows("exact_inventory_art"),
		"exact_field_art_count":_count_rows("exact_field_art"),
		"objective_victory_count":_count_rows("objective_victory"),
		"save_round_trip_count":_count_rows("save_round_trip"),
		"contact_sheet_path":CONTACT_SHEET_PATH,
		"save_version":SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke":true, "rows":_rows, "errors":_errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":12,"battle_victory_count":36,"artifact_collection_count":12,"artifact_auto_equip_count":12,"artifact_bonus_exact_count":12,"objective_victory_count":12,"save_round_trip_count":12,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var prefix := String(case.get("prefix", ""))
	var artifact_id := String(case.get("artifact_id", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	var artifact := ContentService.get_artifact(artifact_id)
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s could not create a live skirmish session." % scenario_id)
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var exact_launch: bool = (
		String(session.hero_id) == String(case.get("hero_id", ""))
		and String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", ""))
		and String(scenario.get("content_batch_id", "")) == BATCH_ID
		and session.overworld.get("army", {}).get("stacks", []).size() == 5
		and scenario.get("encounters", []).size() == 3
		and scenario.get("objectives", {}).get("victory", []).size() == 5
	)
	_expect(exact_launch, "%s lost its exact hero, faction, five-stack company, or five-condition march." % scenario_id)

	var icon_path := String(artifact.get("ui", {}).get("icon_path", ""))
	var icon := load(icon_path) as Texture2D
	var exact_inventory_art := icon != null and icon.get_size() == Vector2(128, 128)
	_expect(exact_inventory_art, "%s inventory art is missing or not 128x128." % artifact_id)
	var node: Dictionary = _row_by_key(session.overworld.get("artifact_nodes", []), "placement_id", "%s_relic" % prefix)
	var artifact_tile := Vector2i(int(node.get("x", -1)), int(node.get("y", -1)))
	_set_active_hero_position(session, artifact_tile)
	OverworldRules._reveal_current_fog_sources(session)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), artifact_tile)
	await get_tree().process_frame
	var presentation: Dictionary = view.call("validation_tile_presentation", artifact_tile).get("artifact_presentation", {})
	var asset_id := "artifact_field_%s" % artifact_id.trim_prefix("artifact_")
	var field_texture = view.call("_object_texture_for_asset", asset_id)
	var exact_field_art: bool = (
		String(presentation.get("artifact_id", "")) == artifact_id
		and String(presentation.get("sprite_asset_id", "")) == asset_id
		and bool(presentation.get("uses_distinct_field_sprite", false))
		and field_texture is AtlasTexture
		and field_texture.region == Rect2(int(case.get("atlas_x", -1)), 0, 48, 48)
		and field_texture.atlas is Texture2D
		and field_texture.atlas.resource_path == FIELD_ATLAS_PATH
	)
	_expect(exact_field_art, "%s did not reach its exact live field-atlas region." % artifact_id)

	var battle_victories := 0
	for index in range(1, 4):
		var placement_id := "%s_front_%d" % [prefix, index]
		var battle_probe := _clone_session(session)
		if _resolve_front(battle_probe, placement_id):
			battle_victories += 1
			var resolved: Array = session.overworld.get("resolved_encounters", [])
			if placement_id not in resolved:
				resolved.append(placement_id)
			session.overworld["resolved_encounters"] = resolved
	_expect(battle_victories == 3, "%s did not win all three production battle probes." % scenario_id)

	_set_active_hero_position(session, artifact_tile)
	var claim: Dictionary = OverworldRules.collect_active_artifact(session)
	var hero: Dictionary = session.overworld.get("hero", {})
	var artifact_collection := bool(claim.get("ok", false)) and ArtifactRulesScript.has_artifact(hero, artifact_id)
	var artifact_auto_equip := artifact_collection and _artifact_equipped(hero, artifact_id)
	var artifact_bonus_exact := artifact_auto_equip and _bonuses_match(ArtifactRulesScript.aggregate_bonuses(hero), case.get("bonuses", {}))
	_expect(artifact_collection, "%s could not be collected through live overworld authority: %s" % [artifact_id, JSON.stringify(claim)])
	_expect(artifact_auto_equip, "%s was not auto-equipped into an open trinket slot." % artifact_id)
	_expect(artifact_bonus_exact, "%s did not contribute its exact live bonuses." % artifact_id)
	var victory_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var objective_victory: bool = String(victory_result.get("status", "")) == "victory" and _met_victory_objective_count(session, scenario_id) == 5
	_expect(objective_victory, "%s did not complete all five live objectives: %s" % [scenario_id, JSON.stringify(victory_result)])
	var restored := _clone_session(session)
	var save_round_trip: bool = int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict()
	_expect(save_round_trip, "%s did not round-trip exactly through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"exact_launch":exact_launch,"battle_victories":battle_victories,"artifact_collection":artifact_collection,"artifact_auto_equip":artifact_auto_equip,"artifact_bonus_exact":artifact_bonus_exact,"exact_inventory_art":exact_inventory_art,"exact_field_art":exact_field_art,"objective_victory":objective_victory,"save_round_trip":save_round_trip})
	SessionState.set_active_session(null)


func _resolve_front(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	var encounter := _row_by_key(session.overworld.get("encounters", []), "placement_id", placement_id)
	if encounter.is_empty():
		_error("Missing encounter placement %s." % placement_id)
		return false
	var tile := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
	_set_active_hero_position(session, Vector2i(tile.x - 1, tile.y))
	var payload: Dictionary = BattleRulesScript.create_battle_payload(session, encounter)
	if payload.is_empty():
		_error("Could not construct production battle for %s." % placement_id)
		return false
	session.battle = payload
	session.game_state = "battle"
	session.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	var result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(session)
	return bool(result.get("completed", false)) and String(result.get("state", "")) == "victory" and placement_id in session.overworld.get("resolved_encounters", [])


func _write_contact_sheet(path: String) -> bool:
	var sheet := Image.create(1024, 600, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("18202b"))
	var atlas := _load_image(FIELD_ATLAS_PATH)
	if atlas == null:
		return false
	for index in range(CASES.size()):
		var artifact_id := String(CASES[index].get("artifact_id", ""))
		var icon := _load_image("res://art/artifacts/runtime/%s.png" % artifact_id.trim_prefix("artifact_"))
		if icon == null:
			return false
		var origin := Vector2i((index % 4) * 256, (index / 4) * 200)
		sheet.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), origin + Vector2i(18, 28))
		var frame := atlas.get_region(Rect2i(index * 48, 0, 48, 48))
		frame.resize(96, 96, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), origin + Vector2i(150, 44))
	return sheet.save_png(path) == OK


func _row_by_key(rows: Variant, key: String, expected: String) -> Dictionary:
	for value in rows if rows is Array else []:
		if value is Dictionary and String(value.get(key, "")) == expected:
			return value
	return {}


func _set_active_hero_position(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> void:
	var position := {"x":tile.x,"y":tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["x"] = tile.x
	hero["y"] = tile.y
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			var roster_hero: Dictionary = heroes[index]
			roster_hero["x"] = tile.x
			roster_hero["y"] = tile.y
			roster_hero["position"] = position.duplicate(true)
			heroes[index] = roster_hero
	session.overworld["player_heroes"] = heroes


func _artifact_equipped(hero: Dictionary, artifact_id: String) -> bool:
	var equipped = hero.get("artifacts", {}).get("equipped", {})
	return equipped is Dictionary and artifact_id in equipped.values()


func _bonuses_match(actual: Dictionary, expected_value: Variant) -> bool:
	var expected: Dictionary = expected_value if expected_value is Dictionary else {}
	for key_value in expected:
		var key := String(key_value)
		if int(actual.get(key, -999)) != int(expected.get(key, -998)):
			return false
	return true


func _met_victory_objective_count(session: SessionStateStoreScript.SessionData, scenario_id: String) -> int:
	var met := 0
	for value in ContentService.get_scenario(scenario_id).get("objectives", {}).get("victory", []):
		if value is Dictionary and ScenarioRulesScript.is_objective_met(session, String(value.get("id", "")), "victory"):
			met += 1
	return met


func _clone_session(source: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var result := SessionStateStoreScript.SessionData.new()
	result.from_dict(source.to_dict())
	return result


func _load_image(path: String) -> Image:
	var image := Image.new()
	return image if image.load(ProjectSettings.globalize_path(path)) == OK else null


func _count_rows(key: String) -> int:
	return _rows.filter(func(row): return bool(row.get(key, false))).size()


func _sum_rows(key: String) -> int:
	return _rows.reduce(func(total, row): return total + int(row.get(key, 0)), 0)


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Could not write %s." % path)
		return
	file.store_string(JSON.stringify(payload, "  ") + "\n")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)


func _error(message: String) -> void:
	_errors.append(message)
