extends RefCounted

const Development = preload("res://scripts/core/TownDevelopmentRules.gd")
const Artifacts = preload("res://scripts/core/ArtifactRules.gd")
const Levels = preload("res://scripts/core/OverworldLevelRules.gd")
const Players = preload("res://scripts/core/PlayerIdentityRules.gd")
const TurnEngine = preload("res://scripts/core/TurnEngine.gd")
static var _turn_engine_mode: int = TurnEngine.mode
## AI weights (content/ai_hero_weights.json): a hero in its own town spends at
## most TOWN_SPEND_SHARE of the gold above GOLD_RESERVE on upgrades and on an
## artifact, buys one only for a loadout gain of MIN_PURCHASE_GAIN or more, and
## scores loadouts with the LOADOUT_ values. AiHeroRules puts a computer
## player's set in place (apply_ai_weights, which passes it on to the faction
## services' useful_to_ai); until it does, the default set.
static var GOLD_RESERVE: int
static var TOWN_SPEND_SHARE: float
static var MIN_PURCHASE_GAIN: float
static var LOADOUT_VALUES: Dictionary = {}
static var LOADOUT_GOLD_INCOME_VALUE: float
static var LOADOUT_INCOME_VALUE: float
static var LOADOUT_SCHOOL_RESISTANCE_VALUE: float
static var LOADOUT_SPELL_EFFECT_VALUE: float
static var LOADOUT_MANA_COST_VALUE: float
static var _ai_weights_ready := false

static func apply_ai_weights(weights: Dictionary) -> void:
	if _turn_engine_mode != TurnEngine.SHADOW:
		apply_ai_weights__gd(weights)
		return
	var before := TurnEngine.before_writing(&"EnemyTownServices.apply_ai_weights", [weights])
	apply_ai_weights__gd(weights)
	TurnEngine.check_writing(&"EnemyTownServices.apply_ai_weights", before, [weights], null)

static func apply_ai_weights__gd(weights: Dictionary) -> void:
	GOLD_RESERVE = int(weights["gold_reserve"])
	TOWN_SPEND_SHARE = float(weights["town_spend_share"])
	MIN_PURCHASE_GAIN = float(weights["min_purchase_gain"])
	var loadout_values := {}
	var values: Dictionary = weights["loadout_values"]
	for key in values:
		loadout_values[String(key)] = float(values[key])
	LOADOUT_VALUES = loadout_values
	LOADOUT_GOLD_INCOME_VALUE = float(weights["loadout_gold_income_value"])
	LOADOUT_INCOME_VALUE = float(weights["loadout_income_value"])
	LOADOUT_SCHOOL_RESISTANCE_VALUE = float(weights["loadout_school_resistance_value"])
	LOADOUT_SPELL_EFFECT_VALUE = float(weights["loadout_spell_effect_value"])
	LOADOUT_MANA_COST_VALUE = float(weights["loadout_mana_cost_value"])
	Development.FactionServices.apply_ai_weights(weights)
	_ai_weights_ready = true

static func can_visit(town: Dictionary, raid: Dictionary, controller: String) -> bool:
	if _turn_engine_mode != TurnEngine.SHADOW:
		return can_visit__gd(town, raid, controller)
	var before := TurnEngine.before_writing(&"EnemyTownServices.can_visit", [town, raid, controller])
	var result = can_visit__gd(town, raid, controller)
	TurnEngine.check_writing(&"EnemyTownServices.can_visit", before, [town, raid, controller], result)
	return result

static func can_visit__gd(town: Dictionary, raid: Dictionary, controller: String) -> bool:
	if town.get("owner", "neutral") != "enemy" or Players.town_controller_id(town) != controller:
		return false
	if Players.raid_controller_id(raid) != controller or bool(raid.get("raid_retired_to_rebuild", false)):
		return false
	# Enemy hosts already resupply at an entrance or its cardinal approach.
	var entrance := Levels.town_entrance(town)
	return Levels.same_level(entrance, raid) and absi(int(entrance.x) - int(raid.get("x", -999))) + absi(int(entrance.y) - int(raid.get("y", -999))) <= 1

