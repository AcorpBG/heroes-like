extends RefCounted

const Development = preload("res://scripts/core/TownDevelopmentRules.gd")
const Artifacts = preload("res://scripts/core/ArtifactRules.gd")
const Levels = preload("res://scripts/core/OverworldLevelRules.gd")
const Players = preload("res://scripts/core/PlayerIdentityRules.gd")
const GOLD_RESERVE := 2000

static func can_visit(town: Dictionary, raid: Dictionary, controller: String) -> bool:
	if town.get("owner", "neutral") != "enemy" or Players.town_controller_id(town) != controller:
		return false
	if Players.raid_controller_id(raid) != controller or bool(raid.get("raid_retired_to_rebuild", false)):
		return false
	# Enemy hosts already resupply at an entrance or its cardinal approach.
	var entrance := Levels.town_entrance(town)
	return Levels.same_level(entrance, raid) and absi(int(entrance.x) - int(raid.get("x", -999))) + absi(int(entrance.y) - int(raid.get("y", -999))) <= 1

static func upgrade_stacks(town: Dictionary, stacks: Array, treasury: Dictionary) -> Dictionary:
	var result := stacks.duplicate(true)
	var upgrades: Array = []
	var budget := maxi(0, (int(treasury.get("gold", 0)) - GOLD_RESERVE) / 2)
	var candidates: Array = []
	for stack in stacks:
		var base := String(stack.get("unit_id", ""))
		if base not in candidates: candidates.append(base)
	# Highest-tier existing troops get priority; stable ids break ties.
	candidates.sort_custom(func(a, b):
		var ta := int(ContentService.get_unit(a).get("tier", 0))
		var tb := int(ContentService.get_unit(b).get("tier", 0))
		return ta > tb if ta != tb else a < b)
	for base in candidates:
		var target := String(Development.data().get("unit_upgrades", {}).get(base, ""))
		if target == "": continue
		var count := 0
		for stack in result:
			if stack.get("unit_id", "") == base: count += int(stack.get("count", 0))
		var cost := Development.upgrade_cost(base, target, count)
		if int(cost.get("gold", 0)) > budget: continue
		var upgraded := Development.upgrade_army(town, result, base, treasury)
		if not upgraded.ok: continue
		result = upgraded.stacks
		budget -= int(cost.get("gold", 0))
		upgrades.append({"base": base, "target": target, "count": count, "cost": cost})
	return {"stacks": result, "upgrades": upgrades}

static func loadout_value(hero: Dictionary) -> float:
	# Compare actual equipped effects, including set thresholds and penalties.
	var bonuses := Artifacts.aggregate_bonuses(hero.duplicate(true))
	var score := 0.0
	var weights := {"battle_attack": 10.0, "battle_defense": 10.0, "battle_initiative": 9.0, "overworld_movement": 12.0, "scouting_radius": 7.0, "battle_spell_resistance_pct": 0.7, "battle_control_resistance_pct": 0.7}
	for key in weights: score += float(bonuses.get(key, 0)) * float(weights[key])
	for key in bonuses.get("daily_income", {}):
		score += float(bonuses.daily_income[key]) * (0.04 if key == "gold" else 4.0)
	for value in bonuses.get("battle_school_resistance_pct", {}).values(): score += float(value) * 0.25
	for modifier in bonuses.get("spell_modifiers", []):
		score += float(modifier.get("effect_amount_delta", 0)) * 2.0 - float(modifier.get("mana_cost_delta", 0)) * 3.0
	return score

static func best_equipment(hero: Dictionary, artifact_id: String) -> Dictionary:
	var best := {"hero": hero, "gain": 0.0}
	var before := loadout_value(hero)
	var slot_type := Artifacts.artifact_slot(artifact_id)
	var slots: Array = ["trinket", "trinket_2"] if slot_type == "trinket" else [slot_type]
	for slot in slots:
		if slot not in Artifacts.EQUIPMENT_SLOTS: continue
		var candidate := Artifacts.ensure_hero_artifacts(hero.duplicate(true))
		# Explicitly compare both trinket slots; default equip only replaces the first.
		var displaced := String(candidate.artifacts.equipped.get(slot, ""))
		candidate.artifacts.inventory.erase(artifact_id)
		if displaced != "": candidate.artifacts.inventory.append(displaced)
		candidate.artifacts.equipped[slot] = artifact_id
		candidate.artifacts = Artifacts.normalize_hero_artifacts(candidate.artifacts)
		var gain := loadout_value(candidate) - before
		if gain > float(best.gain) + 0.001: best = {"hero": candidate, "gain": gain}
	return best

