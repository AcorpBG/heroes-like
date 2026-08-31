extends Node

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SIX_FACTION_FIELD_MUSTER_CAPTAINS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/six_faction_field_muster_captains_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const BATCH_ID := "content-six-faction-field-muster-captains-10184"
const VIEWPORT_SIZE := Vector2i(1280, 720)
const CASES := [
	{
		"hero_id":"hero_embercourt_maela_powderwrit", "hero_name":"Maela Powderwrit", "faction_id":"faction_embercourt", "fixture_scenario_id":"river-pass",
		"unit_id":"unit_embercourt_cinderseal_bombardiers", "site_id":"site_stormseal_powder_wharf", "town_id":"town_rainwrit_bastion",
		"battle_scenario_id":"pollenglass-lockglass-appeal", "battle_placement_id":"pollenglass_watch_contract", "battle_count":1,
		"source_sha":"78c19d7739439322027fb213099810f8b3454b12c2888e62de443d74f43813d9", "portrait_sha":"77113d076eade809d8a2e307e7a4d76ce8b28e6235b7803bc8e886c1180da132",
	},
	{
		"hero_id":"hero_mireclaw_rhask_reedcaller", "hero_name":"Rhask Reedcaller", "faction_id":"faction_mireclaw", "fixture_scenario_id":"bogbound-oath",
		"unit_id":"unit_mireclaw_mireglass_reedcasters", "site_id":"site_moonwax_reed_circle", "town_id":"town_hollowreed_sanctuary",
		"battle_scenario_id":"glassmarshal-fenbell-refraction", "battle_placement_id":"glassmarshal_watch_contract", "battle_count":2,
		"source_sha":"702029913007564436a055693a9f7b2cb01c7a9b426624ec6783075b72f674bb", "portrait_sha":"409f71110d64031ab5f6f5384736e0deff9fcedc7954f36b6b829a52099e35dc",
	},
	{
		"hero_id":"hero_sunvault_aven_sevenfold", "hero_name":"Aven Sevenfold", "faction_id":"faction_sunvault", "fixture_scenario_id":"prismhearth-watch",
		"unit_id":"unit_sunvault_noonfacet_sentinels", "site_id":"site_facet_vigil", "town_id":"town_meridian_choirhold",
		"battle_scenario_id":"thorncart-daybreak-tangle", "battle_placement_id":"thorncart_watch_contract", "battle_count":2,
		"source_sha":"cc22c746c521901218564732da800f3b185a318f34beb4f3f352551ff4eeb138", "portrait_sha":"fc13d7987f722d92630c487cb4574923551f136a1c7cff84d33e121ae08680c0",
	},
	{
		"hero_id":"hero_thornwake_bryn_boltroot", "hero_name":"Bryn Boltroot", "faction_id":"faction_thornwake", "fixture_scenario_id":"mireford-skirmish",
		"unit_id":"unit_thornwake_dawnseed_bolters", "site_id":"site_heartseed_bolt_grove", "town_id":"town_crownroot_refuge",
		"battle_scenario_id":"chainboom-graftwake-cordon", "battle_placement_id":"chainboom_watch_contract", "battle_count":2,
		"source_sha":"8b69dbcfb41ce9fe27e245115c6580649401ca43d2cb89a1b8813050efb51254", "portrait_sha":"d0e611ccc161a99330612df6adfce8e386940a0547092196fe94b529492caf3e",
	},
	{
		"hero_id":"hero_brasshollow_kestra_blackgauge", "hero_name":"Kestra Blackgauge", "faction_id":"faction_brasshollow", "fixture_scenario_id":"orevein-contract",
		"unit_id":"unit_brasshollow_gaugeplate_bailiffs", "site_id":"site_blackbell_assay_watch", "town_id":"town_blackbell_foundry",
		"battle_scenario_id":"reedscript-redline-reckoning", "battle_placement_id":"reedscript_watch_contract", "battle_count":2,
		"source_sha":"a9a7285623f84c6ef07864b8fde53bad77d5d299f691f021fbcf15a0047132ca", "portrait_sha":"70dcaab14eeaf01d835a381d35ffb4130012a328c6716e9b2a1a38d3f2e749de",
	},
	{
		"hero_id":"hero_veilmourn_olan_tidehook", "hero_name":"Olan Tidehook", "faction_id":"faction_veilmourn", "fixture_scenario_id":"bellwake-wreck-claim",
		"unit_id":"unit_veilmourn_tidehook_deckhands", "site_id":"site_last_memory_mooring", "town_id":"town_pale_sounding_harbor",
		"battle_scenario_id":"facetlane-last-sounding", "battle_placement_id":"facetlane_watch_contract", "battle_count":4,
		"source_sha":"3a877521bf50892b0f23c1682787dda15c414eaeff4c51dc6227719026811fc6", "portrait_sha":"77cc69ccb7def401e012b9a988e64ddcfd363953b6696cf285c285cfef981c69",
	},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = VIEWPORT_SIZE
	ContentService.clear_cache()
	_expect(ContentService.get_content_ids(ContentService.HEROES_PATH).size() == 66, "The live hero catalog must contain exactly 66 records after this batch.")
	_validate_balanced_faction_rosters()
	for case_value in CASES:
		await _run_case(case_value)
	var report := {
		"ok": _errors.is_empty(),
		"batch_id": BATCH_ID,
		"case_count": CASES.size(),
		"hero_count": ContentService.get_content_ids(ContentService.HEROES_PATH).size(),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":CASES.size(),"hero_count":66,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_consolidated_smoke":true})])
	SessionState.set_active_session(null)
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(case: Dictionary) -> void:
	_validate_content_and_art(case)
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(String(case.get("fixture_scenario_id", "")), "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s tavern fixture did not create a live session." % String(case.get("hero_id", "")))
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var town := _first_player_town(session)
	_expect(not town.is_empty(), "%s tavern fixture has no controlled town." % String(case.get("hero_id", "")))
	if town.is_empty():
		return
	_prepare_tavern(session, town)
	var hero_id := String(case.get("hero_id", ""))
	var new_ids := _batch_hero_ids()
	var recruitable: Array = HeroCommandRules.recruitable_hero_ids(session)
	var available_batch_ids := recruitable.filter(func(candidate): return String(candidate) in new_ids)
	var actions: Array = TownRules.get_tavern_actions(session)
	var action_id := "hire_hero:%s" % hero_id
	var action_matches := actions.filter(func(row): return row is Dictionary and String(row.get("id", "")) == action_id and not bool(row.get("disabled", true)))
	_expect(available_batch_ids == [hero_id] and action_matches.size() == 1, "%s must be the only new batch captain offered by its faction tavern." % hero_id)
	var hire_result := TownRules.hire_hero_at_active_town(session, hero_id)
	_expect(bool(hire_result.get("ok", false)), "%s failed live tavern recruitment: %s" % [hero_id, JSON.stringify(hire_result)])
	var switch_result := HeroCommandRules.set_active_hero(session, hero_id)
	_expect(bool(switch_result.get("ok", false)), "%s failed live command handoff: %s" % [hero_id, JSON.stringify(switch_result)])
	var hero: Dictionary = session.overworld.get("hero", {})
	_expect(String(hero.get("id", "")) == hero_id and HeroProgressionRulesScript.specialty_rank(hero, "mustercaptain") == 1, "%s did not retain rank-one Muster Captain authority after recruitment." % hero_id)
	var effect := _validate_muster_captain_effect(session, town, case)
	var portrait_capture := await _validate_town_portrait(session, case)
	var battle_result := await _validate_live_company_battle(case)
	var authority := session.to_dict()
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(authority)
	var save_exact := restored.save_version == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == authority
	_expect(save_exact, "%s failed the exact save-v%d round trip." % [hero_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({
		"hero_id": hero_id,
		"faction_id": String(case.get("faction_id", "")),
		"tavern_action_id": action_id,
		"specialty_rank": HeroProgressionRulesScript.specialty_rank(hero, "mustercaptain"),
		"growth_before": int(effect.get("growth_before", 0)),
		"growth_after": int(effect.get("growth_after", 0)),
		"cost_before": effect.get("cost_before", {}),
		"cost_after": effect.get("cost_after", {}),
		"portrait_capture": portrait_capture,
		"battle_stack_count": int(battle_result.get("stack_count", 0)),
		"battle_victory": bool(battle_result.get("victory", false)),
		"save_exact": save_exact,
	})


func _validate_content_and_art(case: Dictionary) -> void:
	var hero_id := String(case.get("hero_id", ""))
	var faction_id := String(case.get("faction_id", ""))
	var hero := ContentService.get_hero(hero_id)
	var faction := ContentService.get_faction(faction_id)
	var art := ContentService.get_hero_art(hero_id)
	_expect(String(hero.get("name", "")) == String(case.get("hero_name", "")) and String(hero.get("faction_id", "")) == faction_id, "%s identity or faction authority changed." % hero_id)
	_expect(String(hero.get("content_status", "")) == "horizon_field_muster_captain_live" and String(hero.get("content_batch_id", "")) == BATCH_ID, "%s lost its live batch contract." % hero_id)
	_expect(hero.get("starting_specialties", []) == ["mustercaptain"] and String(hero.get("signature_unit_id", "")) == String(case.get("unit_id", "")) and String(hero.get("field_muster_site_id", "")) == String(case.get("site_id", "")), "%s lost its exact field-muster command link." % hero_id)
	_expect(hero_id in faction.get("hero_ids", []) and hero_id in faction.get("bible_hero_ids", []), "%s is missing from its live faction roster." % hero_id)
	var source_path := "res://art/heroes/source/curated/%s.png" % hero_id
	var portrait_path := "res://art/heroes/portraits/%s.png" % hero_id
	var source := Image.load_from_file(ProjectSettings.globalize_path(source_path))
	var portrait := Image.load_from_file(ProjectSettings.globalize_path(portrait_path))
	_expect(not source.is_empty() and source.get_size() == Vector2i(1254, 1254) and FileAccess.get_sha256(source_path) == String(case.get("source_sha", "")), "%s curated portrait master changed." % hero_id)
	_expect(not portrait.is_empty() and portrait.get_size() == Vector2i(384, 512) and FileAccess.get_sha256(portrait_path) == String(case.get("portrait_sha", "")), "%s runtime portrait changed." % hero_id)
	_expect(String(art.get("source_kind", "")) == "curated_original_character" and String(art.get("source_path", "")) == source_path and String(art.get("source_sha256", "")) == String(case.get("source_sha", "")) and String(art.get("portrait", "")) == portrait_path, "%s portrait manifest provenance changed." % hero_id)


func _validate_balanced_faction_rosters() -> void:
	for faction_id in ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake", "faction_brasshollow", "faction_veilmourn"]:
		var faction := ContentService.get_faction(faction_id)
		_expect(faction.get("hero_ids", []).size() == 11 and faction.get("bible_hero_ids", []).size() == 11, "%s must expose exactly eleven live authored commanders." % faction_id)


func _validate_muster_captain_effect(session: SessionStateStoreScript.SessionData, town: Dictionary, case: Dictionary) -> Dictionary:
	var unit_id := String(case.get("unit_id", ""))
	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	var baseline_hero := hero.duplicate(true)
	baseline_hero["specialties"] = []
	var fixed_growth := {unit_id: 5}
	var growth_before := int(HeroProgressionRulesScript.scale_recruit_growth(baseline_hero, fixed_growth).get(unit_id, 0))
	var growth_after := int(HeroProgressionRulesScript.scale_recruit_growth(hero, fixed_growth).get(unit_id, 0))
	var baseline_session := _clone_session(session)
	baseline_session.overworld["hero"] = baseline_hero
	var cost_before := OverworldRules.town_recruit_cost(baseline_session, town, unit_id)
	var cost_after := OverworldRules.town_recruit_cost(session, town, unit_id)
	_expect(growth_before == 5 and growth_after == 6, "%s did not apply the exact rank-one 20%% recruit-growth bonus." % String(case.get("hero_id", "")))
	_expect(_cost_is_lower(cost_after, cost_before), "%s did not lower the live production recruit cost." % String(case.get("hero_id", "")))
	return {"growth_before":growth_before,"growth_after":growth_after,"cost_before":cost_before,"cost_after":cost_after}


func _validate_town_portrait(session: SessionStateStoreScript.SessionData, case: Dictionary) -> String:
	session.game_state = "town"
	SessionState.set_active_session(session)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(VIEWPORT_SIZE)
	frame.size = Vector2(VIEWPORT_SIZE)
	add_child(frame)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	frame.add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var portrait: Dictionary = snapshot.get("hero_portrait", {})
	var hero_id := String(case.get("hero_id", ""))
	var portrait_path := "res://art/heroes/portraits/%s.png" % hero_id
	_expect(bool(portrait.get("visible", false)) and String(portrait.get("hero_id", "")) == hero_id and String(portrait.get("portrait_path", "")) == portrait_path, "%s did not render its exact portrait on the live town screen." % hero_id)
	var capture_path := "%s/%s_town.png" % [OUTPUT_DIR, hero_id]
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_expect(image != null and not image.is_empty() and image.save_png(capture_path) == OK, "%s live town capture failed." % hero_id)
	frame.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return capture_path


func _validate_live_company_battle(case: Dictionary) -> Dictionary:
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(String(case.get("battle_scenario_id", "")), "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	_configure_active_hero(session, String(case.get("hero_id", "")))
	var placement := _row_by_key(session.overworld.get("encounters", []), "placement_id", String(case.get("battle_placement_id", "")))
	var battle := BattleRulesScript.create_battle_payload(session, placement)
	var stack := _battle_stack(battle.get("stacks", []), String(case.get("unit_id", "")), "enemy")
	_expect(int(stack.get("base_count", 0)) == int(case.get("battle_count", 0)), "%s did not enter its authored live company battle." % String(case.get("unit_id", "")))
	session.battle = battle
	for stack_value in session.battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy":
			stack_value["total_health"] = 0
	var resolution: Dictionary = BattleRulesScript.resolve_if_battle_ready(session)
	var victory := String(resolution.get("state", "")) == "victory" and OverworldRules.is_encounter_resolved(session, placement)
	_expect(victory, "%s company battle did not resolve through production victory authority." % String(case.get("unit_id", "")))
	return {"stack_count":int(stack.get("base_count", 0)),"victory":victory}


func _prepare_tavern(session: SessionStateStoreScript.SessionData, town: Dictionary) -> void:
	session.overworld["resources"] = {"gold":100000,"wood":1000,"ore":1000,"aetherglass":1000,"embergrain":1000,"peatwax":1000,"verdant_grafts":1000,"brass_scrip":1000,"memory_salt":1000}
	var buildings: Array = town.get("built_buildings", []).duplicate(true)
	if HeroCommandRules.HALL_BUILDING_ID not in buildings:
		buildings.append(HeroCommandRules.HALL_BUILDING_ID)
	town["built_buildings"] = buildings
	_move_active_hero_to_town(session, town)
	var visit := OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	_expect(bool(visit.get("ok", false)), "%s could not establish a live tavern visit." % String(town.get("placement_id", "")))


func _configure_active_hero(session: SessionStateStoreScript.SessionData, hero_id: String) -> void:
	var heroes: Array = session.overworld.get("player_heroes", [])
	var source: Dictionary = heroes[0] if not heroes.is_empty() and heroes[0] is Dictionary else {}
	var position: Dictionary = source.get("position", session.overworld.get("hero_position", {})).duplicate(true)
	var army: Dictionary = source.get("army", session.overworld.get("army", {})).duplicate(true)
	var hero: Dictionary = HeroCommandRules.build_hero_from_template(ContentService.get_hero(hero_id), position, army, session)
	hero["is_primary"] = true
	heroes[0] = hero
	session.hero_id = hero_id
	session.overworld["player_heroes"] = heroes
	session.overworld["active_hero_id"] = hero_id
	session.overworld["primary_hero_id"] = hero_id
	session.overworld["hero"] = hero.duplicate(true)
	session.overworld["hero_position"] = position.duplicate(true)
	session.overworld["army"] = hero.get("army", {}).duplicate(true)
	session.overworld["movement"] = hero.get("movement", {}).duplicate(true)


func _first_player_town(session: SessionStateStoreScript.SessionData) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}


func _move_active_hero_to_town(session: SessionStateStoreScript.SessionData, town: Dictionary) -> void:
	var position := {"x":int(town.get("x", 0)),"y":int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			heroes[index] = hero.duplicate(true)
	session.overworld["player_heroes"] = heroes


func _batch_hero_ids() -> Array:
	return CASES.map(func(case): return String(case.get("hero_id", "")))


func _row_by_key(rows: Variant, key: String, expected: String) -> Dictionary:
	for row_value in rows if rows is Array else []:
		if row_value is Dictionary and String(row_value.get(key, "")) == expected:
			return row_value
	return {}


func _battle_stack(stacks: Variant, unit_id: String, side: String) -> Dictionary:
	for stack_value in stacks if stacks is Array else []:
		if stack_value is Dictionary and String(stack_value.get("unit_id", "")) == unit_id and String(stack_value.get("side", "")) == side:
			return stack_value
	return {}


func _clone_session(source: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(source.to_dict())
	return clone


func _cost_is_lower(after_value: Variant, before_value: Variant) -> bool:
	if not (after_value is Dictionary) or not (before_value is Dictionary):
		return false
	var reduced := false
	for key_value in before_value.keys():
		var key := String(key_value)
		var before := int(before_value.get(key, 0))
		if before <= 0:
			continue
		var after := int(after_value.get(key, before))
		if after > before:
			return false
		if after < before:
			reduced = true
	return reduced


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  ") + "\n")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
	push_error("%s %s" % [REPORT_ID, message])
