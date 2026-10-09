extends Node
## Quick Resolve focus target (bug found 2026-10-09). When Quick Resolve has no
## scored order the active stack can carry out, it falls back to shoot, strike,
## advance or defend against a focus enemy: the weakest living enemy stack by
## total health, then by creatures left. Battle stacks have no "count", and the
## focus check read one, so it skipped every enemy and the fallback kept
## whatever target was already selected. AI battles (AiHeroRules) resolve the
## same way. The battle comes from a generated small map.
##
## A rooted melee stack out of reach used to be scored an advance it cannot
## make, so Quick Resolve fell back (bug found 2026-10-09). The tactical scoring
## now leaves advance out for a rooted stack, on either side, and scores an
## order the stack can carry out.
##
## Quick Resolve also checked a scored spell against battle.player_hero, the
## battle stat payload with no spellbook, so mana read as 8 and every spell
## dearer than that fell back (bug found 2026-10-09). It checks the commander
## state the cast spends from.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const REPORT_ID := "BATTLE_QUICK_RESOLVE_FOCUS_REPORT"
const SEED := "battle-quick-resolve-focus-20261009"
## A battle damage spell that costs more than the 8-point mana minimum.
const DEAR_SPELL_ID := "spell_beacon_bell_lance_25"

var _checks := 0
var _failures := []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("%s check failed: %s" % [REPORT_ID, label])

func _run() -> void:
	var session = _session()
	if session != null:
		var battle: Dictionary = session.battle.duplicate(true)
		_check_rooted_order(session, battle.duplicate(true))
		_check_fallback_focus(session, battle.duplicate(true))
		_check_focus_rules(session, battle.duplicate(true))
		_check_quick_resolve(session, battle.duplicate(true))
		_check_dear_spell(session, battle.duplicate(true))
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)

## A battle against a guard of two or more stacks, starting out of reach.
func _session():
	var config := ScenarioSelectRulesScript.build_random_map_player_config(SEED, "", "", 2, "land", false, "homm3_small", ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, "faction_embercourt", "hero_caelen")
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	_check(bool(setup.get("ok", false)), "small generated setup")
	if not bool(setup.get("ok", false)):
		return null
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state(session)
	for encounter in session.overworld.get("encounters", []):
		var battle := BattleRules.create_battle_payload(session, encounter)
		if _line_up(battle).size() >= 2 and int(battle.get("distance", 0)) > 0 and not _melee_player_stack(battle).is_empty() and not _melee_enemy_stack(battle).is_empty():
			session.battle = battle
			session.game_state = "battle"
			return session
	_check(false, "a guard of two or more stacks to fight on the generated map")
	return null

## Living enemy stacks in battle order.
func _line_up(battle: Dictionary) -> Array:
	return battle.get("stacks", []).filter(func(stack): return String(stack.get("side", "")) == "enemy" and BattleRules._alive_count(stack) > 0)

func _weaker(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("total_health", 0)) != int(b.get("total_health", 0)):
		return int(a.get("total_health", 0)) < int(b.get("total_health", 0))
	return BattleRules._alive_count(a) < BattleRules._alive_count(b)

func _melee_player_stack(battle: Dictionary) -> Dictionary:
	return _melee_stack(battle, "player")

func _melee_enemy_stack(battle: Dictionary) -> Dictionary:
	return _melee_stack(battle, "enemy")

func _melee_stack(battle: Dictionary, side: String) -> Dictionary:
	for stack in battle.get("stacks", []):
		if String(stack.get("side", "")) == side and not bool(stack.get("ranged", false)) and BattleRules._alive_count(stack) > 0:
			return stack
	return {}

## The last enemy stack in the line-up is barely standing, so it alone is the
## weakest and a pick of the first enemy would miss it.
func _barely_standing(battle: Dictionary) -> String:
	var last: Dictionary = _line_up(battle).back()
	last["total_health"] = 1
	return String(last.get("battle_id", ""))

func _act_as(battle: Dictionary, stack: Dictionary) -> void:
	var id := String(stack.get("battle_id", ""))
	battle["active_stack_id"] = id
	battle["turn_index"] = maxi(0, battle.get("turn_order", []).find(id))

