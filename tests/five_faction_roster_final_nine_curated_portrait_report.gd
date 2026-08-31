extends Node

const REPORT_ID := "FIVE_FACTION_ROSTER_FINAL_NINE_CURATED_PORTRAIT_REPORT"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const CASES := [
	{
		"hero_id": "hero_mireclaw_pell_reedscript",
		"hero_name": "Pell Reedscript",
		"faction_id": "faction_mireclaw",
		"archetype": "denaugur",
		"fixture_scenario_id": "bogbound-oath",
		"roster_index": 8,
		"source_path": "res://art/heroes/source/curated/hero_mireclaw_pell_reedscript.png",
		"source_sha256": "692074bfcb365ed46788a256122a9215fee4926b6eb84c1c24b33072c4637c08",
		"portrait_path": "res://art/heroes/portraits/hero_mireclaw_pell_reedscript.png",
		"portrait_sha256": "a2cbf663c960635ac3c06536917c5882bd31ebfb6802cb7e0ea6f1eec9ed6aca",
		"starting_spell_ids": ["spell_trailglyph", "spell_relay_drum", "spell_bulwark_litany"],
		"starting_specialties": ["ledgerkeeper"],
		"battle_traits": ["linekeeper", "bogwise"],
		"command": {"attack": 0, "defense": 1, "power": 1, "knowledge": 3},
		"base_movement": 10,
		"recruit_cost": {"gold": 1100},
	},
	{
		"hero_id": "hero_mireclaw_zhorra_fenwake",
		"hero_name": "Zhorra Fenwake",
		"faction_id": "faction_mireclaw",
		"archetype": "drumoracle",
		"fixture_scenario_id": "bogbound-oath",
		"roster_index": 9,
		"source_path": "res://art/heroes/source/curated/hero_mireclaw_zhorra_fenwake.png",
		"source_sha256": "b0d7a891e93f00ee1aae3de089faef35145b257c6a953109a23d8611b1ed0d46",
		"portrait_path": "res://art/heroes/portraits/hero_mireclaw_zhorra_fenwake.png",
		"portrait_sha256": "ebc4efe6f0d356911b8275d2cdb90743219e1a0d296d2a92cfaade870128a3d8",
		"starting_spell_ids": ["spell_relay_drum", "spell_bloodwake_drum", "spell_coal_rain"],
		"starting_specialties": ["spellwright"],
		"battle_traits": ["bogwise", "linekeeper"],
		"command": {"attack": 0, "defense": 0, "power": 2, "knowledge": 2},
		"base_movement": 11,
		"recruit_cost": {"gold": 1200},
	},
	{
		"hero_id": "hero_sunvault_calis_sunvein",
		"hero_name": "Calis Sunvein",
		"faction_id": "faction_sunvault",
		"archetype": "solarphysician",
		"fixture_scenario_id": "prismhearth-watch",
		"roster_index": 8,
		"source_path": "res://art/heroes/source/curated/hero_sunvault_calis_sunvein.png",
		"source_sha256": "ce60c3cc285553bcc5bd32fc37e9768b6d28888975931e446cdb23a1f6cffb46",
		"portrait_path": "res://art/heroes/portraits/hero_sunvault_calis_sunvein.png",
		"portrait_sha256": "d9b2ca904b6114a2432b04bcd03c0cf8f589b3ef4a73d1a94a17dd1ebc7b60a3",
		"starting_spell_ids": ["spell_prism_bastion", "spell_stone_veil", "spell_resonant_chorus"],
		"starting_specialties": ["spellwright"],
		"battle_traits": ["linekeeper", "artillerist"],
		"command": {"attack": 0, "defense": 1, "power": 2, "knowledge": 1},
		"base_movement": 10,
		"recruit_cost": {"gold": 1200},
	},
	{
		"hero_id": "hero_sunvault_mirro_halometer",
		"hero_name": "Mirro Halometer",
		"faction_id": "faction_sunvault",
		"archetype": "calibration",
		"fixture_scenario_id": "prismhearth-watch",
		"roster_index": 9,
		"source_path": "res://art/heroes/source/curated/hero_sunvault_mirro_halometer.png",
		"source_sha256": "60bd8f0a1e64c9dbf0503513fab82d6fbe4e08ae7f5b3de01f4492be3f220500",
		"portrait_path": "res://art/heroes/portraits/hero_sunvault_mirro_halometer.png",
		"portrait_sha256": "782d59155fb9e47ba9f0c50a7bfca57f327ef7d5e89e8b8a9865794fd1915b81",
		"starting_spell_ids": ["spell_sunlance_arc", "spell_resonant_chorus", "spell_beacon_path"],
		"starting_specialties": ["spellwright"],
		"battle_traits": ["artillerist", "packhunter"],
		"command": {"attack": 0, "defense": 0, "power": 2, "knowledge": 3},
		"base_movement": 11,
		"recruit_cost": {"gold": 1250},
	},
	{
		"hero_id": "hero_thornwake_nara_graftsibyl",
		"hero_name": "Nara Graft-Sibyl",
		"faction_id": "faction_thornwake",
		"archetype": "graftprophet",
		"fixture_scenario_id": "mireford-skirmish",
		"roster_index": 9,
		"source_path": "res://art/heroes/source/curated/hero_thornwake_nara_graftsibyl.png",
		"source_sha256": "c2ccbd6efa9acd34e524416078735d1b1a4a742bb7da1c8ed2d06423520174de",
		"portrait_path": "res://art/heroes/portraits/hero_thornwake_nara_graftsibyl.png",
		"portrait_sha256": "27d7304d252206a573c4adac9bf1d7f999f05763cda0a0c6488ed1c5ff417691",
		"starting_spell_ids": ["spell_graft_mend", "spell_briar_bind", "spell_prism_bastion"],
		"starting_specialties": ["spellwright"],
		"battle_traits": ["linekeeper", "bogwise"],
		"command": {"attack": 0, "defense": 1, "power": 2, "knowledge": 2},
		"base_movement": 11,
		"recruit_cost": {"gold": 1200},
	},
	{
		"hero_id": "hero_brasshollow_harro_debtrune",
		"hero_name": "Harro Debt-Rune",
		"faction_id": "faction_brasshollow",
		"archetype": "clausemage",
		"fixture_scenario_id": "orevein-contract",
		"roster_index": 8,
		"source_path": "res://art/heroes/source/curated/hero_brasshollow_harro_debtrune.png",
		"source_sha256": "aa849944235857bcea00a1e399b29bbd2a572f9421710c194675767b438ae49b",
		"portrait_path": "res://art/heroes/portraits/hero_brasshollow_harro_debtrune.png",
		"portrait_sha256": "e3aaa25d91f44ceabc5eda44ac94336df5c438e7ad9a82e7f955132c929b385d",
		"starting_spell_ids": ["spell_pressure_clause", "spell_briar_bind", "spell_stone_veil"],
		"starting_specialties": ["spellwright"],
		"battle_traits": ["linekeeper", "bogwise"],
		"command": {"attack": 0, "defense": 0, "power": 2, "knowledge": 2},
		"base_movement": 10,
		"recruit_cost": {"gold": 1250},
	},
	{
		"hero_id": "hero_brasshollow_pava_ashmeter",
		"hero_name": "Pava Ashmeter",
		"faction_id": "faction_brasshollow",
		"archetype": "slagalchemist",
		"fixture_scenario_id": "orevein-contract",
		"roster_index": 9,
		"source_path": "res://art/heroes/source/curated/hero_brasshollow_pava_ashmeter.png",
		"source_sha256": "9e3c1804a89042c74fd9f77c34a544cf2eaa89a57f0b1fffb289d77303c01bff",
		"portrait_path": "res://art/heroes/portraits/hero_brasshollow_pava_ashmeter.png",
		"portrait_sha256": "5b5bb7b9487e373477f72ed4cda827cc2fca4f40c0b9548f099d095ecea9d910",
		"starting_spell_ids": ["spell_heat_rite", "spell_coal_rain", "spell_pressure_clause"],
		"starting_specialties": ["ledgerkeeper"],
		"battle_traits": ["artillerist", "ambusher"],
		"command": {"attack": 0, "defense": 0, "power": 3, "knowledge": 2},
		"base_movement": 10,
		"recruit_cost": {"gold": 1250},
	},
	{
		"hero_id": "hero_veilmourn_nacre_vowless",
		"hero_name": "Nacre Vowless",
		"faction_id": "faction_veilmourn",
		"archetype": "funeralhexer",
		"fixture_scenario_id": "bellwake-wreck-claim",
		"roster_index": 8,
		"source_path": "res://art/heroes/source/curated/hero_veilmourn_nacre_vowless.png",
		"source_sha256": "8b5518b76431926bcd6c37a7b53ef6255888056d4dcc7444f01c373ef794bee7",
		"portrait_path": "res://art/heroes/portraits/hero_veilmourn_nacre_vowless.png",
		"portrait_sha256": "222df66b07e83e832b6a1f2e47e3a0b3145acdba3d63a765956ac7ce5f585a87",
		"starting_spell_ids": ["spell_obituary_mark", "spell_stone_veil", "spell_briar_bind"],
		"starting_specialties": ["spellwright"],
		"battle_traits": ["ambusher", "bogwise"],
		"command": {"attack": 0, "defense": 0, "power": 3, "knowledge": 1},
		"base_movement": 11,
		"recruit_cost": {"gold": 1250},
	},
	{
		"hero_id": "hero_veilmourn_orso_nightchart",
		"hero_name": "Orso Nightchart",
		"faction_id": "faction_veilmourn",
		"archetype": "routediviner",
		"fixture_scenario_id": "bellwake-wreck-claim",
		"roster_index": 9,
		"source_path": "res://art/heroes/source/curated/hero_veilmourn_orso_nightchart.png",
		"source_sha256": "ead583409f8d92a8275ba7922dc029cffbc82c032265a84cbcb15f2f65a89034",
		"portrait_path": "res://art/heroes/portraits/hero_veilmourn_orso_nightchart.png",
		"portrait_sha256": "4aa6dd74b9050997eaaa58c5907397bfe91624d81531446b6539ade712eb7e40",
		"starting_spell_ids": ["spell_fogwake_step", "spell_waystride", "spell_beacon_path"],
		"starting_specialties": ["wayfinder"],
		"battle_traits": ["ambusher", "linekeeper"],
		"command": {"attack": 0, "defense": 0, "power": 1, "knowledge": 4},
		"base_movement": 11,
		"recruit_cost": {"gold": 1250},
	},
]