static func upgrade_stacks(town: Dictionary, stacks: Array, treasury: Dictionary) -> Dictionary:
	if _turn_engine_mode != TurnEngine.SHADOW:
		return upgrade_stacks__gd(town, stacks, treasury)
	var before := TurnEngine.before_writing(&"EnemyTownServices.upgrade_stacks", [town, stacks, treasury])
	var result = upgrade_stacks__gd(town, stacks, treasury)
	TurnEngine.check_writing(&"EnemyTownServices.upgrade_stacks", before, [town, stacks, treasury], result)
	return result

static func upgrade_stacks__gd(town: Dictionary, stacks: Array, treasury: Dictionary) -> Dictionary:
	if not _ai_weights_ready:
		apply_ai_weights(ContentService.default_ai_hero_weights())
	var result := stacks.duplicate(true)
	var upgrades: Array = []
	var budget := maxi(0, int(float(int(treasury.get("gold", 0)) - GOLD_RESERVE) * TOWN_SPEND_SHARE))
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
	if _turn_engine_mode != TurnEngine.SHADOW:
		return loadout_value__gd(hero)
	var before := TurnEngine.before_writing(&"EnemyTownServices.loadout_value", [hero])
	var result = loadout_value__gd(hero)
	TurnEngine.check_writing(&"EnemyTownServices.loadout_value", before, [hero], result)
	return result

static func loadout_value__gd(hero: Dictionary) -> float:
	if not _ai_weights_ready:
		apply_ai_weights(ContentService.default_ai_hero_weights())
	# Compare actual equipped effects, including set thresholds and penalties.
	var bonuses := Artifacts.aggregate_bonuses(hero.duplicate(true))
	var score := 0.0
	for key in LOADOUT_VALUES: score += float(bonuses.get(key, 0)) * float(LOADOUT_VALUES[key])
	for key in bonuses.get("daily_income", {}):
		score += float(bonuses.daily_income[key]) * (LOADOUT_GOLD_INCOME_VALUE if key == "gold" else LOADOUT_INCOME_VALUE)
	for value in bonuses.get("battle_school_resistance_pct", {}).values(): score += float(value) * LOADOUT_SCHOOL_RESISTANCE_VALUE
	for modifier in bonuses.get("spell_modifiers", []):
		score += float(modifier.get("effect_amount_delta", 0)) * LOADOUT_SPELL_EFFECT_VALUE - float(modifier.get("mana_cost_delta", 0)) * LOADOUT_MANA_COST_VALUE
	return score

static func best_equipment(hero: Dictionary, artifact_id: String) -> Dictionary:
	if _turn_engine_mode != TurnEngine.SHADOW:
		return best_equipment__gd(hero, artifact_id)
	var before := TurnEngine.before_writing(&"EnemyTownServices.best_equipment", [hero, artifact_id])
	var result = best_equipment__gd(hero, artifact_id)
	TurnEngine.check_writing(&"EnemyTownServices.best_equipment", before, [hero, artifact_id], result)
	return result

static func best_equipment__gd(hero: Dictionary, artifact_id: String) -> Dictionary:
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
	if _turn_engine_mode != TurnEngine.SHADOW:
		return visit__gd(town, raid, treasury, day, controller)
	var before := TurnEngine.before_writing(&"EnemyTownServices.visit", [town, raid, treasury, day, controller])
	var result = visit__gd(town, raid, treasury, day, controller)
	TurnEngine.check_writing(&"EnemyTownServices.visit", before, [town, raid, treasury, day, controller], result)
	return result

static func visit__gd(town: Dictionary, raid: Dictionary, treasury: Dictionary, day: int, controller: String) -> Dictionary:
	if not _ai_weights_ready:
		apply_ai_weights(ContentService.default_ai_hero_weights())
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
		var budget := maxi(0, int(float(int(treasury.get("gold", 0)) - GOLD_RESERVE) * TOWN_SPEND_SHARE))
		var sold: Array = town.get("artifact_shop_purchases", {}).get(str(maxi(0, (day - 1) / 7)), [])
		for id in Development.offers(town, day):
			var artifact := ContentService.get_artifact(String(id))
			var cost := Development.price(artifact)
			if id in sold or cost > budget or Artifacts.has_artifact(hero, String(id)): continue
			var claimed := Artifacts.claim_artifact(hero, String(id), "Purchase preview", false)
			if not claimed.ok: continue
			var equipment := best_equipment(claimed.hero, String(id))
			var value := float(equipment.gain) / float(maxi(1, cost))
			if float(equipment.gain) >= MIN_PURCHASE_GAIN and (best.is_empty() or value > float(best.value)):
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
