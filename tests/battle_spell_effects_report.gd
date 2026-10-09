extends Node
## Battle spell effects (owner review 2026-10-09: buffs and debuffs were
## confusing and most spells felt the same). Checks one clear job per family
## in content, effects counted in the affected stack's own turns, initiative
## changes reordering the rest of the round, Rooted stopping movement,
## Staggered stopping retaliation, haste adding speed, plain-language
## summaries, and a rooted computer stack not choosing to advance. The battle
## comes from a generated small map.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "BATTLE_SPELL_EFFECTS_REPORT"
const SEED := "battle-spell-effects-20261009"

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
	_check_content()
	var battle := _battle()
	if not battle.is_empty():
		_check_turns(battle.duplicate(true))
		_check_order(battle.duplicate(true))
		_check_statuses(battle.duplicate(true))
		_check_texts(battle.duplicate(true))
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)

func _check_content() -> void:
	var families := {"attack_buff": ["attack", "momentum"], "defense_buff": ["cohesion", "defense"], "initiative_buff": ["initiative", "speed"]}
	var statuses := {"status_harried": ["Harried", "cohesion"], "status_staggered": ["Staggered", "initiative"], "status_rooted": ["Rooted", "defense"]}
	var counts := {}
	for spell in ContentService.load_json(ContentService.SPELLS_PATH).get("items", []):
		if String(spell.get("context", "")) != "battle":
			continue
		var effect: Dictionary = spell.get("effect", {})
		var kind := String(effect.get("type", ""))
		if families.has(kind):
			var keys: Array = effect.get("modifiers", {}).keys()
			keys.sort()
			_check(keys == families[kind], "%s (%s) adds exactly %s: %s" % [spell.id, kind, families[kind], keys])
		var status: Dictionary = effect.get("status_effect", {}) if effect.get("status_effect", {}) is Dictionary else {}
		if not status.is_empty():
			var status_id := String(status.get("effect_id", ""))
			counts[status_id] = int(counts.get(status_id, 0)) + 1
			_check(statuses.has(status_id) and String(status.get("label", "")) == String(statuses[status_id][0]) and status.get("modifiers", {}).keys() == [statuses[status_id][1]], "%s applies a plain %s: %s" % [spell.id, status_id, status])
	_check(int(counts.get("status_harried", 0)) >= 8 and int(counts.get("status_staggered", 0)) >= 8 and int(counts.get("status_rooted", 0)) >= 8, "the three statuses are all in use: %s" % counts)

func _battle() -> Dictionary:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(SEED, "", "", 2, "land", false, "homm3_small", ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, "faction_embercourt", "hero_caelen")
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	_check(bool(setup.get("ok", false)), "small generated setup")
	if not bool(setup.get("ok", false)):
		return {}
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state(session)
	var encounters: Array = session.overworld.get("encounters", [])
	_check(not encounters.is_empty(), "generated map has a guard to fight")
	if encounters.is_empty():
		return {}
	var battle := BattleRules.create_battle_payload(session, encounters[0])
	_check(battle.get("turn_order", []).size() >= 3, "battle has at least three stacks in the order")
	return battle

func _stack(battle: Dictionary, side: String, skip: int = 0) -> Dictionary:
	var seen := 0
	for battle_id in battle.get("turn_order", []):
		var stack := BattleRules._get_stack_by_id(battle, String(battle_id))
		if String(stack.get("side", "")) == side:
			if seen == skip:
				return stack
			seen += 1
	return {}

func _effect(modifiers: Dictionary, effect_id: String, turns: int) -> Dictionary:
	var effect := SpellRules.build_battle_effect(effect_id, effect_id.capitalize(), modifiers, turns, {"round": 1}, "spell", "report")
	return SpellRules._counted_in_turns(effect, turns)

func _turns_left(battle: Dictionary, battle_id: String, effect_id: String) -> int:
	for effect in BattleRules._get_stack_by_id(battle, battle_id).get("effects", []):
		if String(effect.get("effect_id", "")) == effect_id:
			return int(effect.get("turns_left", 0))
	return 0

func _check_turns(battle: Dictionary) -> void:
	var active_id := String(battle.get("active_stack_id", ""))
	var other := ""
	for battle_id in battle.get("turn_order", []):
		if String(battle_id) != active_id:
			other = String(battle_id)
			break
	BattleRules._apply_stack_effect(battle, active_id, _effect({"attack": 2}, "spell:self", 1))
	BattleRules._apply_stack_effect(battle, other, _effect({"defense": 2}, "spell:other", 1))
	BattleRules.spend_effect_turns(battle, active_id)
	_check(_turns_left(battle, active_id, "spell:self") == 1, "a buff cast on the acting stack keeps its turn when that turn ends")
	BattleRules.spend_effect_turns(battle, active_id)
	_check(_turns_left(battle, active_id, "spell:self") == 0, "it runs out after the stack's next turn")
	BattleRules._apply_stack_effect(battle, other, _effect({"defense": 2}, "spell:long", 2))
	BattleRules._prepare_round(battle, int(battle.get("round", 1)) + 1)
	_check(_turns_left(battle, other, "spell:other") == 1 and _turns_left(battle, other, "spell:long") == 2, "a new round does not end turn-counted effects")
	BattleRules.spend_effect_turns(battle, other)
	_check(_turns_left(battle, other, "spell:other") == 0 and _turns_left(battle, other, "spell:long") == 1, "the stack's own turn spends them")

