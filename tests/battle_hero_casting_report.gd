extends Node
## The hero casts battle spells as a free action (battle rework, owner request
## 2026-10-09: "Spells are cast by the units, wasting their turn" and "The hero
## who actually casts the spells is not shown"). Checks that a cast keeps the
## active stack's turn, so the stack still gives its order; that a side casts
## once a round and pays the mana once; that the cast plays on the hero, not on
## the stack; that an effect cast on the active stack does not spend its
## current turn, so a haste speeds up this move and lasts its next turn, while
## one on another stack counts that stack's next turn; that the computer hero
## casts at most once a round and its stack still acts; that an army without a
## hero never casts; that Quick Resolve casts and then gives the same stack its
## order; and that a save and load after a cast keeps the round's cast spent.
## The battles come from a generated small map.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const AutoResolve = preload("res://scripts/core/BattleAutoResolveRules.gd")
const REPORT_ID := "BATTLE_HERO_CASTING_REPORT"
const SEED := "battle-hero-casting-20261009"
const DAMAGE_SPELL := "spell_cinder_burst"
const HASTE_SPELL := "spell_quickmarch_hymn"
const WARD_SPELL := "spell_stone_veil"
const ENEMY_HERO_NAME := "Vaska Emberlot"

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
		var base: Dictionary = session.battle.duplicate(true)
		_check_cast_keeps_turn(session, base)
		_check_haste_this_move(session, base)
		_check_other_stack_counts(session, base)
		_check_wait_after_cast(session, base)
		_check_save_load(session, base)
		_check_enemy_hero(session, base)
		_check_no_hero(session, base)
		_check_ai_choice(session, base)
		_check_quick_resolve(session, base)
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)

## A guard battle of two or more stacks a side, entered as the battle screen does.
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
		if _living(battle, "enemy").size() >= 2 and _living(battle, "player").size() >= 2 and not _melee(battle, "player").is_empty():
			session.battle = battle
			session.game_state = "battle"
			_check(BattleRules.normalize_battle_state(session), "the battle normalizes on entry")
			return session
	_check(false, "a guard of two or more stacks against two or more of the player's, one of them melee")
	return null

func _living(battle: Dictionary, side: String) -> Array:
	return battle.get("stacks", []).filter(func(stack): return String(stack.get("side", "")) == side and BattleRules._alive_count(stack) > 0)

func _melee(battle: Dictionary, side: String) -> Dictionary:
	for stack in _living(battle, side):
		if not bool(stack.get("ranged", false)):
			return stack
	return {}

func _active(battle: Dictionary) -> String:
	return String(battle.get("active_stack_id", ""))

## Steps the turn on, without orders, until `battle_id` is active in this round.
func _advance_until(battle: Dictionary, battle_id: String) -> bool:
	var round_number := int(battle.get("round", 1))
	for _step in range(40):
		if _active(battle) == battle_id:
			return true
		BattleRules.advance_turn(battle)
		if int(battle.get("round", 1)) != round_number:
			return false
	return false

## The first stack of `side` in this round's order, from the start of the round.
func _first_of_side(battle: Dictionary, side: String) -> String:
	for battle_id in battle.get("turn_order", []):
		var stack := BattleRules._get_stack_by_id(battle, String(battle_id))
		if String(stack.get("side", "")) == side and BattleRules._alive_count(stack) > 0:
			return String(battle_id)
	return ""

## A player's stack still to act this round after `after_id`.
func _later_of_side(battle: Dictionary, side: String, after_id: String) -> String:
	var order: Array = battle.get("turn_order", [])
	for index in range(order.find(after_id) + 1, order.size()):
		var stack := BattleRules._get_stack_by_id(battle, String(order[index]))
		if String(stack.get("side", "")) == side and BattleRules._alive_count(stack) > 0:
			return String(order[index])
	return ""

## Fresh copy of the battle with the player's hero given three spells and mana.
func _fresh(session, base: Dictionary) -> void:
	session.battle = base.duplicate(true)
	session.game_state = "battle"
	var commander: Dictionary = (session.battle.get("player_commander_state", {}) as Dictionary).duplicate(true)
	var command: Dictionary = (commander.get("command", {}) as Dictionary).duplicate(true)
	command["power"] = 3
	command["knowledge"] = 10
	commander["command"] = command
	commander["spellbook"] = {"known_spell_ids": [DAMAGE_SPELL, HASTE_SPELL, WARD_SPELL], "mana": {"current": 48, "max": 48}}
	session.battle["player_commander_state"] = commander
	BattleRules.normalize_battle_state(session)

