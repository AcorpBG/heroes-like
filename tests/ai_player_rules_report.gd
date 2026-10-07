extends Node

# Computer players play by the human's rules: real heroes that capture mines
# and fight guards through auto-resolve, towns that build and recruit with the
# treasury they hold, and no raid entities. Runs a small generated skirmish.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const AiHeroRulesScript = preload("res://scripts/core/AiHeroRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const LevelRules = preload("res://scripts/core/OverworldLevelRules.gd")
const REPORT_ID := "AI_PLAYER_RULES_REPORT"
const SEED := "ai-player-rules-20261007"
const PLAYER_FACTION_ID := "faction_embercourt"
const PLAYER_HERO_ID := "hero_lyra"
const DAYS := 16

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	var perf_size := OS.get_environment("HEROES_AI_RULES_PERF_SIZE").strip_edges()
	if perf_size != "":
		return _run_perf(perf_size, maxi(1, int(OS.get_environment("HEROES_AI_RULES_PERF_DAYS"))))
	var session = _start_session()
	if session == null:
		return
	var controller := _ai_controller(session)
	if controller == "":
		return _fail("The generated skirmish has no computer player.")

	var migration := _check_legacy_migration(session, controller)
	if _failed:
		return
	_fortify_idle_human(session)

	OS.set_environment("HEROES_STRATEGIC_AI_PROFILE", "1")
	var days := []
	var all_text := []
	var turn_ms_max := 0
	var ai_ms_max := 0
	var hero_steps := 0
	var hero_days := 0
	var battles_with_human := []
	var neutral_before := _unresolved_neutral_ids(session)
	for _day in range(DAYS):
		var positions := _hero_positions(session, controller)
		var started := Time.get_ticks_usec()
		var result: Dictionary = OverworldRules.end_turn(session)
		var elapsed := int((Time.get_ticks_usec() - started) / 1000)
		turn_ms_max = maxi(turn_ms_max, elapsed)
		var ai_ms := 0
		var ai_phases := {}
		for faction_profile in result.get("enemy_turn_profile", {}).get("factions", []):
			ai_ms += int(faction_profile.get("phases_ms", {}).get("total_ms", 0))
			ai_phases = faction_profile.get("phases_ms", {})
		ai_ms_max = maxi(ai_ms_max, ai_ms)
		all_text.append(String(result.get("message", "")))
		all_text.append(String(result.get("enemy_activity_summary", "")))
		for event in result.get("enemy_activity_events", []):
			if event is Dictionary:
				all_text.append(String(event.get("summary", "")))
		if not session.battle.is_empty():
			var battle_context: Dictionary = session.battle.get("context", {})
			battles_with_human.append({"day": int(session.day), "type": String(battle_context.get("type", "")), "name": String(session.battle.get("encounter_name", ""))})
			all_text.append(String(session.battle.get("encounter_name", "")))
			BattleAutoResolveRulesScript.resolve_active_battle(session)
			if session.battle.is_empty() and String(session.scenario_status) == "in_progress":
				session.game_state = "overworld"
		var after := _hero_positions(session, controller)
		for placement_id in after.keys():
			if positions.has(placement_id):
				var before: Vector2i = positions[placement_id]
				var now: Vector2i = after[placement_id]
				hero_steps += maxi(absi(now.x - before.x), absi(now.y - before.y))
				hero_days += 1
		days.append({"day": int(session.day), "ms": elapsed, "ai_ms": ai_ms, "ai_phases": ai_phases, "heroes": _hero_brief(session, controller), "gold": int(_state(session, controller).get("treasury", {}).get("gold", 0))})
		if String(session.scenario_status) != "in_progress":
			break
	OS.set_environment("HEROES_STRATEGIC_AI_PROFILE", "")
	all_text.append(EnemyTurnRules.describe_threats(session))
	for entry in AiHeroRulesScript.active_hero_entries(session, controller):
		all_text.append(OverworldRules.encounter_display_name(entry))

	var captured_mines := _controlled_mines(session, controller)
	print("%s_STAGE %s" % [REPORT_ID, JSON.stringify({"battles": battles_with_human, "ai_ms_max": ai_ms_max, "days": days, "mines": captured_mines, "fights": _guard_fight_evidence(session, neutral_before, all_text), "tiles_per_day": float(hero_steps) / float(maxi(1, hero_days)), "texts": all_text.slice(0, 12), "plans": _plan_brief(session, controller), "towns": _ai_town_brief(session, controller)})])
	if captured_mines.is_empty():
		return _fail("No AI hero captured a mine in %d days: %s" % [DAYS, JSON.stringify(days)])
	var fights := _guard_fight_evidence(session, neutral_before, all_text)
	if int(fights.get("guards_defeated", 0)) <= 0:
		return _fail("No AI hero fought a neutral guard through auto-resolve: %s" % JSON.stringify(fights))
	var raid_check := _no_raid_entities(session, all_text)
	if not bool(raid_check.get("ok", false)):
		return _fail("Raid entities or raid wording remain: %s" % JSON.stringify(raid_check))
	if hero_days > 0 and float(hero_steps) / float(hero_days) < 2.0:
		return _fail("AI heroes barely move (%d tiles over %d hero-days)." % [hero_steps, hero_days])
	var save_check := _check_save_round_trip(session, controller)
	if _failed:
		return
	var economy := _check_town_orders_pay_real_costs(session, controller)
	if _failed:
		return
	var market := _check_market_trades_like_the_player(session, controller)
	if _failed:
		return

	var payload := {
		"ok": true,
		"seed": SEED,
		"controller": controller,
		"days_played": days.size(),
		"migration": migration,
		"town_orders": economy,
		"save_round_trip": save_check,
		"market": market,
		"captured_mines": captured_mines,
		"guard_fights": fights,
		"hero_tiles_per_day": float(hero_steps) / float(maxi(1, hero_days)),
		"turn_ms_max": turn_ms_max,
		"ai_turn_ms_max": ai_ms_max,
		"battles_with_human": battles_with_human,
		"days": days,
		"raid_check": raid_check,
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_cleanup()
	get_tree().quit(0)

## Timing only: computer players on a bigger generated map for several days
## (HEROES_AI_RULES_PERF_SIZE / HEROES_AI_RULES_PERF_DAYS).
func _run_perf(size_class_id: String, day_count: int) -> void:
	var session = _start_session(size_class_id, 4)
	if session == null:
		return
	OS.set_environment("HEROES_STRATEGIC_AI_PROFILE", "1")
	var rows := []
	var ai_ms_max := 0
	for _day in range(day_count):
		var started := Time.get_ticks_usec()
		var result: Dictionary = OverworldRules.end_turn(session)
		var elapsed := int((Time.get_ticks_usec() - started) / 1000)
		var ai_ms := 0
		var factions := []
		for faction_profile in result.get("enemy_turn_profile", {}).get("factions", []):
			ai_ms += int(faction_profile.get("phases_ms", {}).get("total_ms", 0))
			factions.append(faction_profile.get("phases_ms", {}))
		ai_ms_max = maxi(ai_ms_max, ai_ms)
		var heroes := 0
		for state in session.overworld.get("enemy_states", []):
			heroes += AiHeroRulesScript.active_hero_count(session, PlayerRules.controller_id(state))
		rows.append({"day": int(session.day), "end_turn_ms": elapsed, "ai_ms": ai_ms, "ai_heroes": heroes, "factions": factions})
		if not session.battle.is_empty():
			BattleAutoResolveRulesScript.resolve_active_battle(session)
			if session.battle.is_empty() and String(session.scenario_status) == "in_progress":
				session.game_state = "overworld"
		if String(session.scenario_status) != "in_progress":
			break
	OS.set_environment("HEROES_STRATEGIC_AI_PROFILE", "")
	print("%s_PERF %s" % [REPORT_ID, JSON.stringify({"ok": true, "size": size_class_id, "ai_ms_max": ai_ms_max, "days": rows})])
	_cleanup()
	get_tree().quit(0)

func _start_session(size_class_id: String = "homm3_small", player_count: int = 2):
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		SEED,
		"",
		"",
		player_count,
		"land",
		false,
		size_class_id,
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,
		PLAYER_FACTION_ID,
		PLAYER_HERO_ID
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

## The human never moves in this run. A large army at home keeps a sensible AI
## from ending the game early, so the run shows it working the map instead.
func _fortify_idle_human(session) -> void:
	var army_id := String(RandomMapGeneratorRules.DEFAULT_ARMY_BY_FACTION.get(PLAYER_FACTION_ID, ""))
	var stacks := []
	for stack in ContentService.get_army_group(army_id).get("stacks", []):
		stacks.append({"unit_id": String(stack.get("unit_id", "")), "count": int(stack.get("count", 0)) * 40})
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero: Dictionary = heroes[index]
		hero["army"] = {"id": "%s_army" % String(hero.get("id", "")), "name": "Field Army", "stacks": stacks.duplicate(true)}
		heroes[index] = hero
	session.overworld["player_heroes"] = heroes
	session.overworld["army"] = {"id": "fortified", "name": "Field Army", "stacks": stacks.duplicate(true)}
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			town["garrison"] = stacks.duplicate(true)
	HeroCommandRules.normalize_session(session)

func _ai_controller(session) -> String:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary:
			return PlayerRules.controller_id(state)
	return ""

func _state(session, controller: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and PlayerRules.controller_id(state) == controller:
			return state
	return {}

## A save from the raid era: a commander's host becomes a hero, a commanderless
## column disbands into its town's garrison, and nothing raid-shaped remains.
func _check_legacy_migration(session, controller: String) -> Dictionary:
	var town := _first_ai_town(session, controller)
	if town.is_empty():
		_fail("The computer player owns no town.")
		return {}
	var faction_id := PlayerRules.faction_id(session, controller)
	var hero_ids: Array = ContentService.get_faction(faction_id).get("hero_ids", [])
	var hero_id := String(hero_ids[hero_ids.size() - 1])
	var entrance := LevelRules.town_entrance(town)
	var encounters: Array = session.overworld.get("encounters", [])
	var garrison_before := _headcount(town.get("garrison", []))
	encounters.append({
		"placement_id": "%s_raid_1" % controller,
		"encounter_id": "encounter_blackbranch_reavers",
		"x": int(entrance.get("x", 0)) + 2,
		"y": int(entrance.get("y", 0)),
		"difficulty": "pressure",
		"spawned_by_faction_id": faction_id,
		"spawned_by_player_id": controller if not PlayerRules.player(session, controller).is_empty() else "",
		"target_kind": "town",
		"target_placement_id": String(town.get("placement_id", "")),
		"enemy_army": {"id": "legacy", "name": "Raid Host", "stacks": [{"unit_id": "unit_blackbranch_cutthroat", "count": 12}]},
		"enemy_commander_state": {"roster_hero_id": hero_id, "name": String(ContentService.get_hero(hero_id).get("name", hero_id)), "level": 3},
		"days_active": 4,
	})
	encounters.append({
		"placement_id": "%s_raid_2" % controller,
		"encounter_id": "encounter_mire_raid",
		"x": int(entrance.get("x", 0)) - 2,
		"y": int(entrance.get("y", 0)),
		"spawned_by_faction_id": faction_id,
		"spawned_by_player_id": controller if not PlayerRules.player(session, controller).is_empty() else "",
		"commanderless_support_column": true,
		"enemy_army": {"id": "column", "name": "Support Column", "stacks": [{"unit_id": "unit_mire_slinger", "count": 9}]},
	})
	session.overworld["encounters"] = encounters
	# A save from before computer players fielded heroes carries no migration mark.
	session.overworld.erase(AiHeroRulesScript.MIGRATION_KEY)
	EnemyTurnRules.normalize_enemy_states(session)
	if int(session.overworld.get(AiHeroRulesScript.MIGRATION_KEY, 0)) != AiHeroRulesScript.MIGRATION_VERSION:
		_fail("The raid migration did not record its version.")
		return {}
	var converted := {}
	var column_resolved := false
	for entry in session.overworld.get("encounters", []):
		if not (entry is Dictionary):
			continue
		if String(entry.get("placement_id", "")) == "%s_raid_1" % controller:
			converted = entry
	column_resolved = ("%s_raid_2" % controller) in session.overworld.get("resolved_encounters", [])
	if not AiHeroRulesScript.is_ai_hero(converted):
		_fail("A legacy raid host with a commander did not become an AI hero: %s" % JSON.stringify(converted))
		return {}
	if String(converted.get("encounter_id", "")) != AiHeroRulesScript.AI_HERO_ENCOUNTER_ID or _headcount(converted.get("enemy_army", {}).get("stacks", [])) != 12:
		_fail("The converted hero must keep its troops under the field army template: %s" % JSON.stringify(converted))
		return {}
	if int(converted.get("enemy_commander_state", {}).get("level", 0)) != 3:
		_fail("The converted hero must keep its level.")
		return {}
	if not column_resolved:
		_fail("A commanderless raid column must disband.")
		return {}
	var garrison_after := _headcount(_first_ai_town(session, controller).get("garrison", []))
	if garrison_after != garrison_before + 9:
		_fail("Disbanded column troops must return to the town garrison (%d -> %d)." % [garrison_before, garrison_after])
		return {}
	return {"converted_hero": String(converted.get("placement_id", "")), "column_troops_returned": 9}

## Heroes, their armies, movement and private goals survive a save restore,
## and every one still leads troops.
func _check_save_round_trip(session, controller: String) -> Dictionary:
	var before := {}
	for entry in AiHeroRulesScript.active_hero_entries(session, controller):
		before[String(entry.get("placement_id", ""))] = _hero_signature(entry)
	var restored: Dictionary = SaveService._normalize_restore_result(session.to_dict())
	var loaded = restored.get("session", null)
	if not bool(restored.get("ok", false)) or loaded == null:
		_fail("Save restore failed: %s" % String(restored.get("message", "")))
		return {}
	OverworldRules.normalize_overworld_state(loaded)
	var after := {}
	for entry in AiHeroRulesScript.active_hero_entries(loaded, controller):
		if _headcount(entry.get("enemy_army", {}).get("stacks", [])) <= 0:
			_fail("A restored AI hero leads no troops: %s" % JSON.stringify(entry))
			return {}
		after[String(entry.get("placement_id", ""))] = _hero_signature(entry)
	if JSON.stringify(before) != JSON.stringify(after) or before.is_empty():
		_fail("AI heroes changed across a save restore: %s -> %s" % [JSON.stringify(before), JSON.stringify(after)])
		return {}
	return {"heroes": before.size()}

## A computer town short of wood buys it at its market for exactly the human's
## quote and books the week's purchase like the market popout does.
func _check_market_trades_like_the_player(session, controller: String) -> Dictionary:
	var town := _first_ai_town(session, controller)
	var built: Array = town.get("built_buildings", [])
	if "building_market_square" not in built and "building_dev_trade_exchange" not in built:
		built.append("building_market_square")
		town["built_buildings"] = built
	town["market_usage"] = {}
	var market: Dictionary = OverworldRules.town_market_state(town)
	var usage: Dictionary = OverworldRules._normalize_town_market_usage_state({}, int(session.day))
	var pool := {"gold": 5000, "wood": 0, "ore": 0}
	var expected: Dictionary = TownRules.market_trade_quote(market, usage, {"gold": 4000}, "gold", "wood", 2)
	if not bool(expected.get("ok", false)):
		_fail("The town market should sell 2 wood for 4000 gold: %s" % JSON.stringify(expected))
		return {}
	if not AiHeroRulesScript._market_cover(session, town, pool, {"gold": 1000, "wood": 2}, true):
		_fail("The AI could not cover a wood shortfall at its market: %s" % JSON.stringify(market))
		return {}
	var bought := int(town.get("market_usage", {}).get("buy", {}).get("wood", 0))
	if int(pool.get("wood", 0)) != 2 or int(pool.get("gold", 0)) != 5000 - int(expected.get("give_amount", 0)) or bought != 2:
		_fail("AI market trade differs from the human's quote %s: pool %s, usage %s" % [JSON.stringify(expected), JSON.stringify(pool), JSON.stringify(town.get("market_usage", {}))])
		return {}
	return {"bought_wood": 2, "gold_paid": int(expected.get("give_amount", 0))}

func _hero_signature(entry: Dictionary) -> String:
	var block: Dictionary = entry.get("ai_hero", {})
	var movement: Dictionary = block.get("movement", {})
	var goal: Dictionary = block.get("goal", {})
	var commander: Dictionary = entry.get("enemy_commander_state", {})
	return "%s|%d,%d|%d|%d/%d|%s:%s|lv%d" % [
		String(block.get("hero_id", "")),
		int(entry.get("x", 0)),
		int(entry.get("y", 0)),
		_headcount(entry.get("enemy_army", {}).get("stacks", [])),
		int(movement.get("current", 0)),
		int(movement.get("max", 0)),
		String(goal.get("kind", "")),
		String(goal.get("id", "")),
		int(commander.get("level", 1)),
	]

## Town orders on a controlled day: the build and recruits come out of the
## faction treasury at their listed prices.
func _check_town_orders_pay_real_costs(session, controller: String) -> Dictionary:
	var state := _state(session, controller)
	var treasury_before := {"gold": 30000, "wood": 60, "ore": 60, "aetherglass": 20, "embergrain": 20, "peatwax": 20, "verdant_grafts": 20, "brass_scrip": 20, "memory_salt": 20}
	state["treasury"] = treasury_before.duplicate()
	var town := _first_ai_town(session, controller)
	# A week's worth of the faction's first two tiers waits in the town.
	var faction_id := PlayerRules.faction_id(session, controller)
	var army_id := String(RandomMapGeneratorRules.DEFAULT_ARMY_BY_FACTION.get(faction_id, ""))
	var recruits: Dictionary = town.get("available_recruits", {}).duplicate()
	for stack in ContentService.get_army_group(army_id).get("stacks", []):
		var unit_id := String(stack.get("unit_id", ""))
		recruits[unit_id] = int(recruits.get(unit_id, 0)) + 10
	town["available_recruits"] = recruits
	# Town orders for a fresh day: nothing built or hired here yet today. Other
	# towns of the faction sit this one out so every cost lands on this town.
	town["last_build_day"] = 0
	town["last_hire_day"] = 0
	for other in session.overworld.get("towns", []):
		if other is Dictionary and other != town and String(other.get("owner", "")) == "enemy" and PlayerRules.town_controller_id(other) == controller:
			other["available_recruits"] = {}
			other["last_build_day"] = int(session.day)
			other["last_hire_day"] = int(session.day)
	var built_before: Array = town.get("built_buildings", []).duplicate()
	var recruits_before: Dictionary = town.get("available_recruits", {}).duplicate()
	var context: Dictionary = AiHeroRulesScript._new_context(session, EnemyTurnRules._enemy_config_for_faction(session, controller), state)
	var result: Dictionary = AiHeroRulesScript._govern_towns(session, context)
	town = _first_ai_town(session, controller)
	var built_after: Array = town.get("built_buildings", [])
	var new_buildings := []
	var spent := {}
	for building_id in built_after:
		if building_id not in built_before:
			new_buildings.append(String(building_id))
			_add(spent, ContentService.get_building(String(building_id)).get("cost", {}))
	var recruited := {}
	for unit_id in recruits_before.keys():
		var bought := int(recruits_before.get(unit_id, 0)) - int(town.get("available_recruits", {}).get(unit_id, 0))
		if bought > 0:
			recruited[String(unit_id)] = bought
			var unit_cost: Dictionary = EnemyTurnRules._enemy_recruit_cost(town, String(unit_id))
			for key in unit_cost.keys():
				spent[key] = int(spent.get(key, 0)) + int(unit_cost[key]) * bought
	var hired := 0
	for event in result.get("events", []):
		if event is Dictionary and String(event.get("event_type", "")) == "ai_hero_hired":
			hired += 1
	if hired > 0:
		for entry in AiHeroRulesScript.active_hero_entries(session, controller):
			if int(entry.get("ai_hero", {}).get("hired_day", -1)) == int(session.day) and not bool(entry.get("ai_hero", {}).get("migrated_from_raid", false)):
				_add(spent, HeroCommandRules.hero_recruit_cost(ContentService.get_hero(String(entry.get("ai_hero", {}).get("hero_id", "")))))
	if new_buildings.is_empty():
		_fail("An AI town with a full treasury did not build: %s" % JSON.stringify(result))
		return {}
	if recruited.is_empty():
		_fail("An AI town with recruits and a full treasury did not recruit: %s" % JSON.stringify(recruits_before))
		return {}
	var treasury_after: Dictionary = _state(session, controller).get("treasury", {})
	for key in treasury_before.keys():
		var expected := int(treasury_before[key]) - int(spent.get(key, 0))
		if int(treasury_after.get(key, 0)) != expected:
			_fail("Treasury %s should be %d after paying %s, got %d." % [key, expected, JSON.stringify(spent), int(treasury_after.get(key, 0))])
			return {}
	return {"built": new_buildings, "recruited": recruited, "heroes_hired": hired, "spent": spent}

func _hero_positions(session, controller: String) -> Dictionary:
	var positions := {}
	for entry in AiHeroRulesScript.active_hero_entries(session, controller):
		positions[String(entry.get("placement_id", ""))] = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
	return positions

func _hero_brief(session, controller: String) -> Array:
	var rows := []
	for entry in AiHeroRulesScript.active_hero_entries(session, controller):
		rows.append("%s@%d,%d:%d:%s" % [
			AiHeroRulesScript.hero_name(entry),
			int(entry.get("x", 0)),
			int(entry.get("y", 0)),
			_headcount(entry.get("enemy_army", {}).get("stacks", [])),
			String(entry.get("ai_hero", {}).get("goal", {}).get("kind", "")),
		])
	return rows

func _plan_brief(session, controller: String) -> Array:
	var rows := []
	var context: Dictionary = AiHeroRulesScript._new_context(session, EnemyTurnRules._enemy_config_for_faction(session, controller), _state(session, controller))
	for entry in AiHeroRulesScript.active_hero_entries(session, controller):
		var plan: Dictionary = AiHeroRulesScript._choose_plan(session, context, entry)
		rows.append({"hero": AiHeroRulesScript.hero_name(entry), "at": [int(entry.x), int(entry.y)], "move": entry.get("ai_hero", {}).get("movement", {}), "avoid": entry.get("ai_hero", {}).get("avoid", {}), "plan": {"kind": plan.get("kind", ""), "id": plan.get("id", ""), "distance": plan.get("distance", -1), "value": plan.get("value", 0), "path": plan.get("path", []).size()}})
	return rows

func _ai_town_brief(session, controller: String) -> Array:
	var rows := []
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "enemy" and PlayerRules.town_controller_id(town) == controller:
			rows.append({"id": String(town.get("placement_id", "")), "entrance": LevelRules.town_entrance(town), "at": [int(town.get("x", 0)), int(town.get("y", 0))], "built": town.get("built_buildings", []), "recruits": town.get("available_recruits", {}), "garrison": town.get("garrison", [])})
	return rows

func _controlled_mines(session, controller: String) -> Array:
	var mines := []
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not bool(site.get("persistent_control", false)) or (site.get("control_income", {}) as Dictionary).is_empty():
			continue
		if PlayerRules.resource_controller_id(node) == controller or (PlayerRules.resource_controller_id(node) == PlayerRules.faction_id(session, controller) and controller == PlayerRules.faction_id(session, controller)):
			mines.append(String(node.get("placement_id", "")))
	return mines

## The human never moves in this run, so every neutral army that is gone was
## beaten by a computer hero through auto-resolve.
func _guard_fight_evidence(session, neutral_before: Array, summaries: Array) -> Dictionary:
	var resolved: Array = session.overworld.get("resolved_encounters", [])
	var defeated := []
	for placement_id in neutral_before:
		if placement_id in resolved:
			defeated.append(placement_id)
	var reported := 0
	for text in summaries:
		if String(text).find(" defeats ") >= 0:
			reported += 1
	return {"guards_defeated": defeated.size(), "guard_ids": defeated, "reported_fights": reported}

func _unresolved_neutral_ids(session) -> Array:
	var resolved: Array = session.overworld.get("resolved_encounters", [])
	var ids := []
	for entry in session.overworld.get("encounters", []):
		if entry is Dictionary and PlayerRules.raid_controller_id(entry) == "" and String(entry.get("placement_id", "")) not in resolved:
			ids.append(String(entry.get("placement_id", "")))
	return ids

func _no_raid_entities(session, texts: Array) -> Dictionary:
	var resolved: Array = session.overworld.get("resolved_encounters", [])
	var raid_entries := []
	for entry in session.overworld.get("encounters", []):
		if not (entry is Dictionary) or String(entry.get("placement_id", "")) in resolved:
			continue
		if PlayerRules.raid_controller_id(entry) != "" and not AiHeroRulesScript.is_ai_hero(entry):
			raid_entries.append(String(entry.get("placement_id", "")))
	var worded := []
	for text in texts:
		if String(text).to_lower().find("raid") >= 0:
			worded.append(String(text).left(160))
	return {"ok": raid_entries.is_empty() and worded.is_empty(), "raid_entries": raid_entries, "raid_wording": worded}

func _first_ai_town(session, controller: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "enemy" and PlayerRules.town_controller_id(town) == controller:
			return town
	return {}

func _headcount(stacks: Variant) -> int:
	var total := 0
	if stacks is Array:
		for stack in stacks:
			if stack is Dictionary:
				total += int(stack.get("count", 0))
	return total

func _add(pool: Dictionary, delta: Variant) -> void:
	if delta is Dictionary:
		for key in delta.keys():
			pool[String(key)] = int(pool.get(String(key), 0)) + int(delta[key])

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
