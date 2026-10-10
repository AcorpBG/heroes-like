extends Node
## The stack plates and the details cards (docs/battle-rework.md, slice 7:
## owner requests 2026-10-09 for the stack details under the held right
## button, the shots and strike-backs on the field and ranged enemies told
## from melee ones) on a generated small map.
##
## The round is set up by the rules' own orders: the river guard defends,
## the pikewards wait and the hero casts Stone Veil on the acting archers,
## who have spent some shots. The enemy's brute is Rooted, Staggered and
## Harried, its two-hex sovereign has struck back already, and a roster hero
## leads it.
##
## Each plate shows what the rules hold: the side, the role, the count, the
## shots left, the strike-backs (none while Staggered), waiting and
## defending, two effects and "+1", and whether the stack acts now. Each
## card says what the battle fights with, worked out here from the rules'
## numbers: attack and defense as a blow uses them (the stack's, its hero's
## and the Defend stance's), speed as the hexes it may walk now, each effect
## with what it does and for how long ("after this one" on the acting
## stack), and each hero's numbers, specialties and spells at their cost.
##
## The screen part holds the right button on stacks, a ribbon chip, both
## heroes and both hero plates: the card opens beside what it describes,
## below the ribbon and above the command bar, the stack's plate is ringed,
## the drawn cursor and the forecast step aside, and letting go anywhere
## closes it. The card keeps up with the battle while it is held. While a
## spell waits for its target the right button puts the spell away instead.
## The forecast names the right button on the first hovers and always on the
## enemy's hero.
##
## A rendering run given "-- --capture-dir=<dir>" saves screenshots for review.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const REPORT_ID := "BATTLE_PLATES_DETAILS_REPORT"
const SEED := "battle-plates-details-20261010"
const PLAY_SIZE := Vector2i(1920, 1080)
const PLAYBACK_WAIT_MSEC := 30000
const WARD_SPELL := "spell_stone_veil"
const DAMAGE_SPELL := "spell_cinder_burst"
const ENEMY_HERO_ID := "hero_vaska"
const ENEMY_SPELLS := ["spell_cinder_burst", "spell_coal_rain"]
const ENEMY_SPECIALTY := "armsmaster"
const HINT := "Hold the right button for details"
## The hovers that name the right button before the hint stops (the enemy's
## hero names it always).
const HINT_HOVERS := 6
## The stacks: id, unit, count, side and hex. The player's three act first,
## in this order, then the enemy's two, slower than the archers, so the
## enemy does not act while the round is set up.
const STACKS := [
	["report_guard", "unit_river_guard", 15, "player", Vector2i(1, 6)],
	["report_waiter", "unit_citadel_pikeward_veteran", 9, "player", Vector2i(1, 2)],
	["report_shooter", "unit_ember_archer", 14, "player", Vector2i(2, 4)],
	["report_target", "unit_bog_brute", 20, "enemy", Vector2i(7, 4)],
	["report_giant", "unit_mireclaw_drowned_antler_sovereign", 2, "enemy", Vector2i(8, 7)],
]
## The archers' shots left of the unit's eight.
const SHOTS_LEFT := 5
## The brute's statuses: id, label, modifiers (as the abilities that cause
## them give them) and rounds.
const TARGET_STATUSES := [
	["status_rooted", "Rooted", {}, 1],
	["status_staggered", "Staggered", {"initiative": -2, "cohesion": -1}, 2],
	["status_harried", "Harried", {"defense": -1, "initiative": -1, "cohesion": -1}, 3],
]
const ROCKS := [Vector2i(5, 1), Vector2i(4, 7)]

var _checks := 0
var _failures: Array[String] = []
var _details := {}
var _capture_dir := ""
var _base_session = null
var _battle: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("%s check failed: %s" % [REPORT_ID, label])


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--capture-dir="):
			_capture_dir = String(arg).trim_prefix("--capture-dir=")
	if _capture_dir != "":
		DirAccess.make_dir_recursive_absolute(_capture_dir)
		SettingsService.set_battle_playback_speed_id("fast")
	AppRouter.validation_set_battle_report_routing_suppressed(true)
	_base_session = _session()
	if _base_session != null:
		_battle = _base_session.battle.duplicate(true)
		if _prepare(_base_session, true):
			_check_rules(_base_session.battle)
			await _check_screen()
		await _check_spell_targeting()
	AppRouter.validation_set_battle_report_routing_suppressed(false)
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "details": _details}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)


# --- Setup ---------------------------------------------------------------------

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
		if not _living(battle, "enemy").is_empty() and not _living(battle, "player").is_empty():
			session.battle = battle
			session.game_state = "battle"
			_details["encounter"] = String(battle.get("encounter_id", ""))
			return session
	_check(false, "a guard battle on the generated map")
	return null


func _living(battle: Dictionary, side: String) -> Array:
	return battle.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == side and BattleRules._alive_count(stack) > 0)


func _stack(battle: Dictionary, battle_id: String) -> Dictionary:
	return BattleRules._get_stack_by_id(battle, battle_id)


func _active(battle: Dictionary) -> String:
	return String(battle.get("active_stack_id", ""))


