extends Node

# Who stays in the game on a generated map (owner decisions 2026-10-09):
# losing the starting hero does not end the game, another hero leads and the
# fallen one is not brought back; a player with no town and no hero left is
# out; a player that holds no town for seven days is out, the human with a
# defeat and a countdown before it, a computer player by its heroes leaving.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const EliminationRules = preload("res://scripts/core/PlayerEliminationRules.gd")
const AiHeroRulesScript = preload("res://scripts/core/AiHeroRules.gd")
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const REPORT_ID := "PLAYER_ELIMINATION_RULES_REPORT"
const SEED := "player-elimination-20261009"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	var results := {}
	results["starting_hero_falls_another_leads"] = _check_starting_hero_falls(true)
	if _failed:
		return
	results["last_hero_falls_town_held"] = _check_starting_hero_falls(false)
	if _failed:
		return
	results["last_hero_falls_without_town"] = _check_last_hero_without_town()
	if _failed:
		return
	results["human_without_town_seven_days"] = _check_human_townless()
	if _failed:
		return
	results["computer_without_town_seven_days"] = _check_computer_townless()
	if _failed:
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "cases": results})])
	ContentService.clear_generated_scenario_drafts()
	get_tree().quit(0)

## The human's starting hero loses a battle. With a second hero the game goes
## on under that hero; with none, it goes on with the towns and no hero, and the
## fallen hero is not rebuilt from the scenario.
func _check_starting_hero_falls(second_hero: bool) -> Dictionary:
	var session = _start_session()
	if session == null:
		return {}
	var fallen_id := String(session.hero_id)
	var second_id := ""
	if second_hero:
		second_id = _add_second_hero(session)
	_lose_battle(session)
	if String(session.scenario_status) != "in_progress":
		_fail("Losing the starting hero ended the game (%s, second hero %s)." % [String(session.scenario_status), second_hero])
		return {}
	HeroCommandRules.normalize_session(session)
	var ids := []
	for hero in session.overworld.get("player_heroes", []):
		ids.append(String(hero.get("id", "")))
	if ids.has(fallen_id):
		_fail("The fallen starting hero %s came back after normalization: %s." % [fallen_id, JSON.stringify(ids)])
		return {}
	if second_hero and (String(session.hero_id) != second_id or not bool(HeroCommandRules.hero_by_id(session, second_id).get("is_primary", false))):
		_fail("The second hero %s does not lead after the starting hero fell (lead %s)." % [second_id, String(session.hero_id)])
		return {}
	if not second_hero and not ids.is_empty():
		_fail("Heroes appeared after the last hero fell: %s." % JSON.stringify(ids))
		return {}
	return {"fallen": fallen_id, "leads": String(session.hero_id), "heroes": ids}

## The last hero falls with no town held: the game is lost at once.
func _check_last_hero_without_town() -> Dictionary:
	var session = _start_session()
	if session == null:
		return {}
	_give_away_human_towns(session)
	_lose_battle(session)
	if String(session.scenario_status) != "defeat":
		_fail("Losing the last hero with no town left did not end the game (%s)." % String(session.scenario_status))
		return {}
	return {"status": String(session.scenario_status), "summary": String(session.scenario_summary)}

## The human holds no town: six days of warnings, a defeat on the seventh.
func _check_human_townless() -> Dictionary:
	var session = _start_session()
	if session == null:
		return {}
	_give_away_human_towns(session)
	var warnings := 0
	var defeat_day := -1
	for _day in range(EliminationRules.TOWNLESS_DAYS + 2):
		var result: Dictionary = OverworldRules.end_turn(session)
		_settle_battle(session)
		if String(result.get("message", "")).contains("You hold no town"):
			warnings += 1
		if String(session.scenario_status) == "defeat":
			defeat_day = int(session.day)
			break
	if defeat_day < 0:
		_fail("Seven days without a town did not end the game (day %d, %d warnings)." % [int(session.day), warnings])
		return {}
	if warnings < EliminationRules.TOWNLESS_DAYS - 1:
		_fail("Only %d warnings before the townless defeat on day %d." % [warnings, defeat_day])
		return {}
	return {"warnings": warnings, "defeat_day": defeat_day}