func _check_order(battle: Dictionary) -> void:
	var order: Array = battle.get("turn_order", [])
	var last := String(order[order.size() - 1])
	BattleRules._apply_stack_effect(battle, last, _effect({"initiative": 40}, "spell:haste", 1))
	var after: Array = battle.get("turn_order", [])
	_check(after.find(last) == 1, "an initiative buff moves the stack up among those still to act this round: %s -> %s" % [order, after])
	_check(after[0] == order[0], "the acting stack keeps its turn")

func _check_statuses(battle: Dictionary) -> void:
	var melee := {}
	for stack in battle.get("stacks", []):
		if not bool(stack.get("ranged", false)) and BattleRules._alive_count(stack) > 0:
			melee = stack
			break
	_check(not melee.is_empty(), "a melee stack to test on")
	if melee.is_empty():
		return
	var id := String(melee.get("battle_id", ""))
	var free_moves := BattleRules._stack_movement_points(melee, battle)
	BattleRules._apply_stack_effect(battle, id, _effect({"speed": 1}, "spell:speed", 2))
	_check(BattleRules._stack_movement_points(BattleRules._get_stack_by_id(battle, id), battle) == free_moves + 1, "haste adds a hex of movement")
	_check(BattleRules._can_make_retaliation(BattleRules._get_stack_by_id(battle, id), 0, battle), "an unstaggered stack strikes back")
	BattleRules._apply_stack_effect(battle, id, _effect({"initiative": -1}, "status_staggered", 1))
	_check(not BattleRules._can_make_retaliation(BattleRules._get_stack_by_id(battle, id), 0, battle), "a staggered stack cannot strike back")
	_check(not BattleAiRules._can_make_retaliation(BattleRules._get_stack_by_id(battle, id), 0, battle), "the battle AI knows it too")
	BattleRules._apply_stack_effect(battle, id, _effect({"defense": -1}, "status_rooted", 1))
	var rooted := BattleRules._get_stack_by_id(battle, id)
	_check(BattleRules._stack_movement_points(rooted, battle) == 0 and BattleRules.legal_destinations_for_stack(battle, id).is_empty(), "a rooted stack cannot move")
	var foe := {}
	for stack in battle.get("stacks", []):
		if String(stack.get("side", "")) != String(rooted.get("side", "")) and BattleRules._alive_count(stack) > 0:
			foe = stack
			break
	if not foe.is_empty() and not BattleRules._can_make_melee_attack(rooted, battle, foe):
		_check(BattleRules.melee_approach_destination(battle, rooted, foe).is_empty(), "a rooted stack cannot walk up to strike")
	if String(rooted.get("side", "")) == "enemy":
		battle["active_stack_id"] = id
		var decision := BattleAiRules.choose_enemy_action(battle, rooted, {})
		_check(String(decision.get("action", "")) != "advance", "a rooted computer stack does not try to advance (%s)" % decision.get("action", ""))
	else:
		battle["active_stack_id"] = id
		_check(not bool(BattleRules.action_availability(battle).get("advance", true)), "advance is unavailable while rooted")

func _check_texts(battle: Dictionary) -> void:
	var caster := SpellRules.ensure_hero_spellbook({"name": "Report Caster", "command": {"power": 0, "knowledge": 6}, "spellbook": {"known_spell_ids": ["spell_briar_bind", "spell_lantern_phalanx", "spell_cinder_burst"], "mana": {"current": 40, "max": 40}}})
	var ally := _stack(battle, "player")
	var foe := _stack(battle, "enemy")
	var root_text := SpellRules._battle_spell_effect_summary(caster, ContentService.get_spell("spell_briar_bind"), battle, ally, foe)
	_check(root_text.contains("Rooted") and root_text.contains("cannot move") and root_text.contains("its next turn"), "Briar Bind says what it does: %s" % root_text)
	var buff_text := SpellRules._battle_spell_effect_summary(caster, ContentService.get_spell("spell_lantern_phalanx"), battle, ally, ally)
	_check(buff_text.contains("attack") and buff_text.contains("momentum") and buff_text.contains("its next 2 turns"), "Lantern Phalanx says what it does: %s" % buff_text)
	var burst_text := SpellRules._battle_spell_effect_summary(caster, ContentService.get_spell("spell_cinder_burst"), battle, ally, foe)
	_check(burst_text.contains("Staggered") and burst_text.contains("cannot strike back"), "Cinder Burst names its rider: %s" % burst_text)
	var foe_id := String(foe.get("battle_id", ""))
	BattleRules._apply_stack_effect(battle, foe_id, _effect({"defense": -1}, "status_rooted", 2))
	var listed := SpellRules.effect_summary(BattleRules._get_stack_by_id(battle, foe_id), battle)
	_check(listed.contains("cannot move") and listed.contains("2 turns"), "the stack's effect list says what Rooted does and for how long: %s" % listed)