var _active_case: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ContentService.clear_cache()
	if not _validate_curated_provenance():
		return
	if not await _validate_shared_component():
		return
	for case_value in CASES:
		_active_case = Dictionary(case_value).duplicate(true)
		if not _validate_roster_tavern_authority():
			return
		for viewport_size in VIEWPORT_SIZES:
			if not await _validate_overworld(viewport_size):
				return
			if not await _validate_town(viewport_size):
				return
			if not await _validate_battle(viewport_size):
				return
			if not await _validate_outcome(viewport_size):
				return
	print(REPORT_ID, " ", JSON.stringify({
		"ok": true,
		"hero_ids": CASES.map(func(row): return String(row.get("hero_id", ""))),
		"source_count": 9,
		"portrait_count": 9,
		"viewports": VIEWPORT_SIZES,
		"surfaces": ["component", "faction_roster", "tavern_action", "overworld", "town", "battle_player", "battle_enemy_authored", "outcome"],
		"enemy_unknown_hidden": true,
		"non_target_portrait_count": 57,
	}))
	get_tree().quit(0)


func _validate_curated_provenance() -> bool:
	if ContentService.get_content_ids(ContentService.HEROES_PATH).size() != 66:
		_fail("Hero roster must remain exactly 66 live records.")
		return false
	for case_value in CASES:
		var case: Dictionary = case_value
		var hero_id := String(case.get("hero_id", ""))
		var faction_id := String(case.get("faction_id", ""))
		var hero := ContentService.get_hero(hero_id)
		var art := ContentService.get_hero_art(hero_id)
		var faction := ContentService.get_faction(faction_id)
		var roster: Array = faction.get("hero_ids", [])
		var fixture_scenario := ContentService.get_scenario(String(case.get("fixture_scenario_id", "")))
		if String(hero.get("name", "")) != String(case.get("hero_name", "")) \
				or String(hero.get("faction_id", "")) != faction_id \
				or String(hero.get("archetype", "")) != String(case.get("archetype", "")) \
				or hero.get("starting_spell_ids", []) != case.get("starting_spell_ids", []) \
				or hero.get("starting_specialties", []) != case.get("starting_specialties", []) \
				or hero.get("battle_traits", []) != case.get("battle_traits", []) \
				or not _numeric_dictionary_exact(hero.get("command", {}), case.get("command", {})) \
				or int(hero.get("base_movement", 0)) != int(case.get("base_movement", 0)) \
				or not _numeric_dictionary_exact(hero.get("recruit_cost", {}), case.get("recruit_cost", {})):
			_fail("Hero gameplay authority changed for %s: %s" % [hero_id, JSON.stringify(hero)])
			return false
		if roster.find(hero_id) != int(case.get("roster_index", -1)) \
				or String(fixture_scenario.get("player_faction_id", "")) != faction_id \
				or String(fixture_scenario.get("hero_id", "")) == hero_id \
				or RandomMapGeneratorRules.DEFAULT_HERO_BY_FACTION.values().has(hero_id):
			_fail("Faction roster/fixture/default authority changed for %s." % hero_id)
			return false
		if String(art.get("source_kind", "")) != "curated_original_character" \
				or String(art.get("source_path", "")) != String(case.get("source_path", "")) \
				or String(art.get("source_sha256", "")) != String(case.get("source_sha256", "")) \
				or String(art.get("portrait", "")) != String(case.get("portrait_path", "")):
			_fail("Curated manifest provenance changed for %s: %s" % [hero_id, JSON.stringify(art)])
			return false
		var source_path := String(case.get("source_path", ""))
		var portrait_path := String(case.get("portrait_path", ""))
		var source_image := _load_png(source_path)
		var portrait_image := _load_png(portrait_path)
		if source_image == null or source_image.get_size() != Vector2i(1254, 1254) \
				or portrait_image == null or portrait_image.get_size() != Vector2i(384, 512) \
				or FileAccess.get_sha256(source_path) != String(case.get("source_sha256", "")) \
				or FileAccess.get_sha256(portrait_path) != String(case.get("portrait_sha256", "")):
			_fail("Curated source/runtime bytes changed for %s." % hero_id)
			return false
	return true


