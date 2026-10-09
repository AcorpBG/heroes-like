extends Node
## Wait and the live turn order (battle rework, owner request 2026-10-09:
## "We lack wait command" and "The battle order is displayed only for the
## current turn it should be constantly updated"). Checks that a waiting stack
## acts after every stack that has not waited, slowest first; that a stack
## waits once per round; that waiting does not spend the stack's turn; that
## the forecast of the next round equals the order the next round gets; that
## a save and load mid-wait keeps the waiting queue; that the player's Wait
## order and its action surface work through a session; and that a computer
## melee stack out of reach waits while the player still has stacks to act.
## The battle comes from a generated small map.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const Footprint = preload("res://scripts/core/BattleFootprint.gd")
const REPORT_ID := "BATTLE_WAIT_TURN_ORDER_REPORT"
const SEED := "battle-wait-turn-order-20261009"

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
		_check_wait_order(battle.duplicate(true))
		_check_two_waiters(battle.duplicate(true))
		_check_effect_turns(battle.duplicate(true))
		_check_round_end(battle.duplicate(true))
		_check_forecast(battle.duplicate(true))
		_check_enemy_wait(session, battle.duplicate(true))
		session.battle = battle.duplicate(true)
		_check_save_load(session)
		session.battle = battle.duplicate(true)
		_check_player_wait(session)
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)

## A battle with at least two stacks a side, entered as the battle screen does.
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
		if _living(battle, "enemy").size() >= 2 and _living(battle, "player").size() >= 2 and not _melee(battle, "enemy").is_empty():
			session.battle = battle
			session.game_state = "battle"
			_check(BattleRules.normalize_battle_state(session), "the battle normalizes on entry")
			return session
	_check(false, "a guard of two or more stacks, one of them melee, on the generated map")
	return null

func _living(battle: Dictionary, side: String) -> Array:
	return battle.get("stacks", []).filter(func(stack): return String(stack.get("side", "")) == side and BattleRules._alive_count(stack) > 0)

## The slowest living melee stack of a side.
func _melee(battle: Dictionary, side: String) -> Dictionary:
	var best := {}
	for stack in _living(battle, side):
		if bool(stack.get("ranged", false)):
			continue
		if best.is_empty() or int(stack.get("speed", 0)) < int(best.get("speed", 0)):
			best = stack
	return best

func _order(battle: Dictionary) -> Array:
	return (battle.get("turn_order", []) as Array).duplicate()

func _active(battle: Dictionary) -> String:
	return String(battle.get("active_stack_id", ""))

func _effect(modifiers: Dictionary, effect_id: String, turns: int) -> Dictionary:
	var effect := SpellRules.build_battle_effect(effect_id, effect_id.capitalize(), modifiers, turns, {"round": 1}, "spell", "report")
	return SpellRules._counted_in_turns(effect, turns)

func _turns_left(battle: Dictionary, battle_id: String, effect_id: String) -> int:
	for effect in BattleRules._get_stack_by_id(battle, battle_id).get("effects", []):
		if String(effect.get("effect_id", "")) == effect_id:
			return int(effect.get("turns_left", 0))
	return 0

## Steps the turn on until `battle_id` is active or the round ends.
func _advance_until(battle: Dictionary, battle_id: String) -> bool:
	var round_number := int(battle.get("round", 1))
	for _step in range(40):
		if _active(battle) == battle_id:
			return true
		BattleRules.advance_turn(battle)
		if int(battle.get("round", 1)) != round_number:
			return false
	return false

func _check_wait_order(battle: Dictionary) -> void:
	var before := _order(battle)
	var first := _active(battle)
	_check(first == String(before[0]) and BattleRules.can_wait(battle), "the round opens with the fastest stack, which may wait")
	BattleRules._apply_wait(battle)
	var after := _order(battle)
	var expected := before.slice(1)
	expected.append(first)
	_check(after == expected, "a waiting stack moves behind every stack that has not waited: %s -> %s" % [before, after])
	_check(_active(battle) == String(before[1]), "the next stack takes the turn")
	_check(BattleRules.waited_stack_ids(battle) == [first], "the waiting queue holds the stack")
	_check(_advance_until(battle, first), "the waiting stack acts later in the same round")
	_check(not BattleRules.can_wait(battle) and not bool(BattleRules.action_availability(battle).get("wait", true)), "a stack that waited cannot wait again that round")

func _check_two_waiters(battle: Dictionary) -> void:
	var before := _order(battle)
	var first := String(before[0])
	var second := String(before[1])
	BattleRules._apply_wait(battle)
	_check(_active(battle) == second and BattleRules.can_wait(battle), "the next stack may wait too")
	BattleRules._apply_wait(battle)
	var after := _order(battle)
	var first_stack := BattleRules._get_stack_by_id(battle, first)
	var second_stack := BattleRules._get_stack_by_id(battle, second)
	var first_key := {"score": BattleRules._stack_initiative_total(first_stack, battle), "speed": int(first_stack.get("speed", 0)), "waited": 0}
	var second_key := {"score": BattleRules._stack_initiative_total(second_stack, battle), "speed": int(second_stack.get("speed", 0)), "waited": 1}
	var slowest_first := [second, first] if BattleRules._compare_waiting_order_keys(second_key, first_key) else [first, second]
	_check(after.slice(after.size() - 2) == slowest_first, "waiting stacks act slowest first: %s (%s, %s)" % [after, first_key, second_key])
	if before.size() > 2:
		_check(_active(battle) == String(before[2]), "every stack that has not waited acts before them")

