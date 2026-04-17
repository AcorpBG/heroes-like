class_name BattleAiRules
extends RefCounted

const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")

const STATUS_HARRIED := "status_harried"
const STATUS_STAGGERED := "status_staggered"
const COHESION_MIN := 0
const COHESION_MAX := 10
const MOMENTUM_MAX := 4
const FIELD_OBJECTIVES_KEY := "field_objectives"
const STACK_HEX_KEY := "hex"
const COMMANDER_SPELL_CAST_ROUNDS_KEY := "commander_spell_cast_rounds"
const ENEMY_COMMANDER_SPELL_DRAIN_LOCK_KEY := "_enemy_commander_spell_cast_in_drain"
const BATTLE_HEX_COLUMNS := 11
const BATTLE_HEX_ROWS := 7

static func _opposing_side(side: String) -> String:
	if side == "player":
		return "enemy"
	if side == "enemy":
		return "player"
	return ""

static func _field_objectives(battle: Dictionary) -> Array:
	var objectives = battle.get(FIELD_OBJECTIVES_KEY, [])
	return objectives if objectives is Array else []

static func _commander_spell_cast_this_round(battle: Dictionary, side: String) -> bool:
	if battle.is_empty() or side == "":
		return false
	if side == "enemy" and bool(battle.get(ENEMY_COMMANDER_SPELL_DRAIN_LOCK_KEY, false)):
		return true
	var cast_rounds = battle.get(COMMANDER_SPELL_CAST_ROUNDS_KEY, {})
	if not (cast_rounds is Dictionary):
		return false
	return int(cast_rounds.get(side, 0)) >= int(battle.get("round", 1))

static func _side_controls_field_objective_type(battle: Dictionary, side: String, objective_type: String) -> bool:
	for objective in _field_objectives(battle):
		if objective is Dictionary and String(objective.get("type", "")) == objective_type and String(objective.get("control_side", "")) == side:
			return true
	return false

static func _reserve_wave_ready_round(battle: Dictionary, side: String) -> int:
	var ready_round := 3
	if side == "":
		return ready_round
	if _side_controls_field_objective_type(battle, side, "supply_post"):
		ready_round -= 1
	elif _side_controls_field_objective_type(battle, _opposing_side(side), "supply_post"):
		ready_round += 1
	return clamp(ready_round, 2, 4)

static func _reserve_wave_is_active_for_side(battle: Dictionary, side: String) -> bool:
	return side != "" and _battle_has_tag(battle, "reserve_wave") and int(battle.get("round", 1)) >= _reserve_wave_ready_round(battle, side)

