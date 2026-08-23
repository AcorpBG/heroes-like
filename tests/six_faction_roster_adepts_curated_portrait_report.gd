extends Node

const REPORT_ID := "SIX_FACTION_ROSTER_ADEPTS_CURATED_PORTRAIT_REPORT"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const CASES := [
	{
		"hero_id": "hero_embercourt_orra_cinderquill",
		"hero_name": "Orra Cinderquill",
		"faction_id": "faction_embercourt",
		"archetype": "ashwrit",
		"fixture_scenario_id": "river-pass",
		"roster_index": 7,
		"source_path": "res://art/heroes/source/curated/hero_embercourt_orra_cinderquill.png",
		"source_sha256": "80ea797936619191ffd9386f3a1621f0e7ddbf82903a05c549428f516761e348",
		"portrait_path": "res://art/heroes/portraits/hero_embercourt_orra_cinderquill.png",
		"portrait_sha256": "b0b7fcd201db4240769c88ecf21e5ab487045ac2c9d57fa833468b3f7f8f600d",
		"starting_spell_ids": ["spell_cinder_burst", "spell_coal_rain", "spell_beacon_path"],
		"starting_specialties": ["spellwright"],
		"battle_traits": ["artillerist", "ambusher"],
		"command": {"attack": 0, "defense": 0, "power": 3, "knowledge": 1},
		"base_movement": 11,
		"recruit_cost": {"gold": 1250},
	},
	{
		"hero_id": "hero_mireclaw_brakka_mudkeel",
		"hero_name": "Brakka Mudkeel",
		"faction_id": "faction_mireclaw",
		"archetype": "bogplate",
		"fixture_scenario_id": "bogbound-oath",
		"roster_index": 5,
		"source_path": "res://art/heroes/source/curated/hero_mireclaw_brakka_mudkeel.png",
		"source_sha256": "a72f9d5f2afb08eb2d076fe9a82b9fa5cba6a7e8cc3335e3cf825892b13dbd50",
		"portrait_path": "res://art/heroes/portraits/hero_mireclaw_brakka_mudkeel.png",
		"portrait_sha256": "ee7e8bded17e54100a02844b0e2bfae3dc283965550af50938f239ea2786272a",
		"starting_spell_ids": ["spell_stone_veil", "spell_relay_drum", "spell_bloodwake_drum"],
		"starting_specialties": ["mustercaptain"],
		"battle_traits": ["linekeeper", "bogwise"],
		"command": {"attack": 1, "defense": 2, "power": 0, "knowledge": 0},
		"base_movement": 10,
		"recruit_cost": {"gold": 1150},
	},
	{
		"hero_id": "hero_sunvault_dovan_lenscaptain",
		"hero_name": "Dovan Lens-Captain",
		"faction_id": "faction_sunvault",
		"archetype": "relaysurveyor",
		"fixture_scenario_id": "prismhearth-watch",
		"roster_index": 5,
		"source_path": "res://art/heroes/source/curated/hero_sunvault_dovan_lenscaptain.png",
		"source_sha256": "75e29e323d5c61e1e773b6b0c58ab67664d8ac01fc8529c602a8bcf63645d95c",
		"portrait_path": "res://art/heroes/portraits/hero_sunvault_dovan_lenscaptain.png",
		"portrait_sha256": "3be2feea3d62020c7742a87996667f2faed79bb756ddf0f34015b151db4d8cc6",
		"starting_spell_ids": ["spell_beacon_path", "spell_prism_bastion", "spell_sunlance_arc"],
		"starting_specialties": ["borderwarden"],
		"battle_traits": ["artillerist", "ambusher"],
		"command": {"attack": 1, "defense": 1, "power": 0, "knowledge": 2},
		"base_movement": 12,
		"recruit_cost": {"gold": 1250},
	},
	{
		"hero_id": "hero_thornwake_osmund_pollenglass",
		"hero_name": "Osmund Pollenglass",
		"faction_id": "faction_thornwake",
		"archetype": "sporedoctor",
		"fixture_scenario_id": "mireford-skirmish",
		"roster_index": 6,
		"source_path": "res://art/heroes/source/curated/hero_thornwake_osmund_pollenglass.png",
		"source_sha256": "dc418795eccca21e4782ba8c25c49817d17b7539a0cd3f2dfaa55c68058742fc",
		"portrait_path": "res://art/heroes/portraits/hero_thornwake_osmund_pollenglass.png",
		"portrait_sha256": "827401f0d471c6010305e3858d858b74ce30c98cde5f84a82d83d465f515e406",
		"starting_spell_ids": ["spell_graft_mend", "spell_stone_veil", "spell_bulwark_litany"],
		"starting_specialties": ["spellwright"],
		"battle_traits": ["bogwise", "linekeeper"],
		"command": {"attack": 0, "defense": 1, "power": 1, "knowledge": 3},
		"base_movement": 11,
		"recruit_cost": {"gold": 1200},
	},
	{
		"hero_id": "hero_brasshollow_vellum_quench",
		"hero_name": "Vellum Quench",
		"faction_id": "faction_brasshollow",
		"archetype": "heatrice",
		"fixture_scenario_id": "orevein-contract",
		"roster_index": 5,
		"source_path": "res://art/heroes/source/curated/hero_brasshollow_vellum_quench.png",
		"source_sha256": "814574117a6560d3bcbedfac963956ed38568a4a54d717e376cfa707f4760765",
		"portrait_path": "res://art/heroes/portraits/hero_brasshollow_vellum_quench.png",
		"portrait_sha256": "04b7b7bfbdbfd96e700b44fb0b881eb7b268079b5fbd14d648a9fd3f34d3959d",
		"starting_spell_ids": ["spell_heat_rite", "spell_pressure_clause", "spell_stone_veil"],
		"starting_specialties": ["spellwright"],
		"battle_traits": ["artillerist", "linekeeper"],
		"command": {"attack": 0, "defense": 0, "power": 3, "knowledge": 1},
		"base_movement": 10,
		"recruit_cost": {"gold": 1250},
	},
	{
		"hero_id": "hero_veilmourn_morwen_wakeoracle",
		"hero_name": "Morwen Wakeoracle",
		"faction_id": "faction_veilmourn",
		"archetype": "fogprophet",
		"fixture_scenario_id": "bellwake-wreck-claim",
		"roster_index": 5,
		"source_path": "res://art/heroes/source/curated/hero_veilmourn_morwen_wakeoracle.png",
		"source_sha256": "c5a70609478b4c00269ea1252ab4d0f1ed898e5473f50b6eba16450e3df14138",
		"portrait_path": "res://art/heroes/portraits/hero_veilmourn_morwen_wakeoracle.png",
		"portrait_sha256": "1ec89232c4f1ad2a88182c99ee22a50423d31663f77d3994deae6d1ee914db80",
		"starting_spell_ids": ["spell_fogwake_step", "spell_obituary_mark", "spell_beacon_path"],
		"starting_specialties": ["spellwright"],
		"battle_traits": ["ambusher", "linekeeper"],
		"command": {"attack": 0, "defense": 0, "power": 2, "knowledge": 3},
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
		"source_count": 6,
		"portrait_count": 6,
		"viewports": VIEWPORT_SIZES,
		"surfaces": ["component", "faction_roster", "tavern_action", "overworld", "town", "battle_player", "battle_enemy_authored", "outcome"],
		"enemy_unknown_hidden": true,
		"non_target_portrait_count": 54,
	}))
	get_tree().quit(0)


func _validate_curated_provenance() -> bool:
	if ContentService.get_content_ids(ContentService.HEROES_PATH).size() != 60:
		_fail("Hero roster must remain exactly 60 live records.")
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
		_fail("Roster adept tavern fixture has no player town.")
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
		_fail("Roster adept tavern authority failed for %s: %s" % [hero_id, JSON.stringify(actions)])
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
	if hero_ids.size() != 60 or paths.size() != 60:
		_fail("Shared portrait coverage must remain 60 unique heroes.")
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
		print("SIX_FACTION_ROSTER_ADEPTS_PORTRAIT_GEOMETRY ", JSON.stringify({
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
