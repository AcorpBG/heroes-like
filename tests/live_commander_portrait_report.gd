extends Node

const REPORT_ID := "LIVE_COMMANDER_PORTRAIT_REPORT"
const SCENARIO_ID := "river-pass"
const EXPECTED_HERO_ID := "hero_lyra"
const EXPECTED_PATH := "res://art/heroes/portraits/hero_lyra.png"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ContentService.clear_cache()
	if not await _validate_shared_component():
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
		"hero_id": EXPECTED_HERO_ID,
		"portrait_path": EXPECTED_PATH,
		"viewports": VIEWPORT_SIZES,
		"surfaces": ["component", "overworld", "town", "battle_player", "battle_enemy_authored", "outcome"],
		"enemy_unknown_hidden": true,
	}))
	get_tree().quit(0)


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
	SessionState.set_active_session(session)
	var frame := _new_frame("OverworldFrame", viewport_size)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	frame.add_child(shell)
	await _settle_shell()
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var ok := _portrait_exact(snapshot.get("hero_portrait", {}), EXPECTED_HERO_ID, EXPECTED_PATH) \
		and _portrait_contained(frame, shell.get_node("%HeroPortrait"), viewport_size)
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
	SessionState.set_active_session(session)
	var frame := _new_frame("TownFrame", viewport_size)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	frame.add_child(shell)
	await _settle_shell()
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var ok := _portrait_exact(snapshot.get("hero_portrait", {}), EXPECTED_HERO_ID, EXPECTED_PATH) \
		and _portrait_contained(frame, shell.get_node("%HeroPortrait"), viewport_size)
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
		session.battle["enemy_hero"] = enemy_hero
	SessionState.set_active_session(session)
	var frame := _new_frame("BattleFrame", viewport_size)
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	frame.add_child(shell)
	await _settle_shell()
	var hidden_snapshot: Dictionary = shell.call("validation_snapshot")
	var player_ok := _portrait_exact(hidden_snapshot.get("player_commander_portrait", {}), EXPECTED_HERO_ID, EXPECTED_PATH) \
		and _portrait_contained(frame, shell.get_node("%PlayerCommanderPortrait"), viewport_size)
	var hidden_enemy: Dictionary = hidden_snapshot.get("enemy_commander_portrait", {})
	if not player_ok or bool(hidden_enemy.get("visible", true)) or String(hidden_enemy.get("hero_id", "")) != "":
		_fail("Battle portrait initial authority failed at %s: %s" % [viewport_size, JSON.stringify(hidden_snapshot)])
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
	session.scenario_summary = "Portrait outcome fixture."
	SessionState.set_active_session(session)
	var frame := _new_frame("OutcomeFrame", viewport_size)
	var shell = load("res://scenes/results/ScenarioOutcomeShell.tscn").instantiate()
	frame.add_child(shell)
	await _settle_shell()
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var ok := _portrait_exact(snapshot.get("hero_portrait", {}), EXPECTED_HERO_ID, EXPECTED_PATH) \
		and _portrait_contained(frame, shell.get_node("%HeroPortrait"), viewport_size)
	if not ok:
		_fail("Outcome portrait authority failed at %s: %s" % [viewport_size, JSON.stringify(snapshot.get("hero_portrait", {}))])
	await _remove_shell(frame)
	return ok


func _new_session():
	return ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)


func _portrait_exact(value: Variant, hero_id: String, portrait_path: String) -> bool:
	if not (value is Dictionary):
		return false
	var hero := ContentService.get_hero(hero_id)
	return bool(value.get("visible", false)) \
		and String(value.get("hero_id", "")) == hero_id \
		and String(value.get("portrait_path", "")) == portrait_path \
		and String(value.get("tooltip_text", "")) == "%s portrait" % String(hero.get("name", hero_id))


func _portrait_contained(frame: Control, portrait: Control, viewport_size: Vector2i) -> bool:
	var frame_rect := Rect2(frame.global_position, frame.size)
	var portrait_rect := Rect2(portrait.global_position, portrait.size)
	var contained := frame.size == Vector2(viewport_size) \
		and portrait.visible \
		and portrait.size.x > 0.0 \
		and portrait.size.y > 0.0 \
		and frame_rect.encloses(portrait_rect)
	if not contained:
		print("LIVE_COMMANDER_PORTRAIT_GEOMETRY ", JSON.stringify({
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
	for hero_id in ContentService.get_content_ids(ContentService.HEROES_PATH):
		if hero_id != EXPECTED_HERO_ID:
			return hero_id
	return ""


func _fail(message: String) -> void:
	push_error(message)
	print(REPORT_ID, " ", JSON.stringify({"ok": false, "error": message}))
	get_tree().quit(1)