static func _field_objective_attack_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var side := String(stack.get("side", ""))
	var bonus := 0
	for objective in _field_objectives(battle):
		if not (objective is Dictionary) or String(objective.get("control_side", "")) != side:
			continue
		match String(objective.get("type", "")):
			"lane_battery":
				if bool(stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0:
					bonus += 1
			"cover_line":
				if bool(stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0 and not _stack_is_isolated(battle, stack):
					bonus += 1
			"obstruction_line":
				if not bool(stack.get("ranged", false)) and (
					int(battle.get("distance", 1)) <= 1
					or int(battle.get("round", 1)) >= int(objective.get("urgency_round", 2))
				):
					bonus += 1
			"breach_point":
				if not bool(stack.get("ranged", false)) and int(battle.get("round", 1)) >= int(objective.get("urgency_round", 3)):
					bonus += 1
	return min(bonus, 2)

static func _field_objective_defense_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var side := String(stack.get("side", ""))
	var bonus := 0
	for objective in _field_objectives(battle):
		if not (objective is Dictionary) or String(objective.get("control_side", "")) != side:
			continue
		match String(objective.get("type", "")):
			"cover_line":
				if bool(stack.get("ranged", false)) or bool(stack.get("defending", false)):
					bonus += 1
			"obstruction_line":
				if not bool(stack.get("ranged", false)):
					bonus += 1
			"supply_post":
				if not _stack_is_isolated(battle, stack):
					bonus += 1
			"signal_beacon":
				bonus += 1
			"breach_point":
				if _stack_is_anchor_side(stack, battle):
					bonus += 1
	return min(bonus, 2)

static func _field_objective_cohesion_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var side := String(stack.get("side", ""))
	var bonus := 0
	for objective in _field_objectives(battle):
		if not (objective is Dictionary):
			continue
		var controller := String(objective.get("control_side", "neutral"))
		match String(objective.get("type", "")):
			"cover_line":
				if controller == side and (bool(stack.get("ranged", false)) or not _stack_is_isolated(battle, stack)):
					bonus += 1
				elif controller == _opposing_side(side) and bool(stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0:
					bonus -= 1
			"obstruction_line":
				if controller == side and not bool(stack.get("ranged", false)):
					bonus += 1
				elif controller == _opposing_side(side) and not bool(stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0:
					bonus -= 1
			"supply_post":
				if controller == side and not _stack_is_isolated(battle, stack):
					bonus += 1
			"breach_point":
				if controller == side and _stack_is_anchor_side(stack, battle):
					bonus += 1
			"hazard_zone", "ritual_pylon":
				if controller == _opposing_side(side) and int(battle.get("round", 1)) >= int(objective.get("urgency_round", 2)):
					bonus -= 1
	return clamp(bonus, -2, 2)

static func _field_objective_momentum_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var side := String(stack.get("side", ""))
	var bonus := 0
	for objective in _field_objectives(battle):
		if not (objective is Dictionary) or String(objective.get("control_side", "")) != side:
			continue
		match String(objective.get("type", "")):
			"cover_line":
				if bool(stack.get("ranged", false)) and int(battle.get("round", 1)) <= 2 and int(battle.get("distance", 1)) > 0:
					bonus += 1
			"obstruction_line":
				if not bool(stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0 and int(battle.get("round", 1)) >= int(objective.get("urgency_round", 2)):
					bonus += 1
			"breach_point":
				if not bool(stack.get("ranged", false)) and int(battle.get("round", 1)) >= int(objective.get("urgency_round", 3)):
					bonus += 1
			"lane_battery":
				if bool(stack.get("ranged", false)) and int(battle.get("round", 1)) <= 2 and int(battle.get("distance", 1)) > 0:
					bonus += 1
	return min(bonus, 2)

static func _field_objective_commander_modifier(attacker: Dictionary, defender: Dictionary, battle: Dictionary) -> float:
	var modifier := 1.0
	var attacker_side := String(attacker.get("side", ""))
	var defender_side := String(defender.get("side", ""))
	if _side_controls_field_objective_type(battle, attacker_side, "cover_line") and int(battle.get("distance", 1)) > 0:
		modifier *= 1.06
	if _side_controls_field_objective_type(battle, defender_side, "cover_line") and int(battle.get("distance", 1)) > 0:
		modifier *= 0.94
	if _side_controls_field_objective_type(battle, attacker_side, "signal_beacon"):
		modifier *= 1.05
	if _side_controls_field_objective_type(battle, defender_side, "signal_beacon"):
		modifier *= 0.95
	if (
		not bool(attacker.get("ranged", false))
		and _side_controls_field_objective_type(battle, defender_side, "obstruction_line")
		and int(battle.get("distance", 1)) > 0
	):
		modifier *= 0.94
	if (
		not bool(attacker.get("ranged", false))
		and _side_controls_field_objective_type(battle, attacker_side, "obstruction_line")
		and int(battle.get("round", 1)) >= 2
	):
		modifier *= 1.04
	if _side_controls_field_objective_type(battle, attacker_side, "ritual_pylon"):
		modifier *= 1.03
	return modifier

static func _stack_is_cover_screened(stack: Dictionary, battle: Dictionary) -> bool:
	if stack.is_empty():
		return false
	if bool(stack.get("ranged", false)):
		return true
	if _has_ability(stack, "formation_guard") or _has_ability(stack, "brace"):
		return true
	return bool(stack.get("defending", false)) and not _stack_is_isolated(battle, stack)

static func _stack_can_breach_obstruction(stack: Dictionary, battle: Dictionary) -> bool:
	if stack.is_empty() or bool(stack.get("ranged", false)):
		return false
	if _has_ability(stack, "reach") or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard"):
		return true
	if _stack_momentum_total(stack, battle) >= 2:
		return true
	return int(stack.get("speed", 0)) >= 5

static func _advance_distance_delta(stack: Dictionary, battle: Dictionary) -> int:
	if stack.is_empty() or int(battle.get("distance", 1)) <= 0:
		return 0
	var opposing_side := _opposing_side(String(stack.get("side", "")))
	if _side_controls_field_objective_type(battle, opposing_side, "obstruction_line") and not _stack_can_breach_obstruction(stack, battle):
		return 0
	return 1

static func _field_objective_cover_damage_modifier(
	attacker: Dictionary,
	defender: Dictionary,
	battle: Dictionary,
	is_ranged: bool,
	attack_distance: int
) -> float:
	if not is_ranged or attack_distance <= 0:
		return 1.0
	var modifier := 1.0
	var attacker_side := String(attacker.get("side", ""))
	var defender_side := String(defender.get("side", ""))
	if _side_controls_field_objective_type(battle, defender_side, "cover_line"):
		modifier *= 0.85 if _stack_is_cover_screened(defender, battle) else 0.93
	if _side_controls_field_objective_type(battle, attacker_side, "cover_line") and _stack_is_cover_screened(attacker, battle):
		modifier *= 1.08
	return modifier

static func _objective_action_score(
	battle: Dictionary,
	acting_side: String,
	action: String,
	acting_stack: Dictionary,
	target_stack: Dictionary = {}
) -> float:
	var score := 0.0
	for objective in _field_objectives(battle):
		if not (objective is Dictionary):
			continue
		var influence := _field_objective_action_influence(objective, battle, acting_side, action, acting_stack, target_stack)
		if influence <= 0:
			continue
		score += float(influence) * _field_objective_value(objective, battle, acting_side, action, acting_stack, target_stack)
	return score

static func _field_objective_value(
	objective: Dictionary,
	battle: Dictionary,
	acting_side: String,
	action: String,
	acting_stack: Dictionary,
	target_stack: Dictionary
) -> float:
	var objective_type := String(objective.get("type", ""))
	var controller := String(objective.get("control_side", "neutral"))
	var urgency_round := int(objective.get("urgency_round", 2))
	var value := 1.15
	match objective_type:
		"lane_battery":
			value = 1.8 if int(battle.get("distance", 1)) > 0 else 1.1
			if bool(target_stack.get("ranged", false)):
				value += 0.35
		"cover_line":
			value = 1.55 if int(battle.get("distance", 1)) > 0 else 1.15
			if bool(target_stack.get("ranged", false)):
				value += 0.35
			if _has_ability(target_stack, "formation_guard") or _has_ability(target_stack, "brace"):
				value += 0.2
			if int(_hero_payload_for_side(battle, acting_side).get("mana_current", 0)) > 0:
				value += 0.2
		"obstruction_line":
			value = 1.6 if int(battle.get("distance", 1)) > 0 else 1.2
			if _has_ability(target_stack, "formation_guard") or _has_ability(target_stack, "brace") or _has_ability(target_stack, "reach"):
				value += 0.35
			if bool(target_stack.get("ranged", false)):
				value -= 0.15
		"ritual_pylon":
			value = 1.45
			if int(battle.get("round", 1)) >= urgency_round:
				value += 0.45
		"supply_post":
			value = 1.35
			if _battle_has_tag(battle, "reserve_wave"):
				value += 0.5
		"signal_beacon":
			value = 1.3
			if int(_hero_payload_for_side(battle, acting_side).get("mana_current", 0)) > 0:
				value += 0.25
		"breach_point":
			value = 1.55
			if int(battle.get("round", 1)) >= urgency_round:
				value += 0.5
		"hazard_zone":
			value = 1.4
			if int(battle.get("round", 1)) >= urgency_round:
				value += 0.55
	if controller == _opposing_side(acting_side):
		value += 0.35
	elif controller == acting_side:
		value -= 0.1
	if action == "cast_spell" and objective_type not in ["ritual_pylon", "hazard_zone", "signal_beacon"]:
		value *= 0.9
	if action == "defend" and objective_type in ["lane_battery", "cover_line", "signal_beacon", "supply_post"] and bool(acting_stack.get("ranged", false)):
		value += 0.2
	return value

static func _field_objective_action_influence(
	objective: Dictionary,
	battle: Dictionary,
	acting_side: String,
	action: String,
	acting_stack: Dictionary,
	target_stack: Dictionary
) -> int:
	var controller := String(objective.get("control_side", "neutral"))
	var contested := controller != acting_side
	var is_ranged := bool(acting_stack.get("ranged", false))
	match String(objective.get("type", "")):
		"lane_battery":
			match action:
				"advance":
					return 2 if contested and not is_ranged else (1 if contested else 0)
				"strike":
					return 2 if contested and not is_ranged else 1
				"shoot":
					if is_ranged:
						if acting_side == controller:
							return 2
						return 2 if bool(target_stack.get("ranged", false)) else 1
				"defend":
					return 1 if acting_side == controller and (is_ranged or _has_ability(acting_stack, "brace") or _has_ability(acting_stack, "formation_guard")) else 0
		"cover_line":
			match action:
				"advance":
					return 2 if contested and not is_ranged else (1 if contested else 0)
				"strike":
					return 2 if contested and not is_ranged else 1
				"shoot":
					return 1 if is_ranged and acting_side == controller else 0
				"defend":
					return 2 if acting_side == controller and (
						is_ranged
						or _has_ability(acting_stack, "brace")
						or _has_ability(acting_stack, "formation_guard")
					) else (1 if contested and not is_ranged else 0)
				"cast_spell":
					return 1
		"obstruction_line":
			match action:
				"advance":
					return 2 if contested and not is_ranged else (1 if contested else 0)
				"strike":
					return 2 if not is_ranged else 0
				"defend":
					return 2 if acting_side == controller and (
						not is_ranged
						or _has_ability(acting_stack, "brace")
						or _has_ability(acting_stack, "formation_guard")
						or _has_ability(acting_stack, "reach")
					) else (1 if contested and not is_ranged else 0)
		"ritual_pylon":
			match action:
				"advance", "strike":
					return 2 if contested and not is_ranged else 1
				"cast_spell":
					return 1
				"defend":
					return 1 if acting_side == controller else 0
		"supply_post":
			match action:
				"defend":
					return 2
				"strike":
					return 1 if not is_ranged else 0
				"advance":
					return 1 if contested and not is_ranged else 0
		"signal_beacon":
			match action:
				"advance":
					return 1 if contested else 0
				"defend":
					return 2 if acting_side == controller else 1
				"shoot":
					return 1 if is_ranged else 0
				"cast_spell":
					return 1
		"breach_point":
			match action:
				"advance":
					return 2 if not is_ranged else 0
				"strike":
					return 2 if not is_ranged else 1
				"defend":
					return 2 if acting_side == controller and _stack_is_anchor_side({"side": acting_side}, battle) else 0
		"hazard_zone":
			match action:
				"advance", "strike":
					return 2 if contested and not is_ranged else 1
				"cast_spell":
					return 1
				"defend":
					return 1 if acting_side == controller else 0
	return 0

static func choose_enemy_action(battle: Dictionary, active_stack: Dictionary, enemy_hero: Dictionary) -> Dictionary:
	if active_stack.is_empty() or String(active_stack.get("side", "")) != "enemy":
		return {}

	var targets := _alive_stacks_for_side(battle, "player")
	if targets.is_empty():
		return {}

	var best_spell := _best_spell_action(battle, active_stack, enemy_hero, targets)
	var best_attack := _best_attack_action(battle, active_stack, targets)
	var defend_score := _defend_score(battle, active_stack, targets)
	var advance_score := _advance_score(battle, active_stack, targets)
	var distance := int(battle.get("distance", 1))
	var best := {"action": "defend", "score": defend_score}
	if not best_attack.is_empty() and _candidate_beats(best_attack, best):
		best = best_attack
	if not best_spell.is_empty() and _candidate_beats(best_spell, best):
		best = best_spell
	if distance > 0:
		var advance_candidate := {"action": "advance", "score": advance_score}
		if _candidate_beats(advance_candidate, best):
			best = advance_candidate
	if String(best.get("action", "")) == "advance" and not _should_close_distance(active_stack) and not best_attack.is_empty():
		var best_attack_score := float(best_attack.get("score", -9999.0))
		if best_attack_score >= float(best.get("score", -9999.0)) - 0.25:
			return best_attack
	return best

static func _best_spell_action(
	battle: Dictionary,
	active_stack: Dictionary,
	enemy_hero: Dictionary,
	targets: Array
) -> Dictionary:
	if _commander_spell_cast_this_round(battle, String(active_stack.get("side", ""))):
		return {}
	var best := {}
	for spell in SpellRulesScript.known_spells(enemy_hero, SpellRulesScript.CONTEXT_BATTLE):
		if not (spell is Dictionary):
			continue
		var effect = spell.get("effect", {})
		match String(effect.get("type", "")):
			"damage_enemy":
				for target in targets:
					if not (target is Dictionary):
						continue
					var validation := SpellRulesScript.validate_battle_spell(
						enemy_hero,
						battle,
						active_stack,
						target,
						spell,
						"enemy"
					)
					if not bool(validation.get("ok", false)):
						continue
					var score := _damage_spell_score(enemy_hero, battle, active_stack, target, spell)
					var candidate := {
						"action": "cast_spell",
						"spell_id": String(spell.get("id", "")),
						"target_battle_id": String(target.get("battle_id", "")),
						"score": score,
					}
					if _candidate_beats(candidate, best):
						best = candidate
			"defense_buff":
				if _spell_buff_already_active(active_stack, battle, spell):
					continue
				var validation := SpellRulesScript.validate_battle_spell(
					enemy_hero,
					battle,
					active_stack,
					{},
					spell,
					"enemy"
				)
				if not bool(validation.get("ok", false)):
					continue
				var defense_candidate := {
					"action": "cast_spell",
					"spell_id": String(spell.get("id", "")),
					"target_battle_id": String(active_stack.get("battle_id", "")),
					"score": _buff_spell_score(battle, active_stack, targets, spell),
				}
				if _candidate_beats(defense_candidate, best):
					best = defense_candidate
			"initiative_buff", "attack_buff":
				if _spell_buff_already_active(active_stack, battle, spell):
					continue
				var validation := SpellRulesScript.validate_battle_spell(
					enemy_hero,
					battle,
					active_stack,
					{},
					spell,
					"enemy"
				)
				if not bool(validation.get("ok", false)):
					continue
				var initiative_candidate := {
					"action": "cast_spell",
					"spell_id": String(spell.get("id", "")),
					"target_battle_id": String(active_stack.get("battle_id", "")),
					"score": _buff_spell_score(battle, active_stack, targets, spell),
				}
				if _candidate_beats(initiative_candidate, best):
					best = initiative_candidate
	return best

static func _best_attack_action(battle: Dictionary, active_stack: Dictionary, targets: Array) -> Dictionary:
	var best := {}
	if bool(active_stack.get("ranged", false)) and int(active_stack.get("shots_remaining", 0)) > 0:
		for target in targets:
			if not (target is Dictionary):
				continue
			if not _can_make_ranged_attack(active_stack, battle, target):
				continue
			var ranged_candidate := {
				"action": "shoot",
				"target_battle_id": String(target.get("battle_id", "")),
				"score": _attack_score(active_stack, target, battle, true),
			}
			if _candidate_beats(ranged_candidate, best):
				best = ranged_candidate

	for target in targets:
		if not (target is Dictionary):
			continue
		if not _can_make_melee_attack(active_stack, battle, target):
			continue
		var melee_candidate := {
			"action": "strike",
			"target_battle_id": String(target.get("battle_id", "")),
			"score": _attack_score(active_stack, target, battle, false),
		}
		if _candidate_beats(melee_candidate, best):
			best = melee_candidate

	return best

static func _attack_score(attacker: Dictionary, target: Dictionary, battle: Dictionary, is_ranged: bool) -> float:
	var attack_distance := _attack_distance_for_action(attacker, target, battle, is_ranged)
	var damage := _estimate_damage(attacker, target, battle, is_ranged, false, attack_distance)
	var target_health: int = max(1, int(target.get("total_health", 0)))
	var side := String(attacker.get("side", ""))
	var round_number := int(battle.get("round", 1))
	var score := float(damage) / float(max(1, int(target.get("unit_hp", 1))))
	score += min(1.0, float(damage) / float(target_health)) * 8.0
	if damage >= target_health:
		score += 6.0
	if bool(target.get("ranged", false)):
		score += 2.5
	if int(target.get("shots_remaining", 0)) > 0:
		score += 1.0
	score += (1.0 - _health_ratio(target)) * 3.0
	score += (1.0 - (float(_stack_cohesion_total(target, battle)) / float(COHESION_MAX))) * 3.5
	score += float(_stack_momentum_total(attacker, battle)) * 0.6
	if _stack_cohesion_total(target, battle) <= 3:
		score += 2.5
	if _stack_is_isolated(battle, target):
		score += 1.5
	if _stack_cohesion_total(attacker, battle) <= 4:
		score -= 1.5
	if is_ranged and int(battle.get("distance", 1)) > 0:
		score += 2.0
	if is_ranged and int(battle.get("distance", 1)) == 0:
		score -= 1.5
	if is_ranged and int(battle.get("distance", 1)) > 0 and _side_controls_field_objective_type(battle, String(target.get("side", "")), "cover_line"):
		score -= 2.5 if _stack_is_cover_screened(target, battle) else 1.0
	if _side_controls_field_objective_type(battle, String(target.get("side", "")), "cover_line") and _stack_is_cover_screened(target, battle):
		score += 1.25
	if _battle_has_tag(battle, "elevated_fire") and is_ranged:
		score += 2.0
	if _battle_has_tag(battle, "fog_bank") and is_ranged and int(battle.get("distance", 1)) > 0:
		score -= 2.0
	if _battle_has_any_tags(battle, ["chokepoint", "fortified_line"]) and not is_ranged:
		score += 1.5
	if _battle_has_tag(battle, "fortress_lane"):
		if _stack_is_anchor_side(attacker, battle) and not is_ranged and (_has_ability(attacker, "reach") or _has_ability(attacker, "brace") or _has_ability(attacker, "formation_guard")):
			score += 1.5
		elif _stack_is_assault_side(attacker, battle) and is_ranged and int(battle.get("distance", 1)) > 0:
			score -= 1.5
	if _reserve_wave_is_active_for_side(battle, side) and _stack_is_anchor_side(attacker, battle) and not _stack_is_isolated(battle, attacker):
		score += 1.5
	if _battle_has_tag(battle, "battery_nest") and _stack_is_anchor_side(attacker, battle) and is_ranged:
		score += 2.0
		if _stack_has_positive_effect(attacker, battle):
			score += 1.0
	if _battle_has_tag(battle, "wall_pressure") and _stack_is_assault_side(attacker, battle) and not is_ranged and round_number >= 3:
		score += 1.75
	if _side_controls_field_objective_type(battle, String(target.get("side", "")), "obstruction_line") and (
		_has_ability(target, "formation_guard")
		or _has_ability(target, "brace")
		or _has_ability(target, "reach")
		or bool(target.get("defending", false))
	):
		score += 2.0
	if _battle_has_tag(battle, "bog_channels") and (_has_ability(attacker, "harry") or _has_ability(attacker, "backstab") or _has_ability(attacker, "bloodrush")):
		score += 1.5
	if _has_ability(attacker, "harry") and is_ranged and not SpellRulesScript.has_effect_id(target, battle, STATUS_HARRIED):
		score += 2.0
	if _has_ability(attacker, "backstab") and SpellRulesScript.has_any_effect_ids(target, battle, [STATUS_HARRIED, STATUS_STAGGERED]):
		score += 2.5
	if is_ranged and _side_defending_count(battle, side) > 0 and _side_has_ability(battle, side, "formation_guard"):
		score += 1.5
	if _has_ability(attacker, "formation_guard") and SpellRulesScript.has_effect_id(target, battle, STATUS_STAGGERED):
		score += 1.5
	var bloodrush := _ability_by_id(attacker, "bloodrush")
	if not bloodrush.is_empty() and _health_ratio(target) <= float(bloodrush.get("wounded_threshold_ratio", 0.0)):
		score += 2.0
	if not bloodrush.is_empty() and SpellRulesScript.has_any_effect_ids(target, battle, bloodrush.get("status_ids", [])):
		score += 1.5
	if not bloodrush.is_empty() and int(battle.get("round", 1)) >= 3:
		score += 0.75
	if _hero_has_trait(battle, side, "artillerist") and is_ranged and _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
		score += 1.5
	if _hero_has_trait(battle, side, "packhunter") and (_health_ratio(target) <= 0.75 or SpellRulesScript.has_any_effect_ids(target, battle, [STATUS_HARRIED, STATUS_STAGGERED])):
		score += 1.25
	if _hero_has_trait(battle, side, "vanguard") and not is_ranged and int(battle.get("round", 1)) <= 2:
		score += 1.0
	if _hero_has_trait(battle, side, "ambusher") and not is_ranged and (String(battle.get("terrain", "")) == "forest" or _battle_has_tag(battle, "ambush_cover")) and int(battle.get("round", 1)) <= 2:
		score += 1.0
	if is_ranged and _side_controls_field_objective_type(battle, side, "cover_line") and _stack_is_cover_screened(attacker, battle):
		score += 1.25
	score += _objective_action_score(battle, side, "shoot" if is_ranged else "strike", attacker, target)
	if not is_ranged and int(target.get("retaliations_left", 0)) > 0 and _alive_count(target) > 0 and _can_make_retaliation(target, attack_distance):
		var retaliation_damage := _estimate_damage(target, attacker, battle, false, true, attack_distance)
		score -= (float(retaliation_damage) / float(max(1, int(attacker.get("unit_hp", 1))))) * 0.45
	return score

static func _damage_spell_score(
	enemy_hero: Dictionary,
	battle: Dictionary,
	active_stack: Dictionary,
	target: Dictionary,
	spell: Dictionary
) -> float:
	var effect = spell.get("effect", {})
	var power := int(enemy_hero.get("command", {}).get("power", 0))
	var damage: int = max(
		1,
		int(effect.get("base_damage", 0)) + (max(0, power) * int(effect.get("power_scale", 0)))
	)
	var score := _attack_score(active_stack, target, battle, true) + 1.5
	score += min(1.0, float(damage) / float(max(1, int(target.get("total_health", 0))))) * 6.0
	var status_effect := _status_effect_from_spell(spell)
	var status_id := String(status_effect.get("effect_id", ""))
	if status_id != "" and not SpellRulesScript.has_effect_id(target, battle, status_id):
		score += 2.0
		score += _allied_status_synergy_score(battle, String(active_stack.get("side", "")), status_id)
		if status_id == STATUS_HARRIED and _health_ratio(target) <= 0.75:
			score += 1.0
	var status_modifiers = status_effect.get("modifiers", {})
	if status_modifiers is Dictionary and int(status_modifiers.get("cohesion", 0)) < 0:
		score += float(abs(int(status_modifiers.get("cohesion", 0)))) * 1.3
	if _stack_cohesion_total(target, battle) <= 4:
		score += 1.5
	if _battle_has_tag(battle, "fog_bank"):
		score += 1.5
	if _battle_has_tag(battle, "battery_nest") and _stack_is_anchor_side(active_stack, battle):
		score += 1.5
	if _battle_has_tag(battle, "wall_pressure") and status_id == STATUS_HARRIED and _stack_is_assault_side(active_stack, battle) and int(battle.get("round", 1)) >= 3:
		score += 1.0
	if _battle_has_tag(battle, "bog_channels") and status_id == STATUS_HARRIED:
		score += 1.5
	if _hero_has_trait(battle, String(active_stack.get("side", "")), "bogwise") and (_battle_has_tag(battle, "bog_channels") or String(battle.get("terrain", "")) == "mire"):
		score += 1.0
	if _hero_has_trait(battle, String(active_stack.get("side", "")), "packhunter") and _health_ratio(target) <= 0.75:
		score += 1.0
	score += _objective_action_score(battle, String(active_stack.get("side", "")), "cast_spell", active_stack, target)
	score -= float(int(spell.get("mana_cost", 0))) * 0.25
	return score

static func _buff_spell_score(
	battle: Dictionary,
	active_stack: Dictionary,
	targets: Array,
	spell: Dictionary
) -> float:
	var modifiers: Dictionary = SpellRulesScript.battle_spell_modifiers(spell)
	var score := 1.5
	var round_number := int(battle.get("round", 1))
	var defense_bonus := int(modifiers.get("defense", 0))
	if defense_bonus > 0:
		score += float(defense_bonus) * 1.2
		score += (1.0 - _health_ratio(active_stack)) * 4.0
		if int(battle.get("distance", 1)) == 0:
			score += 2.5
		elif not bool(active_stack.get("ranged", false)):
			score += 1.5
		if _has_hostile_ranged_pressure(targets):
			score += 1.0
		if _battle_has_any_tags(battle, ["chokepoint", "fortified_line"]):
			score += 1.5
		if _battle_has_tag(battle, "fortress_lane") and _stack_is_anchor_side(active_stack, battle):
			score += 1.5
		if _reserve_wave_is_active_for_side(battle, String(active_stack.get("side", ""))) and _stack_is_anchor_side(active_stack, battle):
			score += 1.0
		if _hero_has_trait(battle, String(active_stack.get("side", "")), "linekeeper"):
			score += 1.0
		if String(active_stack.get("faction_id", "")) == "faction_sunvault" and _battle_has_any_tags(battle, ["fortified_line", "elevated_fire"]):
			score += 1.0
	var initiative_bonus := int(modifiers.get("initiative", 0))
	if initiative_bonus > 0:
		score += float(initiative_bonus) * 1.1
		if int(battle.get("round", 1)) <= 2:
			score += 1.5
		if int(battle.get("distance", 1)) > 0 and not bool(active_stack.get("ranged", false)):
			score += 2.0
		if _battle_has_any_tags(battle, ["ambush_cover", "open_lane"]) and int(battle.get("round", 1)) <= 2:
			score += 1.0
		if _reserve_wave_is_active_for_side(battle, String(active_stack.get("side", ""))) and _stack_is_anchor_side(active_stack, battle):
			score += 1.5
		if String(active_stack.get("faction_id", "")) == "faction_sunvault" and _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
			score += 1.0
	var attack_bonus := int(modifiers.get("attack", 0))
	if attack_bonus > 0:
		score += float(attack_bonus) * 1.35
		if bool(active_stack.get("ranged", false)) and int(active_stack.get("shots_remaining", 0)) > 0:
			score += 1.0
		if _can_make_melee_attack(active_stack, battle):
			score += 1.5
		if String(active_stack.get("faction_id", "")) == "faction_mireclaw" and _enemy_wounded_count(battle, String(active_stack.get("side", ""))) > 0:
			score += 1.0
			if _side_has_ability(battle, String(active_stack.get("side", "")), "bloodrush"):
				score += 1.5
		if String(active_stack.get("faction_id", "")) == "faction_embercourt" and _side_defending_count(battle, String(active_stack.get("side", ""))) > 0:
			score += 1.0
			if _side_has_ability(battle, String(active_stack.get("side", "")), "formation_guard"):
				score += 1.5
		if String(spell.get("effect", {}).get("type", "")) == "attack_buff" and not bool(active_stack.get("ranged", false)) and int(battle.get("round", 1)) >= 3:
			score += 0.75
		if _battle_has_tag(battle, "elevated_fire") and bool(active_stack.get("ranged", false)):
			score += 1.25
		if _battle_has_tag(battle, "battery_nest") and _stack_is_anchor_side(active_stack, battle) and bool(active_stack.get("ranged", false)):
			score += 1.75
		if _battle_has_tag(battle, "wall_pressure") and _stack_is_assault_side(active_stack, battle) and not bool(active_stack.get("ranged", false)) and round_number >= 3:
			score += 1.25
		if _battle_has_tag(battle, "bog_channels") and (_has_ability(active_stack, "harry") or _has_ability(active_stack, "backstab") or _has_ability(active_stack, "bloodrush")):
			score += 1.25
		if String(active_stack.get("faction_id", "")) == "faction_sunvault" and _side_positive_effect_count(battle, String(active_stack.get("side", ""))) > 0:
			score += 1.25
	var cohesion_bonus := int(modifiers.get("cohesion", 0))
	if cohesion_bonus > 0:
		score += float(cohesion_bonus) * 1.25
		score += (1.0 - (float(_stack_cohesion_total(active_stack, battle)) / float(COHESION_MAX))) * 4.5
		if _stack_is_isolated(battle, active_stack):
			score += 1.5
		if _battle_has_tag(battle, "fortress_lane") and _stack_is_anchor_side(active_stack, battle):
			score += 1.0
		if _reserve_wave_is_active_for_side(battle, String(active_stack.get("side", ""))) and _stack_is_anchor_side(active_stack, battle):
			score += 1.5
		if _hero_has_trait(battle, String(active_stack.get("side", "")), "linekeeper"):
			score += 1.0
		if String(active_stack.get("faction_id", "")) == "faction_sunvault" and _battle_has_any_tags(battle, ["fortified_line", "elevated_fire"]):
			score += 1.0
	var momentum_bonus := int(modifiers.get("momentum", 0))
	if momentum_bonus > 0:
		score += float(momentum_bonus) * 1.4
		if _can_make_melee_attack(active_stack, battle) or (bool(active_stack.get("ranged", false)) and int(active_stack.get("shots_remaining", 0)) > 0):
			score += 1.5
		if _hero_has_trait(battle, String(active_stack.get("side", "")), "vanguard") or _hero_has_trait(battle, String(active_stack.get("side", "")), "packhunter"):
			score += 1.0
		if _reserve_wave_is_active_for_side(battle, String(active_stack.get("side", ""))) and _stack_is_anchor_side(active_stack, battle):
			score += 1.25
		if _battle_has_tag(battle, "wall_pressure") and _stack_is_assault_side(active_stack, battle) and not bool(active_stack.get("ranged", false)) and round_number >= 3:
			score += 1.5
		if String(active_stack.get("faction_id", "")) == "faction_sunvault" and _side_positive_effect_count(battle, String(active_stack.get("side", ""))) >= 2:
			score += 1.0
	if String(active_stack.get("faction_id", "")) == "faction_sunvault" and not _stack_has_positive_effect(active_stack, battle):
		score += 1.5
	score += _objective_action_score(battle, String(active_stack.get("side", "")), "cast_spell", active_stack, active_stack)
	score += float(_alive_count(active_stack)) * 0.2
	score -= float(int(spell.get("mana_cost", 0))) * 0.2
	return score

static func _defend_score(battle: Dictionary, active_stack: Dictionary, targets: Array) -> float:
	var score := 2.0 + ((1.0 - _health_ratio(active_stack)) * 5.0)
	var round_number := int(battle.get("round", 1))
	score += (1.0 - (float(_stack_cohesion_total(active_stack, battle)) / float(COHESION_MAX))) * 5.0
	if bool(active_stack.get("ranged", false)) and int(active_stack.get("shots_remaining", 0)) > 0:
		score -= 3.0
	if int(battle.get("distance", 1)) > 0 and not bool(active_stack.get("ranged", false)):
		score -= 2.0
	if _has_ability(active_stack, "brace") and int(battle.get("distance", 1)) <= 1:
		score += 3.0
	if _has_ability(active_stack, "formation_guard") and _allied_ranged_count(battle, String(active_stack.get("side", ""))) > 0:
		score += 2.5
	if _battle_has_any_tags(battle, ["chokepoint", "fortified_line"]) and not bool(active_stack.get("ranged", false)):
		score += 1.5
	if _battle_has_tag(battle, "fortress_lane") and _stack_is_anchor_side(active_stack, battle) and not bool(active_stack.get("ranged", false)):
		score += 2.0
	if _reserve_wave_is_active_for_side(battle, String(active_stack.get("side", ""))) and _stack_is_anchor_side(active_stack, battle):
		score += 1.5
	if _battle_has_tag(battle, "battery_nest") and _stack_is_anchor_side(active_stack, battle) and bool(active_stack.get("ranged", false)) and _stack_has_positive_effect(active_stack, battle):
		score += 1.0
	if _side_controls_field_objective_type(battle, String(active_stack.get("side", "")), "cover_line") and bool(active_stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0:
		score += 2.0
	if _side_controls_field_objective_type(battle, String(active_stack.get("side", "")), "obstruction_line") and _stack_can_breach_obstruction(active_stack, battle) and int(battle.get("distance", 1)) > 0:
		score += 2.0
	if int(battle.get("distance", 1)) == 0 and _has_hostile_ranged_pressure(targets):
		score += 1.0
	if _stack_is_isolated(battle, active_stack):
		score += 2.0
	if _hero_has_trait(battle, String(active_stack.get("side", "")), "linekeeper"):
		score += 1.0
	score += _objective_action_score(battle, String(active_stack.get("side", "")), "defend", active_stack, active_stack)
	return score

static func _advance_score(battle: Dictionary, active_stack: Dictionary, targets: Array) -> float:
	if int(battle.get("distance", 1)) <= 0:
		return -9999.0
	var side := String(active_stack.get("side", ""))
	var round_number := int(battle.get("round", 1))
	var ranged := bool(active_stack.get("ranged", false))
	var distance_delta := _advance_distance_delta(active_stack, battle)
	var score := -0.5
	if _should_close_distance(active_stack):
		score += 2.5
	if not ranged:
		score += 2.0
		if int(battle.get("distance", 1)) >= 2:
			score += 0.75
	elif int(active_stack.get("shots_remaining", 0)) > 0:
		score -= 1.5
	if _has_hostile_ranged_pressure(targets) and not ranged:
		score += 1.0
	if distance_delta <= 0:
		score -= 4.0
	else:
		score += 0.75
		if _side_controls_field_objective_type(battle, _opposing_side(side), "obstruction_line"):
			if _stack_can_breach_obstruction(active_stack, battle):
				score += 1.5
			else:
				score -= 1.5
		if _side_controls_field_objective_type(battle, side, "obstruction_line"):
			score -= 3.0
		if _stack_cohesion_total(active_stack, battle) <= 4:
			score -= 1.25
	if _stack_is_isolated(battle, active_stack):
		score -= 0.5
	if _battle_has_tag(battle, "wall_pressure") and _stack_is_assault_side(active_stack, battle) and not ranged and round_number >= 3:
		score += 1.25
	if _hero_has_trait(battle, side, "vanguard") and not ranged and round_number <= 2:
		score += 1.0
	if _hero_has_trait(battle, side, "packhunter") and _enemy_wounded_count(battle, side) > 0 and not ranged:
		score += 0.75
	score += _objective_action_score(battle, side, "advance", active_stack)
	return score

static func _should_close_distance(active_stack: Dictionary) -> bool:
	if not bool(active_stack.get("ranged", false)):
		return true
	return int(active_stack.get("shots_remaining", 0)) <= 0

static func _estimate_damage(
	attacker: Dictionary,
	defender: Dictionary,
	battle: Dictionary,
	is_ranged: bool,
	is_retaliation: bool = false,
	attack_distance: int = -1
) -> int:
	var attacker_count: int = max(1, _alive_count(attacker))
	var min_damage: int = int(attacker.get("min_damage", 1))
	var max_damage: int = max(min_damage, int(attacker.get("max_damage", 1)))
	var base_damage: int = attacker_count * int(round(float(min_damage + max_damage) / 2.0))

	var attack_stat: int = int(attacker.get("attack", 0)) + SpellRulesScript.effect_bonus_for_kind(attacker, battle, "attack") + _contextual_attack_bonus(attacker, battle)
	var defense_stat: int = int(defender.get("defense", 0)) + SpellRulesScript.effect_bonus_for_kind(defender, battle, "defense") + _contextual_defense_bonus(defender, battle)
	attack_stat += _hero_bonus_for_side(battle, String(attacker.get("side", "")), "attack")
	defense_stat += _hero_bonus_for_side(battle, String(defender.get("side", "")), "defense")
	if bool(defender.get("defending", false)):
		defense_stat += 2

	var modifier := 1.0 + (clampf(float(attack_stat - defense_stat), -8.0, 8.0) * 0.05)
	if is_ranged and String(battle.get("terrain", "")) == "forest":
		modifier *= 0.8
	var resolved_distance := int(battle.get("distance", 1)) if attack_distance < 0 else attack_distance
	if is_ranged and resolved_distance == 0:
		modifier *= 0.6
	if not is_ranged and String(battle.get("terrain", "")) == "mire":
		modifier *= 0.9
	if is_retaliation:
		modifier *= 0.9
	modifier *= _cohesion_damage_modifier(attacker, defender, battle, is_ranged, is_retaliation)
	modifier *= _ability_damage_modifier(attacker, defender, battle, is_ranged, is_retaliation, resolved_distance)
	modifier *= _terrain_tag_damage_modifier(attacker, defender, battle, is_ranged, resolved_distance)
	modifier *= _field_objective_cover_damage_modifier(attacker, defender, battle, is_ranged, resolved_distance)
	modifier *= _faction_damage_modifier(attacker, defender, battle, is_ranged, resolved_distance)
	modifier *= _commander_damage_modifier(attacker, defender, battle, is_ranged, resolved_distance)
	modifier *= _damage_multiplier_for_side(battle, String(attacker.get("side", "")))

	return max(1, int(round(float(base_damage) * modifier)))

static func _hero_bonus_for_side(battle: Dictionary, side: String, kind: String) -> int:
	return int(_hero_payload_for_side(battle, side).get(kind, 0))

static func _damage_multiplier_for_side(battle: Dictionary, side: String) -> float:
	return float(_hero_payload_for_side(battle, side).get("damage_multiplier", 1.0))

static func _hero_payload_for_side(battle: Dictionary, side: String) -> Dictionary:
	if side == "player":
		return battle.get("player_hero", {})
	return battle.get("enemy_hero_payload", {})

static func _contextual_attack_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var bonus := 0
	var side := String(stack.get("side", ""))
	var round_number := int(battle.get("round", 1))
	if _battle_has_tag(battle, "elevated_fire") and bool(stack.get("ranged", false)):
		bonus += 1
	if _battle_has_tag(battle, "bog_channels") and (_has_ability(stack, "harry") or _has_ability(stack, "backstab") or _has_ability(stack, "bloodrush")):
		bonus += 1
	if _battle_has_tag(battle, "fortress_lane"):
		if _stack_is_anchor_side(stack, battle) and not bool(stack.get("ranged", false)) and (_has_ability(stack, "reach") or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard")):
			bonus += 1
		elif _stack_is_assault_side(stack, battle) and bool(stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0:
			bonus -= 1
	if _reserve_wave_is_active_for_side(battle, side) and _stack_is_anchor_side(stack, battle) and not _stack_is_isolated(battle, stack):
		bonus += 1
	if _battle_has_tag(battle, "battery_nest") and _stack_is_anchor_side(stack, battle) and bool(stack.get("ranged", false)):
		bonus += 1
		if _stack_has_positive_effect(stack, battle):
			bonus += 1
	if _battle_has_tag(battle, "wall_pressure") and _stack_is_assault_side(stack, battle) and not bool(stack.get("ranged", false)) and round_number >= 3:
		bonus += 1
	if _hero_has_trait(battle, side, "artillerist") and bool(stack.get("ranged", false)) and _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
		bonus += 1
	if _hero_has_trait(battle, side, "packhunter") and _enemy_wounded_count(battle, side) > 0:
		bonus += 1
	if _hero_has_trait(battle, side, "vanguard") and not bool(stack.get("ranged", false)) and int(battle.get("round", 1)) <= 2:
		bonus += 1
	if _hero_has_trait(battle, side, "ambusher") and not bool(stack.get("ranged", false)) and _battle_has_tag(battle, "ambush_cover") and int(battle.get("round", 1)) <= 2:
		bonus += 1
	if _hero_has_trait(battle, side, "bogwise") and (_battle_has_tag(battle, "bog_channels") or String(battle.get("terrain", "")) == "mire") and (_has_ability(stack, "harry") or _has_ability(stack, "backstab") or _has_ability(stack, "bloodrush")):
		bonus += 1
	if String(stack.get("faction_id", "")) == "faction_sunvault" and _stack_has_positive_effect(stack, battle):
		bonus += 1
		if bool(stack.get("ranged", false)) and _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
			bonus += 1
	bonus += _field_objective_attack_bonus(stack, battle)
	return bonus

static func _contextual_defense_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var bonus := 0
	var side := String(stack.get("side", ""))
	var round_number := int(battle.get("round", 1))
	if _battle_has_any_tags(battle, ["chokepoint", "fortified_line"]) and not bool(stack.get("ranged", false)) and (_has_ability(stack, "reach") or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard")):
		bonus += 1
	if _battle_has_tag(battle, "fortress_lane") and _stack_is_anchor_side(stack, battle) and not bool(stack.get("ranged", false)) and (_has_ability(stack, "reach") or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard")):
		bonus += 1
	if _reserve_wave_is_active_for_side(battle, side) and _stack_is_anchor_side(stack, battle) and not _stack_is_isolated(battle, stack):
		bonus += 1
	if _battle_has_tag(battle, "battery_nest") and _stack_is_anchor_side(stack, battle) and bool(stack.get("ranged", false)) and _stack_has_positive_effect(stack, battle):
		bonus += 1
	if _hero_has_trait(battle, side, "linekeeper") and (bool(stack.get("defending", false)) or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard")):
		bonus += 1
	if _hero_has_trait(battle, side, "bogwise") and String(battle.get("terrain", "")) == "mire" and not bool(stack.get("ranged", false)):
		bonus += 1
	bonus += _field_objective_defense_bonus(stack, battle)
	return bonus

static func _stack_cohesion_total(stack: Dictionary, battle: Dictionary) -> int:
	var total: int = (
		int(stack.get("cohesion", stack.get("cohesion_base", 5)))
		+ SpellRulesScript.effect_bonus_for_kind(stack, battle, "cohesion")
		+ _contextual_cohesion_bonus(stack, battle)
	)
	return clamp(total, COHESION_MIN, COHESION_MAX)

static func _stack_momentum_total(stack: Dictionary, battle: Dictionary) -> int:
	var total: int = (
		int(stack.get("momentum", 0))
		+ SpellRulesScript.effect_bonus_for_kind(stack, battle, "momentum")
		+ _contextual_momentum_bonus(stack, battle)
	)
	return clamp(total, 0, MOMENTUM_MAX)

static func _contextual_cohesion_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var bonus := 0
	var side := String(stack.get("side", ""))
	var round_number := int(battle.get("round", 1))
	if _stack_is_isolated(battle, stack):
		bonus -= 1
	if _battle_has_any_tags(battle, ["chokepoint", "fortified_line"]) and not bool(stack.get("ranged", false)) and (_has_ability(stack, "reach") or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard")):
		bonus += 1
	if _battle_has_tag(battle, "fortress_lane") and _stack_is_anchor_side(stack, battle) and not bool(stack.get("ranged", false)) and (_has_ability(stack, "reach") or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard")):
		bonus += 1
	if _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]) and bool(stack.get("ranged", false)):
		bonus += 1
	if _reserve_wave_is_active_for_side(battle, side) and _stack_is_anchor_side(stack, battle) and not _stack_is_isolated(battle, stack):
		bonus += 1
	if _battle_has_tag(battle, "battery_nest") and _stack_is_anchor_side(stack, battle) and bool(stack.get("ranged", false)):
		bonus += 1
		if _stack_has_positive_effect(stack, battle):
			bonus += 1
	if _battle_has_tag(battle, "wall_pressure") and _stack_is_assault_side(stack, battle) and not bool(stack.get("ranged", false)) and round_number >= 3:
		bonus += 1
	if SpellRulesScript.has_any_effect_ids(stack, battle, [STATUS_HARRIED, STATUS_STAGGERED]):
		bonus -= 1
	var shielding := _ability_by_id(stack, "shielding")
	if not shielding.is_empty():
		bonus += max(0, int(shielding.get("cohesion_hold_bonus", 0)))
	if _hero_has_trait(battle, side, "linekeeper") and (bool(stack.get("defending", false)) or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard")):
		bonus += 1
	if _hero_has_trait(battle, side, "artillerist") and bool(stack.get("ranged", false)) and _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
		bonus += 1
	if _hero_has_trait(battle, side, "bogwise") and (_battle_has_tag(battle, "bog_channels") or String(battle.get("terrain", "")) == "mire") and not _stack_is_isolated(battle, stack):
		bonus += 1
	if _hero_has_trait(battle, side, "ambusher") and not bool(stack.get("ranged", false)) and int(battle.get("round", 1)) <= 2 and _battle_has_tag(battle, "ambush_cover"):
		bonus += 1
	if String(stack.get("faction_id", "")) == "faction_embercourt" and _side_has_role_mix(battle, side) and not _stack_is_isolated(battle, stack):
		bonus += 1
	if String(stack.get("faction_id", "")) == "faction_mireclaw" and _enemy_wounded_count(battle, side) > 0 and not bool(stack.get("ranged", false)):
		bonus += 1
	if String(stack.get("faction_id", "")) == "faction_sunvault" and _stack_has_positive_effect(stack, battle) and not _stack_is_isolated(battle, stack):
		bonus += 1
		if _battle_has_any_tags(battle, ["fortified_line", "elevated_fire"]):
			bonus += 1
	bonus += _field_objective_cohesion_bonus(stack, battle)
	return bonus

static func _contextual_momentum_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var bonus := 0
	var side := String(stack.get("side", ""))
	var round_number := int(battle.get("round", 1))
	if _battle_has_tag(battle, "ambush_cover") and not bool(stack.get("ranged", false)) and int(battle.get("round", 1)) <= 2:
		bonus += 1
	if _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]) and bool(stack.get("ranged", false)) and int(battle.get("round", 1)) <= 2:
		bonus += 1
	if _battle_has_tag(battle, "bog_channels") and (_has_ability(stack, "harry") or _has_ability(stack, "backstab") or _has_ability(stack, "bloodrush")):
		bonus += 1
	if _reserve_wave_is_active_for_side(battle, side) and _stack_is_anchor_side(stack, battle) and not _stack_is_isolated(battle, stack):
		bonus += 1
	if _battle_has_tag(battle, "battery_nest") and _stack_is_anchor_side(stack, battle) and bool(stack.get("ranged", false)) and (_stack_has_positive_effect(stack, battle) or round_number <= 2):
		bonus += 1
	if _battle_has_tag(battle, "wall_pressure") and _stack_is_assault_side(stack, battle) and not bool(stack.get("ranged", false)) and round_number >= 3:
		bonus += 1
	if _hero_has_trait(battle, side, "packhunter") and _enemy_wounded_count(battle, side) > 0 and not bool(stack.get("ranged", false)):
		bonus += 1
	if _hero_has_trait(battle, side, "vanguard") and not bool(stack.get("ranged", false)) and (int(battle.get("round", 1)) <= 2 or _battle_has_tag(battle, "open_lane")):
		bonus += 1
	if _hero_has_trait(battle, side, "ambusher") and not bool(stack.get("ranged", false)) and int(battle.get("round", 1)) <= 2 and (String(battle.get("terrain", "")) == "forest" or _battle_has_tag(battle, "ambush_cover")):
		bonus += 1
	if _hero_has_trait(battle, side, "artillerist") and bool(stack.get("ranged", false)) and _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
		bonus += 1
	if _hero_has_trait(battle, side, "bogwise") and (_battle_has_tag(battle, "bog_channels") or String(battle.get("terrain", "")) == "mire") and (_has_ability(stack, "harry") or _has_ability(stack, "backstab") or _has_ability(stack, "bloodrush")):
		bonus += 1
	if String(stack.get("faction_id", "")) == "faction_sunvault" and _stack_has_positive_effect(stack, battle):
		bonus += 1
		if _side_positive_effect_count(battle, side) >= 2 and _battle_has_any_tags(battle, ["elevated_fire", "fortified_line"]):
			bonus += 1
	bonus += _field_objective_momentum_bonus(stack, battle)
	return bonus

static func _alive_stacks_for_side(battle: Dictionary, side: String) -> Array:
	var alive := []
	for stack in battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("side", "")) == side and _alive_count(stack) > 0:
			alive.append(stack)
	return alive

static func _stack_has_positive_effect(stack: Dictionary, battle: Dictionary) -> bool:
	var current_round := int(battle.get("round", 1))
	for effect in SpellRulesScript.active_effects_for_round(stack, current_round):
		var modifiers: Dictionary = effect.get("modifiers", {})
		if not (modifiers is Dictionary):
			continue
		for modifier_key in ["attack", "defense", "initiative", "cohesion", "momentum"]:
			if int(modifiers.get(modifier_key, 0)) > 0:
				return true
	return false

static func _side_positive_effect_count(battle: Dictionary, side: String) -> int:
	var total := 0
	for stack in _alive_stacks_for_side(battle, side):
		if stack is Dictionary and _stack_has_positive_effect(stack, battle):
			total += 1
	return total

static func _alive_count(stack: Dictionary) -> int:
	var unit_hp: int = max(1, int(stack.get("unit_hp", 1)))
	return int(ceil(float(max(0, int(stack.get("total_health", 0)))) / float(unit_hp)))

static func _health_ratio(stack: Dictionary) -> float:
	var max_health: int = max(1, int(stack.get("base_count", 0)) * max(1, int(stack.get("unit_hp", 1))))
	return clampf(float(max(0, int(stack.get("total_health", 0)))) / float(max_health), 0.0, 1.0)

static func _has_hostile_ranged_pressure(targets: Array) -> bool:
	for target in targets:
		if target is Dictionary and bool(target.get("ranged", false)) and _alive_count(target) > 0:
			return true
	return false

static func _can_make_melee_attack(stack: Dictionary, battle: Dictionary, target: Dictionary = {}) -> bool:
	if stack.is_empty() or _alive_count(stack) <= 0:
		return false
	if target.is_empty():
		for candidate in _alive_stacks_for_side(battle, _opposing_side(String(stack.get("side", "")))):
			if _can_make_melee_attack(stack, battle, candidate):
				return true
		return false
	if _alive_count(target) <= 0 or String(stack.get("side", "")) == String(target.get("side", "")):
		return false
	var hex_distance := _stack_hex_distance(stack, target)
	if hex_distance <= 1:
		return true
	return hex_distance == 2 and _has_ability(stack, "reach")

static func _can_make_ranged_attack(stack: Dictionary, battle: Dictionary, target: Dictionary) -> bool:
	return (
		not stack.is_empty()
		and not target.is_empty()
		and _alive_count(stack) > 0
		and _alive_count(target) > 0
		and String(stack.get("side", "")) != String(target.get("side", ""))
		and bool(stack.get("ranged", false))
		and int(stack.get("shots_remaining", 0)) > 0
		and not _stack_hex(stack).is_empty()
		and not _stack_hex(target).is_empty()
	)

static func _attack_distance_for_action(attacker: Dictionary, target: Dictionary, battle: Dictionary, is_ranged: bool) -> int:
	var hex_distance := _stack_hex_distance(attacker, target)
	if hex_distance >= 999:
		return int(battle.get("distance", 1))
	if is_ranged:
		return _distance_band_from_hex_distance(hex_distance)
	if hex_distance <= 1:
		return 0
	if hex_distance == 2 and _has_ability(attacker, "reach"):
		return 1
	return int(battle.get("distance", 1))

static func _stack_hex(stack: Dictionary) -> Dictionary:
	return _normalize_hex_cell(stack.get(STACK_HEX_KEY, {}))

static func _normalize_hex_cell(value: Variant) -> Dictionary:
	if value is Vector2i:
		return _hex_cell(value.x, value.y)
	if value is Dictionary:
		var q := int(value.get("q", value.get("x", -1)))
		var r := int(value.get("r", value.get("y", -1)))
		if _hex_in_bounds(q, r):
			return _hex_cell(q, r)
	return {}

static func _hex_cell(q: int, r: int) -> Dictionary:
	return {
		"q": clamp(q, 0, BATTLE_HEX_COLUMNS - 1),
		"r": clamp(r, 0, BATTLE_HEX_ROWS - 1),
	}

static func _hex_in_bounds(q: int, r: int) -> bool:
	return q >= 0 and q < BATTLE_HEX_COLUMNS and r >= 0 and r < BATTLE_HEX_ROWS

static func _stack_hex_distance(lhs: Dictionary, rhs: Dictionary) -> int:
	return _hex_distance(_stack_hex(lhs), _stack_hex(rhs))

static func _hex_distance(lhs: Dictionary, rhs: Dictionary) -> int:
	if lhs.is_empty() or rhs.is_empty():
		return 999
	var lhs_cube := _offset_to_cube(int(lhs.get("q", 0)), int(lhs.get("r", 0)))
	var rhs_cube := _offset_to_cube(int(rhs.get("q", 0)), int(rhs.get("r", 0)))
	return int(
		(
			abs(int(lhs_cube.get("x", 0)) - int(rhs_cube.get("x", 0)))
			+ abs(int(lhs_cube.get("y", 0)) - int(rhs_cube.get("y", 0)))
			+ abs(int(lhs_cube.get("z", 0)) - int(rhs_cube.get("z", 0)))
		) / 2
	)

static func _offset_to_cube(q: int, r: int) -> Dictionary:
	var x := q - int((r - (r % 2)) / 2)
	var z := r
	var y := -x - z
	return {"x": x, "y": y, "z": z}

static func _distance_band_from_hex_distance(hex_distance: int) -> int:
	if hex_distance <= 1:
		return 0
	if hex_distance <= 5:
		return 1
	return 2

static func _can_make_retaliation(stack: Dictionary, attack_distance: int) -> bool:
	if attack_distance <= 0:
		return true
	return attack_distance == 1 and _has_ability(stack, "reach")

static func _cohesion_damage_modifier(
	attacker: Dictionary,
	defender: Dictionary,
	battle: Dictionary,
	is_ranged: bool,
	is_retaliation: bool
) -> float:
	var modifier := 1.0
	var attacker_cohesion := _stack_cohesion_total(attacker, battle)
	var defender_cohesion := _stack_cohesion_total(defender, battle)
	var attacker_momentum := _stack_momentum_total(attacker, battle)
	if attacker_cohesion >= 8:
		modifier *= 1.05
	elif attacker_cohesion <= 3:
		modifier *= 0.9
	if defender_cohesion <= 3:
		modifier *= 1.08
	elif defender_cohesion <= 5:
		modifier *= 1.03
	modifier *= 1.0 + (float(attacker_momentum) * 0.04)
	if is_retaliation and attacker_cohesion <= 4:
		modifier *= 0.92
	if is_ranged and _stack_is_isolated(battle, attacker):
		modifier *= 0.94
	return modifier

static func _ability_damage_modifier(
	attacker: Dictionary,
	defender: Dictionary,
	battle: Dictionary,
	is_ranged: bool,
	is_retaliation: bool,
	attack_distance: int
) -> float:
	var modifier := 1.0
	var reach := _ability_by_id(attacker, "reach")
	if not is_ranged and attack_distance == 1 and not reach.is_empty():
		modifier *= float(reach.get("distance_one_multiplier", 1.0))

	var brace := _ability_by_id(attacker, "brace")
	if is_retaliation and bool(attacker.get("defending", false)) and not brace.is_empty():
		modifier *= float(brace.get("retaliation_multiplier", 1.0))

	var backstab := _ability_by_id(attacker, "backstab")
	if not backstab.is_empty() and SpellRulesScript.has_any_effect_ids(defender, battle, backstab.get("status_ids", [])):
		modifier *= float(backstab.get("damage_multiplier", 1.0))
	if not backstab.is_empty() and _health_ratio(defender) <= float(backstab.get("health_threshold_ratio", 0.0)):
		modifier *= float(backstab.get("threshold_damage_multiplier", 1.0))

	var volley := _ability_by_id(attacker, "volley")
	if is_ranged and not volley.is_empty() and attack_distance >= int(volley.get("min_distance", 1)):
		modifier *= float(volley.get("damage_multiplier", 1.0))
	if is_ranged and not volley.is_empty() and SpellRulesScript.has_any_effect_ids(defender, battle, volley.get("status_ids", [])):
		modifier *= float(volley.get("status_damage_multiplier", 1.0))
	if is_ranged and not volley.is_empty() and _side_defending_count(battle, String(attacker.get("side", ""))) > 0:
		modifier *= float(volley.get("ally_defending_multiplier", 1.0))

	var formation_guard := _ability_by_id(attacker, "formation_guard")
	if not formation_guard.is_empty() and SpellRulesScript.has_effect_id(defender, battle, STATUS_STAGGERED):
		modifier *= float(formation_guard.get("staggered_damage_multiplier", 1.0))

	var harry := _ability_by_id(attacker, "harry")
	if is_ranged and not harry.is_empty() and _health_ratio(defender) <= float(harry.get("wounded_threshold_ratio", 0.0)):
		modifier *= float(harry.get("wounded_damage_multiplier", 1.0))

	var bloodrush := _ability_by_id(attacker, "bloodrush")
	if not bloodrush.is_empty() and _health_ratio(defender) <= float(bloodrush.get("wounded_threshold_ratio", 0.0)):
		modifier *= float(bloodrush.get("wounded_damage_multiplier", 1.0))
	if not bloodrush.is_empty() and SpellRulesScript.has_any_effect_ids(defender, battle, bloodrush.get("status_ids", [])):
		modifier *= float(bloodrush.get("status_damage_multiplier", 1.0))

	var shielding := _ability_by_id(defender, "shielding")
	if is_ranged and not shielding.is_empty():
		modifier *= float(shielding.get("ranged_damage_multiplier", 1.0))
	var attacking_shielding := _ability_by_id(attacker, "shielding")
	if not is_ranged and not attacking_shielding.is_empty() and attack_distance <= 0:
		modifier *= float(attacking_shielding.get("engaged_damage_multiplier", 1.0))
	if not is_ranged and not attacking_shielding.is_empty() and SpellRulesScript.has_effect_id(defender, battle, STATUS_HARRIED):
		modifier *= float(attacking_shielding.get("harried_damage_multiplier", 1.0))

	return modifier

static func _faction_damage_modifier(
	attacker: Dictionary,
	defender: Dictionary,
	battle: Dictionary,
	is_ranged: bool,
	attack_distance: int
) -> float:
	var modifier := 1.0
	var faction_id := String(attacker.get("faction_id", ""))
	var side := String(attacker.get("side", ""))
	if faction_id == "":
		faction_id = _side_faction_id(battle, side)
	var side_defending_count := _side_defending_count(battle, side)
	match faction_id:
		"faction_embercourt":
			if is_ranged and side_defending_count > 0:
				modifier *= 1.08
				if _side_has_ability(battle, side, "formation_guard"):
					modifier *= _side_max_ability_float(battle, side, "formation_guard", "ally_ranged_damage_multiplier", 1.0)
			if SpellRulesScript.has_effect_id(defender, battle, STATUS_STAGGERED):
				modifier *= 1.08
			if int(battle.get("round", 1)) >= 3 and _side_has_role_mix(battle, side):
				modifier *= 1.06 if _side_has_ability(battle, side, "formation_guard") else 1.04
		"faction_mireclaw":
			var wounded_count := _enemy_wounded_count(battle, side)
			if wounded_count > 0:
				modifier *= 1.0 + (float(min(wounded_count, 3)) * 0.04)
			if SpellRulesScript.has_effect_id(defender, battle, STATUS_HARRIED):
				modifier *= 1.08
			if not is_ranged and int(battle.get("round", 1)) >= 3 and attack_distance <= 0:
				modifier *= 1.0 + (float(min(wounded_count, 2)) * 0.03)
		"faction_sunvault":
			var positive_effect_count := _side_positive_effect_count(battle, side)
			if _stack_has_positive_effect(attacker, battle):
				modifier *= 1.08
				if _battle_has_any_tags(battle, ["elevated_fire", "fortified_line"]):
					modifier *= 1.04
			if positive_effect_count >= 2:
				modifier *= 1.0 + (float(min(positive_effect_count, 3)) * 0.03)
			if SpellRulesScript.has_effect_id(defender, battle, STATUS_STAGGERED):
				modifier *= 1.05
			if is_ranged and _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]) and positive_effect_count > 0:
				modifier *= 1.04
	return modifier

static func _terrain_tag_damage_modifier(
	attacker: Dictionary,
	defender: Dictionary,
	battle: Dictionary,
	is_ranged: bool,
	attack_distance: int
) -> float:
	var modifier := 1.0
	if _battle_has_tag(battle, "elevated_fire") and is_ranged and attack_distance > 0:
		modifier *= 1.1
	if _battle_has_tag(battle, "open_lane") and is_ranged and attack_distance > 0:
		modifier *= 1.06
	if _battle_has_any_tags(battle, ["chokepoint", "fortified_line"]):
		if not is_ranged and attack_distance <= 1 and (_has_ability(attacker, "reach") or _has_ability(attacker, "brace") or _has_ability(attacker, "formation_guard")):
			modifier *= 1.08
		elif is_ranged and attack_distance > 0:
			modifier *= 0.92
	if _battle_has_tag(battle, "ambush_cover"):
		if not is_ranged and int(battle.get("round", 1)) <= 2:
			modifier *= 1.08
		elif is_ranged and attack_distance > 0:
			modifier *= 0.94
	if _battle_has_tag(battle, "bog_channels") and (
		_has_ability(attacker, "harry")
		or _has_ability(attacker, "backstab")
		or _has_ability(attacker, "bloodrush")
		or SpellRulesScript.has_effect_id(defender, battle, STATUS_HARRIED)
	):
		modifier *= 1.08
	if _battle_has_tag(battle, "fog_bank") and is_ranged and attack_distance > 0:
		modifier *= 0.88
	return modifier

static func _commander_damage_modifier(
	attacker: Dictionary,
	defender: Dictionary,
	battle: Dictionary,
	is_ranged: bool,
	attack_distance: int
) -> float:
	var modifier := 1.0
	var side := String(attacker.get("side", ""))
	if _hero_has_trait(battle, side, "artillerist") and is_ranged and _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
		modifier *= 1.06
	if _hero_has_trait(battle, side, "linekeeper") and is_ranged and _side_defending_count(battle, side) > 0:
		modifier *= 1.05
	if _hero_has_trait(battle, side, "packhunter") and (
		_health_ratio(defender) <= 0.75
		or SpellRulesScript.has_effect_id(defender, battle, STATUS_HARRIED)
		or SpellRulesScript.has_effect_id(defender, battle, STATUS_STAGGERED)
	):
		modifier *= 1.06
	if _hero_has_trait(battle, side, "bogwise") and (_battle_has_tag(battle, "bog_channels") or String(battle.get("terrain", "")) == "mire") and (
		_has_ability(attacker, "harry")
		or _has_ability(attacker, "backstab")
		or _has_ability(attacker, "bloodrush")
	):
		modifier *= 1.06
	if _hero_has_trait(battle, side, "vanguard") and not is_ranged and (int(battle.get("round", 1)) <= 2 or _battle_has_tag(battle, "open_lane")) and attack_distance <= 1:
		modifier *= 1.06
	if _hero_has_trait(battle, side, "ambusher") and not is_ranged and (String(battle.get("terrain", "")) == "forest" or _battle_has_tag(battle, "ambush_cover")) and int(battle.get("round", 1)) <= 2:
		modifier *= 1.06
	modifier *= _field_objective_commander_modifier(attacker, defender, battle)
	return modifier

static func _ability_by_id(stack: Dictionary, ability_id: String) -> Dictionary:
	if ability_id == "":
		return {}
	for ability in stack.get("abilities", []):
		if ability is Dictionary and String(ability.get("id", "")) == ability_id:
			return ability
	return {}

static func _has_ability(stack: Dictionary, ability_id: String) -> bool:
	return not _ability_by_id(stack, ability_id).is_empty()

static func _spell_buff_already_active(active_stack: Dictionary, battle: Dictionary, spell: Dictionary) -> bool:
	var modifiers: Dictionary = SpellRulesScript.battle_spell_modifiers(spell)
	if modifiers.is_empty():
		return false
	for modifier_key in modifiers.keys():
		var key := String(modifier_key)
		if SpellRulesScript.effect_bonus_for_kind(active_stack, battle, key) < int(modifiers[key]):
			return false
	return true

static func _status_effect_from_spell(spell: Dictionary) -> Dictionary:
	var status_effect = spell.get("effect", {}).get("status_effect", {})
	if status_effect is Dictionary:
		return status_effect
	return {}

static func _allied_status_synergy_score(battle: Dictionary, side: String, status_id: String) -> float:
	if status_id == "":
		return 0.0
	var score := 0.0
	for stack in _alive_stacks_for_side(battle, side):
		if _has_ability(stack, "backstab") and _ability_by_id(stack, "backstab").get("status_ids", []).has(status_id):
			score += 1.2
		if _has_ability(stack, "bloodrush") and _ability_by_id(stack, "bloodrush").get("status_ids", []).has(status_id):
			score += 1.0
		if bool(stack.get("ranged", false)) and _has_ability(stack, "volley") and _ability_by_id(stack, "volley").get("status_ids", []).has(status_id):
			score += 0.9
		if _has_ability(stack, "formation_guard") and status_id == STATUS_STAGGERED:
			score += 0.8
		if _has_ability(stack, "shielding") and status_id == STATUS_HARRIED:
			score += 0.6
	return min(score, 3.0)

static func _side_defending_count(battle: Dictionary, side: String) -> int:
	var total := 0
	for stack in _alive_stacks_for_side(battle, side):
		if bool(stack.get("defending", false)):
			total += 1
	return total

static func _side_has_ability(battle: Dictionary, side: String, ability_id: String) -> bool:
	for stack in _alive_stacks_for_side(battle, side):
		if _has_ability(stack, ability_id):
			return true
	return false

static func _battle_has_tag(battle: Dictionary, tag: String) -> bool:
	if tag == "":
		return false
	for value in battle.get("battlefield_tags", []):
		if String(value) == tag:
			return true
	return false

static func _battle_has_any_tags(battle: Dictionary, tags: Array) -> bool:
	for tag_value in tags:
		if _battle_has_tag(battle, String(tag_value)):
			return true
	return false

static func _capital_front_anchor_side(battle: Dictionary) -> String:
	if String(battle.get("context", {}).get("type", "")) == "town_defense":
		return "player"
	if _battle_has_any_tags(battle, ["fortress_lane", "reserve_wave", "battery_nest", "wall_pressure"]):
		return "enemy"
	return ""

static func _capital_front_assault_side(battle: Dictionary) -> String:
	var anchor_side := _capital_front_anchor_side(battle)
	if anchor_side == "player":
		return "enemy"
	if anchor_side == "enemy":
		return "player"
	return ""

static func _stack_is_anchor_side(stack: Dictionary, battle: Dictionary) -> bool:
	return String(stack.get("side", "")) == _capital_front_anchor_side(battle)

static func _stack_is_assault_side(stack: Dictionary, battle: Dictionary) -> bool:
	return String(stack.get("side", "")) == _capital_front_assault_side(battle)

static func _hero_has_trait(battle: Dictionary, side: String, trait_id: String) -> bool:
	if trait_id == "":
		return false
	for value in _hero_payload_for_side(battle, side).get("battle_traits", []):
		if String(value) == trait_id:
			return true
	return false

static func _side_max_ability_float(
	battle: Dictionary,
	side: String,
	ability_id: String,
	key: String,
	default_value: float = 1.0
) -> float:
	var best := default_value
	for stack in _alive_stacks_for_side(battle, side):
		var ability := _ability_by_id(stack, ability_id)
		if ability.is_empty():
			continue
		best = max(best, float(ability.get(key, default_value)))
	return best

static func _allied_ranged_count(battle: Dictionary, side: String) -> int:
	var total := 0
	for stack in _alive_stacks_for_side(battle, side):
		if bool(stack.get("ranged", false)):
			total += 1
	return total

static func _allied_melee_count(battle: Dictionary, side: String) -> int:
	var total := 0
	for stack in _alive_stacks_for_side(battle, side):
		if not bool(stack.get("ranged", false)):
			total += 1
	return total

static func _stack_is_isolated(battle: Dictionary, stack: Dictionary) -> bool:
	if stack.is_empty():
		return false
	var side := String(stack.get("side", ""))
	var living_allies := _alive_stacks_for_side(battle, side)
	if living_allies.size() <= 1:
		return true
	if bool(stack.get("ranged", false)):
		return _allied_melee_count(battle, side) <= 0
	return false

static func _side_has_role_mix(battle: Dictionary, side: String) -> bool:
	var ranged_alive := false
	var melee_alive := false
	for stack in _alive_stacks_for_side(battle, side):
		if bool(stack.get("ranged", false)):
			ranged_alive = true
		else:
			melee_alive = true
		if ranged_alive and melee_alive:
			return true
	return false

static func _enemy_wounded_count(battle: Dictionary, side: String) -> int:
	var opposing_side := "enemy"
	if side == "enemy":
		opposing_side = "player"
	var total := 0
	for stack in _alive_stacks_for_side(battle, opposing_side):
		if _health_ratio(stack) <= 0.75:
			total += 1
	return total

static func _side_faction_id(battle: Dictionary, side: String) -> String:
	for stack in _alive_stacks_for_side(battle, side):
		var faction_id := String(stack.get("faction_id", ""))
		if faction_id != "":
			return faction_id
	return ""

static func _candidate_beats(candidate: Dictionary, current_best: Dictionary) -> bool:
	if current_best.is_empty():
		return true
	if is_equal_approx(float(candidate.get("score", 0.0)), float(current_best.get("score", 0.0))):
		return String(candidate.get("action", "")) < String(current_best.get("action", ""))
	return float(candidate.get("score", 0.0)) > float(current_best.get("score", 0.0))
