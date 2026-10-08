extends Node

# A whole game with no human player: two computer players on a small generated
# one-level map, each faction drawn at random (a mirror match is possible),
# played day by day until one side holds no town and no hero. Every
# auto-resolved fight goes into a battle log and every day into a ledger per
# side; the full record is written as JSON for the battle report.
#
# HEROES_AI_MATCH_SEED     match seed (factions and map); "random" draws one.
# HEROES_AI_MATCH_MAX_DAYS day cap for an undecided match (default 160).
# HEROES_AI_MATCH_OUT      where the JSON record goes (default user://).
# HEROES_AI_MATCH_TRACE    1 prints each day's heroes, goals and towns.
# HEROES_AI_MATCH_SWAP     1 plays the same map with the factions' starting
#                          places swapped, to tell map balance from faction.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const AiHeroRulesScript = preload("res://scripts/core/AiHeroRules.gd")
const AiSeatRulesScript = preload("res://scripts/core/AiSeatRules.gd")
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const REPORT_ID := "AI_VERSUS_AI_MATCH_REPORT"
const DEFAULT_SEED := "ai-match-20261008"
const DEFAULT_MAX_DAYS := 160
const DEFAULT_OUT := "user://ai_versus_ai_match.json"
## The regression run stops here; a full match is an evaluation, not a test.
const TEST_DAYS := 40
## In the regression run's 40 days (capitals 9 tiles apart) a town may fall to
## the other player without a fight at most this often. Before towns were
## defended 45 of 48 captures were; with defense and the 2026-10-08 battle
## stat scaling the match is decided on day 17 with 9 of 11.
const MAX_UNOPPOSED_CAPTURES := 12

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	var match_seed := OS.get_environment("HEROES_AI_MATCH_SEED").strip_edges()
	var full_match := match_seed != ""
	if match_seed == "random":
		var draw := RandomNumberGenerator.new()
		draw.randomize()
		match_seed = "ai-match-%d" % draw.randi()
	elif match_seed == "":
		match_seed = DEFAULT_SEED
	var max_days := int(OS.get_environment("HEROES_AI_MATCH_MAX_DAYS")) if OS.get_environment("HEROES_AI_MATCH_MAX_DAYS") != "" else (DEFAULT_MAX_DAYS if full_match else TEST_DAYS)
	var swapped := OS.get_environment("HEROES_AI_MATCH_SWAP").strip_edges() not in ["", "0"]
	var trace := OS.get_environment("HEROES_AI_MATCH_TRACE").strip_edges() not in ["", "0"]
	var out_path := OS.get_environment("HEROES_AI_MATCH_OUT").strip_edges()
	if out_path == "":
		out_path = DEFAULT_OUT

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(match_seed)
	var faction_ids := []
	for option in ScenarioSelectRulesScript.random_map_faction_options():
		faction_ids.append(String(option.get("id", "")))
	faction_ids.sort()
	var drawn := [String(faction_ids[rng.randi_range(0, faction_ids.size() - 1)]), String(faction_ids[rng.randi_range(0, faction_ids.size() - 1)])]
	var map_seed := str(rng.randi())

	var session = _start_session(map_seed, drawn[0])
	if session == null:
		return
	var seats := []
	for record in session.overworld.get("players", []):
		seats.append(String(record.get("player_id", "")))
	if seats.size() != 2:
		_fail("Expected a two-player map, got %s." % JSON.stringify(seats))
		return
	var start_treasury: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	if AiSeatRulesScript.hand_human_seat_to_ai(session) != seats[0]:
		_fail("The human seat could not be handed to the computer.")
		return
	# Swapping keeps the map and trades the two factions' starting places.
	var seat_factions := [drawn[1], drawn[0]] if swapped else drawn
	for index in range(seats.size()):
		if PlayerRules.faction_id(session, seats[index]) != String(seat_factions[index]):
			_refound_seat(session, seats[index], String(seat_factions[index]))
	session.flags[AiHeroRulesScript.BATTLE_LOG_FLAG] = true

	var handover := _check_handover(session, seats, seat_factions, start_treasury)
	if _failed:
		return

	var setup := {
		"match_seed": match_seed,
		"map_seed": map_seed,
		"swapped": swapped,
		"scenario_id": String(session.scenario_id),
		"map_size": session.overworld.get("map_size", {}),
		"start_treasury": _live_resources(start_treasury),
		"seats": [],
	}
	for seat in seats:
		var faction := ContentService.get_faction(PlayerRules.faction_id(session, seat))
		var capitals := []
		for entry in _towns_of(session, seat):
			capitals.append({"placement_id": String(entry.get("placement_id", "")), "name": _town_name(entry), "x": int(entry.get("x", 0)), "y": int(entry.get("y", 0))})
		setup.seats.append({"player_id": seat, "faction_id": PlayerRules.faction_id(session, seat), "faction": String(faction.get("name", "")), "towns": capitals})

	var ledger := []
	var timeline := []
	var heroes_seen := {}
	var captures_seen := [0]
	var ai_ms_max := 0
	var winner := ""
	ledger.append(_day_row(session, seats))
	while int(session.day) < max_days:
		var started := Time.get_ticks_msec()
		OverworldRules.end_turn(session)
		ai_ms_max = maxi(ai_ms_max, Time.get_ticks_msec() - started)
		if String(session.game_state) != "overworld" or not session.battle.is_empty():
			_fail("Day %d left the overworld (%s) with no human seat." % [int(session.day), String(session.game_state)])
			return
		_note_changes(session, seats, captures_seen, heroes_seen, timeline)
		if trace:
			_print_trace(session, seats)
		ledger.append(_day_row(session, seats))
		if AiSeatRulesScript.match_over(session):
			var standing := AiSeatRulesScript.standing_players(session)
			winner = String(standing[0]) if not standing.is_empty() else "none"
			break

	var battles: Array = session.flags.get(AiHeroRulesScript.BATTLE_LOG_KEY, [])
	var record := {
		"report_id": REPORT_ID,
		"setup": setup,
		"winner": winner,
		"final_day": int(session.day),
		"decided": winner != "",
		"day_cap": max_days,
		"ai_turn_ms_max": ai_ms_max,
		"battles": battles,
		"timeline": timeline,
		"heroes": heroes_seen.values(),
		"ledger": ledger,
	}
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(record, "  "))
		file.close()

	if battles.is_empty():
		_fail("No fight was logged in %d days." % int(session.day))
		return
	if not full_match:
		var unopposed := 0
		for event in timeline:
			if String(event.get("type", "")) == "town_captured" and String(event.get("from", "")) in seats and float(event.get("garrison_power", 0.0)) <= 0.0:
				unopposed += 1
		if unopposed > MAX_UNOPPOSED_CAPTURES:
			_fail("%d towns fell to the other player without a fight in %d days." % [unopposed, int(session.day)])
			return
	var fought := {}
	for battle in battles:
		fought[String(battle.get("player_id", ""))] = true
	if fought.size() < 2:
		_fail("Only %s fought in %d days." % [JSON.stringify(fought.keys()), int(session.day)])
		return
	var summary := {
		"ok": true,
		"match_seed": match_seed,
		"map_seed": map_seed,
		"factions": [setup.seats[0].faction_id, setup.seats[1].faction_id],
		"handover": handover,
		"winner": winner,
		"winner_faction": PlayerRules.faction_id(session, winner) if winner not in ["", "none"] else "",
		"final_day": int(session.day),
		"battles": battles.size(),
		"timeline_events": timeline.size(),
		"ai_turn_ms_max": ai_ms_max,
		"final": ledger[ledger.size() - 1],
		"out": ProjectSettings.globalize_path(out_path),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(summary)])
	_cleanup()
	get_tree().quit(0)