func _validate_roster_tavern_authority() -> bool:
	var session = ScenarioFactory.create_session(String(_active_case.get("fixture_scenario_id", "")), "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var town := _first_player_town(session)
	if town.is_empty():
		_fail("Final-nine portrait tavern fixture has no player town.")
		return false
	_move_active_hero_to_town(session, town)
	var buildings: Array = town.get("built_buildings", []).duplicate(true)
	if HeroCommandRules.HALL_BUILDING_ID not in buildings:
		buildings.append(HeroCommandRules.HALL_BUILDING_ID)
	town["built_buildings"] = buildings
	var authority_before: Dictionary = session.to_dict()
	var hero_id := String(_active_case.get("hero_id", ""))
	var recruitable: Array = HeroCommandRules.recruitable_hero_ids(session)
	var actions: Array = TownRules.get_tavern_actions(session)
	var action_id := "hire_hero:%s" % hero_id
	var matching_actions := actions.filter(func(row): return row is Dictionary and String(row.get("id", "")) == action_id)
	if hero_id not in recruitable or matching_actions.size() != 1 or session.to_dict() != authority_before:
		_fail("Final-nine portrait tavern authority failed for %s: %s" % [hero_id, JSON.stringify(actions)])
		return false
	return true


func _validate_shared_component() -> bool:
	var portrait := HeroPortraitView.new()
	portrait.custom_minimum_size = Vector2(64.0, 86.0)
	add_child(portrait)
	await get_tree().process_frame
	var hero_ids: Array[String] = ContentService.get_content_ids(ContentService.HEROES_PATH)
	var paths := {}
	for hero_id in hero_ids:
		if not portrait.set_hero_id(hero_id):
			_fail("Shared portrait rejected authored hero %s." % hero_id)
			return false
		var snapshot: Dictionary = portrait.validation_snapshot()
		var expected_path := String(ContentService.get_hero_art(hero_id).get("portrait", ""))
		if String(snapshot.get("hero_id", "")) != hero_id \
			or String(snapshot.get("portrait_path", "")) != expected_path \
			or not bool(snapshot.get("visible", false)) \
			or paths.has(expected_path):
			_fail("Shared portrait authority mismatch for %s: %s" % [hero_id, JSON.stringify(snapshot)])
			return false
		paths[expected_path] = true
	if hero_ids.size() != 66 or paths.size() != 66:
		_fail("Shared portrait coverage must remain 66 unique heroes.")
		return false
	if portrait.set_hero_id("hero_not_authored") or portrait.visible or portrait.texture != null or portrait.tooltip_text != "":
		_fail("Shared portrait did not fail closed for an unknown hero.")
		return false
	portrait.queue_free()
	await get_tree().process_frame
	return true


func _validate_overworld(viewport_size: Vector2i) -> bool:
	var session = _new_session()
	OverworldRules.consume_command_briefing(session)
	var authority_before: Dictionary = session.to_dict()
	SessionState.set_active_session(session)
	var frame := _new_frame("OverworldFrame", viewport_size)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	frame.add_child(shell)
	await _settle_shell()
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var ok := _portrait_exact(snapshot.get("hero_portrait", {}), String(_active_case.get("hero_id", "")), String(_active_case.get("portrait_path", ""))) \
		and _portrait_contained(frame, shell.get_node("%HeroPortrait"), viewport_size) \
		and SessionState.ensure_active_session().to_dict() == authority_before
	if not ok:
		_fail("Overworld portrait authority failed at %s: %s" % [viewport_size, JSON.stringify(snapshot.get("hero_portrait", {}))])
	await _remove_shell(frame)
	return ok


func _validate_town(viewport_size: Vector2i) -> bool:
	var session = _new_session()
	var town := _first_player_town(session)
	if town.is_empty():
		_fail("Town portrait fixture has no player town.")
		return false
	_move_active_hero_to_town(session, town)
	OverworldRules.normalize_overworld_state_for_runtime(session)
	session.game_state = "town"
	var authority_before: Dictionary = session.to_dict()
	SessionState.set_active_session(session)
	var frame := _new_frame("TownFrame", viewport_size)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	frame.add_child(shell)
	await _settle_shell()
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var ok := _portrait_exact(snapshot.get("hero_portrait", {}), String(_active_case.get("hero_id", "")), String(_active_case.get("portrait_path", ""))) \
		and _portrait_contained(frame, shell.get_node("%HeroPortrait"), viewport_size) \
		and SessionState.ensure_active_session().to_dict() == authority_before
	if not ok:
		_fail("Town portrait authority failed at %s: %s" % [viewport_size, JSON.stringify(snapshot.get("hero_portrait", {}))])
	await _remove_shell(frame)
	return ok


func _validate_battle(viewport_size: Vector2i) -> bool:
	var session = _new_session()
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		_fail("Battle portrait fixture has no encounter.")
		return false
	session.battle = BattleRules.create_battle_payload(session, encounter)
	var enemy_hero = session.battle.get("enemy_hero", {})
	if enemy_hero is Dictionary:
		enemy_hero["id"] = ""
		enemy_hero["artifacts"] = ArtifactRules.normalize_hero_artifacts(enemy_hero.get("artifacts", {}))
		session.battle["enemy_hero"] = enemy_hero
	OverworldRules.normalize_overworld_state(session)
	if not BattleRules.normalize_battle_state(session):
		_fail("Battle portrait fixture could not normalize the battle payload.")
		return false
	BattleRules.set_battle_presentation_speed(session, SettingsService.battle_playback_speed_id())
	BattleRules.resolve_if_battle_ready(session)
	BattleRules.consume_tactical_briefing(session)
	session.game_state = "battle"
	var authority_before: Dictionary = session.to_dict()
	SessionState.set_active_session(session)
	var frame := _new_frame("BattleFrame", viewport_size)
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	frame.add_child(shell)
	await _settle_shell()
	var hidden_snapshot: Dictionary = shell.call("validation_snapshot")
	var player_ok := _portrait_exact(hidden_snapshot.get("player_commander_portrait", {}), String(_active_case.get("hero_id", "")), String(_active_case.get("portrait_path", ""))) \
		and _portrait_contained(frame, shell.get_node("%PlayerCommanderPortrait"), viewport_size)
	var hidden_enemy: Dictionary = hidden_snapshot.get("enemy_commander_portrait", {})
	if not player_ok or bool(hidden_enemy.get("visible", true)) or String(hidden_enemy.get("hero_id", "")) != "":
		_fail("Battle portrait initial authority failed at %s: %s" % [viewport_size, JSON.stringify(hidden_snapshot)])
		await _remove_shell(frame)
		return false
	if SessionState.ensure_active_session().to_dict() != authority_before:
		_fail("Battle shell changed session authority before authored enemy refresh.")
		await _remove_shell(frame)
		return false
	var authored_enemy_id := _other_authored_hero_id()
	var authored_enemy_path := String(ContentService.get_hero_art(authored_enemy_id).get("portrait", ""))
	var live_session = SessionState.ensure_active_session()
	enemy_hero = live_session.battle.get("enemy_hero", {})
	enemy_hero["id"] = authored_enemy_id
	live_session.battle["enemy_hero"] = enemy_hero
	shell.call("_refresh")
	await get_tree().process_frame
	var authored_snapshot: Dictionary = shell.call("validation_snapshot")
	var enemy_ok := _portrait_exact(authored_snapshot.get("enemy_commander_portrait", {}), authored_enemy_id, authored_enemy_path) \
		and _portrait_contained(frame, shell.get_node("%EnemyCommanderPortrait"), viewport_size)
	if not enemy_ok:
		_fail("Battle authored enemy portrait failed at %s: %s" % [viewport_size, JSON.stringify(authored_snapshot.get("enemy_commander_portrait", {}))])
	await _remove_shell(frame)
	return enemy_ok


func _validate_outcome(viewport_size: Vector2i) -> bool:
	var session = _new_session()
	session.scenario_status = "victory"
	session.game_state = "outcome"
	session.scenario_summary = "Portrait outcome fixture."
	OverworldRules.normalize_overworld_state(session)
	var authority_before: Dictionary = session.to_dict()
	SessionState.set_active_session(session)
	var frame := _new_frame("OutcomeFrame", viewport_size)
	var shell = load("res://scenes/results/ScenarioOutcomeShell.tscn").instantiate()
	frame.add_child(shell)
	await _settle_shell()
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var ok := _portrait_exact(snapshot.get("hero_portrait", {}), String(_active_case.get("hero_id", "")), String(_active_case.get("portrait_path", ""))) \
		and _portrait_contained(frame, shell.get_node("%HeroPortrait"), viewport_size) \
		and SessionState.ensure_active_session().to_dict() == authority_before
	if not ok:
		_fail("Outcome portrait authority failed at %s: %s" % [viewport_size, JSON.stringify(snapshot.get("hero_portrait", {}))])
	await _remove_shell(frame)
	return ok


func _new_session():
	var session = ScenarioFactory.create_session(String(_active_case.get("fixture_scenario_id", "")), "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	_configure_active_hero(session, String(_active_case.get("hero_id", "")))
	return session


func _configure_active_hero(session, hero_id: String) -> void:
	var heroes: Array = session.overworld.get("player_heroes", [])
	var source: Dictionary = heroes[0] if not heroes.is_empty() and heroes[0] is Dictionary else {}
	var template := ContentService.get_hero(hero_id)
	var position: Dictionary = source.get("position", session.overworld.get("hero_position", {})).duplicate(true)
	var army: Dictionary = source.get("army", session.overworld.get("army", {})).duplicate(true)
	var hero: Dictionary = HeroCommandRules.build_hero_from_template(template, position, army, session)
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


func _portrait_exact(value: Variant, hero_id: String, portrait_path: String) -> bool:
	if not (value is Dictionary):
		return false
	var hero := ContentService.get_hero(hero_id)
	return bool(value.get("visible", false)) \
		and String(value.get("hero_id", "")) == hero_id \
		and String(value.get("portrait_path", "")) == portrait_path \
		and String(value.get("tooltip_text", "")) == "%s portrait" % String(hero.get("name", hero_id))


func _numeric_dictionary_exact(actual_value: Variant, expected_value: Variant) -> bool:
	if not (actual_value is Dictionary) or not (expected_value is Dictionary):
		return false
	var actual: Dictionary = actual_value
	var expected: Dictionary = expected_value
	if actual.size() != expected.size():
		return false
	for key in expected:
		if not actual.has(key) or float(actual.get(key, 0.0)) != float(expected.get(key, 0.0)):
			return false
	return true


func _load_png(path: String) -> Image:
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return image


func _portrait_contained(frame: Control, portrait: Control, viewport_size: Vector2i) -> bool:
	var frame_rect := Rect2(frame.global_position, frame.size)
	var portrait_rect := Rect2(portrait.global_position, portrait.size)
	var contained := frame.size == Vector2(viewport_size) \
		and portrait.visible \
		and portrait.size.x > 0.0 \
		and portrait.size.y > 0.0 \
		and frame_rect.encloses(portrait_rect)
	if not contained:
		print("FIVE_FACTION_ROSTER_FINAL_NINE_PORTRAIT_GEOMETRY ", JSON.stringify({
			"requested": viewport_size,
			"frame_position": frame.global_position,
			"frame_size": frame.size,
			"portrait_position": portrait.global_position,
			"portrait_size": portrait.size,
			"portrait_visible": portrait.visible,
			"enclosed": frame_rect.encloses(portrait_rect),
		}))
	return contained


func _new_frame(frame_name: String, viewport_size: Vector2i) -> Control:
	var frame := Control.new()
	frame.name = frame_name
	frame.custom_minimum_size = Vector2(viewport_size)
	frame.size = Vector2(viewport_size)
	add_child(frame)
	return frame


func _settle_shell() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _remove_shell(shell: Node) -> void:
	shell.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _first_player_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return town
	return {}


func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			heroes[index] = hero.duplicate(true)
	session.overworld["player_heroes"] = heroes


func _first_encounter(session) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary:
			return encounter
	return {}


func _other_authored_hero_id() -> String:
	return "hero_mira" if String(_active_case.get("hero_id", "")) == "hero_caelen" else "hero_caelen"


func _fail(message: String) -> void:
	push_error(message)
	print(REPORT_ID, " ", JSON.stringify({"ok": false, "error": message}))
	get_tree().quit(1)