## The round the checks look at, on the generated battle's field: the stacks
## of STACKS on an open field with two rocks, the brute's statuses, the
## archers' spent shots and the sovereign's spent strike-back; the enemy led
## by a roster hero, the player's hero knowing Stone Veil and Cinder Burst
## with full mana. Then the rules' own orders: the river guard defends, the
## pikewards wait and (cast) the hero casts Stone Veil on the acting archers.
func _prepare(session, cast: bool) -> bool:
	session.battle = _battle.duplicate(true)
	session.game_state = "battle"
	var battle: Dictionary = session.battle
	var stacks := []
	var order := []
	for index in range(STACKS.size()):
		var spec: Array = STACKS[index]
		var stack := BattleRules._build_battle_stack(String(spec[1]), int(spec[2]), String(spec[3]), index)
		_check(not stack.is_empty(), "setup: the unit %s exists" % spec[1])
		if stack.is_empty():
			return false
		var cell: Vector2i = spec[4]
		stack["battle_id"] = String(spec[0])
		stack[BattleRules.STACK_HEX_KEY] = {"q": cell.x, "r": cell.y}
		match String(spec[0]):
			"report_shooter":
				stack["shots_remaining"] = SHOTS_LEFT
			"report_giant":
				stack["retaliations_left"] = 0
		stacks.append(stack)
		order.append(String(spec[0]))
	battle["stacks"] = stacks
	var target := _stack(battle, "report_target")
	var effects: Array = []
	for status in TARGET_STATUSES:
		effects.append(SpellRules.build_battle_effect(String(status[0]), String(status[1]), status[2], int(status[3]), battle))
	target["effects"] = effects
	var obstacles := []
	for index in range(ROCKS.size()):
		var rock: Vector2i = ROCKS[index]
		obstacles.append({"id": "t%d" % (index + 1), "kind": "rock", "size": 1, "variant": index, "cells": [{"q": rock.x, "r": rock.y}]})
	battle[BattleRules.OBSTACLES_KEY] = obstacles
	battle[BattleRules.FIELD_OBJECTIVES_KEY] = []
	battle["battlefield_tags"] = []
	battle["turn_order"] = order
	battle["turn_index"] = 0
	battle["active_stack_id"] = order[0]
	battle[BattleRules.WAITED_STACK_IDS_KEY] = []
	var template := ContentService.get_hero(ENEMY_HERO_ID)
	var hero := SpellRules.ensure_hero_spellbook({
		"id": ENEMY_HERO_ID,
		"name": String(template.get("name", ENEMY_HERO_ID)),
		"faction_id": String(template.get("faction_id", "")),
		"command": {"attack": 2, "defense": 1, "power": 3, "knowledge": 4},
		"specialties": [ENEMY_SPECIALTY],
		"spellbook": {"known_spell_ids": ENEMY_SPELLS.duplicate(), "mana": {"current": 4, "max": 40}},
	})
	battle["enemy_hero"] = hero
	battle["enemy_hero_payload"] = BattleRules._enemy_hero_payload_from_state(hero, {}, session)
	var commander: Dictionary = (battle.get("player_commander_state", {}) as Dictionary).duplicate(true)
	var spellbook: Dictionary = (commander.get("spellbook", {}) as Dictionary).duplicate(true) if commander.get("spellbook", {}) is Dictionary else {}
	var known: Array = (spellbook.get("known_spell_ids", []) as Array).duplicate()
	for spell_id in [WARD_SPELL, DAMAGE_SPELL]:
		if not known.has(spell_id):
			known.append(spell_id)
	var mana_max := SpellRules.mana_max_from_hero(commander)
	spellbook["known_spell_ids"] = known
	spellbook["mana"] = {"current": mana_max, "max": mana_max}
	commander["spellbook"] = spellbook
	battle["player_commander_state"] = commander
	BattleRules._sync_occupied_hexes(battle)
	BattleRules._sync_distance_from_hexes(battle)
	var defended := BattleRules.perform_player_action(session, "defend")
	_check(bool(defended.get("ok", false)) and _active(session.battle) == "report_waiter", "setup: the river guard defends and the pikewards come up (%s): %s" % [_active(session.battle), String(defended.get("message", ""))])
	var waited := BattleRules.perform_player_action(session, "wait")
	_check(bool(waited.get("ok", false)) and _active(session.battle) == "report_shooter", "setup: the pikewards wait and the archers come up (%s): %s" % [_active(session.battle), String(waited.get("message", ""))])
	if cast:
		var veil := BattleRules.cast_player_spell(session, WARD_SPELL, "report_shooter")
		_check(bool(veil.get("ok", false)) and _active(session.battle) == "report_shooter", "setup: the hero casts Stone Veil on the archers, who keep their turn: %s" % String(veil.get("message", "")))
	return _active(session.battle) == "report_shooter"


## The archers' Stone Veil, or {}.
func _veil(battle: Dictionary) -> Dictionary:
	for effect in SpellRules.active_effects_for_round(_stack(battle, "report_shooter"), int(battle.get("round", 1))):
		if String(effect.get("spell_id", "")) == WARD_SPELL:
			return effect
	return {}


# --- What the plates and cards must say ----------------------------------------