func _player_mana(session) -> int:
	return int(SpellRules.mana_state(BattleRules._player_commander_state(session)).get("current", -1))

func _cost(session, spell_id: String) -> int:
	return SpellRules.adjusted_spell_mana_cost(BattleRules._player_commander_state(session), ContentService.get_spell(spell_id))

func _effect_with(stack: Dictionary, modifier: String) -> Dictionary:
	for effect in stack.get("effects", []):
		if effect is Dictionary and effect.has("turns_left") and int(effect.get("modifiers", {}).get(modifier, 0)) > 0:
			return effect
	return {}

func _hero_cast_events(battle: Dictionary, side: String) -> Array:
	return BattleRules.battle_presentation_event_stream(battle).filter(func(event): return String(event.get("event_type", "")) == "cast" and String(event.get("actor_battle_id", "")) == BattleRules.hero_actor_id(side))

func _check_cast_keeps_turn(session, base: Dictionary) -> void:
	_fresh(session, base)
	var battle: Dictionary = session.battle
	var actor := _first_of_side(battle, "player")
	_check(_advance_until(battle, actor), "a player stack comes up to act")
	var target: Dictionary = _living(battle, "enemy")[0]
	var target_id := String(target.get("battle_id", ""))
	var target_health := int(target.get("total_health", 0))
	var round_before := int(battle.get("round", 1))
	var index_before := int(battle.get("turn_index", 0))
	var mana_before := _player_mana(session)
	var cost := _cost(session, DAMAGE_SPELL)
	_check(not BattleRules.get_spell_actions(session).is_empty(), "the hero offers spells on a stack's turn")
	var result := BattleRules.perform_presented_action(session, "cast_spell:" + DAMAGE_SPELL, {"target_id": target_id})
	battle = session.battle
	_check(bool(result.get("ok", false)) and String(result.get("state", "")) == "continue" and bool(result.get("hero_cast", false)), "the hero casts: %s" % String(result.get("message", "")))
	_check(_active(battle) == actor and int(battle.get("turn_index", 0)) == index_before and int(battle.get("round", 1)) == round_before, "the active stack keeps its turn after the cast")
	_check(_player_mana(session) == mana_before - cost, "the cast costs its mana once: %d -> %d, cost %d" % [mana_before, _player_mana(session), cost])
	_check(int(BattleRules._get_stack_by_id(battle, target_id).get("total_health", 0)) < target_health, "the spell lands on its target")
	_check(BattleRules.get_spell_actions(session).is_empty(), "no second spell is offered this round")
	var availability := BattleRules.action_availability(battle)
	_check(bool(availability.get("defend", false)) and bool(availability.get("wait", false)), "the stack's own orders stay open: %s" % [availability])
	var second := BattleRules.cast_player_spell(session, WARD_SPELL, actor)
	_check(not bool(second.get("ok", false)) and String(second.get("state", "")) == "invalid", "a second cast in the round is refused: %s" % String(second.get("message", "")))
	_check(_player_mana(session) == mana_before - cost, "a refused cast costs nothing")
	# The cast plays on the hero, not on the stack.
	var cast_frames: Array = result.get("playback_frames", []).filter(func(frame): return String(frame.get("playback_event", {}).get("event_id", "")) == "battle_unit_cast")
	_check(cast_frames.size() == 1 and String(cast_frames[0].playback_event.get("battle_id", "")) == BattleRules.hero_actor_id("player"), "one cast frame, played by the hero: %s" % [cast_frames.map(func(frame): return frame.playback_event.get("battle_id", ""))])
	if cast_frames.size() == 1:
		_check(String(cast_frames[0].get("active_stack_id", "")) == actor, "the active stack stays lit while the hero casts")
	var reactions: Array = result.get("playback_frames", []).filter(func(frame): return String(frame.get("playback_event", {}).get("battle_id", "")) == target_id)
	_check(not reactions.is_empty() and String(reactions[0].playback_event.get("source_battle_id", "")) == BattleRules.hero_actor_id("player"), "the target reacts to the hero's spell")
	var hero_events := _hero_cast_events(battle, "player")
	var hero_name := BattleRules.commander_name(battle, "player")
	_check(hero_events.size() == 1 and hero_name != "" and String(hero_events[0].get("actor_name", "")) == hero_name and String(hero_events[0].get("side", "")) == "player", "the log names the hero as the caster: %s" % [hero_events])
	_check(BattleRules.battle_presentation_event_stream(battle).filter(func(event): return String(event.get("event_type", "")) == "cast" and String(event.get("actor_battle_id", "")) == actor).is_empty(), "the stack is not named as the caster")
	# The stack then gives its order and the turn passes.
	var order := BattleRules.perform_player_action(session, "defend")
	battle = session.battle
	_check(bool(order.get("ok", false)), "the stack gives its order after the cast: %s" % String(order.get("message", "")))
	_check(battle.is_empty() or _active(battle) != actor or int(battle.get("round", 1)) != round_before, "the turn passes after the stack's order")