## A computer player holds no town for seven days: its heroes leave the map
## and it no longer counts as standing.
func _check_computer_townless() -> Dictionary:
	var session = _start_session()
	if session == null:
		return {}
	var rival := ""
	for player in session.overworld.get("players", []):
		if player is Dictionary and not bool(player.get("human", false)):
			rival = String(player.get("player_id", ""))
	# Two days in: it has hired its first hero.
	for _day in range(2):
		OverworldRules.end_turn(session)
		_settle_battle(session)
	if AiHeroRulesScript.active_hero_count(session, rival) == 0:
		_fail("The computer player has no hero on day %d." % int(session.day))
		return {}
	var townless_from := int(session.day)
	# Its towns go neutral behind walls it cannot storm, so it stays townless.
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town: Dictionary = towns[index]
		if String(town.get("owner", "")) == "enemy" and PlayerRules.town_controller_id(town) == rival:
			town["owner"] = "neutral"
			town.erase("controller_id")
			town.erase("player_id")
			town["garrison"] = [{"unit_id": "unit_ember_archer", "count": 5000}]
			towns[index] = town
	session.overworld["towns"] = towns
	var out_day := -1
	for _day in range(EliminationRules.TOWNLESS_DAYS + 3):
		OverworldRules.end_turn(session)
		_settle_battle(session)
		if AiHeroRulesScript.active_hero_count(session, rival) == 0:
			out_day = int(session.day)
			break
	if out_day < 0:
		_fail("A computer player without a town for seven days still has %d heroes on day %d." % [AiHeroRulesScript.active_hero_count(session, rival), int(session.day)])
		return {}
	if out_day - townless_from < EliminationRules.TOWNLESS_DAYS:
		_fail("A computer player left the war on day %d, only %d days after losing its towns." % [out_day, out_day - townless_from])
		return {}
	return {"rival": rival, "townless_from": townless_from, "out_day": out_day}

func _start_session():
	ContentService.clear_generated_scenario_drafts()
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		SEED, "", "", 2, "land", false, "homm3_small",
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,
		"faction_embercourt", "hero_lyra"
	)
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	if not bool(setup.get("ok", false)):
		_fail("Generated setup failed: %s" % JSON.stringify(setup).left(400))
		return null
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or session.scenario_id == "":
		_fail("Generated session could not start.")
		return null
	session.session_id = "player-elimination-%s" % SEED
	OverworldRules.normalize_overworld_state(session)
	if not EliminationRules.applies(session):
		_fail("The elimination rules do not apply to a generated session.")
		return null
	return session

func _add_second_hero(session) -> String:
	var primary: Dictionary = HeroCommandRules.active_hero(session)
	var template := {}
	for hero_id in ContentService.get_faction("faction_embercourt").get("hero_ids", []):
		if String(hero_id) != String(primary.get("id", "")):
			template = ContentService.get_hero(String(hero_id))
			break
	if template.is_empty():
		_fail("No second Embercourt hero to hire.")
		return ""
	var hero := HeroCommandRules.build_hero_from_template(template, primary.get("position", {}), {"id": "second_army", "name": "Field Army", "stacks": [{"unit_id": "unit_ember_archer", "count": 3}]}, session)
	hero["is_primary"] = false
	var heroes: Array = session.overworld.get("player_heroes", [])
	heroes.append(hero)
	session.overworld["player_heroes"] = heroes
	return String(hero.get("id", ""))

func _give_away_human_towns(session) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town: Dictionary = towns[index]
		if String(town.get("owner", "")) == "player":
			town["owner"] = "neutral"
			town.erase("controller_id")
			town.erase("player_id")
			towns[index] = town
	session.overworld["towns"] = towns

## The starting hero, with a single creature, attacks the strongest guard on
## the map and the battle is auto-resolved through the player's battle rules.
func _lose_battle(session) -> void:
	var primary_id := String(session.hero_id)
	session.overworld["active_hero_id"] = primary_id
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if String(heroes[index].get("id", "")) == primary_id:
			heroes[index]["army"] = {"id": "doomed", "name": "Field Army", "stacks": [{"unit_id": "unit_ember_archer", "count": 1}]}
	session.overworld["player_heroes"] = heroes
	HeroCommandRules.normalize_session(session)
	var strongest := {}
	var strongest_power := -1.0
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and PlayerRules.raid_controller_id(encounter) == "" and not OverworldRules.is_encounter_resolved(session, encounter):
			var power := AiHeroRulesScript._guard_power(encounter)
			if power > strongest_power:
				strongest_power = power
				strongest = encounter
	var payload: Dictionary = BattleRules.create_battle_payload(session, strongest)
	if payload.is_empty():
		_fail("Could not start a battle against %s." % String(strongest.get("placement_id", "")))
		return
	session.battle = payload
	session.game_state = "battle"
	BattleAutoResolveRulesScript.resolve_active_battle(session)
	if not session.battle.is_empty():
		_fail("The lost battle did not finish.")

func _settle_battle(session) -> void:
	if not session.battle.is_empty():
		BattleAutoResolveRulesScript.resolve_active_battle(session)
		if session.battle.is_empty() and String(session.scenario_status) == "in_progress":
			session.game_state = "overworld"

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