## The rules' state the round was set up for, and what the rules report of it.
func _check_rules(battle: Dictionary) -> void:
	var veil := _veil(battle)
	_check(veil.has("turns_left") and bool(veil.get("skip_current_turn", false)), "rules: Stone Veil counts the archers' turns and not this one %s" % [veil])
	_check(BattleRules.stack_is_waiting(battle, "report_waiter"), "rules: the pikewards are waiting")
	for battle_id in ["report_guard", "report_shooter", "report_target", "report_giant"]:
		_check(not BattleRules.stack_is_waiting(battle, battle_id), "rules: %s is not waiting" % battle_id)
	var target := _stack(battle, "report_target")
	_check(int(target.get("retaliations_left", 0)) == 1 and BattleRules.stack_strike_backs(battle, target) == {"left": 0, "max": 1, "blocked": true}, "rules: the Staggered brute has its strike-back but cannot make it %s" % [BattleRules.stack_strike_backs(battle, target)])
	_check(BattleRules.stack_strike_backs(battle, _stack(battle, "report_giant")) == {"left": 0, "max": 1, "blocked": false}, "rules: the sovereign has struck back this round")
	_check(bool(_stack(battle, "report_guard").get("defending", false)), "rules: the river guard defends")
	_check(BattleRules.stack_details(battle, "report_nobody").is_empty() and BattleRules.hero_details(battle, "nobody").is_empty(), "rules: no details for what is not in the battle")


## What a stack's plate must show, from its state: expect adds the flags and
## effects the round gave it.
func _check_plate(board, battle: Dictionary, battle_id: String, expect: Dictionary) -> void:
	var plate: Dictionary = board.validation_stack_plate(battle_id)
	var stack := _stack(battle, battle_id)
	var ranged := bool(stack.get("ranged", false))
	var staggered := SpellRules.has_effect_id(stack, battle, BattleRules.STATUS_STAGGERED)
	var want := {
		"side": String(stack.get("side", "")),
		"ranged": ranged,
		"count": BattleRules._alive_count(stack),
		"shots": int(stack.get("shots_remaining", 0)) if ranged else -1,
		"strike_backs": int(stack.get("retaliations", 0)),
		"strike_backs_left": 0 if staggered else int(stack.get("retaliations_left", 0)),
		"waiting": false,
		"defending": bool(stack.get("defending", false)),
		"effect_ids": [],
		"overflow": 0,
		"active": battle_id == _active(battle),
	}
	want.merge(expect, true)
	_check(not plate.is_empty(), "plate: %s has a plate" % battle_id)
	for key in want:
		_check(plate.get(key) == want[key], "plate: %s shows %s %s (%s)" % [battle_id, key, want[key], plate.get(key)])
	# The plate follows the figure, which sways a little as it idles.
	var rect: Rect2 = plate.get("rect", Rect2())
	var layout: Dictionary = board._current_hex_layout()
	var center: Vector2 = board._stack_rest_center(board._stack_by_id(battle_id), layout)
	var sway := float(layout.get("radius", 1.0)) * 0.2
	_check(rect.size.x > 0.0 and absf(rect.get_center().x - center.x) < sway and rect.position.y > center.y, "plate: %s's plate sits at its feet (%s, %s)" % [battle_id, rect, center])


func _cell(stack: Dictionary) -> Vector2i:
	var hex: Dictionary = stack.get(BattleRules.STACK_HEX_KEY, {})
	return Vector2i(int(hex.get("q", -1)), int(hex.get("r", -1)))


## What a stack's card must say, from the battle's own numbers. waiting: the
## stack waited this round and has yet to act.
func _stack_texts(battle: Dictionary, battle_id: String, waiting: bool) -> Dictionary:
	var stack := _stack(battle, battle_id)
	var unit := ContentService.get_unit(String(stack.get("unit_id", "")))
	var side := String(stack.get("side", ""))
	var hero := BattleRules._hero_payload_for_side(battle, side)
	var count := BattleRules._alive_count(stack)
	var unit_hp := int(stack.get("unit_hp", 1))
	var total := int(stack.get("total_health", 0))
	var ranged := bool(stack.get("ranged", false))
	var defending := bool(stack.get("defending", false))
	var stance := 2 + int(hero.get("defend_defense_bonus", 0)) if defending else 0
	# As a blow counts them (BattleRules._damage_modifier).
	var attack := BattleRules._stack_attack_total(stack, battle) + int(hero.get("attack", 0))
	var defense := BattleRules._stack_defense_total(stack, battle) + int(hero.get("defense", 0)) + stance
	var speed := BattleRules._stack_movement_points(stack, battle)
	var initiative := BattleRules._stack_initiative_total(stack, battle)
	var staggered := SpellRules.has_effect_id(stack, battle, BattleRules.STATUS_STAGGERED)
	var min_damage := int(stack.get("min_damage", 1))
	var max_damage := int(stack.get("max_damage", 1))
	var shots := int(stack.get("shots_remaining", 0))
	var parts := PackedStringArray([String(ContentService.get_faction(String(stack.get("faction_id", ""))).get("name", "")), "Tier %d" % int(unit.get("tier", 1)), "Ranged" if ranged else "Melee"])
	if int(stack.get("battle_footprint", 1)) == 2:
		parts.append("Large")
	var abilities := []
	for ability in unit.get("abilities", []):
		if ability is Dictionary and String(ability.get("name", "")) != "":
			abilities.append(("%s. %s" % [String(ability.get("name", "")), String(ability.get("description", ""))]).strip_edges())
	var effects := []
	for effect in SpellRules.active_effects_for_round(stack, int(battle.get("round", 1))):
		effects.append(_effect_line(effect, battle))
	if defending:
		effects.append("Defending +%d defense until the round ends" % stance)
	if waiting:
		effects.append("Waiting acts at the end of this round, slowest first")
	var hero_name := BattleRules.commander_name(battle, side)
	var footer := ""
	if hero_name != "" and (int(hero.get("attack", 0)) != 0 or int(hero.get("defense", 0)) != 0):
		footer = "Includes %s's %s attack, %s defense." % [hero_name, _signed(int(hero.get("attack", 0))), _signed(int(hero.get("defense", 0)))]
	return {
		"name": String(stack.get("name", "")),
		"subtitle": " · ".join(parts),
		"count": str(count),
		"top_health": "Top creature %d/%d HP" % [total - (count - 1) * unit_hp, unit_hp],
		"stack_health": "Stack %d HP" % total,
		"attack": str(attack),
		"attack_delta": _delta(attack - int(unit.get("attack", 0))),
		"defense": str(defense),
		"defense_delta": _delta(defense - int(unit.get("defense", 0))),
		"damage": str(min_damage) if min_damage == max_damage else "%d–%d" % [min_damage, max_damage],
		"health": str(unit_hp),
		"health_delta": _delta(unit_hp - int(unit.get("hp", unit_hp))),
		"speed": str(speed),
		"speed_delta": _delta(speed - clampi(int(unit.get("speed", 1)), 1, 6)),
		"initiative": str(initiative),
		"initiative_delta": _delta(initiative - int(unit.get("initiative", 1))),
		"shots": "%d/%d" % [shots, maxi(shots, int(unit.get("shots", 0)))] if ranged else "—",
		"strike_backs": "%d/%d" % [0 if staggered else int(stack.get("retaliations_left", 0)), int(stack.get("retaliations", 0))],
		"cohesion": str(BattleRules._stack_cohesion_total(stack, battle)),
		"momentum": str(BattleRules._stack_momentum_total(stack, battle)),
		"abilities": abilities,
		"effects": effects,
		"footer": footer,
	}


