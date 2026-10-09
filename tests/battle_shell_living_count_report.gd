extends Node
## The battle screen counts living creatures from stack health (bug found
## 2026-10-09). Battle stacks have no "count"; BattleRules._alive_count gives
## the creatures left from total_health and unit_hp. BattleShell read the
## missing count, so the Active and Target labels showed x0, the initiative cue
## never found the next living stack ("no queued stack") and left the count and
## health off its labels, and the target-cycle fallback listed no enemies.
## The battle comes from a generated small map.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "BATTLE_SHELL_LIVING_COUNT_REPORT"
const SEED := "battle-shell-living-count-20261009"

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
		var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
		shell._session = session
		session.battle = battle.duplicate(true)
		_check_focus_labels(shell, session)
		session.battle = battle.duplicate(true)
		_check_initiative_cue(shell, session)
		session.battle = battle.duplicate(true)
		_check_target_fallback(shell, session)
		shell.free()
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)

## A battle against a guard of three or more stacks.
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
		if _living_enemies(battle).size() >= 3:
			session.battle = battle
			session.game_state = "battle"
			return session
	_check(false, "a guard of three or more stacks to fight on the generated map")
	return null

func _living_enemies(battle: Dictionary) -> Array:
	return battle.get("stacks", []).filter(func(stack): return String(stack.get("side", "")) == "enemy" and BattleRules._alive_count(stack) > 0)

func _ids(stacks: Array) -> Array:
	return stacks.map(func(stack): return String(stack.get("battle_id", "")))

## Two whole creatures and one wounded one left.
func _wound(stack: Dictionary) -> void:
	stack["total_health"] = int(stack.get("unit_hp", 1)) * 2 + 1

## The Active and Target labels show the creatures left and the stack's health.
func _check_focus_labels(shell, session) -> void:
	var active := BattleRules.get_active_stack(session.battle)
	_check(not active.is_empty(), "setup: the battle has an active stack")
	var count := BattleRules._alive_count(active)
	var text: String = shell._battle_focus_visible_surface("Active", active, {})
	var expected := "| x%d | HP %d" % [count, int(active.get("total_health", 0))]
	_check(count > 0 and text.contains(expected), "the Active label shows %s: %s" % [expected, text.replace("\n", " / ")])

	var target: Dictionary = _living_enemies(session.battle)[0]
	_wound(target)
	text = shell._battle_focus_visible_surface("Target", target, {})
	expected = "| x3 | HP %d" % int(target.get("total_health", 0))
	_check(text.contains(expected), "a wounded Target with two whole creatures and one hurt shows %s: %s" % [expected, text.replace("\n", " / ")])

## The initiative cue names the next living stack in turn order with its
## creatures and health, and skips a fallen one.
func _check_initiative_cue(shell, session) -> void:
	var cue: Dictionary = shell._battle_initiative_handoff_surface()
	var active := BattleRules.get_active_stack(session.battle)
	_check(String(cue.get("current_stack", "")) == _stack_label(active), "the current stack reads %s (%s)" % [_stack_label(active), cue.get("current_stack", "")])
	var next := _expected_next(session.battle)
	_check(not next.is_empty() and String(cue.get("next_stack", "")) == _stack_label(next), "the next stack reads %s (%s)" % [_stack_label(next), cue.get("next_stack", "")])

	next["total_health"] = 0
	var after := _expected_next(session.battle)
	cue = shell._battle_initiative_handoff_surface()
	_check(not after.is_empty() and String(after.get("battle_id", "")) != String(next.get("battle_id", "")), "setup: another stack is left to act after %s falls" % next.get("battle_id", ""))
	_check(String(cue.get("next_stack", "")) == _stack_label(after), "a fallen stack is skipped for %s (%s)" % [_stack_label(after), cue.get("next_stack", "")])

func _stack_label(stack: Dictionary) -> String:
	return "%s x%d, %d HP" % [String(stack.get("name", "")).strip_edges(), BattleRules._alive_count(stack), int(stack.get("total_health", 0))]

## The first living stack after the active one in turn order, else the first of
## the next round.
func _expected_next(battle: Dictionary) -> Dictionary:
	var turn_order: Array = battle.get("turn_order", [])
	var start := int(battle.get("turn_index", 0)) + 1
	for index in range(start, turn_order.size()) + range(0, turn_order.size()):
		var stack := BattleRules._get_stack_by_id(battle, String(turn_order[index]))
		if not stack.is_empty() and BattleRules._alive_count(stack) > 0:
			return stack
	return {}

## With no legal targets the target cycle runs over every living enemy stack.
func _check_target_fallback(shell, session) -> void:
	var living := _ids(_living_enemies(session.battle))
	_check(shell._living_enemy_target_ids() == living, "every living enemy stack can be cycled to %s (%s)" % [living, shell._living_enemy_target_ids()])
	var fallen: Dictionary = _living_enemies(session.battle).back()
	fallen["total_health"] = 0
	living = _ids(_living_enemies(session.battle))
	_check(shell._living_enemy_target_ids() == living, "a fallen enemy stack drops out of the cycle %s (%s)" % [living, shell._living_enemy_target_ids()])

	var active := BattleRules.get_active_stack(session.battle)
	var target: Dictionary = _living_enemies(session.battle)[0]
	var cue: Dictionary = shell._battle_target_cycle_cue_surface(true, active, target, [], living.size())
	_check(String(cue.get("scope", "")) == "enemy stacks" and int(cue.get("target_count", 0)) == living.size(), "the fallback cycle counts %d enemy stacks (%s, %d)" % [living.size(), cue.get("scope", ""), int(cue.get("target_count", 0))])
	_check(String(cue.get("position", "")) == "1/%d" % living.size(), "the first living enemy is target 1/%d (%s)" % [living.size(), cue.get("position", "")])