func _check_haste_this_move(session, base: Dictionary) -> void:
	_fresh(session, base)
	var battle: Dictionary = session.battle
	var actor := String(_melee(battle, "player").get("battle_id", ""))
	_check(_advance_until(battle, actor), "the melee stack comes up to act")
	var points_before := BattleRules._stack_movement_points(BattleRules._get_stack_by_id(battle, actor), battle)
	var reach_before := BattleRules.legal_destinations_for_active_stack(battle).size()
	var result := BattleRules.cast_player_spell(session, HASTE_SPELL, actor)
	battle = session.battle
	_check(bool(result.get("ok", false)) and _active(battle) == actor, "the hero hastes the active stack and it keeps its turn: %s" % String(result.get("message", "")))
	var stack := BattleRules._get_stack_by_id(battle, actor)
	_check(BattleRules._stack_movement_points(stack, battle) == points_before + 1, "the haste speeds up this very move: %d -> %d" % [points_before, BattleRules._stack_movement_points(stack, battle)])
	_check(BattleRules.legal_destinations_for_active_stack(battle).size() >= reach_before, "the stack reaches at least as far")
	var effect := _effect_with(stack, "speed")
	_check(not effect.is_empty() and bool(effect.get("skip_current_turn", false)) and int(effect.get("turns_left", 0)) == 1, "the effect does not count the turn it landed in: %s" % [effect])
	# The stack ends its turn: the effect is still there for its next turn.
	BattleRules.advance_turn(battle)
	effect = _effect_with(BattleRules._get_stack_by_id(battle, actor), "speed")
	_check(not effect.is_empty() and int(effect.get("turns_left", 0)) == 1 and not effect.has("skip_current_turn"), "after this turn the haste still covers the next one: %s" % [effect])
	BattleRules.spend_effect_turns(battle, actor)
	_check(_effect_with(BattleRules._get_stack_by_id(battle, actor), "speed").is_empty(), "the stack's next turn spends it")

func _check_other_stack_counts(session, base: Dictionary) -> void:
	_fresh(session, base)
	var battle: Dictionary = session.battle
	var actor := _first_of_side(battle, "player")
	_check(_advance_until(battle, actor), "a player stack comes up to act")
	var other := _later_of_side(battle, "player", actor)
	_check(other != "", "another player stack is still to act this round")
	if other == "":
		return
	var result := BattleRules.cast_player_spell(session, WARD_SPELL, other)
	battle = session.battle
	_check(bool(result.get("ok", false)) and _active(battle) == actor, "the hero wards another stack and the active one keeps its turn: %s" % String(result.get("message", "")))
	var effect := _effect_with(BattleRules._get_stack_by_id(battle, other), "defense")
	_check(not effect.is_empty() and not bool(effect.get("skip_current_turn", false)) and int(effect.get("turns_left", 0)) == 1, "a stack that is not acting counts its next turn: %s" % [effect])
	_check(_advance_until(battle, other), "the warded stack comes up to act")
	_check(not _effect_with(BattleRules._get_stack_by_id(battle, other), "defense").is_empty(), "the ward covers that turn")
	BattleRules.advance_turn(battle)
	_check(_effect_with(BattleRules._get_stack_by_id(battle, other), "defense").is_empty(), "and ends with it")

func _check_wait_after_cast(session, base: Dictionary) -> void:
	_fresh(session, base)
	var battle: Dictionary = session.battle
	var actor := _first_of_side(battle, "player")
	_check(_advance_until(battle, actor), "a player stack comes up to act")
	var target_id := String(_living(battle, "enemy")[0].get("battle_id", ""))
	_check(bool(BattleRules.cast_player_spell(session, DAMAGE_SPELL, target_id).get("ok", false)), "the hero casts")
	var waited := BattleRules.perform_player_action(session, "wait")
	_check(bool(waited.get("ok", false)) and BattleRules.waited_stack_ids(session.battle).has(actor), "the stack can still wait after the cast: %s" % String(waited.get("message", "")))