## An effect's row: its name, the status's rules and the numbers it changes,
## and how long it has left: turns of its stack ("after this one" while the
## stack acts in the turn it was cast), else rounds.
func _effect_line(effect: Dictionary, battle: Dictionary) -> String:
	var parts := PackedStringArray()
	var rules := String(SpellRules.STATUS_RULES.get(String(effect.get("effect_id", "")), ""))
	if rules != "":
		parts.append(rules)
	var changes := PackedStringArray()
	var modifiers: Dictionary = effect.get("modifiers", {}) if effect.get("modifiers", {}) is Dictionary else {}
	for key in ["attack", "defense", "speed", "initiative", "cohesion", "momentum"]:
		if int(modifiers.get(key, 0)) != 0:
			changes.append("%s %s" % [_signed(int(modifiers.get(key, 0))), key])
	if int(modifiers.get("retaliation", 0)) < 0:
		changes.append("strikes back %d%% weaker" % mini(75, -int(modifiers.get("retaliation", 0))))
	if not changes.is_empty():
		parts.append(", ".join(changes))
	var round_number := int(battle.get("round", 1))
	var when := ""
	if effect.has("turns_left"):
		var turns := int(effect.get("turns_left", 1))
		when = "%d turn%s" % [turns, "" if turns == 1 else "s"]
		if bool(effect.get("skip_current_turn", false)):
			when += " after this one"
	else:
		var rounds := int(effect.get("expires_after_round", round_number)) - round_number + 1
		if rounds > int(battle.get("max_rounds", 12)):
			when = "for the battle"
		elif rounds <= 1:
			when = "until the round ends"
		else:
			when = "%d rounds" % rounds
	var said := "; ".join(parts)
	var label := String(effect.get("label", "Effect"))
	return "%s %s · %s" % [label, said, when] if said != "" else "%s %s" % [label, when]


## What a hero's card must say: its numbers as its stacks fight with them,
## spell power and knowledge, mana, its specialties at their ranks, its
## battle spells at what they cost it, and whether it may still cast.
func _hero_texts(battle: Dictionary, side: String) -> Dictionary:
	var state: Dictionary = battle.get("enemy_hero", {}) if side == "enemy" else battle.get("player_commander_state", {})
	var payload := BattleRules._hero_payload_for_side(battle, side)
	var mana := SpellRules.mana_state(state)
	var command: Dictionary = state.get("command", {}) if state.get("command", {}) is Dictionary else {}
	var specialties := []
	var seen := {}
	for specialty_value in state.get("specialties", []):
		var specialty_id := String(specialty_value)
		var definition := HeroProgressionRulesScript.specialty_definition(specialty_id)
		if seen.has(specialty_id) or definition.is_empty():
			continue
		seen[specialty_id] = true
		var rank := HeroProgressionRulesScript.specialty_rank(state, specialty_id)
		var title := "%s (%s)" % [String(definition.get("name", specialty_id)), HeroProgressionRulesScript.rank_label(rank)]
		var text := HeroProgressionRulesScript.rank_text(specialty_id, rank)
		specialties.append("%s. %s" % [title, text] if text != "" else "%s." % title)
	var spells := []
	for spell in SpellRules.known_spells(state, "battle"):
		spells.append("%s %d" % [String(spell.get("name", "")), SpellRules.adjusted_spell_mana_cost(state, spell)])
	var cast_rounds: Dictionary = battle.get(BattleRules.COMMANDER_SPELL_CAST_ROUNDS_KEY, {}) if battle.get(BattleRules.COMMANDER_SPELL_CAST_ROUNDS_KEY, {}) is Dictionary else {}
	var cast := int(cast_rounds.get(side, 0)) == int(battle.get("round", 1))
	var footer := "Can cast one spell this round, on any of its side's turns."
	if cast:
		footer = "Has cast a spell this round."
	elif spells.is_empty():
		footer = "Knows no battle spells."
	return {
		"name": BattleRules.commander_name(battle, side),
		"mana": "%d/%d" % [int(mana.get("current", 0)), int(mana.get("max", 0))],
		"attack": str(int(payload.get("attack", 0))),
		"defense": str(int(payload.get("defense", 0))),
		"power": str(SpellRules.spell_power(state)),
		"knowledge": str(int(command.get("knowledge", 0))),
		"specialties": specialties,
		"spells": spells,
		"footer": footer,
	}