static func visit(town: Dictionary, raid: Dictionary, treasury: Dictionary, day: int, controller: String) -> Dictionary:
	var changes: Array = []
	var sold_ids: Array = []
	if not can_visit(town, raid, controller): return {"changes": changes}
	var hero: Dictionary = raid.get("enemy_commander_state", {}).duplicate(true)
	if hero.is_empty(): return {"changes": changes}
	for id in Development.active_buildings(town):
		var trained := Development.train_hero(hero, town, String(id))
		if trained.ok:
			hero = trained.hero
			changes.append("trained at " + String(ContentService.get_building(String(id)).get("name", id)))
		var building := ContentService.get_building(String(id))
		if building.has("faction_service") and Development.FactionServices.useful_to_ai(hero, town, building, day, treasury):
			var service := Development.FactionServices.perform(hero, town, building, day, treasury)
			if service.ok:
				hero = service.hero
				changes.append(String(building.faction_service.label).to_lower())
	var army: Dictionary = raid.get("enemy_army", {}).duplicate(true)
	var upgraded := upgrade_stacks(town, army.get("stacks", []), treasury)
	if not upgraded.upgrades.is_empty():
		army["stacks"] = upgraded.stacks
		raid["enemy_army"] = army
		changes.append("upgraded existing troops")
	var has_exchange := false
	for id in Development.active_buildings(town):
		if ContentService.get_building(String(id)).get("artifact_exchange", false): has_exchange = true
	if has_exchange and int(hero.get("last_town_trade_day", -1)) != day:
		# Equip useful items already owned before evaluating purchases or sales.
		for id in Artifacts.normalize_hero_artifacts(hero.get("artifacts", {})).inventory.duplicate():
			var equipment := best_equipment(hero, String(id))
			if float(equipment.gain) > 0.0:
				hero = equipment.hero
				changes.append("equipped " + Artifacts.artifact_name(String(id)))
		var best := {}
		var budget := maxi(0, (int(treasury.get("gold", 0)) - GOLD_RESERVE) / 2)
		var sold: Array = town.get("artifact_shop_purchases", {}).get(str(maxi(0, (day - 1) / 7)), [])
		for id in Development.offers(town, day):
			var artifact := ContentService.get_artifact(String(id))
			var cost := Development.price(artifact)
			if id in sold or cost > budget or Artifacts.has_artifact(hero, String(id)): continue
			var claimed := Artifacts.claim_artifact(hero, String(id), "Purchase preview", false)
			if not claimed.ok: continue
			var equipment := best_equipment(claimed.hero, String(id))
			var value := float(equipment.gain) / float(maxi(1, cost))
			if float(equipment.gain) >= 5.0 and (best.is_empty() or value > float(best.value)):
				best = {"id": id, "value": value}
		if not best.is_empty():
			var bought := Development.trade_artifact(hero, town, day, String(best.id), true, treasury)
			if bought.ok:
				hero = best_equipment(bought.hero, String(best.id)).hero
				changes.append("bought " + Artifacts.artifact_name(String(best.id)))
		for id in Artifacts.normalize_hero_artifacts(hero.get("artifacts", {})).inventory.duplicate():
			var artifact := ContentService.get_artifact(String(id))
			if bool(artifact.get("quest_item", false)) or String(artifact.get("set_id", "")) != "" or String(artifact.get("artifact_class", "")) in ["set_piece", "scenario", "relic"]: continue
			if float(best_equipment(hero, String(id)).gain) > 0.0: continue
			var sale := Development.trade_artifact(hero, town, day, String(id), false, treasury)
			if sale.ok:
				hero = sale.hero
				sold_ids.append(String(id))
				changes.append("sold surplus " + Artifacts.artifact_name(String(id)))
		hero["last_town_trade_day"] = day
	raid["enemy_commander_state"] = hero
	return {"changes": changes, "sold_ids": sold_ids}