func _root(battle: Dictionary, stack: Dictionary) -> void:
	var effect := SpellRules.build_battle_effect(BattleRules.STATUS_ROOTED, "Rooted", {"defense": -1}, 1, battle, "spell", "report")
	BattleRules._apply_stack_effect(battle, String(stack.get("battle_id", "")), SpellRules._counted_in_turns(effect, 1))

## A melee stack rooted out of reach (as by an enemy hero's Briar Bind) is
## scored an order it can carry out, never an advance, by Quick Resolve and by
## the enemy side's own scoring alike.
func _check_rooted_order(session, battle: Dictionary) -> void:
	session.battle = battle
	var melee := _melee_player_stack(battle)
	_act_as(battle, melee)
	_root(battle, melee)
	# The hero has cast this round, so a spell cannot stand in for the order.
	BattleRules._mark_commander_spell_cast(battle, "player")
	var enemy_battle: Dictionary = battle.duplicate(true)
	var decision := BattleAutoResolveRulesScript.player_autoplay_decision(session, true)
	var action := String(decision.get("action", ""))
	_check(String(decision.get("reason", "")) == "scored_tactical_order", "Quick Resolve scores an order the rooted stack can carry out: %s" % JSON.stringify(decision))
	_check(action != "advance" and bool(BattleRules.action_availability(session.battle).get(action, false)), "the scored order (%s) is not an advance and is available" % action)
	_check(float(decision.get("candidate_scores", {}).get("advance", 0.0)) <= -9999.0, "advance is scored out for the rooted stack: %s" % JSON.stringify(decision.get("candidate_scores", {})))
	var result: Dictionary = BattleAutoResolveRulesScript._perform_player_order(session, decision, action)
	_check(String(result.get("state", "")) != "invalid", "Quick Resolve carries it out: %s" % result.get("message", ""))

	# The enemy side: a rooted melee guard stack out of reach, scored by the
	# shared tactical order and by the enemy turn's own choice.
	var enemy_melee := _melee_enemy_stack(enemy_battle)
	_act_as(enemy_battle, enemy_melee)
	_root(enemy_battle, enemy_melee)
	BattleRules._mark_commander_spell_cast(enemy_battle, "enemy")
	var shared := BattleAiRules.choose_stack_tactical_order(enemy_battle, enemy_melee, "player")
	var own := BattleAiRules.choose_enemy_action(enemy_battle, enemy_melee, {})
	_check(String(shared.get("action", "")) != "advance" and String(own.get("action", "")) != "advance", "a rooted enemy stack is not ordered to advance (shared %s, enemy turn %s)" % [shared.get("action", ""), own.get("action", "")])
	_check(float(shared.get("candidate_scores", {}).get("advance", 0.0)) <= -9999.0 and float(own.get("candidate_scores", {}).get("advance", 0.0)) <= -9999.0, "both score advance out for the rooted enemy stack")

## When the scored order cannot be carried out, the fallback first selects the
## weakest enemy (another one is selected) and gives its order against it.
func _check_fallback_focus(session, battle: Dictionary) -> void:
	session.battle = battle
	_act_as(battle, _melee_player_stack(battle))
	var weakest := _barely_standing(battle)
	var first := String(_line_up(battle)[0].get("battle_id", ""))
	BattleRules.select_target(session, first)
	_check(String(battle.get("selected_target_id", "")) == first, "setup: the first enemy stack is selected")
	var decision := BattleAutoResolveRulesScript._fallback_player_autoplay_decision(session, "scored_order_unavailable", true)
	_check(String(session.battle.get("selected_target_id", "")) == weakest, "the fallback selects the weakest enemy %s before its order (selected %s)" % [weakest, session.battle.get("selected_target_id", "")])
	_check(String(decision.get("target_battle_id", "")) == weakest, "the fallback order is given against it: %s" % JSON.stringify(decision))
	var action := String(decision.get("action", ""))
	_check(bool(BattleRules.action_availability(session.battle).get(action, false)), "the fallback order (%s) is one the stack can carry out" % action)
	var result: Dictionary = BattleAutoResolveRulesScript._perform_player_order(session, decision, action)
	_check(String(result.get("state", "")) != "invalid", "Quick Resolve carries it out: %s" % result.get("message", ""))

