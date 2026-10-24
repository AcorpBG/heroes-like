extends RefCounted

const BattleEngine = preload("res://scripts/core/BattleEngine.gd")

static func effect(battle: Dictionary, id: String) -> Dictionary:
	return BattleEngine.native(&"TownBattleRules.effect", [battle, id])

static func defends(battle: Dictionary, stack: Dictionary) -> bool:
	return BattleEngine.native(&"TownBattleRules.defends", [battle, stack])

static func damage_multiplier(battle: Dictionary, attacker: Dictionary, defender: Dictionary, ranged: bool) -> float:
	return BattleEngine.native(&"TownBattleRules.damage_multiplier", [battle, attacker, defender, ranged])

static func movement_penalty(battle: Dictionary, stack: Dictionary) -> int:
	return BattleEngine.native(&"TownBattleRules.movement_penalty", [battle, stack])

static func absorb(stack: Dictionary, damage: int) -> int:
	return BattleEngine.native_writing(&"TownBattleRules.absorb", [stack, damage])
