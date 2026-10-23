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

static func summary(battle: Dictionary, stack: Dictionary) -> String:
	var parts: Array = []
	if defends(battle, stack):
		for id in ["beacon_volley", "prism_ward", "root_ward", "bellwake_fog"]:
			var active := effect(battle, id)
			if not active.is_empty(): parts.append(String(active.get("description", id)))
		if int(stack.get("town_shield_hp", 0)) > 0: parts.append("Pressure shield: %d damage absorption remaining" % int(stack.town_shield_hp))
	elif movement_penalty(battle, stack) > 0:
		parts.append(String(effect(battle, "chainboom").get("description", "Chainboom slows ground movement")))
	return "; ".join(parts)
