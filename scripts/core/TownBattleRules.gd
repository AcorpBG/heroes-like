extends RefCounted

# A battle snapshots the defending town once. Loading or changing ownership
# later must not refill shields or replay healing already resolved this round.
static func prepare(battle: Dictionary, building_ids: Array, side: String) -> void:
	var defenses: Dictionary = {}
	for id in building_ids:
		var effect: Dictionary = ContentService.get_building(String(id)).get("town_defense_effect", {})
		if not effect.is_empty(): defenses[String(effect.id)] = effect.duplicate(true)
	if defenses.is_empty(): return
	battle["town_defenses"] = {"side": side, "effects": defenses, "last_healing_round": 0}
	var shield: Dictionary = defenses.get("pressure_shield", {})
	if not shield.is_empty():
		for stack in battle.get("stacks", []):
			if stack.get("side", "") == side:
				stack["town_shield_hp"] = maxi(0, int(ceil(float(stack.get("total_health", 0)) * float(shield.get("health_pct", 15)) / 100.0)))

static func effect(battle: Dictionary, id: String) -> Dictionary:
	var value: Dictionary = battle.get("town_defenses", {}).get("effects", {}).get(id, {})
	if value.is_empty() or int(battle.get("round", 1)) > int(value.get("rounds", 999)): return {}
	return value

static func defends(battle: Dictionary, stack: Dictionary) -> bool:
	return not battle.get("town_defenses", {}).is_empty() and stack.get("side", "") == battle.town_defenses.get("side", "")

static func damage_multiplier(battle: Dictionary, attacker: Dictionary, defender: Dictionary, ranged: bool) -> float:
	if not ranged: return 1.0
	var multiplier := 1.0
	if defends(battle, attacker):
		multiplier *= 1.0 + float(effect(battle, "beacon_volley").get("damage_pct", 0)) / 100.0
	if defends(battle, defender):
		multiplier *= 1.0 - float(effect(battle, "bellwake_fog").get("ranged_reduction_pct", 0)) / 100.0
	return multiplier

static func movement_penalty(battle: Dictionary, stack: Dictionary) -> int:
	if defends(battle, stack): return 0
	return int(effect(battle, "chainboom").get("movement_penalty", 0))

static func spell_resistance(battle: Dictionary, stack: Dictionary) -> int:
	return int(effect(battle, "prism_ward").get("resistance_pct", 0)) if defends(battle, stack) else 0

static func heal_round(battle: Dictionary) -> Array:
	var restored: Array = []
	var ward := effect(battle, "root_ward")
	var round_number := int(battle.get("round", 1))
	if ward.is_empty() or round_number < 2: return restored
	var state: Dictionary = battle.get("town_defenses", {})
	if int(state.get("last_healing_round", 0)) >= round_number: return restored
	state["last_healing_round"] = round_number
	for stack in battle.get("stacks", []):
		var health := int(stack.get("total_health", 0))
		if not defends(battle, stack) or health <= 0: continue
		var hp := maxi(1, int(stack.get("unit_hp", 1)))
		var living := int(ceil(float(health) / hp))
		var amount := mini(living * hp - health, maxi(1, int(ceil(float(hp) * float(ward.get("heal_pct", 25)) / 100.0))))
		if amount <= 0: continue
		stack["total_health"] = health + amount
		restored.append({"stack": stack, "amount": amount})
	return restored

static func absorb(stack: Dictionary, damage: int) -> int:
	var absorbed := mini(maxi(0, int(stack.get("town_shield_hp", 0))), maxi(0, damage))
	if absorbed > 0: stack["town_shield_hp"] = int(stack.town_shield_hp) - absorbed
	return absorbed

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
