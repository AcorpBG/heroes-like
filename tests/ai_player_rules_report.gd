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
## Days a hero may stand on one tile outside its towns before it counts as stuck.
const MAX_STALLED_DAYS := 4
## The large map of the owner's 2026-10-08 playthrough (Veilmourn against
## Embercourt, Mireclaw and Sunvault). There Embercourt's lesser hero waited on
## the one tile linking its capital's pocket to the map and held the main army
## in for 34 days, Mireclaw stopped exploring after day 18 while it turned down
## guards it would beat, and no computer town built a Marketplace, so the
## factions short of ore hoarded up to 60,000 gold.
const WIND_RIDGE_SEED := "1041912569"
const WIND_RIDGE_SCENARIO_ID := "native_h3maped_72863470_skirmish"
const WIND_RIDGE_SESSION_ID := "native_rmg_session_native_h3maped_72863470"
const WIND_RIDGE_FACTION_ID := "faction_veilmourn"
const WIND_RIDGE_HERO_ID := "hero_veilmourn_ivara_blacktide"
const WIND_RIDGE_DAYS := 24
## Each computer player explores at least this much by day 25. In the owner's
## game Embercourt had 443 tiles all game and Mireclaw 1,114; the hero model now
## reaches about 1,480, 1,375 and 1,830 for Embercourt, Mireclaw and Sunvault.
const WIND_RIDGE_MIN_EXPLORED := 1000
const WIND_RIDGE_POCKET_EXIT := Vector2i(71, 98)
const WIND_RIDGE_POCKET_INSIDE := Vector2i(73, 100)
## A small map with an underground level (map seed of the capped two-level
## game m111 in the 2026-10-16 AI batch).
const GATE_SEED := "359365613"
## A small islands map: every player starts on its own island and only boats
## built at shipyards cross the water.
const ISLANDS_SEED := "101"
const WaterTravel = preload("res://scripts/core/WaterTravelRules.gd")

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	var perf_size := OS.get_environment("HEROES_AI_RULES_PERF_SIZE").strip_edges()
	if perf_size != "":
		return _run_perf(perf_size, maxi(1, int(OS.get_environment("HEROES_AI_RULES_PERF_DAYS"))))
	if OS.get_environment("HEROES_AI_RULES_ONLY").strip_edges() == "gate":
		var gate_only := _check_gate_crossing()
		if not _failed:
			print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "gate_crossing": gate_only})])
			_cleanup()
			get_tree().quit(0)
		return
	if OS.get_environment("HEROES_AI_RULES_ONLY").strip_edges() == "sail":
		var sail_only := _check_sailing()
		if not _failed:
			print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "sailing": sail_only})])
			_cleanup()
			get_tree().quit(0)
		return
	if OS.get_environment("HEROES_AI_RULES_ONLY").strip_edges() == "wind_ridge":
		var only := _check_wind_ridge_reach()
		if not _failed:
			print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "wind_ridge_reach": only})])
			_cleanup()
			get_tree().quit(0)
		return
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
	var still_days := {}
	var longest_stall := {"hero": "", "days": 0}
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
		var moved := _track_stalls(session, controller, positions, still_days, longest_stall)
		hero_steps += int(moved.steps)
		hero_days += int(moved.hero_days)
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
	if int(longest_stall.days) >= MAX_STALLED_DAYS:
		return _fail("An AI hero stood still away from its towns for %d days: %s" % [int(longest_stall.days), JSON.stringify(longest_stall)])
	var save_check := _check_save_round_trip(session, controller)
	if _failed:
		return
	var economy := _check_town_orders_pay_real_costs(session, controller)
	if _failed:
		return
	var market := _check_market_trades_like_the_player(session, controller)
	if _failed:
		return
	var doorway_hire := _check_hire_with_hero_in_doorway(session, controller)
	if _failed:
		return
	var garrison_swap := _check_garrison_pickup_swaps_in_stronger_stacks()
	if _failed:
		return
	var rewards := _check_battle_rewards_scale_with_strength()
	if _failed:
		return
	var wind_ridge := _check_wind_ridge_reach()
	if _failed:
		return
	var gate_crossing := _check_gate_crossing()
	if _failed:
		return
	var sailing := _check_sailing()
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
		"doorway_hire": doorway_hire,
		"garrison_swap": garrison_swap,
		"battle_rewards": rewards,
		"wind_ridge_reach": wind_ridge,
		"gate_crossing": gate_crossing,
		"sailing": sailing,
		"captured_mines": captured_mines,
		"guard_fights": fights,
		"hero_tiles_per_day": float(hero_steps) / float(maxi(1, hero_days)),
		"longest_stall": longest_stall,
		"turn_ms_max": turn_ms_max,
		"ai_turn_ms_max": ai_ms_max,
		"battles_with_human": battles_with_human,
		"days": days,
		"raid_check": raid_check,
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	var capture_dir := OS.get_environment("HEROES_AI_RULES_CAPTURE_DIR").strip_edges()
	if capture_dir != "":
		await _capture_overworld(session, controller, capture_dir)
	_cleanup()
	get_tree().quit(0)