func _check_effect_turns(battle: Dictionary) -> void:
	var order := _order(battle)
	var second := String(order[1])
	BattleRules._apply_stack_effect(battle, second, _effect({"attack": 1}, "spell:count", 2))
	BattleRules.advance_turn(battle)
	_check(_active(battle) == second and _turns_left(battle, second, "spell:count") == 2, "an effect cast before the stack's turn counts 2 turns")
	BattleRules._apply_wait(battle)
	_check(_turns_left(battle, second, "spell:count") == 2, "waiting does not spend the stack's turn")
	_check(_advance_until(battle, second), "the waiting stack comes back this round")
	_check(_turns_left(battle, second, "spell:count") == 2, "the other stacks' turns do not spend it either")
	BattleRules.advance_turn(battle)
	_check(_turns_left(battle, second, "spell:count") == 1, "the stack's real turn spends one")

func _check_round_end(battle: Dictionary) -> void:
	var round_number := int(battle.get("round", 1))
	var living := _order(battle).filter(func(battle_id): return BattleRules._alive_count(BattleRules._get_stack_by_id(battle, String(battle_id))) > 0)
	var first := _active(battle)
	BattleRules._apply_wait(battle)
	var acted := []
	for _step in range(40):
		if int(battle.get("round", 1)) != round_number:
			break
		acted.append(_active(battle))
		BattleRules.advance_turn(battle)
	_check(int(battle.get("round", 1)) == round_number + 1, "the round ends once both segments are done")
	_check(acted.size() == living.size() and acted.back() == first, "every stack acts once and the lone waiter last: %s" % [acted])
	_check(BattleRules.waited_stack_ids(battle).is_empty() and BattleRules.can_wait(battle), "a new round clears the waiting queue")

func _check_forecast(battle: Dictionary) -> void:
	var round_number := int(battle.get("round", 1))
	var order := _order(battle)
	var first := String(order[0])
	var last := String(order.back())
	# A one-turn initiative boost moves the last stack up now and runs out
	# after its turn, so the next round differs from this one.
	BattleRules._apply_stack_effect(battle, last, _effect({"initiative": 40}, "spell:haste", 1))
	BattleRules._apply_wait(battle)
	var forecast := BattleRules.turn_order_forecast(battle)
	_check(int(forecast.get("round", 0)) == round_number, "the forecast names the current round")
	_check(forecast.get("current", []).size() > 0 and String(forecast.get("current", [])[0]) == _active(battle), "the forecast starts with the active stack")
	_check(String(forecast.get("current", [""])[0]) == last, "the hasted stack acts next: %s" % [forecast])
	_check(forecast.get("waiting", []) == [first], "the waiting stack is listed after this round's order: %s" % [forecast])
	var predicted: Array = forecast.get("next_round", [])
	var snapshot := battle.duplicate(true)
	_check(BattleRules.turn_order_forecast(battle) == forecast and battle == snapshot, "the forecast leaves the battle untouched and repeats")
	for _step in range(40):
		if int(battle.get("round", 1)) != round_number:
			break
		BattleRules.advance_turn(battle)
	_check(not predicted.is_empty() and predicted == _order(battle), "the forecast next round equals the order it gets: %s vs %s" % [predicted, _order(battle)])
	_check(predicted.find(last) > 0, "the boost has run out in the prediction: %s" % [predicted])