func _start_session(map_seed: String, faction_id: String):
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		map_seed, "", "", 2, "land", false, "homm3_small",
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,
		faction_id, ""
	)
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	if not bool(setup.get("ok", false)):
		_fail("Small generated setup failed: %s" % JSON.stringify(setup).left(600))
		return null
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or session.scenario_id == "":
		_fail("Small generated session could not start.")
		return null
	OverworldRules.normalize_overworld_state(session)
	return session

## The generator never gives two players one faction, and a swapped match keeps
## the map. A seat whose drawn faction differs from the generator's has its
## capital set up as that faction's starting capital instead.
func _refound_seat(session, seat: String, faction_id: String) -> void:
	var town_id := String(RandomMapGeneratorRules.DEFAULT_TOWN_BY_FACTION.get(faction_id, ""))
	var template := ContentService.get_town(town_id)
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town: Dictionary = towns[index]
		if String(town.get("owner", "")) != "enemy" or PlayerRules.town_controller_id(town) != seat:
			continue
		town["town_id"] = town_id
		town["faction_id"] = faction_id
		town["controlling_faction_id"] = faction_id
		town["built_buildings"] = template.get("starting_building_ids", []).duplicate(true)
		town["garrison"] = template.get("garrison", []).duplicate(true)
		town["available_recruits"] = {}
		towns[index] = town
	session.overworld["towns"] = towns
	var players: Array = session.overworld.get("players", [])
	for index in range(players.size()):
		if String(players[index].get("player_id", "")) == seat:
			players[index]["faction_id"] = faction_id
	session.overworld["players"] = players
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state: Dictionary = states[index]
		if PlayerRules.controller_id(state) == seat:
			state["faction_id"] = faction_id
			for key in ["commander_roster", "ai_tavern"]:
				state.erase(key)
			states[index] = state
	session.overworld["enemy_states"] = states
	OverworldRules.normalize_overworld_state(session)
	for index in range(towns.size()):
		var town: Dictionary = session.overworld.towns[index]
		if PlayerRules.town_controller_id(town) == seat and (town.get("available_recruits", {}) as Dictionary).is_empty():
			town["available_recruits"] = OverworldRules._seed_recruits_for_town(town)
			session.overworld.towns[index] = town

