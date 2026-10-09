extends Node
## The battle screen counts living creatures from stack health (bug found
## 2026-10-09). Battle stacks have no "count"; BattleRules._alive_count gives
## the creatures left from total_health and unit_hp. The old screen read the
## missing count, so its labels showed x0 and its cues lost the living stacks.
## The reworked screen (docs/battle-rework.md) shows the counts on the turn
## ribbon's chips and the stacks' badges: each counts the creatures left from
## health, a wounded creature counts as one, a fallen stack leaves the ribbon
## and the enemy count, and the log line names the stack whose turn it is.
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
	var base = _session()
	if base != null:
		SessionState.set_active_session(base)
		var frame := Control.new()
		frame.size = Vector2(1920, 1080)
		add_child(frame)
		var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
		frame.add_child(shell)
		for _frame in range(3):
			await get_tree().process_frame
		_check_ribbon_counts(shell)
		_check_wounded_stack(shell)
		_check_fallen_stack(shell)
		_check_log_line(shell)
		frame.queue_free()
		await get_tree().process_frame
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

## The ribbon's chip for a stack, or {} when the stack is not on it.
func _chip_for(board, battle_id: String) -> Dictionary:
	for chip in board._turn_ribbon_chips():
		if String((chip.get("stack", {}) as Dictionary).get("battle_id", "")) == battle_id:
			return chip
	return {}

## A stack of the battle the screen shows, which a test may wound.
func _battle_stack(shell, battle_id: String) -> Dictionary:
	for stack in shell._session.battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			return stack
	return {}

## Every chip on the ribbon counts its stack's living creatures from health.
func _check_ribbon_counts(shell) -> void:
	var board = shell._battle_board_view
	var chips: Array = board._turn_ribbon_chips()
	var active := BattleRules.get_active_stack(shell._session.battle)
	_check(not active.is_empty(), "setup: the battle has an active stack")
	var active_chip := _chip_for(board, String(active.get("battle_id", "")))
	_check(String(active_chip.get("phase", "")) == "active", "the active stack leads the ribbon (%s)" % active_chip.get("phase", ""))
	_check(chips.size() >= 3, "the ribbon shows the stacks of the round (%d chips)" % chips.size())
	for chip in chips:
		var stack: Dictionary = chip.get("stack", {})
		var expected := BattleRules._alive_count(stack)
		_check(expected > 0 and board._stack_alive_count(stack) == expected, "%s's chip counts %d creatures (%d)" % [stack.get("battle_id", ""), expected, board._stack_alive_count(stack)])

## Two whole creatures and one hurt one count as three, on the ribbon and on
## the field.
func _check_wounded_stack(shell) -> void:
	var board = shell._battle_board_view
	var active_id := String(BattleRules.get_active_stack(shell._session.battle).get("battle_id", ""))
	var target := {}
	for stack in _living_enemies(shell._session.battle):
		if String(stack.get("battle_id", "")) != active_id:
			target = _battle_stack(shell, String(stack.get("battle_id", "")))
			break
	_check(not target.is_empty(), "setup: an enemy stack to wound")
	if target.is_empty():
		return
	target["total_health"] = int(target.get("unit_hp", 1)) * 2 + 1
	shell._refresh()
	var battle_id := String(target.get("battle_id", ""))
	var chip := _chip_for(board, battle_id)
	_check(not chip.is_empty(), "the wounded %s stays on the ribbon" % battle_id)
	_check(board._stack_alive_count(chip.get("stack", {})) == 3, "the wounded %s's chip counts 3 (%d)" % [battle_id, board._stack_alive_count(chip.get("stack", {}))])
	_check(board._stack_alive_count(board._stack_by_id(battle_id)) == 3, "the wounded %s's badge on the field counts 3" % battle_id)

## A fallen stack leaves the ribbon and the enemy count.
func _check_fallen_stack(shell) -> void:
	var board = shell._battle_board_view
	var active_id := String(BattleRules.get_active_stack(shell._session.battle).get("battle_id", ""))
	var living := _living_enemies(shell._session.battle)
	var fallen := {}
	for index in range(living.size() - 1, -1, -1):
		if String(living[index].get("battle_id", "")) != active_id:
			fallen = _battle_stack(shell, String(living[index].get("battle_id", "")))
			break
	_check(not fallen.is_empty(), "setup: an enemy stack to fell")
	if fallen.is_empty():
		return
	var battle_id := String(fallen.get("battle_id", ""))
	_check(not _chip_for(board, battle_id).is_empty(), "setup: %s is on the ribbon before it falls" % battle_id)
	fallen["total_health"] = 0
	shell._refresh()
	_check(_chip_for(board, battle_id).is_empty(), "the fallen %s leaves the ribbon" % battle_id)
	var left := _living_enemies(shell._session.battle).size()
	_check(left == living.size() - 1 and shell._enemy_target_count() == left, "the enemy count drops to %d (%d)" % [left, shell._enemy_target_count()])
	for chip in board._turn_ribbon_chips():
		_check(board._stack_alive_count(chip.get("stack", {})) > 0, "only living stacks are on the ribbon (%s)" % (chip.get("stack", {}) as Dictionary).get("battle_id", ""))

## With nothing else to say, the log line names the stack whose turn it is.
func _check_log_line(shell) -> void:
	var active := BattleRules.get_active_stack(shell._session.battle)
	var name := String(active.get("name", "")).strip_edges()
	_check(name != "" and String(shell._idle_log_text()).contains(name), "the idle log line names %s (%s)" % [name, shell._idle_log_text()])