## With a window: the overworld where the human's scout has come within sight
## of the computer player's strongest hero, as the human would see it.
func _capture_overworld(session, controller: String, output_dir: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("%s_CAPTURE {\"skipped\":\"headless\"}" % REPORT_ID)
		return
	var focus := {}
	for entry in AiHeroRulesScript.active_hero_entries(session, controller):
		if focus.is_empty() or AiHeroRulesScript.hero_power(entry) > AiHeroRulesScript.hero_power(focus):
			focus = entry
	if focus.is_empty():
		return
	var center := Vector2i(int(focus.get("x", 0)), int(focus.get("y", 0)))
	var scout_tile := Vector2i(-1, -1)
	for radius in range(3, 6):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var tile := center + Vector2i(dx, dy)
				if scout_tile.x < 0 and maxi(absi(dx), absi(dy)) == radius and not OverworldRules.tile_is_blocked(session, tile.x, tile.y, LevelRules.level_of(focus)):
					scout_tile = tile
	if scout_tile.x >= 0:
		OverworldRules._set_active_hero_position(session, scout_tile, LevelRules.level_of(focus))
	OverworldRules.refresh_fog_of_war(session)
	session.game_state = "overworld"
	session = SessionState.set_active_session(session)
	get_window().size = Vector2i(1280, 720)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	for _frame in range(4):
		await get_tree().process_frame
	if shell.has_method("validation_minimap_recenter"):
		shell.call("validation_minimap_recenter", center.x, center.y)
	for _frame in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(output_dir)
	var path := "%s/ai_hero_on_overworld_1280x720.png" % output_dir
	var saved := image != null and not image.is_empty() and image.save_png(path) == OK
	print("%s_CAPTURE %s" % [REPORT_ID, JSON.stringify({"path": path, "saved": saved, "hero": AiHeroRulesScript.hero_name(focus), "tile": [center.x, center.y], "threats": EnemyTurnRules.describe_threats(session)})])
	shell.queue_free()
	await get_tree().process_frame

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

func _start_session(size_class_id: String = "homm3_small", player_count: int = 2, seed: String = SEED, hero_id: String = PLAYER_HERO_ID, faction_id: String = PLAYER_FACTION_ID, underground: bool = false, water: String = "land"):
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		seed,
		"",
		"",
		player_count,
		water,
		underground,
		size_class_id,
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,
		faction_id,
		hero_id
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

## The human never moves in this run. A large garrison at home keeps a sensible
## AI from ending the game early, so the run shows it working the map instead.
## The idle hero keeps its own army: a hero forty times a computer hero's
## strength would rightly keep the computer's heroes out of a fifth of a small
## map (AiHeroRules._dangers).
func _fortify_idle_human(session, faction_id: String = PLAYER_FACTION_ID) -> void:
	var army_id := String(RandomMapGeneratorRules.DEFAULT_ARMY_BY_FACTION.get(faction_id, ""))
	var stacks := []
	for stack in ContentService.get_army_group(army_id).get("stacks", []):
		stacks.append({"unit_id": String(stack.get("unit_id", "")), "count": int(stack.get("count", 0)) * 40})
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
	# Rare resources trade at every market, with their own weekly caps.
	var rare_id := ""
	for resource_id in TownRules.market_resource_ids(market):
		if String(resource_id) not in ["wood", "ore"]:
			rare_id = String(resource_id)
			break
	if rare_id == "":
		_fail("The town market offers no rare resource: %s" % JSON.stringify(market))
		return {}
	town["market_usage"] = {}
	var rare_quote: Dictionary = TownRules.market_trade_quote(market, usage, {"gold": 4000}, "gold", rare_id, 1)
	var rare_pool := {"gold": 5000}
	if not bool(rare_quote.get("ok", false)) or not AiHeroRulesScript._market_cover(session, town, rare_pool, {"gold": 1000, rare_id: 1}, true):
		_fail("The AI could not buy %s at its market like the human: %s" % [rare_id, JSON.stringify(rare_quote)])
		return {}
	if int(rare_pool.get(rare_id, 0)) != 1 or int(rare_pool.get("gold", 0)) != 5000 - int(rare_quote.get("give_amount", 0)) or int(town.get("market_usage", {}).get("buy", {}).get(rare_id, 0)) != 1:
		_fail("AI rare purchase differs from the human's quote %s: pool %s" % [JSON.stringify(rare_quote), JSON.stringify(rare_pool)])
		return {}
	return {"bought_wood": 2, "gold_paid": int(expected.get("give_amount", 0)), "bought_rare": rare_id, "rare_gold_paid": int(rare_quote.get("give_amount", 0))}

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
	var context: Dictionary = AiHeroRulesScript._new_context(session, _ai_config(session, controller), state)
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

## A hero of the faction standing in its town's doorway is in that town: the
## town still hires, and the new hero joins it there, as the human's do.
func _check_hire_with_hero_in_doorway(session, controller: String) -> Dictionary:
	var state := _state(session, controller)
	state["treasury"] = {"gold": 30000, "wood": 60, "ore": 60}
	var town := _first_ai_town(session, controller)
	if not HeroCommandRules.town_has_hall(town):
		town["built_buildings"] = town.get("built_buildings", []) + [HeroCommandRules.HALL_BUILDING_ID]
	town["last_hire_day"] = 0
	var entrance := LevelRules.town_entrance(town)
	var heroes := AiHeroRulesScript.active_hero_entries(session, controller)
	if heroes.is_empty():
		_fail("The computer player has no hero to stand in its doorway.")
		return {}
	# One hero left, standing in the doorway: the faction wants more.
	var doorway_id := String(heroes[0].get("placement_id", ""))
	var kept := []
	for entry in session.overworld.get("encounters", []):
		if AiHeroRulesScript.is_ai_hero(entry) and PlayerRules.raid_controller_id(entry) == controller and String(entry.get("placement_id", "")) != doorway_id:
			continue
		if String(entry.get("placement_id", "")) == doorway_id:
			entry["x"] = int(entrance.get("x", 0))
			entry["y"] = int(entrance.get("y", 0))
			entry["level"] = LevelRules.level_of(entrance)
		kept.append(entry)
	session.overworld["encounters"] = kept
	OverworldRules.invalidate_spatial_lookup(session)
	if AiHeroRulesScript.desired_hero_count(session, controller) <= 1:
		_fail("The doorway fixture does not want a second hero.")
		return {}
	var context: Dictionary = AiHeroRulesScript._new_context(session, _ai_config(session, controller), state)
	var result: Dictionary = AiHeroRulesScript._govern_towns(session, context)
	var hired := []
	for event in result.get("events", []):
		if event is Dictionary and String(event.get("event_type", "")) == "ai_hero_hired":
			hired.append(String(event.get("actor_id", "")))
	if hired.is_empty():
		_fail("A town did not hire while its own hero stood in the doorway: %s" % JSON.stringify(result))
		return {}
	var in_doorway := []
	for entry in AiHeroRulesScript.active_hero_entries(session, controller):
		if int(entry.get("x", -1)) == int(entrance.get("x", -2)) and int(entry.get("y", -1)) == int(entrance.get("y", -2)):
			in_doorway.append(String(entry.get("placement_id", "")))
	if doorway_id not in in_doorway or String(hired[0]) not in in_doorway:
		_fail("The hired hero and the doorway hero must both stand in the town: %s" % JSON.stringify(in_doorway))
		return {}
	return {"doorway_hero": doorway_id, "hired": hired, "in_doorway": in_doorway}

## Moves each hero made in a day, and how long each has stood still. A hero
## holding its own town's gate, or waiting by it for recruits, may stand; in
## the field one that never moves is stuck.
func _track_stalls(session, controller: String, positions: Dictionary, still_days: Dictionary, longest_stall: Dictionary) -> Dictionary:
	var steps := 0
	var hero_days := 0
	var after := _hero_positions(session, controller)
	for placement_id in after.keys():
		if not positions.has(placement_id):
			continue
		var before: Vector2i = positions[placement_id]
		var now: Vector2i = after[placement_id]
		steps += maxi(absi(now.x - before.x), absi(now.y - before.y))
		hero_days += 1
		if now == before and not _by_own_town(session, controller, now):
			still_days[placement_id] = int(still_days.get(placement_id, 0)) + 1
		else:
			still_days[placement_id] = 0
		if int(still_days[placement_id]) > int(longest_stall.days):
			longest_stall["hero"] = placement_id
			longest_stall["days"] = int(still_days[placement_id])
			longest_stall["tile"] = [now.x, now.y]
	return {"steps": steps, "hero_days": hero_days}

## The owner's 2026-10-08 large map with the human idle at home: every computer
## player builds a Marketplace, Embercourt's main army gets out of its capital's
## pocket, and no hero stands idle in the field.
func _check_wind_ridge_reach() -> Dictionary:
	ContentService.clear_generated_scenario_drafts()
	var session = _start_session("homm3_large", 4, WIND_RIDGE_SEED, WIND_RIDGE_HERO_ID, WIND_RIDGE_FACTION_ID)
	if session == null:
		return {}
	if session.scenario_id != WIND_RIDGE_SCENARIO_ID:
		_fail("Seed %s no longer generates the owner's large map: %s" % [WIND_RIDGE_SEED, session.scenario_id])
		return {}
	session.session_id = WIND_RIDGE_SESSION_ID
	_fortify_idle_human(session, WIND_RIDGE_FACTION_ID)
	var controllers := []
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary:
			controllers.append(PlayerRules.controller_id(state))
	# The one tile linking Embercourt's capital pocket to the map cuts a way
	# through; the tile its main hero stood on for 30 days does not.
	var pocket := _check_capital_pocket_exit(session)
	if _failed:
		return {}
	var still_days := {}
	var longest_stall := {}
	var market_day := {}
	for controller in controllers:
		still_days[controller] = {}
		longest_stall[controller] = {"hero": "", "days": 0}
	# HEROES_AI_RULES_WIND_DAYS plays longer for a look at the later game.
	var day_count := maxi(WIND_RIDGE_DAYS, int(OS.get_environment("HEROES_AI_RULES_WIND_DAYS")))
	for _day in range(day_count):
		var positions := {}
		for controller in controllers:
			positions[controller] = _hero_positions(session, controller)
		OverworldRules.end_turn(session)
		if not session.battle.is_empty():
			BattleAutoResolveRulesScript.resolve_active_battle(session)
			if session.battle.is_empty() and String(session.scenario_status) == "in_progress":
				session.game_state = "overworld"
		for controller in controllers:
			_track_stalls(session, controller, positions[controller], still_days[controller], longest_stall[controller])
			if not market_day.has(controller) and _has_market(session, controller):
				market_day[controller] = int(session.day)
			if OS.get_environment("HEROES_AI_RULES_WIND_TRACE") != "":
				var trace_state := _state(session, controller)
				var trace_heroes := []
				for entry in AiHeroRulesScript.active_hero_entries(session, controller):
					var block: Dictionary = entry.get("ai_hero", {})
					trace_heroes.append("%s@%d,%d p%d %s:%s%s w%d" % [AiHeroRulesScript.hero_name(entry).left(6), int(entry.x), int(entry.y), int(AiHeroRulesScript.hero_power(entry)), String(block.get("goal", {}).get("kind", "")), String(block.get("goal", {}).get("id", "")).right(4), " P" if String(block.get("parked", "")) != "" else "", int(entry.get("enemy_commander_state", {}).get("battle_wins", 0))])
				print("WIND_TRACE d%d %s x%d g%d o%d b%s %s" % [int(session.day), controller, AiHeroRulesScript.explored_tile_count(trace_state), int(trace_state.get("treasury", {}).get("gold", 0)), int(trace_state.get("treasury", {}).get("ore", 0)), str(_ai_town_brief(session, controller).map(func(row): return row.built.size())), " | ".join(trace_heroes)])
		if String(session.scenario_status) != "in_progress":
			break
	var factions := {}
	for controller in controllers:
		var state := _state(session, controller)
		var wins := 0
		for entry in AiHeroRulesScript.active_hero_entries(session, controller):
			wins += int(entry.get("enemy_commander_state", {}).get("battle_wins", 0))
		var sites := 0
		for node in session.overworld.get("resource_nodes", []):
			if node is Dictionary and PlayerRules.resource_controller_id(node) == controller:
				sites += 1
		factions[controller] = {
			"faction": PlayerRules.faction_id(session, controller),
			"explored_tiles": AiHeroRulesScript.explored_tile_count(state),
			"battle_wins": wins,
			"sites": sites,
			"market_day": int(market_day.get(controller, -1)),
			"gold": int(state.get("treasury", {}).get("gold", 0)),
			"ore": int(state.get("treasury", {}).get("ore", 0)),
			"longest_stall": longest_stall[controller],
			"heroes": _hero_brief(session, controller),
			"towns": _ai_town_brief(session, controller).map(func(row): return {"id": row.id, "built": row.built.size()}),
		}
	var result := {"seed": WIND_RIDGE_SEED, "day": int(session.day), "pocket_exit": pocket, "factions": factions}
	print("%s_WIND_RIDGE %s" % [REPORT_ID, JSON.stringify(result)])
	for controller in controllers:
		var row: Dictionary = factions[controller]
		if _first_ai_town(session, controller).is_empty():
			continue
		if int(row.market_day) < 0:
			_fail("%s never built a Marketplace on the owner's large map: %s" % [controller, JSON.stringify(row)])
			return result
		if int(row.longest_stall.days) >= MAX_STALLED_DAYS:
			_fail("%s left a hero idle in the field for %d days on the owner's large map: %s" % [controller, int(row.longest_stall.days), JSON.stringify(row)])
			return result
		if int(row.explored_tiles) < WIND_RIDGE_MIN_EXPLORED:
			_fail("%s stayed boxed in on the owner's large map: %s" % [controller, JSON.stringify(row)])
			return result
	return result

## A computer hero plans through a subterranean gate to the other level: it
## beats the guard in front of the gate, steps through, fights the guard at the
## far end on arrival and keeps the errand it crossed for. Until 2026-10-17
## heroes never left their level, and most two-level games ran to the day cap
## with the rivals out of each other's reach.
func _check_gate_crossing() -> Dictionary:
	ContentService.clear_generated_scenario_drafts()
	var session = _start_session("homm3_small", 2, GATE_SEED, PLAYER_HERO_ID, PLAYER_FACTION_ID, true)
	if session == null:
		return {}
	var controller := _ai_controller(session)
	# The computer player hires its first hero on its first turn.
	OverworldRules.end_turn(session)
	var heroes: Array = AiHeroRulesScript.active_hero_entries(session, controller)
	if heroes.is_empty():
		_fail("The computer player has no hero on the two-level map.")
		return {}
	var placement_id := String(heroes[0].get("placement_id", ""))
	var context: Dictionary = AiHeroRulesScript._new_context(session, _ai_config(session, controller), _state(session, controller))
	var gates: Dictionary = AiHeroRulesScript._level_surface(session, context, 0).get("gates", {})
	if gates.is_empty():
		_fail("Seed %s generates no subterranean gate on the surface." % GATE_SEED)
		return {}
	# The hero stands on the first gate with an army that beats its guards.
	var gate_tile := int(gates.keys().min())
	var exit: Vector3i = gates[gate_tile].exit
	var size: Vector2i = context.map_size
	var index: int = AiHeroRulesScript._entry_index(session, placement_id)
	var entry: Dictionary = session.overworld.encounters[index]
	entry["x"] = gate_tile % size.x
	entry["y"] = gate_tile / size.x
	entry["level"] = 0
	for stack in entry.get("enemy_army", {}).get("stacks", []):
		stack["count"] = int(stack.get("count", 0)) * 40
	session.overworld.encounters[index] = entry
	OverworldRules.invalidate_spatial_lookup(session)
	var steps := []
	for _step in range(3):
		index = AiHeroRulesScript._entry_index(session, placement_id)
		entry = session.overworld.encounters[index]
		if LevelRules.level_of(entry) == exit.z:
			break
		var block: Dictionary = entry.get("ai_hero", {})
		var movement: Dictionary = block.get("movement", {})
		movement["current"] = int(movement.get("max", 1))
		block["movement"] = movement
		entry["ai_hero"] = block
		session.overworld.encounters[index] = entry
		context = AiHeroRulesScript._new_context(session, _ai_config(session, controller), _state(session, controller))
		var movement_max := maxi(1, int(movement.get("max", 1)))
		var search: Dictionary = AiHeroRulesScript._search(session, context, entry, movement_max * AiHeroRulesScript.SEARCH_DAYS)
		var plan: Dictionary = AiHeroRulesScript._gate_candidate(session, context, entry, search, movement_max, movement_max * AiHeroRulesScript.FAR_SEARCH_DAYS)
		steps.append({"kind": plan.get("kind", ""), "id": String(plan.get("id", "")).get_slice("_object_", 1), "beyond": plan.get("beyond", {})})
		if plan.is_empty() or not AiHeroRulesScript._gate_fight_looks_good(session, context, entry, plan):
			break
		plan["path"] = AiHeroRulesScript._path_to(search, int(plan.tile_index))
		AiHeroRulesScript._follow_plan(session, context, index, plan)
	entry = session.overworld.encounters[AiHeroRulesScript._entry_index(session, placement_id)]
	var far_guard: Dictionary = OverworldRules._find_guard_engagement_at_tile(session, exit.x, exit.y, exit.z, false)
	var result := {"gate": [gate_tile % size.x, gate_tile / size.x], "exit": [exit.x, exit.y, exit.z], "at": [int(entry.get("x", -1)), int(entry.get("y", -1)), LevelRules.level_of(entry)], "steps": steps, "goal": entry.get("ai_hero", {}).get("goal", {}), "far_guard_left": int(far_guard.get("index", -1))}
	if LevelRules.level_of(entry) != exit.z or int(entry.get("x", -1)) != exit.x or int(entry.get("y", -1)) != exit.y:
		_fail("A computer hero on a subterranean gate did not come out on its far side: %s" % JSON.stringify(result))
	elif int(far_guard.get("index", -1)) >= 0:
		_fail("A computer hero came out of a gate and left the guard there standing: %s" % JSON.stringify(result))
	elif String(result.goal.get("id", "")) == "" or String(result.goal.get("id", "")) != String(steps[-1].beyond.get("id", "")):
		_fail("A computer hero lost the errand it crossed a gate for: %s" % JSON.stringify(result))
	if _failed:
		return result
	# With nothing to do down there, the hero heads home through a gate: every
	# town of its player stands on the surface.
	index = AiHeroRulesScript._entry_index(session, placement_id)
	entry = session.overworld.encounters[index]
	var home_block: Dictionary = entry.get("ai_hero", {})
	var home_movement: Dictionary = home_block.get("movement", {})
	home_movement["current"] = int(home_movement.get("max", 1))
	home_block["movement"] = home_movement
	entry["ai_hero"] = home_block
	session.overworld.encounters[index] = entry
	context = AiHeroRulesScript._new_context(session, _ai_config(session, controller), _state(session, controller))
	var home_search: Dictionary = AiHeroRulesScript._search(session, context, entry, maxi(1, int(home_movement.get("max", 1))) * AiHeroRulesScript.SEARCH_DAYS)
	var homeward: Dictionary = AiHeroRulesScript._wait_by_home(session, context, entry, home_search)
	result["homeward"] = {"kind": homeward.get("kind", ""), "beyond": homeward.get("beyond", {})}
	if String(homeward.get("kind", "")) not in ["gate", "encounter"] or String(homeward.get("beyond", {}).get("kind", "")) != "park":
		_fail("An idle computer hero on the level below its towns did not head home through a gate: %s" % JSON.stringify(result))
		return result
	homeward["path"] = AiHeroRulesScript._path_to(home_search, int(homeward.tile_index))
	AiHeroRulesScript._follow_plan(session, context, index, homeward)
	entry = session.overworld.encounters[AiHeroRulesScript._entry_index(session, placement_id)]
	result["home_level"] = LevelRules.level_of(entry)
	if LevelRules.level_of(entry) != 0:
		_fail("An idle computer hero heading home did not come up through the gate: %s" % JSON.stringify(result))
	return result

## On an islands map a computer hero at a shipyard pays for a boat, boards it
## (the day ends), sails and steps ashore on another island (the day ends
## again), leaving the boat moored at the shore, as the human does.
func _check_sailing() -> Dictionary:
	ContentService.clear_generated_scenario_drafts()
	var session = _start_session("homm3_small", 2, ISLANDS_SEED, PLAYER_HERO_ID, PLAYER_FACTION_ID, false, "islands")
	if session == null:
		return {}
	var controller := _ai_controller(session)
	OverworldRules.end_turn(session)
	var heroes: Array = AiHeroRulesScript.active_hero_entries(session, controller)
	if heroes.is_empty():
		_fail("The computer player has no hero on the islands map.")
		return {}
	var placement_id := String(heroes[0].get("placement_id", ""))
	var context: Dictionary = AiHeroRulesScript._new_context(session, _ai_config(session, controller), _state(session, controller))
	var size: Vector2i = context.map_size
	var shipyards: Dictionary = AiHeroRulesScript._level_surface(session, context, 0).get("shipyards", {})
	if shipyards.is_empty():
		_fail("Islands seed %s generates no shipyard with a dock." % ISLANDS_SEED)
		return {}
	var yard_tile := int(shipyards.keys().min())
	var dock := int(shipyards[yard_tile].dock)
	var index: int = AiHeroRulesScript._entry_index(session, placement_id)
	var entry: Dictionary = session.overworld.encounters[index]
	entry["x"] = yard_tile % size.x
	entry["y"] = yard_tile / size.x
	entry["level"] = 0
	session.overworld.encounters[index] = entry
	OverworldRules.invalidate_spatial_lookup(session)
	var treasury: Dictionary = context.state.treasury
	treasury["gold"] = maxi(int(treasury.get("gold", 0)), 5000)
	treasury["wood"] = maxi(int(treasury.get("wood", 0)), 20)
	var gold_before := int(treasury.gold)
	# The nearest open shore tile the hero reaches only over water.
	var movement_max := maxi(1, AiHeroRulesScript._movement_max(entry))
	var search: Dictionary = AiHeroRulesScript._search(session, context, entry, movement_max * AiHeroRulesScript.STRATEGIC_DAYS)
	var phase: PackedByteArray = search.get("phase", PackedByteArray())
	var target := -1
	for tile_index in range(phase.size()):
		if (phase[tile_index] & 3) == 2 and int(search.dist[tile_index]) > 0 and not search.stops.has(tile_index) and (target < 0 or int(search.dist[tile_index]) < int(search.dist[target])):
			target = tile_index
	if target < 0:
		_fail("A computer hero at a shipyard on the islands map finds no shore across the water.")
		return {}
	var result := {"shipyard": [yard_tile % size.x, yard_tile / size.x], "dock": [dock % size.x, dock / size.x], "target": [target % size.x, target / size.x], "days": []}
	for day in range(12):
		index = AiHeroRulesScript._entry_index(session, placement_id)
		entry = session.overworld.encounters[index]
		if _tile_index(entry, size) == target:
			break
		var block: Dictionary = entry.get("ai_hero", {})
		var movement: Dictionary = block.get("movement", {})
		movement["current"] = movement_max
		block["movement"] = movement
		entry["ai_hero"] = block
		session.overworld.encounters[index] = entry
		search = AiHeroRulesScript._search(session, context, entry, movement_max * AiHeroRulesScript.STRATEGIC_DAYS)
		if int(search.dist[target]) < 0:
			_fail("A computer hero lost its way to the far shore on day %d: %s" % [day, JSON.stringify(result)])
			return result
		var plan := {"kind": "wait", "id": "wait:%d" % target, "index": target, "value": 0.0, "tile_index": target, "path": AiHeroRulesScript._path_to(search, target)}
		AiHeroRulesScript._follow_plan(session, context, index, plan)
		entry = session.overworld.encounters[AiHeroRulesScript._entry_index(session, placement_id)]
		result.days.append({"at": [int(entry.get("x", -1)), int(entry.get("y", -1))], "boat": WaterTravel.hero_boat_id(entry), "left": int(entry.get("ai_hero", {}).get("movement", {}).get("current", -1))})
	var boats := WaterTravel.boats(session)
	result["boats"] = boats
	result["gold_spent"] = gold_before - int(treasury.get("gold", 0))
	var days: Array = result.days
	if days.is_empty() or String(days[0].boat) == "" or days[0].at != result.dock or int(days[0].left) != 0:
		_fail("A computer hero at a shipyard did not build a boat and board it at the dock, ending its day: %s" % JSON.stringify(result))
	elif int(result.gold_spent) != 1000:
		_fail("A computer hero's boat did not cost its player the shipyard's price: %s" % JSON.stringify(result))
	elif _tile_index(entry, size) != target or WaterTravel.hero_boat_id(entry) != "" or int(days[-1].left) != 0:
		_fail("A computer hero did not step ashore on the far island, ending its day: %s" % JSON.stringify(result))
	elif boats.size() != 1 or String(boats[0].get("hero_id", "x")) != "" or maxi(absi(int(boats[0].x) - target % size.x), absi(int(boats[0].y) - target / size.x)) != 1:
		_fail("A computer hero that went ashore did not leave its boat moored beside it: %s" % JSON.stringify(result))
	return result

func _tile_index(point: Dictionary, size: Vector2i) -> int:
	return int(point.get("y", 0)) * size.x + int(point.get("x", 0))

## Embercourt's capital sits in a pocket whose only way out is one tile beside
## the town. On 2026-10-08 a lesser hero waited there and held the main army in
## for 34 days. That tile cuts a way through, and waiting heroes avoid such
## tiles; the open tile the main army stood on does not.
func _check_capital_pocket_exit(session) -> Dictionary:
	var controller := ""
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == "faction_embercourt":
			controller = PlayerRules.controller_id(state)
	var capital := _first_ai_town(session, controller)
	if capital.is_empty():
		_fail("Embercourt holds no town on the owner's large map.")
		return {}
	# Heroes take the field on the computer player's first turn: search from the
	# capital's doorway instead.
	var door := LevelRules.town_entrance(capital)
	var probe := {"placement_id": "pocket_probe", "x": int(door.get("x", 0)), "y": int(door.get("y", 0)), "level": LevelRules.level_of(door)}
	var context: Dictionary = AiHeroRulesScript._new_context(session, _ai_config(session, controller), _state(session, controller))
	var search: Dictionary = AiHeroRulesScript._search(session, context, probe, 30)
	var size: Vector2i = context.map_size
	var exit_cuts: bool = AiHeroRulesScript._cuts_a_way(search, WIND_RIDGE_POCKET_EXIT.y * size.x + WIND_RIDGE_POCKET_EXIT.x, size)
	var inside_cuts: bool = AiHeroRulesScript._cuts_a_way(search, WIND_RIDGE_POCKET_INSIDE.y * size.x + WIND_RIDGE_POCKET_INSIDE.x, size)
	var result := {"exit": [WIND_RIDGE_POCKET_EXIT.x, WIND_RIDGE_POCKET_EXIT.y], "exit_cuts": exit_cuts, "inside": [WIND_RIDGE_POCKET_INSIDE.x, WIND_RIDGE_POCKET_INSIDE.y], "inside_cuts": inside_cuts}
	if not exit_cuts or inside_cuts:
		_fail("The pocket exit beside Embercourt's capital is not told apart from open ground: %s" % JSON.stringify(result))
	return result

## A full army takes a stronger garrison stack in place of its weakest, as a
## human would; a garrison of other kinds it cannot take is worth nothing to it.
func _check_garrison_pickup_swaps_in_stronger_stacks() -> Dictionary:
	var weak := []
	var strong_id := ""
	for unit in ContentService.load_json("res://content/units.json").get("items", []):
		if not (unit is Dictionary):
			continue
		if int(unit.get("tier", 0)) == 1 and weak.size() < 7:
			weak.append({"unit_id": String(unit.get("id", "")), "count": 2})
		elif int(unit.get("tier", 0)) == 7 and strong_id == "":
			strong_id = String(unit.get("id", ""))
	if weak.size() < 7 or strong_id == "":
		_fail("The unit catalog has no seven tier-1 kinds and a tier-7 kind for the garrison check.")
		return {}
	var garrison := [{"unit_id": strong_id, "count": 1}]
	var pickup: Dictionary = AiHeroRulesScript._garrison_pickup(weak.duplicate(true), garrison.duplicate(true))
	var taken_ids: Array = pickup.stacks.map(func(stack): return String(stack.unit_id))
	var left_ids: Array = pickup.left.map(func(stack): return String(stack.unit_id))
	var result := {"taken": taken_ids, "left": left_ids, "gain": snappedf(float(pickup.gain), 0.1)}
	if pickup.stacks.size() != 7 or strong_id not in taken_ids or left_ids.size() != 1 or float(pickup.gain) <= 0.0:
		_fail("A full army did not trade its weakest stack for a stronger garrison stack: %s" % JSON.stringify(result))
	return result

## A won battle pays by the strength beaten (BattleRules.battle_rewards_for_strength):
## half a point of experience per point of strength, half the encounter's gold
## scaled against a typical guard of 300 strength. Beating an AI hero no longer
## pays a flat 140 gold and 160 experience whatever its army.
func _check_battle_rewards_scale_with_strength() -> Dictionary:
	var template := ContentService.get_encounter(AiHeroRulesScript.AI_HERO_ENCOUNTER_ID)
	var lone := [{"unit_id": "unit_bog_brute", "count": 1}]
	var host := [{"unit_id": "unit_bog_brute", "count": 120}]
	var lone_rewards: Dictionary = BattleRules.battle_rewards_for_strength(template, lone)
	var host_rewards: Dictionary = BattleRules.battle_rewards_for_strength(template, host)
	var host_strength: float = AiHeroRulesScript.army_power(host)
	var scale := clampf(host_strength / BattleRules.REWARD_REFERENCE_STRENGTH, BattleRules.REWARD_RESOURCE_SCALE_MIN, BattleRules.REWARD_RESOURCE_SCALE_MAX)
	var expected_gold := int(round(float(template.get("rewards", {}).get("gold", 0)) * BattleRules.REWARD_RESOURCE_SHARE * scale / 10.0)) * 10
	var result := {"lone": lone_rewards, "host": host_rewards, "host_strength": snappedf(host_strength, 0.1), "template": template.get("rewards", {})}
	if int(host_rewards.get("experience", 0)) != int(round(host_strength * BattleRules.REWARD_EXPERIENCE_PER_STRENGTH)) or int(host_rewards.get("gold", 0)) != expected_gold:
		_fail("Battle rewards do not follow the strength beaten: %s" % JSON.stringify(result))
	elif int(lone_rewards.get("experience", 0)) * 20 > int(host_rewards.get("experience", 0)) or int(lone_rewards.get("gold", 0)) >= int(template.get("rewards", {}).get("gold", 0)):
		_fail("A lone creature pays as much as an army: %s" % JSON.stringify(result))
	return result

func _has_market(session, controller: String) -> bool:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "enemy" and PlayerRules.town_controller_id(town) == controller:
			for building_id in town.get("built_buildings", []):
				if not (ContentService.get_building(String(building_id)).get("market_profile", {}) as Dictionary).is_empty():
					return true
	return false

func _by_own_town(session, controller: String, tile: Vector2i) -> bool:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "enemy" and PlayerRules.town_controller_id(town) == controller:
			var entrance := LevelRules.town_entrance(town)
			if maxi(absi(int(entrance.get("x", -1)) - tile.x), absi(int(entrance.get("y", -1)) - tile.y)) <= AiHeroRulesScript.HOME_WAIT_RADIUS:
				return true
	return false

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

## The computer player's faction config, as the enemy turn reads it.
func _ai_config(session, controller: String) -> Dictionary:
	for config in EnemyTurnRules._enemy_faction_configs_for_session(session):
		if config is Dictionary and PlayerRules.controller_id(config) == controller:
			return config
	return {}

func _plan_brief(session, controller: String) -> Array:
	var rows := []
	var context: Dictionary = AiHeroRulesScript._new_context(session, _ai_config(session, controller), _state(session, controller))
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