func _check_handover(session, seats: Array, drawn: Array, start_treasury: Dictionary) -> Dictionary:
	if PlayerRules.has_human_seat(session):
		_fail("A human seat is left after the handover.")
		return {}
	if not session.overworld.get("player_heroes", []).is_empty():
		_fail("Human heroes are left after the handover.")
		return {}
	var result := {}
	for index in range(seats.size()):
		var seat := String(seats[index])
		var state := _state(session, seat)
		if state.is_empty():
			_fail("%s has no computer player state." % seat)
			return {}
		if PlayerRules.faction_id(session, seat) != String(drawn[index]):
			_fail("%s plays %s, not the drawn %s." % [seat, PlayerRules.faction_id(session, seat), drawn[index]])
			return {}
		if _towns_of(session, seat).is_empty():
			_fail("%s holds no town." % seat)
			return {}
		if _live_resources(state.get("treasury", {})) != _live_resources(start_treasury):
			_fail("%s starts with %s, not %s." % [seat, JSON.stringify(state.get("treasury", {})), JSON.stringify(start_treasury)])
			return {}
		result[seat] = {"faction": String(drawn[index]), "towns": _towns_of(session, seat).size()}
	return result

func _state(session, seat: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and PlayerRules.controller_id(state) == seat:
			return state
	return {}

func _towns_of(session, seat: String) -> Array:
	var result := []
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "enemy" and PlayerRules.town_controller_id(town) == seat:
			result.append(town)
	return result

func _town_name(town: Dictionary) -> String:
	return String(EnemyTurnRules._town_name(town))

func _town(session, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}

func _live_resources(pool: Dictionary) -> Dictionary:
	var result := {}
	for key in pool:
		if int(pool[key]) != 0:
			result[String(key)] = int(pool[key])
	return result

## Town captures, hires and fallen heroes since yesterday. A town can change
## hands twice in one day, so captures come from the capture log.
func _note_changes(session, seats: Array, captures_seen: Array, heroes_seen: Dictionary, timeline: Array) -> void:
	var captures: Array = session.flags.get(AiHeroRulesScript.CAPTURE_LOG_KEY, [])
	for index in range(captures_seen[0], captures.size()):
		var logged: Dictionary = captures[index]
		var town := _town(session, String(logged.get("town_placement_id", "")))
		timeline.append({
			"day": int(logged.get("day", 0)),
			"type": "town_captured",
			"town": String(logged.get("town", "")),
			"x": int(town.get("x", 0)),
			"y": int(town.get("y", 0)),
			"from": String(logged.get("from", "")),
			"to": String(logged.get("player_id", "")),
			"hero": String(logged.get("hero", "")),
			"hero_power": snappedf(float(logged.get("hero_power", 0.0)), 0.1),
			"garrison_power": snappedf(float(logged.get("garrison_power", 0.0)), 0.1),
		})
	captures_seen[0] = captures.size()
	# Fallen heroes stay in the encounter list, marked resolved, so a hero
	# hired and beaten on one day is still seen.
	var resolved: Array = session.overworld.get("resolved_encounters", [])
	for entry in session.overworld.get("encounters", []):
		if not (entry is Dictionary) or not AiHeroRulesScript.is_ai_hero(entry):
			continue
		var seat := PlayerRules.raid_controller_id(entry)
		if seat not in seats:
			continue
		var placement_id := String(entry.get("placement_id", ""))
		var commander: Dictionary = entry.get("enemy_commander_state", {})
		if not heroes_seen.has(placement_id):
			heroes_seen[placement_id] = {"placement_id": placement_id, "player_id": seat, "hero": AiHeroRulesScript.hero_name(entry), "hired_day": int(session.day), "fell_day": 0}
			timeline.append({"day": int(session.day), "type": "hero_hired", "player_id": seat, "hero": AiHeroRulesScript.hero_name(entry)})
		var seen: Dictionary = heroes_seen[placement_id]
		if int(seen.get("fell_day", 0)) != 0:
			continue
		seen["level"] = int(commander.get("level", 1))
		seen["experience"] = int(commander.get("experience", 0))
		seen["power"] = snappedf(AiHeroRulesScript.hero_power(entry), 0.1)
		seen["battle_wins"] = int(commander.get("battle_wins", 0))
		if placement_id in resolved:
			seen["fell_day"] = int(session.day)
			timeline.append({"day": int(session.day), "type": "hero_fell", "player_id": seat, "hero": String(seen.hero)})

func _print_trace(session, seats: Array) -> void:
	for seat in seats:
		var heroes := []
		for entry in AiHeroRulesScript.active_hero_entries(session, seat):
			var goal: Dictionary = entry.get("ai_hero", {}).get("goal", {})
			heroes.append("%s(%d)@%d,%d>%s:%s" % [AiHeroRulesScript.hero_name(entry), int(AiHeroRulesScript.hero_power(entry)), int(entry.get("x", 0)), int(entry.get("y", 0)), String(goal.get("kind", "")), String(goal.get("id", "")).get_slice("_object_", 1)])
		var towns := []
		for town in _towns_of(session, seat):
			towns.append("%s@%d,%d g%d" % [_town_name(town), int(town.get("x", 0)), int(town.get("y", 0)), int(AiHeroRulesScript.army_power(town.get("garrison", []))) ])
		print("MATCH_TRACE d%d %s gold=%d %s | %s" % [int(session.day), seat, int(_state(session, seat).get("treasury", {}).get("gold", 0)), " ".join(heroes), " ".join(towns)])

func _day_row(session, seats: Array) -> Dictionary:
	var row := {"day": int(session.day), "sides": {}}
	for seat in seats:
		var state := _state(session, seat)
		var towns := _towns_of(session, seat)
		var buildings := 0
		var garrison_power := 0.0
		for town in towns:
			buildings += (town.get("built_buildings", []) as Array).size()
			garrison_power += AiHeroRulesScript.army_power(town.get("garrison", []))
		var heroes := []
		var hero_power := 0.0
		for entry in AiHeroRulesScript.active_hero_entries(session, seat):
			var power := AiHeroRulesScript.hero_power(entry)
			hero_power += power
			heroes.append({"hero": AiHeroRulesScript.hero_name(entry), "level": int(entry.get("enemy_commander_state", {}).get("level", 1)), "power": snappedf(power, 0.1), "x": int(entry.get("x", 0)), "y": int(entry.get("y", 0))})
		var sites := 0
		for node in session.overworld.get("resource_nodes", []):
			if node is Dictionary and PlayerRules.resource_controller_id(node) == seat:
				sites += 1
		row.sides[seat] = {
			"treasury": _live_resources(state.get("treasury", {})),
			"towns": towns.size(),
			"buildings": buildings,
			"heroes": heroes,
			"hero_power": snappedf(hero_power, 0.1),
			"garrison_power": snappedf(garrison_power, 0.1),
			"sites": sites,
			"explored": AiHeroRulesScript.explored_tile_count(state),
		}
	return row

func _cleanup() -> void:
	ContentService.clear_generated_scenario_drafts()

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	_cleanup()
	get_tree().quit(1)
