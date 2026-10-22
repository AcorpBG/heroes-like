extends RefCounted

const Progression = preload("res://scripts/core/HeroProgressionRules.gd")
const Spells = preload("res://scripts/core/SpellRules.gd")
## AI weights (content/ai_hero_weights.json) for useful_to_ai: the gold a
## service that costs gold leaves; mana restored at this share or below; gold
## before buying experience; wood and ore an exchange leaves; gold below which,
## or stock at or below which, an exchange is worth it. AiHeroRules puts a
## computer player's set in place (apply_ai_weights); until it does, the
## default set.
static var AI_GOLD_RESERVE: int
static var AI_RESTORE_MANA_SHARE: float
static var AI_EXPERIENCE_MIN_GOLD: int
static var AI_EXCHANGE_MIN_KEPT: int
static var AI_EXCHANGE_GOLD_CAP: int
static var AI_EXCHANGE_LOW_STOCK: int
static var _ai_weights_ready := false

static func week(day: int) -> int:
	return maxi(0, (day - 1) / 7)

static func recruit_reward(town: Dictionary, service: Dictionary) -> Dictionary:
	var reward := {}
	for id in town.get("built_buildings", []):
		var uid := String(ContentService.get_building(String(id)).get("unlock_unit_id", ""))
		if uid == "": continue
		var unit := ContentService.get_unit(uid)
		# JSON numbers arrive as floats; Array membership is type-sensitive.
		var eligible := false
		for tier in service.get("tiers", []):
			if int(unit.get("tier", 0)) == int(tier): eligible = true
		if not eligible: continue
		reward[uid] = maxi(1, int(ceil(float(unit.get("growth", 1)) * float(service.get("growth_pct", 100)) / 100.0)))
	return reward

static func unavailable_reason(hero: Dictionary, town: Dictionary, building: Dictionary, day: int, resources: Dictionary) -> String:
	var service: Dictionary = building.get("faction_service", {})
	if service.is_empty() or String(building.get("id", "")) not in town.get("built_buildings", []): return "This faction building is not constructed."
	var holder := hero if service.get("scope", "town") == "hero" else town
	if int(holder.get("town_service_claims", {}).get(String(building.id), -1)) >= week(day): return "Already used this week. Available again next week."
	for key in service.get("cost", {}):
		if int(resources.get(key, 0)) < int(service.cost[key]): return "Not enough " + String(key).replace("_", " ") + "."
	if service.get("kind", "") == "restore_mana":
		var mana := Spells.mana_state(hero)
		if int(mana.current) >= int(mana.max): return "This hero's mana is already full."
	if service.get("kind", "") == "recruits" and recruit_reward(town, service).is_empty(): return "Build a matching creature dwelling first."
	return ""

static func perform(hero: Dictionary, town: Dictionary, building: Dictionary, day: int, resources: Dictionary) -> Dictionary:
	var reason := unavailable_reason(hero, town, building, day, resources)
	if reason != "": return {"ok": false, "hero": hero, "message": reason}
	var service: Dictionary = building.faction_service
	var result := hero.duplicate(true)
	match String(service.get("kind", "")):
		"resource_exchange":
			for key in service.get("reward", {}): resources[key] = int(resources.get(key, 0)) + int(service.reward[key])
		"restore_mana":
			result = Spells.refresh_daily_mana(result)
		"experience":
			result = Progression.add_experience(result, int(service.get("experience", 0))).hero
		"recruits":
			var pool: Dictionary = town.get("available_recruits", {}).duplicate(true)
			var recruits := recruit_reward(town, service)
			for id in recruits: pool[id] = int(pool.get(id, 0)) + int(recruits[id])
			town["available_recruits"] = pool
		_:
			return {"ok": false, "hero": hero, "message": "Unknown faction service."}
	for key in service.get("cost", {}): resources[key] = int(resources.get(key, 0)) - int(service.cost[key])
	var holder := result if service.get("scope", "town") == "hero" else town
	var claims: Dictionary = holder.get("town_service_claims", {}).duplicate(true)
	claims[String(building.id)] = week(day)
	holder["town_service_claims"] = claims
	return {"ok": true, "hero": result, "message": String(service.get("description", service.get("label", "Faction service completed.")))}