## A computer melee stack that cannot reach anyone this turn waits for the
## player's stacks, which still have to act.
func _check_enemy_wait(session, battle: Dictionary) -> void:
	var enemy := _melee(battle, "enemy")
	var enemy_id := String(enemy.get("battle_id", ""))
	var columns := BattleRules.BATTLE_HEX_COLUMNS
	var rows := BattleRules.BATTLE_HEX_ROWS
	for stack in _living(battle, "player"):
		stack["hex"] = {}
	_place(battle, enemy, [columns - 1, columns - 2], rows)
	for stack in _living(battle, "player"):
		_place(battle, stack, [1, 2], rows)
	BattleRules._sync_occupied_hexes(battle)
	BattleRules._sync_distance_from_hexes(battle)
	var order := _order(battle)
	order.erase(enemy_id)
	order.push_front(enemy_id)
	battle["turn_order"] = order
	battle["turn_index"] = 0
	battle["active_stack_id"] = enemy_id
	session.battle = battle
	var active := BattleRules.get_active_stack(battle)
	var target := BattleRules._nearest_opposing_stack(battle, active)
	_check(BattleRules.melee_approach_destination(battle, active, target).is_empty() and not BattleAiRules._can_make_melee_attack(active, battle), "the enemy stack is out of reach (%s at %s, %s at %s)" % [enemy_id, active.get("hex", {}), String(target.get("battle_id", "")), target.get("hex", {})])
	var hex_before: Dictionary = active.get("hex", {}).duplicate()
	var result: Dictionary = BattleRules._run_enemy_turn(session, active)
	_check(BattleRules.stack_has_waited(battle, enemy_id), "the out-of-reach melee stack waits: %s" % [result])
	_check(BattleRules._get_stack_by_id(battle, enemy_id).get("hex", {}) == hex_before and String(result.get("message", "")).contains("waits"), "it stays put and says so: %s" % [result])
	_check(_active(battle) != enemy_id and _order(battle).back() == enemy_id, "the turn moves on and the stack acts last")
	var again := BattleAiRules.should_wait_for_contact(battle, BattleRules._get_stack_by_id(battle, enemy_id), false, 3)
	_check(not again, "a stack that waited does not choose to wait again")
	_check(not BattleAiRules.should_wait_for_contact(battle, BattleRules._get_stack_by_id(battle, enemy_id), true, 0), "nobody left to act means no reason to wait")

func _place(battle: Dictionary, stack: Dictionary, columns: Array, rows: int) -> void:
	for q in columns:
		for r in range(rows):
			var cell := {"q": int(q), "r": r}
			if Footprint.fits(stack, cell, BattleRules._build_blocking_map(battle), BattleRules.BATTLE_HEX_COLUMNS, rows):
				stack["hex"] = cell
				return
	_check(false, "room to place %s in columns %s" % [String(stack.get("battle_id", "")), columns])

func _check_save_load(session) -> void:
	var first := _active(session.battle)
	BattleRules._apply_wait(session.battle)
	var order := _order(session.battle)
	var active := _active(session.battle)
	session.battle = JSON.parse_string(JSON.stringify(session.battle))
	_check(BattleRules.normalize_battle_state(session), "the battle normalizes after a JSON reload mid-wait")
	_check(BattleRules.waited_stack_ids(session.battle) == [first], "the waiting queue survives a save and load: %s" % [BattleRules.waited_stack_ids(session.battle)])
	_check(_order(session.battle) == order and _active(session.battle) == active, "the order and the active stack survive it")
	_check(_advance_until(session.battle, first) and not BattleRules.can_wait(session.battle), "the loaded stack still cannot wait again")

## The player's Wait order through a session, as the battle screen sends it.
func _check_player_wait(session) -> void:
	var ready: Dictionary = BattleRules.resolve_if_battle_ready(session)
	var active := BattleRules.get_active_stack(session.battle)
	_check(String(ready.get("state", "")) == "continue" and String(active.get("side", "")) == "player", "a player stack has the turn after the enemy's opening moves")
	if String(active.get("side", "")) != "player":
		return
	var waiter := String(active.get("battle_id", ""))
	var round_number := int(session.battle.get("round", 1))
	var surface: Dictionary = BattleRules.get_action_surface(session).get("wait", {})
	_check(String(surface.get("label", "")) == "Wait" and not bool(surface.get("disabled", true)) and String(surface.get("summary", "")).contains("Act later"), "the action surface offers Wait: %s" % [surface])
	var result: Dictionary = BattleRules.perform_presented_action(session, "wait")
	_check(bool(result.get("ok", false)) and String(result.get("message", "")).contains("waits"), "the Wait order is accepted: %s" % [result.get("message", "")])
	_check(BattleRules.stack_has_waited(session.battle, waiter), "the stack is in the waiting queue")
	var frames: Array = result.get("playback_frames", [])
	_check(frames.any(func(frame): return String(frame.get("playback_event", {}).get("event_id", "")) == "battle_unit_wait"), "the wait plays back as its own event")
	for _step in range(20):
		var current := BattleRules.get_active_stack(session.battle)
		if String(current.get("battle_id", "")) == waiter or int(session.battle.get("round", 1)) != round_number or session.battle.is_empty():
			break
		_check(String(current.get("side", "")) == "player", "only player stacks are left to steer")
		BattleRules.perform_presented_action(session, "defend")
	_check(_active(session.battle) == waiter and int(session.battle.get("round", 1)) == round_number, "the waiting stack gets its turn later in the round")
	var blocked: Dictionary = BattleRules.get_action_surface(session).get("wait", {})
	_check(bool(blocked.get("disabled", false)) and String(blocked.get("summary", "")).contains("already waited"), "the second Wait is offered as blocked: %s" % [blocked])
	var refused: Dictionary = BattleRules.perform_presented_action(session, "wait")
	_check(not bool(refused.get("ok", true)) and String(refused.get("message", "")).contains("already waited"), "a second Wait in the round is refused: %s" % [refused.get("message", "")])
