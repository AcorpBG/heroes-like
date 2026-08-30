extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const EnemyAdventureRulesScript = preload("res://scripts/core/EnemyAdventureRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SIX_GRAND_CONVERGENCE_RIVAL_COMMANDERS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/six_grand_convergence_rival_commanders_smoke"
const ATLAS_PATH := "res://art/overworld/runtime/objects/encounters/grand_convergence_rival_commanders/grand_convergence_rival_commanders_atlas.png"
const ATLAS_SHA256 := "442415856610c845d2f8512d236581ebd22cb184ec846bf0d87d57ed4578dc3b"

const CASES := [
	{"scenario_id":"rainledger-cinder-convergence","placement_id":"rainledger_march_e","objective_id":"clear_rainledger_march_e","encounter_id":"encounter_rotlamp_spoor_court","army_id":"army_rainledger_march_e","hero_id":"hero_mireclaw_edda_rotlamp","faction_id":"faction_mireclaw","field_objective_id":"rotlamp_spore_lanterns","field_objective_type":"hazard_zone","reward_id":"embergrain","gold":240,"victory_flag":"rival_commander_rotlamp_broken","asset_id":"encounter_rival_commander_rotlamp_spoor_court","atlas_x":0,"source_name":"rotlamp_spoor_court_source.png","source_sha256":"49072f908575f6144a5e8467e0b6b4e1472bcbe0f67ea5786f88d0c682d9ca7f"},
	{"scenario_id":"fenwake-bogbell-convergence","placement_id":"fenwake_march_e","objective_id":"clear_fenwake_march_e","encounter_id":"encounter_daynote_refraction_bench","army_id":"army_fenwake_march_e","hero_id":"hero_sunvault_essa_daynote","faction_id":"faction_sunvault","field_objective_id":"daynote_chord_prism","field_objective_type":"ritual_pylon","reward_id":"peatwax","gold":250,"victory_flag":"rival_commander_daynote_broken","asset_id":"encounter_rival_commander_daynote_refraction_bench","atlas_x":48,"source_name":"daynote_refraction_bench_source.png","source_sha256":"30ab4310f199e73f1aed7f503882ea04c0d7cb72be457cf35b1d41b0ab29b1e5"},
	{"scenario_id":"halometer-icehook-convergence","placement_id":"halometer_march_e","objective_id":"clear_halometer_march_e","encounter_id":"encounter_thorncart_pilgrim_cordon","army_id":"army_halometer_march_e","hero_id":"hero_thornwake_halen_thorncart","faction_id":"faction_thornwake","field_objective_id":"thorncart_witness_rail","field_objective_type":"obstruction_line","reward_id":"aetherglass","gold":250,"victory_flag":"rival_commander_thorncart_broken","asset_id":"encounter_rival_commander_thorncart_pilgrim_cordon","atlas_x":96,"source_name":"thorncart_pilgrim_cordon_source.png","source_sha256":"7011cbff977f3eb54946c852facdeb2d4fee77e76043734e343f6646343bf0cb"},
	{"scenario_id":"graftsibyl-lantern-convergence","placement_id":"graftsibyl_march_e","objective_id":"clear_graftsibyl_march_e","encounter_id":"encounter_pitmarshal_red_chain_assize","army_id":"army_graftsibyl_march_e","hero_id":"hero_brasshollow_selka_pitmarshal","faction_id":"faction_brasshollow","field_objective_id":"pitmarshal_chain_gate","field_objective_type":"breach_point","reward_id":"verdant_grafts","gold":260,"victory_flag":"rival_commander_pitmarshal_broken","asset_id":"encounter_rival_commander_pitmarshal_red_chain_assize","atlas_x":144,"source_name":"pitmarshal_red_chain_assize_source.png","source_sha256":"d428c13563d034f8c055441fb132a1c2a2bac8b1d8ba8f11aa03682e713c2003"},
	{"scenario_id":"debtrune-default-convergence","placement_id":"debtrune_march_e","objective_id":"clear_debtrune_march_e","encounter_id":"encounter_mistcorsair_foghook_boarding","army_id":"army_debtrune_march_e","hero_id":"hero_veilmourn_cela_mistcorsair","faction_id":"faction_veilmourn","field_objective_id":"mistcorsair_false_bearing","field_objective_type":"signal_beacon","reward_id":"brass_scrip","gold":260,"victory_flag":"rival_commander_mistcorsair_broken","asset_id":"encounter_rival_commander_mistcorsair_foghook_boarding","atlas_x":192,"source_name":"mistcorsair_foghook_boarding_source.png","source_sha256":"c399013f6311171848b06f08c0ed7c6eef23c2a8709ff6dce3012030dd12dadd"},
	{"scenario_id":"nightchart-meridian-convergence","placement_id":"nightchart_march_e","objective_id":"clear_nightchart_march_e","encounter_id":"encounter_tollbrand_sluice_levy","army_id":"army_nightchart_march_e","hero_id":"hero_embercourt_helva_tollbrand","faction_id":"faction_embercourt","field_objective_id":"tollbrand_levy_wagon","field_objective_type":"supply_post","reward_id":"memory_salt","gold":250,"victory_flag":"rival_commander_tollbrand_broken","asset_id":"encounter_rival_commander_tollbrand_sluice_levy","atlas_x":240,"source_name":"tollbrand_sluice_levy_source.png","source_sha256":"cd687ed685d79d00a137ab031628900881e9a900c0a41844d1fdec22a8dc9dec"},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ContentService.clear_cache()
	var image := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	_expect(not image.is_empty() and image.get_size() == Vector2i(288, 48) and image.detect_alpha() != Image.ALPHA_NONE, "Rival-command atlas must remain a transparent 288x48 strip.")
	_expect(FileAccess.get_sha256(ATLAS_PATH) == ATLAS_SHA256, "Rival-command atlas bytes changed.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		print("%s CASE_START %s" % [REPORT_ID, case_value.get("encounter_id", "")])
		await _validate_case(view, case_value)
		print("%s CASE_DONE %s" % [REPORT_ID, case_value.get("encounter_id", "")])
	var report := {"ok":_errors.is_empty(),"case_count":CASES.size(),"named_roster_commander_count":CASES.size(),"atlas_path":ATLAS_PATH,"atlas_size":[288,48],"atlas_sha256":ATLAS_SHA256,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_consolidated_smoke":true,"rows":_rows,"errors":_errors}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":CASES.size(),"save_version":SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var encounter_id := String(case.get("encounter_id", ""))
	var hero_id := String(case.get("hero_id", ""))
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s did not create a live skirmish session." % scenario_id)
	if session == null:
		return
	var placement := _encounter(session, placement_id)
	var commander_seed: Dictionary = placement.get("enemy_commander_state", {}) if placement.get("enemy_commander_state", {}) is Dictionary else {}
	_expect(String(placement.get("encounter_id", "")) == encounter_id and bool(placement.get("prefer_identity_landmark", false)) and String(commander_seed.get("roster_hero_id", "")) == hero_id, "%s lost its fixed named-rival placement." % encounter_id)
	var encounter := ContentService.get_encounter(encounter_id)
	var army := ContentService.get_army_group(String(case.get("army_id", "")))
	var hero := ContentService.get_hero(hero_id)
	var objective := _objective(encounter.get("field_objectives", []), String(case.get("field_objective_id", "")))
	_expect(String(encounter.get("enemy_group_id", "")) == String(case.get("army_id", "")) and String(army.get("faction_id", "")) == String(case.get("faction_id", "")), "%s lost its exact faction army." % encounter_id)
	_expect(String(encounter.get("enemy_commander", {}).get("roster_hero_id", "")) == hero_id and String(objective.get("type", "")) == String(case.get("field_objective_type", "")), "%s lost its roster hero or tactical objective." % encounter_id)
	var source_path := "res://art/overworld/source/generated/encounters/grand_convergence_rival_commanders/%s" % String(case.get("source_name", ""))
	_expect(FileAccess.get_sha256(source_path) == String(case.get("source_sha256", "")), "%s source provenance changed." % encounter_id)
	_set_active_hero_position(session, Vector2i(int(placement.get("x", 0)), int(placement.get("y", 0))))
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(placement.get("x", 0)), int(placement.get("y", 0))))
	await get_tree().process_frame
	var presentation: Dictionary = view.call("validation_encounter_presentation_payload", placement)
	var texture = view.call("_object_texture_for_asset", String(case.get("asset_id", "")))
	var exact_art: bool = String(presentation.get("identity_encounter_asset_id", "")) == String(case.get("asset_id", "")) and String(presentation.get("identity_encounter_path", "")) == ATLAS_PATH and bool(presentation.get("uses_identity_encounter_sprite", false)) and texture is AtlasTexture and texture.region == Rect2(float(case.get("atlas_x", 0)), 0.0, 48.0, 48.0) and texture.atlas.get_size() == Vector2(288, 48)
	_expect(exact_art, "%s did not resolve its exact rival-standard frame." % encounter_id)
	var capture_path := await _capture_if_requested(scenario_id)
	var resources_before := (session.overworld.get("resources", {}) as Dictionary).duplicate(true)
	var battle := BattleRulesScript.create_battle_payload(session, placement)
	_expect(not battle.is_empty() and String(battle.get("enemy_army_id", "")) == String(case.get("army_id", "")), "%s did not construct its exact live battle." % encounter_id)
	if battle.is_empty():
		return
	var enemy_hero: Dictionary = battle.get("enemy_hero", {}) if battle.get("enemy_hero", {}) is Dictionary else {}
	var enemy_payload: Dictionary = battle.get("enemy_hero_payload", {}) if battle.get("enemy_hero_payload", {}) is Dictionary else {}
	var known_spells: Array = enemy_hero.get("spellbook", {}).get("known_spell_ids", []) if enemy_hero.get("spellbook", {}) is Dictionary else []
	var portrait_path := String(ContentService.get_hero_art(hero_id).get("portrait", ""))
	var expected_commander := EnemyAdventureRulesScript.build_roster_commander_state(
		hero_id,
		String(case.get("faction_id", "")),
		commander_seed
	)
	var commander_checks := {
		"state_roster_id": String(enemy_hero.get("roster_hero_id", "")) == hero_id,
		"payload_roster_id": String(enemy_payload.get("roster_hero_id", "")) == hero_id,
		"name": String(enemy_hero.get("name", "")) == String(hero.get("name", "")),
		"command": enemy_hero.get("command", {}) == expected_commander.get("command", {}),
		"command_base_floor": _command_at_least(enemy_hero.get("command", {}), hero.get("command", {})),
		"spellbook": known_spells == hero.get("starting_spell_ids", []),
		"specialties": _specialty_ids(enemy_hero.get("specialties", [])) == hero.get("starting_specialties", []),
		"traits": enemy_hero.get("battle_traits", []) == hero.get("battle_traits", []),
		"portrait": load(portrait_path) is Texture2D,
	}
	var commander_exact: bool = commander_checks.values().all(func(value): return bool(value))
	_expect(commander_exact, "%s did not hydrate canonical roster details: %s" % [encounter_id, JSON.stringify(commander_checks)])
	session.battle = battle
	for stack_value in session.battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy":
			stack_value["total_health"] = 0
	var resolution := BattleRulesScript.resolve_if_battle_ready(session)
	var resources_after: Dictionary = session.overworld.get("resources", {})
	var reward_id := String(case.get("reward_id", ""))
	var reward_exact := int(resources_after.get("gold", 0)) - int(resources_before.get("gold", 0)) == int(case.get("gold", -1)) and int(resources_after.get(reward_id, 0)) - int(resources_before.get(reward_id, 0)) == 1
	var objective_met := ScenarioRulesScript.is_objective_met(session, String(case.get("objective_id", "")), "victory")
	_expect(String(resolution.get("state", "")) == "victory" and OverworldRules.is_encounter_resolved(session, placement) and objective_met and reward_exact and bool(session.flags.get(String(case.get("victory_flag", "")), false)), "%s did not resolve its objective, reward, or victory flag through live authority." % encounter_id)
	var authority := session.to_dict()
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(authority)
	var save_exact := restored.save_version == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == authority
	_expect(save_exact, "%s did not round-trip exactly through save version %d." % [encounter_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"encounter_id":encounter_id,"hero_id":hero_id,"named_commander_exact":commander_exact,"commander_checks":commander_checks,"objective_met":objective_met,"reward_exact":reward_exact,"exact_art":exact_art,"capture_path":capture_path,"save_round_trip_exact":save_exact})
	SessionState.set_active_session(null)


func _specialty_ids(value: Variant) -> Array:
	var result := []
	for entry in value if value is Array else []:
		var specialty_id := String(entry.get("id", "")) if entry is Dictionary else String(entry)
		if specialty_id != "" and specialty_id not in result:
			result.append(specialty_id)
	return result


func _command_at_least(actual_value: Variant, base_value: Variant) -> bool:
	var actual: Dictionary = actual_value if actual_value is Dictionary else {}
	var base: Dictionary = base_value if base_value is Dictionary else {}
	for key in ["attack", "defense", "power", "knowledge"]:
		if int(actual.get(key, -1)) < int(base.get(key, 0)):
			return false
	return true


func _objective(value: Variant, objective_id: String) -> Dictionary:
	for entry in value if value is Array else []:
		if entry is Dictionary and String(entry.get("id", "")) == objective_id:
			return entry
	return {}


func _encounter(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for entry in session.overworld.get("encounters", []):
		if entry is Dictionary and String(entry.get("placement_id", "")) == placement_id:
			return entry
	return {}


func _set_active_hero_position(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> void:
	var position := {"x":tile.x,"y":tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero


func _capture_if_requested(stem: String) -> String:
	var capture_dir := OS.get_environment("RIVAL_COMMANDER_CAPTURE_DIR")
	if capture_dir == "":
		return ""
	var absolute_dir := ProjectSettings.globalize_path(capture_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := absolute_dir.path_join("%s.png" % stem)
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		_error("Could not save visual capture %s." % path)
		return ""
	return path


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)


func _error(message: String) -> void:
	_errors.append(message)
	push_error(message)


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Unable to write report %s." % path)
		return
	file.store_string(JSON.stringify(payload, "  "))