func _signed(amount: int) -> String:
	return "+%d" % amount if amount > 0 else str(amount)


func _delta(amount: int) -> String:
	return "" if amount == 0 else _signed(amount)


# --- The battle screen ---------------------------------------------------------

## Opens the battle screen on the round _prepare set up.
func _open_shell():
	SessionState.set_active_session(_base_session)
	var frame := Control.new()
	frame.name = "BattleFrame"
	frame.size = Vector2(PLAY_SIZE) if _capture_dir == "" else get_viewport().get_visible_rect().size
	add_child(frame)
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	frame.add_child(shell)
	for _frame in range(4):
		await get_tree().process_frame
	var opened: bool = shell._session != null and not shell._session.battle.is_empty()
	_check(opened, "screen: the battle screen opens on the prepared round")
	if opened:
		_check(_active(shell._session.battle) == "report_shooter", "screen: the archers are acting (%s)" % _active(shell._session.battle))
		_check(BattleRules.commander_name(shell._session.battle, "enemy") == String(ContentService.get_hero(ENEMY_HERO_ID).get("name", "")), "screen: the enemy's hero leads its army (%s)" % BattleRules.commander_name(shell._session.battle, "enemy"))
	return shell


func _close_shell(shell) -> void:
	var frame: Node = shell.get_parent()
	frame.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _settle(shell) -> void:
	var deadline := Time.get_ticks_msec() + PLAYBACK_WAIT_MSEC
	while (shell._action_playback_in_progress or shell._battle_exit_handoff_in_progress) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _capture(label: String) -> void:
	if _capture_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_capture_dir.path_join("%s.png" % label))