func _check_save_load(session, base: Dictionary) -> void:
	_fresh(session, base)
	var actor := _first_of_side(session.battle, "player")
	_check(_advance_until(session.battle, actor), "a player stack comes up to act")
	var target_id := String(_living(session.battle, "enemy")[0].get("battle_id", ""))
	_check(bool(BattleRules.cast_player_spell(session, DAMAGE_SPELL, target_id).get("ok", false)), "the hero casts before the save")
	var mana := _player_mana(session)
	session.battle = JSON.parse_string(JSON.stringify(session.battle))
	_check(BattleRules.normalize_battle_state(session), "the battle normalizes after a JSON reload")
	_check(_active(session.battle) == actor, "the same stack is still to give its order")
	_check(_player_mana(session) == mana and BattleRules.get_spell_actions(session).is_empty(), "the round's cast stays spent after the reload")
	_check(not bool(BattleRules.cast_player_spell(session, WARD_SPELL, actor).get("ok", false)), "a second cast is still refused")
	_check(bool(BattleRules.perform_player_action(session, "defend").get("ok", false)), "the stack gives its order after the reload")

## The computer's hero: a damage spell and the mana for several casts.
func _arm_enemy_hero(session) -> Dictionary:
	var hero := SpellRules.ensure_hero_spellbook({
		"id": "hero_report_enemy",
		"name": ENEMY_HERO_NAME,
		"command": {"attack": 1, "defense": 1, "power": 4, "knowledge": 10},
		"spellbook": {"known_spell_ids": [DAMAGE_SPELL], "mana": {"current": 48, "max": 48}},
	})
	session.battle["enemy_hero"] = hero
	session.battle["enemy_hero_payload"] = BattleRules._enemy_hero_payload_from_state(hero, {}, session)
	BattleRules.normalize_battle_state(session)
	return hero

func _enemy_mana(battle: Dictionary) -> int:
	return int(SpellRules.mana_state(battle.get("enemy_hero", {})).get("current", -1))

func _check_enemy_hero(session, base: Dictionary) -> void:
	session.battle = base.duplicate(true)
	session.game_state = "battle"
	_arm_enemy_hero(session)
	var battle: Dictionary = session.battle
	var actor := _first_of_side(battle, "enemy")
	_check(_advance_until(battle, actor), "a computer stack comes up to act")
	var mana_before := _enemy_mana(battle)
	var cost := SpellRules.adjusted_spell_mana_cost(battle.get("enemy_hero", {}), ContentService.get_spell(DAMAGE_SPELL))
	var round_number := int(battle.get("round", 1))
	var serial_before := int(battle.get(BattleRules.PRESENTATION_EVENT_SERIAL_KEY, 0))
	BattleRules.resolve_if_battle_ready(session)
	battle = session.battle
	var casts := _hero_cast_events(battle, "enemy").filter(func(event): return int(event.get("serial", 0)) > serial_before)
	_check(casts.size() == 1, "the computer hero casts once on its first stack's turn: %d casts" % casts.size())
	if casts.is_empty():
		return
	_check(String(casts[0].get("actor_name", "")) == ENEMY_HERO_NAME, "the log names the computer hero as the caster")
	_check(_enemy_mana(battle) == mana_before - cost, "its mana is spent once: %d -> %d, cost %d" % [mana_before, _enemy_mana(battle), cost])
	_check(int(battle.get(BattleRules.COMMANDER_SPELL_CAST_ROUNDS_KEY, {}).get("enemy", 0)) == round_number, "the cast is booked for this round")
	var cast_serial := int(casts[0].get("serial", 0))
	var actor_orders := BattleRules.battle_presentation_event_stream(battle).filter(func(event): return int(event.get("serial", 0)) > cast_serial and String(event.get("actor_battle_id", "")) == actor)
	var actor_animations := BattleRules.animation_event_queue(battle).filter(func(event): return String(event.get("battle_id", "")) == actor and String(event.get("event_id", "")) in ["battle_unit_move", "battle_unit_melee_attack", "battle_unit_ranged_attack", "battle_unit_defend", "battle_unit_wait"])
	_check(not actor_orders.is_empty() or not actor_animations.is_empty(), "the stack the hero cast on still gives its own order")
	_check(_active(battle) != actor or int(battle.get("round", 1)) != round_number, "and its turn passes")
	# Play two rounds: the computer hero casts at most once in each.
	var steps := 0
	while not session.battle.is_empty() and int(session.battle.get("round", 1)) <= round_number + 1 and steps < 60:
		steps += 1
		var active := BattleRules.get_active_stack(session.battle)
		if String(active.get("side", "")) == "player":
			BattleRules.perform_player_action(session, "defend")
		else:
			BattleRules.resolve_if_battle_ready(session)
	if session.battle.is_empty():
		return
	var per_round := {}
	for event in _hero_cast_events(session.battle, "enemy"):
		var key := str(int(event.get("round", 0)))
		per_round[key] = int(per_round.get(key, 0)) + 1
	var at_most_once := true
	for key in per_round:
		at_most_once = at_most_once and int(per_round[key]) <= 1
	_check(at_most_once and not per_round.is_empty(), "the computer hero casts at most once a round: %s" % [per_round])

