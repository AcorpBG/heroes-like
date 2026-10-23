class_name BattleAiRules
extends RefCounted

const BattleEngine = preload("res://scripts/core/BattleEngine.gd")

static var _weights: Dictionary = {}

# The memos of one AI decision (_open_scoring_scope). Never saved.
static var _scoring_scope_depth := 0
# Per side: [payload source, commander source, scoring payload, trait set or null].
static var _scoring_payloads: Dictionary = {}
# Per side: entries [stacks array, the side's living stacks in it, how many of them are not ranged].
static var _scoring_living: Dictionary = {}
# Per stack battle_id: entries [stack, battle, total].
static var _scoring_cohesion: Dictionary = {}
static var _scoring_momentum: Dictionary = {}
# Per "attacker>target" battle ids: entries [attacker, target, battle, is_ranged, score].
static var _scoring_attack_scores: Dictionary = {}
# Per "defended>target" battle ids: entries [defended stack, target, battle, score].
static var _scoring_threats: Dictionary = {}
# Per "attacker>defender" battle ids: entries [attacker, defender, battle,
# is_ranged, is_retaliation, attack_distance, damage].
static var _scoring_damage: Dictionary = {}
# Per "term|stack battle_id": entries [stack, battle, value] of one stack's
# terms (_stack_term_memo); per "synergy|side|status": entries [battle, battle,
# score] of _allied_status_synergy_score.
static var _scoring_stack_terms: Dictionary = {}

## The next order on an enemy stack's turn. The hero's cast is a free action
## that comes first: "cast_spell" when the hero should cast now (see
## _hero_cast_worthwhile), else the stack's own order. With allow_hero_cast
## false, or once the hero has cast this round, only the stack's order.
static func choose_enemy_action(battle: Dictionary, active_stack: Dictionary, enemy_hero: Dictionary, allow_hero_cast: bool = true) -> Dictionary:
	return BattleEngine.native_writing(&"BattleAiRules.choose_enemy_action", [battle, active_stack, enemy_hero, allow_hero_cast])

## The best strike the stack can make this turn, from where it stands or after
## walking to the hex the AI picks, for a stack that fights hand to hand:
## {"action": "strike", "target_battle_id", "score"}, with "approach" when it
## walks first. {} when no enemy is in reach. advance_plan carries out an
## advance order with it.
static func best_reachable_strike(battle: Dictionary, active_stack: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"BattleAiRules.best_reachable_strike", [battle, active_stack])

## The enemy an advance heads for: the one the stack can walk to in the fewest
## steps around obstacles and stacks, then the nearest in hexes.
static func advance_target(battle: Dictionary, stack: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"BattleAiRules.advance_target", [battle, stack])

## Where an advance walks (the native BattleRules._apply_auto_advance_movement, also the
## player's Advance order): the legal destination that brings the stack nearest
## its target by walking, around obstacles and stacks, without standing closer
## than desired_gap to any enemy. A target it cannot walk to is measured in
## hexes. With no living enemy target given it heads for advance_target.
static func best_advance_destination(battle: Dictionary, stack: Dictionary, preferred_target: Dictionary = {}, desired_gap: int = 1) -> Dictionary:
	return BattleEngine.native_writing(&"BattleAiRules.best_advance_destination", [battle, stack, preferred_target, desired_gap])

## The next order on any stack's turn, for Quick Resolve, computer players'
## battles and the suggested order: the hero's free cast first when it should
## cast now, else the stack's own order (see choose_enemy_action).
static func choose_stack_tactical_order(battle: Dictionary, active_stack: Dictionary, target_side: String = "", commander_payload: Dictionary = {}, allow_hero_cast: bool = true) -> Dictionary:
	return BattleEngine.native_writing(&"BattleAiRules.choose_stack_tactical_order", [battle, active_stack, target_side, commander_payload, allow_hero_cast])

## Each damage and control spell scores its target with the shot's score, so
## inside a scoring scope one pair's score is worked out once.
static func _attack_score(attacker: Dictionary, target: Dictionary, battle: Dictionary, is_ranged: bool) -> float:
	return BattleEngine.native_writing(&"BattleAiRules._attack_score", [attacker, target, battle, is_ranged])

static func _buff_spell_score(battle: Dictionary, active_stack: Dictionary, target_stack: Dictionary, targets: Array, spell: Dictionary) -> float:
	return BattleEngine.native_writing(&"BattleAiRules._buff_spell_score", [battle, active_stack, target_stack, targets, spell])

## What bracing is worth to the stack this turn. The stack's own contact
## counts, not the closest pair on the field, and in the last rounds before
## stalemate (_clock_pressure) bracing loses its worth.
static func _defend_score(battle: Dictionary, active_stack: Dictionary, targets: Array) -> float:
	return BattleEngine.native_writing(&"BattleAiRules._defend_score", [battle, active_stack, targets])

static func _advance_score(battle: Dictionary, active_stack: Dictionary, targets: Array) -> float:
	return BattleEngine.native_writing(&"BattleAiRules._advance_score", [battle, active_stack, targets])

# Last scoring payload per side, reused while its source dictionaries compare
# equal. Scoring asks for it on every trait and damage check. Never saved.
static var _hero_payload_cache: Dictionary = {}