func _hover_at(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	motion.relative = Vector2(6.0, 0.0)
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	await get_tree().process_frame


func _click_at(position: Vector2) -> void:
	await _hover_at(position)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame


func _right_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if pressed else 0
	event.position = position
	event.global_position = position
	event.pressed = pressed
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	await get_tree().process_frame


func _stack_point(board, battle: Dictionary, battle_id: String) -> Vector2:
	return board.global_position + board._hex_center(_cell(_stack(battle, battle_id)), board._current_hex_layout())


func _hero_point(board, side: String) -> Vector2:
	return board.global_position + (board.hero_figure_layout(side).get("hit_rect", Rect2()) as Rect2).get_center()


## The first ribbon chip of a stack, in the board's space.
func _chip_rect(board, battle_id: String) -> Rect2:
	for chip in board._turn_ribbon_chips():
		var stack: Dictionary = chip.get("stack", {}) if chip.get("stack", {}) is Dictionary else {}
		if String(stack.get("battle_id", "")) == battle_id:
			return Rect2(chip.get("rect", Rect2()))
	return Rect2()


## A point on the painted scenery: off the hexes, the heroes, the ribbon and
## every part of the HUD.
func _scenery_point(shell, board) -> Vector2:
	var rects: Dictionary = shell.validation_hud_snapshot().get("rects", {})
	var grid: Rect2 = board._current_hex_layout().get("rect", Rect2())
	var columns := [grid.end.x + (board.size.x - grid.end.x) * 0.5, grid.position.x * 0.5]
	for x in columns:
		for y in range(int(grid.position.y), int(grid.end.y), 24):
			var point := Vector2(float(x), float(y))
			if board._cell_in_bounds(board._hex_cell_at_position(point)) or board._hero_side_at_position(point) != "" or board._ribbon_rect().has_point(point):
				continue
			if rects.values().any(func(rect): return (rect as Rect2).has_point(point)):
				continue
			return board.global_position + point
	return Vector2(-1.0, -1.0)


func _forecast(board) -> String:
	return " | ".join(board.validation_pointer_order().get("forecast", PackedStringArray()))


func _card(shell) -> Dictionary:
	return shell.validation_details_card()


func _texts(shell) -> Dictionary:
	return (_card(shell).get("shown", {}) as Dictionary).get("texts", {})


## The card is open on what the right button went down on, and says what the
## rules say of it (expected).
func _check_card(shell, kind: String, id: String, expected: Dictionary, label: String) -> void:
	var card := _card(shell)
	var shown: Dictionary = card.get("shown", {})
	var subject := {"kind": "hero" if kind == "hero" else "stack", "id": id}
	_check(bool(card.get("visible", false)) and String(card.get("kind", "")) == kind and String(card.get("id", "")) == id, "%s: the card shows for %s %s (%s %s)" % [label, kind, id, card.get("kind", ""), card.get("id", "")])
	_check(String(shown.get("kind", "")) == subject.kind and String(shown.get("id", "")) == id and card.get("board_subject", {}) == subject, "%s: the card and the field name the same %s %s (%s)" % [label, subject.kind, id, card.get("board_subject", {})])
	var texts: Dictionary = shown.get("texts", {})
	for key in expected:
		_check(texts.get(key) == expected[key], "%s: the card's %s is %s (%s)" % [label, key, expected[key], texts.get(key)])


## The card stands inside the window, below the ribbon and above the command
## bar, and beside ("beside", "right" or "left") or under ("below") what it
## describes.
func _check_card_place(shell, where: String, label: String) -> void:
	var card := _card(shell)
	var rect: Rect2 = card.get("rect", Rect2())
	var anchor: Rect2 = card.get("anchor", Rect2())
	var board = shell._battle_board_view
	var view: Vector2 = shell.size
	var k: float = shell._hud_scale
	var ribbon_bottom: float = board.turn_ribbon_rect().end.y + board.global_position.y - shell._hud.global_position.y
	var bar_top: float = shell._command_bar.position.y
	_check(rect.size.x > 0.0 and rect.position.x >= 0.0 and rect.end.x <= view.x, "%s: the card stays inside the window (%s in %s)" % [label, rect, view])
	_check(rect.position.y >= ribbon_bottom - 0.5 and rect.end.y <= bar_top + 0.5, "%s: the card stays between the ribbon and the command bar (%s, %.0f to %.0f)" % [label, rect, ribbon_bottom, bar_top])
	var placed := false
	match where:
		"beside":
			placed = rect.position.x >= anchor.end.x or rect.end.x <= anchor.position.x
		"right":
			placed = rect.position.x >= anchor.end.x
		"left":
			placed = rect.end.x <= anchor.position.x
		"below":
			var clamped := rect.position.x <= 16.0 * k + 1.0 or rect.end.x >= view.x - 16.0 * k - 1.0
			placed = rect.position.y >= anchor.end.y and (absf(rect.get_center().x - anchor.get_center().x) <= 1.0 or clamped)
	_check(placed, "%s: the card stands %s what it describes (%s, %s)" % [label, where, rect, anchor])


func _check_closed(shell, label: String) -> void:
	var card := _card(shell)
	_check(not bool(card.get("visible", false)) and String(card.get("kind", "")) == "" and (card.get("shown", {}) as Dictionary).is_empty() and (card.get("board_subject", {}) as Dictionary).is_empty(), "%s: letting go closes the card (%s %s %s)" % [label, card.get("visible", false), card.get("kind", ""), card.get("board_subject", {})])


func _check_screen() -> void:
	var shell = await _open_shell()
	if shell._session == null or shell._session.battle.is_empty():
		await _close_shell(shell)
		return
	var board = shell._battle_board_view
	var battle: Dictionary = shell._session.battle
	var scenery := _scenery_point(shell, board)
	_check(scenery.x >= 0.0, "screen: the window shows scenery beside the field")
	await _hover_at(scenery)
	_check_plates(board, battle)
	await _capture("plates")
	await _check_hint(shell, board, battle, scenery)
	await _check_stack_cards(shell, board, battle, scenery)
	await _check_chip_card(shell, board, battle)
	await _check_hero_cards(shell, board, battle)
	await _check_live_card(shell, board)
	await _close_shell(shell)


## Each stack's plate on the prepared round.
func _check_plates(board, battle: Dictionary) -> void:
	var veil := _veil(battle)
	_check_plate(board, battle, "report_waiter", {"waiting": true})
	_check_plate(board, battle, "report_guard", {"defending": true})
	_check_plate(board, battle, "report_shooter", {"effect_ids": [String(veil.get("effect_id", ""))]})
	# Three statuses: the two that end soonest, then "+1".
	_check_plate(board, battle, "report_target", {"effect_ids": ["status_rooted", "status_staggered"], "overflow": 1})
	_check_plate(board, battle, "report_giant", {})
	_details["plate_shooter"] = board.validation_stack_plate("report_shooter")
	_details["plate_target"] = board.validation_stack_plate("report_target")


## The forecast names the right button on the first HINT_HOVERS hovers of a
## chip, a hero or a stack the cursor gives no order for, then only on the
## enemy's hero; an order's forecast never does.
func _check_hint(shell, board, battle: Dictionary, scenery: Vector2) -> void:
	var guard := _stack_point(board, battle, "report_guard")
	var waiter := _stack_point(board, battle, "report_waiter")
	var chip: Vector2 = board.global_position + _chip_rect(board, "report_target").get_center()
	var stops := [
		["stack:report_guard", guard], ["stack:report_waiter", waiter], ["chip:report_target", chip],
		["hero:player", _hero_point(board, "player")], ["stack:report_guard", guard], ["stack:report_waiter", waiter],
	]
	for index in range(stops.size()):
		await _hover_at(stops[index][1])
		var hint: Dictionary = board.validation_details_hint()
		_check(String(hint.get("subject", "")) == String(stops[index][0]) and int(hint.get("hovers", 0)) == index + 1 and bool(hint.get("shown", false)), "hint: hover %d, on %s, names the right button %s" % [index + 1, stops[index][0], hint])
		_check(_forecast(board).ends_with(HINT), "hint: hover %d says how to see the details: %s" % [index + 1, _forecast(board)])
		if index == 0:
			await _capture("hint")
	await _hover_at(_stack_point(board, battle, "report_target"))
	_check(String(board.validation_pointer_order().get("kind", "")) == "shoot" and not _forecast(board).contains(HINT), "hint: an order's forecast does not carry it: %s" % _forecast(board))
	await _hover_at(guard)
	var after: Dictionary = board.validation_details_hint()
	_check(int(after.get("hovers", 0)) == HINT_HOVERS + 1 and not bool(after.get("shown", true)) and not _forecast(board).contains(HINT), "hint: after %d hovers it stops %s: %s" % [HINT_HOVERS, after, _forecast(board)])
	await _hover_at(_hero_point(board, "enemy"))
	_check(bool(board.validation_details_hint().get("shown", false)) and _forecast(board).ends_with(HINT), "hint: the enemy's hero always names it: %s" % _forecast(board))
	await _hover_at(_hero_point(board, "player"))
	_check(not bool(board.validation_details_hint().get("shown", true)) and not _forecast(board).contains(HINT), "hint: the player's hero no longer does: %s" % _forecast(board))
	await _hover_at(scenery)


## The right button on stacks: the card opens beside the stack and says what
## the rules say; the plate is ringed, the drawn cursor and the forecast step
## aside; letting go anywhere closes it.
func _check_stack_cards(shell, board, battle: Dictionary, scenery: Vector2) -> void:
	var target := _stack_point(board, battle, "report_target")
	await _hover_at(target)
	var before: Dictionary = board.validation_pointer_order()
	_check(String(before.get("kind", "")) == "shoot" and int(before.get("cursor_shape", -1)) != Control.CURSOR_ARROW, "hold: the archers aim at the brute with the drawn arrow (%s, %s)" % [before.get("kind", ""), before.get("cursor_shape", -1)])
	await _right_button(target, true)
	_check_card(shell, "stack", "report_target", _stack_texts(battle, "report_target", false), "card brute")
	_check_card_place(shell, "beside", "card brute")
	var held: Dictionary = board.validation_pointer_order()
	_check(int(held.get("cursor_shape", -1)) == Control.CURSOR_ARROW, "hold: the plain pointer stands in for the drawn arrow while the card shows (%s)" % held.get("cursor_shape", -1))
	_check(bool(board.validation_stack_plate("report_target").get("highlighted", false)), "hold: the brute's plate is ringed")
	_details["card_brute"] = _texts(shell)
	await _capture("details_stack_enemy")
	await _right_button(target, false)
	_check_closed(shell, "release brute")
	var after: Dictionary = board.validation_pointer_order()
	_check(String(after.get("kind", "")) == "shoot" and int(after.get("cursor_shape", -1)) == int(before.get("cursor_shape", -2)), "release: the drawn arrow comes back (%s)" % after.get("cursor_shape", -1))
	# The others, each let go of somewhere else.
	for entry in [["report_guard", false, "card river guard"], ["report_waiter", true, "card pikewards"], ["report_giant", false, "card sovereign"]]:
		var point := _stack_point(board, battle, String(entry[0]))
		await _hover_at(point)
		await _right_button(point, true)
		_check_card(shell, "stack", String(entry[0]), _stack_texts(battle, String(entry[0]), bool(entry[1])), String(entry[2]))
		_check_card_place(shell, "beside", String(entry[2]))
		_check(bool(board.validation_stack_plate(String(entry[0])).get("highlighted", false)), "%s: the plate is ringed" % entry[2])
		_details[String(entry[2]).replace(" ", "_")] = _texts(shell)
		await _hover_at(scenery)
		await _right_button(scenery, false)
		_check_closed(shell, String(entry[2]))
	_check(_texts(shell).is_empty(), "release: nothing is left on the card")
	_check(String(_details.get("card_sovereign", {}).get("subtitle", "")).ends_with("Large"), "card sovereign: a two-hex stack is called large")


## The right button on a ribbon chip: the card of its stack under the chip.
func _check_chip_card(shell, board, battle: Dictionary) -> void:
	var rect := _chip_rect(board, "report_target")
	_check(rect.size.x > 0.0, "chip: the brute has a chip on the ribbon")
	if rect.size.x <= 0.0:
		return
	var point: Vector2 = board.global_position + rect.get_center()
	await _hover_at(point)
	await _right_button(point, true)
	_check_card(shell, "chip", "report_target", _stack_texts(battle, "report_target", false), "chip")
	_check_card_place(shell, "below", "chip")
	_check(bool(board.validation_stack_plate("report_target").get("highlighted", false)), "chip: the brute's plate on the field is ringed")
	await _capture("details_chip")
	await _right_button(point, false)
	_check_closed(shell, "chip")


## The right button on each hero and on each hero's plate.
func _check_hero_cards(shell, board, battle: Dictionary) -> void:
	for side in ["enemy", "player"]:
		var figure: Dictionary = board.hero_figure_layout(side)
		_check(bool(figure.get("has_figure", false)), "hero: the %s hero stands beside the field" % side)
		var point := _hero_point(board, side)
		await _hover_at(point)
		await _right_button(point, true)
		var expected := _hero_texts(battle, side)
		_check_card(shell, "hero", side, expected, "hero %s" % side)
		_check_card_place(shell, "left" if side == "enemy" else "right", "hero %s" % side)
		var faction_id := String(ContentService.get_hero(ENEMY_HERO_ID).get("faction_id", "")) if side == "enemy" else String((battle.get("player_commander_state", {}) as Dictionary).get("faction_id", "faction_embercourt"))
		_check(String(_texts(shell).get("subtitle", "")).begins_with(String(ContentService.get_faction(faction_id).get("name", "?"))), "hero %s: the card names the hero's faction (%s)" % [side, _texts(shell).get("subtitle", "")])
		_details["card_hero_%s" % side] = _texts(shell)
		await _capture("details_hero_%s" % side)
		await _right_button(point, false)
		_check_closed(shell, "hero %s" % side)
	_check(String(_details.get("card_hero_player", {}).get("footer", "")) == "Has cast a spell this round.", "hero player: the card says the hero has cast this round")
	_check((_details.get("card_hero_enemy", {}).get("specialties", []) as Array).size() == 1, "hero enemy: the card lists the hero's specialty")
	for entry in [["player", shell._player_plate], ["enemy", shell._enemy_plate]]:
		var plate: Control = entry[1]
		_check(plate.visible, "plate: the %s hero's plate shows" % entry[0])
		var point: Vector2 = plate.get_global_rect().get_center()
		await _hover_at(point)
		await _right_button(point, true)
		_check_card(shell, "hero", String(entry[0]), _hero_texts(battle, String(entry[0])), "hero plate %s" % entry[0])
		_check_card_place(shell, "left" if entry[0] == "enemy" else "right", "hero plate %s" % entry[0])
		await _right_button(point + Vector2(0.0, -200.0), false)
		_check_closed(shell, "hero plate %s" % entry[0])


## The card held on the acting archers keeps up while they defend and the
## enemy plays its turns: Stone Veil now counts their next turns, and the
## Defend stance shows.
func _check_live_card(shell, board) -> void:
	var battle: Dictionary = shell._session.battle
	var point := _stack_point(board, battle, "report_shooter")
	await _hover_at(point)
	await _right_button(point, true)
	var expected := _stack_texts(battle, "report_shooter", false)
	_check_card(shell, "stack", "report_shooter", expected, "card archers")
	_check_card_place(shell, "beside", "card archers")
	_check((expected.get("effects", []) as Array).any(func(line): return String(line).begins_with("Stone Veil") and String(line).ends_with("after this one")), "card archers: Stone Veil leaves out the turn it was cast in %s" % [expected.get("effects", [])])
	_details["card_archers"] = _texts(shell)
	await _capture("details_stack_shooter")
	shell._on_defend_pressed()
	await _settle(shell)
	battle = shell._session.battle
	var archers := _stack(battle, "report_shooter")
	if battle.is_empty() or BattleRules._alive_count(archers) <= 0:
		_check(not bool(_card(shell).get("visible", true)), "live: the card closes when its stack is gone")
		await _right_button(point, false)
		return
	var veil := _veil(battle)
	_check(bool(archers.get("defending", false)) and not veil.is_empty() and not bool(veil.get("skip_current_turn", false)), "live: the archers defend and Stone Veil now counts their turns %s" % [veil])
	var live := _stack_texts(battle, "report_shooter", false)
	_check_card(shell, "stack", "report_shooter", live, "live archers")
	_check((live.get("effects", []) as Array).has("Defending +%d defense until the round ends" % (2 + int(BattleRules._hero_payload_for_side(battle, "player").get("defend_defense_bonus", 0)))), "live: the card shows the Defend stance %s" % [live.get("effects", [])])
	_details["card_archers_live"] = _texts(shell)
	# The pikewards act now, so they no longer wait.
	if _active(battle) == "report_waiter":
		_check_plate(board, battle, "report_waiter", {})
	await _capture("details_live")
	await _right_button(point, false)
	_check_closed(shell, "live archers")


## While a spell waits for its target the right button puts the spell away,
## on the field and on the hero's plate, and shows no card.
func _check_spell_targeting() -> void:
	if not _prepare(_base_session, false):
		return
	var shell = await _open_shell()
	if shell._session == null or shell._session.battle.is_empty():
		await _close_shell(shell)
		return
	var board = shell._battle_board_view
	var target := _stack_point(board, shell._session.battle, "report_target")
	for where in ["field", "plate"]:
		await _click_at(_hero_point(board, "player"))
		var row: Button = null
		for child in shell._spell_list.get_children():
			if child is Button and String(child.get_meta("spell_id", "")) == DAMAGE_SPELL:
				row = child
		_check(row != null and not row.disabled, "spell: the spellbook offers %s" % DAMAGE_SPELL)
		if row == null or row.disabled:
			shell._close_popovers()
			break
		await _click_at(row.get_global_rect().get_center())
		_check(shell._spell_targeting_id == DAMAGE_SPELL, "spell: choosing Cinder Burst lights its targets")
		var point: Vector2 = target if where == "field" else shell._player_plate.get_global_rect().get_center()
		await _hover_at(point)
		await _right_button(point, true)
		_check(shell._spell_targeting_id == "" and not bool(_card(shell).get("visible", true)), "spell: the right button on the %s puts the spell away and shows no card" % where)
		await _right_button(point, false)
	await _right_button(target, true)
	_check_card(shell, "stack", "report_target", _stack_texts(shell._session.battle, "report_target", false), "spell put away")
	await _right_button(target, false)
	_check_closed(shell, "spell put away")
	await _close_shell(shell)