func _check_no_hero(session, base: Dictionary) -> void:
	session.battle = base.duplicate(true)
	session.game_state = "battle"
	# Every guard encounter in content names a commander, and normalizing
	# restores it from the encounter; take it away to stand for an army without
	# a hero.
	session.battle["enemy_hero"] = {}
	session.battle["enemy_hero_payload"] = {}
	_check(BattleRules.commander_name(session.battle, "enemy") == "", "the army has no commander")
	var steps := 0
	var cast_choices := 0
	while not session.battle.is_empty() and int(session.battle.get("round", 1)) <= 2 and steps < 60:
		steps += 1
		var active := BattleRules.get_active_stack(session.battle)
		if String(active.get("side", "")) == "player":
			BattleRules.perform_player_action(session, "defend")
		else:
			if String(BattleAiRules.choose_enemy_action(session.battle, active, session.battle.get("enemy_hero", {})).get("action", "")) == "cast_spell":
				cast_choices += 1
			BattleRules.resolve_if_battle_ready(session)
	_check(cast_choices == 0, "a guard army without a hero never chooses a cast")
	if not session.battle.is_empty():
		_check(_hero_cast_events(session.battle, "enemy").is_empty(), "and no enemy cast shows in the log")

func _check_ai_choice(session, base: Dictionary) -> void:
	session.battle = base.duplicate(true)
	session.game_state = "battle"
	var hero := _arm_enemy_hero(session)
	var battle: Dictionary = session.battle
	var actor := _first_of_side(battle, "enemy")
	_check(_advance_until(battle, actor), "a computer stack comes up to act")
	var stack := BattleRules._get_stack_by_id(battle, actor)
	var first := BattleAiRules.choose_enemy_action(battle, stack, hero)
	_check(String(first.get("action", "")) == "cast_spell", "a worthwhile spell is cast first, whatever the stack's own order: %s" % [first])
	var own := BattleAiRules.choose_enemy_action(battle, stack, hero, false)
	_check(String(own.get("action", "")) not in ["", "cast_spell"], "without the cast the stack has its own order: %s" % [own])
	var cast := BattleRules._cast_enemy_spell(session, stack, first)
	battle = session.battle
	_check(bool(cast.get("ok", false)) and String(cast.get("state", "")) == "continue" and _active(battle) == actor, "the computer hero's cast keeps the stack's turn")
	var after := BattleAiRules.choose_enemy_action(battle, BattleRules._get_stack_by_id(battle, actor), battle.get("enemy_hero", {}))
	_check(String(after.get("action", "")) not in ["", "cast_spell"], "after the cast the stack gives its own order: %s" % [after])

func _check_quick_resolve(session, base: Dictionary) -> void:
	_fresh(session, base)
	var actor := _first_of_side(session.battle, "player")
	_check(_advance_until(session.battle, actor), "a player stack comes up to act")
	var decision := AutoResolve.player_autoplay_decision(session, true)
	_check(String(decision.get("action", "")) == "cast_spell", "Quick Resolve's hero casts first: %s" % [decision])
	if String(decision.get("action", "")) == "cast_spell":
		var cast := AutoResolve._perform_player_order(session, decision, "cast_spell")
		_check(bool(cast.get("ok", false)) and _active(session.battle) == actor, "the same stack keeps its turn: %s" % String(cast.get("message", "")))
		var next := AutoResolve.player_autoplay_decision(session, true)
		_check(String(next.get("action", "")) not in ["", "cast_spell"] and _active(session.battle) == actor, "then that stack gets its own order: %s" % [next])
	_fresh(session, base)
	var resolution := AutoResolve.resolve_active_battle(session)
	_check(bool(resolution.get("completed", false)), "Quick Resolve finishes the battle: %s" % String(resolution.get("state", "")))
	_check(int(resolution.get("action_counts", {}).get("cast_spell", 0)) >= 1, "and its hero cast: %s" % [resolution.get("action_counts", {})])
	_check(int(resolution.get("invalid_orders", 0)) == 0, "with no refused orders")