## A dead stack is never the focus, even the one selected when it fell, and of
## two equally hurt stacks the one with fewer creatures left is.
func _check_focus_rules(session, battle: Dictionary) -> void:
	_act_as(battle, _melee_player_stack(battle))
	session.battle = battle.duplicate(true)
	var dead := _barely_standing(session.battle)
	BattleRules.select_target(session, dead)
	BattleRules._get_stack_by_id(session.battle, dead)["total_health"] = 0
	BattleAutoResolveRulesScript._select_focus_enemy(session)
	var focus := BattleRules._get_stack_by_id(session.battle, String(session.battle.get("selected_target_id", "")))
	var least: Dictionary = _line_up(session.battle).reduce(func(best, stack): return stack if _weaker(stack, best) else best)
	_check(not focus.is_empty() and String(focus.get("battle_id", "")) != dead and not _weaker(least, focus), "a dead stack is skipped for the weakest living one (selected %s)" % focus.get("battle_id", ""))

	session.battle = battle.duplicate(true)
	var line_up := _line_up(session.battle)
	for stack in line_up:
		stack["total_health"] = 10000
	var many: Dictionary = line_up[0]
	var few: Dictionary = line_up[1]
	many["unit_hp"] = 10
	many["total_health"] = 120
	few["unit_hp"] = 40
	few["total_health"] = 120
	BattleAutoResolveRulesScript._select_focus_enemy(session)
	_check(String(session.battle.get("selected_target_id", "")) == String(few.get("battle_id", "")), "equal health goes to the stack with fewer creatures left (selected %s)" % session.battle.get("selected_target_id", ""))

## Quick Resolve plays a battle of rooted stacks out with orders it can carry out.
func _check_quick_resolve(session, battle: Dictionary) -> void:
	for stack in battle.get("stacks", []):
		if String(stack.get("side", "")) == "player":
			_root(battle, stack)
	session.battle = battle
	var result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(session)
	_check(bool(result.get("completed", false)) and int(result.get("invalid_orders", 0)) == 0, "Quick Resolve finishes the battle with no invalid order: %s" % JSON.stringify(result.get("action_counts", {})))

## A hero with mana for a spell dearer than 8 points gets it scored, checked
## and cast: the barely standing enemy dies to it while no melee stack is in
## reach.
func _check_dear_spell(session, battle: Dictionary) -> void:
	session.battle = battle
	_act_as(battle, _melee_player_stack(battle))
	var weakest := _barely_standing(battle)
	var commander: Dictionary = battle.get("player_commander_state", {})
	var command: Dictionary = commander.get("command", {})
	command["knowledge"] = maxi(5, int(command.get("knowledge", 0)))
	commander["command"] = command
	var max_mana := SpellRules.mana_max_from_hero(commander)
	commander["spellbook"] = {"known_spell_ids": [DEAR_SPELL_ID], "mana": {"current": max_mana, "max": max_mana}}
	var cost := SpellRules.adjusted_spell_mana_cost(commander, ContentService.get_spell(DEAR_SPELL_ID))
	_check(cost > 8 and max_mana >= cost, "setup: the spell costs %d, more than 8, and the hero has %d mana" % [cost, max_mana])
	var decision := BattleAutoResolveRulesScript.player_autoplay_decision(session, true)
	_check(String(decision.get("action", "")) == "cast_spell" and String(decision.get("spell_id", "")) == DEAR_SPELL_ID, "Quick Resolve scores the dear spell: %s" % JSON.stringify(decision))
	_check(String(decision.get("reason", "")) == "scored_tactical_spell_order", "the dear spell passes the check before casting: %s" % decision.get("spell_validation_message", decision.get("reason", "")))
	_check(String(decision.get("target_battle_id", "")) == weakest, "the spell targets the barely standing enemy %s: %s" % [weakest, decision.get("target_battle_id", "")])
	var result: Dictionary = BattleAutoResolveRulesScript._perform_player_order(session, decision, String(decision.get("action", "")))
	_check(String(result.get("state", "")) != "invalid", "Quick Resolve casts it: %s" % result.get("message", ""))
	var mana_left := int(session.battle.get("player_commander_state", {}).get("spellbook", {}).get("mana", {}).get("current", -1))
	_check(mana_left == max_mana - cost, "the cast spends %d mana (left %d of %d)" % [cost, mana_left, max_mana])
