extends Node

const REPORT_ID := "CAMPAIGN_LEAD_CURATED_PORTRAIT_REPORT"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const CASES := [
	{
		"hero_id": "hero_solera",
		"hero_name": "Solera Prismarch",
		"faction_id": "faction_sunvault",
		"archetype": "marshal",
		"campaign_id": "campaign_shards_of_daybreak",
		"scenario_id": "prismhearth-watch",
		"generated_default_hero_id": "hero_solera",
		"source_path": "res://art/heroes/source/curated/hero_solera.png",
		"source_sha256": "da709332aad655d58bacde34eb2106ac0b938ad5cff4fd57b04de2c9ab451850",
		"portrait_path": "res://art/heroes/portraits/hero_solera.png",
		"portrait_sha256": "455b864439baac23ec0e51fcd4e986bb1e0c81fd93547b85e4c45a850bfa5414",
		"starting_spell_ids": ["spell_prism_bastion", "spell_resonant_chorus", "spell_stone_veil"],
		"starting_specialties": ["drillmaster"],
		"battle_traits": ["linekeeper", "artillerist"],
		"command": {"attack": 1, "defense": 2, "power": 0, "knowledge": 0},
		"base_movement": 11,
		"recruit_cost": {"gold": 1250},
	},
	{
		"hero_id": "hero_thornwake_silsa_bramblehound",
		"hero_name": "Silsa Bramble-Hound",
		"faction_id": "faction_thornwake",
		"archetype": "huntleader",
		"campaign_id": "campaign_frontier_claims",
		"scenario_id": "mireford-skirmish",
		"generated_default_hero_id": "hero_thornwake_ardren_briarmarshal",
		"source_path": "res://art/heroes/source/curated/hero_thornwake_silsa_bramblehound.png",
		"source_sha256": "5b7da93abfe6e2c42926a6749f71306eb4bd180636ce8f1c17a3c3fb0a70059e",
		"portrait_path": "res://art/heroes/portraits/hero_thornwake_silsa_bramblehound.png",
		"portrait_sha256": "47463a01b63ce9cb782b674521a3adb38dac0c4c70f6ba4351ab850ebe4487f3",
		"starting_spell_ids": ["spell_briar_bind", "spell_quickmarch_hymn", "spell_coal_rain"],
		"starting_specialties": ["drillmaster"],
		"battle_traits": ["vanguard", "packhunter"],
		"command": {"attack": 2, "defense": 0, "power": 1, "knowledge": 1},
		"base_movement": 10,
		"recruit_cost": {"gold": 1200},
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
		if not await _validate_menu():
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
		"source_count": 2,
		"portrait_count": 2,
		"viewports": VIEWPORT_SIZES,
		"surfaces": ["component", "campaign_menu", "overworld", "town", "battle_player", "battle_enemy_authored", "outcome"],
		"enemy_unknown_hidden": true,
		"non_target_portrait_count": 58,
	}))
	get_tree().quit(0)


func _validate_curated_provenance() -> bool:
	if ContentService.get_content_ids(ContentService.HEROES_PATH).size() != 60:
		_fail("Hero roster must remain exactly 60 live records.")
		return false
	for case_value in CASES:
		var case: Dictionary = case_value
		var hero_id := String(case.get("hero_id", ""))
		var hero := ContentService.get_hero(hero_id)
		var art := ContentService.get_hero_art(hero_id)
		var campaign := ContentService.get_campaign(String(case.get("campaign_id", "")))
		var scenario := ContentService.get_scenario(String(case.get("scenario_id", "")))
		if String(hero.get("name", "")) != String(case.get("hero_name", "")) \
				or String(hero.get("faction_id", "")) != String(case.get("faction_id", "")) \
				or String(hero.get("archetype", "")) != String(case.get("archetype", "")) \
				or hero.get("starting_spell_ids", []) != case.get("starting_spell_ids", []) \
				or hero.get("starting_specialties", []) != case.get("starting_specialties", []) \
				or hero.get("battle_traits", []) != case.get("battle_traits", []) \
				or not _numeric_dictionary_exact(hero.get("command", {}), case.get("command", {})) \
				or int(hero.get("base_movement", 0)) != int(case.get("base_movement", 0)) \
				or not _numeric_dictionary_exact(hero.get("recruit_cost", {}), case.get("recruit_cost", {})):
			_fail("Hero gameplay authority changed for %s: %s" % [hero_id, JSON.stringify(hero)])
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
		if String(campaign.get("starting_scenario_id", "")) != String(case.get("scenario_id", "")) \
				or String(scenario.get("hero_id", "")) != hero_id \
				or String(scenario.get("player_faction_id", "")) != String(case.get("faction_id", "")) \
				or RandomMapGeneratorRules.DEFAULT_HERO_BY_FACTION.get(String(case.get("faction_id", "")), "") != String(case.get("generated_default_hero_id", "")):
			_fail("Campaign/scenario/default-commander authority changed for %s." % hero_id)
			return false
	return true


func _validate_menu() -> bool:
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	shell.call("validation_open_campaign_stage")
	if not bool(shell.call("validation_select_campaign", String(_active_case.get("campaign_id", "")))) \
			or not bool(shell.call("validation_select_campaign_chapter", String(_active_case.get("scenario_id", "")))):
		_fail("Campaign menu could not select %s." % String(_active_case.get("scenario_id", "")))
		return false
	await get_tree().process_frame
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var ok := bool(snapshot.get("campaign_commander_portrait_visible", false)) \
		and String(snapshot.get("campaign_commander_portrait_path", "")) == String(_active_case.get("portrait_path", "")) \
		and String(snapshot.get("campaign_commander_portrait_tooltip", "")) == "%s portrait" % String(_active_case.get("hero_name", ""))
	if not ok:
		_fail("Campaign portrait did not follow %s: %s" % [String(_active_case.get("hero_id", "")), JSON.stringify(snapshot)])
	await _remove_shell(shell)
	return ok


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
	return ScenarioFactory.create_session(String(_active_case.get("scenario_id", "")), "normal", SessionState.LAUNCH_MODE_SKIRMISH)


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
		print("CAMPAIGN_LEAD_PORTRAIT_GEOMETRY ", JSON.stringify({
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
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["position"] = position.duplicate(true)
		session.overworld["hero"] = hero


func _first_encounter(session) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary:
			return encounter
	return {}


func _other_authored_hero_id() -> String:
	return "hero_thornwake_silsa_bramblehound" if String(_active_case.get("hero_id", "")) == "hero_solera" else "hero_solera"


func _fail(message: String) -> void:
	push_error(message)
	print(REPORT_ID, " ", JSON.stringify({"ok": false, "error": message}))
	get_tree().quit(1)
