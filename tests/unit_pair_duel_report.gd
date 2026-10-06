extends Node

## Duels between the two dwelling lines of every tier I-V choice (base units and
## their upgrades) in each faction town. Commanders are neutralised and each
## pairing is fought from both sides with several combat seeds. For every pair
## the report bisects the size of line B's army until the two lines tie:
## `value_ratio` is line A's strength per gold relative to line B (1.0 = even).

const Harness = preload("res://tests/support/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "UNIT_PAIR_DUEL_REPORT"
const SCENARIO_ID := "river-pass"
const ENCOUNTER_ID := "encounter_ford_reavers"
const BUDGET_UNITS := 24
const SEEDS := [101, 202]
const STEP_LIMIT := 900
const BISECTION_STEPS := 7
# Same-role lines must trade evenly per gold. A ranged line wins head-on duels
# against its melee partner (the duel cannot credit screening or blocking), so
# mixed pairs keep the ranged line's edge inside one shared band.
const SAME_ROLE_TOLERANCE := 0.10
const MIXED_ROLE_LOW := 1.3
const MIXED_ROLE_HIGH := 2.0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var only_faction := OS.get_environment("DUEL_FACTION")
	var rows := []
	for town in ContentService.load_json("res://content/towns.json").get("items", []):
		if only_faction != "" and String(town.get("faction_id", "")) != only_faction:
			continue
		for pair in _pairs_for_town(town):
			var row := _duel_pair(pair)
			rows.append(row)
			print("UNIT_PAIR_DUEL_ROW %s" % JSON.stringify(row))
			await get_tree().process_frame
	var lopsided := rows.filter(func(row): return bool(row.get("lopsided", false)))
	var report := {
		"ok": lopsided.is_empty(),
		"report_id": REPORT_ID,
		"pair_count": rows.size(),
		"lopsided_count": lopsided.size(),
		"same_role_tolerance": SAME_ROLE_TOLERANCE,
		"mixed_role_band": [MIXED_ROLE_LOW, MIXED_ROLE_HIGH],
		"rows": rows,
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if lopsided.is_empty() else 1)

func _pairs_for_town(town: Dictionary) -> Array:
	var by_key := {}
	for building_id in town.get("buildable_building_ids", []):
		var building := ContentService.get_building(String(building_id))
		var tier := int(building.get("dwelling_tier", 0))
		if tier <= 0 or tier > 5:
			continue
		var key := "%d:%d" % [tier, int(building.get("stage", 1))]
		if not by_key.has(key):
			by_key[key] = {}
		by_key[key][int(building.get("choice_branch", 1))] = String(building.get("unlock_unit_id", ""))
	var pairs := []
	var keys := by_key.keys()
	keys.sort()
	for key in keys:
		var branches: Dictionary = by_key[key]
		if branches.has(1) and branches.has(2):
			pairs.append({
				"faction_id": String(town.get("faction_id", "")),
				"tier": int(String(key).split(":")[0]),
				"stage": "upgrade" if String(key).ends_with(":2") else "base",
				"a": String(branches[1]),
				"b": String(branches[2]),
			})
	return pairs

func _duel_pair(pair: Dictionary) -> Dictionary:
	var unit_a := ContentService.get_unit(String(pair.a))
	var unit_b := ContentService.get_unit(String(pair.b))
	var gold_a: int = max(1, int(unit_a.get("cost", {}).get("gold", 1)))
	var gold_b: int = max(1, int(unit_b.get("cost", {}).get("gold", 1)))
	var budget := int(round(float(gold_a + gold_b) * 0.5 * BUDGET_UNITS))
	var count_a: int = max(1, int(round(float(budget) / float(gold_a))))
	var count_b: int = max(1, int(round(float(budget) / float(gold_b))))
	var even := _mean_score(String(pair.a), count_a, String(pair.b), count_b)
	# Bisect line B's army size (as a multiple of the equal-gold count) for a tie.
	var low := 0.25
	var high := 4.0
	for _step in range(BISECTION_STEPS):
		var middle := sqrt(low * high)
		var score := _mean_score(String(pair.a), count_a, String(pair.b), max(1, int(round(float(count_b) * middle))))
		if score > 0.0:
			low = middle
		else:
			high = middle
	var ratio := sqrt(low * high)
	var same_role := bool(unit_a.get("ranged", false)) == bool(unit_b.get("ranged", false))
	var ranged_edge := ratio if bool(unit_a.get("ranged", false)) else 1.0 / ratio
	var lopsided := absf(log(ratio)) > log(1.0 + SAME_ROLE_TOLERANCE) if same_role else (ranged_edge < MIXED_ROLE_LOW or ranged_edge > MIXED_ROLE_HIGH)
	return {
		"faction_id": pair.faction_id,
		"tier": pair.tier,
		"stage": pair.stage,
		"a": pair.a,
		"b": pair.b,
		"a_name": String(unit_a.get("name", "")),
		"b_name": String(unit_b.get("name", "")),
		"same_role": same_role,
		"budget_gold": budget,
		"count_a": count_a,
		"count_b": count_b,
		"a_ranged": bool(unit_a.get("ranged", false)),
		"b_ranged": bool(unit_b.get("ranged", false)),
		"even_gold_score": int(round(even)),
		"value_ratio": snappedf(ratio, 0.01),
		"ranged_edge": snappedf(ranged_edge, 0.01) if not same_role else 0.0,
		"lopsided": lopsided,
	}

func _mean_score(unit_a: String, count_a: int, unit_b: String, count_b: int) -> float:
	var total := 0.0
	var fights := 0
	for seed in SEEDS:
		for a_is_player in [true, false]:
			var result := _fight(unit_a, count_a, unit_b, count_b, a_is_player, int(seed))
			if result.is_empty():
				continue
			fights += 1
			total += float(result.score_a)
	return total / float(max(1, fights))

func _fight(unit_a: String, count_a: int, unit_b: String, count_b: int, a_is_player: bool, seed: int) -> Dictionary:
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	if session == null:
		return {}
	var player_unit := unit_a if a_is_player else unit_b
	var player_count := count_a if a_is_player else count_b
	var enemy_unit := unit_b if a_is_player else unit_a
	var enemy_count := count_b if a_is_player else count_a
	_set_player_army(session, {"id": "duel_player", "name": "Duel", "stacks": [{"unit_id": player_unit, "count": player_count}]})
	var placement := {
		"placement_id": "duel_%s_%s_%d" % [player_unit, enemy_unit, seed],
		"encounter_id": ENCOUNTER_ID,
		"x": 0,
		"y": 0,
		"enemy_army": {"id": "duel_enemy", "name": "Duel", "stacks": [{"unit_id": enemy_unit, "count": enemy_count}]},
	}
	session.battle = BattleRules.create_battle_payload(session, placement)
	if session.battle.is_empty():
		return {}
	_neutralise(session.battle, seed)
	var initial: Dictionary = Harness._side_health_totals(session.battle)
	var final_state := "continue"
	var steps := 0
	var last: Dictionary = initial.duplicate(true)
	while steps < STEP_LIMIT and not session.battle.is_empty():
		steps += 1
		last = Harness._side_health_totals(session.battle)
		var ready: Dictionary = BattleRules.resolve_if_battle_ready(session)
		final_state = String(ready.get("state", "continue"))
		if Harness._is_terminal_state(final_state) or session.battle.is_empty():
			break
		if String(BattleRules.get_active_stack(session.battle).get("side", "")) != "player":
			continue
		var decision: Dictionary = Harness.player_autoplay_decision_report(session, true)
		var action := String(decision.get("action", "defend"))
		var result: Dictionary = {"state": "invalid"}
		if action not in ["cast_spell", "retreat", "surrender"]:
			result = BattleRules.perform_player_action(session, action)
		# Commanders carry no spells here; fall back through the unit orders.
		for fallback in ["shoot", "strike", "advance", "defend"]:
			if String(result.get("state", "")) != "invalid":
				break
			result = BattleRules.perform_player_action(session, fallback)
		final_state = String(result.get("state", "continue"))
		if Harness._is_terminal_state(final_state):
			break
	var end: Dictionary = Harness._side_health_totals(session.battle) if not session.battle.is_empty() else last
	if final_state == "victory":
		end["enemy"] = 0
	elif final_state == "defeat":
		end["player"] = 0
	var player_pct := 100.0 * float(end.get("player", 0)) / float(max(1, int(initial.get("player", 1))))
	var enemy_pct := 100.0 * float(end.get("enemy", 0)) / float(max(1, int(initial.get("enemy", 1))))
	var a_pct := player_pct if a_is_player else enemy_pct
	var b_pct := enemy_pct if a_is_player else player_pct
	return {"state": final_state, "steps": steps, "score_a": int(round(a_pct - b_pct))}

## Battles read the active hero's own army; keep every copy in step.
func _set_player_army(session, army: Dictionary) -> void:
	session.overworld["army"] = army.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["army"] = army.duplicate(true)
	session.overworld["hero"] = hero
	var active_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_id:
			heroes[index]["army"] = army.duplicate(true)
	session.overworld["player_heroes"] = heroes

## Strip commander bonuses, spells, traits and difficulty multipliers so the
## two unit lines meet on equal terms.
func _neutralise(battle: Dictionary, seed: int) -> void:
	battle["combat_seed"] = seed
	for key in ["player_hero", "enemy_hero_payload"]:
		var hero: Dictionary = battle.get(key, {}) if battle.get(key, {}) is Dictionary else {}
		hero["attack"] = 0
		hero["defense"] = 0
		hero["initiative"] = 0
		hero["damage_multiplier"] = 1.0
		hero["mana_current"] = 0
		hero["mana_max"] = 0
		hero["battle_traits"] = []
		hero.erase("spellbook")
		battle[key] = hero
	var enemy_hero: Dictionary = battle.get("enemy_hero", {}) if battle.get("enemy_hero", {}) is Dictionary else {}
	enemy_hero.erase("spellbook")
	enemy_hero.erase("starting_spell_ids")
	enemy_hero.erase("battle_traits")
	if enemy_hero.has("command"):
		enemy_hero["command"] = {"attack": 0, "defense": 0, "power": 0, "knowledge": 0}
	battle["enemy_hero"] = enemy_hero
	battle["field_objectives"] = []
	battle["battlefield_tags"] = []
